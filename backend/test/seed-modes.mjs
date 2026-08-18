// Üretim tohumlaması ile demo tohumlamasının kesin olarak ayrıldığını doğrular.
// Amaç: canlıya çıkarken sahte kişi/faaliyet kayıtlarının veritabanına sızmaması.
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';

let pass = 0;
let fail = 0;
const check = (label, ok, extra = '') => {
  console.log(`  ${ok ? '✓' : '✗'} ${label}${ok || !extra ? '' : ` — ${extra}`}`);
  ok ? pass++ : fail++;
};

const dir = mkdtempSync(path.join(tmpdir(), 'kk-seed-'));

// Her senaryo KENDİ veritabanı dosyasını alır.
// (Önceden `getDb()` + önbellek kırıcı import kullanılıyordu; `config.js` tek kez
//  değerlendiği için `DB_PATH` ilk çağrıda donuyor ve tüm senaryolar AYNI dosyayı
//  paylaşıyordu. `createDb(path)` ile yol açıkça verilir, izolasyon gerçek olur.)
const { createDb } = await import('../src/db.js');
const { seedAll, resolveSeedUsers } = await import('../src/seed.js');

async function seedInto(dbFile, withDemo, opts = {}) {
  const db = await createDb(path.join(dir, dbFile));
  const counts = seedAll(db, { withDemo, ...opts });
  const transactional = ['persons', 'memberships', 'field_activities', 'meetings', 'assignments',
    'tasks', 'trainings', 'events', 'org_assignments', 'material_requests', 'shipments', 'attachments',
    'documents']
    .map((t) => db.prepare(`SELECT COUNT(*) AS c FROM ${t}`).get().c)
    .reduce((a, b) => a + b, 0);
  return { counts, transactional, db };
}

/** Her çağrı için taze bir veritabanı + toplanmış konsol çıktısı. */
async function seedWithEnv(dbFile, env, { withDemo = false } = {}) {
  const logs = [];
  const out = await seedInto(dbFile, withDemo, { env, log: (m) => logs.push(String(m)) });
  return { ...out, log: logs.join('\n') };
}

console.log('\n[1] Üretim tohumlaması (withDemo: false)');
const prod = await seedInto('prod.db', false);
check('81 il yüklenir', prod.counts.provinces === 81);
check('973 ilçe yüklenir', prod.counts.districts === 973);
check('6 komisyon + kurul yüklenir', prod.counts.commissions === 6 && prod.counts.bodies === 7);
check('görev alanları yüklenir', prod.counts.task_areas >= 7);
check('giriş kullanıcıları yüklenir', prod.counts.users === 2);
check('HİÇ demo kaydı yüklenmez', prod.transactional === 0);

console.log('\n[2] Demo tohumlaması (withDemo: true)');
const demo = await seedInto('demo.db', true);
check('referans veri yine tam', demo.counts.provinces === 81 && demo.counts.districts === 973);
check('demo kişiler yüklenir', demo.counts.persons === 9);
check('demo işlem kayıtları yüklenir', demo.transactional > 9);

console.log('\n[3] v2 referans verisi üretimde de yüklenir (demo değil)');
check('7 bölge + 81 il eşlemesi', prod.counts.regions === 7 && prod.counts.provinces_mapped === 81);
// Tanımlar genişletilebilir olduğu için alt sınır kontrolü (bkz. test/migration.mjs).
check('tanım kategorileri ve kalemleri yüklendi (≥14 / ≥138)',
  prod.counts.lookup_categories >= 14 && prod.counts.lookup_items >= 138);
check('1068 teşkilat birimi', prod.counts.org_units === 1068);
check('68 takvim kaydı + 13 içerik bloğu',
  prod.counts.calendar_events === 68 && prod.counts.content_blocks === 13);

