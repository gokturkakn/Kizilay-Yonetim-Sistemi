/**
 * Göç (migration) testi — v1 veritabanı v2'ye VERİ KAYBI OLMADAN yükselir mi?
 *
 * Yöntem: v1 şeması bu dosyada BİREBİR yeniden yazılır (commit 12cef9f'teki `src/db.js`
 * SCHEMA bloğu). Kasıtlı olarak `src/migrations/001_baseline.js` içe aktarılmaz — test,
 * doğruladığı koda bağımlı olmamalıdır. Sonra gerçek veri yazılır, `runMigrations()`
 * çalıştırılır ve her satırın hayatta kaldığı tek tek doğrulanır.
 */
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import Database from 'better-sqlite3';
import { runMigrations, migrationFiles } from '../src/migrations/index.js';
import { seedAll } from '../src/seed.js';

let pass = 0;
let fail = 0;
const failures = [];
const check = (label, ok, extra = '') => {
  if (ok) { pass += 1; console.log(`  ✓ ${label}`); } else {
    fail += 1; failures.push(label);
    console.error(`  ✗ ${label}${extra ? ` — ${extra}` : ''}`);
  }
};

const dir = mkdtempSync(path.join(tmpdir(), 'kk-migration-'));
const dbPath = path.join(dir, 'v1.db');

// --------------------------------------------------------------------------
// v1 ŞEMASI (MVP 0.1 — birebir kopya, `persons.is_active INTEGER` dahil)
// --------------------------------------------------------------------------
const V1_SCHEMA = `
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL, role TEXT NOT NULL CHECK (role IN ('genel_merkez','saha')),
  created_at TEXT NOT NULL DEFAULT (datetime('now')));
CREATE TABLE provinces (
  id INTEGER PRIMARY KEY AUTOINCREMENT, code INTEGER NOT NULL UNIQUE, name TEXT NOT NULL);
CREATE TABLE districts (
  id INTEGER PRIMARY KEY AUTOINCREMENT, province_id INTEGER NOT NULL REFERENCES provinces(id),
  name TEXT NOT NULL, UNIQUE (province_id, name));
CREATE TABLE bodies (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  type TEXT NOT NULL CHECK (type IN ('koordinasyon_kurulu','komisyon')),
  name TEXT NOT NULL UNIQUE, is_active INTEGER NOT NULL DEFAULT 1);
CREATE TABLE task_areas (
  id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE,
  is_active INTEGER NOT NULL DEFAULT 1);
CREATE TABLE persons (
  id INTEGER PRIMARY KEY AUTOINCREMENT, first_name TEXT NOT NULL, last_name TEXT NOT NULL,
  tc_no TEXT NOT NULL UNIQUE, birth_date TEXT NOT NULL, phone TEXT NOT NULL, email TEXT,
  profession TEXT,
  unit_type TEXT NOT NULL CHECK (unit_type IN ('il_teskilati','ilce_teskilati','temsilcilik')),
  province_id INTEGER NOT NULL REFERENCES provinces(id),
  district_id INTEGER REFERENCES districts(id),
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')));
CREATE INDEX idx_persons_active ON persons(is_active);
CREATE TABLE memberships (
  id INTEGER PRIMARY KEY AUTOINCREMENT, body_id INTEGER NOT NULL REFERENCES bodies(id),
  person_id INTEGER NOT NULL REFERENCES persons(id), role_title TEXT,
  is_active INTEGER NOT NULL DEFAULT 1, created_at TEXT NOT NULL DEFAULT (datetime('now')));
CREATE TABLE field_activities (
  id INTEGER PRIMARY KEY AUTOINCREMENT, task_area_id INTEGER NOT NULL REFERENCES task_areas(id),
  activity_date TEXT NOT NULL, volunteer_count INTEGER NOT NULL CHECK (volunteer_count >= 0),
  beneficiary_count INTEGER NOT NULL CHECK (beneficiary_count >= 0),
  province_id INTEGER REFERENCES provinces(id), district_id INTEGER REFERENCES districts(id),
  notes TEXT, created_by INTEGER NOT NULL REFERENCES users(id),
  created_at TEXT NOT NULL DEFAULT (datetime('now')));
CREATE TABLE meetings (
  id INTEGER PRIMARY KEY AUTOINCREMENT, body_id INTEGER NOT NULL REFERENCES bodies(id),
  meeting_date TEXT NOT NULL, decision TEXT NOT NULL, outcome TEXT,
  created_by INTEGER NOT NULL REFERENCES users(id),
  created_at TEXT NOT NULL DEFAULT (datetime('now')));
CREATE TABLE assignments (
  id INTEGER PRIMARY KEY AUTOINCREMENT, person_id INTEGER NOT NULL REFERENCES persons(id),
  title TEXT NOT NULL, description TEXT, assigned_date TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'atandi' CHECK (status IN ('atandi','devam','tamamlandi')),
  created_by INTEGER NOT NULL REFERENCES users(id),
  created_at TEXT NOT NULL DEFAULT (datetime('now')));
CREATE TABLE audit_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT, entity TEXT NOT NULL, entity_id INTEGER NOT NULL,
  action TEXT NOT NULL, changed_by INTEGER REFERENCES users(id), changes TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')));
`;

