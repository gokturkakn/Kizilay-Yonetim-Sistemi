import { PORT, DB_PATH, IS_PRODUCTION_LIKE, startupConfigError } from './config.js';
import { getDb } from './db.js';
import { seedAll } from './seed.js';
import { createApp } from './app.js';

// ÜRETİM GÜVENLİK KONTROLÜ — her şeyden önce (veritabanı bile açılmadan).
// Üretim benzeri ortamda KK_JWT_SECRET yoksa/zayıfsa sunucu AÇILMAZ (denetim BLOKE-5).
const configError = startupConfigError();
if (configError) {
  console.error(configError);
  process.exit(1);
}

// Şema göçleri açılışta otomatik uygulanır. Bir göç patlarsa süreç burada durur (fail-fast):
// yarım şemayla servis vermektense hiç açılmamak doğrudur.
const db = await getDb();
// Referans veri (il/ilçe, bölgeler, tanımlar, teşkilat birimleri, takvim, içerik, kullanıcılar)
// her açılışta güvence altına alınır; idempotenttir. Sahte kayıtlar yalnızca KK_SEED_DEMO=1 ile.
// Giriş hesabı politikası ortama göre değişir (bkz. src/seed.js — env / none / dev).
let counts;
try {
  counts = seedAll(db, { withDemo: process.env.KK_SEED_DEMO === '1' });
} catch (e) {
  console.error(`\n  SUNUCU BAŞLATILAMADI — TOHUM YAPILANDIRMASI GEÇERSİZ\n  ${e.message}\n`);
  process.exit(1);
}

const app = createApp(db);
app.listen(PORT, () => {
  console.log(`Teşkilat Yönetim Sistemi API → http://localhost:${PORT}/api/v1 (db: ${DB_PATH})`);
  console.log(`Ortam: ${IS_PRODUCTION_LIKE ? 'üretim benzeri' : 'geliştirme'} · `
    + `giriş hesabı modu: ${counts.seed_user_mode}`);
  console.log('Tohum veri:', JSON.stringify(counts));
});
