import { getDb } from './db.js';
import { seedAll } from './seed.js';

// Demo veri yalnızca açıkça istendiğinde yüklenir:
//   npm run seed        → sadece referans veri (81 il, komisyonlar, görev alanları, kullanıcılar)
//   npm run seed:demo   → referans veri + sahte kişi/faaliyet/toplantı kayıtları (geliştirme)
const withDemo = process.argv.includes('--demo') || process.env.KK_SEED_DEMO === '1';

let counts;
try {
  counts = seedAll(await getDb(), { withDemo });
} catch (e) {
  console.error(`\n  TOHUMLAMA BAŞARISIZ — YAPILANDIRMA GEÇERSİZ\n  ${e.message}\n`);
  process.exit(1);
}
console.log(withDemo ? 'Tohum veri hazır (demo dahil):' : 'Tohum veri hazır (yalnız referans veri):',
  JSON.stringify(counts));
