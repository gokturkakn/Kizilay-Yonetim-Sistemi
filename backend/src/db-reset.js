/**
 * Test/demo kayıtlarını temizler — teşkilat omurgasına DOKUNMAZ.
 *
 * Silinenler : kişiler, üyelikler, saha faaliyetleri, toplantılar, görev atamaları,
 *              değişiklik günlüğü (yani üretimde Excel'den gelecek olan tüm işlem verisi).
 * Korunanlar : 81 il + ilçeler, koordinasyon kurulu + komisyonlar, görev alanları, kullanıcılar.
 *
 * Kullanım:
 *   npm run db:reset            → onay ister (ne silineceğini gösterir)
 *   npm run db:reset -- --yes   → onaysız çalışır (betiklerde kullanmak için)
 */
import readline from 'node:readline/promises';
import { stdin, stdout } from 'node:process';
import { getDb } from './db.js';
import { DB_PATH } from './config.js';

const TRANSACTIONAL_TABLES = [
  'audit_logs',
  'attachments',
  'documents',
  'stock_movements',
  'shipments',
  'material_requests',
  'events',
  'trainings',
  'tasks',
  'org_assignments',
  'assignments',
  'meetings',
  'field_activities',
  'memberships',
  'persons',
];

const db = await getDb();

const counts = Object.fromEntries(
  TRANSACTIONAL_TABLES.map((t) => [t, db.prepare(`SELECT COUNT(*) AS c FROM ${t}`).get().c])
);
const toDelete = Object.values(counts).reduce((a, b) => a + b, 0);

console.log(`Veritabanı: ${DB_PATH}`);
console.log('Silinecek kayıtlar:');
for (const [table, c] of Object.entries(counts)) console.log(`  ${table.padEnd(18)} ${c}`);
console.log(`  ${'TOPLAM'.padEnd(18)} ${toDelete}`);
console.log('Korunacak: iller, ilçeler, bölgeler, tanımlar, teşkilat birimleri, takvim, içerik, kullanıcılar.');

if (toDelete === 0) {
  console.log('\nSilinecek kayıt yok. Veritabanı zaten temiz.');
  process.exit(0);
}

const approved = process.argv.includes('--yes') || process.argv.includes('-y');
if (!approved) {
  const rl = readline.createInterface({ input: stdin, output: stdout });
  const answer = await rl.question('\nDevam edilsin mi? (evet/hayır): ');
  rl.close();
  if (!['evet', 'e', 'yes', 'y'].includes(answer.trim().toLowerCase())) {
    console.log('İptal edildi. Hiçbir kayıt silinmedi.');
    process.exit(1);
  }
}

db.transaction(() => {
  for (const table of TRANSACTIONAL_TABLES) db.prepare(`DELETE FROM ${table}`).run();
  // AUTOINCREMENT sayaçlarını da sıfırla ki gerçek veri 1'den başlasın.
  const seq = db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name='sqlite_sequence'").get();
  if (seq) {
    for (const table of TRANSACTIONAL_TABLES) {
      db.prepare('DELETE FROM sqlite_sequence WHERE name = ?').run(table);
    }
  }
})();

const remaining = {
  iller: db.prepare('SELECT COUNT(*) AS c FROM provinces').get().c,
  ilceler: db.prepare('SELECT COUNT(*) AS c FROM districts').get().c,
  kurul_komisyon: db.prepare('SELECT COUNT(*) AS c FROM bodies').get().c,
  gorev_alanlari: db.prepare('SELECT COUNT(*) AS c FROM task_areas').get().c,
  kullanicilar: db.prepare('SELECT COUNT(*) AS c FROM users').get().c,
  kisiler: db.prepare('SELECT COUNT(*) AS c FROM persons').get().c,
  bolgeler: db.prepare('SELECT COUNT(*) AS c FROM regions').get().c,
  tanim_kalemleri: db.prepare('SELECT COUNT(*) AS c FROM lookup_items').get().c,
  teskilat_birimleri: db.prepare('SELECT COUNT(*) AS c FROM org_units').get().c,
  takvim: db.prepare('SELECT COUNT(*) AS c FROM calendar_events').get().c,
};
// Teşkilat birimleri görevlendirmesiz kaldığı için boşluk durumuna geri döner.
db.prepare("UPDATE org_units SET status = 'teskilat_yok' WHERE type IN ('bolge_temsilciligi','il_baskanligi','ilce_baskanligi','temsilcilik')").run();
console.log(`\n${toDelete} kayıt silindi. Kalan referans veri:`, JSON.stringify(remaining));