// --------------------------------------------------------------------------
// 1. Gerçekçi bir v1 veritabanı kur
// --------------------------------------------------------------------------
console.log('\n[1] v1 veritabanı oluşturuluyor (gerçek veriyle)');
const db = new Database(dbPath);
db.pragma('foreign_keys = ON');
db.exec(V1_SCHEMA);

db.transaction(() => {
  db.prepare("INSERT INTO users (id, name, email, password_hash, role) VALUES (1,'Genel Merkez Admin','admin@kizilay.org.tr','x','genel_merkez')").run();
  db.prepare("INSERT INTO users (id, name, email, password_hash, role) VALUES (2,'Saha Kullanıcısı','saha@kizilay.org.tr','x','saha')").run();

  // Gerçek il/ilçe alt kümesi — plaka kodları v2'de bölgeye eşlenecek.
  const insP = db.prepare('INSERT INTO provinces (id, code, name) VALUES (?, ?, ?)');
  const insD = db.prepare('INSERT INTO districts (id, province_id, name) VALUES (?, ?, ?)');
  insP.run(1, 6, 'Ankara'); insP.run(2, 34, 'İstanbul'); insP.run(3, 61, 'Trabzon');
  insD.run(1, 1, 'Çankaya'); insD.run(2, 2, 'Üsküdar');

  db.prepare("INSERT INTO bodies (id, type, name) VALUES (1,'koordinasyon_kurulu','Koordinasyon Kurulu')").run();
  db.prepare("INSERT INTO bodies (id, type, name) VALUES (2,'komisyon','Eğitim Komisyonu')").run();
  db.prepare("INSERT INTO bodies (id, type, name, is_active) VALUES (3,'komisyon','Kapatılmış Komisyon', 0)").run();
  db.prepare("INSERT INTO task_areas (id, name) VALUES (1,'Kan Bağışı Organizasyonu')").run();

  const insPerson = db.prepare(`INSERT INTO persons
    (id, first_name, last_name, tc_no, birth_date, phone, email, profession, unit_type,
     province_id, district_id, is_active, created_at, updated_at)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)`);
  insPerson.run(1, 'Ayşe', 'Yılmaz', '10000000146', '1985-03-12', '05300000001', 'ayse@example.org', 'Öğretmen', 'il_teskilati', 1, null, 1, '2026-01-02 10:00:00', '2026-01-02 10:00:00');
  insPerson.run(2, 'Fatma', 'Demir', '10000000254', '1990-07-25', '05300000002', null, 'Hemşire', 'ilce_teskilati', 1, 1, 1, '2026-01-03 10:00:00', '2026-01-03 10:00:00');
  insPerson.run(3, 'Zeynep', 'Kaya', '10000000362', '1988-11-02', '05300000003', 'zeynep@example.org', 'Avukat', 'il_teskilati', 2, null, 0, '2026-01-04 10:00:00', '2026-01-04 10:00:00');
  insPerson.run(4, 'Büşra', 'Öztürk', '10000000470', '1993-08-03', '05300000004', null, 'Mühendis', 'temsilcilik', 3, null, 0, '2026-01-05 10:00:00', '2026-01-05 10:00:00');

  db.prepare("INSERT INTO memberships (id, body_id, person_id, role_title, is_active) VALUES (1,1,1,'Başkan',1)").run();
  db.prepare("INSERT INTO memberships (id, body_id, person_id, role_title, is_active) VALUES (2,2,2,'Üye',0)").run();

  db.prepare(`INSERT INTO field_activities (id, task_area_id, activity_date, volunteer_count,
    beneficiary_count, province_id, district_id, notes, created_by)
    VALUES (1,1,'2026-07-05',12,240,1,1,'Kızılay Meydanı kan bağışı standı',2)`).run();
  db.prepare(`INSERT INTO field_activities (id, task_area_id, activity_date, volunteer_count,
    beneficiary_count, province_id, district_id, notes, created_by)
    VALUES (2,1,'2026-07-12',8,65,2,null,'İkinci faaliyet',2)`).run();

  db.prepare(`INSERT INTO meetings (id, body_id, meeting_date, decision, outcome, created_by)
    VALUES (1,1,'2026-07-01','2026 sonbahar kampanya takviminin onaylanması','Oy birliği ile onaylandı',1)`).run();
  db.prepare(`INSERT INTO meetings (id, body_id, meeting_date, decision, outcome, created_by)
    VALUES (2,2,'2026-07-10','İlk yardım eğitici eğitimi planlaması',null,1)`).run();

  db.prepare(`INSERT INTO assignments (id, person_id, title, description, assigned_date, status, created_by)
    VALUES (1,1,'Ankara il koordinasyon toplantısı','Hazırlık','2026-07-15','devam',1)`).run();

  db.prepare(`INSERT INTO audit_logs (id, entity, entity_id, action, changed_by, changes)
    VALUES (1,'persons',1,'create',1,'{"first_name":"Ayşe"}')`).run();
  db.prepare(`INSERT INTO audit_logs (id, entity, entity_id, action, changed_by, changes)
    VALUES (2,'persons',3,'active_toggle',1,'{"is_active":{"old":1,"new":0}}')`).run();
})();

