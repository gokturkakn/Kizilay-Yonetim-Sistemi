# UX/UI Temeli — Teşkilat Yönetim Sistemi (MVP)

**Sürüm:** 1.0 · **Tarih:** 2026-08-01 · **Kaynaklar:** `docs/SPEC.md`, `docs/API.md`
**Hedef:** Flutter geliştiricisi bu belgeden hiçbir etiket, akış veya durum uydurmadan uygulamayı birebir kodlayabilmelidir. Tüm kullanıcıya görünen metinler bu belgede **aynen** yazıldığı gibi kullanılır.

Genel ton: **kurumsal, güvenilir, sade.** Oyuncu renkler, gölge/gradyan gösterileri, animasyon süsleri yok. Kızılay kırmızısı yalnızca marka vurgusu ve birincil aksiyonlarda; geri kalan her şey beyaz/gri. Yalnızca **açık tema** (MVP'de karanlık tema yok — `ThemeMode.light` sabit).

---

## 1. Tasarım Token'ları

Dart'ta tek dosyada tanımlanır: `lib/theme/tokens.dart` + `lib/theme/app_theme.dart` (Material 3, `useMaterial3: true`).

### 1.1 Renk paleti

| Token (Dart sabiti) | Değer | Kullanım |
|---|---|---|
| `kPrimary` | `#E30613` | Kızılay kırmızısı. AppBar arka planı, birincil butonlar, seçili tab, FAB |
| `kPrimaryDark` | `#B10510` | Basılı (pressed) durum, kırmızı üzerinde koyu vurgu |
| `kPrimaryContainer` | `#FDE7E9` | Kırmızının %8 tonu: seçili çip arka planı, vurgulu kart şeridi |
| `kOnPrimary` | `#FFFFFF` | Kırmızı üzerindeki metin/ikon |
| `kSurface` | `#FFFFFF` | Kart ve sayfa yüzeyleri |
| `kBackground` | `#F7F7F8` | Sayfa zemin rengi (liste ekranlarında kartları ayırır) |
| `kBorder` | `#E2E4E8` | Kart kenarı, ayraç (divider), form alanı çerçevesi |
| `kTextPrimary` | `#1A1C1E` | Başlıklar, gövde metni |
| `kTextSecondary` | `#5F6368` | İkincil metin, alt yazılar, ipuçları |
| `kTextDisabled` | `#9AA0A6` | Pasif eleman metni |
| `kSuccess` | `#1E8E3E` | Başarı mesajı, **Aktif** rozeti, "tamamlandı" durumu |
| `kSuccessContainer` | `#E6F4EA` | Aktif rozetinin arka planı |
| `kWarning` | `#B26A00` | Uyarı metni, "devam ediyor" durumu |
| `kWarningContainer` | `#FDF3E0` | Uyarı/devam rozet arka planı |
| `kError` | `#C5221F` | Doğrulama hataları, silme aksiyonu, hata durumu |
| `kErrorContainer` | `#FCE8E6` | Hata banner arka planı |
| `kInactive` | `#5F6368` | **Pasif** rozet metni/ikonu (gri) |
| `kInactiveContainer` | `#EEF0F2` | Pasif rozetinin arka planı |
| `kInfo` | `#1A73E8` | "Atandı" durumu, bilgi vurgusu |
| `kInfoContainer` | `#E8F0FE` | Atandı rozet arka planı |

Kural: **Aktif = yeşil (`kSuccess`), Pasif = gri (`kInactive`).** Kırmızı asla durum rengi olarak kullanılmaz (hata/silme hariç) — Kızılay kırmızısıyla karışmaması için.

### 1.2 Tipografi (Material 3, TR uyumlu)

Yazı tipi: **Roboto** (Flutter varsayılanı; Türkçe karakter kapsamı tam, ek font paketi gerekmez).

| Token | Boyut / Ağırlık / Satır | Kullanım |
|---|---|---|
| `headlineSmall` | 24 / w600 / 32 | Ekran başlıkları (AppBar dışında büyük başlık gerekirse) |
| `titleLarge` | 20 / w600 / 28 | AppBar başlığı, dialog başlığı |
| `titleMedium` | 16 / w600 / 24 | Kart başlığı, bölüm başlığı, liste elemanında ad-soyad |
| `titleSmall` | 14 / w600 / 20 | Form bölüm başlıkları |
| `bodyLarge` | 16 / w400 / 24 | Form alan girdileri, dialog gövdesi |
| `bodyMedium` | 14 / w400 / 20 | Liste alt satırı, genel gövde metni |
| `bodySmall` | 12 / w400 / 16 | Yardımcı metin, zaman damgaları, rozet metni |
| `labelLarge` | 14 / w600 / 20 | Buton metinleri (TÜMÜ BÜYÜK HARF **kullanılmaz**; normal cümle düzeni) |

### 1.3 Boşluk ölçeği (4 pt tabanı)

| Token | Değer | Kullanım |
|---|---|---|
| `s4` | 4 | Rozet iç boşluğu (dikey) |
| `s8` | 8 | İkon–metin arası, çipler arası |
| `s12` | 12 | Kart iç boşluğu (kompakt), liste elemanı dikey padding |
| `s16` | 16 | **Standart sayfa kenar boşluğu**, kart iç boşluğu, form alanları arası |
| `s24` | 24 | Bölümler arası dikey boşluk |
| `s32` | 32 | Büyük ayrım (form sonu ile kaydet butonu arası) |

### 1.4 Köşe yarıçapları ve yükseklikler

| Token | Değer | Kullanım |
|---|---|---|
| `r8` | 8 | Form alanları (`OutlinedInputBorder`), rozetler |
| `r12` | 12 | Kartlar, dialoglar, bottom sheet üst köşeleri (16 da kabul) |
| `rFull` | 999 | Filtre çipleri, durum rozetleri (stadium) |
| Kart elevation | `0` + 1 px `kBorder` çerçeve | Gölge yerine çerçeve — kurumsal görünüm |
| Buton yüksekliği | 48 | Tüm `FilledButton`/`OutlinedButton` |
| Liste elemanı min yükseklik | 64 | Kişi kartı; 56 basit satırlar |
| Dokunma hedefi | min 48×48 | Tüm etkileşimli öğeler |

### 1.5 AppBar ve genel iskelet

- AppBar: arka plan `kPrimary`, metin/ikon `kOnPrimary`, `centerTitle: false`, elevation 0.
- Scaffold arka planı: `kBackground`.
- `FilledButton` = kırmızı zemin/beyaz metin (birincil). `OutlinedButton` = beyaz zemin/kırmızı metin ve çerçeve (ikincil). `TextButton` yalnızca dialog aksiyonlarında.

---

## 2. Navigasyon Mimarisi

### 2.1 Alt gezinme çubuğu (BottomNavigationBar / NavigationBar)

Girişten sonra kalıcı 4 sekme (`genel_merkez` rolü). Seçili ikon/etiket `kPrimary`, seçili olmayan `kTextSecondary`.

| Sıra | Etiket | İkon (Material) |
|---|---|---|
| 1 | `Yönetim Paneli` | `Icons.dashboard_outlined` / seçili `Icons.dashboard` |
| 2 | `Saha Çalışmaları` | `Icons.groups_outlined` / `Icons.groups` |
| 3 | `Raporlar` | `Icons.insert_chart_outlined` / `Icons.insert_chart` |
| 4 | `Profil` | `Icons.person_outline` / `Icons.person` |

**`saha` rolü** için çubukta yalnızca **Saha Çalışmaları** ve **Profil** görünür (bkz. §5).

### 2.2 Ekran ağacı (tam)

```
Giriş (Login)  [oturum yoksa tek ekran]
└─ (başarılı giriş) → Ana İskelet (alt gezinme)
   ├─ 1. Yönetim Paneli (home)
   │  ├─ Koordinasyon Kurulu → Üye Listesi
   │  │  └─ Üye Ekle (kayıtlı kişiden seçim — bottom sheet/ekran)
   │  ├─ Komisyonlar → Komisyon Listesi (6 kayıt)
   │  │  └─ [Komisyon] Üye Listesi
   │  │     └─ Üye Ekle (kayıtlı kişiden seçim)
   │  └─ Kadın Teşkilatları → İl Listesi (81, aranabilir)
   │     └─ İl Detayı ([İl] Teşkilatı)
   │        ├─ sekme "İl Teşkilatı": il kişileri listesi
   │        │  └─ Kişi Detayı → Kişi Formu (düzenle)
   │        ├─ sekme "İlçeler": ilçe listesi
   │        │  └─ İlçe Kişileri Listesi
   │        │     └─ Kişi Detayı → Kişi Formu (düzenle)
   │        └─ FAB → Kişi Formu (yeni)
   ├─ 2. Saha Çalışmaları (home)
   │  ├─ Saha Faaliyetleri → Faaliyet Listesi
   │  │  ├─ FAB → Görev Formu (yeni)
   │  │  └─ eleman dokunuşu → Görev Formu (düzenle)
   │  ├─ Yönetsel Faaliyetler → sekmeli ekran
   │  │  ├─ sekme "Kurul Toplantıları": liste
   │  │  │  └─ FAB / dokunuş → Kurul Toplantısı Formu (yeni/düzenle)
   │  │  └─ sekme "Komisyon Toplantıları": liste
   │  │     └─ FAB / dokunuş → Komisyon Toplantısı Formu (yeni/düzenle)
   │  └─ Görev Atamaları → Atama Listesi (herkes görür)
   │     └─ FAB (yalnız genel_merkez) → Atama Formu (yeni/düzenle)
   ├─ 3. Raporlar
   │  ├─ 4 Excel indirme kartı (kişiler, saha, toplantılar, atamalar)
   │  └─ Değişiklik Günlüğü → günlük listesi
   └─ 4. Profil
      └─ ad/e-posta/rol + "Çıkış Yap"
```

Geri davranışı: her alt ekran AppBar'da geri oku taşır; alt gezinme sekmeleri kendi Navigator yığınını korur (sekme değişince yığın sıfırlanmaz).

---

## 3. Ekran Ekran Şartname

Aşağıdaki her ekran için: amaç, bileşenler, boş durum, birincil aksiyonlar. API çağrıları `docs/API.md` uç noktalarına referansla verilmiştir.

### 3.1 Giriş — `LoginScreen`

- **Amaç:** E-posta + şifre ile oturum açma (`POST /auth/login`), token'ı güvenli saklama.
- **Bileşenler:** Üstte Kızılay Kadın logosu alanı (yoksa `kPrimary` renkli hilal ikonu + `Kızılay Kadın` `titleLarge`); altında `Teşkilat Yönetim Sistemi` `bodyMedium`/`kTextSecondary`. Form: `E-posta` alanı (klavye: email), `Şifre` alanı (gizli, göz ikonu ile göster/gizle), `Giriş Yap` birincil butonu (tam genişlik).
- **Doğrulama (yerel):** boş e-posta → `E-posta adresi gerekli.` · biçim hatası → `Geçerli bir e-posta adresi girin.` · boş şifre → `Şifre gerekli.`
- **Sunucu hatası (401):** alanların üstünde `kErrorContainer` banner: `E-posta veya şifre hatalı.` · Ağ hatası: `Sunucuya ulaşılamadı. Bağlantınızı kontrol edin.`
- **Yüklenme:** buton içinde spinner, buton metni gizlenir, form kilitlenir.
- **Başarı:** rolü ne olursa olsun Ana İskelete gidilir; `saha` ise ilk sekme Saha Çalışmaları olur.

### 3.2 Yönetim Paneli (home) — `AdminHomeScreen`

- **Amaç:** Üç yönetim alanına giriş kapısı.
- **AppBar:** `Yönetim Paneli`.
- **Bileşenler:** Dikey 3 büyük gezinme kartı (tam genişlik, `r12`, ikon solda `kPrimary`, sağda `chevron_right`):
  1. `Koordinasyon Kurulu` — alt yazı: `Kurul üyelerini görüntüle ve yönet` — ikon `Icons.account_balance_outlined`
  2. `Komisyonlar` — alt yazı: `6 komisyon ve üyelikleri` — ikon `Icons.diversity_3_outlined`
  3. `Kadın Teşkilatları` — alt yazı: `81 il ve ilçe teşkilatları` — ikon `Icons.location_city_outlined`
- **Boş durum:** yok (kartlar statik).
- **Birincil aksiyon:** kart dokunuşu → ilgili ekran.

### 3.3 Komisyon Listesi — `CommissionListScreen`

- **Amaç:** 6 (genişleyebilir) komisyonu listelemek. `GET /commissions` (gösterim `GET /bodies` type=`komisyon` ile eşlenir).
- **AppBar:** `Komisyonlar`.
- **Bileşenler:** basit liste satırları (komisyon adı `titleMedium`, `chevron_right`). Pasif komisyon (`is_active=false`) listede gösterilmez.
- **Boş durum:** `Henüz komisyon tanımlanmamış.`
- **Aksiyon:** satır → o komisyonun Üye Listesi. (Komisyon ekleme MVP arayüzünde yok; API'den tohumlanır.)

### 3.4 Kurul / Komisyon Üye Listesi — `BodyMembersScreen`

Koordinasyon Kurulu ve her komisyon için aynı ekran; `body_id` parametreli. `GET /bodies/:id/members?is_active=`.

- **AppBar:** kurul için `Koordinasyon Kurulu`; komisyon için komisyonun adı (ör. `Eğitim Komisyonu`).
- **Bileşenler (yukarıdan aşağı):**
  1. Filtre çipleri (yatay): `Tümü` · `Aktif` · `Pasif` — varsayılan **Aktif**. Seçili çip: `kPrimaryContainer` zemin, `kPrimary` metin.
  2. Üye listesi: kişi kartı (bkz. §4.1) + `role_title` doluysa ad altında `bodySmall`/`kTextSecondary` olarak görev unvanı (ör. `Başkan`).
  3. Kart üzerinde taşma menüsü (`⋮`): `Pasif Yap` / `Aktif Yap` (`PATCH /memberships/:id/active`) ve `Üyelikten Çıkar` (`DELETE /memberships/:id`, onay dialoglu: başlık `Üyelikten çıkar`, gövde `Bu kişi listeden kaldırılacak. Devam edilsin mi?`, aksiyonlar `Vazgeç` / `Çıkar` kırmızı).
- **Boş durum:** ikon `Icons.group_off_outlined` + `Bu listede üye bulunmuyor.` + `Üye Ekle` butonu.
- **Birincil aksiyon:** FAB `Üye Ekle` (`Icons.person_add`) → Üye Ekle ekranı. **Yalnız `genel_merkez`** (bkz. §5); `saha` bu ekranı zaten görmez.

### 3.5 Üye Ekle (kayıtlı kişiden seçim) — `AddMemberScreen`

- **Amaç:** Kayıtlı kişilerden birini kurula/komisyona atamak. `GET /persons?q=` + `POST /bodies/:id/members`.
- **Sunum:** tam sayfa (bottom sheet değil — arama klavyesi ile çakışmaması için).
- **AppBar:** `Üye Ekle`.
- **Bileşenler:**
  1. Arama alanı: ipucu `Ad veya soyad ile ara...`, 300 ms debounce, `q` parametresi.
  2. Sonuç listesi: kişi kartı (ad, il/ilçe, aktif/pasif rozeti). Zaten üye olanlar listede soluk (`kTextDisabled`) ve dokunulamaz; sağında `Üye` etiketi.
  3. Kişi seçilince dialog: başlık `Üyelik bilgisi`, içerik: seçilen kişinin adı + opsiyonel metin alanı `Görev / Unvan (isteğe bağlı)` (ipucu: `Örn. Başkan, Sekreter`), aksiyonlar `Vazgeç` / `Ekle`.
- **Boş durum (arama sonucu yok):** `Aramanızla eşleşen kişi bulunamadı.`
- **Başarı:** snackbar `Üye eklendi.`, listeye dönülür ve liste yenilenir.

### 3.6 İl Listesi — `ProvinceListScreen`

- **Amaç:** 81 ilin plaka sırasıyla listesi. `GET /provinces` (tek seferde, sayfalama yok; yerelde filtrelenir).
- **AppBar:** `Kadın Teşkilatları`.
- **Bileşenler:** üstte kalıcı arama alanı, ipucu `İl ara...` (yerel filtre, Türkçe küçük/büyük harf duyarsız — `İ/i, I/ı` doğru karşılaştırılır: `toLowerCase('tr')` mantığı). Liste satırı: solda plaka kodu iki haneli (`06`) `kInactiveContainer` zeminli küçük rozet, il adı `titleMedium`, sağda `chevron_right`.
- **Boş durum (arama):** `"{arama}" ile eşleşen il bulunamadı.`
- **Aksiyon:** satır → İl Detayı.

### 3.7 İl Detayı — `ProvinceDetailScreen`

- **Amaç:** İl teşkilatı kişileri + ilçe listesi tek ekranda. `GET /persons?province_id=&unit_type=` ve `GET /provinces/:id/districts`.
- **AppBar:** `{İl adı} Teşkilatı` (ör. `Ankara Teşkilatı`).
- **Bileşenler:** iki sekme (`TabBar`, sekme metni `kPrimary` altçizgi):
  - **Sekme 1 — `İl Teşkilatı`:** bu ile bağlı `unit_type` `il_teskilati` **ve** `temsilcilik` kişileri. Üstte: arama alanı (`Kişi ara...`) + filtre çipleri `Tümü/Aktif/Pasif` (varsayılan Aktif). Kişi kartında `temsilcilik` ise ad altındaki konum satırı yerine `Temsilcilik` rozeti (`kInfoContainer`/`kInfo`).
  - **Sekme 2 — `İlçeler`:** ilçe adları alfabetik liste, satırda `chevron_right`. Dokunuş → İlçe Kişileri.
- **Boş durumlar:** Sekme 1: `Bu il teşkilatında kayıtlı kişi bulunmuyor.` + `Kişi Ekle` butonu. Sekme 2 (teorik): `İlçe kaydı bulunamadı.`
- **Birincil aksiyon:** FAB `Kişi Ekle` (`Icons.person_add`) → Kişi Formu; il alanı bu il ile ön dolu. Yalnız `genel_merkez`.

### 3.8 İlçe Kişileri — `DistrictPersonsScreen`

- **Amaç:** Seçili ilçenin kişileri. `GET /persons?district_id=&is_active=&q=`.
- **AppBar:** `{İlçe adı}` (ör. `Çankaya`), alt başlık gerekmez.
- **Bileşenler:** arama alanı (`Kişi ara...`) + `Tümü/Aktif/Pasif` çipleri (varsayılan Aktif) + kişi kartı listesi. Sayfalama: sonsuz kaydırma (`page/limit`, limit 50), liste sonunda küçük yüklenme göstergesi.
- **Boş durum:** `Bu ilçede kayıtlı kişi bulunmuyor.` + `Kişi Ekle` butonu. Arama sonucu boşsa: `Aramanızla eşleşen kişi bulunamadı.`
- **Birincil aksiyon:** FAB `Kişi Ekle` → Kişi Formu; il ve ilçe ön dolu, `unit_type` = `ilce_teskilati` ön seçili. Yalnız `genel_merkez`.

### 3.9 Kişi Formu (yeni/düzenle) — `PersonFormScreen`

- **Amaç:** `POST /persons` / `PUT /persons/:id`. SPEC'teki tüm alanlar.
- **AppBar:** yeni: `Yeni Kişi` · düzenleme: `Kişiyi Düzenle`.
- **Alanlar (sıra ile, tümü `OutlinedInputBorder` `r8`):**

| Etiket | Tür | Zorunlu | Notlar |
|---|---|---|---|
| `Ad` | metin | Evet | boş → `Ad gerekli.` |
| `Soyad` | metin | Evet | boş → `Soyad gerekli.` |
| `TC Kimlik No` | sayı, 11 hane | Evet | aşağıda |
| `Doğum Tarihi` | tarih seçici | Evet | gösterim `dd.MM.yyyy`, API'ye `YYYY-MM-DD`; başlangıç 1980, aralık 1920–bugün. Boş → `Doğum tarihi gerekli.` |
| `Telefon` | tel klavyesi | Evet | aşağıda |
| `E-posta` | email klavyesi | Hayır | doluysa biçim: `Geçerli bir e-posta adresi girin.` |
| `Meslek` | metin | Hayır | — |
| `Birim Türü` | 3 seçenekli segment/radyo | Evet | `İl Teşkilatı` / `İlçe Teşkilatı` / `Temsilcilik` |
| `İl` | dropdown (81) | Evet | `GET /provinces` |
| `İlçe` | dropdown | Yalnız `İlçe Teşkilatı` seçiliyse | il seçilince yüklenir; il değişince sıfırlanır. `il_teskilati` ve `temsilcilik` seçiliyken alan **gizlenir** ve `district_id=null` gönderilir |
| `Aktif` | switch | — | varsayılan açık; yanında etiket `Aktif` |

- **TC doğrulama (yerelde, kaydetmeden önce):**
  - boş → `TC kimlik numarası gerekli.`
  - 11 haneli değil / rakam dışı → `TC kimlik numarası 11 haneli olmalıdır.`
  - checksum geçmez (standart algoritma: ilk hane ≠ 0; 10. hane = ((1,3,5,7,9. haneler toplamı×7) − (2,4,6,8. haneler toplamı)) mod 10; 11. hane = ilk 10 hane toplamı mod 10) → `Geçersiz TC kimlik numarası.`
  - sunucu benzersizlik hatası (409/400) → alan altında `Bu TC kimlik numarası ile kayıtlı bir kişi zaten var.`
- **Telefon doğrulama:** giriş maskesi `0(5XX) XXX XX XX`; yalnız rakam saklanır (11 hane, `05` ile başlar). Boş → `Telefon numarası gerekli.` · biçim → `Geçerli bir telefon numarası girin (05XX XXX XX XX).`
- **Birincil aksiyon:** en altta tam genişlik `Kaydet` butonu. Başarı: snackbar `Kişi kaydedildi.` ve geri dönüş. Sunucu genel hatası: snackbar `Kayıt başarısız. Lütfen tekrar deneyin.`
- **Kirli form çıkışı:** geri basılırsa dialog `Değişiklikler kaydedilmedi` / `Bu sayfadan çıkarsanız girdiğiniz bilgiler silinecek.` / `Vazgeç` · `Çık`.

### 3.10 Kişi Detayı — `PersonDetailScreen`

- **Amaç:** Tüm kişi alanlarını göstermek; aktif/pasif hızlı değişim. `GET /persons/:id`, `PATCH /persons/:id/active`.
- **AppBar:** `Kişi Detayı`; sağda `Icons.edit` → Kişi Formu (düzenle) (yalnız `genel_merkez`).
- **Bileşenler:**
  1. Üst kart: Ad Soyad `headlineSmall`, altında konum satırı (`{İl} / {İlçe}` veya `{İl} — Temsilcilik` veya `{İl} — İl Teşkilatı`), sağ üstte aktif/pasif rozeti.
  2. **Durum kartı (belirgin):** tam genişlik ayrı kart, solda `Durum` `titleMedium` + alt yazı: aktifken `Bu kişi aktif olarak görünüyor.`, pasifken `Bu kişi pasif olarak işaretlendi.`; sağda büyük `Switch` (açık: `kSuccess`; kapalı: gri). Değişimde onay dialoğu: başlık `Durumu değiştir`, gövde aktife çekilirken `{Ad Soyad} aktif yapılacak. Onaylıyor musunuz?` / pasife çekilirken `{Ad Soyad} pasif yapılacak. Onaylıyor musunuz?`, aksiyonlar `Vazgeç` / `Onayla`. Başarıda snackbar `Durum güncellendi.`
  3. Bilgi listesi (etiket `bodySmall`/`kTextSecondary`, değer `bodyLarge`): `TC Kimlik No`, `Doğum Tarihi` (dd.MM.yyyy), `Telefon` (05XX XXX XX XX; dokununca arama uygulamasını açar), `E-posta` (boşsa `—`), `Meslek` (boşsa `—`), `Birim Türü` (`İl Teşkilatı`/`İlçe Teşkilatı`/`Temsilcilik`), `Kayıt Tarihi` (dd.MM.yyyy).
- **`saha` rolü** bu ekranı görmez (Yönetim Paneli kapalı).

### 3.11 Saha Çalışmaları (home) — `FieldHomeScreen`

- **Amaç:** Saha alanının üç girişine kapı.
- **AppBar:** `Saha Çalışmaları`.
- **Bileşenler:** 2 büyük kart + 1 liste girişi:
  1. Kart `Saha Faaliyetleri` — alt yazı: `Görev formu ile etkinlik kaydı` — ikon `Icons.volunteer_activism_outlined`
  2. Kart `Yönetsel Faaliyetler` — alt yazı: `Kurul ve komisyon toplantıları` — ikon `Icons.meeting_room_outlined`
  3. Giriş satırı `Görev Atamaları` — alt yazı: `Genel merkez tarafından atanan görevler` — ikon `Icons.assignment_outlined`
- **Aksiyon:** dokunuş → ilgili ekran.

### 3.12 Saha Faaliyetleri Listesi — `FieldActivityListScreen`

- **Amaç:** Girilen görev formlarının listesi. `GET /field-activities?task_area_id=&from=&to=` (varsayılan: son kayıtlar, tarihe göre yeniden eskiye).
- **AppBar:** `Saha Faaliyetleri`; sağda filtre ikonu (`Icons.filter_list`) → bottom sheet: `Görev Alanı` dropdown (`Tümü` + liste), `Başlangıç Tarihi` / `Bitiş Tarihi` seçiciler, `Temizle` + `Uygula` butonları.
- **Liste elemanı (kart):** üst satır: görev alanı adı `titleMedium` + sağda tarih `bodySmall` (dd.MM.yyyy); alt satır: `👥 {n} gönüllü · {m} yararlanıcı` `bodyMedium`/`kTextSecondary`; il/ilçe doluysa üçüncü satır `{İl} / {İlçe}`.
- **Boş durum:** ikon `Icons.event_note_outlined` + `Henüz saha faaliyeti kaydı yok.` + alt metin `İlk kaydı eklemek için + butonuna dokunun.`
- **Aksiyonlar:** FAB `+` → Görev Formu (yeni). Eleman dokunuşu → Görev Formu (düzenle, `PUT`). Kart taşma menüsünde `Sil` **yalnız `genel_merkez`** (`DELETE`; onay: `Faaliyet silinsin mi?` / `Bu işlem geri alınamaz.` / `Vazgeç` · `Sil`).

### 3.13 Görev Formu — `FieldActivityFormScreen`

- **AppBar:** yeni: `Yeni Görev Formu` · düzenleme: `Görev Formunu Düzenle`.
- **Alanlar:**

| Etiket | Tür | Zorunlu | Doğrulama mesajı |
|---|---|---|---|
| `Görev Alanı` | dropdown (`GET /task-areas`, yalnız `is_active`) | Evet | `Görev alanı seçin.` |
| `Tarih` | tarih seçici, varsayılan bugün | Evet | `Tarih seçin.` |
| `Katılan Gönüllü Sayısı` | sayı | Evet | boş/0 altı → `Gönüllü sayısı girin.` · rakam dışı → `Geçerli bir sayı girin.` |
| `Yararlanıcı Sayısı` | sayı | Evet | boş/0 altı → `Yararlanıcı sayısı girin.` · rakam dışı → `Geçerli bir sayı girin.` |
| `İl (isteğe bağlı)` | dropdown, `Seçilmedi` ilk seçenek | Hayır | — |
| `İlçe (isteğe bağlı)` | dropdown, il seçiliyse aktif | Hayır | — |
| `Açıklama (isteğe bağlı)` | çok satırlı metin (3 satır) | Hayır | — |

- **Birincil aksiyon:** `Kaydet`. Başarı: snackbar `Faaliyet kaydedildi.`

### 3.14 Yönetsel Faaliyetler — `MeetingsScreen`

- **Amaç:** Toplantı kayıtları. `GET /meetings?body_id=`.
- **AppBar:** `Yönetsel Faaliyetler`. İki sekme: `Kurul Toplantıları` (body = koordinasyon_kurulu) ve `Komisyon Toplantıları` (body type = komisyon).
- **Liste elemanı (her iki sekme):** üst satır: kurul sekmesinde `Koordinasyon Kurulu`, komisyon sekmesinde komisyon adı, `titleMedium` + sağda tarih (dd.MM.yyyy); orta: `Karar: {decision}` en fazla 2 satır, taşarsa `...`; alt: `Sonuç: {outcome}` 1 satır.
- **Boş durumlar:** kurul: `Henüz kurul toplantısı kaydı yok.` · komisyon: `Henüz komisyon toplantısı kaydı yok.` (+ her ikisinde `İlk kaydı eklemek için + butonuna dokunun.`)
- **Aksiyonlar:** FAB `+` → aktif sekmeye göre form. Eleman → düzenleme. `Sil` taşma menüsünde, yalnız `genel_merkez` (onay metinleri §3.12 ile aynı kalıp: `Toplantı kaydı silinsin mi?`).

### 3.15 Toplantı Formu — `MeetingFormScreen`

- **AppBar:** kurul yeni: `Yeni Kurul Toplantısı` · komisyon yeni: `Yeni Komisyon Toplantısı` · düzenleme: `Toplantıyı Düzenle`.
- **Alanlar:**

| Etiket | Tür | Zorunlu | Mesaj |
|---|---|---|---|
| `Komisyon` | dropdown — **yalnız komisyon formunda** (`GET /bodies` type=komisyon) | Evet | `Komisyon seçin.` |
| `Toplantı Tarihi` | tarih seçici | Evet | `Tarih seçin.` |
| `Toplantı Kararı` | çok satırlı (3 satır) | Evet | `Toplantı kararını girin.` |
| `Sonuç` | çok satırlı (3 satır) | Evet | `Sonucu girin.` |

Kurul formunda `body_id` otomatik koordinasyon kuruludur, alan gösterilmez.
- **Başarı:** snackbar `Toplantı kaydedildi.`

### 3.16 Görev Atamaları — `AssignmentListScreen`

- **Amaç:** Genel merkezin sahaya atadığı görevler; **tüm roller okuyabilir**. `GET /assignments?status=`.
- **AppBar:** `Görev Atamaları`.
- **Filtre çipleri:** `Tümü` · `Atandı` · `Devam Ediyor` · `Tamamlandı` (varsayılan Tümü).
- **Liste elemanı (kart):** üst: görev başlığı `titleMedium` + sağda durum rozeti — `Atandı` (`kInfo`/`kInfoContainer`), `Devam Ediyor` (`kWarning`/`kWarningContainer`), `Tamamlandı` (`kSuccess`/`kSuccessContainer`); orta: `Icons.person_outline` + kişinin adı soyadı; alt: atama tarihi (dd.MM.yyyy) + açıklama varsa 1 satır özet.
- **Boş durum:** `Henüz görev ataması yok.` (`genel_merkez` için ek satır: `Yeni atama için + butonuna dokunun.`)
- **Aksiyonlar:** FAB `+` **yalnız `genel_merkez`** → Atama Formu. Eleman dokunuşu: `genel_merkez` → düzenleme formu; `saha` → salt okunur detay (aynı form ekranı, alanlar kilitli, buton yok).

### 3.17 Atama Formu — `AssignmentFormScreen` (yalnız `genel_merkez`)

- **AppBar:** yeni: `Yeni Görev Ataması` · düzenleme: `Atamayı Düzenle`.
- **Alanlar:**

| Etiket | Tür | Zorunlu | Mesaj |
|---|---|---|---|
| `Kişi` | arama ile kişi seçici (§3.5'teki arama listesi deseni; salt seçim) | Evet | `Kişi seçin.` |
| `Görev Başlığı` | metin | Evet | `Görev başlığı gerekli.` |
| `Açıklama (isteğe bağlı)` | çok satırlı | Hayır | — |
| `Atama Tarihi` | tarih seçici, varsayılan bugün | Evet | `Tarih seçin.` |
| `Durum` | segment: `Atandı` / `Devam Ediyor` / `Tamamlandı` (yeni kayıtta `Atandı` seçili) | Evet | — |

- **Başarı:** snackbar `Atama kaydedildi.`

### 3.18 Raporlar — `ReportsScreen` (yalnız `genel_merkez`)

- **Amaç:** 4 Excel dışa aktarımı + değişiklik günlüğü girişi.
- **AppBar:** `Raporlar`.
- **Bileşenler:** başlık `Excel Raporları` `titleSmall`, altında 4 kart (ikon `Icons.table_view_outlined` `kSuccess`, sağda `Icons.download`):
  1. `Kişi Listesi` — alt yazı `Tüm kayıtlı kişiler (.xlsx)` — `GET /export/persons.xlsx`
  2. `Saha Faaliyetleri` — alt yazı `Görev formu kayıtları (.xlsx)` — `GET /export/field-activities.xlsx`
  3. `Yönetsel Faaliyetler` — alt yazı `Kurul ve komisyon toplantıları (.xlsx)` — `GET /export/meetings.xlsx`
  4. `Görev Atamaları` — alt yazı `Atama kayıtları (.xlsx)` — `GET /export/assignments.xlsx`
  - İndirme sırasında kartta spinner; başarıda snackbar `Rapor indirildi.` (web hedefinde tarayıcı indirmesi tetiklenir); hatada `Rapor indirilemedi. Tekrar deneyin.`
  - Altında ayrı bölüm başlığı `Kayıt Takibi` ve giriş satırı: `Değişiklik Günlüğü` — alt yazı `Kim, ne zaman, neyi değiştirdi` — ikon `Icons.history`.
- **Boş durum:** yok.

### 3.19 Değişiklik Günlüğü — `AuditLogScreen` (yalnız `genel_merkez`)

- **Amaç:** Denetim kayıtları. `GET /audit-logs?entity=&from=&to=`, sonsuz kaydırma.
- **AppBar:** `Değişiklik Günlüğü`; sağda filtre ikonu → bottom sheet: `Kayıt Türü` dropdown (`Tümü`, `Kişiler`, `Üyelikler`, `Saha Faaliyetleri`, `Toplantılar`, `Atamalar` → `entity` değerleri: persons, memberships, field-activities/activities, meetings, assignments — API'nin döndürdüğü entity adlarıyla eşle), tarih aralığı, `Temizle`/`Uygula`.
- **Liste elemanı:** üst: eylem cümlesi `bodyMedium` — kalıp: `{changed_by adı} · {eylem} — {kayıt türü}`; eylem çevirileri: create → `Ekleme`, update → `Güncelleme`, delete → `Silme`, active-toggle → `Durum değişikliği`; alt: tarih-saat `dd.MM.yyyy HH:mm` `bodySmall`. Dokununca genişler ve `changes` json'u `alan: eski → yeni` satırları olarak gösterilir.
- **Boş durum:** `Kayıt bulunamadı.`

### 3.20 Profil — `ProfileScreen`

- **AppBar:** `Profil`.
- **Bileşenler:** üst kart: baş harfli avatar dairesi (`kPrimaryContainer` zemin, `kPrimary` harf), ad `titleMedium`, e-posta `bodyMedium`/`kTextSecondary`, rol rozeti: `genel_merkez` → `Genel Merkez` (`kPrimaryContainer`/`kPrimary`), `saha` → `Saha` (`kInactiveContainer`/`kInactive`). Altta sürüm satırı `Sürüm 0.1.0` `bodySmall`. En altta tam genişlik `OutlinedButton` kırmızı metinli `Çıkış Yap` (`Icons.logout`). Dokununca dialog: `Çıkış yap` / `Oturumunuz kapatılacak. Devam edilsin mi?` / `Vazgeç` · `Çıkış Yap`. Onayda token silinir, Giriş ekranına dönülür.

---

## 4. Bileşen Kuralları ve Ortak Desenler

### 4.1 Kişi kartı (`PersonListTile`) — tüm kişi listelerinde tek desen

```
┌──────────────────────────────────────────────┐
│ (Avatar: baş harfler)  Ayşe Yılmaz   [Aktif] │
│                        Ankara / Çankaya      │
└──────────────────────────────────────────────┘
```
- Avatar: 40 px daire, `kInactiveContainer` zemin, baş harfler `kTextSecondary` (`AY`).
- 1. satır: `{Ad} {Soyad}` `titleMedium`, tek satır, taşarsa `...`.
- 2. satır `bodyMedium`/`kTextSecondary`: `unit_type`e göre — `ilce_teskilati`: `{İl} / {İlçe}` · `il_teskilati`: `{İl} — İl Teşkilatı` · `temsilcilik`: `{İl} — Temsilcilik`.
- Sağda durum rozeti: `Aktif` (`kSuccessContainer` zemin, `kSuccess` metin) veya `Pasif` (`kInactiveContainer` zemin, `kInactive` metin). Rozet: `bodySmall` w600, yatay 8 / dikey 4 padding, `rFull`.
- Pasif kişide ad metni `kTextSecondary` yapılır (kart soluklaştırılmaz — rozet yeterli).
- Dokunma: Kişi Detayı. Kart `r12`, çerçeve `kBorder`, elevation 0.

### 4.2 Filtre çipleri
`Tümü / Aktif / Pasif` üçlüsü her kişi/üye listesinde aynı sırada, tek seçim. `Aktif`/`Pasif` API'ye `is_active=true/false`, `Tümü` parametresiz. Varsayılan seçim her listede belirtilmiştir (kişi/üye listelerinde `Aktif`, atamalarda `Tümü`).

### 4.3 Form desenleri
- Tüm alanlar `OutlinedInputBorder` (`r8`), etiket `labelText` olarak (floating label), zorunlu alan etiketine `*` **eklenmez** — hata mesajı yeterli.
- Doğrulama: `Kaydet`e basınca tetiklenir (`AutovalidateMode.onUserInteraction` sonrasında alan bazlı). Hata: alan altı kırmızı metin (yukarıdaki mesajlar aynen).
- Tarih seçici: Material `showDatePicker`, `locale: tr_TR`, onay `Tamam`, iptal `Vazgeç`. Alanda gösterim `dd.MM.yyyy`; API'ye `YYYY-MM-DD`.
- Dropdown boş seçeneği (opsiyonel alanlarda): `Seçilmedi`.
- `Kaydet` butonu: ekran altına sabit değil, formun sonunda; kaydetme sırasında buton spinner'a döner ve form kilitlenir.

### 4.4 Biçimler
- **Tarih:** ekranlarda `dd.MM.yyyy` (`01.08.2026`); saat gerekiyorsa `dd.MM.yyyy HH:mm`. `intl` paketi `DateFormat('dd.MM.yyyy', 'tr_TR')`.
- **Telefon:** saklama `05XXXXXXXXX` (11 rakam), gösterim `0532 123 45 67` (`0XXX XXX XX XX`).
- **Sayılar:** binlik ayraç gerekmez (MVP ölçeği küçük).
- **TR arama:** aramalar aksan/harf duyarsız (İ→i, I→ı dönüşümü doğru yapılır).

### 4.5 Yüklenme / hata / boş durum kalıpları (tüm listeler)
- **Yüklenme:** ekran ortasında `CircularProgressIndicator` (`kPrimary`); sayfalamada liste sonunda küçük gösterge. Yenileme: her liste `RefreshIndicator` (aşağı çekince yenile) destekler.
- **Hata:** ortada `Icons.cloud_off_outlined` + `Bir şeyler ters gitti.` `titleMedium` + `Veriler yüklenemedi. İnternet bağlantınızı kontrol edin.` `bodyMedium`/`kTextSecondary` + `Tekrar Dene` `OutlinedButton`.
- **Boş durum:** ortada 48 px soluk ikon + ekrana özel mesaj (yukarıda her ekranda verildi) + varsa aksiyon butonu.
- **Oturum düşmesi (401):** her ekranda ortak yakalanır → token silinir, Giriş ekranına dönüş + snackbar `Oturum süreniz doldu. Lütfen tekrar giriş yapın.`
- **Yetki hatası (403):** snackbar `Bu işlem için yetkiniz yok.`
- **Snackbar süresi:** 3 sn, tekil (yenisi eskisini kapatır).

### 4.6 Ortak sözlük (geliştirici bu metinleri aynen kopyalar)

| Anahtar | Türkçe metin |
|---|---|
| ortak.kaydet | `Kaydet` |
| ortak.vazgec | `Vazgeç` |
| ortak.sil | `Sil` |
| ortak.tamam | `Tamam` |
| ortak.tekrarDene | `Tekrar Dene` |
| ortak.ara | `Ara...` |
| ortak.tumu | `Tümü` |
| ortak.aktif | `Aktif` |
| ortak.pasif | `Pasif` |
| ortak.secilmedi | `Seçilmedi` |
| ortak.bos | `—` |
| ortak.uygula | `Uygula` |
| ortak.temizle | `Temizle` |
| ortak.onayla | `Onayla` |
| ortak.cikar | `Çıkar` |
| ortak.cikisYap | `Çıkış Yap` |
| durum.atandi | `Atandı` |
| durum.devam | `Devam Ediyor` |
| durum.tamamlandi | `Tamamlandı` |
| birim.il | `İl Teşkilatı` |
| birim.ilce | `İlçe Teşkilatı` |
| birim.temsilcilik | `Temsilcilik` |
| hata.genel | `Bir şeyler ters gitti.` |
| hata.ag | `Sunucuya ulaşılamadı. Bağlantınızı kontrol edin.` |
| hata.yetki | `Bu işlem için yetkiniz yok.` |
| hata.oturum | `Oturum süreniz doldu. Lütfen tekrar giriş yapın.` |

Durum eşlemesi (API → ekran): `atandi` → `Atandı`, `devam` → `Devam Ediyor`, `tamamlandi` → `Tamamlandı`.

---

## 5. Rol Farkları (`genel_merkez` vs `saha`)

| Alan / Yetenek | `genel_merkez` | `saha` |
|---|---|---|
| Alt gezinme | 4 sekme (Yönetim, Saha, Raporlar, Profil) | **2 sekme** (Saha Çalışmaları, Profil) — Yönetim Paneli ve Raporlar sekmeleri hiç render edilmez |
| Kişi/üyelik yönetimi (ekle, düzenle, aktif/pasif, üyelikten çıkar) | Evet | Hayır (ekranlara erişimi yok) |
| Görev formu (saha faaliyeti) ekleme/düzenleme | Evet | Evet |
| Saha faaliyeti **silme** | Evet | Hayır (taşma menüsünde `Sil` görünmez) |
| Toplantı ekleme/düzenleme | Evet | Evet |
| Toplantı **silme** | Evet | Hayır |
| Görev atamaları listesi | Görür + FAB ile ekler, dokununca düzenler | Görür (salt okunur; FAB yok, dokunuş salt okunur detay açar) |
| Raporlar (Excel + değişiklik günlüğü) | Evet | Hayır (sekme yok) |
| Profil / çıkış | Evet | Evet |

Uygulama kuralı: rol `login` cevabındaki `user.role`den okunur ve UI **derlenirken** gizlenir (yalnızca butonu devre dışı bırakmak yeterli değildir); API zaten 403 ile ikinci kademe koruma sağlar.

---

## 6. Çözülen Belirsizlikler (kayıt)

1. **Görev Atamaları'nın yeri:** SPEC 2.2(c) gereği Saha Çalışmaları altına üçüncü giriş olarak kondu (2 kart + 1 giriş satırı).
2. **`temsilcilik` birimi:** ile bağlıdır, ilçe seçilmez (`district_id=null`); il detayında "İl Teşkilatı" sekmesinde `Temsilcilik` rozetiyle listelenir.
3. **`saha` rolü navigasyonu:** SPEC rol tanımı gereği Yönetim Paneli ve Raporlar sekmeleri tamamen gizlendi.
4. **Değişiklik günlüğü erişimi:** API'de `genel_merkez` kısıtlı olduğundan Raporlar sekmesi içine alındı.
5. **Varsayılan filtre:** kişi/üye listelerinde `Aktif` (günlük kullanım senaryosu), atama listesinde `Tümü`.
6. **Kurul toplantısı formunda** `body_id` sabittir; komisyon formunda dropdown ile seçilir.
