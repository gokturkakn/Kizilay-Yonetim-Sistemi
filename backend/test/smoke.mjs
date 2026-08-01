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
