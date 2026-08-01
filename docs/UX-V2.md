# UX/UI Mimarisi — TYS v2 (Kurumsal Yönetim Bilgi Sistemi)

**Sürüm:** 2.0 · **Tarih:** 2026-08-01
**Kaynaklar:** `docs/SPEC-V2.md` (bağlayıcı), `docs/UX.md` (v1 temeli — **korunur**), `docs/SPEC.md`, `docs/API.md`
**Hedef:** Flutter geliştiricisi bu belgeden hiçbir etiket, akış, durum veya kural uydurmadan v2'yi kodlayabilmelidir. Tüm kullanıcıya görünen metinler bu belgede **aynen** yazıldığı gibi kullanılır.

> **Bu belge `docs/UX.md`'yi genişletir, değiştirmez.** v1'deki tüm token'lar, kişi kartı deseni, form kuralları, yüklenme/hata/boş durum kalıpları, tarih ve telefon biçimleri ve ortak sözlük **aynen geçerlidir**. Aşağıda yalnızca **eklenenler** ve **v2'ye özgü kurallar** yazılıdır. Bir konu burada geçmiyorsa `docs/UX.md` bağlayıcıdır.
>
> **API notu:** `docs/API-V2.md` **yayımlandı ve bağlayıcıdır.** Bu belge ona göre uyumlanmıştır: uç nokta adları, alan adları, zorunluluklar ve durum değerleri API-V2'den; **ekran davranışı, akış ve tüm metinler bu belgeden** alınır. İki belgenin çeliştiği yerler §11'de tek tek listelenmiştir — orada "API notu" olarak işaretlenen maddeler backend tarafında karşılanana kadar arayüz belirtilen **zarif geri düşüşü (graceful fallback)** uygular.

---

## 0. v1 → v2 Değişim Özeti (geliştiriciye tek bakışta)

| Konu | v1 | v2 |
|---|---|---|
| Navigasyon | 4 alt sekme, sabit | 6 hedef, **uyarlanabilir** (alt çubuk / gezinme rayı / genişletilmiş yan panel) |
| Ekran boyutu | yalnız mobil | **mobil + tablet + masaüstü** (3 kırılma noktası) |
| Durum | `Aktif` / `Pasif` | `Aktif` / `Pasif` / **`Teşkilat Yok`** (3 durum) |
| Açılır listeler | kodda sabit | **Tanımlar** modülünden gelen `lookup` verisi |
| Formlar | sabit alanlar | **tek dinamik form kuralı** (§4): kademeli seçim, koşullu alan, matris, seçici |
| Ana ekran | kart menüsü | **Dashboard** (KPI + grafik + filtre çubuğu) |
| Dosya | yok | **fotoğraf / doküman ekleri** (§7) |
| Tema | yalnız açık tema | yalnız açık tema (**değişmedi** — `ThemeMode.light` sabit) |

**Tema kararı (kayıt):** v2'de de karanlık tema **yoktur**. Uygulama kurumsal bir iç sistemdir, v1 ile görsel süreklilik önceliklidir ve grafik paleti yalnız açık zemin (`kSurface #FFFFFF`) için doğrulanmıştır. Karanlık tema v2.1 kapsamındadır; eklendiğinde §1.3 paleti koyu zemine göre yeniden adımlanır (otomatik ters çevirme **yasak**).

---

## 1. Token Eklemeleri

`lib/theme/tokens.dart` dosyasına **eklenir**; mevcut sabitlerin hiçbiri değiştirilmez veya silinmez.

### 1.1 Kırılma noktaları (yeni)

```dart
// Kırılma noktaları — docs/UX-V2.md §1.1
const double kBpMedium   = 600;   // mobil → tablet
const double kBpLarge    = 840;   // iki panelli düzenin açıldığı eşik
const double kBpExpanded  = 1240;  // tablet → masaüstü (genişletilmiş yan panel)
```

Ölçüm **her zaman** `MediaQuery.sizeOf(context).width` ile yapılır (cihaz türü tahmini **yasak** — masaüstü tarayıcı penceresi küçültülünce mobil düzene düşmelidir).

| Sınıf | Genişlik | Adı (kodda) |
|---|---|---|
| Dar | `< 600` | `LayoutClass.compact` |
| Orta | `600 – 839` | `LayoutClass.medium` |
| Geniş | `840 – 1239` | `LayoutClass.large` |
| Çok geniş | `>= 1240` | `LayoutClass.expanded` |

### 1.2 Yeni boşluk / ölçü sabitleri

| Token | Değer | Kullanım |
|---|---|---|
| `s48` | 48 | Masaüstünde bölüm arası büyük boşluk |
| `kRailWidth` | 80 | Gezinme rayı (orta/geniş) |
| `kSidebarWidth` | 256 | Genişletilmiş yan panel (çok geniş) |
| `kContentMaxWidth` | 1200 | Form ve detay ekranlarında içerik en fazla bu genişlikte, ortalanır |
| `kListPaneWidth` | 360 | İki panelli düzende sol liste paneli |
| `kChartMinHeight` | 220 | Grafik kartının en küçük çizim yüksekliği (eksen bandı hariç) |
| `kThumbSize` | 72 | Dosya eki küçük görseli (kare) |

### 1.3 Grafik paleti (yeni — yalnızca grafiklerde kullanılır)

Kategorik seri renkleri. **Sıra sabittir, döngüye sokulmaz**; 8. seriden sonrası `Diğer`e katlanır.

```dart
// Grafik kategorik paleti — docs/UX-V2.md §1.3 (doğrulanmış sıra, değiştirilmez)
const Color kChart1 = Color(0xFF2A78D6); // mavi   — birincil seri
const Color kChart2 = Color(0xFFEB6834); // turuncu
const Color kChart3 = Color(0xFF1BAF7A); // deniz yeşili
const Color kChart4 = Color(0xFFEDA100); // sarı
const Color kChart5 = Color(0xFFE87BA4); // magenta
const Color kChart6 = Color(0xFF008300); // yeşil
const Color kChart7 = Color(0xFF4A3AA7); // mor
const Color kChartOther = Color(0xFF9AA0A6); // "Diğer" ve vurgusuz seriler (= kTextDisabled)

// Grafik kromu
const Color kGridLine = Color(0xFFE2E4E8); // = kBorder, 1 px, DÜZ çizgi (kesikli YASAK)
const Color kAxisLine = Color(0xFFC9CCD1);
```

**Kızılay kırmızısı (`kPrimary`) grafiklerde seri rengi olarak kullanılmaz.** v1 §1.1 kuralının devamıdır: kırmızı marka + hata/silme rengidir; bir çubuğu kırmızı yapmak "kötü/hata" anlamı üretir.

**Doğrulama kaydı:** yukarıdaki 7 renk, `kSurface #FFFFFF` zemininde açık-renk modunda tüm sertlik kontrollerini geçer (komşu çift en kötü renk körlüğü ΔE 9.1; normal görüş ΔE 19.6). `kChart3`, `kChart4` ve `kChart5` zemine karşı 3:1 kontrastın altındadır → **rahatlatma kuralı zorunludur**: bu renkleri kullanan her grafikte ya doğrudan değer etiketi ya da tablo görünümü (§5.6) bulunur. Bu iki mekanizma zaten §5'te her grafik için şart koşulmuştur.

### 1.4 Durum renkleri (grafiklerde ve rozetlerde) — yeni token yok

Üç durum, **mevcut v1 token'larını** kullanır (§3). Kategorik palete **karışmaz**, seri rengi olarak asla kullanılmaz.

| Durum | Zemin | Metin/İşaret | İkon |
|---|---|---|---|
| Aktif | `kSuccessContainer` | `kSuccess` | `Icons.check_circle_outline` |
| Pasif | `kInactiveContainer` | `kInactive` | `Icons.pause_circle_outline` |
| Teşkilat Yok | `kWarningContainer` | `kWarning` | `Icons.location_off_outlined` |

**Zorunlu kural:** Bu üç durum **hiçbir yerde yalnız renkle** anlatılmaz — her zaman **ikon + metin** birlikte gösterilir. (Aktif yeşili ile Teşkilat Yok kehribarı, kırmızı-yeşil renk körlüğünde birbirine yakındır: ΔE 5.7. İkon + etiket eşlemesi bunun telafisidir ve isteğe bağlı değildir.) Aynı kural pasta/halka grafiğinin dilimleri için de geçerlidir: her dilim doğrudan etiketlenir.

### 1.5 Erişilebilirlik (v1 BULGU-2/3'ün kapatılması)

- Her ikon butonuna `Semantics(label: ...)` / `tooltip:` verilir. Örn. filtre ikonu `tooltip: 'Filtrele'`, ek silme `tooltip: 'Eki sil'`.
- Filtre çipleri **daima** `SingleChildScrollView(scrollDirection: Axis.horizontal)` içinde, aralarında `s8` boşlukla; taşma kesilmez, sarmalanmaz.
- Dokunma hedefi min 48×48 (v1 §1.4) — grafik dokunma alanları da dahil (nokta yarıçapı görselde 4 px olsa da vuruş alanı 24 px).
- Grafiklerde renk körlüğü/yazdırma durumu için **Tablo görünümü** her grafik kartında zorunlu (§5.6).

---

## 2. Navigasyon Mimarisi (v2)

### 2.1 Karar ve gerekçe

**Karar: 5 alt sekme + "Daha Fazla" sekmesi (mobil) → 6 hedefli gezinme rayı (tablet/masaüstü).**
Yönetim Paneli **çekmeceye (drawer) konmaz.**

Mobilde 6 üst düzey hedef vardır (5 modül + Profil), alt çubuk ise en fazla 5 taşır. Seçilen desen:

| Sıra | Mobil sekme (`< 600`) | Kapsadığı |
|---|---|---|
| 1 | `Panel` | Raporlama ve Dashboard |
| 2 | `Teşkilat` | Teşkilatlanma |
| 3 | `Saha` | Saha Faaliyetleri |
| 4 | `Lojistik` | Lojistik |
| 5 | `Daha Fazla` | Yönetim Paneli + Profil (+ ileride eklenecekler) |

**Neden çekmece değil, "Daha Fazla" sekmesi:**

1. **Çekmece, geri okuyla çakışır.** v1 §2.2 kuralı gereği her alt ekran AppBar'da geri oku taşır ve her sekme kendi Navigator yığınını korur. Çekmece de aynı sol üst köşeyi ister; iç içe bir ekranda hamburger ile geri oku aynı anda gösterilemez. Çekmeceyi yalnız kök ekranda göstermek, kullanıcının Yönetim Paneli'ne erişimini "önce kök ekrana dön" şartına bağlar.
2. **Keşfedilebilirlik.** Yönetim Paneli, Tanımlar ve Kullanıcı Yönetimi'ni barındırır — sistemin **kurulum ve bakım** merkezidir. v1 denetim raporundaki Y-2 riskinin (kullanıcı yönetimi yokluğu) çözümüdür; gizli bir menüye konmaz.
3. **Rol farkı çekmeceyi boşaltır.** `saha` rolü Yönetim Paneli'ni görmez. Tek elemanı rol nedeniyle gizlenen bir çekmece, kullanıcıların çoğunda **boş** kalır. "Daha Fazla" ise her rolde en az Profil'i taşır.
4. **Tek gezinme modeli, üç ekran boyutu.** "Daha Fazla" gerçek bir ekrandır (`MoreScreen`), yığın açar; ray düzeninde ise **kaybolur** ve iki çocuğu doğrudan hedef olur. Çekmece deseni bu geçişi yapamaz (masaüstünde de gizli menü kalır).
5. **Büyümeye açık.** v2.1'de gelecek Harita ve Bildirimler, navigasyonu yeniden tasarlamadan "Daha Fazla" listesine eklenir.

### 2.2 Uyarlanabilir düzen kuralı (bağlayıcı)

| Genişlik | Gezinme bileşeni | Hedef sayısı | Davranış |
|---|---|---|---|
| `< 600` | `NavigationBar` (altta) | **5** | 5. sekme `Daha Fazla` → `MoreScreen` |
| `600 – 1239` | `NavigationRail` (solda, `kRailWidth` 80, `labelType: all`, `extended: false`) | **6** | `Daha Fazla` **yok**; `Yönetim Paneli` ve `Profil` doğrudan hedeftir |
| `>= 1240` | `NavigationRail` (`extended: true`, `kSidebarWidth` 256, ikon + metin yan yana) | **6** | Aynı 6 hedef, etiketler daima görünür |

Ek kurallar:

- **Tek hedef sıralaması, iki görünüm.** Kodda tek bir `AppDestination` enum'ı vardır: `panel, teskilat, saha, lojistik, yonetim, profil`. Alt çubuk bunun ilk 4'ünü + sanal `daha_fazla` girişini render eder; ray 6'sını da render eder.
- **Yığın korunur.** Her hedef kendi `Navigator`'ına sahiptir (v1 §2.2 kuralı). Kırılma noktası geçişinde **yığınlar korunur**.
- **Kırılma noktası geçişi.** Kullanıcı `< 600`'de `Daha Fazla` kökündeyken pencere `>= 600` olursa → hedef `yonetim`e (rol `saha` ise `profil`e) geçilir. `Daha Fazla` içinden Yönetim Paneli veya Profil yığınına girmişse → o yığın **olduğu gibi** ilgili ray hedefine taşınır, ekran değişmez.
- **`>= 840` iki panelli düzen.** Liste + detay ekranları (kişi listesi/detayı, birim listesi/detayı, faaliyet listesi/formu, tanım listesi/formu) tek `Scaffold` içinde iki panel olur: solda `kListPaneWidth` 360 px liste, sağda detay/form. `< 840`'ta klasik "listeye dokun → yeni sayfa aç" davranışı. **Hangi ekranların iki panelli olduğu §6'da her ekranda ayrıca yazılıdır.**
- **İçerik genişliği.** Form ve detay panelleri `kContentMaxWidth` 1200 px ile sınırlanır ve ortalanır — masaüstünde form alanları ekranı boydan boya germez.
- **AppBar.** Ray düzeninde AppBar korunur (v1 §1.5: `kPrimary` zemin), ancak sol üstteki modül adı ray tarafından zaten verildiğinden AppBar başlığı **ekran** adını taşır.
- **FAB.** `< 600`'de `FloatingActionButton`; `>= 600`'de `FloatingActionButton.extended` (ikon + metin, örn. `Yeni Kayıt`) sağ altta kalır.
- **Klavye (masaüstü).** `Ctrl/Cmd + K` → global arama değil, **aktif listenin arama alanına odak**. `Esc` → açık bottom sheet/dialog kapatır. Form içinde `Ctrl/Cmd + S` → `Kaydet`.

### 2.3 Sekme ikonları ve etiketleri

| Hedef | Etiket (mobil kısa) | Etiket (ray, tam) | İkon (boş / dolu) |
|---|---|---|---|
| `panel` | `Panel` | `Raporlama ve Dashboard` | `Icons.dashboard_outlined` / `Icons.dashboard` |
| `teskilat` | `Teşkilat` | `Teşkilatlanma` | `Icons.account_tree_outlined` / `Icons.account_tree` |
| `saha` | `Saha` | `Saha Faaliyetleri` | `Icons.volunteer_activism_outlined` / `Icons.volunteer_activism` |
| `lojistik` | `Lojistik` | `Lojistik` | `Icons.local_shipping_outlined` / `Icons.local_shipping` |
| `daha_fazla` | `Daha Fazla` | *(ray'da yok)* | `Icons.more_horiz` |
| `yonetim` | *(alt çubukta yok)* | `Yönetim Paneli` | `Icons.settings_outlined` / `Icons.settings` |
| `profil` | *(alt çubukta yok)* | `Profil` | `Icons.person_outline` / `Icons.person` |

Seçili ikon/etiket `kPrimary`, seçili olmayan `kTextSecondary` (v1 §2.1 ile aynı).

### 2.4 Tam ekran ağacı

```
Giriş (LoginScreen)                                   [oturum yoksa tek ekran]
└─ Ana İskelet — AdaptiveShell
   │  < 600  : NavigationBar (5)     |  600–1239 : NavigationRail (6)  |  >= 1240 : genişletilmiş ray (6)
   │
   ├─ 1. PANEL  (Raporlama ve Dashboard)
   │  ├─ E-10  Dashboard                                   [açılış ekranı]
   │  │  ├─ E-11  Bölge Kırılımı (tam liste)
   │  │  ├─ E-12  İl Kırılımı (tam liste)
   │  │  └─ E-13  Grafik Tablo Görünümü (her grafikten açılır, tam sayfa)
   │  ├─ E-14  Rapor Merkezi
   │  │  ├─ E-15  Rapor Önizleme (tablo + sayfalama)
   │  │  └─ E-16  Dışa Aktar (Excel / PDF seçimi)
   │  └─ E-17  Değişiklik Günlüğü               [v1 §3.19 korunur, filtre genişletildi]
   │
   ├─ 2. TEŞKİLATLANMA
   │  ├─ E-20  Teşkilatlanma Ana Ekranı (6 modül kartı)
   │  ├─ E-21  Koordinasyon Kurulu       ─┐
   │  ├─ E-22  Bölge Temsilcileri         │  hepsi aynı iskelet:
   │  ├─ E-23  Komisyonlar                ├─ bilgilendirme metni başlığı (§6.1.1)
   │  ├─ E-24  İl Kadın Başkanlıkları     │  + filtre çipleri (3 durum)
   │  ├─ E-25  İlçe Kadın Başkanlıkları   │  + birim listesi
   │  └─ E-26  Temsilcilikler            ─┘
   │     └─ E-27  Birim Detayı  (ortak — tüm birim türleri)
   │        ├─ sekme "Görevliler" → E-28 Görevlendirme Formu
   │        ├─ sekme "Alt Birimler"  (yalnız il → ilçe/temsilcilik)
   │        ├─ sekme "Ekler"         (§7)
   │        ├─ E-29  Kişi Detayı        [v1 §3.10 + fotoğraf + görev tarihleri]
   │        └─ E-30  Kişi Formu         [v1 §3.9 + fotoğraf + görev tarihleri + 3 durum]
   │
   ├─ 3. SAHA FAALİYETLERİ
   │  ├─ E-40  Saha Faaliyetleri Ana Ekranı (4 modül kartı + son kayıtlar)
   │  ├─ E-41  Görevler Listesi        → E-42  Görev Formu
   │  ├─ E-43  Eğitimler Listesi       → E-44  Eğitim Formu
   │  ├─ E-45  Etkinlikler Listesi     → E-46  Etkinlik Formu
   │  │                                   └─ E-47  Etkinlik Adı Seçici (takvimden)
   │  └─ E-48  Toplantılar Listesi     → E-49  Toplantı Formu
   │     └─ (her formdan) E-70 Ek Ekle · E-71 Ek Görüntüleyici
   │
   ├─ 4. LOJİSTİK
   │  ├─ E-50  Lojistik Ana Ekranı (3 modül kartı + özet şerit)
   │  ├─ E-51  Malzeme Talepleri       → E-52  Talep Formu
   │  ├─ E-53  Gönderiler              → E-54  Gönderi Formu
   │  │                                   └─ E-55  Teslim Bilgisi Girişi
   │  └─ E-56  Stok Durumu             → E-57  Stok Hareketleri (ürün bazlı)
   │
   ├─ 5. YÖNETİM PANELİ            [rol: yalnız genel_merkez]
   │  ├─ E-60  Yönetim Paneli Ana Ekranı (7 modül satırı)
   │  ├─ E-61  Kullanıcı Yönetimi      → E-62  Kullanıcı Formu
   │  ├─ E-63  Tanımlar (kategori listesi)
   │  │  └─ E-64  Tanım Öğeleri (kategori içi liste, sürükle-sırala)
   │  │     └─ E-65  Tanım Öğesi Formu
   │  ├─ E-66  Yetkilendirme (rol ve kapsam)
   │  ├─ E-67  Bildirimler
   │  ├─ E-68  Sistem Ayarları
   │  ├─ E-69  Form Yönetimi (zorunluluk/görünürlük anahtarları)
   │  └─ E-6A  İçerik Yönetimi (bilgilendirme metinleri)
   │
   ├─ 6. PROFİL
   │  └─ E-80  Profil                          [v1 §3.20 + fotoğraf + tema/dil satırı yok]
   │
   └─ (yalnız < 600) E-90  Daha Fazla
      ├─ → Yönetim Paneli (E-60)   [rol: genel_merkez]
      └─ → Profil (E-80)
```

---

## 3. Üç Durumlu Statü Bileşeni

`StatusBadge` — tek bileşen, uygulamadaki **her** durum gösteriminde kullanılır. v1'deki iki durumlu rozet bununla değiştirilir (görünüm birebir korunur, üçüncü durum eklenir).

### 3.1 Değerler ve görünüm

| API değeri | Rozet metni | Zemin | Metin/ikon | İkon (14 px, metnin solunda, `s4` boşluk) |
|---|---|---|---|---|
| `aktif` | `Aktif` | `kSuccessContainer` | `kSuccess` | `Icons.check_circle_outline` |
| `pasif` | `Pasif` | `kInactiveContainer` | `kInactive` | `Icons.pause_circle_outline` |
| `teskilat_yok` | `Teşkilat Yok` | `kWarningContainer` | `kWarning` | `Icons.location_off_outlined` |

Rozet biçimi v1 §4.1 ile aynı: `bodySmall` w600, yatay 8 / dikey 4 padding, `rFull`.
`teskilat_yok` metni tek satırda sığmazsa **kısaltılmaz** — rozet sarmalanır veya kart genişletilir; `Tşk. Yok` gibi kısaltma **yasaktır**.

### 3.2 "Teşkilat Yok" ne demek — anlam kuralı

`teskilat_yok`, **bir teşkilat biriminin var olduğu ama görevli atanmadığı** durumdur (K4: birim kaydı kişi olmadan da vardır). Yönetsel bir **boşluk metriğidir, hata değildir.**

Bağlayıcı yazım kuralları:

- ❌ `kError` / kırmızı ile gösterilmez. ❌ `Icons.error`, `Icons.warning` (ünlem üçgeni) kullanılmaz.
- ❌ Metinlerde `hata`, `eksik`, `sorun`, `uyarı`, `başarısız` kelimeleri **kullanılmaz**.
- ✅ Kullanılacak dil: `Teşkilat Yok`, `Teşkilatlanma boşluğu`, `Henüz görevli atanmamış`, `Teşkilatlanma bekleyen birim`.
- ✅ Bu durum bir **aksiyon davetidir**: gösterildiği her yerde birincil aksiyon `Görevli Ata`dır.

### 3.3 Bağlamlara göre okunuşu

**a) Birim listesinde (E-24/25/26):**
```
┌────────────────────────────────────────────────────────┐
│ ⌂  Ağrı İl Kadın Başkanlığı            [⚑ Teşkilat Yok]│
│    Doğu Anadolu Bölgesi · Ağrı                         │
│    Henüz görevli atanmamış.                            │
│                                        [ Görevli Ata ] │
└────────────────────────────────────────────────────────┘
```
- Avatar yerine birim ikonu (`Icons.location_city_outlined`, `kInactiveContainer` daire içinde).
- 3. satır `bodySmall`/`kTextSecondary`: `Henüz görevli atanmamış.`
- Sağ altta `OutlinedButton` (küçük): `Görevli Ata`. Yalnız `genel_merkez` ve kapsamı uyan rol görür.
- Kart soluklaştırılmaz, gri yapılmaz — **görünür kalır**, çünkü aranan şey odur.