// ==========================================================================
// v2.1 — GİRİŞ HESABI POLİTİKASI (canlı bulgu: README'deki tohum şifreleri
// üretimde çalışıyordu). Üç mod tek tek doğrulanır.
// ==========================================================================
console.log('\n[4] Giriş hesabı modu — yerel geliştirme (varsayılan)');
const devEnv = { KK_ENV: 'development' };
const devSeed = await seedWithEnv('users-dev.db', devEnv);
check("mod 'dev'", devSeed.counts.seed_user_mode === 'dev', devSeed.counts.seed_user_mode);
check('yerelde iki tohum hesabı açılır (eski davranış korunur)', devSeed.counts.users === 2);
check('yerel tohum hesapları KİLİTLİ DEĞİL (npm test etkilenmez)',
  devSeed.db.prepare('SELECT COUNT(*) AS c FROM users WHERE must_change_password = 1').get().c === 0);
check('tohum saha hesabı Ankara/Çankaya kapsamıyla açılır', (() => {
  const u = devSeed.db.prepare("SELECT province_id, district_id FROM users WHERE email = 'saha@kizilay.org.tr'").get();
  const ank = devSeed.db.prepare("SELECT id, region_id FROM provinces WHERE name = 'Ankara'").get();
  const cnk = devSeed.db.prepare('SELECT id FROM districts WHERE province_id = ? AND name = ?').get(ank.id, 'Çankaya');
  return u.province_id === ank.id && u.district_id === cnk.id;
})());
check('tohum saha hesabının bölgesi ilden türetildi', (() => {
  const u = devSeed.db.prepare("SELECT region_id FROM users WHERE email = 'saha@kizilay.org.tr'").get();
  const ank = devSeed.db.prepare("SELECT region_id FROM provinces WHERE name = 'Ankara'").get();
  return u.region_id !== null && u.region_id === ank.region_id;
})());
check('yerelde uyarı basılmaz', devSeed.log === '');

console.log('\n[5] Giriş hesabı modu — üretim benzeri, değişken YOK');
for (const [label, env] of [
  ['NODE_ENV=production', { NODE_ENV: 'production' }],
  ['RENDER=true', { RENDER: 'true' }],
  ['KK_ENV=production', { KK_ENV: 'production' }],
]) {
  const p = await seedWithEnv(`users-none-${label.replace(/\W/g, '')}.db`, env);
  check(`${label} → hiçbir hesap oluşturulmaz`, p.counts.users === 0, `alınan: ${p.counts.users}`);
  check(`${label} → mod 'none'`, p.counts.seed_user_mode === 'none');
  check(`${label} → operatöre Türkçe uyarı basılır`,
    /HİÇBİR GİRİŞ HESABI OLUŞTURULMADI/.test(p.log)
    && /KK_SEED_ADMIN_EMAIL/.test(p.log) && /KK_SEED_ADMIN_PASSWORD/.test(p.log),
    p.log.slice(0, 120));
  check(`${label} → referans veri yine tam yüklenir (sistem çalışır durumda)`,
    p.counts.provinces === 81 && p.counts.districts === 973 && p.counts.org_units === 1068);
}
// Kaçış kapısı: KK_ENV=development her şeyin önüne geçer.
const escaped = await seedWithEnv('users-escape.db', { NODE_ENV: 'production', KK_ENV: 'development' });
check('KK_ENV=development üretim tespitini geçersiz kılar (yerel tekrar üretim için)',
  escaped.counts.seed_user_mode === 'dev' && escaped.counts.users === 2);

console.log('\n[6] Giriş hesabı modu — üretim benzeri, KK_SEED_ADMIN_* verilmiş');
const envSeed = await seedWithEnv('users-env.db', {
  NODE_ENV: 'production',
  KK_SEED_ADMIN_EMAIL: 'Yonetici@Kizilay.Org.Tr',
  KK_SEED_ADMIN_PASSWORD: 'CokGizli!2026',
  KK_SEED_ADMIN_NAME: 'İlk Yönetici',
});
check("mod 'env'", envSeed.counts.seed_user_mode === 'env', envSeed.counts.seed_user_mode);
check('YALNIZ bir hesap açılır (paylaşımlı saha hesabı üretilmez)', envSeed.counts.users === 1);
check('e-posta küçük harfe normalize edilir', (() => {
  const u = envSeed.db.prepare('SELECT email, name, role FROM users').get();
  return u.email === 'yonetici@kizilay.org.tr' && u.role === 'genel_merkez' && u.name === 'İlk Yönetici';
})());
check('hesap must_change_password = 0 ile açılır (tek yönetici kendi kendini kilitlemez)',
  envSeed.db.prepare('SELECT must_change_password AS m FROM users').get().m === 0);
