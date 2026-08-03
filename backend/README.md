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

Ortam değişkenlerinin tam listesi ve açıklamaları `.env.example` içindedir.
En önemlileri: `PORT` (vars. 4141), `KK_DB_PATH` (vars. `data/app.db`),
`KK_JWT_SECRET`, `KK_SEED_ADMIN_EMAIL` / `KK_SEED_ADMIN_PASSWORD`.

## Giriş hesapları — ortama göre değişir

Ortam **üretim benzeri** sayılırsa (`NODE_ENV=production`, `RENDER` tanımlı ya da
`KK_ENV=production`) iki koruma birden devreye girer:

1. `KK_JWT_SECRET` yoksa ya da 32 karakterden kısaysa **sunucu açılmaz** (fail-fast).
2. `KK_SEED_ADMIN_EMAIL` + `KK_SEED_ADMIN_PASSWORD` yoksa **hiçbir hesap oluşturulmaz**;
   konsola ilk yöneticinin nasıl açılacağını anlatan Türkçe uyarı basılır.

| Ortam | Oluşturulan hesaplar |
|---|---|
| Yerel geliştirme (varsayılan) | `admin@kizilay.org.tr` / `Admin!2026` · `saha@kizilay.org.tr` / `Saha!2026` — **yalnız geliştirme içindir** |
| Üretim benzeri + `KK_SEED_ADMIN_*` | Verilen e-posta ile tek `genel_merkez` hesabı, `must_change_password = 1` |
| Üretim benzeri, değişken yok | **Yok** (uyarı basılır) |

`must_change_password` açıkken API `GET /auth/me` ve `POST /auth/change-password`
dışındaki her isteği `403 PASSWORD_CHANGE_REQUIRED` ile reddeder.

Geliştirme tohum hesabı `saha@kizilay.org.tr` Ankara / Çankaya kapsamıyla açılır;
dokümanlardaki `?applicable_to=district:<id>` görünümü temiz kurulumda denenebilsin diye.

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
- `src/loginRateLimit.js` — giriş hız sınırlama (bellek içi, tek süreç)
- `src/config.js` — ortam tespiti + açılış güvenlik kontrolü (fail-fast)
- `test/migration.mjs` · `test/seed-modes.mjs` · `test/smoke.mjs` · `test/security.mjs`
  — framework'süz test paketleri (`npm test` dördünü sırayla çalıştırır)
