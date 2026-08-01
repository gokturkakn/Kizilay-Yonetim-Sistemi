# Gerçeklik Denetimi — Teşkilat Yönetim Sistemi MVP

**Tarih:** 2026-08-01 · **Yürüten:** Reality Checker (bağımsız denetim) · **Sürüm:** MVP 0.1

**Yöntem:** Önceki ajanların (backend, frontend, QA) raporları *iddia* kabul edilmiş, hiçbiri
kanıt sayılmamıştır. Tüm testler bu denetim sırasında yeniden çalıştırılmış, backend ayrı bir
geçici veritabanıyla ayağa kaldırılıp 17 ayrı uç nokta probu yapılmış, SPEC.md satır satır
koda kadar izlenmiştir.

**KARAR: NEEDS WORK** — Üretime çıkış için 6 bloke edici madde var. Ayrıntı §5–6.

---

## 1. Bağımsız Olarak Yeniden Çalıştırılan Testler

Üç test paketi de **iddia edildiği gibi geçti**. Bu bölümdeki sonuçlar bu denetimde
bizzat çalıştırılmıştır.

| Komut | İddia | Bu denetimde alınan sonuç | Durum |
|---|---|---|---|
| `cd backend && npm test` | 46/46 | `=== Duman testi sonucu: 46 başarılı, 0 başarısız ===` | ✅ DOĞRULANDI |
| `flutter analyze` | temiz | `No issues found! (ran in 1.9s)` | ✅ DOĞRULANDI |
| `flutter test` | 16 test | `00:01 +16: All tests passed!` | ✅ DOĞRULANDI |
| `flutter build web` | başarılı | `✓ Built build/web` (25.1 s) | ✅ DOĞRULANDI |

**Ancak testlerin geçmesi gereksinimin karşılandığını kanıtlamaz.** Duman testinin
**kapsamadığı** uçlar (46 kontrolün hiçbiri bunlara dokunmuyor):

- `POST /persons/import` — EVIDENCE.md §3 "uç nokta backend duman testinde doğrulandı"
  diyor; **bu iddia yanlıştır**, smoke.mjs bu ucu hiç çağırmıyor. (Ucu elle test ettim,
  §4 PROBE-9b: gerçekten çalışıyor — yani iddia doğru çıktı ama gösterilen kanıt sahteydi.)
- `POST /commissions`, `POST /task-areas` — SPEC'in açık "genişletilebilirlik" gereksinimi, test yok
- `DELETE /memberships/:id`, `DELETE /field-activities/:id`, `DELETE /meetings/:id`
- `PATCH /memberships/:id/active`, `POST /bodies/:id/members`
- `PUT /field-activities/:id`, `PUT /meetings/:id`, `PUT /assignments/:id`
- 4 Excel raporundan yalnız `persons.xlsx` test ediliyor; diğer 3'ü test edilmiyor
- **`is_active` alanının POST/PUT'ta gerçekten yazılıp yazılmadığı** (→ BLOKE-2, gerçek hata)

**README tutarsızlığı:** README.md satır 56 `flutter test` için "12 birim/widget testi"
diyor; gerçek sayı 16.

---

## 2. SPEC İzlenebilirlik Matrisi

Müşterinin birebir istekleri (görev tanımındaki liste) + SPEC.md tüm maddeleri.

### 2.1 Müşterinin literal istekleri

| # | Müşteri isteği | Kanıt (kod/uç nokta/ekran) | Durum |
|---|---|---|---|
| 1 | Kişi alanları: ad, soyad | `persons.first_name/last_name` · `person_form_screen.dart:294-311` | ✅ TAM |
| 2 | il/ilçe/temsilcilik | `unit_type` CHECK(`il_teskilati\|ilce_teskilati\|temsilcilik`) `db.js:56` · form dropdown | ✅ TAM |
| 3 | doğum tarihi | `birth_date` NOT NULL · `_pickBirthDate` tarih seçici | ✅ TAM |
| 4 | TC kimlik (11 hane, doğrulamalı) | `tc.js:8-18` gerçek checksum · UNIQUE · PROBE-2 doğruladı | ✅ TAM |
| 5 | telefon | `phone` NOT NULL · maske `0(5XX) XXX XX XX` | ✅ TAM |
| 6 | e-posta | `email` + `EMAIL_RE` doğrulama | ✅ TAM |
| 7 | meslek | `profession` | ✅ TAM |
| 8 | **aktif/pasif (tik)** | Kişi Formu'ndaki tik **backend tarafından yok sayılıyor** (PROBE-2/3) | ❌ **BOZUK** |
| 9 | Aktif/pasifte kalanların panel genelinde görülebilmesi | 3 liste ekranında filtre + `PersonListTile` durum rozeti | ⚠️ KISMİ |
| 10 | Excel raporlama | 4 rapor, gerçek Türkçe başlıklı .xlsx (PROBE-7) — **ama mobilde dosyaya erişilemiyor** | ⚠️ KISMİ |
| 11 | Düzenli değişiklik kaydı (audit) | `audit.js` + 5 varlıkta create/update/delete/toggle | ⚠️ KISMİ |
| 12 | Saha görev formu: görev alanı | `field_activities.task_area_id` → `task_areas` | ✅ TAM |
| 13 | … tarih | `activity_date` + `validDate` | ✅ TAM |
| 14 | … gönüllü sayısı | `volunteer_count` CHECK(>=0) | ✅ TAM |
| 15 | … yararlanıcı sayısı | `beneficiary_count` CHECK(>=0) | ✅ TAM |
| 16 | Yönetsel: kurul tarih/karar/sonuç | `meetings.meeting_date/decision/outcome` · `meeting_form_screen.dart` | ✅ TAM |
| 17 | Yönetsel: komisyonlar için aynısı | `meetings.body_id` → `bodies` (1 kurul + 6 komisyon) | ✅ TAM |
| 18 | Genel merkez atamalarının **tüm kayıtlı isimler için** görülebilmesi | `GET /assignments` rol kısıtı yok; `assignment_list_screen.dart` her iki role açık | ⚠️ YORUM RİSKİ |
| 19 | **Genişletilebilirlik** (görev alanı + komisyon sonradan eklenebilmeli) | API'de var (PROBE-11: 201/201); **uygulamada ekran/istemci metodu YOK** | ❌ **EKSİK** |

