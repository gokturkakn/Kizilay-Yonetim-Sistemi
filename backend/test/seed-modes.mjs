// Üretim tohumlaması ile demo tohumlamasının kesin olarak ayrıldığını doğrular.
// Amaç: canlıya çıkarken sahte kişi/faaliyet kayıtlarının veritabanına sızmaması.
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';

let pass = 0;
let fail = 0;
const check = (label, ok) => {
  console.log(`  ${ok ? '✓' : '✗'} ${label}`);
  ok ? pass++ : fail++;
};

const dir = mkdtempSync(path.join(tmpdir(), 'kk-seed-'));

async function seedInto(dbFile, withDemo) {
  process.env.KK_DB_PATH = path.join(dir, dbFile);
  const { getDb } = await import(`../src/db.js?v=${dbFile}`);
  const { seedAll } = await import(`../src/seed.js?v=${dbFile}`);
  const db = await getDb();
  const counts = seedAll(db, { withDemo });
  const transactional = ['persons', 'memberships', 'field_activities', 'meetings', 'assignments',
    'tasks', 'trainings', 'events', 'org_assignments', 'material_requests', 'shipments', 'attachments',
    'documents']
    .map((t) => db.prepare(`SELECT COUNT(*) AS c FROM ${t}`).get().c)
    .reduce((a, b) => a + b, 0);
  return { counts, transactional };
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

rmSync(dir, { recursive: true, force: true });
console.log(`\n=== Tohum modu testi: ${pass} başarılı, ${fail} başarısız ===`);
process.exit(fail === 0 ? 0 : 1);
