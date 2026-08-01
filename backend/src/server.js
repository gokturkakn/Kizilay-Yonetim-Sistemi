import { PORT, DB_PATH } from './config.js';
import { getDb } from './db.js';
import { seedAll } from './seed.js';
import { createApp } from './app.js';

// Şema göçleri açılışta otomatik uygulanır. Bir göç patlarsa süreç burada durur (fail-fast):
// yarım şemayla servis vermektense hiç açılmamak doğrudur.
const db = await getDb();
// Referans veri (il/ilçe, bölgeler, tanımlar, teşkilat birimleri, takvim, içerik, kullanıcılar)
// her açılışta güvence altına alınır; idempotenttir. Sahte kayıtlar yalnızca KK_SEED_DEMO=1 ile.
const counts = seedAll(db, { withDemo: process.env.KK_SEED_DEMO === '1' });

const app = createApp(db);
app.listen(PORT, () => {
  console.log(`Teşkilat Yönetim Sistemi API → http://localhost:${PORT}/api/v1 (db: ${DB_PATH})`);
  console.log('Tohum veri:', JSON.stringify(counts));
});
