# Kurulum ve Erişim Rehberi

Bu belge üç ayrı soruyu ayırır, çünkü cevapları çok farklı:

| Kişi ne yapacak? | Ne kurması gerekir? |
|---|---|
| **Sadece test edecek** (açıp kullanacak) | **Hiçbir şey** — sunucuya kurulursa yalnız tarayıcı yeter |
| Kendi bilgisayarında çalıştıracak | Node.js (+ isteğe bağlı Git) — **Flutter'a gerek yok** |
| Kod yazacak | Node.js + Flutter + Git + editör |

> **Önemli:** Flutter yalnızca uygulamayı **derlemek** için gerekli. Derlenmiş uygulama
> (`app/build/web`) sıradan HTML/JS dosyalarıdır; çalıştırmak için Flutter gerekmez.

---

## Senaryo A — Önerilen: sunucuya kurulum (arkadaşınız hiçbir şey kurmaz)

"Her an güncel haliyle açıp test edebilmesi" isteğinin doğru karşılığı budur.
Sistem zaten bulut tabanlı çalışacak şekilde tasarlandı.

### Gerekenler
1. **Uzak kod deposu** — şu an proje yalnız bu bilgisayarda, uzak depo yok.
   GitHub (özel depo) veya GitLab. *Ücretsiz.*
2. **Sunucu / barındırma.** Backend Node.js, veritabanı SQLite (dosya tabanlı),
   arayüz statik dosyalar. Uygun seçenekler:

   | Seçenek | Aylık maliyet | Not |
   |---|---|---|
   | **Hetzner / DigitalOcean VPS** | ~5–8 € | En esnek, kalıcı disk sorunsuz. **Önerilen.** |
   | Render / Railway | 0–7 $ | Kolay kurulum, ancak **kalıcı disk (persistent volume) şart** |
   | Kurum içi sunucu | — | KVKK açısından en güvenli; Kızılay BT'nin sunucusu |

   > ⚠️ **Kritik uyarı:** Render/Railway gibi servislerin ücretsiz katmanlarında dosya
   > sistemi geçicidir. Kalıcı disk tanımlanmazsa **her yeniden başlatmada veritabanı
   > sıfırlanır**. SQLite dosyası (`backend/data/app.db`) kalıcı bir diskte durmalıdır.

3. **Alan adı + HTTPS** (ör. `tys.kizilaykadin.org`). Let's Encrypt ile ücretsiz sertifika.
   TC kimlik numarası taşındığı için **HTTPS zorunlu** sayılmalıdır.

### Sonuç
Arkadaşınız yalnızca tarayıcıdan adrese girer ve kendi kullanıcısıyla oturum açar.
Kurulum yapmaz, güncelleme beklemez — siz dağıtım yaptıkça hep güncel sürümü görür.

### Ek: telefonda test
Uygulama mobil uyumlu olduğu için telefon tarayıcısından da açılır ve "Ana ekrana ekle"
denildiğinde uygulama gibi görünür. Gerçek Android/iOS kurulumu isterseniz APK/IPA
derlemesi gerekir — bunun için bu bilgisayarda **Android SDK / Xcode kurulu değil**
(bilinen eksik), önce o kurulmalı.

---

## Senaryo B — Arkadaşınız kendi bilgisayarında çalıştıracak

Sunucu kurulmadan önceki geçici çözüm. **Flutter gerekmez.**

### Kurulacaklar
| # | Yazılım | Sürüm | Nereden | Not |
|---|---|---|---|---|
| 1 | **Node.js** | 20 LTS veya üzeri | nodejs.org (LTS) | Backend'i çalıştırır. Kurulum sihirbazı yeterli. |
| 2 | **Git** *(isteğe bağlı)* | güncel | git-scm.com | Güncellemeleri çekmek için. Olmazsa dosyaları zip ile paylaşırsınız. |
| 3 | Tarayıcı | Chrome / Edge güncel | — | Zaten var |

**Windows notu:** Backend'in SQLite bağımlılığı (`better-sqlite3`) hazır derlenmiş
ikili indirir, yani normal şartlarda derleyici gerekmez. İndirme başarısız olursa
"Visual Studio Build Tools (C++)" + Python 3 kurulumu gerekir — nadir bir durumdur.

### Gönderilmesi gerekenler
Proje klasörünü **`node_modules` ve `build` hariç** paylaşın (zip ~5 MB), veya Git deposundan çeksin.
`backend/data/turkey-provinces-districts.json` dosyası mutlaka içinde olsun — 81 il ve
973 ilçe verisinin kaynağı odur.

### Çalıştırma (iki terminal)
```bash
# 1. terminal — backend (ilk seferde: npm install)
cd Kızılay/backend
npm install
KK_SEED_DEMO=1 npm start
```
```bash
# 2. terminal — arayüz
cd Kızılay/app
python3 -m http.server 5757 -d build/web
```
Windows'ta Python yoksa ikinci komut yerine:
```bash
npx serve build/web -l 5757
```
Sonra tarayıcıdan **http://localhost:5757**

> **Dikkat:** Bu yöntemde arkadaşınız **kendi kopyasını** görür; sizin verinizi görmez ve
> güncel sürüm için her seferinde dosyaları yeniden almanız gerekir. "Her an güncel"
> gereksinimini tam karşılamaz — bu yüzden Senaryo A önerilir.

---

## Senaryo C — Arkadaşınız kod da yazacak

Senaryo B'deki her şeye ek olarak:

| # | Yazılım | Sürüm | Not |
|---|---|---|---|
| 1 | **Flutter SDK** | 3.41+ (Dart 3.11.5+) | docs.flutter.dev — arayüzü derlemek için |
| 2 | **Git** | güncel | Zorunlu (isteğe bağlı değil) |
| 3 | **VS Code** + Flutter/Dart eklentileri | güncel | Veya Android Studio |
| 4 | Android Studio + Android SDK | *yalnız mobil derleme için* | APK üretmek isterse |
| 5 | Xcode | *yalnız iOS için, Mac şart* | iOS derlemesi isterse |

Kurulum doğrulaması:
```bash
flutter doctor
```

Geliştirme çalıştırması:
```bash
cd app && flutter run -d chrome
```

Testler:
```bash
cd backend && npm test     # 369 kontrol
cd app && flutter test     # 88 test
```

---

## Özet tavsiye

1. **Önce uzak depo açın** (GitHub özel depo) — proje şu an tek bilgisayarda duruyor,
   bu başlı başına bir risk.
2. **Sunucuya kurun** (Senaryo A). Arkadaşınız hiçbir şey kurmadan, her zaman güncel
   sürümü test eder; ayrıca gerçek kullanıcı testine de bu şekilde geçilir.
3. Sunucu hazır olana kadar geçici olarak Senaryo B ile ilerleyin.

### Sunucuya çıkmadan önce mutlaka yapılacaklar
- `KK_JWT_SECRET` ortam değişkenini değiştirin (varsayılan anahtar depoda açık).
- Tohum şifreleri (`Admin!2026` / `Saha!2026`) değiştirin; gerçek kullanıcıları
  Yönetim Paneli → Kullanıcı Yönetimi'nden açın.
- `npm run db:reset` ile demo kayıtları temizleyin (referans veri korunur).
- HTTPS'i zorunlu kılın (TC kimlik numarası taşınıyor).
- Veritabanı yedeklemesi planlayın (`backend/data/app.db`) — henüz prosedür yok.