### 2.2 SPEC.md madde madde

| SPEC | Gereksinim | Kanıt | Durum |
|---|---|---|---|
| §2.1.1 | Koordinasyon Kurulu üye listesi | `bodies` type=koordinasyon_kurulu · `body_members_screen.dart` | ✅ |
| §2.1.2 | 6 komisyon (tohum) | `seed.js:7-14` — 6 ad birebir SPEC ile aynı | ✅ |
| §2.1.2 | Komisyonlar genişletilebilir | `POST /commissions` var, **UI yok** | ❌ |
| §2.1.3 | 81 il + ilçeleri tohum | `/health` → `{provinces:81, districts:973}` | ✅ |
| §2.1.3 | Excel'den toplu aktarım altyapısı | `POST /persons/import` gerçekten çalışıyor (PROBE-9b) | ✅ |
| §2.1 | Tüm listeler Excel raporlanabilir | 4 rapor var; **kişi raporu filtre uygulamıyor** (§3'e bkz.) | ⚠️ |
| §2.1 | **Tüm** değişiklikler audit log'a | komisyon/görev alanı ekleme audit'e **yazılmıyor** (PROBE-11) | ⚠️ |
| §2.2.a | Görev formu 4 zorunlu alan | tamamı mevcut + opsiyonel il/ilçe/açıklama | ✅ |
| §2.2.b | Şema genişletilebilir | `notes`, nullable il/ilçe; PostgreSQL uyumlu şema | ✅ |
| §2.2.c | Atama listesi (kişi, başlık, tarih, durum) | `assignments` 4 alan + `STATUS_TR` rozetleri | ✅ |
| §3 | Roller: genel_merkez / saha | `requireRole` middleware, 403'ler testlerde doğrulandı | ✅ |
| §3 | E-posta+şifre, JWT | bcrypt (cost 10) + HS256, 12 s ömür | ✅ |
| §4 | Değişiklik günlüğü **(kim/**ne zaman/ne değişti) | "ne zaman" ve "ne değişti" ✅; **"kim" ham sayısal ID olarak görünüyor** | ❌ **BOZUK** |
| §5 | Flutter, Android+iOS hedefli | Kod tabanı üç platformu hedefliyor; **hiçbir mağaza derlemesi doğrulanmadı** | ⚠️ |
| §5 | Node+Express+SQLite, exceljs, port 4141 | Birebir uyumlu | ✅ |
| §5 | Tüm ekran metinleri Türkçe | `strings.dart` + tüm ekranlar Türkçe | ✅ |

---

## 3. Fantezi Probu (stub / sahte / ölü kod araması)

**Genel sonuç: kod tabanı büyük ölçüde dürüst.** Aranan ve **bulunamayan**ler:

- `TODO` / `FIXME` / `HACK` / `mock` / `dummy` / `placeholder` işaretleri: **0 adet**
- Boş `catch {}` blokları: **0 adet** (tüm catch'lerde ya kullanıcıya mesaj ya açıklayıcı yorum)
- Sabit kodlanmış (canned) cevap döndüren uç nokta: **0 adet** — tüm uçlar gerçek SQL çalıştırıyor
- API çağırmayan ekran: **0 adet**
- Excel raporları gerçek mi? **Evet** — PROBE-7 .xlsx'i açıp içeriğini okudu:
  başlıklar `Ad, Soyad, TC Kimlik No, Doğum Tarihi, Telefon, E-posta, Meslek, Birim Türü,
  İl, İlçe, Durum, Kayıt Tarihi`, altında gerçek kişi satırları. Sahte değil.
- TC checksum gerçek mi? **Evet** — `tc.js` standart algoritmayı doğru uyguluyor; denetim
  sırasında geçersiz ürettiğim `99900099178` numarası doğru şekilde reddedildi.

**Ama 3 gerçek "sessiz yalan" bulundu:**

### FANTEZİ-1 — Kişi Formu'ndaki "Aktif" tiki hiçbir şey yapmıyor *(BLOKE)*

`person_form_screen.dart:171` gövdeye `'is_active': _isActive` koyuyor.
Backend `persons.js:121` INSERT'te `is_active`'i **sabit 1** yazıyor; `validatePersonPayload`
(satır 58-69) `is_active`'i hiç döndürmüyor, PUT'un UPDATE cümlesinde (satır 133-138)
`is_active` **hiç yer almıyor**.

```
PROBE-2  POST /persons  {... "is_active": false}  → HTTP 201, cevap: "is_active": 1
PROBE-3  PUT /persons/10 {... "is_active": false} → HTTP 200, cevap: "is_active": 1
PROBE-4  PATCH /persons/10/active {"is_active":false} → "is_active": 0   ← tek çalışan yol
```

**Etki:** Kullanıcı formda tiki kapatıp kaydediyor, uygulama *"Kişi kaydedildi."* diyor,
kişi aktif kalmaya devam ediyor. Hata mesajı yok, geri bildirim yok. Müşterinin birebir
istediği "aktif/pasif (tik)" alanı formda ölü kontrol. (Kişi Detay ekranındaki ayrı
aç/kapa düğmesi `setPersonActive` ile doğru çalışıyor — yani özellik tamamen yok değil,
ama formdaki hâli sessizce yanıltıyor.)

### FANTEZİ-2 — Değişiklik günlüğünde "kim" yok, ham kullanıcı ID'si var *(BLOKE)*

SPEC §4 birebir: *"Değişiklik günlüğü ekranı (kim/ne zaman/ne değişti)"*.
Raporlar ekranı da kullanıcıya *"Kim, ne zaman, neyi değiştirdi"* vaat ediyor
(`reports_screen.dart:109`).

Backend `auditLogs.js:5` yalnız `changed_by` (INTEGER) seçiyor, `users` tablosuna **JOIN yok**.
Frontend `models.dart:328` önce `changed_by_name` arıyor — **API böyle bir alan hiç döndürmüyor** —
sonra ham `changed_by`'a düşüyor. `audit_log_screen.dart:350` bunu doğrudan basıyor.

```
PROBE-5  GET /audit-logs → {"changed_by": 1, ...}      (isim yok, JOIN yok)
Ekranda görünen satır:  "1 · Güncelleme — Kişiler"
```

İlginç şekilde aynı `users` JOIN'i Excel raporlarında **yapılmış**
(`exports.js:98,128,157` → "Kaydı Giren"/"Atayan" sütunları isim gösteriyor).
Yani ekip nasıl yapılacağını biliyor; audit ucunda atlanmış.

**Not:** PROBE-5 ayrıca boş diff'li audit kaydı üretilebildiğini gösterdi
(`"action":"update", "changes":{}`) — hiçbir şey değişmeyen bir PUT bile günlüğe
içeriksiz "Güncelleme" satırı yazıyor.

### FANTEZİ-3 — Mobilde "Rapor indirildi." mesajı yanıltıcı *(BLOKE)*

`file_saver_io.dart:5-11` (Android/iOS/masaüstü yolu) dosyayı `Directory.systemTemp`'e
yazıyor. `_tryOpen` yalnız macOS/Linux/Windows'ta dosyayı açıyor; **Android ve iOS için
hiçbir şey yapmıyor** — kodun kendi yorumu bunu itiraf ediyor (satır 22-23):
*"Android/iOS: MVP'de dosya geçici dizine kaydedilir; açma işlemi sonraki sürümde platform
kanalı/eklenti ile yapılacak."*

`reports_screen.dart:47` ise koşulsuz *"Rapor indirildi."* snackbar'ı gösteriyor.

**Etki:** Bu bir **mobil öncelikli uygulama** (SPEC §1). Hedef platformda kullanıcı
"Excel raporlama" düğmesine basıyor, "indirildi" yazısını görüyor, ama dosya uygulamanın
özel geçici dizininde erişilemez halde duruyor — paylaşım sayfası, "Dosyalar"a kaydetme
veya açma yok. Müşterinin birebir istediği "Excel raporlama" özelliği **gerçek hedef
platformda kullanılamaz durumda** ve bu makinede SDK olmadığı için hiç test edilmemiş.

**Ek eksik:** `exportXlsx(name)` hiçbir sorgu parametresi göndermiyor
(`api.dart:217`, tek çağrısı `reports_screen.dart:45`). SPEC §4 "kişiler **(filtreli)**"
diyor ve backend filtreleri destekliyor (`exports.js:39-52`), ama arayüzde filtreli rapor
almanın **hiçbir yolu yok** — her zaman tüm kişiler iniyor.

---

## 4. Uç Nokta Probları (bu denetimde çalıştırıldı)

Backend `KK_DB_PATH` ile ayrı geçici veritabanına yönlendirilip 4141'de başlatıldı
(projenin `app.db`'si kirletilmedi). Tohumlama sıfırdan doğru çalıştı:
`{"users":2,"provinces":81,"districts":973,"commissions":6,"bodies":7,"task_areas":7,"persons":9}`

| # | Prob | Sonuç |
|---|---|---|
| 1 | JWT içeriği | `{id,name,email,role,iat,exp}` — 12 s ömür, `jti` yok, iptal mekanizması yok |
| 2 | `POST /persons` + `is_active:false` | ❌ sessizce yok sayıldı (FANTEZİ-1) |
| 3 | `PUT /persons/:id` + `is_active:false` | ❌ sessizce yok sayıldı (FANTEZİ-1) |
| 4 | `PATCH /persons/:id/active` | ✅ çalışıyor |
| 5 | `GET /audit-logs` | ⚠️ `changed_by:1` — isim yok (FANTEZİ-2) |
| 6 | Türkçe arama | ❌ `q=Ayşe`→1, `q=ayşe`→1, **`q=AYŞE`→0** |
| 7 | `GET /export/persons.xlsx` | ✅ 7817 bayt, gerçek Türkçe başlıklar + gerçek veri |
| 8 | `GET /api/v1/health` | ⚠️ HTTP 404 (yalnız kök `/health` çalışıyor — API.md taban URL'i ile çelişiyor) |
| 9b | `POST /persons/import` | ✅ `{"imported":1,"errors":[satır bazlı 2 hata]}` — ilçe çözümü doğru |
| 10 | **saha rolü başkasının kaydını düzenliyor** | ❌ `PUT /field-activities/4` (admin'in kaydı) → **HTTP 200**, not alanı üzerine yazıldı; `PUT /meetings/1` → **HTTP 200** |
| 11 | `POST /task-areas` / `POST /commissions` | ✅ 201/201 — ama **audit log'a yazılmıyor**, UI yok |
| 12 | N+1 gecikmesi | `GET /persons/:id` ≈ 1.0 ms (yerel) — 200 atama ≈ 0.2 s yerelde, mobil şebekede kat kat fazla |
| 13 | 5011 kişiyle ölçek | liste 2.5 ms · arama 2.8 ms · **Excel 275 ms / 220 KB** — backend performansı **iyi** |
| 14 | Liste kırpılması | `limit=500` → 500 döndü, `total:5011` → **4511 kayıt sessizce görünmüyor** |
| 15 | Kaba kuvvet (brute force) | 25 ardışık hatalı giriş → hepsi 401, **429 yok**, gecikme yok, kilitleme yok |
| 16 | CORS | `Access-Control-Allow-Origin: *` — herhangi bir site tarayıcıdan API'ye erişebilir |
| 17 | Güvenlik başlıkları | HSTS / X-Frame-Options / X-Content-Type-Options / CSP — **hiçbiri yok** |

---

## 5. Risk Listesi (şiddete göre sıralı)

### 🔴 BLOKE EDİCİ

**BLOKE-1 — Proje sürüm kontrolünde DEĞİL. Tek commit bile yok.**
```
$ git rev-parse --show-toplevel  → /Users/grravitie/Downloads/Kızılay
$ git log                        → fatal: your current branch 'main' does not have any commits yet
$ git ls-files | wc -l           → 0
```
Backend, uygulama, dokümanlar, kanıtlar — **hepsi izlenmeyen çalışma ağacında**.
Sonuçları: geri alma yok, sürüm etiketi yok, dağıtılabilir bir kaynak yok, iki kişi
aynı anda çalışamaz. Dahası **`backend/data/turkey-provinces-districts.json` (19,5 KB,
81 il / 973 ilçe tohum kaynağı) hiçbir yerde saklı değil** — bu makinedeki tek kopya.
Bu dosya kaybolursa sistemin tüm referans veri temeli kaybolur ve `seed.js:70` ENOENT ile
patlar. Tek bir `rm -rf` tüm teslimatı yok eder.

**BLOKE-2 — Kişi Formu'ndaki aktif/pasif tiki sessizce çalışmıyor** (FANTEZİ-1).
Müşterinin birebir istediği alan; kullanıcı yanlış geri bildirim alıyor.

**BLOKE-3 — Değişiklik günlüğü "kim" sorusunu cevaplamıyor** (FANTEZİ-2).
SPEC §4'ün birebir gereksinimi. Denetim izinin varlık sebebi bu; ham `1` sayısı
denetlenebilirlik sağlamaz. (Düzeltme küçük: `auditLogs.js`'e `users` JOIN'i + `changed_by_name`.)

**BLOKE-4 — Excel raporlama mobilde kullanılamıyor** (FANTEZİ-3).
Mobil öncelikli bir üründe, müşterinin birebir istediği özellik hedef platformda çalışmıyor
ve arayüz aksini iddia ediyor. Ayrıca filtreli rapor alma yolu yok (SPEC §4 "filtreli").

**BLOKE-5 — Varsayılan JWT gizli anahtarı ile üretime çıkma riski.**
`config.js:11` → `process.env.KK_JWT_SECRET || 'kizilay-kadin-mvp-dev-secret'`.
Bu değer README'de ve depoda açıkta. Ortam değişkeni **unutulursa uygulama sessizce
çalışmaya devam eder** ve herkes kendi admin token'ını imzalayabilir. Üretimde eksik
değişkende başlangıçta hata verip durmalı (fail-fast), sessizce varsayılana düşmemeli.
Aynı şekilde tohum şifreler (`Admin!2026` / `Saha!2026`) README'de yayınlanmış durumda
ve şifre değiştirme uç noktası **yok**.

**BLOKE-6 — Android/iOS derlemesi hiç doğrulanmadı.**
Bu makinede Xcode/Android SDK yok. Ürün "mobil uygulama" olarak sipariş edildi; teslim
edilen ve doğrulanan tek şey web derlemesi. Mobil hedefte doğrulanmamış olanlar:
dosya indirme (BLOKE-4 bunun bir sonucu), tarih seçici yerelleştirmesi, klavye/telefon
maskesi davranışı, izinler, uygulama imzalama. "Kod tabanı üç platformu hedefliyor"
ifadesi doğrudur ama **çalıştığına dair kanıt değildir**.

### 🟠 YÜKSEK

**Y-1 — KVKK: TC kimlik numaraları düz metin, yetki sınırı zayıf.**
TC kimlik no özel nitelikli sayılabilecek kimlik verisidir. Mevcut durum: veritabanında
şifresiz, Excel raporunda maskesiz (PROBE-7 tam numaraları gösterdi), cihazda korumasız
geçici dizine yazılıyor, JWT token'ı `shared_preferences` içinde düz metin saklanıyor
(`session.dart:59`) — web'de bu `localStorage` demektir, XSS ile okunabilir;
mobilde `flutter_secure_storage`/Keychain kullanılmıyor. HTTPS zorlaması yok
(`config.dart:11` varsayılanı `http://`). Aydınlatma metni/rıza akışı, veri saklama süresi,
silme (unutulma hakkı) mekanizması yok — `DELETE /persons` ucu hiç yok.

**Y-2 — Nesne düzeyinde yetkilendirme yok (PROBE-10).**
`saha` rolü, kendisine ait olmayan **her** saha faaliyetini ve **her** toplantıyı
düzenleyebiliyor (HTTP 200, üzerine yazdı). İl/ilçe kapsamı da yok: Adana'daki bir kullanıcı
İstanbul'un kaydını değiştirebilir. Üstelik ülke genelinde **tek bir paylaşımlı `saha`
hesabı** var (`seed.js:28-31`) — kullanıcı yönetimi ucu olmadığı için ikinci bir saha
kullanıcısı açmak mümkün değil. Bu, `created_by`'ı ve dolayısıyla tüm denetim izini
anlamsızlaştırır: her şey "Saha Kullanıcısı" olarak görünür.

**Y-3 — Kaba kuvvet koruması yok (PROBE-15).** 25 deneme 1,84 s'de, hiç engelleme yok.
Şifreler README'de yayınlanmış, tek admin hesabı var. Hız sınırlama + hesap kilitleme şart.

**Y-4 — Veri dayanıklılığı: yedekleme/geri yükleme yok.**
Tek `backend/data/app.db` dosyası (WAL modunda). Yedekleme betiği, zamanlanmış görev,
geri yükleme prosedürü veya denenmiş restore testi yok. README'de yalnız "yedekleyin"
tavsiyesi var — prosedür yok. Şema göçü (migration) altyapısı da yok: `CREATE TABLE IF NOT
EXISTS` var ama alan eklendiğinde mevcut veritabanını güncelleyecek bir mekanizma yok,
ki SPEC "şema genişletilebilir" diyor.

### 🟡 ORTA

**O-1 — Türkçe büyük harf araması sonuç döndürmüyor (PROBE-6).**
SQLite `LIKE` yalnız ASCII için harf duyarsızdır. `q=AYŞE` → 0 sonuç, `q=Ayşe` → 1 sonuç.
Büyük harfle yazan bir kullanıcı kayıtlı kişiyi bulamaz. Uygulamada Türkçe'ye duyarlı
`trLower` yardımcıları var ama yalnız istemci tarafı il filtresinde kullanılıyor;
kişi araması sunucuya gidiyor.

**O-2 — Kişi seçicide yalnız ilk 50 kişi görünüyor (PROBE-14 karşılığı).**
`person_picker_screen.dart:42` ve `add_member_screen.dart:52`, `api.persons()`'ı
varsayılan `limit=50` ile ve **sayfalama olmadan** çağırıyor. 5011 kişilik veritabanında
API 50 kayıt döndürdü. Görev ataması ve komisyona üye ekleme bu ekranlardan yapılıyor —
ülke genelinde binlerce gönüllüyle çoğu kişi seçilemez hale gelir. O-1 ile birleşince
(arama da güvenilmez) sorun ciddileşir.

**O-3 — Atama / toplantı / üye listeleri 500'de sessizce kırpılıyor.**
`api.dart` bu üç uç için `limit:'500'` sabitliyor ve `Paged` yerine düz `List` döndürüyor —
yani sayfalama **mimari olarak** mümkün değil. PROBE-14: `total:5011` iken 500 kayıt döndü,
kullanıcıya hiçbir uyarı yok. Kişiler, saha faaliyetleri ve değişiklik günlüğü ekranları
ise doğru şekilde sayfalıyor (sonsuz kaydırma) — tutarsızlık.

**O-4 — Atama listesinde N+1 istek (PROBE-12).**
`ref_data.dart:120-127` her farklı kişi için ayrı ayrı ve **sırayla** `GET /persons/:id`
çağırıyor; `GET /assignments` isim döndürmediği için. Yerelde 1 ms/istek (fark edilmez),
ancak mobil şebekede 150 ms RTT ile 200 farklı kişi ≈ 30 s açılış beklemesi.
Çözüm: `/assignments`'a Excel raporlarında zaten yapılan `persons` JOIN'ini eklemek.

**O-5 — Genişletilebilirlik yalnız API'de, arayüzde yok.**
SPEC iki yerde açıkça "genişletilebilir" diyor (§2.1.2 komisyonlar, §2.2.a görev alanları)
ve müşterinin literal isteklerinden biri. `POST /commissions` ve `POST /task-areas`
çalışıyor (PROBE-11) ama Flutter tarafında ne istemci metodu ne ekran var — müşteri
yeni komisyon eklemek için geliştiriciye/curl'e muhtaç. Ayrıca bu iki işlem
**audit log'a yazılmıyor**, ki SPEC §2.1 "tüm değişiklikler" diyor.

### 🟢 DÜŞÜK

- **D-1** — `GET /api/v1/health` 404; yalnız kök `/health` var (API.md taban URL'iyle çelişki).
- **D-2** — Boş diff'li audit kaydı yazılıyor (`"changes":{}`) — günlükte içeriksiz satırlar.
- **D-3** — Güvenlik başlıkları yok (HSTS/X-Frame-Options/X-Content-Type-Options/CSP); `helmet` yok.
- **D-4** — CORS `*`. Token `Authorization` başlığında olduğu için cookie riski yok, ama
  üretimde origin beyaz listesi olmalı.
- **D-5** — README 16 testi "12" olarak yazıyor.
- **D-6** — Teslim edilen `app.db` QA kalıntıları içeriyor (kişi id=10 "Test Kişisi",
  id=11 "Zeynep Demir"; 2 fazla faaliyet, 2 fazla toplantı). EVIDENCE.md BULGU-4 bunu
  dürüstçe bildirmiş — doğrulandı, hâlâ duruyor.
- **D-7** — EVIDENCE.md BULGU-2 (erişilebilirlik etiketleri) ve BULGU-3 (durum çipi taşması)
  düzeltilmemiş; ikisi de hâlâ açık.

---

## 6. Önceki QA Bulgularının Çapraz Doğrulaması

| QA bulgusu | Bu denetimin sonucu |
|---|---|
| BULGU-1 (audit filtresi tire/alt çizgi) MAJÖR, düzeltildi | ✅ **Doğrulandı.** `audit_log_screen.dart:23-38` backend değerleriyle uyumlu (`field_activities`, `active_toggle`); geriye dönük eşleme satır 125-131'de korunmuş. Gerçek bir hata bulunmuş ve gerçekten düzeltilmiş. |
| BULGU-2 (erişilebilirlik etiketi yok) MİNÖR | ✅ Hâlâ açık — doğru raporlanmış |
| BULGU-3 (durum çipi taşması) MİNÖR | ✅ Hâlâ açık — doğru raporlanmış |
| BULGU-4 (QA test verisi DB'de kaldı) BİLGİ | ✅ Doğrulandı, kalıntılar yerinde |
| BULGU-5 (otomasyon Flutter canvas'a tıklayamıyor) BİLGİ | ✅ Ürün hatası değil, doğru sınıflandırılmış |
| §3 "import ucu duman testinde doğrulandı" | ❌ **YANLIŞ.** smoke.mjs bu ucu hiç çağırmıyor. (Uç gerçekten çalışıyor — iddia doğru, kanıt sahte.) |
| Genel karar: "Çekirdek akışların tamamı çalışıyor" | ⚠️ **Fazla iyimser.** QA'in test ettiği 18 akış gerçekten çalışıyor, ancak QA hiç denemediği için 3 sessiz hata gözden kaçmış: form aktif/pasif tiki, audit "kim" alanı, mobil rapor indirme. Üçü de müşterinin birebir isteklerine denk geliyor. |

**Önceki QA hakkında adil değerlendirme:** EVIDENCE.md abartılı puan (A+, 98/100) veya
"sıfır hata" iddiası içermiyor, majör bir hatayı gerçekten bulup düzeltmiş ve kapsam
dışı bıraktıklarını (§3) dürüstçe listelemiş. Bu, denetim gördüğüm QA raporlarının
üst çeyreğinde. Tek ciddi kusuru, doğrulamadığı bir şeyi ("import ucu duman testinde
doğrulandı") doğrulanmış gibi yazması.

---

## 7. Sistemin Gerçekten İyi Yaptıkları (doğrulanmış)

Denetimin görevi hata bulmak, ama kanıtlanmış güçlü yanları saklamak da çarpıtma olur:

- **Backend mühendisliği sağlam.** Tüm SQL parametreli (SQL injection denemesi için
  yüzey bulunamadı), merkezî hata modeli sözleşmeye birebir uyuyor, `better-sqlite3`
  transaction'ları doğru kullanılmış, foreign key'ler açık, indeksler yerinde.
- **Performans gerçekten iyi.** 5011 kişilik veritabanında liste 2,5 ms, 5000+ satırlık
  Excel 275 ms. Bu bir MVP için fazlasıyla yeterli ve ölçek sorunu backend'de değil.
- **TC doğrulaması gerçek**, kopyala-yapıştır sahte değil; checksum algoritması doğru.
- **Excel çıktıları gerçek ve Türkçe**, `users` JOIN'i ile "Kaydı Giren" isimleri dahil.
- **Rol kısıtları çalışıyor** — 403'ler hem duman testinde hem arayüz seviyesinde doğrulandı.
- **Tohumlama sıfırdan çalışıyor** ve idempotent (81/973/6/7 birebir).
- **Türkçe yerelleştirme eksiksiz**, `İ/ı` duyarlı arama yardımcıları düşünülmüş
  (yalnız yanlış katmanda kullanılmış — O-1).
- **Kod temiz:** `flutter analyze` sıfır uyarı, TODO/stub/boş catch yok.

Bu bir "çalışıyormuş gibi yapan" proje değil. Gerçek, çalışan bir sistem —
üretime çıkmak için henüz erken olan bir sistem.

---

## 8. KARAR

# ⛔ NEEDS WORK

**Gerekçe:** Sistem demo edilebilir ve çekirdek akışların çoğu gerçekten çalışıyor.
Ancak müşterinin birebir saydığı 8 istekten **3'ü sessizce bozuk** (aktif/pasif tiki,
audit "kim", mobilde Excel) ve 1'i eksik (genişletilebilirlik arayüzü). Bunların üçü de
kullanıcıya hata göstermediği için "çalışıyor gibi" görünüyor — üretimde en tehlikeli
hata sınıfı budur. Ayrıca teslimatın tamamı sürüm kontrolü dışında ve mobil hedef
hiç doğrulanmamış.

**"GO" diyebilmem için kapatılması gereken maddeler:**

| # | Bloke edici | Tahmini efor |
|---|---|---|
| 1 | Projeyi git'e alıp commit'lemek; `turkey-provinces-districts.json` dahil (ignore edilmediğinden emin olun) | 0,5 saat |
| 2 | `is_active`'i POST/PUT'ta gerçekten yazmak **veya** formdaki tiki kaldırıp kullanıcıyı Detay ekranına yönlendirmek | 2 saat |
| 3 | `auditLogs.js`'e `users` JOIN'i + `changed_by_name` döndürmek (kalıbı `exports.js`'de hazır) | 1 saat |
| 4 | Mobilde rapor paylaşımı (`share_plus`/`open_filex`) **veya** dürüst mesaj + filtre parametrelerinin `exportXlsx`'e geçirilmesi | 4 saat |
| 5 | `KK_JWT_SECRET` yoksa üretimde fail-fast; tohum şifreleri zorunlu değiştirme akışı | 2 saat |
| 6 | En az bir Android APK derlemesi alıp gerçek cihazda giriş + rapor indirme + form kaydı akışını kanıtlamak (ekran görüntüsüyle) | 4–8 saat (SDK kurulumu dahil) |

**Ek olarak, üretim öncesi kesinlikle önerilen (bloke değil ama yüksek risk):**
Y-1 (KVKK: token'ı güvenli depoya taşı, HTTPS zorla, TC maskeleme kararı al),
Y-2 (saha rolüne sahiplik/kapsam kontrolü + kullanıcı yönetimi ucu),
Y-3 (giriş hız sınırlama), Y-4 (yedekleme prosedürü + bir kez restore denemesi).

**Gerçekçi kalite notu: C+ / B−.**
Sağlam bir ilk sürüm; birinci revizyon turunda olması gereken yerde. Bu, MVP'ler için
normal ve beklenen bir durumdur — kusur değil, aşamadır. Yukarıdaki 6 madde kapandıktan
sonra **GO WITH CONDITIONS** verilmesi makul olur; Y-1'den Y-4'e kadar olanlar da
kapanırsa tam **GO**.

**Tahmini üretime hazır olma süresi:** 2–3 iş günü (bloke edici 6 madde) +
1 hafta (yüksek riskli güvenlik/KVKK maddeleri).
**Yeni revizyon turu gerekli:** EVET.

---

## 9. Sonraki Denetim İçin Kanıt Gereksinimleri

Bir sonraki "hazır" iddiası şu kanıtlarla gelmeli:

1. `git log --oneline` çıktısı — en az bir commit ve sürüm etiketi
2. `curl` çıktısı: `PUT /persons/:id` `{"is_active":false}` → cevapta `"is_active": 0`
3. `curl` çıktısı: `GET /audit-logs` → `"changed_by_name": "Genel Merkez Admin"`
4. **Gerçek Android cihaz/emülatör ekran görüntüsü:** giriş → rapor indir → dosyanın
   paylaşım sayfasında/Dosyalar'da açıldığı an
5. `KK_JWT_SECRET` olmadan `npm start` → başlangıçta hata verip durduğunun çıktısı
6. Yeni duman testleri: import, komisyon/görev alanı ekleme, 3 eksik Excel raporu,
   `is_active` yazımı, saha rolünün başkasının kaydını düzenleyememesi

---

**Denetimi yapan:** Reality Checker · **Tarih:** 2026-08-01
**Denetim ortamı:** Backend geçici DB ile 4141'de çalıştırıldı, denetim sonunda kapatıldı
(port 4141 boş bırakıldı); projenin `backend/data/app.db` dosyası bu denetimde değiştirilmedi.
**Yeniden değerlendirme:** §8'deki 6 bloke edici madde kapatıldıktan sonra.

---

# EK — Denetim Sonrası Düzeltmeler (Orkestratör, 2026-08-01)

Denetim raporu teslim edildikten sonra, **kod hatası niteliğindeki iki bloke edici madde**
düzeltildi. Diğer bloke ediciler (BLOKE-1 sürüm kontrolü, BLOKE-4 mobil indirme,
BLOKE-5 JWT/şifre politikası, BLOKE-6 mobil derleme) **açık durumdadır** — bunlar kod
hatası değil, altyapı/politika kararı gerektiriyor.

## ✅ BLOKE-2 kapatıldı — Kişi Formu'ndaki aktif/pasif tiki artık yazılıyor
- `src/routes/persons.js`: `validatePersonPayload` artık `is_active` döndürüyor
  (`parseBoolFlag` ile); POST sabit `1` yerine `@is_active` yazıyor; PUT'un UPDATE
  cümlesine `is_active=@is_active` eklendi. `is_active` gönderilmezse yeni kayıt aktif,
  güncellemede **mevcut değer korunuyor** (PATCH ucunun davranışı bozulmadan).
- Canlı doğrulama: `POST {is_active:false}` → `is_active: 0` · `PUT {is_active:true}` →
  `1` · alan gönderilmeyen PUT → `1` korundu.

## ✅ BLOKE-3 kapatıldı — Değişiklik günlüğü artık "kim" sorusunu cevaplıyor
- `src/routes/auditLogs.js`: `users` tablosuna `LEFT JOIN` eklendi, yanıta
  `changed_by_name` alanı geldi (kullanıcı silinmişse `Bilinmeyen kullanıcı (#id)`).
- Arayüzde değişiklik gerekmedi: `models.dart:328` zaten `changed_by_name` alanını
  öncelikli okuyup `changed_by`'a düşüyordu.
- Görsel doğrulama: günlük ekranı artık `Genel Merkez Admin · Güncelleme — Kişiler` ve
  `Saha Kullanıcısı · Ekleme — Toplantılar` gösteriyor.

## Denetçinin "test kapsamı yetersiz" uyarısına yanıt
Denetim, geçen testlerin gereksinimi kanıtlamadığını haklı olarak vurguladı. Bu iki hata
için **5 yeni regresyon testi** `test/smoke.mjs` içine eklendi:
`POST is_active:false yazılır` · `PUT is_active:true yazılır` ·
`PUT is_active gönderilmezse mevcut değer korunur` · `audit kaydında changed_by_name dolu` ·
`changed_by_name doğru kullanıcıyı gösterir`.

**Duman testi: 46 → 51 kontrol, 51 başarılı / 0 başarısız.**

Denetçinin §9'da istediği kanıtlardan 2 ve 3 numaralı maddeler böylece karşılandı.
Kalan kanıt gereksinimleri (git commit, mobil cihaz ekran görüntüsü, fail-fast JWT)
hâlâ açıktır.

---

# EK-2 — Demo verisinin referans veriden ayrılması (2026-08-01)

**Gerekçe (müşteri geri bildirimi):** "bu veriler test verileri, uygulama tamamlandıktan
sonra işimize yaramayacak."

**Yapılan ayrım.** Tohum veri artık iki kategoriye bölünmüştür ve karıştırılamaz:

| Kategori | İçerik | Üretimde |
|---|---|---|
| **Referans veri** | 81 il, 973 ilçe, koordinasyon kurulu + 6 komisyon, görev alanları, giriş kullanıcıları | **Gerekli** — her açılışta güvence altına alınır |
| **Demo veri** | 9 sahte kişi, üyelikler, faaliyetler, toplantılar, atamalar | **Yüklenmez** — yalnızca `KK_SEED_DEMO=1` / `--demo` ile |

**Not:** Referans veri "test verisi" değildir; müşterinin "81 il ve ilçeler tanımlı olacak,
veri girişi yapılmış olacak" gereksinimidir ve üründe de kullanılacaktır. Atılabilir olan
yalnızca sahte kişi/işlem kayıtlarıdır. Bu nedenle
`backend/data/turkey-provinces-districts.json` dosyasının yedeklenmesi (BLOKE-1) hâlâ
geçerlidir.

**Eklenen araçlar:**
- `npm start` / `npm run seed` → yalnız referans veri (kişi sayısı 0)
- `npm run start:demo` / `npm run seed:demo` → demo veri dahil
- `npm run db:reset` → işlem kayıtlarını siler, referans veriyi korur (onay ister)

**Doğrulama:**
- Temiz kurulum, üretim modu: `{provinces:81, districts:973, commissions:6, task_areas:7, persons:0}`
- Temiz kurulum, demo modu: aynı referans veri + `persons:9`
- Geliştirme veritabanı temizlendi: 44 test kaydı silindi, referans veri sağlam kaldı.
- **Yeni test paketi `test/seed-modes.mjs` (9 kontrol)** — üretim tohumlamasının hiçbir demo
  kaydı sızdırmadığını doğrular; `npm test` artık bunu duman testinden önce çalıştırıyor.

**Test durumu: 9 tohum modu + 51 duman testi = 60 kontrol, hepsi geçiyor.**
