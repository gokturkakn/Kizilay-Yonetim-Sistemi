# Kızılay Kadın — Teşkilat Yönetim Sistemi (MVP)

Genel merkez tarafından atanan gönüllülerin ve saha çalışmalarının yönetildiği,
raporlanabilir mobil uygulama. İki ana alan: **Yönetim Paneli** (koordinasyon kurulu,
6 komisyon, 81 il + 973 ilçe kadın teşkilatları, kişi kayıtları) ve **Saha Çalışmaları**
(görev formu, yönetsel faaliyetler/toplantılar, genel merkez görev atamaları).
Excel raporlama ve değişiklik günlüğü dahildir.

## Hızlı Başlangıç

### 1. Backend (Node.js + SQLite, port 4141)
```bash
cd backend
npm install
npm start
```
Sağlık kontrolü: `curl http://localhost:4141/health`

#### Tohum veri: referans veri ile demo veri ayrıdır
| Komut | Ne yükler |
|---|---|
| `npm start` / `npm run seed` | **Yalnız referans veri:** 81 il, 973 ilçe, koordinasyon kurulu + 6 komisyon, görev alanları, giriş kullanıcıları. Kişi kaydı **yüklenmez**. |
| `npm run start:demo` / `npm run seed:demo` | Referans veri **+ sahte** kişi, üyelik, faaliyet, toplantı, atama kayıtları (yalnız geliştirme/tanıtım için). |
| `npm run db:reset` | Test/işlem kayıtlarını siler (kişiler, üyelikler, faaliyetler, toplantılar, atamalar, günlük); **referans veriye dokunmaz**. Onay ister; betikte `-- --yes`. |

**Referans veri silinmez** — müşterinin "81 il ve ilçeler tanımlı olacak" gereksinimidir ve
üründe de gereklidir. Gerçek üye listesi Excel'den `POST /api/v1/persons/import` ile yüklenir.
Canlıya çıkmadan önce `npm run db:reset` çalıştırıp veritabanının kişi sayısının 0 olduğunu
doğrulayın.

### 2. Uygulama (Flutter)
```bash
cd app
flutter pub get
flutter run -d chrome          # geliştirme (web)
# veya üretim web derlemesi:
flutter build web && python3 -m http.server 5757 -d build/web
```
Android/iOS derlemesi için ilgili SDK'lar kurulduktan sonra `flutter build apk` /
`flutter build ipa` kullanılır; kod tabanı üç platformu da hedefler.

API adresi `app/lib/core/config.dart` içinde; farklı sunucu için
`--dart-define=API_BASE_URL=...` verilebilir.

### 3. Giriş Bilgileri (tohum kullanıcılar — üründe değiştirin)
| Rol | E-posta | Şifre |
|---|---|---|
| Genel Merkez | admin@kizilay.org.tr | Admin!2026 |
| Saha | saha@kizilay.org.tr | Saha!2026 |

## Belgeler
- [docs/SPEC.md](docs/SPEC.md) — v1 ürün kapsamı
- [docs/SPEC-V2.md](docs/SPEC-V2.md) — **v2 kapsamı ve mimari kararlar (K1–K6)**
- [docs/API.md](docs/API.md) — v1 REST sözleşmesi (tüm uçları çalışmaya devam eder)
- [docs/API-V2.md](docs/API-V2.md) — **v2 REST sözleşmesi (bağlayıcı; çelişkide bu geçerlidir)**
- [docs/UX.md](docs/UX.md) — ekran ve tasarım rehberi
- [docs/BACKLOG.md](docs/BACKLOG.md) — sprint durumu
- [evidence/](evidence) — QA kanıt raporları

## Üretime Çıkış Notları
- `npm run db:reset` ile demo/test kayıtlarını temizleyin; `/health` çıktısında kişi
  sayısının 0 olduğunu doğrulayın. `KK_SEED_DEMO` **ayarlanmamış** olmalı.
- `KK_JWT_SECRET` ortam değişkenini mutlaka değiştirin.
- SQLite dosyası `backend/data/app.db`; yedekleyin. PostgreSQL'e geçiş şeması uyumludur.
- Gerçek teşkilat üyeleri Excel'den `POST /api/v1/persons/import` ile toplu yüklenebilir.
- Görev alanları listesi (`task-areas`) genel merkez rolüyle genişletilebilir.
- Açık üretim engelleri için [evidence/REALITY-CHECK.md](evidence/REALITY-CHECK.md) §5'e bakın
  (sürüm kontrolü, mobil derleme, KVKK, yetkilendirme kapsamı).

## Testler
```bash
cd backend && npm test        # 9 tohum modu + 51 duman testi (API uçtan uca)
cd app && flutter test        # 16 birim/widget testi
```