**b) Kişi listesinde:** `teskilat_yok` **bir kişinin durumu olamaz.** Kişi durumu yalnız `aktif`/`pasif` alır. Bu üçüncü durum yalnızca `org_units` kayıtlarına aittir. Form ve API bunu zorlar (§4 R11).

**c) Filtre çiplerinde:** `Tümü` · `Aktif` · `Pasif` · `Teşkilat Yok` (bu sırada, tek seçim).
Varsayılan: birim listelerinde **`Tümü`** (boşluğu görmek asıl amaç); kişi listelerinde v1'deki gibi **`Aktif`** (ve `Teşkilat Yok` çipi kişi listelerinde **hiç render edilmez**).
Çipler yatay kaydırmalı satırda (§1.5).

**d) Dashboard'da:** 3 KPI kutucuğu + halka grafik (§5.2). Kutucuk etiketi `Teşkilat Yok`, alt yazısı `Teşkilatlanma boşluğu`. Kutucuğa dokunuş → E-11/E-12 kırılım listesi, `Teşkilat Yok` filtresi ön seçili.

**e) Raporda (Excel/PDF):** sütun adı `Durum`, hücre değeri `Teşkilat Yok`. Hücre **kırmızı boyanmaz**; kehribar zemin (`#FDF3E0`) kullanılır. Ayrıca özet sayfasında ayrı satır: `Teşkilat Yok (teşkilatlanma boşluğu)`.

### 3.4 Durum değiştirme

Birim detayında (E-27) durum kartı — v1 §3.10 desenine benzer, ama **switch değil, 3'lü segment**:

- Bileşen: `SegmentedButton` — `Aktif` / `Pasif` / `Teşkilat Yok`.
- Onay dialoğu: başlık `Durumu değiştir`, gövde `{Birim adı} durumu "{yeni durum}" olarak güncellenecek. Onaylıyor musunuz?`, aksiyonlar `Vazgeç` / `Onayla`.
- **Kilit kuralı:** birimde en az bir aktif görevlendirme varken `Teşkilat Yok` seçilemez. Segment devre dışı ve altında `bodySmall`/`kTextSecondary`: `Bu birimde aktif görevli bulunduğu için "Teşkilat Yok" seçilemez.`
- Son aktif görevlendirme bitirildiğinde durum **otomatik** `teskilat_yok`a düşer; snackbar: `Birimde görevli kalmadığı için durum "Teşkilat Yok" olarak güncellendi.`
- Başarı snackbar'ı: `Durum güncellendi.` (v1 ile aynı).

---

## 4. Dinamik Form Spesifikasyonu (TEK KURAL)

> **Bu bölüm v2'nin çekirdeğidir.** Uygulamadaki **bütün** formlar (Görev, Eğitim, Etkinlik, Toplantı, Talep, Gönderi, Kişi, Görevlendirme, Tanım, Kullanıcı) tek bir motorla kurulur: `DynamicForm`. Geliştirici her ekran için ayrı form mantığı yazmaz; **yalnızca alan tanımı listesi (`List<FieldSpec>`) yazar.**

### 4.1 Alan tanımı (`FieldSpec`)

```dart
class FieldSpec {
  final String key;                 // API alan adı, ör. 'district_id'
  final String label;               // Ekranda görünen Türkçe etiket (bu belgeden aynen)
  final FieldType type;             // text, multiline, number, decimal, date, dateRange,
                                    // lookup, picker, orgPicker, personPicker, segment,
                                    // matrix, attachment, switchField
  final bool required;              // görünürken zorunlu mu
  final String? lookupCategory;     // type==lookup/picker → 'gorev_turu' vb.
  final String? parentKey;          // KADEMELİ SEÇİM: üst alanın key'i
  final VisibleWhen? visibleWhen;   // KOŞULLU ALAN: {key, equalsCode | inCodes | isNotNull}
  final String? requiredMessage;    // boş bırakılırsa §4.7 kalıbı üretilir
  final String? helper;             // alan altı yardımcı metin
  final String? hint;               // ipucu metni
  final int? maxLength;
}
```

### 4.2 On iki bağlayıcı kural

**R1 — Kademeli seçim (cascade).**
`parentKey` dolu bir alan:
1. Üst alan boşken **devre dışıdır** (`enabled: false`), gri görünür, ipucu metni: `Önce {üst alan etiketi} seçin.`
2. Üst alan seçildiğinde listesi `?parent_id={üst değer}` ile **yeniden yüklenir**. Yükleme sırasında alan kilitli + sağda 16 px spinner.
3. Üst alan **değişirse** çocuk (ve torun) değeri **koşulsuz temizlenir**; onay sorulmaz, snackbar gösterilmez.
4. Üst alan **temizlenirse** çocuk temizlenir ve tekrar devre dışı olur.
5. Formda üst alan **her zaman** çocuğun üstünde durur. İstisna yok.
6. Yeni kayıt açılırken bir üst değer ön dolu geliyorsa (örn. il detayından gelindi) çocuk listesi **hemen** yüklenir.

**R2 — Koşullu alan (göster/gizle).**
`visibleWhen` dolu bir alan:
1. Koşul sağlanmıyorsa alan **DOM'dan kaldırılır** (yalnız opaklık/`enabled` değil — yer kaplamaz).
2. Gizli alan **doğrulanmaz** (`required` göz ardı edilir) ve API gövdesine **`null` olarak** gönderilir — sunucu eski değeri temizleyebilsin diye açıkça `null`.
   **İstisna:** `/meetings` uçlarında `location` ve `platform` alanları, yönteme uymayan taraf gönderilirse sunucu **400** döndürür (API-V2 §6.4). Bu iki alan gizliyken gövdeye **hiç konmaz** (anahtar tamamen atlanır). `FieldSpec` bunu `omitWhenHidden: true` bayrağıyla işaretler; başka hiçbir alanda bu bayrak kullanılmaz.
3. Gizli alanın kullanıcı girdisi **oturum belleğinde tutulur**: koşul tekrar sağlanırsa eski değer geri gelir. (Kullanıcı yöntemi yanlışlıkla değiştirip geri aldığında yazdığını kaybetmez.) Bellek yalnız açık form için geçerlidir; `Kaydet` veya ekrandan çıkışta silinir.
4. Geçiş animasyonu: `AnimatedSize` + `AnimatedOpacity`, **150 ms**, `Curves.easeOut`. Kaydırma konumu korunur.
5. Gizli alanın altındaki hata mesajı varsa gizlenirken **temizlenir**.
6. `visibleWhen` zincirlenebilir: gizli bir alana bağlı alan da gizlidir (özyinelemeli değerlendirme).

**R3 — Görünürken zorunluluk.** `required: true` olan koşullu alan, **yalnız görünür durumdayken** zorunludur. Gizliyken `Kaydet`i bloklamaz.

**R4 — Tek veri kaynağı: Tanımlar.** `type: lookup` her alan listesini `GET /lookups/{category}?is_active=true&parent_id=` ucundan alır. **Kodda sabit liste yazmak yasaktır** (SPEC-V2 §0). Liste boş dönerse: alan devre dışı + `helper` metni
`Bu liste henüz tanımlanmamış. Yönetim Paneli → Tanımlar bölümünden ekleyebilirsiniz.`
(`saha` rolü için: `Bu liste henüz tanımlanmamış. Genel merkez ile iletişime geçin.`)
Listeler oturum başına önbelleğe alınır; `Tanımlar` modülünde kayıt değişince önbellek geçersizleşir.

**R5 — Seçici eşiği (15 kuralı).**
- Seçenek sayısı **≤ 15** → `DropdownButtonFormField` (v1 §4.3 görünümü).
- Seçenek sayısı **> 15** → salt okunur alan + sağda `Icons.chevron_right`; dokununca **aranabilir seçici** açılır (`< 600`: tam sayfa; `>= 600`: 480×560 dialog). Seçicide üstte arama alanı, ipucu `{Alan adı} ara...`, Türkçe harf duyarsız arama (v1 §4.4), sonuç yoksa `Aramanızla eşleşen kayıt bulunamadı.`
- İl (81) ve İlçe (~50) **daima** seçici ile açılır.
- Klavye seçicide açılmaz; alanın kendisi asla yazılabilir değildir.

**R6 — Yalnızca seçim alanları (serbest metin yasağı).**
`type: picker` alanları **hiçbir koşulda** klavye açmaz (`readOnly: true`, `showCursor: false`, `onTap` → seçici). Etkinlik Adı, Görev Türü, Alt Görev, Eğitim Konusu, Toplantı Türü, Ürün, Gönderim Şekli, Şube, Kadın Teşkilatı bu türdendir.
Kullanıcı listede aradığını bulamazsa gösterilecek metin: `Aradığınız kayıt listede yoksa Yönetim Paneli → Tanımlar bölümünden eklenmelidir.` — "yeni ekle" kısayolu forma **konmaz** (yetki ve veri tutarlılığı için).

**R7 — Matris alanı (`type: matrix`).**
İki bağımsız boyut, iki `SegmentedButton` olarak **yan yana (>=600) veya alt alta (<600)** gösterilir; ikisi de zorunludur. Seçilen ikili, alt alandaki listeyi filtreler.
Örnek (Eğitim): `Kategori` (Gönüllü / Halka Açık) × `Yöntem` (Yüz Yüze / Çevrim İçi) → `Konu` listesi `GET /lookups/egitim_konusu?kategori=&yontem=`.
Bir kombinasyon için konu yoksa: Konu alanı devre dışı + helper `Bu kategori ve yöntem için tanımlı konu bulunmuyor.`
Boyutlardan biri değişirse Konu değeri **temizlenir** (R1.3 ile aynı davranış).

**R8 — Doğrulama zamanlaması (v1 §4.3 korunur).** İlk doğrulama `Kaydet`e basınca; sonrasında `AutovalidateMode.onUserInteraction` ile alan bazlı. Hata: alan altında `kError` metin.
`Kaydet`e basıldığında ilk hatalı alana **otomatik kaydırılır** ve odaklanılır. Ayrıca formun en üstünde `kErrorContainer` banner: `Lütfen işaretli alanları doldurun.`

**R9 — Kirli formdan çıkış (v1 §3.9 korunur).** Dialog: `Değişiklikler kaydedilmedi` / `Bu sayfadan çıkarsanız girdiğiniz bilgiler silinecek.` / `Vazgeç` · `Çık`.

**R10 — Kaydet düğmesi.** Formun sonunda, tam genişlik `FilledButton` `Kaydet` (v1 §4.3). `>= 840` iki panelli düzende ise sağ panelin altına **sabitlenmiş** eylem çubuğu (`Vazgeç` `OutlinedButton` + `Kaydet` `FilledButton`, sağa yaslı, üstünde 1 px `kBorder` ayraç). Kaydetme sırasında buton spinner'a döner, form kilitlenir.

**R11 — Alan kilidi.** Bir alan bağlamdan ön dolu geldiyse ve değiştirilmemeliyse (örn. il detayından açılan görevlendirme formunda `İl`) alan **görünür ama devre dışıdır**, sağında `Icons.lock_outline` 14 px `kTextDisabled`. Gizlenmez — kullanıcı hangi bağlamda olduğunu görmelidir.

**R12 — Bölüm başlıkları.** 6'dan fazla alanı olan formlar `titleSmall` bölüm başlıklarıyla ayrılır; başlıklar arası `s24`. Standart bölüm adları: `Konum Bilgileri` · `Faaliyet Bilgileri` · `Sayısal Bilgiler` · `Açıklama` · `Ekler`. Bu adlar dışına çıkılmaz.

### 4.3 Kademeli seçim örnekleri (tam tanım)

#### (a) Bölge → İl → İlçe

| Alan | Tür | Kaynak | Zorunlu | parentKey |
|---|---|---|---|---|
| `Bölge` | lookup (7) → dropdown (≤15) | `GET /regions` | duruma göre | — |
| `İl` | picker (81) | `GET /provinces?region_id=` | Evet | `region_id` |
| `İlçe` | picker | `GET /provinces/:id/districts` | Hayır (varsayılan) | `province_id` |

Davranış:
- Bölge seçilince İl listesi o bölgenin illerine **daralır**.
- **Bölge seçmeden İl seçilebilir.** Bölge boşken İl seçicisi 81 ilin tamamını gösterir; il seçildiğinde **Bölge otomatik dolar** (her il tek bir bölgeye aittir) ve alan kilitlenir (R11, `Icons.lock_outline`), altında `bodySmall`/`kTextSecondary`: `Seçilen ile göre otomatik belirlendi.`
  Bölgeyi tekrar serbest bırakmak için kullanıcı İl'i temizler.
- İl değişirse İlçe temizlenir. İl temizlenirse hem Bölge kilidi kalkar hem İlçe temizlenir.
- İlçe **zorunlu değildir**; il düzeyinde yapılan faaliyet için boş bırakılır. Boş seçenek etiketi: `İl geneli` (`Seçilmedi` yerine — daha anlamlı).

#### (b) Görev Türü → Alt Görev

| Alan | Tür | Kaynak | Zorunlu |
|---|---|---|---|
| `Görev Türü` | picker | `GET /lookups/gorev_turu` (12 ana başlık) | Evet |
| `Alt Görev` | picker | `GET /lookups/alt_gorev?parent_id={gorev_turu_id}` | Evet* |

*Seçilen görev türünün alt görevi yoksa alan **gizlenir** (R2) ve API'ye `null` gider. Alt görev varsa zorunludur.
Boş liste durumunda helper: `Bu görev türü için tanımlı alt görev bulunmuyor.`

#### (c) Toplantı Yöntemi → Toplantı Yeri / Platform  ⟵ **tam kural**

Alanlar ve tam show/hide mantığı:

| Alan | Tür | Görünürlük koşulu | Zorunlu | Doğrulama |
|---|---|---|---|---|
| `Toplantı Yöntemi` | lookup, dropdown (2) `GET /lookups/toplanti_yontemi` | **daima** | Evet | boş → `Toplantı yöntemi seçin.` |
| `Toplantı Yeri` | metin, maxLength 120 → API `location` | `toplanti_yontemi.code == 'yuz_yuze'` | Evet (görünürken) | boş → `Toplantı yerini girin.` · <3 karakter → `Toplantı yeri en az 3 karakter olmalıdır.` |
| `Platform` | dropdown → API `platform` (**metin**, aşağıya bakın) | `toplanti_yontemi.code == 'cevrim_ici'` | Evet (görünürken) | boş → `Platform seçin.` |
| `Platform Adı` | metin, maxLength 60 → API `platform` | `platform == 'Diğer'` | Evet (görünürken) | boş → `Platform adını girin.` |

Kesin davranış tablosu (API-V2 §6.4 alan adlarıyla):

| `toplanti_yontemi` | Toplantı Yeri | Platform | Platform Adı | Gövdeye giden |
|---|---|---|---|---|
| *boş* | gizli | gizli | gizli | `location` ve `platform` **anahtarları hiç konmaz** |
| `yuz_yuze` | **görünür, zorunlu** | gizli | gizli | `location` dolu · `platform` anahtarı **konmaz** |
| `cevrim_ici` | gizli | **görünür, zorunlu** | Platform=`Diğer` ise görünür+zorunlu | `platform` dolu · `location` anahtarı **konmaz** |

- **Anahtar atlama zorunludur** (R2.2 istisnası): sunucu yönteme uymayan alanı reddeder (400).
- Yöntem `yuz_yuze` → `cevrim_ici` değiştirilirse: `Toplantı Yeri` gizlenir, değeri **oturum belleğine alınır** (R2.3). Kullanıcı geri dönerse yazdığı yer geri gelir.
- Uyarı, onay dialoğu veya snackbar **gösterilmez** — sessiz geçiş (R1.3 ile aynı ilke).
- **`platform` API'de serbest metin sütunudur, FK değildir.** Serbest metni asgaride tutma ilkesi (§0) gereği arayüz yine de **dropdown** gösterir: liste `GET /lookups/toplanti_platformu` ile çekilir ve **seçilen öğenin `name` değeri metin olarak** `platform` alanına yazılır.
  **API notu:** `toplanti_platformu` kategorisi API-V2'nin tohumladığı 14 kategori arasında **yoktur**; uç 404 döner. Geri düşüş kuralı: **404 alınırsa** alan serbest metne (`maxLength 60`, ipucu `Örn. Zoom, Microsoft Teams`) döner ve `Platform Adı` alanı hiç gösterilmez. Kategori Tanımlar'dan eklenir eklenmez dropdown kendiliğinden devreye girer — **kod değişikliği gerekmez.** Önerilen tohum: `Zoom`, `Microsoft Teams`, `Google Meet`, `Webex`, `Diğer`.
- `Bağlantı Adresi` alanı **kaldırıldı** — API-V2'de karşılığı olan sütun yoktur. Bağlantı gerekiyorsa `Gündem` alanına yazılır.

#### (d) Eğitim: Kategori × Yöntem matrisi

```
┌─ Eğitim Bilgileri ──────────────────────────────────┐
│  Kategori *                                          │
│  ( Gönüllü ) ( Halka Açık )        ← SegmentedButton │
│                                                      │
│  Yöntem *                                            │
│  ( Yüz Yüze ) ( Çevrim İçi )       ← SegmentedButton │
│                                                      │
│  Konu *                                    [ seç ▸ ] │
│  ↑ Kategori ve Yöntem seçilene kadar devre dışı      │
└──────────────────────────────────────────────────────┘
```
- `Kategori`: `GET /lookups/egitim_kategorisi` — zorunlu. Boş → `Eğitim kategorisi seçin.`
- `Yöntem`: `GET /lookups/egitim_yontemi` — zorunlu. Boş → `Eğitim yöntemi seçin.`
- `Konu`: `GET /lookups/egitim_konusu?kategori_id=&yontem_id=` — zorunlu (>15 olduğu için picker). Boş → `Eğitim konusu seçin.`
- Segmentler 2'şer seçenekten fazlaysa (Tanımlar'dan eklenirse) `SegmentedButton` yerine dropdown'a düşülür — eşik: **3'ten fazla seçenek → dropdown**.
- Yöntem `Çevrim İçi` ise ek alan `Platform` (c) şıkkındaki ile **aynı** kural ve aynı lookup kategorisiyle gösterilir.

#### (e) Etkinlik Adı — takvimden seçim, asla serbest metin

| Alan | Tür | Kaynak | Zorunlu |
|---|---|---|---|
| `Etkinlik Türü` | lookup, dropdown | `GET /lookups/etkinlik_turu` | Evet |
| `Etkinlik Adı` | **picker** (E-47) | `GET /calendar-events?category={etkinlik_turu.code}&year={tarih.yıl}` | Evet |