const before = {
  users: db.prepare('SELECT COUNT(*) AS c FROM users').get().c,
  persons: db.prepare('SELECT COUNT(*) AS c FROM persons').get().c,
  memberships: db.prepare('SELECT COUNT(*) AS c FROM memberships').get().c,
  field_activities: db.prepare('SELECT COUNT(*) AS c FROM field_activities').get().c,
  meetings: db.prepare('SELECT COUNT(*) AS c FROM meetings').get().c,
  assignments: db.prepare('SELECT COUNT(*) AS c FROM assignments').get().c,
  audit_logs: db.prepare('SELECT COUNT(*) AS c FROM audit_logs').get().c,
};
const beforePersons = db.prepare('SELECT * FROM persons ORDER BY id').all();
const beforeMeetings = db.prepare('SELECT * FROM meetings ORDER BY id').all();
const beforeActivities = db.prepare('SELECT * FROM field_activities ORDER BY id').all();
console.log('  v1 satır sayıları:', JSON.stringify(before));
check('v1 veritabanında persons.is_active sütunu var (v2 öncesi şekil)',
  db.prepare('PRAGMA table_info(persons)').all().some((c) => c.name === 'is_active'));
check('v1 veritabanında schema_migrations YOK (göç altyapısı yoktu)',
  !db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name='schema_migrations'").get());

// --------------------------------------------------------------------------
// 2. Göçleri çalıştır
// --------------------------------------------------------------------------
console.log('\n[2] Göçler uygulanıyor');
const result = await runMigrations(db);
console.log(`  uygulanan: ${result.applied.length} → ${result.applied.join(', ')}`);
// Sayıyı sabitlemek yerine keşfedilen göç dosyalarıyla karşılaştır: yeni göç eklendiğinde
// test kendiliğinden güncel kalır, ama "hepsi uygulandı" güvencesi korunur.
const allMigrations = migrationFiles().map((f) => f.replace(/\.js$/, ''));
check(`tüm göçler uygulandı (${allMigrations.length} adet)`,
  result.applied.length === allMigrations.length, `alınan: ${result.applied.length}`);
check('şema sürümü son göç dosyasıyla eşleşiyor',
  result.version === allMigrations[allMigrations.length - 1], `alınan: ${result.version}`);
check('001_baseline mevcut v1 tablolarını bozmadan geçti', result.applied[0] === '001_baseline');
check('yabancı anahtar ihlali yok', db.pragma('foreign_key_check').length === 0);

// --------------------------------------------------------------------------
// 3. VERİ KAYBI OLMADI MI?
// --------------------------------------------------------------------------
console.log('\n[3] v1 verisi korundu mu?');
const after = Object.fromEntries(
  Object.keys(before).map((t) => [t, db.prepare(`SELECT COUNT(*) AS c FROM ${t}`).get().c])
);
for (const t of Object.keys(before)) {
  check(`${t}: ${before[t]} satır korundu`, after[t] === before[t], `alınan: ${after[t]}`);
}

const afterPersons = db.prepare('SELECT * FROM persons ORDER BY id').all();
check('kişi kimlikleri (id) değişmedi',
  afterPersons.map((p) => p.id).join(',') === beforePersons.map((p) => p.id).join(','));
check('kişi alanları birebir korundu (ad/TC/telefon/il/ilçe/tarihler)',
  afterPersons.every((a) => {
    const b = beforePersons.find((x) => x.id === a.id);
    return b && a.first_name === b.first_name && a.last_name === b.last_name
      && a.tc_no === b.tc_no && a.birth_date === b.birth_date && a.phone === b.phone
      && a.email === b.email && a.profession === b.profession && a.unit_type === b.unit_type
      && a.province_id === b.province_id && a.district_id === b.district_id
      && a.created_at === b.created_at && a.updated_at === b.updated_at;
  }));

console.log('\n[4] K3 — is_active → status eşlemesi');
check("is_active=1 → status='aktif'",
  afterPersons.filter((p) => [1, 2].includes(p.id)).every((p) => p.status === 'aktif'),
  JSON.stringify(afterPersons.map((p) => [p.id, p.status])));
check("is_active=0 → status='pasif'",
  afterPersons.filter((p) => [3, 4].includes(p.id)).every((p) => p.status === 'pasif'));
check('hiçbir v1 satırı teskilat_yok olmadı (v1de böyle bir bilgi yoktu)',
  afterPersons.every((p) => p.status !== 'teskilat_yok'));
check('persons.is_active sütunu artık YOK (status devraldı)',
  !db.prepare('PRAGMA table_info(persons)').all().some((c) => c.name === 'is_active'));
check("status CHECK kısıtı gerçekten çalışıyor", (() => {
  try {
    db.prepare("UPDATE persons SET status = 'saçmalık' WHERE id = 1").run();
    return false;
  } catch { return true; }
})());

console.log('\n[5] Toplantı ve faaliyet kayıtları');
const afterMeetings = db.prepare('SELECT * FROM meetings ORDER BY id').all();
check('toplantı içerikleri birebir korundu',
  afterMeetings.every((a) => {
    const b = beforeMeetings.find((x) => x.id === a.id);
    return b && a.body_id === b.body_id && a.meeting_date === b.meeting_date
      && a.decision === b.decision && a.outcome === b.outcome
      && a.created_by === b.created_by && a.created_at === b.created_at;
  }));
check('toplantıya v2 alanları eklendi (boş)',
  afterMeetings.every((m) => m.meeting_type_id === null && m.platform === null && m.agenda === null));
check('meetings.body_id artık NULL kabul ediyor (Kamp/Çalıştay)', (() => {
  db.prepare("INSERT INTO meetings (body_id, meeting_date, decision, created_by) VALUES (NULL,'2026-08-01','',1)").run();
  const ok = db.prepare('SELECT COUNT(*) AS c FROM meetings WHERE body_id IS NULL').get().c === 1;
  db.prepare('DELETE FROM meetings WHERE body_id IS NULL').run();
  return ok;
})());

const afterActivities = db.prepare('SELECT * FROM field_activities ORDER BY id').all();
check('saha faaliyetleri birebir korundu',
  afterActivities.every((a) => {
    const b = beforeActivities.find((x) => x.id === a.id);
    return b && a.task_area_id === b.task_area_id && a.activity_date === b.activity_date
      && a.volunteer_count === b.volunteer_count && a.beneficiary_count === b.beneficiary_count
      && a.notes === b.notes && a.created_by === b.created_by;
  }));

check('üyelikler korundu (rol başlıkları dahil)',
  db.prepare("SELECT COUNT(*) AS c FROM memberships WHERE role_title = 'Başkan'").get().c === 1);
check('görev atamaları korundu',
  db.prepare("SELECT status FROM assignments WHERE id = 1").get().status === 'devam');
check('denetim günlüğü korundu (JSON içeriğiyle)',
  db.prepare('SELECT changes FROM audit_logs WHERE id = 1').get().changes === '{"first_name":"Ayşe"}');

console.log('\n[6] Yeni v2 tabloları ve sütunları');
const tables = new Set(db.prepare("SELECT name FROM sqlite_master WHERE type='table'").all().map((t) => t.name));
for (const t of ['schema_migrations', 'lookup_categories', 'lookup_items', 'regions', 'org_units',
  'org_assignments', 'attachments', 'calendar_events', 'calendar_event_dates', 'content_blocks',
  'tasks', 'trainings', 'events', 'material_requests', 'shipments', 'stock_items', 'stock_movements']) {
  check(`tablo oluştu: ${t}`, tables.has(t));
}
check('provinces.region_id sütunu eklendi',
  db.prepare('PRAGMA table_info(provinces)').all().some((c) => c.name === 'region_id'));
check('users.is_active / region_id / province_id sütunları eklendi', (() => {
  const cols = db.prepare('PRAGMA table_info(users)').all().map((c) => c.name);
  return ['is_active', 'region_id', 'province_id', 'updated_at'].every((c) => cols.includes(c));
})());

// --- 013: kullanıcı ilçe kapsamı + zorunlu şifre değişikliği bayrağı ---
const userCols = db.prepare('PRAGMA table_info(users)').all();
const userColNames = userCols.map((c) => c.name);
check('users.district_id sütunu eklendi (013)', userColNames.includes('district_id'));
check('users.must_change_password sütunu eklendi (013)', userColNames.includes('must_change_password'));
check('district_id NULL kabul ediyor (kapsamsız hesap geçerlidir)',
  userCols.find((c) => c.name === 'district_id')?.notnull === 0);
// Yükseltmede kimse kilitlenmemeli: v1'den gelen hesaplar bayraksız gelir.
check('mevcut (v1) hesaplar must_change_password = 0 ile geliyor — kimse kilitlenmez',
  db.prepare('SELECT COUNT(*) AS c FROM users WHERE must_change_password <> 0').get().c === 0);
check('district_id yabancı anahtarı districts tablosuna bağlı', (() => {
  const fks = db.pragma('foreign_key_list(users)');
  return fks.some((f) => f.from === 'district_id' && f.table === 'districts');
})());
check('users.district_id gerçekten yazılabiliyor ve okunabiliyor', (() => {
  db.prepare('UPDATE users SET province_id = 1, district_id = 1 WHERE id = 2').run();
  const row = db.prepare('SELECT province_id, district_id FROM users WHERE id = 2').get();
  db.prepare('UPDATE users SET province_id = NULL, district_id = NULL WHERE id = 2').run();
  return row.province_id === 1 && row.district_id === 1;
})());
check('idx_users_district indeksi oluştu',
  db.prepare("SELECT name FROM sqlite_master WHERE type='index' AND name='idx_users_district'").get() !== undefined);

// --------------------------------------------------------------------------
// 4. Göç idempotent mi?
// --------------------------------------------------------------------------
console.log('\n[7] Göçlerin ikinci kez çalıştırılması');
const second = await runMigrations(db);
check('ikinci çalıştırmada hiçbir göç uygulanmaz', second.applied.length === 0, JSON.stringify(second.applied));
check('ikinci çalıştırmada tüm göçler atlanır', second.skipped.length === allMigrations.length);
check('veri ikinci çalıştırmadan sonra da yerinde',
  db.prepare('SELECT COUNT(*) AS c FROM persons').get().c === before.persons);

// --------------------------------------------------------------------------
// 5. Yükseltilmiş veritabanı üzerine v2 tohumlaması
// --------------------------------------------------------------------------
console.log('\n[8] Yükseltilmiş veritabanına v2 referans verisi tohumlanıyor');
const counts = seedAll(db, { withDemo: false });
check('7 bölge tohumlandı', counts.regions === 7, `alınan: ${counts.regions}`);
check('mevcut 3 il bölgeye eşlendi', counts.provinces_mapped === 3, `alınan: ${counts.provinces_mapped}`);
check('Ankara → İç Anadolu',
  db.prepare("SELECT r.code FROM provinces p JOIN regions r ON r.id = p.region_id WHERE p.name = 'Ankara'").get()?.code === 'ic_anadolu');
check('Trabzon → Karadeniz',
  db.prepare("SELECT r.code FROM provinces p JOIN regions r ON r.id = p.region_id WHERE p.name = 'Trabzon'").get()?.code === 'karadeniz');
// Tanımlar Yönetim Paneli'nden genişletilebilir olduğu için alt sınır kontrol edilir;
// SPEC-V2'nin zorunlu kıldığı kategoriler ayrıca isim isim doğrulanır.
check('tanım kategorileri tohumlandı (≥14)', counts.lookup_categories >= 14, `alınan: ${counts.lookup_categories}`);
check('tanım kalemleri tohumlandı (≥138)', counts.lookup_items >= 138, `alınan: ${counts.lookup_items}`);
const requiredCategories = ['gorev_turu', 'alt_gorev', 'egitim_konusu', 'toplanti_turu',
  'toplanti_yontemi', 'lojistik_urun', 'gonderim_sekli'];
const seededCategories = new Set(
  db.prepare('SELECT code FROM lookup_categories').all().map((r) => r.code)
);
check('SPEC-V2 zorunlu tanım kategorileri mevcut',
  requiredCategories.every((c) => seededCategories.has(c)),
  `eksik: ${requiredCategories.filter((c) => !seededCategories.has(c)).join(', ')}`);
check('takvim tohumlandı', counts.calendar_events === 68, `alınan: ${counts.calendar_events}`);
check('13 içerik bloğu', counts.content_blocks === 13, `alınan: ${counts.content_blocks}`);

// seedAll ayrıca SPEC'teki 6 standart komisyonu da güvence altına alır; bu v1 DB'sinde
// yalnız 'Eğitim Komisyonu' vardı, 5 tanesi eklenir → toplam 7 komisyon.
// org_units: 1 kurul + 7 komisyon + 7 bölge temsilciliği + 3 il + 2 ilçe = 20
check('teşkilat birimleri v1 bodies + il/ilçelerden türetildi',
  counts.org_units === 20, `alınan: ${counts.org_units}`);
check('komisyon birimleri bodies ile 1:1',
  db.prepare("SELECT COUNT(*) AS c FROM org_units WHERE type = 'komisyon'").get().c
  === db.prepare("SELECT COUNT(*) AS c FROM bodies WHERE type = 'komisyon'").get().c);
check('aktif komisyon aktif, kapatılmış komisyon pasif taşındı', (() => {
  const a = db.prepare("SELECT status FROM org_units WHERE name = 'Eğitim Komisyonu'").get();
  const p = db.prepare("SELECT status FROM org_units WHERE name = 'Kapatılmış Komisyon'").get();
  return a?.status === 'aktif' && p?.status === 'pasif';
})());
check("il/ilçe başkanlıkları 'teskilat_yok' ile geldi (boşluk raporu anlamlı)",
  db.prepare("SELECT COUNT(*) AS c FROM org_units WHERE type IN ('il_baskanligi','ilce_baskanligi') AND status = 'teskilat_yok'").get().c === 5);

check('tohumlama v1 kişilerine dokunmadı',
  db.prepare('SELECT COUNT(*) AS c FROM persons').get().c === before.persons);
// v1'den yükselen `saha` hesabına da coğrafya verilir (boş olduğu sürece).
check('yükseltilen saha hesabına Ankara/Çankaya kapsamı verildi', (() => {
  const u = db.prepare("SELECT province_id, district_id FROM users WHERE email = 'saha@kizilay.org.tr'").get();
  const ank = db.prepare("SELECT id FROM provinces WHERE name = 'Ankara'").get();
  const cnk = db.prepare('SELECT id FROM districts WHERE province_id = ? AND name = ?').get(ank.id, 'Çankaya');
  return u.province_id === ank.id && u.district_id === cnk.id;
})());
check('yükseltmede tohumlanan hesaplar kilitli gelmiyor (must_change_password = 0)',
  db.prepare('SELECT COUNT(*) AS c FROM users WHERE must_change_password = 1').get().c === 0);
check('tohumlama sonrası da yabancı anahtar ihlali yok', db.pragma('foreign_key_check').length === 0);

db.close();
rmSync(dir, { recursive: true, force: true });

console.log(`\n=== Göç testi: ${pass} başarılı, ${fail} başarısız ===`);
if (fail > 0) {
  console.error('Başarısız kontroller:', failures.join(' | '));
  process.exit(1);
}
