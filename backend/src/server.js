import { PORT, DB_PATH } from './config.js';
import { getDb } from './db.js';
import { seedAll } from './seed.js';
import { createApp } from './app.js';

const db = getDb();
// Referans veri (il/ilçe, komisyonlar, görev alanları, kullanıcılar) her açılışta güvence altına
// alınır; idempotenttir. Sahte kişi/faaliyet kayıtları yalnızca KK_SEED_DEMO=1 ile yüklenir.
const counts = seedAll(db, { withDemo: process.env.KK_SEED_DEMO === '1' });

const app = createApp(db);
app.listen(PORT, () => {
  console.log(`Teşkilat Yönetim Sistemi API → http://localhost:${PORT}/api/v1 (db: ${DB_PATH})`);
  console.log('Tohum veri:', JSON.stringify(counts));
});