- `Etkinlik Adı` alanı `readOnly`, `showCursor: false`, sağında `Icons.chevron_right`. **Klavye hiçbir koşulda açılmaz.**
- Seçici (E-47) tam sayfa: üstte arama, altında **aya göre gruplanmış** liste (`Ocak`, `Şubat`, ...). Her satır: etkinlik adı `titleMedium` + altında tarih `bodySmall`/`kTextSecondary` (`dd MMMM` biçimi, ör. `23 Nisan`). Hicri takvime bağlı etkinliklerde (K6 `is_fixed=0`) tarih o yılın tablosundan gelir; yıl tablosunda kayıt yoksa tarih yerine `Tarih girilmemiş` yazılır ve satır seçilebilir kalır.
- `Tarih` alanı değişirse ve seçili etkinliğin o yıl karşılığı yoksa → Etkinlik Adı **temizlenir**, snackbar: `Seçilen tarihe göre etkinlik listesi güncellendi.` (Bu, R1.3'ün tek istisnasıdır: kullanıcı tarihi değiştirdiğinde neden temizlendiğini bilmelidir.)
- Boş durum: `Bu tür için takvimde etkinlik bulunmuyor.` + alt metin `Etkinlik takvimi Yönetim Paneli → Tanımlar bölümünden yönetilir.`

### 4.4 Sayısal alan kuralları

| Alan tipi | Klavye | Kural | Hata mesajı |
|---|---|---|---|
| Sayı (kişi sayıları) | `TextInputType.number`, yalnız rakam | 0 dahil, üst sınır 999.999 | boş → `{Alan adı} girin.` · rakam dışı → `Geçerli bir sayı girin.` · negatif/aşım → `0 ile 999.999 arasında bir değer girin.` |
| `Süre (saat)` | `decimal` | Ekranda Türkçe **virgüllü** ondalık (`2,5`), 0,5 adım önerilir. API alanı `duration_hours` ve **ondalık saat** bekler → gönderirken virgül noktaya çevrilir (`2,5` → `2.5`), okurken tersi. Dakikaya çevirme **yapılmaz**. | boş → `Süre girin.` · geçersiz → `Süreyi saat cinsinden girin (örn. 2,5).` |
| `Miktar` (lojistik) | `number` | ≥ 1 | boş/0 → `Miktar girin.` |

Gösterimde binlik ayraç **kullanılır** (v1 §4.4 güncellenir — v2 ölçeği büyük): `1.284` (nokta ayraç, `tr_TR`). Grafik eksenlerinde ve tablo sütunlarında `tabular-nums`; KPI kutucuğundaki büyük sayıda **orantılı rakam** kullanılır.

### 4.5 Tarih ve tarih aralığı

- Tek tarih: v1 §4.3 (Material `showDatePicker`, `locale: tr_TR`, gösterim `dd.MM.yyyy`, API `YYYY-MM-DD`).
- `Tarih Aralığı`: `showDateRangePicker`. Alan gösterimi `dd.MM.yyyy – dd.MM.yyyy`. Boşken ipucu `Tarih aralığı seçin`.
- Hazır aralık kısayolları (filtre çubuğunda çip olarak): `Bu Ay` · `Son 3 Ay` · `Bu Yıl` · `Özel`.
- Bitiş < başlangıç → `Bitiş tarihi başlangıç tarihinden önce olamaz.`
- Gelecek tarih: faaliyet kayıtlarında **yasak** → `İleri tarihli kayıt girilemez.` (Toplantı ve etkinlik planı için istisna yok; v2'de planlama yoktur.)

### 4.6 Kişi ve birim seçicileri

- `type: personPicker` → v1 §3.5'teki arama listesi deseni (300 ms debounce, kişi kartı). Çoklu seçimde seçilenler alanın altında `Chip` olarak, her birinde `Icons.close`.
- `type: orgPicker` → birim seçici; arama + tür filtresi. Satır: birim adı `titleMedium` + altında `{Bölge} · {İl} · {İlçe}` `bodySmall`, sağda `StatusBadge`.

### 4.7 Otomatik hata mesajı kalıbı

`requiredMessage` verilmemişse motor şu kalıbı üretir:
- Seçim alanları (`lookup`, `picker`, `segment`, `orgPicker`, `personPicker`, `date`): **`{Etiket} seçin.`**
- Yazılan alanlar (`text`, `multiline`, `number`, `decimal`): **`{Etiket} girin.`**

Etiketteki ` (isteğe bağlı)` eki mesaja **taşınmaz**. Zorunlu alan etiketine `*` **eklenmez** (v1 §4.3).

---

## 5. Dashboard (E-10) — "Dashboard Odaklı Yönetim"

Giriş sonrası açılan **ilk ekrandır** (rol `saha` hariç — §8).

**Veri kaynakları (API-V2 §11 ve §4):**

| Bölüm | Uç nokta | Durum |
|---|---|---|
| 1 — Durum KPI + halka | `GET /dashboard/summary` → `organization.org_units` | ✔ hazır |
| 2 — Bölge yığılmış çubuk | `GET /org-units/summary` → `by_region` (3 durum da var) | ✔ hazır |
| 2 — İl sıralı çubuk | **yok** → geri düşüş: `GET /org-units?type=il_baskanligi&limit=1000` çekilip istemcide sayılır | ⚠ API notu N-1 |
| 3 — Faaliyet KPI | `GET /dashboard/summary` → `activity` | ✔ hazır |
| 3 — Görev türü sıralaması | `GET /dashboard/summary` → `top_task_types` | ✔ hazır |
| 3 — Aylık trend | **yok** → kart gizlenir | ⚠ API notu N-2 |
| 4 — Eğitim matrisi | **yok** → 4 ayrı `GET /trainings?category_id=&method_id=&limit=1` çağrısının `total` değeri | ⚠ API notu N-3 |
| 5 — Lojistik KPI + ürün çubuğu | `GET /dashboard/summary` → `logistics` (ürün kırılımı **yok** → `GET /shipments?limit=1000` istemcide gruplanır) | ⚠ API notu N-4 |

Ayrıntı ve geri düşüş kuralları §11'de.

`GET /dashboard/by-region` ucu **faaliyet** kırılımı verir (`tasks`, `trainings`, `events`, `meetings`); Bölüm 2'deki teşkilatlanma çubuğu için değil, Bölüm 3'ün bölge kırılımı sekmesi için kullanılır.

### 5.1 Düzen

```
┌─ AppBar: Dashboard ──────────────────── [⟳] [⇩ Dışa Aktar] ─┐
├─ FİLTRE ÇUBUĞU  (tek satır, HER ŞEYİ kapsar — §5.5)         │
├─ Bölüm 1: Teşkilatlanma Durumu   → 3 KPI + halka grafik      │
├─ Bölüm 2: Teşkilatlanma Kırılımı → bölge yatay çubuk         │
│                                    + il sıralı çubuk (ilk 10)│
├─ Bölüm 3: Faaliyet Özeti         → 5 KPI + aylık trend       │
├─ Bölüm 4: Eğitim Dağılımı        → 2×2 matris tablosu        │
└─ Bölüm 5: Lojistik               → 3 KPI + ürün çubuğu       │
```

**Izgara (grid) kuralı — KPI kutucukları:**

| Genişlik | Sütun | Kutucuk yüksekliği |
|---|---|---|
| `< 600` | **2** | 96 |
| `600 – 839` | 3 | 104 |
| `840 – 1239` | 4 | 104 |
| `>= 1240` | 5 | 112 |

**Izgara kuralı — grafik kartları:** `< 840` → **1 sütun (tam genişlik)**; `840 – 1239` → 2 sütun; `>= 1240` → 2 sütun (kart en fazla 720 px). Halka grafik kartı hiçbir boyutta 1 sütundan geniş olmaz.

Bölüm başlıkları `titleSmall`, üstünde `s24` boşluk. Kartlar v1 §1.4: elevation 0 + 1 px `kBorder`, `r12`.

### 5.2 Bölüm 1 — Teşkilatlanma Durumu

**KPI kutucukları (3):** `StatTile` sözleşmesi — üstte etiket `bodySmall`/`kTextSecondary`, ortada büyük sayı `headlineSmall` w600 (orantılı rakam), altında yüzde `bodySmall`.

| Etiket | Alt yazı | Değer | Renk vurgusu |
|---|---|---|---|
| `Aktif` | `Toplamın %{n}'i` | aktif birim sayısı | sol kenarda 3 px `kSuccess` şerit + `Icons.check_circle_outline` |
| `Pasif` | `Toplamın %{n}'i` | pasif birim sayısı | 3 px `kInactive` şerit + `Icons.pause_circle_outline` |
| `Teşkilat Yok` | `Teşkilatlanma boşluğu` | boş birim sayısı | 3 px `kWarning` şerit + `Icons.location_off_outlined` |

Her kutucuk dokunulabilir → E-12 (İl Kırılımı), o durum filtresi ön seçili. Kutucukta `Icons.chevron_right` 16 px sağ altta.

**Grafik: `Durum Dağılımı` — halka (donut) grafik.**
- Neden halka: 3 dilim, parça-bütün ilişkisi, "boşluk toplamın ne kadarı" sorusu. (3 dilim halka için üst sınır 6'nın altındadır — kabul.)
- Renkler: `kSuccess` / `kInactive` / `kWarning` (durum renkleri, kategorik palet **değil**).
- **Her dilim doğrudan etiketlenir**: halkanın dışında `{Durum} · {sayı} (%{oran})`, çekme çizgisiyle (leader line, 1 px `kAxisLine`). Dilim %5'in altındaysa etiket dışarı taşınır, dilim içine yazılmaz.
- Halkanın ortasında toplam: sayı `headlineSmall` + altında `Toplam Birim` `bodySmall`.
- Dilimler arası **2 px `kSurface` boşluk** (kenarlık çizilmez).
- Legend: 3 satır, her satırda ikon + renk noktası + etiket + sayı. Renk tek başına anlam taşımaz (§1.4).

### 5.3 Bölüm 2 — Teşkilatlanma Kırılımı

**Grafik A: `Bölge Bazlı Teşkilatlanma` — yatay yığılmış çubuk.**
- 7 bölge = 7 satır. Her satır 3 segment: Aktif / Pasif / Teşkilat Yok (durum renkleri).
- **Yatay** seçilmesinin nedeni: bölge adları uzundur (`Doğu Anadolu Bölgesi`); dikey sütunda eksen etiketi döndürmek gerekirdi — **eksen etiketi döndürmek yasaktır**.
- Çubuk kalınlığı ≤ 24 px, veri ucu 4 px yuvarlatılmış, taban kare. Segmentler arası 2 px `kSurface` boşluk.
- Satır sonunda toplam sayı `bodySmall`/`kTextSecondary`. Segment içi etiket **yalnız sığıyorsa** yazılır (min 28 px genişlik), sığmazsa tooltip + tablo görünümüne bırakılır.
- Sıralama: `Teşkilat Yok` sayısına göre **azalan** (yönetsel öncelik). Sıralama seçici (`Bölge adı` / `Teşkilat Yok`) kartın sağ üstünde.
- Satıra dokunuş → E-11 Bölge Kırılımı, o bölge seçili.

**Grafik B: `İl Bazlı Teşkilatlanma` — yatay sıralı çubuk (ilk 10).**
> **⚠ API notu N-1.** İl kırılımı ucu yoktur. Geri düşüş: açılışta bir kez `GET /org-units?type=il_baskanligi&limit=1000` çekilir, sayım istemcide yapılır ve oturum boyunca önbellekte tutulur (81 satır, kabul edilebilir). `GET /dashboard/by-province` eklenirse doğrudan ona geçilir; **ekran değişmez.**
- **Tek seri** (`Teşkilat Yok` birim sayısı) → tek renk: `kWarning`. Legend **yok** (tek seri), başlık zaten neyi çizdiğini söyler.
- Değerler çubuk ucunda doğrudan etiketlenir.
- Kart altında `Tümünü Gör (81 il)` `TextButton` → E-12.
- **Yasak:** çubukları büyüklüğe göre koyulaştırmak (değer zaten uzunlukta kodlu). Hepsi tek renk.
- Harita görünümü v2.1 kapsamındadır (SPEC-V2 §5) — bu ekranda **yer tutucu bile konmaz**.

### 5.4 Bölüm 3, 4, 5

**Bölüm 3 — Faaliyet Özeti. KPI kutucukları (5):**

| Etiket | Alt yazı | Kaynak |
|---|---|---|
| `Gönüllü` | `Faaliyetlere katılan` | toplam gönüllü sayısı |
| `Faaliyet` | `Görev kaydı` | görev sayısı |
| `Eğitim` | `Düzenlenen eğitim` | eğitim sayısı |
| `Etkinlik` | `Düzenlenen etkinlik` | etkinlik sayısı |
| `Toplantı` | `Yapılan toplantı` | toplantı sayısı |

Her kutucukta isteğe bağlı değişim satırı: `▲ %12` veya `▼ %4` + `bodySmall`/`kTextSecondary` `önceki döneme göre`. Yön rengi: artış `kSuccess`, azalış `kInactive` (**kırmızı değil** — faaliyet azalması hata değildir). Karşılaştırma dönemi filtredeki aralığın bir öncekidir; aralık seçilmemişse değişim satırı **gösterilmez**.

**Ek liste: `En Çok Yapılan Görev Türleri`** — `top_task_types` dizisinden ilk 5 satır: sıra numarası + görev türü adı `bodyLarge` + sağda sayı `tabular-nums` + altında ince oran çubuğu (`kChart1`, en büyük değere göre %100). Grafik kartı değil, KPI ızgarasının altında sade liste. Boşsa bölüm gizlenir.

**Grafik: `Aylık Faaliyet Trendi` — çizgi grafik.**
> **⚠ API notu N-2 — bu kart v2'nin ilk sürümünde GİZLENİR.** Aylık zaman serisi döndüren bir uç yoktur ve 12 ay × 4 tür için istemci tarafında 48 istek atmak kabul edilemez. `GET /dashboard/by-month?from=&to=&metric=` eklenene kadar kart **hiç render edilmez** (yer tutucu, "yakında" metni veya boş kart **konmaz**). Aşağıdaki şartname, uç eklendiğinde uygulanmak üzere hazırdır.

- Kartın üstünde `SegmentedButton`: `Faaliyet` · `Eğitim` · `Etkinlik` · `Toplantı` — **aynı anda tek seri** çizilir.
- Tek seri gerekçesi: mobil sütunda 4 çizgi okunmaz; ayrıca dört ölçünün ölçeği farklıdır → **çift eksen yasağı** (asla iki y ekseni).
- Çizgi 2 px, yuvarlak uç/birleşim; nokta yarıçapı ≥ 4 px, 2 px `kSurface` halka.
- Yalnız **son nokta** doğrudan etiketlenir; kalan değerler eksen + tooltip + tablo görünümünden okunur.
- Renk: `kChart1`. Legend yok (tek seri).
- Yatay eksen: ay kısaltmaları (`Oca`, `Şub`, ...). Dikey eksen: yuvarlak sayılar, binlik ayraçlı. Izgara çizgileri 1 px `kGridLine`, **düz** (kesikli yasak).

**Bölüm 4 — `Eğitim Dağılımı (Kategori × Yöntem)` — 2×2 matris tablosu.**
Grafik değil **tablo** seçilmesinin nedeni: 4 hücre için grafik gereksizdir, sayı doğrudan okunur.
> **⚠ API notu N-3.** Kesişim sayıları için uç yoktur. Geri düşüş: 4 kesişim için `GET /trainings?category_id=&method_id=&limit=1` çağrılır ve yanıtın **`total`** alanı okunur (veri gövdesi indirilmez). Toplamlar istemcide hesaplanır. Kategori/yöntem tanımları ikiden fazlaysa matris `n × m` büyür ve çağrı sayısı `n × m` olur; **6'yı aşarsa bölüm gizlenir** ve yerine `Rapor Merkezi`ne bağlantı konur.

```
                  Yüz Yüze    Çevrim İçi    Toplam
  Gönüllü            124           38         162
  Halka Açık          87           15         102
  Toplam             211           53         264
```
- Başlık satırı/sütunu `titleSmall`, hücreler `bodyLarge` `tabular-nums`, toplam satırı/sütunu w600 ve `kBackground` zemin.
- Hücreye dokunuş → E-15 Rapor Önizleme, o kesişim filtresiyle.
- `< 600`'de tablo yatay kaydırmalıdır (`overflow-x`), sayfa kaymaz.

**Bölüm 5 — Lojistik. KPI kutucukları (3):** `Talep` (`Açık talep` = `logistics.requests.talep + onaylandi`), `Gönderi` (`Yola çıkan` = `logistics.shipments.count`), `Stok` (`Toplam ürün adedi` = `logistics.stock.total_quantity`). `logistics.stock.low_stock > 0` ise `Stok` kutucuğunun altında `bodySmall`/`kWarning`: `{n} üründe stok kritik.` ve kutucuk E-56'ya `Yalnız azalanlar` filtresiyle gider.

**Grafik: `Ürün Bazlı Gönderim` — yatay çubuk, ilk 8 ürün + `Diğer`.**
> **⚠ API notu N-4.** Ürün kırılımı ucu yoktur. Geri düşüş: `GET /shipments?limit=1000` çekilip `product_name` üzerinden istemcide gruplanır. Toplam gönderi sayısı 1000'i aşarsa (yanıt `total > 1000`) kart gizlenir ve yerine `bodySmall`/`kTextSecondary` `Ürün kırılımı için Rapor Merkezi'ni kullanın.` + `Rapor Merkezi` `TextButton` konur.
- Tek seri (gönderilen miktar) → tek renk `kChart1`. 9. ve sonraki ürünler **`Diğer`** satırına toplanır, rengi `kChartOther`. Yeni renk üretilmez.
- Değerler çubuk ucunda etiketli.

### 5.5 Filtre çubuğu (tek satır, tüm dashboard'u kapsar)

**Kural: filtre kartların içinde değil, hepsinin üstünde tek yerdedir.** Bir filtre değişince **tüm** bölümler aynı dilime göre yeniden çizilir.

| Genişlik | Sunum |
|---|---|
| `>= 840` | Yapışkan (sticky) tek satır: 5 açılır kontrol yan yana + sağda `Temizle` `TextButton` |
| `600 – 839` | Aynı satır, kontroller kaydırmalı |
| `< 600` | **Özet çip satırı** (yatay kaydırmalı) + sağda `Icons.tune` `Filtreler` düğmesi → tam ekran bottom sheet |

Filtreler (sıra sabit):

| # | Etiket | Tür | Varsayılan | Bağımlılık |
|---|---|---|---|---|
| 1 | `Bölge` | çoklu seçim (7) | `Tümü` | — |
| 2 | `İl` | çoklu seçim, aranabilir | `Tümü` | Bölge seçiliyse daralır (R1) |
| 3 | `İlçe` | tekli seçim, aranabilir | `Tümü` | **Tek il** seçiliyken etkin; il seçilmemişse devre dışı + helper `İlçe filtresi için önce il seçin.` |
| 4 | `Tarih Aralığı` | tarih aralığı + hazır çipler | `Bu Yıl` | → `from` / `to` |
| 5 | `Faaliyet Türü` | tekli seçim `GET /lookups/gorev_turu` | `Tümü` | → `task_type_id` |

**⚠ API kısıtı — filtrelerin kapsamı (bağlayıcı).** `GET /dashboard/summary` yalnız `region_id`, `province_id`, `from`, `to` parametrelerini alır. Bu nedenle:

| Filtre | Dashboard grafiklerine etkisi | Detay/liste ekranlarına etkisi |
|---|---|---|
| `Bölge`, `İl`, `Tarih Aralığı` | **uygulanır** | uygulanır |
| `İlçe`, `Faaliyet Türü` | **uygulanmaz** (uç desteklemiyor) | uygulanır |

`İlçe` veya `Faaliyet Türü` seçiliyken Bölüm 1–5 grafiklerinin **üstünde** tek bir bilgi satırı (`kWarningContainer`, `Icons.info_outline`) görünür, metin **aynen**:
`İlçe ve faaliyet türü filtreleri özet grafiklere uygulanmaz; ayrıntı listelerinde geçerlidir.`
Bu satır yalnız o iki filtre seçiliyken görünür. Grafikler **sessizce yanlış veri göstermez** — uygulanmayan filtre kullanıcıya söylenir.
`Bölge`/`İl` çoklu seçimde birden fazla değer seçilirse uç tek değer aldığından **yalnız ilk seçili** değer gönderilir ve aynı bilgi satırına ek cümle eklenir: `Özet grafiklerde tek bölge/il dikkate alınır.` (Bu kısıt N-5 olarak §11'de kayıtlıdır.)

- Bottom sheet başlığı `Filtreler`; altında sabit iki buton: `Temizle` (`OutlinedButton`) · `Uygula` (`FilledButton`). (v1 §3.12 deseni.)
- Aktif filtre sayısı `Filtreler` düğmesinin üstünde küçük `kPrimary` rozet olarak gösterilir.
- Özet çip satırı yalnız **seçili** filtreleri gösterir, her çipte `Icons.close` ile tekil kaldırma. Hiç filtre yoksa çip satırı yerine `bodySmall`/`kTextSecondary`: `Tüm kayıtlar gösteriliyor.`
- Filtreler URL/oturum durumunda tutulur; kullanıcı Dashboard'dan çıkıp dönünce **korunur** (uygulama kapanınca sıfırlanır).
- Yenileme sırasında **iskelet (skeleton) gösterilmez**: önceki çizim `opacity: 0.4` ile yerinde tutulur, üstünde ince `LinearProgressIndicator`. Düzen zıplaması yasak.

### 5.6 Her grafik kartının ortak sözleşmesi

Her grafik kartı **istisnasız** şunları taşır:

1. Başlık `titleMedium`; gerekiyorsa alt başlık `bodySmall`/`kTextSecondary` (ör. `Bu yıl · 7 bölge`).
2. Sağ üstte taşma menüsü (`⋮`): `Tablo görünümü` · `Görseli kaydet` · `Excel'e aktar`.
3. **Tablo görünümü zorunludur** (E-13): grafikteki her değerin okunabildiği basit tablo. Renk körlüğü, yazdırma ve `kChart3/4/5` düşük kontrast durumunun telafisidir.
4. Dokunma/üzerine gelme: ilgili işaretin tooltip'i — `{kategori} · {seri}: {değer}`. Dokunma alanı ≥ 24 px. Tooltip **tek okuma yolu değildir** (kural 3).
5. Boş durum (veri yok): grafik yerine ortada `Icons.bar_chart_outlined` 48 px `kTextDisabled` + `Seçilen filtrelerle gösterilecek veri bulunamadı.` + `Filtreleri Temizle` `TextButton`.
6. Hata durumu: v1 §4.5 hata kalıbı, kart içinde.
7. Yükseklik: çizim alanı en az `kChartMinHeight` 220 px; **eksen etiketi bandı buna dahil değildir** — kart yüksekliği çizim + eksen bandını kapsar, kart içinde dikey kaydırma çubuğu oluşmaz.
8. Metin asla seri rengini giymez — etiketler, değerler ve legend `kTextPrimary`/`kTextSecondary`; kimliği yanındaki renkli işaret taşır. (İstisna: dolgu içine yazılan etiket, dolgunun parlaklığına göre beyaz veya `kTextPrimary`.)

**Flutter notu:** `fl_chart` paketi kullanılır (`PieChart`, `BarChart`, `LineChart`). Yukarıdaki işaret ölçüleri şu alanlara karşılık gelir: çubuk kalınlığı `BarChartRodData.width` (≤24), yuvarlak uç `borderRadius: BorderRadius.vertical(top: Radius.circular(4))`, segment boşluğu için segmentler arası 2 px `kSurface` dolgu parçası, ızgara `FlGridData(drawVerticalLine: false, getDrawingHorizontalLine: → Colors kGridLine, strokeWidth: 1, dashArray: null)`.

---

## 6. Ekran Şartnameleri

Her ekran için: **Amaç · AppBar · Bileşenler · Boş durum · Birincil aksiyonlar**, v1 §3 kalıbıyla. Yüklenme/hata/401/403 davranışları v1 §4.5'ten gelir ve tekrar yazılmaz.

### 6.1 Modül: Teşkilatlanma

#### 6.1.1 Bilgilendirme metni başlığı (6 alt modülün ortak bileşeni)

`InfoBlockHeader` — E-21…E-26'nın **hepsinde**, listenin üstünde.

- Kaynak: `GET /content-blocks/:key` (API-V2 §10).
- **Bilgilendirme metni yalnız Teşkilatlanma'da değildir** — API 13 anahtar tohumlar; bileşen aşağıdaki **her** ekranın başında kullanılır:

| Anahtar | Ekran |
|---|---|
| `teskilatlanma.koordinasyon_kurulu` | E-21 |
| `teskilatlanma.bolge_temsilcileri` | E-22 |
| `teskilatlanma.komisyonlar` | E-23 |
| `teskilatlanma.il_baskanliklari` | E-24 |
| `teskilatlanma.ilce_baskanliklari` | E-25 |
| `teskilatlanma.temsilcilikler` | E-26 |
| `saha.gorevler` | E-41 |
| `saha.egitimler` | E-43 |
| `saha.etkinlikler` | E-45 |
| `saha.toplantilar` | E-48 |
| `lojistik.genel` | E-50 |
| `raporlama.genel` | E-14 |
| `yonetim.genel` | E-60 |
- Görünüm: `kPrimaryContainer` zeminli kart, `r12`, solda 3 px `kPrimary` şerit, sol üstte `Icons.info_outline` `kPrimary` 20 px. Başlık `titleSmall`/`kTextPrimary`, gövde `bodyMedium`/`kTextPrimary`.
- **Katlanır:** varsayılan olarak gövde 3 satır gösterilir; altında `TextButton` `Daha fazla göster` ↔ `Daha az göster`. Kullanıcı bir kez kapattıysa (`Icons.close` sağ üstte) o anahtar için kapalı kalır (yerel tercih, `SharedPreferences`, anahtar `info_block_dismissed_{key}`). Kapalıyken AppBar'da `Icons.info_outline` düğmesi ile geri açılır (`tooltip: 'Bilgilendirme metnini göster'`).
- Metin yoksa (`404` veya boş `body`): bileşen **hiç render edilmez** (yer tutucu, "metin bulunamadı" gibi bir şey gösterilmez).
- Metinler `genel_merkez` tarafından E-6A İçerik Yönetimi'nden düzenlenir.

#### E-20 · Teşkilatlanma Ana Ekranı — `OrgHomeScreen`

- **Amaç:** 6 alt modüle giriş + teşkilatlanma özeti.
- **AppBar:** `Teşkilatlanma`.
- **Bileşenler:** Üstte ince özet şerit — 3 küçük sayı yan yana: `Aktif {n}` · `Pasif {n}` · `Teşkilat Yok {n}` (durum renkleriyle, ikonlu). Altında 6 gezinme kartı (`< 600`: 1 sütun tam genişlik; `>= 600`: 2 sütun; `>= 1240`: 3 sütun). Kart deseni v1 §3.2 (ikon solda `kPrimary`, sağda `chevron_right`):

| Kart | Alt yazı | İkon |
|---|---|---|
| `Koordinasyon Kurulu` | `Kurul üyeleri ve görevlendirmeleri` | `Icons.account_balance_outlined` |
| `Bölge Temsilcileri` | `7 bölge ve temsilcileri` | `Icons.map_outlined` |
| `Komisyonlar` | `Komisyonlar ve üyelikleri` | `Icons.diversity_3_outlined` |
| `İl Kadın Başkanlıkları` | `81 il başkanlığı` | `Icons.location_city_outlined` |
| `İlçe Kadın Başkanlıkları` | `İlçe başkanlıkları` | `Icons.holiday_village_outlined` |
| `Temsilcilikler` | `İl ve ilçe temsilcilikleri` | `Icons.storefront_outlined` |

- **Boş durum:** yok (kartlar statik). Özet şerit veri yokken `—` gösterir.
- **Birincil aksiyon:** kart dokunuşu.

#### E-21 · Koordinasyon Kurulu — `CoordinationBoardScreen`

- **Amaç:** Kurulun görevlilerini yönetmek. `GET /org-units?type=koordinasyon_kurulu` (tek birim) + `GET /org-units/:id/assignments`.
- **AppBar:** `Koordinasyon Kurulu`.
- **Bileşenler:** InfoBlockHeader (`teskilatlanma.koordinasyon_kurulu`) → filtre çipleri `Tümü / Aktif / Pasif` (kurul birim değil kişi listesidir; `Teşkilat Yok` çipi **yok**) → görevli kartları. Kart: v1 §4.1 kişi kartı + fotoğraf varsa avatar yerine fotoğraf + ad altında **görev unvanı** `bodySmall`/`kTextSecondary` + ikinci satırda görev tarihleri `{dd.MM.yyyy} – {dd.MM.yyyy}` (bitiş boşsa `{dd.MM.yyyy} – devam ediyor`).
- Kart taşma menüsü (`⋮`): `Düzenle` · `Görevi Sonlandır` · `Görevden Çıkar`.
  - `Görevi Sonlandır` → tarih seçici dialog: başlık `Görevi sonlandır`, gövde `Görev bitiş tarihini seçin.`, aksiyon `Vazgeç` / `Kaydet`.
  - `Görevden Çıkar` → onay: `Görevden çıkar` / `Bu kişi listeden kaldırılacak. Devam edilsin mi?` / `Vazgeç` · `Çıkar` (kırmızı).
- **Boş durum:** `Icons.group_off_outlined` + `Kurulda görevli bulunmuyor.` + `Görevli Ata` butonu.
- **Birincil aksiyon:** FAB `Görevli Ata` (`Icons.person_add`) → E-28. Yalnız `genel_merkez`.

#### E-22 · Bölge Temsilcileri — `RegionRepsScreen`

- **Amaç:** 7 coğrafi bölge ve temsilcileri. `GET /regions` + `GET /org-units?type=bolge_temsilciligi`.
- **AppBar:** `Bölge Temsilcileri`.
- **Bileşenler:** InfoBlockHeader (`teskilatlanma.bolge_temsilcileri`) → filtre çipleri **4'lü** (`Tümü / Aktif / Pasif / Teşkilat Yok`, varsayılan `Tümü`) → 7 bölge kartı. Kart: bölge adı `titleMedium`, altında `{n} il` `bodySmall`, sağda `StatusBadge`; temsilci varsa 3. satırda `Icons.person_outline` + temsilcinin adı, yoksa `Henüz görevli atanmamış.` (§3.3a).
- **İki panelli (`>= 840`):** solda 7 bölge listesi, sağda seçili bölgenin detayı (E-27).
- **Boş durum:** olmaz (7 bölge tohum veridir). Filtre sonucu boşsa: `Seçilen duruma uyan bölge bulunmuyor.`
- **Birincil aksiyon:** kart dokunuşu → E-27 Birim Detayı.

#### E-23 · Komisyonlar — `CommissionsScreen`

- **Amaç:** Komisyon listesi ve üyelikleri. `GET /org-units?type=komisyon`.
- **AppBar:** `Komisyonlar`.
- **Bileşenler:** InfoBlockHeader (`teskilatlanma.komisyonlar`) → 4'lü filtre çipleri → komisyon kartları (ad `titleMedium`, `{n} üye` `bodySmall`, `StatusBadge`, `chevron_right`).
- **Boş durum:** `Henüz komisyon tanımlanmamış.` (v1 §3.3 ile aynı metin).
- **Birincil aksiyon:** kart → E-27. FAB `Yeni Komisyon` (yalnız `genel_merkez`) → E-27'nin form modu (birim adı + durum).

#### E-24 · İl Kadın Başkanlıkları — `ProvinceOrgListScreen`

- **Amaç:** 81 il başkanlığının **teşkilatlanma durumunu** görmek — v2'nin en çok bakılan listesi. `GET /org-units?type=il_baskanligi&region_id=&status=&q=`.
- **AppBar:** `İl Kadın Başkanlıkları`; sağda `Icons.filter_list` (`tooltip: 'Filtrele'`).
- **Bileşenler:**
  1. InfoBlockHeader (`teskilatlanma.il_baskanliklari`).
  2. Arama alanı, ipucu `İl ara...` (Türkçe harf duyarsız, v1 §4.4).
  3. `Bölge` açılır filtresi (`Tümü` + 7 bölge).
  4. 4'lü durum çipleri, varsayılan **`Tümü`**.
  5. Özet şerit: `{a} Aktif · {p} Pasif · {t} Teşkilat Yok` (filtreye göre canlı).
  6. Liste: solda plaka rozeti (v1 §3.6 deseni, `kInactiveContainer`), il başkanlığı adı `titleMedium`, altında `{Bölge}` `bodySmall`, sağda `StatusBadge`; `teskilat_yok` ise §3.3a kartı.
- **İki panelli (`>= 840`):** sol liste 360 px, sağ detay E-27.
- **Boş durum:** arama sonucu yoksa `"{arama}" ile eşleşen il bulunamadı.` · filtre sonucu yoksa `Seçilen duruma uyan il başkanlığı bulunmuyor.`
- **Birincil aksiyonlar:** satır → E-27. `Teşkilat Yok` satırındaki `Görevli Ata` → E-28 (birim ön dolu, kilitli).

#### E-25 · İlçe Kadın Başkanlıkları — `DistrictOrgListScreen`

- **Amaç:** Seçili ilin ilçe başkanlıkları. `GET /org-units?type=ilce_baskanligi&province_id=`.
- **AppBar:** il seçilmeden `İlçe Kadın Başkanlıkları`; il seçilince `{İl} İlçe Başkanlıkları`.
- **Bileşenler:** InfoBlockHeader (`teskilatlanma.ilce_baskanliklari`) → **il seçici** (zorunlu ilk adım; R5 gereği aranabilir seçici; seçilene kadar liste yerine yönlendirme: `Icons.location_city_outlined` 48 px + `İlçe başkanlıklarını görmek için önce bir il seçin.` + `İl Seç` `FilledButton`) → il seçilince: arama (`İlçe ara...`) + 4'lü durum çipleri (varsayılan `Tümü`) + özet şerit + ilçe listesi.
- Seçilen il AppBar altında kaldırılabilir bir `Chip` olarak durur (`Icons.close` ile temizlenir).
- **Boş durum:** `Bu ilde ilçe başkanlığı kaydı bulunmuyor.`
- **Birincil aksiyonlar:** satır → E-27; `Görevli Ata`.

#### E-26 · Temsilcilikler — `RepresentationListScreen`

- **Amaç:** İl/ilçe temsilcilikleri. `GET /org-units?type=temsilcilik&region_id=&province_id=&status=`.
- **AppBar:** `Temsilcilikler`.
- **Bileşenler:** InfoBlockHeader (`teskilatlanma.temsilcilikler`) → arama (`Temsilcilik ara...`) → `Bölge` + `İl` açılır filtreleri (kademeli, R1) → 4'lü durum çipleri (varsayılan `Tümü`) → liste (ad `titleMedium`, `{İl} / {İlçe}` veya `{İl}` `bodySmall`, `StatusBadge`).
- **Boş durum:** `Kayıtlı temsilcilik bulunmuyor.`
- **Birincil aksiyon:** FAB `Yeni Temsilcilik` (yalnız `genel_merkez`) → birim formu (Ad · Bölge · İl · İlçe (isteğe bağlı) · Durum · Açıklama).

#### E-27 · Birim Detayı — `OrgUnitDetailScreen` (ortak ekran)

Tüm birim türleri için **tek** ekran; `org_unit_id` parametreli.

- **Amaç:** Birimin künyesi, görevlileri, alt birimleri ve ekleri. `GET /org-units/:id`.
- **AppBar:** birim adı (ör. `Ankara İl Kadın Başkanlığı`); sağda `Icons.edit` (yalnız `genel_merkez`).
- **Bileşenler:**
  1. **Künye kartı:** birim adı `headlineSmall`, altında `{Bölge} · {İl} · {İlçe}` `bodyMedium`/`kTextSecondary`, sağ üstte `StatusBadge`.
  2. **Durum kartı (§3.4):** 3'lü `SegmentedButton` + onay dialoğu + kilit kuralı.
  3. **Sekmeler:**
     - `Görevliler` — kişi kartı listesi (E-21 ile aynı kart deseni: fotoğraf, unvan, görev tarihleri). Filtre çipleri `Tümü / Aktif / Pasif`.
     - `Alt Birimler` — **yalnız** `il_baskanligi` biriminde görünür: o ilin ilçe başkanlıkları + temsilcilikleri, `StatusBadge`'li satırlar.
     - `Ekler` — §7 ek listesi (`kind: dokuman | fotograf`).
  4. Sekme sayısı 1'e düşerse (`komisyon`, `bolge_temsilciligi` vb. için `Alt Birimler` yoksa) `TabBar` **gizlenir**, içerik doğrudan gösterilir.
- **Boş durumlar:** Görevliler: `Bu birimde görevli bulunmuyor.` + `Görevli Ata` butonu · Alt Birimler: `Bu ile bağlı alt birim kaydı bulunmuyor.` · Ekler: §7.
- **Birincil aksiyonlar:** FAB `Görevli Ata` → E-28 (birim kilitli, R11). Kişi kartına dokunuş → E-29.

#### E-28 · Görevlendirme Formu — `AssignmentOrgFormScreen`

- **Amaç:** Kişiyi bir birime görevle bağlamak (K4 `assignments_org`). `POST/PUT /org-assignments`.
- **AppBar:** yeni: `Görevli Ata` · düzenleme: `Görevlendirmeyi Düzenle`.
- **Alanlar (`DynamicForm`):**

| Etiket | Tür | Zorunlu | Not / mesaj |
|---|---|---|---|
| `Teşkilat Birimi` | orgPicker | Evet | bağlamdan geldiyse **kilitli** (R11) · `Teşkilat birimi seçin.` |
| `Kişi` | personPicker | Evet | `Kişi seçin.` · sağda `TextButton` `Yeni Kişi Ekle` → E-30, dönüşte seçili gelir |
| `Görev` | picker `GET /lookups/gorev_unvani` | Evet | `Görev seçin.` |
| `Göreve Başlama Tarihi` | date | Evet | `Göreve başlama tarihi seçin.` |
| `Görev Bitiş Tarihi` | date | Hayır | boşsa görev devam ediyor demektir; helper: `Boş bırakılırsa görev devam ediyor sayılır.` · bitiş<başlangıç → `Görev bitiş tarihi başlama tarihinden önce olamaz.` |
| `Durum` | segment `Aktif` / `Pasif` | Evet | varsayılan `Aktif` |
| `Açıklama` | multiline (3 satır) | Hayır | maxLength 500 |

- **Kural:** Aynı kişi aynı birimde **aktif** ikinci bir görevlendirme alamaz. Sunucu 409 dönerse alan altında: `Bu kişi bu birimde zaten görevli.`
- **Başarı:** snackbar `Görevlendirme kaydedildi.` Birim durumu `teskilat_yok` iken ilk aktif görevlendirme eklenirse ek snackbar: `Birim durumu "Aktif" olarak güncellendi.`

#### E-29 · Kişi Detayı — `PersonDetailScreen` (v1 §3.10 genişletildi)

v1 ekranı **korunur**; şu eklemeler yapılır:

- Üst kartta baş harf avatarı yerine **fotoğraf** (varsa, 64 px daire); fotoğrafa dokunuş → E-71 tam ekran görüntüleyici.
- Bilgi listesine eklenen satırlar: `Görev` · `Göreve Başlama Tarihi` · `Görev Bitiş Tarihi` (boşsa `Devam ediyor`).
- Yeni bölüm `Görevlendirmeler`: kişinin bağlı olduğu birimler listesi (birim adı + görev + tarih aralığı + `StatusBadge`). Boşsa: `Bu kişinin görevlendirmesi bulunmuyor.`
- Yeni sekme/bölüm `Ekler` (§7).
- Durum kartı **iki durumludur** (kişi `teskilat_yok` alamaz, §3.3b) — v1'deki switch korunur.

#### E-30 · Kişi Formu — `PersonFormScreen` (v1 §3.9 genişletildi)

v1 alan tablosu **aynen korunur**; şu alanlar eklenir (v1 sırasının sonunda, `Durum`dan önce):

| Etiket | Tür | Zorunlu | Not |
|---|---|---|---|
| `Fotoğraf` | attachment (tek, `kind: fotograf`) | Hayır | §7.4 tek-görsel deseni |
| `Görev` | picker `GET /lookups/gorev_unvani` | Hayır | kişinin genel unvanı; birim görevi E-28'de |
| `Göreve Başlama Tarihi` | date | Hayır | — |
| `Görev Bitiş Tarihi` | date | Hayır | bitiş<başlangıç → `Görev bitiş tarihi başlama tarihinden önce olamaz.` |
| `Açıklama` | multiline (3 satır) | Hayır | maxLength 500 |

- v1'deki `Aktif` switch'i **`Durum` segmentine** dönüşür: `Aktif` / `Pasif` (iki seçenek, varsayılan `Aktif`).
- v1'deki `Birim Türü` / `İl` / `İlçe` üçlüsü, R1 kademeli kuralına uyacak şekilde `Bölge` → `İl` → `İlçe` sırasına alınır; `Birim Türü` bunların **üstünde** kalır.
- Diğer her şey (TC doğrulaması, telefon maskesi, hata metinleri) v1 §3.9'dan **birebir** gelir.

### 6.2 Modül: Saha Faaliyetleri

#### E-40 · Saha Faaliyetleri Ana Ekranı — `FieldHomeScreen` (v2)

- **Amaç:** 4 alt modüle giriş + son kayıtlar.
- **AppBar:** `Saha Faaliyetleri`.
- **Bileşenler:** 4 gezinme kartı (`< 600` 1 sütun, `>= 600` 2 sütun):

| Kart | Alt yazı | İkon |
|---|---|---|
| `Görevler` | `Saha görev kayıtları` | `Icons.assignment_outlined` |
| `Eğitimler` | `Gönüllü ve halka açık eğitimler` | `Icons.school_outlined` |
| `Etkinlikler` | `Takvim etkinlikleri` | `Icons.celebration_outlined` |
| `Toplantılar` | `Kurul, komisyon ve saha toplantıları` | `Icons.meeting_room_outlined` |

Altında bölüm başlığı `Son Kayıtlar` + en yeni 5 kayıt (tür ikonu + başlık + tarih), satır dokunuşu ilgili forma gider.
- **Boş durum:** Son Kayıtlar boşsa bölüm **hiç gösterilmez**.

#### E-41 · Görevler Listesi — `TaskListScreen`

- **Amaç:** Saha görev kayıtları. `GET /tasks?gorev_turu_id=&region_id=&province_id=&district_id=&from=&to=`.
- **AppBar:** `Görevler`; sağda `Icons.filter_list`.
- **Bileşenler:** filtre bottom sheet (`Görev Türü`, `Alt Görev`, `Bölge`/`İl`/`İlçe` (kademeli), `Tarih Aralığı`; `Temizle`/`Uygula`) → liste kartları.
  Kart: 1. satır `{Görev Türü}` `titleMedium` + sağda tarih `bodySmall` (`dd.MM.yyyy`); 2. satır `{Alt Görev}` `bodyMedium`/`kTextSecondary`; 3. satır `{İl} / {İlçe}`; 4. satır `Icons.groups` `{n} gönüllü · {m} yararlanıcı · {s} saat`; ek varsa sağ altta `Icons.attach_file` + adet.
- **İki panelli (`>= 840`):** sol liste, sağ form.
- **Boş durum:** `Icons.assignment_outlined` + `Henüz görev kaydı yok.` + `İlk kaydı eklemek için + butonuna dokunun.`
- **Birincil aksiyonlar:** FAB `Yeni Görev` → E-42. Satır → E-42 (düzenle). Taşma menüsü `Sil` (yalnız `genel_merkez`; onay `Görev kaydı silinsin mi?` / `Bu işlem geri alınamaz.` / `Vazgeç` · `Sil`).

#### E-42 · Görev Formu — `TaskFormScreen`

**Alanlar (`DynamicForm`, §4 kuralları geçerli):**

| Bölüm | Etiket | Tür | Zorunlu | Not |
|---|---|---|---|---|
| Faaliyet Bilgileri | `Tarih` | date | Evet | varsayılan bugün; ileri tarih yasak (§4.5) |
| Konum Bilgileri | `Bölge` | lookup (7) | Evet | R1 üst; il seçilirse otomatik dolar+kilitlenir |
| | `İl` | picker (81) | Evet | `parentKey: region_id` |
| | `İlçe` | picker | Hayır | `parentKey: province_id`; boş seçenek `İl geneli` |
| | `Şube` | text (autocomplete), maxLength 100 → API `branch` | Hayır | API-V2'de **serbest metin** sütunu; il seçilmeden devre dışı. Yazarken daha önce girilmiş şube adlarından öneri listesi açılır (`GET /tasks?province_id=` yanıtındaki farklı `branch` değerleri, istemcide toplanır). Öneriler yazımı tekilleştirir; seçim zorunlu değildir. |
| | `Kadın Teşkilatı` | orgPicker (il/ilçeye göre daralır) | Evet | `Kadın teşkilatı seçin.` |
| Faaliyet Bilgileri | `Görev Türü` | picker (12) | Evet | §4.3(b) |
| | `Alt Görev` | picker | Evet* | §4.3(b); alt görev yoksa gizli |
| Sayısal Bilgiler | `Gönüllü Sayısı` | number | Evet | §4.4 |
| | `Yararlanıcı Sayısı` | number | Evet | §4.4 |
| | `Süre (saat)` | decimal | Evet | §4.4 |
| Açıklama | `Açıklama` | multiline (4 satır) | Hayır | maxLength 1000 |
| Ekler | `Fotoğraf` | attachment çoklu (`fotograf`) | Hayır | §7 |
| | `Doküman` | attachment çoklu (`dokuman`) | Hayır | §7 |

- **AppBar:** yeni `Yeni Görev Kaydı` · düzenleme `Görev Kaydını Düzenle`.
- **Başarı:** snackbar `Görev kaydedildi.`

#### E-43 · Eğitimler Listesi — `TrainingListScreen`

- **AppBar:** `Eğitimler`; sağda filtre.
- **Filtreler:** `Kategori`, `Yöntem`, `Konu`, `Bölge`/`İl`, `Tarih Aralığı`.
- **Kart:** 1. satır `{Konu}` `titleMedium` + tarih; 2. satır iki küçük çip: `{Kategori}` (`kInfoContainer`/`kInfo`) ve `{Yöntem}` (`kInactiveContainer`/`kInactive`); 3. satır `{İl}` + `{Düzenleyen Teşkilat}`; 4. satır `Icons.person_outline` `{Eğitmen}` · `{n} katılımcı · {s} saat`.
- **Boş durum:** `Icons.school_outlined` + `Henüz eğitim kaydı yok.` + `İlk kaydı eklemek için + butonuna dokunun.`
- **Aksiyonlar:** FAB `Yeni Eğitim` → E-44; satır → düzenle; `Sil` (genel_merkez).

#### E-44 · Eğitim Formu — `TrainingFormScreen`

| Bölüm | Etiket | Tür | Zorunlu | Not |
|---|---|---|---|---|
| Faaliyet Bilgileri | `Tarih` | date | Evet | ileri tarih yasak |
| Konum Bilgileri | `Bölge` | lookup | Evet | R1 |
| | `İl` | picker | Evet | R1 |
| | `Düzenleyen Teşkilat` | orgPicker | Evet | `Düzenleyen teşkilat seçin.` |
| Eğitim Bilgileri | `Kategori` | segment/matris | Evet | §4.3(d) |
| | `Yöntem` | segment/matris | Evet | §4.3(d) |
| | `Konu` | picker (filtreli) | Evet | §4.3(d) |
| | `Platform` | lookup | Evet* | yalnız `Yöntem = Çevrim İçi` (§4.3c kuralı) |
| | `Platform Adı` | text | Evet* | yalnız `Platform = Diğer` |
| | `Eğitmen` | text, maxLength 100 | Evet | `Eğitmen adını girin.` |
| Sayısal Bilgiler | `Katılımcı Sayısı` | number | Evet | — |
| | `Gönüllü Sayısı` | number | Evet | — |
| | `Süre (saat)` | decimal | Evet | — |
| Açıklama | `Açıklama` | multiline | Hayır | maxLength 1000 |
| Ekler | `Katılım Listesi` | attachment çoklu (`katilim_listesi`) | Hayır | §7 |
| | `Fotoğraf` | attachment çoklu (`fotograf`) | Hayır | — |
| | `Doküman` | attachment çoklu (`dokuman`) | Hayır | — |

- **AppBar:** `Yeni Eğitim Kaydı` / `Eğitim Kaydını Düzenle`. **Başarı:** `Eğitim kaydedildi.`

#### E-45 · Etkinlikler Listesi — `EventListScreen`

- **AppBar:** `Etkinlikler`; sağda filtre (`Etkinlik Türü`, `Bölge`/`İl`, `Tarih Aralığı`).
- **Kart:** 1. satır `{Etkinlik Adı}` `titleMedium` + tarih; 2. satır `{Etkinlik Türü}` çipi; 3. satır `{İl}` · `{Düzenleyen Teşkilat}`; 4. satır `{k} katılımcı · {g} gönüllü · {y} yararlanıcı`.
- **Boş durum:** `Icons.celebration_outlined` + `Henüz etkinlik kaydı yok.` + `İlk kaydı eklemek için + butonuna dokunun.`
- **Aksiyonlar:** FAB `Yeni Etkinlik` → E-46.

#### E-46 · Etkinlik Formu — `EventFormScreen`

| Bölüm | Etiket | Tür | Zorunlu | Not |
|---|---|---|---|---|
| Faaliyet Bilgileri | `Tarih` | date | Evet | API `event_date`; değişimi Etkinlik Adı'nı etkiler (§4.3e) |
| | `Etkinlik Türü` | lookup `etkinlik_turu` | **Hayır** | API `event_type_id` opsiyoneldir. Seçilirse E-47 takvim listesini `category` ile daraltır; seçilmezse takvimin tamamı listelenir. |
| | `Etkinlik Adı` | **picker (takvim, E-47)** | **Evet** | API `calendar_event_id` — **zorunlu**. **Serbest metin yasak** (R6). Boş → `Etkinlik seçin.` |
| Konum Bilgileri | `Bölge` | lookup | Evet | R1 |
| | `İl` | picker | Evet | R1 |
| | `Düzenleyen Teşkilat` | orgPicker | Evet | — |
| Sayısal Bilgiler | `Katılımcı Sayısı` | number | Evet | — |
| | `Gönüllü Sayısı` | number | Evet | — |
| | `Yararlanıcı Sayısı` | number | Evet | — |
| Açıklama | `Açıklama` | multiline | Hayır | maxLength 1000 |
| Ekler | `Fotoğraf` · `Doküman` | attachment çoklu | Hayır | §7 |

- **AppBar:** `Yeni Etkinlik Kaydı` / `Etkinlik Kaydını Düzenle`. **Başarı:** `Etkinlik kaydedildi.`

#### E-47 · Etkinlik Adı Seçici — `CalendarEventPickerScreen`

- **Amaç:** Takvimden etkinlik seçtirmek. `GET /calendar-events?category=&year=`.
- **AppBar:** `Etkinlik Seç`.
- **Bileşenler:** arama alanı (`Etkinlik ara...`) → aya göre gruplu liste (`Ocak` … `Aralık`, grup başlığı `titleSmall` yapışkan). Satır: etkinlik adı `titleMedium`, altında tarih `bodySmall`, sağda kategori çipi.
- **Çağrıda `year` daima gönderilir** (formdaki `Tarih` alanının yılı). `is_fixed=1` kayıtlarda tarih `month`/`day`'den (`23 Nisan`), `is_fixed=0` kayıtlarda (dinî bayramlar) yanıttaki **`resolved_date`**'ten biçimlenir. `resolved_date` boşsa satır `Tarih girilmemiş` yazar, **seçilebilir kalır** ve gruplama için listenin sonunda ayrı `Tarihi belirlenmemiş` başlığı altında toplanır.
- **Kategori adları** (`category` → ekran metni): `milli_bayram` → `Millî Bayram` · `dini_bayram` → `Dinî Bayram` · `dini_gun` → `Dinî Gün` · `resmi_gun` → `Resmî Gün` · `onemli_gun` → `Önemli Gün` · `onemli_hafta` → `Önemli Hafta`.
- `end_month`/`end_day` (veya `resolved_date`in `end_date`i) doluysa tarih aralık olarak yazılır: `10 – 16 Mayıs`.
- **Boş durum:** `Bu tür için takvimde etkinlik bulunmuyor.` + `Etkinlik takvimi Yönetim Paneli → Tanımlar bölümünden yönetilir.`
- **Arama boş:** `Aramanızla eşleşen etkinlik bulunamadı.`
- **Birincil aksiyon:** satır dokunuşu → seçer ve geri döner (onay dialoğu yok).

#### E-48 · Toplantılar Listesi — `MeetingListScreen` (v2)

- **AppBar:** `Toplantılar`; sağda filtre (`Toplantı Türü` (7), `Yöntem`, `Bölge`/`İl`, `Tarih Aralığı`).
- **Kart:** 1. satır `{Toplantı Türü}` `titleMedium` + tarih; 2. satır yöntem çipi — `Yüz Yüze` ise `Icons.place_outlined` + `{Toplantı Yeri}`, `Çevrim İçi` ise `Icons.videocam_outlined` + `{Platform}`; 3. satır `{Düzenleyen Teşkilat}`; 4. satır `Gündem: {gündem}` en fazla 2 satır, taşarsa `...`.
- **Boş durum:** `Icons.meeting_room_outlined` + `Henüz toplantı kaydı yok.` + `İlk kaydı eklemek için + butonuna dokunun.`
- **Aksiyonlar:** FAB `Yeni Toplantı` → E-49. `Sil` (genel_merkez): `Toplantı kaydı silinsin mi?`

#### E-49 · Toplantı Formu — `MeetingFormScreen` (v2)

| Bölüm | Etiket | Tür | Zorunlu | Not |
|---|---|---|---|---|
| Faaliyet Bilgileri | `Toplantı Türü` | lookup (7) | Evet | `Toplantı türü seçin.` |
| | `Tarih` | date | Evet | — |
| | `Toplantı Yöntemi` | lookup (2) | Evet | **§4.3(c) tam kuralı** |
| | `Toplantı Yeri` | text | Evet* | yalnız `Yüz Yüze` |
| | `Platform` | dropdown → API `platform` (metin) | Evet* | yalnız `Çevrim İçi` · §4.3(c) 404 geri düşüşü geçerli |
| | `Platform Adı` | text | Evet* | yalnız `Platform = Diğer` |
| Konum Bilgileri | `Düzenleyen Teşkilat` | orgPicker → `org_unit_id` | Evet | — |
| Katılım | `Katılımcılar` | multiline (2 satır) → API `participants` | Hayır | API'de **serbest metin** sütunudur (kişi bağı yok). İpucu: `Örn. 12 kurul üyesi` · maxLength 500 |
| Açıklama | `Gündem` | multiline (4 satır) → `agenda` | Evet | UI kuralı (API'de opsiyonel) · `Gündemi girin.` · maxLength 2000 |
| | `Alınan Kararlar` | multiline (4 satır) → `decision` | Evet | UI kuralı (API'de opsiyonel) · `Alınan kararları girin.` · maxLength 2000 |
| | `Sonuç` | multiline (3 satır) → `outcome` | Hayır | v1 alanı korunur · maxLength 1000 |
| Ekler | `Tutanak` | attachment çoklu (`tutanak`) | Hayır | §7 |
| | `Sunum` | attachment çoklu (`sunum`) | Hayır | §7 |
| | `Fotoğraf` | attachment çoklu (`fotograf`) | Hayır | §7 |

- **API notu:** API-V2 §6.4'te zorunlu olan tek alan `meeting_date`'tir; yukarıdaki `Toplantı Türü`, `Yöntem`, `Düzenleyen Teşkilat`, `Gündem` ve `Alınan Kararlar` zorunlulukları **arayüz düzeyinde ve kasıtlıdır** (raporlanabilir veri için). Sunucu daha gevşek olduğundan bu kurallar istemcide zorlanır.
- **`body_id`:** Toplantı Türü `Koordinasyon Kurulu` veya `Komisyon` ise, seçilen `Düzenleyen Teşkilat` biriminin `body_id` alanı gövdeye eklenir (v1 uyumluluğu); diğer türlerde `null` gider. Kullanıcıya ayrı alan gösterilmez.
- **AppBar:** `Yeni Toplantı Kaydı` / `Toplantı Kaydını Düzenle`. **Başarı:** `Toplantı kaydedildi.`

### 6.3 Modül: Lojistik

#### E-50 · Lojistik Ana Ekranı — `LogisticsHomeScreen`

- **AppBar:** `Lojistik`.
- **Bileşenler:** üstte 3 küçük sayı şeridi (`Açık Talep {n}` · `Yolda {n}` · `Teslim Edilen {n}`) + 3 gezinme kartı:

| Kart | Alt yazı | İkon |
|---|---|---|
| `Malzeme Talepleri` | `Teşkilatlardan gelen talepler` | `Icons.playlist_add_check_outlined` |
| `Gönderiler` | `Kargo ve teslimat kayıtları` | `Icons.local_shipping_outlined` |
| `Stok Durumu` | `Ürün stokları ve hareketleri` | `Icons.inventory_2_outlined` |

#### E-51 · Malzeme Talepleri — `MaterialRequestListScreen`

- **Amaç:** `GET /material-requests?status=&province_id=&from=&to=`.
- **AppBar:** `Malzeme Talepleri`; sağda filtre.
- **Durum değerleri (API-V2 §7.1 ile birebir):**

| API `status` | Rozet metni | Zemin / metin |
|---|---|---|
| `talep` | `Talep Edildi` | `kWarningContainer` / `kWarning` |
| `onaylandi` | `Onaylandı` | `kInfoContainer` / `kInfo` |
| `gonderildi` | `Gönderildi` | `kPrimaryContainer` / `kPrimary` |
| `teslim_edildi` | `Teslim Edildi` | `kSuccessContainer` / `kSuccess` |
| `iptal` | `İptal Edildi` | `kInactiveContainer` / `kInactive` |

- **Durum çipleri:** `Tümü` · `Talep Edildi` · `Onaylandı` · `Gönderildi` · `Teslim Edildi` · `İptal Edildi` (varsayılan `Tümü`, yatay kaydırmalı).
- **Kart:** 1. satır `{Talep Eden Teşkilat}` `titleMedium` + sağda durum rozeti; 2. satır `{Ürün} × {Miktar}`; gönderilmiş miktar varsa aynı satırın sonunda `bodySmall`/`kTextSecondary` `({shipped_quantity} gönderildi)`; 3. satır `Talep Tarihi: {dd.MM.yyyy}`.
- **Boş durum:** `Icons.playlist_add_check_outlined` + `Henüz malzeme talebi yok.` + `İlk talebi eklemek için + butonuna dokunun.`
- **Aksiyonlar:** FAB `Yeni Talep` → E-52. Taşma menüsü (genel_merkez): `Onayla` · `İptal Et` · `Gönderi Oluştur` (→ E-54, talep kilitli ön dolu) · `Sil`.
  - `Onayla` / `İptal Et` → `PATCH /material-requests/:id/status`. `İptal Et` onayı: `Talebi iptal et` / `Bu talep iptal edilecek. Devam edilsin mi?` / `Vazgeç` · `İptal Et`. Başarı: `Talep durumu güncellendi.`
  - **Ret/gerekçe akışı yoktur** — API'de `reddedildi` durumu ve gerekçe sütunu bulunmaz; karşılığı `iptal`dir.
  - `Sil` yalnız gönderisi olmayan talepte; sunucu 409 `IN_USE` dönerse dialog: `Talep silinemiyor` / `Bu talebe bağlı gönderi kaydı olduğu için silinemez. Talebi iptal edebilirsiniz.` / `Tamam`.

#### E-52 · Talep Formu — `MaterialRequestFormScreen`

| Etiket | Tür | Zorunlu | Not |
|---|---|---|---|
| `Talep Tarihi` | date → `request_date` | Evet | varsayılan bugün |
| `Talep Eden Teşkilat` | orgPicker → `org_unit_id` | Evet | kullanıcının kapsamı varsa ön dolu + kilitli (R11); `region_id`/`province_id` birimden türetilir |
| `Ürün` | picker `GET /lookups/lojistik_urun` → `product_id` | Evet | `Ürün seçin.` |
| `Miktar` | number ≥1 → `quantity` | Evet | `Miktar girin.` |
| `Talep Eden Kişi` | personPicker → `requested_by_person_id` | Hayır | — |
| `Açıklama` | multiline → `notes` | Hayır | maxLength 500 |

- **Tek kalemli talep.** API-V2 §7.1'de bir talep **tek ürün + tek miktar** taşır. Çok kalemli talep bileşeni **yoktur**; kullanıcı birden çok ürün için birden çok talep açar. Formun altında `bodySmall`/`kTextSecondary`: `Her ürün için ayrı talep oluşturulur.` ve kaydettikten sonra snackbar aksiyonu `Yeni Talep` ile form aynı teşkilat ön dolu olarak yeniden açılır (art arda giriş kolaylığı).
- **Başarı:** `Talep kaydedildi.`

#### E-53 · Gönderiler — `ShipmentListScreen`

- **AppBar:** `Gönderiler`; sağda filtre (`Gönderim Şekli`, `Tarih Aralığı`, teslim durumu).
- **Durum çipleri:** `Tümü` · `Yolda` · `Teslim Edildi`. **Türetilmiş durumdur** — API'de `shipments.status` sütunu yoktur: `received_date` boşsa `Yolda`, doluysa `Teslim Edildi`. Üçüncü bir durum (`Hazırlanıyor`) **yoktur**.
- **Kart:** 1. satır `{Ürün}` `titleMedium` + sağda türetilmiş durum rozeti; 2. satır `{Ürün} × {Miktar}` ve `Talep: {request_date}`; 3. satır `{Gönderim Şekli}` · `Gönderi: {dd.MM.yyyy}`; takip no varsa 4. satır `Takip No: {no}` + sağda `Icons.copy` (`tooltip: 'Takip numarasını kopyala'`, kopyalanınca snackbar `Takip numarası kopyalandı.`).
- **Alıcı teşkilat** gönderide değil, bağlı talepte tutulur; karta bağlı talebin `org_unit_name` değeri 1. satırın altına `bodySmall` olarak yazılır.
- **Boş durum:** `Icons.local_shipping_outlined` + `Henüz gönderi kaydı yok.` + `İlk kaydı eklemek için + butonuna dokunun.`
- **Aksiyonlar:** FAB `Yeni Gönderi` → E-54; satır → E-54 (düzenle); taşma menüsü `Teslim Bilgisi Gir` → E-55 (yalnız `received_date` boşken görünür).

#### E-54 · Gönderi Formu — `ShipmentFormScreen`

| Bölüm | Etiket | Tür | Zorunlu | Not |
|---|---|---|---|---|
**Gönderi daima bir talepten oluşturulur** (API `request_id` zorunlu). Ürün, miktar ve alıcı teşkilat talepten okunur.

| Bölüm | Etiket | Tür | Zorunlu | Not |
|---|---|---|---|---|
| Gönderi Bilgileri | `Talep` | picker (açık talepler) → `request_id` | Evet | E-51'den gelindiyse **kilitli** (R11). Seçici satırı: `{Ürün} × {Miktar} — {Talep Eden Teşkilat}` + `{request_date}`. Boş → `Talep seçin.` |
| | `Talep Tarihi` | salt okunur | — | Seçilen talepten gösterilir, gönderilmez |
| | `Ürün` | salt okunur | — | Talepten; gönderilmez |
| | `Alıcı Teşkilat` | salt okunur | — | Talepten; gönderilmez |
| | `Gönderi Tarihi` | date → `shipment_date` | Evet | `Gönderi tarihi seçin.` |
| | `Miktar` | number ≥1 → `quantity` | Evet | varsayılan = talebin kalan miktarı; talebi aşarsa `Miktar, talep edilen miktarı aşamaz.` |
| | `Gönderim Şekli` | lookup `gonderim_sekli` → `shipping_method_id` | Evet | `Gönderim şekli seçin.` |
| | `Kargo Takip No` | text, maxLength 50 → `tracking_no` | **Evet*** | **yalnız `Gönderim Şekli = Kargo`** (R2 koşullu alan) · `Kargo takip numarasını girin.` |
| Teslim | `Teslim Alan` | text, maxLength 100 → `received_by` | Hayır | — |
| | `Teslim Tarihi` | date → `received_date` | Hayır | gönderi tarihinden önce olamaz → `Teslim tarihi gönderi tarihinden önce olamaz.` · helper `Doldurulursa talep "Teslim Edildi" olarak işaretlenir.` |
| Açıklama | `Açıklama` | multiline → `notes` | Hayır | maxLength 500 |
| Ekler | `Doküman` | attachment çoklu | Hayır | irsaliye/fatura |

- **Stok yan etkisi kullanıcıya bildirilir:** kayıt sonrası snackbar `Gönderi kaydedildi. Stok güncellendi.`
- Sunucu `INSUFFICIENT_STOCK` (400) dönerse `Miktar` alanı altında: `Stok yetersiz. Mevcut stok: {n}.`
- Açık talep yoksa `Talep` seçicisinin boş durumu: `Gönderilecek açık talep bulunmuyor.` + `Yeni Talep Oluştur` `TextButton` → E-52.

#### E-55 · Teslim Bilgisi Girişi — `DeliveryFormScreen` (bottom sheet / dialog)

- **Amaç:** Gönderiyi hızlıca "teslim edildi"ye çevirmek.
- **Başlık:** `Teslim Bilgisi`.
- **Alanlar:** `Teslim Alan` (text, zorunlu → `Teslim alan kişiyi girin.`) · `Teslim Tarihi` (date, zorunlu, varsayılan bugün) · `Açıklama` (isteğe bağlı) · `Fotoğraf` (isteğe bağlı, teslim kanıtı).
- **Aksiyonlar:** `Vazgeç` · `Kaydet`. **Başarı:** `Teslim bilgisi kaydedildi.`

#### E-56 · Stok Durumu — `StockListScreen`

- **Amaç:** `GET /stock-items?product_id=&low_only=1`.
- **AppBar:** `Stok Durumu`; sağda `Icons.search`.
- **Bileşenler:** arama (`Ürün ara...`) + `Yalnız azalanlar` filtre çipi (→ `low_only=1`) → ürün listesi. Satır: ürün adı `titleMedium`, sağda mevcut miktar `titleMedium` `tabular-nums`; altında `Kritik seviye: {min_quantity}` `bodySmall`/`kTextSecondary`.
- **Azalan stok (`is_low = true`):** miktar `kWarning` renkte, solunda `Icons.trending_down` `kWarning`, satırın altında `bodySmall`/`kWarning`: `Stok kritik seviyenin altında.` Miktar 0 ise: `Stokta ürün kalmadı.`
- Listenin üstünde azalan ürün varsa özet şerit (`kWarningContainer`): `{n} üründe stok kritik seviyenin altında.`
- **Boş durum:** `Icons.inventory_2_outlined` + `Stok kaydı bulunmuyor.` · `Yalnız azalanlar` seçiliyken boşsa: `Kritik seviyenin altında ürün bulunmuyor.`
- **Aksiyonlar:** satır → E-57. Satır taşma menüsü (genel_merkez): `Kritik Seviyeyi Değiştir` → küçük dialog (`Kritik Seviye` sayı alanı, `PUT /stock-items/:productId`). Başarı: `Kritik seviye güncellendi.`

#### E-57 · Stok Hareketleri — `StockMovementScreen`

- **AppBar:** `{Ürün adı}`.
- **Bileşenler:** üstte özet kart (`Mevcut Stok` büyük sayı + `Giriş {n}` / `Çıkış {n}`), altında hareket listesi (ters kronolojik). Satır: yön ikonu (`Icons.arrow_downward` `kSuccess` giriş / `Icons.arrow_upward` `kWarning` çıkış) + `{±miktar}` + açıklama + `dd.MM.yyyy HH:mm`.
- **Boş durum:** `Bu ürün için hareket kaydı bulunmuyor.`
- **Aksiyon:** FAB `Stok Girişi` (yalnız `genel_merkez`) → küçük form (`Miktar` zorunlu, `Açıklama` isteğe bağlı).

### 6.4 Modül: Raporlama ve Dashboard

E-10 Dashboard §5'te tam olarak tanımlandı. Bu modülün diğer ekranları:

#### E-11 · Bölge Kırılımı — `RegionBreakdownScreen`

- **AppBar:** `Bölge Kırılımı`.
- **Bileşenler:** §5.5 filtre çubuğu (aynı bileşen) → 7 bölge satırı; her satır: bölge adı `titleMedium`, altında `{a} Aktif · {p} Pasif · {t} Teşkilat Yok` renkli küçük ikon+sayı üçlüsü, sağda `chevron_right`.
- **Boş durum:** `Seçilen filtrelerle gösterilecek veri bulunamadı.`
- **Aksiyon:** satır → E-12, o bölge ön filtreli.

#### E-12 · İl Kırılımı — `ProvinceBreakdownScreen`

- **AppBar:** `İl Kırılımı`; sağda `Icons.swap_vert` (`tooltip: 'Sırala'`).
- **Bileşenler:** filtre çubuğu + durum çipleri (4'lü) + sıralama seçici (`Plaka` / `İl Adı` / `Teşkilat Yok`) → il satırları (plaka rozeti + il adı + durum sayıları + `StatusBadge`).
- **Boş durum:** `Seçilen filtrelerle gösterilecek veri bulunamadı.`
- **Aksiyon:** satır → E-27 Birim Detayı.

#### E-13 · Grafik Tablo Görünümü — `ChartTableScreen`

- **Amaç:** Bir grafiğin verisini tablo olarak sunmak (§5.6 kuralı).
- **AppBar:** `{Grafik başlığı}` · alt başlık `Tablo Görünümü`; sağda `Icons.download` → Excel.
- **Bileşenler:** sabit başlıklı, yatay kaydırılabilir tablo; sayılar `tabular-nums`, sağa yaslı; son satır `Toplam` w600 + `kBackground` zemin.
- **Boş durum:** `Gösterilecek veri bulunamadı.`

#### E-14 · Rapor Merkezi — `ReportCenterScreen`

- **Amaç:** Tüm raporların tek girişi (v1 §3.18'in genişletilmiş hâli).
- **AppBar:** `Rapor Merkezi`.
- **Bileşenler:** §5.5 filtre çubuğu (tüm raporlara uygulanır) + rapor kartları listesi. Her kart: ad `titleMedium`, alt yazı `bodySmall`, sağda iki küçük buton — `Icons.table_view_outlined` `Excel` ve `Icons.picture_as_pdf_outlined` `PDF`.

| Rapor | Alt yazı |
|---|---|
| `Teşkilatlanma Raporu` | `Birim ve durum dağılımı` |
| `Kişi Listesi` | `Tüm kayıtlı kişiler` |
| `Görevlendirmeler` | `Birim bazlı görev kayıtları` |
| `Görev Faaliyetleri` | `Saha görev kayıtları` |
| `Eğitimler` | `Eğitim kayıtları` |
| `Etkinlikler` | `Etkinlik kayıtları` |
| `Toplantılar` | `Toplantı kayıtları` |
| `Lojistik Hareketleri` | `Talep, gönderi ve stok` |

- Kart gövdesine dokunuş → E-15 Önizleme.
- İndirme sırasında ilgili butonda spinner; başarıda snackbar `Rapor indirildi.`; hatada `Rapor indirilemedi. Tekrar deneyin.` (v1 §3.18 metinleri).
- **Mobil indirme (v1 BLOKE-4'ün karşılığı):** `< 600` ve mobil hedefte dosya cihaza kaydedilir ve snackbar aksiyonu `Aç` gösterilir; kaydedilemezse `Dosya kaydedilemedi. Depolama iznini kontrol edin.`
- **Boş durum:** yok.

#### E-15 · Rapor Önizleme — `ReportPreviewScreen`

- **AppBar:** `{Rapor adı}`; sağda `Icons.download` → E-16.
- **Bileşenler:** filtre özeti çip satırı (salt okunur) + sayfalı tablo (sayfa boyu 50, altta `‹ 1 / 12 ›` gezinme). Sütun başlıkları Türkçe, sabit; sayılar `tabular-nums`.
- **Boş durum:** `Seçilen filtrelerle kayıt bulunamadı.` + `Filtreleri Temizle`.

#### E-16 · Dışa Aktar — `ExportSheet` (bottom sheet)

- **Başlık:** `Dışa Aktar`.
- **Bileşenler:** 2 seçenek satırı — `Excel (.xlsx)` (`Icons.table_view_outlined` `kSuccess`) ve `PDF (.pdf)` (`Icons.picture_as_pdf_outlined` `kError`); altında bilgi satırı `bodySmall`/`kTextSecondary`: `Rapor, seçili filtrelere göre oluşturulur.`
- **Aksiyon:** seçim → indirme; sheet kapanır.

#### E-17 · Değişiklik Günlüğü — `AuditLogScreen`

v1 §3.19 **korunur**. Değişiklikler: `Kayıt Türü` filtresine yeni değerler eklenir — `Teşkilat Birimleri`, `Görevlendirmeler`, `Görevler`, `Eğitimler`, `Etkinlikler`, `Toplantılar`, `Talepler`, `Gönderiler`, `Stok`, `Tanımlar`, `Kullanıcılar`, `İçerikler`. Ek eylem çevirisi: `status-change` → `Durum değişikliği`, `upload` → `Dosya ekleme`, `file-delete` → `Dosya silme`.

### 6.5 Modül: Yönetim Paneli (yalnız `genel_merkez`)

#### E-60 · Yönetim Paneli Ana Ekranı — `AdminPanelScreen`

- **AppBar:** `Yönetim Paneli`.
- **Bileşenler:** 7 giriş satırı (ikon + başlık + alt yazı + `chevron_right`), aralarında `kBorder` ayraç:

| Satır | Alt yazı | İkon |
|---|---|---|
| `Kullanıcı Yönetimi` | `Sistem kullanıcıları ve şifreleri` | `Icons.manage_accounts_outlined` |
| `Tanımlar` | `Açılır liste ve kod tanımları` | `Icons.list_alt_outlined` |
| `Yetkilendirme` | `Rol ve kapsam ayarları` | `Icons.admin_panel_settings_outlined` |
| `Bildirimler` | `Bildirim tanımları ve gönderim` | `Icons.notifications_outlined` |
| `Sistem Ayarları` | `Genel sistem parametreleri` | `Icons.tune_outlined` |
| `Form Yönetimi` | `Form alanlarının görünürlüğü` | `Icons.dynamic_form_outlined` |
| `İçerik Yönetimi` | `Modül bilgilendirme metinleri` | `Icons.article_outlined` |

- **Boş durum:** yok.

#### E-61 · Kullanıcı Yönetimi — `UserListScreen`

- **Amaç:** v1 denetim raporundaki Y-2 riskinin çözümü. `GET /users?role=&status=&q=`.
- **AppBar:** `Kullanıcı Yönetimi`; sağda `Icons.search`.
- **Bileşenler:** arama (`Kullanıcı ara...`) + rol çipleri (`Tümü` · `Genel Merkez` · `Saha`) + durum çipleri (`Tümü` · `Aktif` · `Pasif`) + liste. Satır: baş harf avatarı + ad `titleMedium` + e-posta `bodySmall` + rol rozeti (`kPrimaryContainer`/`kPrimary`) + `StatusBadge` (2 durumlu); kapsam doluysa e-postanın altında `bodySmall`/`kTextSecondary`: `Kapsam: {Bölge} / {İl}`.
- Taşma menüsü: `Düzenle` · `Şifre Belirle` · `Pasif Yap` / `Aktif Yap`.
  - `Şifre Belirle` (`PUT /users/:id/password`) → dialog: başlık `Şifre belirle`, gövde metni `{Ad Soyad} için yeni bir şifre belirleyin.`, alanlar `Yeni Şifre` (gizli, göz ikonu) ve `Yeni Şifre (Tekrar)`, aksiyonlar `Vazgeç` / `Kaydet`. Hatalar: `Şifre en az 8 karakter olmalıdır.` (400 `WEAK_PASSWORD`) · `Şifreler eşleşmiyor.` Başarı: `Şifre güncellendi.` Altında `bodySmall`/`kTextSecondary`: `Şifreyi kullanıcıya güvenli bir kanaldan iletin.`
  - **Rastgele geçici şifre üretimi yoktur** — API böyle bir uç sunmaz; şifreyi yönetici belirler.
  - `Pasif Yap` sunucudan 409 `LAST_ADMIN` dönerse dialog: `İşlem yapılamıyor` / `Sistemdeki son genel merkez hesabı pasif yapılamaz.` / `Tamam`.
- **Boş durum:** `Kayıtlı kullanıcı bulunamadı.` · arama sonucu boşsa `Aramanızla eşleşen kullanıcı bulunamadı.`
- **Birincil aksiyon:** FAB `Yeni Kullanıcı` → E-62.

#### E-62 · Kullanıcı Formu — `UserFormScreen`

| Etiket | Tür | Zorunlu | Not |
|---|---|---|---|
| `Ad Soyad` | text | Evet | `Ad soyad girin.` |
| `E-posta` | email | Evet | `E-posta adresi gerekli.` / `Geçerli bir e-posta adresi girin.` / 409 → `Bu e-posta adresi ile kayıtlı bir kullanıcı zaten var.` |
| `Rol` | segment (2) → `role` | Evet | `Genel Merkez` (`genel_merkez`) · `Saha` (`saha`) |
| `Kapsam — Bölge` | lookup **tekli** → `region_id` | Hayır | `GET /regions`; boş seçenek `Tüm bölgeler`. Helper: `Boş bırakılırsa kullanıcı tüm bölgeleri görür.` |
| `Kapsam — İl` | picker **tekli** → `province_id` | Hayır | `parentKey: region_id` (R1); boş seçenek `Tüm iller` |
| `Durum` | segment `Aktif`/`Pasif` → `is_active` | Evet | varsayılan `Aktif`; düzenlemede `PATCH /users/:id/active` ile ayrı gönderilir |
| `Şifre` | text (gizli, göz ikonu) → `password` | Evet (yalnız yeni kayıt) | en az 8 karakter → `Şifre en az 8 karakter olmalıdır.` |

- **Kapsam alanları tekildir ve çoklu seçim yoktur** (API `region_id` / `province_id` tek değer alır).
- **Kapsam uyarısı — zorunlu:** iki kapsam alanının altında `kWarningContainer` bilgi kartı, metin **aynen**:
  `Kapsam bilgisi bu sürümde yalnız raporlama içindir; kullanıcının veri erişimini kısıtlamaz.`
  (API-V2 §11 notunun karşılığı — yöneticiye olmayan bir güvenlik güvencesi verilmez.)
- **AppBar:** `Yeni Kullanıcı` / `Kullanıcıyı Düzenle`. **Başarı:** `Kullanıcı kaydedildi.`
- Düzenleme modunda `Şifre` alanı **gösterilmez**; şifre yalnız `Şifre Belirle` ile değişir.
- E-posta çakışması (409): alan altında `Bu e-posta adresi ile kayıtlı bir kullanıcı zaten var.`
- `Bağlı Kişi` alanı **yoktur** — API kullanıcı ile kişi kaydı arasında bağ tutmaz.

#### E-63 · Tanımlar (kategori listesi) — `LookupCategoryListScreen`

- **Amaç:** K1 lookup altyapısının yönetim yüzü — **v2'nin "kod değişikliği gerekmez" vaadinin arayüzü.**
- **AppBar:** `Tanımlar`; sağda `Icons.search`.
- **Bileşenler:** arama (`Tanım ara...`) → kategori satırları. Satır: kategori adı `titleMedium` + altında `{n} kayıt` `bodySmall` + `chevron_right`. Sistem kategorileri (`is_system=1`) sağda küçük `Sistem` çipi (`kInactiveContainer`/`kInactive`) taşır.
- Kategori adları (ekranda gösterilecek Türkçe karşılıklar):

Kategori adları API'den (`GET /lookup-categories` → `name`) gelir; **ekranda sabit metin yazılmaz.** Aşağıdaki tablo, tohumlanan 14 kategorinin beklenen Türkçe karşılığıdır (API'nin `name` alanı farklıysa **API kazanır**):

| `code` | Beklenen ekran adı | Arayüzde kullanımı |
|---|---|---|
| `gorev_turu` | `Görev Türleri` | E-42 |
| `alt_gorev` | `Alt Görevler` | E-42 (hiyerarşik) |
| `egitim_kategorisi` | `Eğitim Kategorileri` | E-44 |
| `egitim_yontemi` | `Eğitim Yöntemleri` | E-44 |
| `egitim_konusu` | `Eğitim Konuları` | E-44 |
| `etkinlik_turu` | `Etkinlik Türleri` | E-46 |
| `etkinlik_adi` | `Etkinlik Adları` | **kullanılmaz** — §10/4 kararı |
| `toplanti_turu` | `Toplantı Türleri` | E-49 |
| `toplanti_yontemi` | `Toplantı Yöntemleri` | E-49 |
| `lojistik_urun` | `Lojistik Ürünleri` | E-52, E-54, E-56 |
| `gonderim_sekli` | `Gönderim Şekilleri` | E-54 |
| `gorev_unvani` | `Görev Unvanları` | E-28 |
| `bolge` | `Bölgeler` | **kullanılmaz** — §10/2 kararı (`GET /regions` esas alınır) |
| `durum` | `Durumlar` | **kullanılmaz** — §10/3 kararı (durum koddaki sabit enum) |

- **Kullanılmayan kategoriler gizlenmez** — listede görünür, ama satırın altında `bodySmall`/`kTextSecondary`: `Bu liste arayüzde kullanılmıyor.` Yönetici yanlışlıkla veri girip beklemesin diye.
- Listenin sonunda, lookup olmayan iki ayrı satır: `Etkinlik Takvimi` (→ `GET /calendar-events`, kendi ekranı) ve `Toplantı Platformları` (kategori yoksa satır `Tanımlı değil` çipiyle görünür; `+` ile `POST /lookup-categories {code:'toplanti_platformu', name:'Toplantı Platformları'}` oluşturulur — §4.3(c) geri düşüşünü kapatır).
- **Boş durum:** olmaz (tohum veri).
- **Aksiyon:** satır → E-64.

#### E-64 · Tanım Öğeleri — `LookupItemListScreen`

- **AppBar:** `{Kategori adı}`; sağda `Icons.search`.
- **Bileşenler:** arama + `Pasifleri göster` anahtarı (`Switch`, varsayılan kapalı) → **sürükle-sırala** liste (`ReorderableListView`). Satır: sol kenarda `Icons.drag_handle` `kTextDisabled`, ad `titleMedium`, altında `code` `bodySmall`/`kTextDisabled`, sağda `Aktif`/`Pasif` rozeti ve `⋮`.
- Hiyerarşik kategorilerde (`alt_gorev`) satırlar üst öğeye göre gruplanır: grup başlığı `titleSmall` = üst öğe adı.
- Taşma menüsü: `Düzenle` · `Pasif Yap`/`Aktif Yap` · `Sil`.
  - `Sil` yalnızca **hiç kullanılmamış** öğede etkindir. Kullanılmışsa devre dışı, altında ipucu `Bu tanım kayıtlarda kullanıldığı için silinemez. Pasif yapabilirsiniz.` Sunucu 409 dönerse aynı metin dialogda gösterilir.
  - `Pasif Yap`: pasif öğe yeni formlarda görünmez, **eski kayıtlarda görünmeye devam eder**.
- Sıralama değişince otomatik kaydedilir; snackbar `Sıralama güncellendi.`
- **Boş durum:** `Bu kategoride henüz tanım yok.` + `İlk tanımı eklemek için + butonuna dokunun.`
- **Birincil aksiyon:** FAB `Yeni Tanım` → E-65.

#### E-65 · Tanım Öğesi Formu — `LookupItemFormScreen`

| Etiket | Tür | Zorunlu | Not |
|---|---|---|---|
| `Ad` | text, maxLength 120 | Evet | `Ad girin.` |
| `Kod` | text, maxLength 40 | Hayır | helper `Boş bırakılırsa addan otomatik üretilir.` · yalnız küçük harf/rakam/alt çizgi → `Kod yalnızca küçük harf, rakam ve alt çizgi içerebilir.` · 409 → `Bu kod zaten kullanılıyor.` |
| `Üst Tanım` | picker | Evet* | **yalnız hiyerarşik kategorilerde** (`alt_gorev`) · `Üst tanım seçin.` |
| `Sıra` | number | Hayır | helper `Boş bırakılırsa listenin sonuna eklenir.` |
| `Durum` | segment `Aktif`/`Pasif` | Evet | varsayılan `Aktif` |

- **AppBar:** `Yeni Tanım` / `Tanımı Düzenle`. **Başarı:** `Tanım kaydedildi.`

#### E-66 · Yetkilendirme — `AuthorizationScreen`

- **AppBar:** `Yetkilendirme`.
- **Bileşenler:** 2 rol kartı (`Genel Merkez`, `Saha`). Her kart: rol adı `titleMedium` + `{n} kullanıcı` + `chevron_right`. Dokununca **salt okunur** yetki matrisi: modül satırları × 4 sütun (`Görüntüle` · `Ekle` · `Düzenle` · `Sil`) — işaretli/işaretsiz `Icons.check` ve `Icons.remove`.
- **Matris bu sürümde düzenlenemez.** Yetkiler sunucuda role gömülüdür (API-V2 §1.6); değiştirilebilirmiş gibi `Checkbox` gösterilmez. Ekranın üstünde `kWarningContainer` bilgi kartı, metin **aynen**:
  `Rol yetkileri bu sürümde sabittir ve yalnızca görüntülenebilir.`
- `Kaydet` butonu **yoktur**.
- Ekranın altında ayrı bölüm `Kapsam Tanımlı Kullanıcılar`: `region_id` veya `province_id` dolu kullanıcıların listesi + altında `Kapsam bilgisi raporlama içindir; veri erişimini kısıtlamaz.` Satır dokunuşu → E-62.
- **Boş durum:** kapsam bölümü boşsa `Kapsam tanımlı kullanıcı bulunmuyor.`

#### E-67 · Bildirimler — `NotificationSettingsScreen`

- **AppBar:** `Bildirimler`.
- **Bileşenler:** bildirim türü satırları, her birinde `Switch`: `Yeni malzeme talebi`, `Talep onaylandı`, `Gönderi teslim edildi`, `Görev bitiş tarihi yaklaşan görevliler`, `Teşkilat Yok durumuna düşen birim`. Her satırın altında `bodySmall` açıklama.
- Sayfanın üstünde bilgi kartı (`kWarningContainer`): `Bildirim gönderimi bu sürümde devre dışıdır; ayarlar kaydedilir.` (SPEC-V2 §5 kapsam dışı maddesinin karşılığı — kullanıcıya yalan söylenmez.)
- **Başarı:** `Bildirim ayarları kaydedildi.`

#### E-68 · Sistem Ayarları — `SystemSettingsScreen`

- **AppBar:** `Sistem Ayarları`.
- **Bileşenler:** bölümler hâlinde salt bilgi + birkaç ayar:
  - `Kurum Bilgileri`: `Kurum Adı` (text), `Logo` (tek görsel eki).
  - `Dosya Ayarları` — **tamamı salt okunur** (sunucuda sabittir, API-V2 §9): `En Büyük Dosya Boyutu` → `10 MB`, `İzin Verilen Dosya Türleri` → `JPG, PNG, WEBP, GIF, PDF, DOCX, XLSX`. Bölümün altında `bodySmall`/`kTextSecondary`: `Dosya kısıtları sunucu tarafından belirlenir.` Düzenlenemeyen alan **giriş kutusu olarak gösterilmez** (etiket + değer satırı).
  - `Sistem Bilgisi` (salt okunur): `Sürüm`, `Veritabanı Durumu`, `Son Yedekleme` (`GET /health`). Yedekleme kaydı yoksa değer `Kayıt yok`.
- **Başarı:** `Ayarlar kaydedildi.`

#### E-69 · Form Yönetimi — `FormSettingsScreen`

- **Amaç:** Alanların zorunluluk/görünürlük anahtarları (SPEC-V2 §3.5 `Form Yönetimi`).
- **AppBar:** `Form Yönetimi`.
- **Bileşenler:** form seçici (`Görev Formu`, `Eğitim Formu`, `Etkinlik Formu`, `Toplantı Formu`, `Kişi Formu`, `Talep Formu`, `Gönderi Formu`) → seçilen formun alan listesi. Her satır: alan adı `titleMedium` + iki `Switch`: `Görünür` ve `Zorunlu`.
- **Kilit kuralı:** sistemin çalışması için gereken alanlar (tarih, konum, tür alanları) devre dışıdır; altında `Bu alan sistem tarafından zorunlu tutulur.`
- `Görünür` kapatılırsa `Zorunlu` otomatik kapanır ve devre dışı olur.
- **Başarı:** `Form ayarları kaydedildi.` + bilgi satırı `Değişiklikler kullanıcıların bir sonraki form açılışında geçerli olur.`
- **Boş durum:** yok.

#### E-6A · İçerik Yönetimi — `ContentBlockListScreen`

- **Amaç:** §6.1.1 bilgilendirme metinlerini düzenlemek (`content_blocks`).
- **AppBar:** `İçerik Yönetimi`.
- **Bileşenler:** içerik satırları (`{Modül adı}` + altında gövdenin ilk satırı + `chevron_right`). Dokununca düzenleme ekranı: `Başlık` (text, zorunlu → `Başlık girin.`), `Metin` (multiline 8 satır, zorunlu → `Metin girin.`, maxLength 2000), altında canlı **önizleme kartı** (§6.1.1 görünümüyle birebir).
- **Boş durum:** `Tanımlı içerik bulunmuyor.`
- **Başarı:** `İçerik kaydedildi.`

### 6.6 Profil ve Daha Fazla

#### E-80 · Profil — `ProfileScreen`

v1 §3.20 **korunur**. Eklenenler:
- Avatar yerine kullanıcının **fotoğrafı** (varsa); yoksa v1'deki baş harf dairesi.
- Rol rozeti v1'deki iki değeri korur: `Genel Merkez` · `Saha`.
- Kullanıcının kapsamı varsa rozetin altında satır: `Kapsam: {Bölge} / {İl}` (yalnız dolu olanlar yazılır).
- Yeni satır: `Şifre Değiştir` (`Icons.lock_outline`) → `POST /auth/change-password` · dialog alanları: `Mevcut Şifre`, `Yeni Şifre`, `Yeni Şifre (Tekrar)` (üçü de gizli, göz ikonlu); hata metinleri: `Mevcut şifreyi girin.` · `Yeni şifre en az 8 karakter olmalıdır.` (400 `WEAK_PASSWORD`) · `Şifreler eşleşmiyor.` · sunucu 401 → `Mevcut şifre hatalı.` Başarı: `Şifreniz güncellendi.`
- Sürüm satırı `Sürüm 2.0.0`.

#### E-90 · Daha Fazla — `MoreScreen` (yalnız `< 600`)

- **AppBar:** `Daha Fazla`.
- **Bileşenler:** giriş satırları (ikon + başlık + alt yazı + `chevron_right`):
  1. `Yönetim Paneli` — `Kullanıcılar, tanımlar ve ayarlar` — `Icons.settings_outlined` — **yalnız `genel_merkez`**
  2. `Profil` — `Hesap bilgileri ve çıkış` — `Icons.person_outline`
- Altında ayraç ve `bodySmall`/`kTextSecondary` satırı: `Sürüm 2.0.0`.
- **Boş durum:** olmaz (en az `Profil` bulunur).

---

## 7. Dosya Ekleri (Fotoğraf ve Doküman)

Tek bileşen ailesi, **her yerde aynı**: `AttachmentField` (formda) + `AttachmentList` (detayda) + `AttachmentViewer` (E-71).

### 7.1 Ek türleri (K5 `kind`)

| `kind` | Ekrandaki etiket | Nerede |
|---|---|---|
| `fotograf` | `Fotoğraf` | Görev, Eğitim, Etkinlik, Toplantı, Kişi, Teslim |
| `dokuman` | `Doküman` | Görev, Eğitim, Etkinlik, Gönderi, Birim |
| `tutanak` | `Tutanak` | Toplantı |
| `sunum` | `Sunum` | Toplantı |
| `katilim_listesi` | `Katılım Listesi` | Eğitim |

### 7.2 Kısıtlar ve doğrulama

| Kural | Değer | Aşılırsa gösterilecek metin |
|---|---|---|
| En büyük dosya | **10 MB** (API-V2 §9 — sunucuda sabit) | `Dosya boyutu en fazla 10 MB olabilir.` |
| Fotoğraf türleri | `.jpg .jpeg .png .webp .gif` | `Yalnızca JPG, PNG, WEBP ve GIF dosyaları yükleyebilirsiniz.` |
| Doküman türleri | `.pdf .docx .xlsx` | `Yalnızca PDF, Word (.docx) ve Excel (.xlsx) dosyaları yükleyebilirsiniz.` |
| Kayıt başına en fazla | 20 ek (**istemci kuralı**) | `Bir kayda en fazla 20 dosya ekleyebilirsiniz.` |
| Boş dosya | 0 byte (**istemci kuralı**) | `Dosya boş görünüyor. Başka bir dosya seçin.` |

**Türler API-V2 §9'un izin listesiyle birebir eşleşir.** `.heic`, `.doc`, `.xls`, `.ppt`, `.pptx` **desteklenmez** — dosya seçicinin tür süzgeci bunları hiç göstermez, sürükle-bırakla gelirse yukarıdaki metinle reddedilir. iPhone'dan gelen HEIC görseller için seçici, platformun JPEG dönüştürmesini talep eder (`image_picker` varsayılan davranışı); dönüştürülemezse: `Bu fotoğraf biçimi desteklenmiyor. JPG veya PNG olarak kaydedip tekrar deneyin.`

**Boyut sınırı E-68'den değiştirilemez** — sunucuda sabittir. E-68'deki `En Büyük Dosya Boyutu` alanı **salt okunur** gösterilir (`10 MB`).

**Geçerli `entity` değerleri** (API-V2 §9): `tasks`, `trainings`, `events`, `meetings`, `persons`, `org_units`, `material_requests`, `shipments`, `field_activities`. Bu listede olmayan bir ekrana ek alanı **konmaz** — özellikle `users` ve `org_assignments` ek almaz.

Dosya adı 40 karakteri aşarsa **ortadan** kısaltılır: `katilim_listesi_ege_bol…_2026.xlsx` (baştan ve sondan kesme yasak — uzantı görünür kalmalı).

### 7.3 Formda ek alanı (`AttachmentField`)

```
Fotoğraf
┌──────────────────────────────────────────────────────┐
│  [küçük]  [küçük]  [küçük]   ┌──────────┐            │
│   72×72    72×72    72×72    │  +       │            │
│                              │ Ekle     │            │
│                              └──────────┘            │
└──────────────────────────────────────────────────────┘
3 dosya · toplam 4,2 MB
```
- Bölüm etiketi `titleSmall` (`Fotoğraf` / `Doküman` / …).
- Fotoğraflar `kThumbSize` 72×72 kare küçük görsel, `r8`, 1 px `kBorder`. Sağ üst köşesinde 20 px `Icons.close` düğmesi (`kSurface` daire zemin, `tooltip: 'Eki sil'`).
- Dokümanlar küçük görsel yerine **satır** olarak: uzantı ikonu (`Icons.picture_as_pdf_outlined` `kError` / `Icons.description_outlined` `kInfo` / `Icons.table_view_outlined` `kSuccess`) + dosya adı `bodyMedium` + boyut `bodySmall`/`kTextSecondary` + sağda `Icons.close`.
- `+ Ekle` kutusu: kesikli **olmayan** 1 px `kBorder` çerçeve, ortada `Icons.add` + `Ekle` `bodySmall`.
- Alt bilgi satırı: `{n} dosya · toplam {boyut}`; hiç yoksa gösterilmez.
- **Boş durum (formda):** `+ Ekle` kutusu tek başına + solunda `bodySmall`/`kTextSecondary`: `Henüz dosya eklenmedi.`

### 7.4 Tek görsel deseni (Kişi Fotoğrafı, Kurum Logosu)

- 96×96 daire (kişi) / 96×96 kare `r8` (logo) önizleme; ortada `Icons.add_a_photo_outlined` `kTextSecondary` boşken.
- Altında iki `TextButton`: `Fotoğraf Seç` ve (fotoğraf varsa) `Kaldır`.
- `Kaldır` onayı: `Fotoğrafı kaldır` / `Bu fotoğraf silinecek. Devam edilsin mi?` / `Vazgeç` · `Kaldır`.

### 7.5 Dosya seçme akışı — mobil ve masaüstü farkları

**`< 600` (mobil):** `+ Ekle` → **bottom sheet** `Dosya Ekle`:

| Satır | İkon | Not |
|---|---|---|
| `Fotoğraf Çek` | `Icons.photo_camera_outlined` | yalnız `fotograf` türünde; kamera izni yoksa satır gizlenir |
| `Galeriden Seç` | `Icons.photo_library_outlined` | yalnız `fotograf` türünde; çoklu seçim açık |
| `Dosya Seç` | `Icons.folder_open_outlined` | tüm türlerde |
| `Vazgeç` | — | sheet'i kapatır |

**`>= 600` (tablet/masaüstü):**
- `+ Ekle` **doğrudan** sistem dosya seçicisini açar (ara sheet yok). Kamera seçeneği gösterilmez.
- **Sürükle-bırak zorunludur:** ek alanının tamamı bırakma hedefidir. Sürükleme sırasında alan `kPrimaryContainer` zemine döner, 2 px `kPrimary` çerçeve alır ve ortada `Dosyaları buraya bırakın` yazar.
- **Panodan yapıştırma:** ek alanı odaktayken `Ctrl/Cmd + V` ile pano görseli eklenir; eklenince snackbar `Panodaki görsel eklendi.`
- Birden çok dosya aynı anda seçilebilir; sıraya alınır ve **eşzamanlı en fazla 3** yükleme yapılır.

**İzinler (mobil):** kamera/galeri izni reddedilirse dialog — başlık `İzin gerekli`, gövde `Fotoğraf eklemek için kamera iznine ihtiyaç var. Ayarlardan izin verebilirsiniz.`, aksiyonlar `Vazgeç` / `Ayarları Aç`.

### 7.6 Yükleme ilerlemesi ve durumlar

Her ek öğesi 4 durumdan birindedir:

| Durum | Görünüm | Metin |
|---|---|---|
| `bekliyor` | küçük görsel %40 opaklık + ortada `Icons.schedule` | `Sırada` |
| `yükleniyor` | küçük görsel %40 opaklık + **dairesel** ilerleme (fotoğrafta) / satırda **çizgisel** `LinearProgressIndicator` (dokümanda), `kPrimary` | `%{n}` |
| `tamam` | tam opaklık, kısa `Icons.check_circle` `kSuccess` belirip 1 sn sonra kaybolur | — |
| `hata` | `kErrorContainer` çerçeve + ortada `Icons.error_outline` `kError` | altında `bodySmall` `kError` hata metni + `Tekrar Dene` `TextButton` |

- İlerleme **gerçek yükleme yüzdesidir** (sahte animasyon yasak). Yüzde bilinmiyorsa belirsiz (indeterminate) gösterge kullanılır.
- Yükleme sürerken `Kaydet` butonu **devre dışıdır**; üstünde `bodySmall`/`kTextSecondary`: `Dosyalar yükleniyor, lütfen bekleyin.`
- Yükleme sırasında formdan çıkılmak istenirse dialog: `Yükleme sürüyor` / `Devam eden dosya yüklemeleri iptal edilecek. Çıkmak istiyor musunuz?` / `Vazgeç` · `Çık`.

**Yeni kayıtta ek ekleme — "önce kaydet, sonra yükle" (bağlayıcı akış).**
API-V2 §9'da `POST /attachments` **var olan** bir `entity_id` ister; kayıt oluşmadan dosya yüklenemez. Geçici yükleme ucu **yoktur**. Bu nedenle:

1. Yeni kayıt formunda ek alanı **etkindir**; seçilen dosyalar yüklenmez, yalnız **yerel kuyruğa** alınır ve `bekliyor` durumunda küçük görsel olarak gösterilir. Alanın altında `bodySmall`/`kTextSecondary`: `Dosyalar kayıt tamamlandığında yüklenecek.`
2. `Kaydet`e basılınca sıra: **(a)** `POST /{kayıt}` → dönen `id` alınır · **(b)** kuyruktaki her dosya için sırayla `POST /attachments` (`entity`, `entity_id`, `kind`) · **(c)** tamamlanınca ekrandan çıkılır.
3. (a) ve (b) arasında `Kaydet` butonunun metni `Kaydediliyor...` → `Dosyalar yükleniyor ({i}/{n})...` olarak değişir. Form kilitli kalır.
4. **Kayıt başarılı ama bir dosya yüklenemezse kayıt geri alınmaz.** Ekran kapanmaz; forma düzenleme modunda kalınır, başarısız dosyalar `hata` durumunda `Tekrar Dene` ile listede durur ve üstte `kWarningContainer` banner: `Kayıt oluşturuldu, ancak {n} dosya yüklenemedi. Tekrar deneyebilir veya bu sayfadan çıkabilirsiniz.`
5. Düzenleme modunda (kayıt zaten var) dosyalar **seçilir seçilmez** yüklenir — kuyruk beklemesi yoktur.

**Hata metinleri (yükleme):**

| Sebep | Metin |
|---|---|
| Ağ | `Dosya yüklenemedi. Bağlantınızı kontrol edip tekrar deneyin.` |
| Sunucu (5xx) | `Dosya yüklenemedi. Lütfen tekrar deneyin.` |
| Boyut (413) | `Dosya boyutu en fazla {n} MB olabilir.` |
| Tür (415) | §7.2 tür metni |
| Yetki (403) | `Bu işlem için yetkiniz yok.` (v1 ortak metin) |

### 7.7 Görüntüleme (E-71 · `AttachmentViewer`)

- **Fotoğraf:** tam ekran, siyah zemin, çift dokunuş/parmak ile yakınlaştırma, yatay kaydırma ile kayıttaki diğer fotoğraflar arasında geçiş; üstte `{i} / {n}` ve `Icons.close`; altta dosya adı + `dd.MM.yyyy HH:mm` + yükleyen kullanıcı adı. Sağ üstte `⋮`: `İndir` · `Sil`.
- **Doküman:** uygulama içinde açılmaz; dokununca indirilir/sistem uygulamasında açılır. İndirme sırasında satırda çizgisel ilerleme; başarıda snackbar `Dosya indirildi.` (aksiyon `Aç`), hatada `Dosya indirilemedi. Tekrar deneyin.`
- **Silme onayı:** `Eki sil` / `{Dosya adı} silinecek. Bu işlem geri alınamaz.` / `Vazgeç` · `Sil` (kırmızı). Başarı: `Ek silindi.`
- **Silme yetkisi:** dosyayı yükleyen kullanıcı **veya** `genel_merkez`. Yetkisi olmayanda `⋮` menüsünde `Sil` **hiç render edilmez** (v1 §5 kuralı: gizle, devre dışı bırakma).

### 7.8 Detay ekranında ek listesi (`AttachmentList`)

- Fotoğraflar: 3 sütunlu (`< 600`) / 5 sütunlu (`>= 600`) kare ızgara, aralarında `s8`; dokunuş → E-71.
- Dokümanlar: satır listesi (§7.3 satır deseni, silme yerine `Icons.download`).
- Tür başlıkları `titleSmall` (`Fotoğraf`, `Doküman`, `Tutanak`, `Sunum`, `Katılım Listesi`); boş tür başlığı **gösterilmez**.
- **Boş durum (hiç ek yok):** `Icons.attach_file` 48 px `kTextDisabled` + `Bu kayda eklenmiş dosya bulunmuyor.` (+ yetkiliyse `Dosya Ekle` butonu).

---

## 8. Roller, Kapsam ve Navigasyon Görünürlüğü

**Roller v1'deki gibi ikidir.** API-V2 §1.6 yalnız `genel_merkez` ve `saha` tanımlar; kullanıcıya ayrıca **bilgi amaçlı** bir kapsam (`region_id` / `province_id`) verilebilir, ama bu kapsam **yazma yetkisini kısıtlamaz** (API-V2 §11 notu, v2.1'e bırakılmıştır).

| Rol | API değeri | Yetki |
|---|---|---|
| Genel Merkez | `genel_merkez` | tam yetki |
| Saha | `saha` | faaliyet girişi + okuma |

### 8.1 Navigasyon görünürlüğü

| Hedef | `genel_merkez` | `saha` |
|---|---|---|
| Panel (Dashboard) | ✔ | ✘ |
| Teşkilatlanma | ✔ | ✘ |
| Saha Faaliyetleri | ✔ | ✔ |
| Lojistik | ✔ | ✔ (**yalnız Malzeme Talepleri**; Gönderiler ve Stok gizli) |
| Yönetim Paneli | ✔ | ✘ |
| Profil | ✔ | ✔ |

- **`saha` rolünde alt çubuk 3 sekmelidir**: `Saha` · `Lojistik` · `Profil`. `Daha Fazla` sekmesi **render edilmez**; `Profil` doğrudan sekmedir. Ray düzeninde de yalnız bu 3 hedef görünür.
- `genel_merkez` rolünde alt çubuk 5 sekmelidir; `Daha Fazla` iki satır taşır.
- Giriş sonrası açılan ilk hedef: `saha` → `Saha`; `genel_merkez` → `Panel`.
- E-50 Lojistik ana ekranında `saha` rolü yalnız `Malzeme Talepleri` kartını görür; özet şeridinde yalnız `Açık Talep` sayısı gösterilir.

### 8.2 Kapsam (bilgi amaçlı — kısıtlama değil)

- Kullanıcının `region_id`/`province_id` değeri varsa **formlarda ön dolu gelir** ama **kilitlenmez** (R11 uygulanmaz) — kullanıcı gerçekten başka bir il için kayıt girebilir, sunucu engellemez. Kilitlemek, olmayan bir güvence verirdi.
- Kapsam, listelerde **varsayılan filtre** olarak uygulanır (kullanıcı temizleyebilir); üstte çip: `Kapsamınız: {İl}` + `Icons.close`.
- Kapsam **hiçbir yerde "yetkiniz yok" gibi sunulmaz.** E-62'deki uyarı kartı (§6.5) bunu yöneticiye açıkça söyler.
- Nesne düzeyi yetkilendirme geldiğinde (v2.1) bu bölüm ve E-62 birlikte güncellenir.

### 8.3 Uygulama kuralı

Rol farkları **derleme zamanında gizlenir** — buton devre dışı bırakmak yeterli değildir (v1 §5). API 403 ile ikinci kademe koruma sağlar.

---

## 9. Türkçe Sözlük (v2 eklemeleri)

`lib/core/strings.dart` içine **eklenir**; v1 anahtarları değişmez.

### 9.1 Ortak

| Anahtar | Metin |
|---|---|
| ortak.dahaFazla | `Daha Fazla` |
| ortak.filtreler | `Filtreler` |
| ortak.sirala | `Sırala` |
| ortak.tumunuGor | `Tümünü Gör` |
| ortak.ekle | `Ekle` |
| ortak.kaldir | `Kaldır` |
| ortak.duzenle | `Düzenle` |
| ortak.cik | `Çık` |
| ortak.ac | `Aç` |
| ortak.kopyala | `Kopyala` |
| ortak.indir | `İndir` |
| ortak.filtreleriTemizle | `Filtreleri Temizle` |
| ortak.tabloGorunumu | `Tablo görünümü` |
| ortak.gorseliKaydet | `Görseli kaydet` |
| ortak.excelAktar | `Excel'e aktar` |
| ortak.ilGeneli | `İl geneli` |
| ortak.devamEdiyor | `devam ediyor` |
| ortak.toplam | `Toplam` |
| ortak.sistem | `Sistem` |
| ortak.kayitYok | `Kayıt yok` |

### 9.2 Durum

| Anahtar | Metin |
|---|---|
| durum.aktif | `Aktif` |
| durum.pasif | `Pasif` |
| durum.teskilatYok | `Teşkilat Yok` |
| durum.teskilatYokAlt | `Teşkilatlanma boşluğu` |
| durum.gorevliYok | `Henüz görevli atanmamış.` |
| durum.gorevliAta | `Görevli Ata` |
| durum.gorevliKilit | `Bu birimde aktif görevli bulunduğu için "Teşkilat Yok" seçilemez.` |
| durum.otomatikTeskilatYok | `Birimde görevli kalmadığı için durum "Teşkilat Yok" olarak güncellendi.` |
| durum.otomatikAktif | `Birim durumu "Aktif" olarak güncellendi.` |
| durum.guncellendi | `Durum güncellendi.` |
| talep.talep | `Talep Edildi` |
| talep.onaylandi | `Onaylandı` |
| talep.gonderildi | `Gönderildi` |
| talep.teslimEdildi | `Teslim Edildi` |
| talep.iptal | `İptal Edildi` |
| talep.durumGuncellendi | `Talep durumu güncellendi.` |
| gonderi.yolda | `Yolda` |
| gonderi.teslimEdildi | `Teslim Edildi` |
| stok.kritik | `Stok kritik seviyenin altında.` |
| stok.yok | `Stokta ürün kalmadı.` |
| stok.kritikOzet | `{n} üründe stok kritik seviyenin altında.` |
| stok.yetersiz | `Stok yetersiz. Mevcut stok: {n}.` |

**Durum eşlemesi (API → ekran).** Talep: `talep` → `Talep Edildi` · `onaylandi` → `Onaylandı` · `gonderildi` → `Gönderildi` · `teslim_edildi` → `Teslim Edildi` · `iptal` → `İptal Edildi`. Gönderi durumu **türetilir**: `received_date == null` → `Yolda`, aksi hâlde `Teslim Edildi`.

### 9.3 Navigasyon ve modüller

| Anahtar | Metin |
|---|---|
| nav.panel | `Panel` |
| nav.teskilat | `Teşkilat` |
| nav.saha | `Saha` |
| nav.lojistik | `Lojistik` |
| nav.dahaFazla | `Daha Fazla` |
| modul.dashboard | `Raporlama ve Dashboard` |
| modul.teskilatlanma | `Teşkilatlanma` |
| modul.sahaFaaliyetleri | `Saha Faaliyetleri` |
| modul.lojistik | `Lojistik` |
| modul.yonetimPaneli | `Yönetim Paneli` |
| modul.profil | `Profil` |

### 9.4 Dinamik form

| Anahtar | Metin |
|---|---|
| form.onceSecin | `Önce {alan} seçin.` |
| form.listeYok | `Bu liste henüz tanımlanmamış. Yönetim Paneli → Tanımlar bölümünden ekleyebilirsiniz.` |
| form.listeYokSaha | `Bu liste henüz tanımlanmamış. Genel merkez ile iletişime geçin.` |
| form.tanimEkleUyari | `Aradığınız kayıt listede yoksa Yönetim Paneli → Tanımlar bölümünden eklenmelidir.` |
| form.zorunluBanner | `Lütfen işaretli alanları doldurun.` |
| form.aramaBos | `Aramanızla eşleşen kayıt bulunamadı.` |
| form.bolgeOtomatik | `Seçilen ile göre otomatik belirlendi.` |
| form.altGorevYok | `Bu görev türü için tanımlı alt görev bulunmuyor.` |
| form.konuYok | `Bu kategori ve yöntem için tanımlı konu bulunmuyor.` |
| form.gorevDevam | `Boş bırakılırsa görev devam ediyor sayılır.` |
| form.kirliBaslik | `Değişiklikler kaydedilmedi` |
| form.kirliGovde | `Bu sayfadan çıkarsanız girdiğiniz bilgiler silinecek.` |

**Form doğrulama mesajları (verbatim):**

| Alan | Mesaj |
|---|---|
| Toplantı Yöntemi | `Toplantı yöntemi seçin.` |
| Toplantı Yeri | `Toplantı yerini girin.` / `Toplantı yeri en az 3 karakter olmalıdır.` |
| Platform | `Platform seçin.` |
| Platform Adı | `Platform adını girin.` |
| Görev Türü | `Görev türü seçin.` |
| Alt Görev | `Alt görev seçin.` |
| Eğitim Kategorisi | `Eğitim kategorisi seçin.` |
| Eğitim Yöntemi | `Eğitim yöntemi seçin.` |
| Eğitim Konusu | `Eğitim konusu seçin.` |
| Eğitmen | `Eğitmen adını girin.` |
| Etkinlik Türü | `Etkinlik türü seçin.` |
| Etkinlik Adı | `Etkinlik seçin.` |
| Bölge | `Bölge seçin.` |
| İl | `İl seçin.` |
| Kadın Teşkilatı | `Kadın teşkilatı seçin.` |
| Düzenleyen Teşkilat | `Düzenleyen teşkilat seçin.` |
| Teşkilat Birimi | `Teşkilat birimi seçin.` |
| Kişi | `Kişi seçin.` |
| Görev | `Görev seçin.` |
| Göreve Başlama Tarihi | `Göreve başlama tarihi seçin.` |
| Görev Bitiş Tarihi | `Görev bitiş tarihi başlama tarihinden önce olamaz.` |
| Gönüllü Sayısı | `Gönüllü sayısı girin.` |
| Yararlanıcı Sayısı | `Yararlanıcı sayısı girin.` |
| Katılımcı Sayısı | `Katılımcı sayısı girin.` |
| Süre | `Süre girin.` / `Süreyi saat cinsinden girin (örn. 2,5).` |
| Sayı genel | `Geçerli bir sayı girin.` / `0 ile 999.999 arasında bir değer girin.` |
| Tarih | `Tarih seçin.` / `İleri tarihli kayıt girilemez.` |
| Tarih aralığı | `Bitiş tarihi başlangıç tarihinden önce olamaz.` |
| Gündem | `Gündemi girin.` |
| Alınan Kararlar | `Alınan kararları girin.` |
| Ürün | `Ürün seçin.` |
| Miktar | `Miktar girin.` |
| Gönderim Şekli | `Gönderim şekli seçin.` |
| Kargo Takip No | `Kargo takip numarasını girin.` |
| Teslim Alan | `Teslim alan kişiyi girin.` |
| Teslim Tarihi | `Teslim tarihi gönderi tarihinden önce olamaz.` |
| Talep (gönderide) | `Talep seçin.` |
| Gönderi miktarı | `Miktar, talep edilen miktarı aşamaz.` |
| Ad (tanım) | `Ad girin.` |
| Kod (tanım) | `Kod yalnızca küçük harf, rakam ve alt çizgi içerebilir.` / `Bu kod zaten kullanılıyor.` |
| Üst Tanım | `Üst tanım seçin.` |
| Ad Soyad (kullanıcı) | `Ad soyad girin.` |
| Kapsam Bölge | `En az bir bölge seçin.` |
| Kapsam İl | `En az bir il seçin.` |
| Şifre | `Şifre en az 8 karakter olmalıdır.` / `Şifreler eşleşmiyor.` / `Mevcut şifreyi girin.` / `Mevcut şifre hatalı.` |
| Başlık (içerik) | `Başlık girin.` |
| Metin (içerik) | `Metin girin.` |

### 9.5 Dashboard ve raporlama

| Anahtar | Metin |
|---|---|
| dash.baslik | `Dashboard` |
| dash.teskilatlanmaDurumu | `Teşkilatlanma Durumu` |
| dash.teskilatlanmaKirilimi | `Teşkilatlanma Kırılımı` |
| dash.faaliyetOzeti | `Faaliyet Özeti` |
| dash.egitimDagilimi | `Eğitim Dağılımı (Kategori × Yöntem)` |
| dash.lojistik | `Lojistik` |
| dash.durumDagilimi | `Durum Dağılımı` |
| dash.bolgeBazli | `Bölge Bazlı Teşkilatlanma` |
| dash.ilBazli | `İl Bazlı Teşkilatlanma` |
| dash.aylikTrend | `Aylık Faaliyet Trendi` |
| dash.urunBazli | `Ürün Bazlı Gönderim` |
| dash.toplamBirim | `Toplam Birim` |
| dash.toplamOran | `Toplamın %{n}'i` |
| dash.oncekiDonem | `önceki döneme göre` |
| dash.tumKayitlar | `Tüm kayıtlar gösteriliyor.` |
| dash.ilceTekIl | `İlçe filtresi için tek il seçin.` |
| dash.veriYok | `Seçilen filtrelerle gösterilecek veri bulunamadı.` |
| dash.buAy | `Bu Ay` |
| dash.son3Ay | `Son 3 Ay` |
| dash.buYil | `Bu Yıl` |
| dash.ozel | `Özel` |
| rapor.merkezi | `Rapor Merkezi` |
| rapor.onizleme | `Rapor Önizleme` |
| rapor.disaAktar | `Dışa Aktar` |
| rapor.excel | `Excel (.xlsx)` |
| rapor.pdf | `PDF (.pdf)` |
| rapor.filtreNotu | `Rapor, seçili filtrelere göre oluşturulur.` |
| rapor.indirildi | `Rapor indirildi.` |
| rapor.indirilemedi | `Rapor indirilemedi. Tekrar deneyin.` |
| rapor.kayitYok | `Seçilen filtrelerle kayıt bulunamadı.` |
| rapor.dosyaKaydedilemedi | `Dosya kaydedilemedi. Depolama iznini kontrol edin.` |

### 9.6 Ekler

| Anahtar | Metin |
|---|---|
| ek.fotograf | `Fotoğraf` |
| ek.dokuman | `Doküman` |
| ek.tutanak | `Tutanak` |
| ek.sunum | `Sunum` |
| ek.katilimListesi | `Katılım Listesi` |
| ek.dosyaEkle | `Dosya Ekle` |
| ek.fotografCek | `Fotoğraf Çek` |
| ek.galeridenSec | `Galeriden Seç` |
| ek.dosyaSec | `Dosya Seç` |
| ek.fotografSec | `Fotoğraf Seç` |
| ek.buraya | `Dosyaları buraya bırakın` |
| ek.panoEklendi | `Panodaki görsel eklendi.` |
| ek.bosDurum | `Henüz dosya eklenmedi.` |
| ek.detayBos | `Bu kayda eklenmiş dosya bulunmuyor.` |
| ek.sirada | `Sırada` |
| ek.yukleniyorUyari | `Dosyalar yükleniyor, lütfen bekleyin.` |
| ek.cikisBaslik | `Yükleme sürüyor` |
| ek.cikisGovde | `Devam eden dosya yüklemeleri iptal edilecek. Çıkmak istiyor musunuz?` |
| ek.silBaslik | `Eki sil` |
| ek.silGovde | `{dosya} silinecek. Bu işlem geri alınamaz.` |
| ek.silindi | `Ek silindi.` |
| ek.indirildi | `Dosya indirildi.` |
| ek.indirilemedi | `Dosya indirilemedi. Tekrar deneyin.` |
| ek.hataAg | `Dosya yüklenemedi. Bağlantınızı kontrol edip tekrar deneyin.` |
| ek.hataSunucu | `Dosya yüklenemedi. Lütfen tekrar deneyin.` |
| ek.hataBoyut | `Dosya boyutu en fazla 10 MB olabilir.` |
| ek.hataFotoTur | `Yalnızca JPG, PNG, WEBP ve GIF dosyaları yükleyebilirsiniz.` |
| ek.hataDokTur | `Yalnızca PDF, Word (.docx) ve Excel (.xlsx) dosyaları yükleyebilirsiniz.` |
| ek.hataBicim | `Bu fotoğraf biçimi desteklenmiyor. JPG veya PNG olarak kaydedip tekrar deneyin.` |
| ek.kuyrukNotu | `Dosyalar kayıt tamamlandığında yüklenecek.` |
| ek.kismiHata | `Kayıt oluşturuldu, ancak {n} dosya yüklenemedi. Tekrar deneyebilir veya bu sayfadan çıkabilirsiniz.` |
| ek.hataAdet | `Bir kayda en fazla 20 dosya ekleyebilirsiniz.` |
| ek.hataBos | `Dosya boş görünüyor. Başka bir dosya seçin.` |
| ek.izinBaslik | `İzin gerekli` |
| ek.izinGovde | `Fotoğraf eklemek için kamera iznine ihtiyaç var. Ayarlardan izin verebilirsiniz.` |
| ek.ayarlariAc | `Ayarları Aç` |
| ek.fotografKaldirBaslik | `Fotoğrafı kaldır` |
| ek.fotografKaldirGovde | `Bu fotoğraf silinecek. Devam edilsin mi?` |

### 9.7 Boş durum metinleri (ekran bazlı, hepsi bir arada)

| Ekran | Metin |
|---|---|
| E-21 Koordinasyon Kurulu | `Kurulda görevli bulunmuyor.` |
| E-22 Bölge Temsilcileri (filtre) | `Seçilen duruma uyan bölge bulunmuyor.` |
| E-23 Komisyonlar | `Henüz komisyon tanımlanmamış.` |
| E-24 İl Başkanlıkları (filtre) | `Seçilen duruma uyan il başkanlığı bulunmuyor.` |
| E-25 İlçe Başkanlıkları (il seçilmedi) | `İlçe başkanlıklarını görmek için önce bir il seçin.` |
| E-25 İlçe Başkanlıkları | `Bu ilde ilçe başkanlığı kaydı bulunmuyor.` |
| E-26 Temsilcilikler | `Kayıtlı temsilcilik bulunmuyor.` |
| E-27 Görevliler | `Bu birimde görevli bulunmuyor.` |
| E-27 Alt Birimler | `Bu ile bağlı alt birim kaydı bulunmuyor.` |
| E-29 Görevlendirmeler | `Bu kişinin görevlendirmesi bulunmuyor.` |
| E-41 Görevler | `Henüz görev kaydı yok.` |
| E-43 Eğitimler | `Henüz eğitim kaydı yok.` |
| E-45 Etkinlikler | `Henüz etkinlik kaydı yok.` |
| E-47 Etkinlik Seçici | `Bu tür için takvimde etkinlik bulunmuyor.` / `Aramanızla eşleşen etkinlik bulunamadı.` |
| E-48 Toplantılar | `Henüz toplantı kaydı yok.` |
| E-51 Talepler | `Henüz malzeme talebi yok.` |
| E-53 Gönderiler | `Henüz gönderi kaydı yok.` |
| E-56 Stok | `Stok kaydı bulunmuyor.` |
| E-57 Stok Hareketleri | `Bu ürün için hareket kaydı bulunmuyor.` |
| E-61 Kullanıcılar | `Kayıtlı kullanıcı bulunamadı.` / `Aramanızla eşleşen kullanıcı bulunamadı.` |
| E-64 Tanım Öğeleri | `Bu kategoride henüz tanım yok.` |
| E-6A İçerik Yönetimi | `Tanımlı içerik bulunmuyor.` |
| Ortak liste alt metni | `İlk kaydı eklemek için + butonuna dokunun.` |

### 9.8 Başarı bildirimleri (snackbar)

| Anahtar | Metin |
|---|---|
| basari.gorev | `Görev kaydedildi.` |
| basari.egitim | `Eğitim kaydedildi.` |
| basari.etkinlik | `Etkinlik kaydedildi.` |
| basari.toplanti | `Toplantı kaydedildi.` |
| basari.gorevlendirme | `Görevlendirme kaydedildi.` |
| basari.talep | `Talep kaydedildi.` |
| basari.gonderi | `Gönderi kaydedildi.` |
| basari.teslim | `Teslim bilgisi kaydedildi.` |
| basari.gonderiStok | `Gönderi kaydedildi. Stok güncellendi.` |
| basari.kritikSeviye | `Kritik seviye güncellendi.` |
| basari.sifreBelirle | `Şifre güncellendi.` |
| basari.tanim | `Tanım kaydedildi.` |
| basari.siralama | `Sıralama güncellendi.` |
| basari.kullanici | `Kullanıcı kaydedildi.` |
| basari.yetki | `Yetkiler güncellendi.` |
| basari.bildirimAyar | `Bildirim ayarları kaydedildi.` |
| basari.ayarlar | `Ayarlar kaydedildi.` |
| basari.formAyar | `Form ayarları kaydedildi.` |
| basari.icerik | `İçerik kaydedildi.` |
| basari.sifre | `Şifreniz güncellendi.` |
| basari.takipKopya | `Takip numarası kopyalandı.` |

### 9.9 Onay dialogları (başlık / gövde / aksiyonlar)

| Bağlam | Başlık | Gövde | Aksiyonlar |
|---|---|---|---|
| Durum değiştir (birim) | `Durumu değiştir` | `{Birim adı} durumu "{yeni durum}" olarak güncellenecek. Onaylıyor musunuz?` | `Vazgeç` · `Onayla` |
| Görevi sonlandır | `Görevi sonlandır` | `Görev bitiş tarihini seçin.` | `Vazgeç` · `Kaydet` |
| Görevden çıkar | `Görevden çıkar` | `Bu kişi listeden kaldırılacak. Devam edilsin mi?` | `Vazgeç` · `Çıkar` |
| Görev kaydı sil | `Görev kaydı silinsin mi?` | `Bu işlem geri alınamaz.` | `Vazgeç` · `Sil` |
| Toplantı sil | `Toplantı kaydı silinsin mi?` | `Bu işlem geri alınamaz.` | `Vazgeç` · `Sil` |
| Talebi iptal et | `Talebi iptal et` | `Bu talep iptal edilecek. Devam edilsin mi?` | `Vazgeç` · `İptal Et` |
| Talep silinemez (409) | `Talep silinemiyor` | `Bu talebe bağlı gönderi kaydı olduğu için silinemez. Talebi iptal edebilirsiniz.` | `Tamam` |
| Şifre belirle | `Şifre belirle` | `{Ad Soyad} için yeni bir şifre belirleyin.` *(iki şifre alanı)* | `Vazgeç` · `Kaydet` |
| Son yönetici (409) | `İşlem yapılamıyor` | `Sistemdeki son genel merkez hesabı pasif yapılamaz.` | `Tamam` |
| Tanım silinemez | `Tanım silinemiyor` | `Bu tanım kayıtlarda kullanıldığı için silinemez. Pasif yapabilirsiniz.` | `Tamam` |
| Ek sil | `Eki sil` | `{Dosya adı} silinecek. Bu işlem geri alınamaz.` | `Vazgeç` · `Sil` |
| Yükleme sürerken çıkış | `Yükleme sürüyor` | `Devam eden dosya yüklemeleri iptal edilecek. Çıkmak istiyor musunuz?` | `Vazgeç` · `Çık` |
| Kirli form çıkışı | `Değişiklikler kaydedilmedi` | `Bu sayfadan çıkarsanız girdiğiniz bilgiler silinecek.` | `Vazgeç` · `Çık` |

---

## 10. Çözülen Belirsizlikler (kayıt)

Aşağıdakiler SPEC-V2'de açık bırakılmıştı; **karar burada verildi ve bağlayıcıdır.** API yazarı farklı bir yol seçerse bu belge güncellenmelidir.

1. **6 hedef, 5 sekme.** "Daha Fazla" sekmesi seçildi, çekmece reddedildi (gerekçe §2.1). `>= 600`'de `Daha Fazla` kaybolur, iki çocuğu ray hedefi olur.
2. **Bölge iki kez tanımlı.** SPEC-V2 K1 `bolge`'yi lookup kategorisi, K2 `regions`'ı tablo yapıyor. **Karar:** arayüz bölgeleri `GET /regions`'tan okur; `bolge` lookup kategorisi formlarda kullanılmaz (yalnız geriye dönük uyum için durabilir).
3. **`durum` lookup kategorisi.** K1'de `durum` kategorisi var, K3'te ise `status` sabit üç değerli enum. **Karar:** durum **koddaki sabit enum**dur (3 değer); `durum` lookup'u arayüzde hiç kullanılmaz. Tanımlar ekranında da gösterilmez.
4. **`etkinlik_adi` lookup vs. `calendar_events`.** K1 `etkinlik_adi` kategorisini, K6 `calendar_events` tablosunu tanımlıyor. **Karar:** etkinlik adı **takvimden** (`calendar_events`) seçilir (SPEC §3.2C "listeden seçilir" ifadesi takvimi kastediyor). `etkinlik_adi` lookup kategorisi kullanılmaz; Tanımlar ekranında yerine `Etkinlik Takvimi` satırı görünür.
5. **`Platform` alanının kaynağı yok.** SPEC §3.2D "Platform" alanını istiyor ama K1 listesinde karşılığı yok; API-V2 ise `platform`'u **serbest metin sütunu** yaptı. **Karar:** arayüz yine dropdown gösterir (`GET /lookups/toplanti_platformu`) ve seçilenin **adını metin olarak** yazar; kategori yoksa (404) serbest metne düşer (§4.3c). Böylece hem API sözleşmesi hem "minimum serbest metin" ilkesi korunur.
6. **`Şube` alanının kaynağı.** SPEC §3.2A `Şube` alanını istiyor. API-V2 §6.1 `branch`'i **serbest metin** yaptı. **Karar:** API'ye uyuldu; serbest metin + **daha önce girilmiş değerlerden otomatik tamamlama** ile yazım tekilleştirilir (E-42). Lookup'a dönüştürülmesi v2.1 önerisidir.
7. **`Süre` biriminin belirsizliği.** **Karar:** ekranda `Süre (saat)`, Türkçe virgüllü ondalık (`2,5`); API alanı `duration_hours` **ondalık saat** olduğundan yalnız virgül↔nokta dönüşümü yapılır. (İlk taslaktaki dakikaya çevirme kararı API-V2'ye göre iptal edildi.)
8. **Toplantı `Katılımcılar` alanı: sayı mı isim listesi mi?** API-V2 §6.4 `participants`'ı **tek serbest metin** sütunu yaptı; katılımcı sayısı sütunu yok. **Karar:** tek serbest metin alanı (ipucu `Örn. 12 kurul üyesi`). Ayrı `Katılımcı Sayısı` alanı ve kişi seçici **kaldırıldı**; raporda toplantı katılımı sayısal olarak toplanamaz — bu bilinen bir kısıttır (§11 N-6).
9. **"Teşkilat Yok" kişiye uygulanabilir mi?** **Karar:** hayır. Üçüncü durum yalnız `org_units`'e aittir; kişi ve kullanıcı yalnız `Aktif`/`Pasif` alır (§3.3b). Kişi listelerinde bu çip hiç render edilmez.
10. **"Teşkilat Yok" için yeni renk token'ı.** **Karar:** yeni token eklenmedi; mevcut `kWarning`/`kWarningContainer` kullanılır. Kırmızı reddedildi (marka + hata rengi). Görevlendirme durumundaki `Devam Ediyor` ile aynı aile olduğu için **ikon zorunlu kılındı** — ayrıca ikisi aynı listede hiç bulunmaz.
11. **İlçe zorunlu mu?** **Karar:** hayır. İl düzeyinde faaliyet olabilir; boş seçenek `İl geneli` etiketiyle gösterilir (`Seçilmedi` yerine).
12. **Bölge seçmeden il seçilebilir mi?** **Karar:** evet. İl seçilince Bölge otomatik dolar ve kilitlenir (§4.3a). Zorunlu tepeden-aşağı akış, 81 il arasından hızlı seçim yapmak isteyen kullanıcıyı yavaşlatırdı.
13. **Alt görevi olmayan görev türü.** **Karar:** `Alt Görev` alanı gizlenir (boş dropdown gösterilmez) ve `null` gönderilir.
14. **Grafik renkleri.** **Karar:** Kızılay kırmızısı seri rengi olarak kullanılmaz; ayrı, doğrulanmış 7 renkli kategorik palet tanımlandı (§1.3). Durum renkleri kategorik paletten ayrıdır ve seri rengi olamaz.
15. **Harita görünümü.** SPEC §3.4 harita istiyor, §5 onu v2.1'e atıyor. **Karar:** v2 Dashboard'ında harita **yoktur** ve yer tutucu da konmaz; il yoğunluğu sıralı çubuk grafikle verilir (§5.3B).
16. **Karanlık tema.** **Karar:** v2'de yok (gerekçe §0). Palet yalnız açık zemin için doğrulandı.
17. **Kırılma noktası geçişinde yığın.** **Karar:** yığınlar korunur ve taşınır; kullanıcı pencereyi yeniden boyutlandırınca çalıştığı ekrandan atılmaz (§2.2).
18. **Bildirim modülü kapsam dışı ama menüde var.** **Karar:** ekran yapılır, ayarlar kaydedilir, üstte açık bir bilgi kartıyla gönderimin devre dışı olduğu **yazılır** (E-67). Çalışıyormuş gibi gösterilmez.
19. **Yeni kayıtta dosya eki.** API-V2 §9 geçici yükleme sunmuyor; `entity_id` şart. **Karar:** "önce kaydet, sonra yükle" akışı (§7.6): dosyalar yerel kuyrukta bekler, kayıt oluşunca sırayla yüklenir; kısmi başarısızlıkta kayıt geri alınmaz, kullanıcı bilgilendirilir.
20. **v1 `is_active` uyumluluğu.** API-V2 §0 `is_active`'i türetilmiş döndürmeye devam ediyor. **Karar:** v2 arayüzü **yalnız `status` alanını okur ve yazar** (`PATCH /persons/:id/status`, `PATCH /org-units/:id/status`); `is_active` istemcide hiç kullanılmaz — aksi hâlde `teskilat_yok` birim `pasif` gibi görünürdü. **Tek istisna:** `users` kaynağında `status` yoktur, `is_active` kullanılır (§6.5 E-62).
21. **Roller: dört mü, iki mi?** İlk taslak SPEC-V2 §3.5'teki "bölge/il sınırlı kullanıcı" ifadesinden dört rol türetmişti. API-V2 §1.6 yalnız **iki rol** tanımlar; kapsam alanları kaydedilir ama **yetki kısıtlamaz** (§11 notu). **Karar:** iki rol (§8). Kapsam alanları formda "kilitli" değil "ön dolu" olarak sunulur ve E-62'de yöneticiye kapsamın kısıtlama olmadığı **açıkça yazılır** — arayüz, sistemin sağlamadığı bir güvenceyi ima etmez.
22. **Gönderi bağımsız oluşturulabilir mi?** API-V2 §7.2 `request_id`'yi zorunlu kılıyor. **Karar:** hayır — her gönderi bir talepten türer (E-54). Ürün/miktar/alıcı talepten okunur, formda salt okunur gösterilir.
23. **Talep reddi.** İlk taslakta `Reddedildi` durumu ve `Ret Gerekçesi` alanı vardı; API'de karşılığı yok. **Karar:** akış `İptal Et` (`status = iptal`) olarak sadeleştirildi, gerekçe alanı kaldırıldı.
24. **Gönderi durumu.** API'de `shipments.status` sütunu yok. **Karar:** durum `received_date`ten **türetilir** (`Yolda` / `Teslim Edildi`); üçüncü bir durum uydurulmaz.
25. **Bilgilendirme metinleri yalnız Teşkilatlanma'da mı?** SPEC-V2 §3.1 öyle diyor, API 13 anahtar tohumluyor. **Karar:** bileşen Saha, Lojistik, Raporlama ve Yönetim ana ekranlarında da kullanılır (§6.1.1 tablosu) — metin yoksa hiç render edilmediği için ek maliyet yok.

---

## 11. API-V2 Uyum Notları

`docs/API-V2.md` bağlayıcıdır. Bu belge ona uyumlandı; kalan boşluklar aşağıda kayıtlıdır.
**Her boşluk için arayüzün ne yapacağı yazılıdır — geliştirici karar vermez.**

### 11.1 Eksik uçlar ve geri düşüşler

| # | Eksik | Arayüzün davranışı | İstenen uç |
|---|---|---|---|
| **N-1** | İl bazlı teşkilatlanma kırılımı | `GET /org-units?type=il_baskanligi&limit=1000` ile istemcide sayılır, oturum önbelleğine alınır | `GET /dashboard/by-province` |
| **N-2** | Aylık faaliyet zaman serisi | **Trend kartı hiç render edilmez** (yer tutucu konmaz) | `GET /dashboard/by-month?from=&to=&metric=` |
| **N-3** | Eğitim kategori × yöntem kesişimi | 4 adet `GET /trainings?...&limit=1` çağrısının `total`'ı okunur; kesişim sayısı 6'yı aşarsa bölüm gizlenir | `GET /dashboard/trainings-matrix` |
| **N-4** | Ürün bazlı gönderim kırılımı | `GET /shipments?limit=1000` istemcide gruplanır; `total > 1000` ise kart gizlenir | `GET /dashboard/by-product` |
| **N-5** | `dashboard/summary` yalnız 4 parametre alır | `İlçe` ve `Faaliyet Türü` filtreleri grafiklere uygulanmaz; kullanıcıya §5.5'teki bilgi satırıyla **açıkça söylenir**; çoklu bölge/il seçiminde ilki gönderilir | `district_id`, `task_type_id` desteği + çoklu değer |
| **N-6** | Toplantı katılımcı **sayısı** sütunu yok | Katılım yalnız serbest metin; toplantı katılımı raporda sayısal toplanamaz | `meetings.participant_count` |
| **N-7** | `toplanti_platformu` lookup kategorisi tohumlanmıyor | 404 alınınca alan serbest metne düşer (§4.3c); E-63'ten oluşturulabilir | kategori + 5 öğe tohumu |
| **N-8** | PDF dışa aktarım ucu tanımlı değil | E-14/E-16'daki `PDF` düğmesi, uç 404 dönerse **gizlenir**; yalnız `Excel` kalır. Devre dışı buton gösterilmez. | `GET /export/*.pdf` |
| **N-9** | `org_assignments` son görev bitince birimi `teskilat_yok`a düşürmüyor | API yalnız **ters yönü** garanti eder (ilk görev → `aktif`). Son aktif görev sonlandırılınca istemci kullanıcıya sorar: dialog `Birimde görevli kalmadı` / `Birim durumunu "Teşkilat Yok" olarak güncellemek ister misiniz?` / `Hayır` · `Evet` → `PATCH /org-units/:id/status`. **Sessiz otomatik değişiklik yapılmaz.** | otomatik geri düşüş |

**§3.4'teki otomatik durum kuralı N-9'a göre okunur:** `Aktif`e geçiş sunucuda otomatiktir (snackbar `Birim durumu "Aktif" olarak güncellendi.` sunucu yanıtı doğruladıktan sonra gösterilir); `Teşkilat Yok`a dönüş **kullanıcı onaylıdır**.

### 11.2 Hata kodu → Türkçe metin eşlemesi

`ApiException.code` alanından okunur. Eşleşme yoksa v1 `hata.genel` kullanılır.

| Kod | HTTP | Gösterilecek metin | Sunum |
|---|---|---|---|
| `VALIDATION_ERROR` | 400 | *(alan bazlı mesaj; yoksa)* `Girdiğiniz bilgilerde hata var. Lütfen kontrol edin.` | alan altı / banner |
| `INVALID_JSON` | 400 | `Bir şeyler ters gitti.` | snackbar |
| `INVALID_TC_NO` | 400 | `Geçersiz TC kimlik numarası.` | alan altı |
| `UNSUPPORTED_FILE_TYPE` | 400 | §7.2 tür metni | ek öğesi altında |
| `FILE_TOO_LARGE` | 400 | `Dosya boyutu en fazla 10 MB olabilir.` | ek öğesi altında |
| `WEAK_PASSWORD` | 400 | `Şifre en az 8 karakter olmalıdır.` | alan altı |
| `INSUFFICIENT_STOCK` | 400 | `Stok yetersiz. Mevcut stok: {n}.` | alan altı |
| `UNAUTHORIZED` | 401 | `Oturum süreniz doldu. Lütfen tekrar giriş yapın.` | snackbar + Giriş ekranı |
| `ACCOUNT_DISABLED` | 401 | `Hesabınız pasif durumda. Genel merkez ile iletişime geçin.` | Giriş ekranında banner |
| `FORBIDDEN` | 403 | `Bu işlem için yetkiniz yok.` | snackbar |
| `NOT_FOUND` | 404 | `Kayıt bulunamadı. Silinmiş olabilir.` | snackbar + listeye dönüş |
| `CONFLICT` | 409 | *(bağlama özel: TC / e-posta / kod / birim çakışması metni)* | alan altı |
| `IN_USE` | 409 | *(bağlama özel: tanım / talep silinemez metni)* | dialog |
| `LAST_ADMIN` | 409 | `Sistemdeki son genel merkez hesabı pasif yapılamaz.` | dialog |
| `INTERNAL` | 500 | `Bir şeyler ters gitti.` + `Tekrar Dene` | v1 §4.5 hata kalıbı |

`ACCOUNT_DISABLED` sözlük anahtarı: `hata.hesapPasif` → `Hesabınız pasif durumda. Genel merkez ile iletişime geçin.`
`NOT_FOUND` sözlük anahtarı: `hata.bulunamadi` → `Kayıt bulunamadı. Silinmiş olabilir.`

### 11.3 Alan adı eşlemesi (form etiketi → API alanı)

| Ekran | Etiket | API alanı |
|---|---|---|
| E-42 | Tarih · Şube · Kadın Teşkilatı · Görev Türü · Alt Görev · Süre (saat) | `task_date` · `branch` · `org_unit_id` · `task_type_id` · `sub_task_id` · `duration_hours` |
| E-44 | Tarih · Düzenleyen Teşkilat · Eğitmen · Konu · Kategori · Yöntem | `training_date` · `org_unit_id` · `trainer` · `topic_id` · `category_id` · `method_id` |
| E-46 | Tarih · Etkinlik Adı · Etkinlik Türü | `event_date` · `calendar_event_id` · `event_type_id` |
| E-49 | Toplantı Türü · Yöntem · Toplantı Yeri · Platform · Katılımcılar · Gündem · Alınan Kararlar · Sonuç | `meeting_type_id` · `method_id` · `location` · `platform` · `participants` · `agenda` · `decision` · `outcome` |
| E-52 | Talep Tarihi · Talep Eden Teşkilat · Ürün · Miktar · Talep Eden Kişi | `request_date` · `org_unit_id` · `product_id` · `quantity` · `requested_by_person_id` |
| E-54 | Talep · Gönderi Tarihi · Gönderim Şekli · Kargo Takip No · Teslim Alan · Teslim Tarihi | `request_id` · `shipment_date` · `shipping_method_id` · `tracking_no` · `received_by` · `received_date` |
| E-28 | Teşkilat Birimi · Kişi · Görev · Göreve Başlama · Görev Bitiş | `org_unit_id` · `person_id` · `role_id` (+`role_title`) · `start_date` · `end_date` |

Tüm faaliyet formlarında `region_id` gönderilmeyebilir — sunucu `province_id`'den türetir (API-V2 §1.3). Arayüz yine de seçili bölgeyi gönderir.

---

## 12. Geliştirici Uygulama Sırası (öneri)

1. **Temel:** `tokens.dart` eklemeleri (§1) · `AdaptiveShell` + `NavigationBar`/`NavigationRail` (§2) · `StatusBadge` (§3).
2. **Motor:** `DynamicForm` + `FieldSpec` + lookup önbelleği (§4). **Bu adım bitmeden hiçbir form ekranına başlanmaz** — 15+ form aynı motoru kullanacak.
3. **Ekler:** `AttachmentField` / `AttachmentList` / `AttachmentViewer` (§7).
4. **Teşkilatlanma:** E-20…E-30 (motor + rozet + ekler burada birlikte sınanır).
5. **Saha Faaliyetleri:** E-40…E-49 (motorun kademeli/koşullu/matris/seçici kurallarının tamamı burada kullanılır).
6. **Lojistik:** E-50…E-57.
7. **Dashboard ve Raporlama:** E-10…E-17 (`fl_chart` + filtre çubuğu + tablo görünümü).
8. **Yönetim Paneli:** E-60…E-6A (Tanımlar ekranı olmadan diğer modüller tohum veriyle çalışır; ama teslimden önce şart).

---

**UX Architect** · v2 temeli hazır · Sonraki adım: `docs/API-V2.md` ile uç nokta adlarının eşlenmesi, ardından Flutter uygulaması.
