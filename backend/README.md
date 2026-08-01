# Teşkilat Yönetim Sistemi — Backend (MVP)

Node.js + Express + SQLite (better-sqlite3). API sözleşmesi: `../docs/API.md`.

## Çalıştırma

```bash
cd backend
npm install
npm start          # http://localhost:4141 — boş DB'de tohum veri otomatik yüklenir
npm run seed       # tohum veriyi elle yükler (idempotent)
npm test           # duman testi: geçici DB ile tüm uçları uçtan uca doğrular
```

Ortam değişkenleri: `PORT` (vars. 4141), `KK_DB_PATH` (vars. `data/app.db`),
`KK_JWT_SECRET` (üretimde mutlaka değiştirin).

## Tohum kullanıcılar
- `admin@kizilay.org.tr` / `Admin!2026` — rol: `genel_merkez`
- `saha@kizilay.org.tr` / `Saha!2026` — rol: `saha`

## Veri
- `data/turkey-provinces-districts.json`: 81 il (plaka 1–81) ve 973 gerçek ilçe
  (`turkey-neighbourhoods` npm paketinin veri setinden türetildi, depoya gömüldü).
- Demo kişiler bariz sahte ama TC sağlama kuralını geçen numaralar kullanır
  (999… tabanından `src/tc.js` ile üretilir).

## Yapı
- `src/server.js` — giriş noktası (4141), açılışta idempotent tohumlama
- `src/app.js` — Express uygulaması, merkezi hata gövdesi `{error:{code,message}}`
- `src/db.js` — şema; `src/seed.js` — tohum veri; `src/tc.js` — TC doğrulama
- `src/routes/*` — sözleşmedeki uçlar; `src/audit.js` — değişiklik günlüğü yardımcı
- `test/smoke.mjs` — framework'süz duman testi
