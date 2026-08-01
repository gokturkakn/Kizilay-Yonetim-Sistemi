// Duman testi: geçici bir SQLite dosyasıyla sunucuyu başlatır ve API sözleşmesini uçtan uca doğrular.
// Çalıştırma: npm test  (framework gerekmez, sadece Node)
import { spawn } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const BACKEND_DIR = path.resolve(__dirname, '..');
const PORT = process.env.SMOKE_PORT || 4199;
const BASE = `http://localhost:${PORT}/api/v1`;

const tmpDir = mkdtempSync(path.join(tmpdir(), 'kk-smoke-'));
const dbPath = path.join(tmpDir, 'smoke.db');

let passed = 0;
let failed = 0;
const failures = [];

function check(name, cond, extra = '') {
  if (cond) {
    passed += 1;
    console.log(`  ✓ ${name}`);
  } else {
    failed += 1;
    failures.push(name);
    console.error(`  ✗ ${name}${extra ? ` — ${extra}` : ''}`);
  }
}

async function req(method, url, { token, body, raw } = {}) {
  const headers = {};
  if (token) headers.Authorization = `Bearer ${token}`;
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  const res = await fetch(`${BASE}${url}`, {
    method,
    headers,
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  if (raw) return res;
  let json = null;
  try { json = await res.json(); } catch { /* 204 vs. */ }
  return { status: res.status, json };
}

const server = spawn(process.execPath, ['src/server.js'], {
  cwd: BACKEND_DIR,
  // Duman testi demo kayıtları üzerinde çalışır; üretim tohumlaması bunları yüklemez.
  env: { ...process.env, KK_DB_PATH: dbPath, PORT: String(PORT), KK_SEED_DEMO: '1' },
  stdio: ['ignore', 'pipe', 'pipe'],
});
let serverLog = '';
server.stdout.on('data', (d) => { serverLog += d; });
server.stderr.on('data', (d) => { serverLog += d; });

async function waitForServer(timeoutMs = 30000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    try {
      const res = await fetch(`http://localhost:${PORT}/health`);
      if (res.ok) return res.json();
    } catch { /* henüz hazır değil */ }
    await new Promise((r) => setTimeout(r, 250));
  }
  throw new Error(`Sunucu ${timeoutMs}ms içinde ayağa kalkmadı.\n--- log ---\n${serverLog}`);
}

try {
  console.log(`Geçici DB: ${dbPath}`);
  const health = await waitForServer();

  console.log('\n[1] Sağlık ve tohum veri');
  check('health.status ok', health.status === 'ok' && health.db === 'ok');
  check('81 il', health.seeded?.provinces === 81, `alınan: ${health.seeded?.provinces}`);
  check('>900 ilçe', health.seeded?.districts > 900, `alınan: ${health.seeded?.districts}`);
  check('6 komisyon', health.seeded?.commissions === 6, `alınan: ${health.seeded?.commissions}`);

  console.log('\n[2] Kimlik doğrulama');
  const noAuth = await req('GET', '/persons');
  check('token olmadan 401', noAuth.status === 401 && noAuth.json?.error?.code);

  const badLogin = await req('POST', '/auth/login', { body: { email: 'admin@kizilay.org.tr', password: 'yanlis' } });
  check('yanlış şifre 401', badLogin.status === 401);

  const adminLogin = await req('POST', '/auth/login', { body: { email: 'admin@kizilay.org.tr', password: 'Admin!2026' } });
  check('admin girişi', adminLogin.status === 200 && !!adminLogin.json.token && adminLogin.json.user.role === 'genel_merkez');
  const admin = adminLogin.json.token;

  const sahaLogin = await req('POST', '/auth/login', { body: { email: 'saha@kizilay.org.tr', password: 'Saha!2026' } });
  check('saha girişi', sahaLogin.status === 200 && sahaLogin.json.user.role === 'saha');
  const saha = sahaLogin.json.token;

  console.log('\n[3] Tüm GET uçları');
  const provinces = await req('GET', '/provinces?limit=100', { token: admin });
  check('GET /provinces {data,total}', provinces.status === 200 && provinces.json.total === 81 && provinces.json.data.length === 81);
  const ankara = provinces.json.data.find((p) => p.code === 6);
  check('plaka 6 = Ankara', ankara?.name === 'Ankara');

  const districts = await req('GET', `/provinces/${ankara.id}/districts?limit=100`, { token: admin });
  check('GET /provinces/:id/districts', districts.status === 200 && districts.json.total === 25 && districts.json.data.some((d) => d.name === 'Çankaya'));

  const commissions = await req('GET', '/commissions', { token: admin });
  check('GET /commissions (6 adet)', commissions.status === 200 && commissions.json.total === 6);

  const taskAreas = await req('GET', '/task-areas', { token: admin });
  check('GET /task-areas (7 tohum)', taskAreas.status === 200 && taskAreas.json.total === 7);

  const bodies = await req('GET', '/bodies', { token: admin });
  check('GET /bodies (1 kurul + 6 komisyon)', bodies.status === 200 && bodies.json.total === 7
    && bodies.json.data.filter((b) => b.type === 'koordinasyon_kurulu').length === 1);
  const kurul = bodies.json.data.find((b) => b.type === 'koordinasyon_kurulu');

  const members = await req('GET', `/bodies/${kurul.id}/members`, { token: admin });
  check('GET /bodies/:id/members', members.status === 200 && members.json.total >= 2
    && members.json.data[0].person?.first_name && members.json.data[0].membership_id > 0);

  const persons = await req('GET', '/persons', { token: admin });
  check('GET /persons (tohum ≥8)', persons.status === 200 && persons.json.total >= 8);
  const onePerson = await req('GET', `/persons/${persons.json.data[0].id}`, { token: admin });
  check('GET /persons/:id', onePerson.status === 200 && !!onePerson.json.tc_no);

  const personsFiltered = await req('GET', `/persons?province_id=${ankara.id}&is_active=1`, { token: admin });
  check('GET /persons filtreleri', personsFiltered.status === 200
    && personsFiltered.json.data.every((p) => p.province_id === ankara.id && p.is_active === 1));
  const personsQ = await req('GET', '/persons?q=Demir', { token: admin });
  check('GET /persons?q= isim araması', personsQ.status === 200 && personsQ.json.total >= 1);

  const acts = await req('GET', '/field-activities', { token: admin });
  check('GET /field-activities (tohum ≥3)', acts.status === 200 && acts.json.total >= 3);
  const actsFiltered = await req('GET', '/field-activities?from=2026-07-10&to=2026-07-20', { token: admin });
  check('GET /field-activities tarih filtresi', actsFiltered.status === 200
    && actsFiltered.json.data.every((a) => a.activity_date >= '2026-07-10' && a.activity_date <= '2026-07-20'));

  const meetings = await req('GET', '/meetings', { token: admin });
  check('GET /meetings (tohum ≥2)', meetings.status === 200 && meetings.json.total >= 2);

  const assignments = await req('GET', '/assignments', { token: saha });
  check('GET /assignments (saha rolü okuyabilir)', assignments.status === 200 && assignments.json.total >= 3);

  const audits = await req('GET', '/audit-logs', { token: admin });
  check('GET /audit-logs (genel_merkez)', audits.status === 200 && Array.isArray(audits.json.data));
  const auditsForbidden = await req('GET', '/audit-logs', { token: saha });
  check('GET /audit-logs saha için 403', auditsForbidden.status === 403);

  console.log('\n[4] Kişi oluştur / güncelle / aktif-pasif');
  const badTc = await req('POST', '/persons', {
    token: admin,
    body: { first_name: 'Test', last_name: 'Kisi', tc_no: '12345678901', birth_date: '1990-01-01', phone: '05001112233', unit_type: 'il_teskilati', province_id: ankara.id },
  });
  check('geçersiz TC reddedilir', badTc.status === 400 && badTc.json.error.code === 'INVALID_TC_NO');

  const cankaya = districts.json.data.find((d) => d.name === 'Çankaya');
  const newPerson = await req('POST', '/persons', {
    token: admin,
    body: {
      first_name: 'Duman', last_name: 'Testi', tc_no: '99988877780', birth_date: '1991-06-15',
      phone: '05009998877', email: 'duman.testi@example.org', profession: 'Test Uzmanı',
      unit_type: 'ilce_teskilati', province_id: ankara.id, district_id: cankaya.id,
    },
  });
  check('POST /persons 201', newPerson.status === 201 && newPerson.json.id > 0 && newPerson.json.is_active === 1);
  const pid = newPerson.json.id;

  const dupTc = await req('POST', '/persons', {
    token: admin,
    body: { ...{ first_name: 'Kopya', last_name: 'Kayit', tc_no: '99988877780', birth_date: '1991-06-15', phone: '05000000000', unit_type: 'il_teskilati', province_id: ankara.id } },
  });
  check('aynı TC ile 409', dupTc.status === 409);

  const sahaCreate = await req('POST', '/persons', {
    token: saha,
    body: { first_name: 'X', last_name: 'Y', tc_no: '99988877780', birth_date: '1990-01-01', phone: '1', unit_type: 'il_teskilati', province_id: ankara.id },
  });
  check('saha kişi ekleyemez (403)', sahaCreate.status === 403);

  const updated = await req('PUT', `/persons/${pid}`, {
    token: admin,
    body: {
      first_name: 'Duman', last_name: 'Testi', tc_no: '99988877780', birth_date: '1991-06-15',
      phone: '05009998877', email: 'duman.testi@example.org', profession: 'Kıdemli Test Uzmanı',
      unit_type: 'ilce_teskilati', province_id: ankara.id, district_id: cankaya.id,
    },
  });
  check('PUT /persons/:id', updated.status === 200 && updated.json.profession === 'Kıdemli Test Uzmanı');

  const toggled = await req('PATCH', `/persons/${pid}/active`, { token: admin, body: { is_active: false } });
  check('PATCH /persons/:id/active', toggled.status === 200 && toggled.json.is_active === 0);

  // Regresyon: kişi formundaki aktif/pasif tiki POST ve PUT'ta da yazılmalı.
  // (Daha önce sessizce yok sayılıyordu; form "kaydedildi" deyip kişiyi aktif bırakıyordu.)
  const passiveTc = '99665544356'; // sağlama kuralına uygun sahte numara
  const bornPassive = await req('POST', '/persons', {
    token: admin,
    body: {
      first_name: 'Pasif', last_name: 'Doğan', tc_no: passiveTc, birth_date: '1991-02-02',
      phone: '05007776655', email: 'pasif.dogan@example.org', profession: 'Gönüllü',
      unit_type: 'il_teskilati', province_id: ankara.id, is_active: false,
    },
  });
  check('POST /persons is_active:false yazılır', bornPassive.status === 201 && bornPassive.json.is_active === 0);

  const basePut = {
    first_name: 'Pasif', last_name: 'Doğan', tc_no: passiveTc, birth_date: '1991-02-02',
    phone: '05007776655', email: 'pasif.dogan@example.org', profession: 'Gönüllü',
    unit_type: 'il_teskilati', province_id: ankara.id,
  };
  const reactivated = await req('PUT', `/persons/${bornPassive.json.id}`, {
    token: admin, body: { ...basePut, is_active: true },
  });
  check('PUT /persons is_active:true yazılır', reactivated.status === 200 && reactivated.json.is_active === 1);

  const untouched = await req('PUT', `/persons/${bornPassive.json.id}`, {
    token: admin, body: { ...basePut, profession: 'Kıdemli Gönüllü' },
  });
  check('PUT is_active gönderilmezse mevcut değer korunur', untouched.status === 200 && untouched.json.is_active === 1);

  console.log('\n[5] Saha faaliyeti / toplantı / atama oluşturma');
  const ta = taskAreas.json.data[0];
  const newAct = await req('POST', '/field-activities', {
    token: saha,
    body: { task_area_id: ta.id, activity_date: '2026-08-01', volunteer_count: 7, beneficiary_count: 55, province_id: ankara.id, notes: 'Duman testi faaliyeti' },
  });
  check('POST /field-activities (saha rolü)', newAct.status === 201 && newAct.json.id > 0);

  const newMeeting = await req('POST', '/meetings', {
    token: admin,
    body: { body_id: kurul.id, meeting_date: '2026-08-01', decision: 'Duman testi kararı', outcome: 'Onaylandı' },
  });
  check('POST /meetings', newMeeting.status === 201 && newMeeting.json.decision === 'Duman testi kararı');

  const newAssignment = await req('POST', '/assignments', {
    token: admin,
    body: { person_id: pid, title: 'Duman testi görevi', assigned_date: '2026-08-01' },
  });
  check('POST /assignments (varsayılan status atandi)', newAssignment.status === 201 && newAssignment.json.status === 'atandi');
  const sahaAssign = await req('POST', '/assignments', {
    token: saha,
    body: { person_id: pid, title: 'Yetkisiz', assigned_date: '2026-08-01' },
  });
  check('saha atama yapamaz (403)', sahaAssign.status === 403);

  console.log('\n[6] Değişiklik günlüğü doğrulaması');
  const auditAfter = await req('GET', '/audit-logs?entity=persons&limit=100', { token: admin });
  const personAudits = auditAfter.json.data.filter((a) => a.entity === 'persons' && a.entity_id === pid);
  check('kişi create kaydı', personAudits.some((a) => a.action === 'create'));
  check('kişi update kaydı', personAudits.some((a) => a.action === 'update' && a.changes?.profession));
  check('kişi active_toggle kaydı', personAudits.some((a) => a.action === 'active_toggle'));
  // Denetim izi "kim" sorusunu isimle cevaplamalı (SPEC §4) — ham kullanıcı ID'si yetersiz.
  check('audit kaydında changed_by_name dolu',
    personAudits.length > 0 && personAudits.every((a) => typeof a.changed_by_name === 'string' && a.changed_by_name.length > 0));
  check('changed_by_name doğru kullanıcıyı gösterir',
    personAudits.some((a) => a.changed_by_name === 'Genel Merkez Admin'));

  const allAudits = await req('GET', '/audit-logs?limit=200', { token: admin });
  check('faaliyet create kaydı', allAudits.json.data.some((a) => a.entity === 'field_activities' && a.entity_id === newAct.json.id && a.action === 'create'));
  check('toplantı create kaydı', allAudits.json.data.some((a) => a.entity === 'meetings' && a.entity_id === newMeeting.json.id && a.action === 'create'));
  check('atama create kaydı', allAudits.json.data.some((a) => a.entity === 'assignments' && a.entity_id === newAssignment.json.id && a.action === 'create'));

  console.log('\n[7] Excel dışa aktarım');
  const xlsxRes = await req('GET', '/export/persons.xlsx', { token: admin, raw: true });
  const buf = Buffer.from(await xlsxRes.arrayBuffer());
  check('xlsx HTTP 200 + içerik türü', xlsxRes.status === 200
    && (xlsxRes.headers.get('content-type') || '').includes('spreadsheetml'));
  check('xlsx boş değil', buf.length > 1000, `boyut: ${buf.length}`);
  check('xlsx PK zip imzası', buf[0] === 0x50 && buf[1] === 0x4b, `ilk baytlar: ${buf[0]},${buf[1]}`);
  const xlsxForbidden = await req('GET', '/export/persons.xlsx', { token: saha, raw: true });
  check('export saha için 403', xlsxForbidden.status === 403);


  // ======================================================================
  // v2 modülleri (Faz A + Faz B)
  // ======================================================================
  console.log('\n[9] v2 — sağlık ucu ve tohum sayaçları');
  check('/api/v1/health de yanıt veriyor (denetim D-1)', (await req('GET', '/health')).status === 200);
  check('schema_version dolu', typeof health.schema_version === 'string' && health.schema_version.startsWith('010'));
  check('10 göç uygulandı', health.migrations_applied === 10, `alınan: ${health.migrations_applied}`);
  check('7 bölge', health.seeded?.regions === 7, `alınan: ${health.seeded?.regions}`);
  check('81 il bölgeye eşlendi', health.seeded?.provinces_mapped_to_region === 81,
    `alınan: ${health.seeded?.provinces_mapped_to_region}`);
  check('14 tanım kategorisi', health.seeded?.lookup_categories === 14, `alınan: ${health.seeded?.lookup_categories}`);
  check('138 tanım kalemi', health.seeded?.lookup_items === 138, `alınan: ${health.seeded?.lookup_items}`);
  check('1068 teşkilat birimi', health.seeded?.org_units === 1068, `alınan: ${health.seeded?.org_units}`);
  check('68 takvim kaydı', health.seeded?.calendar_events === 68, `alınan: ${health.seeded?.calendar_events}`);
  check('13 içerik bloğu', health.seeded?.content_blocks === 13, `alınan: ${health.seeded?.content_blocks}`);

  console.log('\n[10] v2 — bölgeler (K2)');
  const regions = await req('GET', '/regions', { token: admin });
  check('GET /regions 7 bölge', regions.status === 200 && regions.json.total === 7);
  const expectedCounts = { Marmara: 11, 'Ege': 8, 'Akdeniz': 8, 'İç Anadolu': 13, 'Karadeniz': 18, 'Doğu Anadolu': 14, 'Güneydoğu Anadolu': 9 };
  check('her bölgenin il sayısı doğru (toplam 81)',
    regions.json.data.every((r) => r.province_count === expectedCounts[r.name])
    && regions.json.data.reduce((a, r) => a + r.province_count, 0) === 81,
    JSON.stringify(regions.json.data.map((r) => [r.name, r.province_count])));
  const icAnadolu = regions.json.data.find((r) => r.code === 'ic_anadolu');
  const regionProvinces = await req('GET', `/regions/${icAnadolu.id}/provinces?limit=100`, { token: admin });
  check('GET /regions/:id/provinces — Ankara İç Anadolu bölgesinde',
    regionProvinces.status === 200 && regionProvinces.json.data.some((p) => p.name === 'Ankara'));
  check('GET /provinces artık region_id döndürüyor (v1 uyumlu alan ekleme)',
    typeof provinces.json.data[0].region_id === 'number');

  console.log('\n[11] v2 — tanımlar / lookups (K1)');
  const cats = await req('GET', '/lookup-categories', { token: admin });
  check('GET /lookup-categories 14 kategori', cats.status === 200 && cats.json.total === 14);
  const gorevTuru = await req('GET', '/lookups/gorev_turu?limit=50', { token: admin });
  check('GET /lookups/gorev_turu → 12 ana başlık', gorevTuru.status === 200 && gorevTuru.json.total === 12);
  const egitimKonu = await req('GET', '/lookups/egitim_konusu?limit=50', { token: admin });
  check('GET /lookups/egitim_konusu → 18 konu', egitimKonu.json.total === 18, `alınan: ${egitimKonu.json.total}`);
  const toplantiTuru = await req('GET', '/lookups/toplanti_turu?limit=50', { token: admin });
  check('GET /lookups/toplanti_turu → 7 tür', toplantiTuru.json.total === 7, `alınan: ${toplantiTuru.json.total}`);
  const urunler = await req('GET', '/lookups/lojistik_urun?limit=50', { token: admin });
  check('GET /lookups/lojistik_urun → 15 ürün', urunler.json.total === 15, `alınan: ${urunler.json.total}`);
  check('bilinmeyen kategori 404', (await req('GET', '/lookups/yok_boyle_bir_sey', { token: admin })).status === 404);

  const kanHizmetleri = gorevTuru.json.data.find((i) => i.name === 'Kan Hizmetleri');
  const altGorev = await req('GET', `/lookups/alt_gorev?parent_id=${kanHizmetleri.id}&limit=50`, { token: admin });
  check('alt görevler ana göreve bağlı (parent_id hiyerarşisi)',
    altGorev.status === 200 && altGorev.json.total >= 3
    && altGorev.json.data.every((i) => i.parent_id === kanHizmetleri.id));
  const kanBagisi = altGorev.json.data.find((i) => i.name === 'Kan Bağışı Organizasyonu');

  // Genişletilebilirlik: kod değişikliği olmadan yeni kalem eklenebilmeli.
  const newLookup = await req('POST', '/lookup-items', {
    token: admin, body: { category_code: 'gorev_turu', name: 'Duman Testi Görev Türü' },
  });
  check('POST /lookup-items 201 (kod değişikliği gerekmez)', newLookup.status === 201 && newLookup.json.id > 0);
  check('yeni kalem listede görünür',
    (await req('GET', '/lookups/gorev_turu?limit=50', { token: admin })).json.total === 13);
  check('aynı isim 409', (await req('POST', '/lookup-items', {
    token: admin, body: { category_code: 'gorev_turu', name: 'Duman Testi Görev Türü' },
  })).status === 409);
  check('saha rolü tanım ekleyemez (403)', (await req('POST', '/lookup-items', {
    token: saha, body: { category_code: 'gorev_turu', name: 'Yetkisiz' },
  })).status === 403);
  const renamed = await req('PUT', `/lookup-items/${newLookup.json.id}`, {
    token: admin, body: { name: 'Duman Testi Görev Türü (güncel)' },
  });
  check('PUT /lookup-items/:id', renamed.status === 200 && renamed.json.name.endsWith('(güncel)'));
  check('DELETE /lookup-items/:id 204',
    (await req('DELETE', `/lookup-items/${newLookup.json.id}`, { token: admin })).status === 204);

  console.log('\n[12] v2 — teşkilat birimleri (K4) ve boşluk raporu');
  const summary = await req('GET', '/org-units/summary', { token: admin });
  check('GET /org-units/summary 1068 birim', summary.status === 200 && summary.json.total === 1068);
  check('81 il başkanlığı kayıtlı',
    summary.json.by_type.find((t) => t.type === 'il_baskanligi')?.total === 81);
  check('973 ilçe başkanlığı kayıtlı',
    summary.json.by_type.find((t) => t.type === 'ilce_baskanligi')?.total === 973);
  check('teşkilat boşluğu raporlanıyor (teskilat_yok > 1000)', summary.json.by_status.teskilat_yok > 1000);
  check('bölge kırılımı 7 satır', summary.json.by_region.filter((x) => x.region_id !== null).length === 7);

  const bosIller = await req('GET', '/org-units?type=il_baskanligi&status=teskilat_yok&limit=100', { token: admin });
  check('GET /org-units status filtresi', bosIller.status === 200
    && bosIller.json.data.every((u) => u.status === 'teskilat_yok' && u.type === 'il_baskanligi'));
  const bosIl = bosIller.json.data[0];
  check('birim bölge/il adlarıyla dönüyor', typeof bosIl.region_name === 'string' && typeof bosIl.province_name === 'string');

  console.log('\n[13] v2 — görevlendirmeler (org_assignments)');
  const orgAssign = await req('POST', '/org-assignments', {
    token: admin,
    body: { org_unit_id: bosIl.id, person_id: pid, role_title: 'İl Başkanı', start_date: '2026-08-01' },
  });
  check('POST /org-assignments 201', orgAssign.status === 201 && orgAssign.json.person_name);
  const activatedUnit = await req('GET', `/org-units/${bosIl.id}`, { token: admin });
  check('görevlendirme birimi otomatik AKTİF yapar (teşkilat boşluğu kapanır)',
    activatedUnit.json.status === 'aktif' && activatedUnit.json.assignment_count === 1);
  check('GET /org-units/:id/assignments',
    (await req('GET', `/org-units/${bosIl.id}/assignments`, { token: admin })).json.total === 1);
  check('saha rolü görevlendirme ekleyemez (403)', (await req('POST', '/org-assignments', {
    token: saha, body: { org_unit_id: bosIl.id, person_id: pid },
  })).status === 403);
  check('DELETE /org-assignments/:id 204',
    (await req('DELETE', `/org-assignments/${orgAssign.json.id}`, { token: admin })).status === 204);
  check('son görevlendirme silinince birim tekrar teşkilat_yok olur',
    (await req('GET', `/org-units/${bosIl.id}`, { token: admin })).json.status === 'teskilat_yok');

  console.log('\n[14] v2 — görevler (§3.2A)');
  const newTask = await req('POST', '/tasks', {
    token: saha,
    body: {
      task_date: '2026-08-01', province_id: ankara.id, district_id: cankaya.id,
      branch: 'Çankaya Şubesi', task_type_id: kanHizmetleri.id, sub_task_id: kanBagisi.id,
      volunteer_count: 10, beneficiary_count: 120, duration_hours: 4.5, notes: 'Duman testi görevi',
    },
  });
  check('POST /tasks 201 (saha rolü)', newTask.status === 201 && newTask.json.id > 0);
  check('bölge il üzerinden otomatik türetildi', newTask.json.region_id === icAnadolu.id
    && newTask.json.region_name === 'İç Anadolu');
  check('görev türü/alt görev adları çözümlendi',
    newTask.json.task_type_name === 'Kan Hizmetleri' && newTask.json.sub_task_name === 'Kan Bağışı Organizasyonu');
  check('süre (duration_hours) kaydedildi', newTask.json.duration_hours === 4.5);
  const wrongSub = await req('POST', '/tasks', {
    token: saha,
    body: { task_date: '2026-08-01', task_type_id: gorevTuru.json.data[0].id, sub_task_id: kanBagisi.id },
  });
  check('yanlış ana göreve bağlı alt görev reddedilir (400)', wrongSub.status === 400);
  const inUse = await req('DELETE', `/lookup-items/${kanHizmetleri.id}`, { token: admin });
  check('kullanımdaki tanım silinemez (409 IN_USE)',
    inUse.status === 409 && inUse.json.error.code === 'IN_USE');
  check('silmek yerine pasifleştirilebilir',
    (await req('PATCH', `/lookup-items/${kanHizmetleri.id}/active`, { token: admin, body: { is_active: false } })).json.is_active === 0);
  await req('PATCH', `/lookup-items/${kanHizmetleri.id}/active`, { token: admin, body: { is_active: true } });
  check('GET /tasks filtreleri',
    (await req('GET', `/tasks?task_type_id=${kanHizmetleri.id}&from=2026-07-01`, { token: admin })).json.total >= 1);
  check('PUT /tasks/:id', (await req('PUT', `/tasks/${newTask.json.id}`, {
    token: saha, body: { task_date: '2026-08-02', task_type_id: kanHizmetleri.id, volunteer_count: 11 },
  })).json.volunteer_count === 11);
  check('saha görev silemez (403)', (await req('DELETE', `/tasks/${newTask.json.id}`, { token: saha })).status === 403);

  console.log('\n[15] v2 — eğitimler (§3.2B)');
  const konu = egitimKonu.json.data.find((i) => i.name === 'İlk Yardım');
  const kategori = (await req('GET', '/lookups/egitim_kategorisi', { token: admin })).json.data;
  const yontem = (await req('GET', '/lookups/egitim_yontemi', { token: admin })).json.data;
  const newTraining = await req('POST', '/trainings', {
    token: saha,
    body: {
      training_date: '2026-08-01', province_id: ankara.id, topic_id: konu.id,
      category_id: kategori.find((c) => c.name === 'Gönüllü').id,
      method_id: yontem.find((m) => m.name === 'Çevrim İçi').id,
      trainer: 'Duman Eğitmen', participant_count: 25, volunteer_count: 3, duration_hours: 2,
    },
  });
  check('POST /trainings 201', newTraining.status === 201 && newTraining.json.topic_name === 'İlk Yardım');
  check('kategori × yöntem çözümlendi',
    newTraining.json.category_name === 'Gönüllü' && newTraining.json.method_name === 'Çevrim İçi');
  check('yanlış kategoriden konu reddedilir (400)', (await req('POST', '/trainings', {
    token: saha, body: { training_date: '2026-08-01', topic_id: kanHizmetleri.id },
  })).status === 400);
  check('GET /trainings', (await req('GET', '/trainings', { token: admin })).json.total >= 1);

  console.log('\n[16] v2 — etkinlikler (§3.2C) ve takvim (K6)');
  const calendar = await req('GET', '/calendar-events?limit=200', { token: admin });
  check('GET /calendar-events 68 kayıt', calendar.status === 200 && calendar.json.total === 68);
  check('millî bayramlar sabit tarihli',
    calendar.json.data.filter((c) => c.category === 'milli_bayram').every((c) => c.is_fixed === 1 && c.month));
  const dini = calendar.json.data.filter((c) => c.category === 'dini_bayram');
  check('dinî bayramlar hareketli (is_fixed=0, ay/gün boş)',
    dini.length === 2 && dini.every((c) => c.is_fixed === 0 && c.month === null));
  const ramazan = dini.find((c) => c.name === 'Ramazan Bayramı');
  const ramazanDates = await req('GET', `/calendar-events/${ramazan.id}/dates`, { token: admin });
  check('hareketli bayramın yıl bazlı tarihi var (2026)',
    ramazanDates.json.data.some((d) => d.year === 2026 && d.start_date === '2026-03-20'));
  const withYear = await req('GET', '/calendar-events?is_fixed=0&year=2026&limit=50', { token: admin });
  check('?year= ile resolved_date dönüyor',
    withYear.json.data.find((c) => c.name === 'Ramazan Bayramı')?.resolved_date === '2026-03-20');
  const cumhuriyet = calendar.json.data.find((c) => c.name === 'Cumhuriyet Bayramı');
  check('önemli haftalarda bitiş tarihi var',
    calendar.json.data.find((c) => c.name === 'Kızılay Haftası')?.end_month === 11);

  const newEvent = await req('POST', '/events', {
    token: saha,
    body: {
      event_date: '2026-10-29', calendar_event_id: cumhuriyet.id, province_id: ankara.id,
      participant_count: 200, volunteer_count: 20, beneficiary_count: 500,
    },
  });
  check('POST /events 201 (ad takvimden seçilir)',
    newEvent.status === 201 && newEvent.json.calendar_event_name === 'Cumhuriyet Bayramı');
  check('takvim kaydı olmadan etkinlik açılamaz (400)', (await req('POST', '/events', {
    token: saha, body: { event_date: '2026-10-29', calendar_event_id: 999999 },
  })).status === 400);
  check('kullanımdaki takvim kaydı silinemez (409 IN_USE)',
    (await req('DELETE', `/calendar-events/${cumhuriyet.id}`, { token: admin })).status === 409);

  console.log('\n[17] v2 — toplantılar (§3.2D, dinamik yer/platform)');
  const yuzYuze = toplantiTuru.json.data;
  const tYontem = (await req('GET', '/lookups/toplanti_yontemi', { token: admin })).json.data;
  const online = tYontem.find((m) => m.name === 'Çevrim İçi');
  const inPerson = tYontem.find((m) => m.name === 'Yüz Yüze');
  const calistay = yuzYuze.find((t) => t.name === 'Çalıştay');

  const onlineMeeting = await req('POST', '/meetings', {
    token: admin,
    body: {
      meeting_date: '2026-08-05', meeting_type_id: calistay.id, method_id: online.id,
      platform: 'Microsoft Teams', participants: '40 kişi', agenda: 'Duman testi gündemi',
    },
  });
  check('POST /meetings body_id olmadan (Kamp/Çalıştay) 201',
    onlineMeeting.status === 201 && onlineMeeting.json.body_id === null
    && onlineMeeting.json.platform === 'Microsoft Teams');
  check('çevrim içi toplantıya location gönderilemez (400)', (await req('POST', '/meetings', {
    token: admin, body: { meeting_date: '2026-08-05', method_id: online.id, location: 'Salon' },
  })).status === 400);
  check('yüz yüze toplantıya platform gönderilemez (400)', (await req('POST', '/meetings', {
    token: admin, body: { meeting_date: '2026-08-05', method_id: inPerson.id, platform: 'Zoom' },
  })).status === 400);
  check('v1 toplantı gövdesi hâlâ çalışıyor (geriye dönük uyum)',
    (await req('POST', '/meetings', {
      token: admin, body: { body_id: kurul.id, meeting_date: '2026-08-06', decision: 'v1 kararı', outcome: 'ok' },
    })).json.decision === 'v1 kararı');
  check('GET /meetings?meeting_type_id= filtresi',
    (await req('GET', `/meetings?meeting_type_id=${calistay.id}`, { token: admin })).json.total >= 1);

  console.log('\n[18] v2 — lojistik (§3.3)');
  const yelek = urunler.json.data.find((u) => u.name === 'Yelek');
  const kargo = (await req('GET', '/lookups/gonderim_sekli', { token: admin })).json.data.find((g) => g.name === 'Kargo');
  const stockBefore = (await req('GET', `/stock-items?product_id=${yelek.id}`, { token: admin })).json.data[0];
  check('GET /stock-items 15 ürün', (await req('GET', '/stock-items?limit=50', { token: admin })).json.total === 15);

  const stockIn = await req('POST', '/stock-movements', {
    token: admin, body: { product_id: yelek.id, direction: 'giris', quantity: 100, reason: 'Duman testi girişi' },
  });
  check('POST /stock-movements giriş 201', stockIn.status === 201);
  const stockAfterIn = (await req('GET', `/stock-items?product_id=${yelek.id}`, { token: admin })).json.data[0];
  check('stok girişi bakiyeyi artırdı', stockAfterIn.quantity === stockBefore.quantity + 100);

  const request = await req('POST', '/material-requests', {
    token: saha,
    body: { request_date: '2026-08-01', product_id: yelek.id, quantity: 30, province_id: ankara.id, notes: 'Duman testi talebi' },
  });
  check('POST /material-requests 201 (durum talep)',
    request.status === 201 && request.json.status === 'talep' && request.json.product_name === 'Yelek');

  const shipment = await req('POST', '/shipments', {
    token: admin,
    body: {
      request_id: request.json.id, shipment_date: '2026-08-03', shipping_method_id: kargo.id,
      tracking_no: 'TR999888777', quantity: 30, received_by: 'Duman Testi', received_date: '2026-08-05',
    },
  });
  check('POST /shipments 201', shipment.status === 201 && shipment.json.tracking_no === 'TR999888777');
  const stockAfterShip = (await req('GET', `/stock-items?product_id=${yelek.id}`, { token: admin })).json.data[0];
  check('gönderi stoktan düştü (aynı transaction)', stockAfterShip.quantity === stockAfterIn.quantity - 30,
    `beklenen ${stockAfterIn.quantity - 30}, alınan ${stockAfterShip.quantity}`);
  check('talep durumu teslim_edildi oldu',
    (await req('GET', `/material-requests/${request.json.id}`, { token: admin })).json.status === 'teslim_edildi');
  check('gönderisi olan talep silinemez (409 IN_USE)',
    (await req('DELETE', `/material-requests/${request.json.id}`, { token: admin })).status === 409);
  const tooMuch = await req('POST', '/stock-movements', {
    token: admin, body: { product_id: yelek.id, direction: 'cikis', quantity: 999999 },
  });
  check('stok eksiye düşürülemez (400 INSUFFICIENT_STOCK)',
    tooMuch.status === 400 && tooMuch.json.error.code === 'INSUFFICIENT_STOCK');
  check('GET /stock-movements', (await req('GET', '/stock-movements', { token: admin })).json.total >= 2);

  console.log('\n[19] v2 — dosya ekleri (K5)');
  const png = Buffer.from(
    '89504e470d0a1a0a0000000d494844520000000100000001080200000090' +
    '7753de0000000c4944415408d763f8cfc0000003010100' + '18dd8db00000000049454e44ae426082', 'hex');
  const form = new FormData();
  form.append('file', new Blob([png], { type: 'image/png' }), '../../../etc/kotu-niyetli.png');
  form.append('entity', 'tasks');
  form.append('entity_id', String(newTask.json.id));
  form.append('kind', 'fotograf');
  const upRes = await fetch(`${BASE}/attachments`, {
    method: 'POST', headers: { Authorization: `Bearer ${saha}` }, body: form,
  });
  const upJson = await upRes.json();
  check('POST /attachments 201', upRes.status === 201 && upJson.id > 0);
  check('istemci dosya adı yol bileşenlerinden arındırıldı',
    upJson.file_name === 'kotu-niyetli.png', `alınan: ${upJson.file_name}`);
  check('ek görev kaydına bağlandı', upJson.entity === 'tasks' && upJson.entity_id === newTask.json.id);
  check('görevin attachment_count arttı',
    (await req('GET', `/tasks/${newTask.json.id}`, { token: admin })).json.attachment_count === 1);

  const dlRes = await fetch(`${BASE}/attachments/${upJson.id}/download`, {
    headers: { Authorization: `Bearer ${saha}` },
  });
  const dlBuf = Buffer.from(await dlRes.arrayBuffer());
  check('GET /attachments/:id/download dosyayı verir',
    dlRes.status === 200 && dlBuf.length === png.length && dlBuf[1] === 0x50 && dlBuf[2] === 0x4e);
  check('Content-Disposition attachment', (dlRes.headers.get('content-disposition') || '').startsWith('attachment;'));

  const badForm = new FormData();
  badForm.append('file', new Blob([Buffer.from('#!/bin/sh\nrm -rf /')], { type: 'text/x-shellscript' }), 'kotu.sh');
  badForm.append('entity', 'tasks');
  badForm.append('entity_id', String(newTask.json.id));
  badForm.append('kind', 'dokuman');
  const badUp = await fetch(`${BASE}/attachments`, {
    method: 'POST', headers: { Authorization: `Bearer ${saha}` }, body: badForm,
  });
  const badUpJson = await badUp.json();
  check('izinsiz dosya türü reddedilir (400 UNSUPPORTED_FILE_TYPE)',
    badUp.status === 400 && badUpJson.error?.code === 'UNSUPPORTED_FILE_TYPE');
  check('DELETE /attachments/:id 204',
    (await req('DELETE', `/attachments/${upJson.id}`, { token: saha })).status === 204);

  console.log('\n[20] v2 — içerik blokları');
  const blocks = await req('GET', '/content-blocks', { token: saha });
  check('GET /content-blocks 13 blok', blocks.status === 200 && blocks.json.total === 13);
  const oneBlock = await req('GET', '/content-blocks/saha.gorevler', { token: saha });
  check('GET /content-blocks/:key', oneBlock.status === 200 && oneBlock.json.title === 'Görevler');
  const editedBlock = await req('PUT', '/content-blocks/saha.gorevler', {
    token: admin, body: { title: 'Görevler', body: 'Duman testi metni' },
  });
  check('PUT /content-blocks/:key (genel_merkez)',
    editedBlock.status === 200 && editedBlock.json.body === 'Duman testi metni'
    && editedBlock.json.updated_by_name === 'Genel Merkez Admin');
  check('saha içerik düzenleyemez (403)', (await req('PUT', '/content-blocks/saha.gorevler', {
    token: saha, body: { title: 'X', body: 'Y' },
  })).status === 403);

  console.log('\n[21] v2 — kullanıcı yönetimi (denetim Y-2)');
  const users = await req('GET', '/users', { token: admin });
  check('GET /users (genel_merkez)', users.status === 200 && users.json.total >= 2);
  check('password_hash hiçbir yanıtta dönmüyor',
    users.json.data.every((u) => u.password_hash === undefined));
  check('saha kullanıcı listesini göremez (403)', (await req('GET', '/users', { token: saha })).status === 403);

  const newUser = await req('POST', '/users', {
    token: admin,
    body: {
      name: 'Ankara Saha Sorumlusu', email: 'ankara.saha@kizilay.org.tr',
      password: 'Ankara!2026', role: 'saha', province_id: ankara.id, region_id: icAnadolu.id,
    },
  });
  check('POST /users 201 (paylaşımlı hesap sorunu çözülür)',
    newUser.status === 201 && newUser.json.role === 'saha' && newUser.json.province_id === ankara.id);
  check('zayıf şifre reddedilir (400 WEAK_PASSWORD)', (await req('POST', '/users', {
    token: admin, body: { name: 'X', email: 'x@kizilay.org.tr', password: '123', role: 'saha' },
  })).json.error?.code === 'WEAK_PASSWORD');
  check('aynı e-posta 409', (await req('POST', '/users', {
    token: admin, body: { name: 'Y', email: 'ankara.saha@kizilay.org.tr', password: 'Gecerli!2026', role: 'saha' },
  })).status === 409);

  const newUserLogin = await req('POST', '/auth/login', {
    body: { email: 'ankara.saha@kizilay.org.tr', password: 'Ankara!2026' },
  });
  check('yeni kullanıcı giriş yapabiliyor', newUserLogin.status === 200 && !!newUserLogin.json.token);
  check('PATCH /users/:id/active pasifleştirir',
    (await req('PATCH', `/users/${newUser.json.id}/active`, { token: admin, body: { is_active: false } })).json.is_active === 0);
  const disabledLogin = await req('POST', '/auth/login', {
    body: { email: 'ankara.saha@kizilay.org.tr', password: 'Ankara!2026' },
  });
  check('pasif kullanıcı giriş YAPAMAZ (401 ACCOUNT_DISABLED)',
    disabledLogin.status === 401 && disabledLogin.json.error.code === 'ACCOUNT_DISABLED');
  check('son genel_merkez hesabı pasifleştirilemez (409 LAST_ADMIN)',
    (await req('PATCH', '/users/1/active', { token: admin, body: { is_active: false } })).json.error?.code === 'LAST_ADMIN');
  check('PUT /users/:id/password 200',
    (await req('PUT', `/users/${newUser.json.id}/password`, { token: admin, body: { password: 'YeniSifre!2026' } })).json.ok === true);

  console.log('\n[22] v2 — üç durumlu statü (K3) geriye dönük uyum');
  const statusPerson = await req('PATCH', `/persons/${pid}/status`, { token: admin, body: { status: 'teskilat_yok' } });
  check('PATCH /persons/:id/status → teskilat_yok', statusPerson.status === 200 && statusPerson.json.status === 'teskilat_yok');
  check('teskilat_yok için türetilmiş is_active = 0 (v1 istemcisi kırılmaz)', statusPerson.json.is_active === 0);
  check('is_active=0 filtresi pasif + teskilat_yok döndürür',
    (await req('GET', '/persons?is_active=0&limit=100', { token: admin })).json.data.every((p) => p.status !== 'aktif'));
  check('?status= filtresi çalışıyor',
    (await req('GET', '/persons?status=teskilat_yok', { token: admin })).json.data.every((p) => p.status === 'teskilat_yok'));
  const backToActive = await req('PATCH', `/persons/${pid}/active`, { token: admin, body: { is_active: true } });
  check('v1 PATCH .../active hâlâ çalışıyor → aktif',
    backToActive.json.is_active === 1 && backToActive.json.status === 'aktif');
  check('geçersiz statü reddedilir (400)',
    (await req('PATCH', `/persons/${pid}/status`, { token: admin, body: { status: 'yok_boyle' } })).status === 400);
  check('kişi yanıtında bölge bilgisi var', backToActive.json.region_name === 'İç Anadolu');

  console.log('\n[23] v2 — dashboard');
  const dash = await req('GET', '/dashboard/summary', { token: admin });
  check('GET /dashboard/summary 200', dash.status === 200);
  check('teşkilat durum dağılımı var',
    dash.json.organization.org_units.total === 1068 && dash.json.organization.persons.total >= 9);
  check('faaliyet sayaçları dolu',
    dash.json.activity.tasks.count >= 1 && dash.json.activity.trainings.count >= 1
    && dash.json.activity.events.count >= 1 && dash.json.activity.meetings.count >= 1);
  check('lojistik sayaçları dolu',
    dash.json.logistics.requests.total >= 1 && dash.json.logistics.stock.products === 15);
  check('bölge kırılımı 7 satır', dash.json.organization.by_region.length === 7);
  const dashFiltered = await req('GET', `/dashboard/summary?region_id=${icAnadolu.id}&from=2026-01-01&to=2026-12-31`, { token: admin });
  check('dashboard filtreleri uygulanıyor',
    dashFiltered.status === 200 && dashFiltered.json.filters.region_id === icAnadolu.id);
  const byRegion = await req('GET', '/dashboard/by-region', { token: admin });
  check('GET /dashboard/by-region 7 bölge', byRegion.status === 200 && byRegion.json.total === 7);

  console.log('\n[24] v2 — denetim izi yeni varlıkları kapsıyor');
  const v2Audits = await req('GET', '/audit-logs?limit=500', { token: admin });
  for (const entity of ['tasks', 'trainings', 'events', 'org_assignments', 'material_requests',
    'shipments', 'attachments', 'lookup_items', 'content_blocks', 'users']) {
    check(`audit: ${entity} kaydı yazılıyor`,
      v2Audits.json.data.some((a) => a.entity === entity),
      `bulunan varlıklar: ${[...new Set(v2Audits.json.data.map((a) => a.entity))].join(',')}`);
  }
  check('v2 audit kayıtlarında da changed_by_name dolu',
    v2Audits.json.data.filter((a) => a.entity === 'tasks').every((a) => typeof a.changed_by_name === 'string'));

  console.log('\n[8] Hata gövdesi biçimi');
  const nf = await req('GET', '/persons/999999', { token: admin });
  check('404 {error:{code,message}}', nf.status === 404 && typeof nf.json.error?.code === 'string' && typeof nf.json.error?.message === 'string');
} catch (err) {
  failed += 1;
  failures.push(`beklenmeyen hata: ${err.message}`);
  console.error('\nBeklenmeyen hata:', err);
} finally {
  server.kill('SIGTERM');
  rmSync(tmpDir, { recursive: true, force: true });
}

console.log(`\n=== Duman testi sonucu: ${passed} başarılı, ${failed} başarısız ===`);
if (failed > 0) {
  console.error('Başarısız kontroller:', failures.join(' | '));
  process.exit(1);
}