check('bilinen tohum hesapları AÇILMAZ',
  envSeed.db.prepare("SELECT COUNT(*) AS c FROM users WHERE email IN ('admin@kizilay.org.tr','saha@kizilay.org.tr')").get().c === 0);
check('bu modda uyarı basılmaz', envSeed.log === '');

console.log('\n[7] Geçersiz tohum yapılandırması reddedilir (fail-fast)');
const badConfigs = [
  ['yalnız e-posta verilmiş', { KK_SEED_ADMIN_EMAIL: 'a@b.com' }, /birlikte verilmelidir/],
  ['yalnız şifre verilmiş', { KK_SEED_ADMIN_PASSWORD: 'Gecerli!2026' }, /birlikte verilmelidir/],
  ['e-posta biçimi bozuk', { KK_SEED_ADMIN_EMAIL: 'yonetici', KK_SEED_ADMIN_PASSWORD: 'Gecerli!2026' }, /geçerli bir e-posta değil/],
  ['şifre 8 karakterden kısa', { KK_SEED_ADMIN_EMAIL: 'a@b.com', KK_SEED_ADMIN_PASSWORD: 'kisa1' }, /en az 8 karakter/],
];
for (const [label, env, re] of badConfigs) {
  let message = null;
  try { resolveSeedUsers(env); } catch (e) { message = e.message; }
  check(`${label} → hata fırlatılır ve sebebi Türkçe açıklanır`,
    message !== null && re.test(message), String(message));
}

console.log('\n[8] KK_SEED_DEMO dolu veritabanında sessizce yutulmuyor');
const twiceDb = await createDb(path.join(dir, 'demo-twice.db'));
seedAll(twiceDb, { withDemo: true, env: devEnv, log: () => {} });
const firstCount = twiceDb.prepare('SELECT COUNT(*) AS c FROM persons').get().c;
const secondLogs = [];
seedAll(twiceDb, { withDemo: true, env: devEnv, log: (m) => secondLogs.push(String(m)) });
const secondLog = secondLogs.join('\n');
check('ilk çalıştırmada demo kişiler yüklendi', firstCount === 9, `alınan: ${firstCount}`);
check('ikinci çalıştırmada kayıt SAYISI DEĞİŞMEDİ (mükerrer demo yok)',
  twiceDb.prepare('SELECT COUNT(*) AS c FROM persons').get().c === firstCount);
check('atlandığı AÇIKÇA bildiriliyor (sessiz no-op değil)',
  /DEMO VERİSİ YÜKLENMEDİ/.test(secondLog), secondLog.slice(0, 120));
check('mesaj mevcut kayıt sayısını söylüyor', new RegExp(`${firstCount} kişi kaydı var`).test(secondLog));
check('mesaj sıfırlama yolunu gösteriyor (npm run db:reset)',
  /npm run db:reset/.test(secondLog) && /npm run start:demo/.test(secondLog));
const freshDemo = await seedWithEnv('demo-fresh.db', devEnv, { withDemo: true });
check('boş veritabanına demo yüklenirken bu mesaj basılmaz',
  !/DEMO VERİSİ YÜKLENMEDİ/.test(freshDemo.log) && freshDemo.counts.persons === 9,
  freshDemo.log.slice(0, 120));

rmSync(dir, { recursive: true, force: true });
console.log(`\n=== Tohum modu testi: ${pass} başarılı, ${fail} başarısız ===`);
process.exit(fail === 0 ? 0 : 1);
