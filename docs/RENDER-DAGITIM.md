# Render Dağıtımı — Kalıcılık Uyarısı ve Yapılandırma

**Canlı adres:** https://kizilaykadin.onrender.com
**Tarih:** 2026-08-03

## ⚠️ En kritik konu: veriler kalıcı değil

Sistem SQLite kullanıyor ve veritabanı dosyası `backend/data/app.db`, yüklenen dosyalar
ise `backend/uploads/` altında duruyor. **Render'da web servislerinin dosya sistemi
geçicidir** — her yeni dağıtımda (deploy) ve servis yeniden başladığında disk sıfırlanır.

Sonuç: **girilen tüm kişiler, faaliyetler, toplantılar, dokümanlar ve yüklenen dosyalar
bir sonraki dağıtımda kaybolur.** Referans veri (81 il, ilçeler, tanımlar, teşkilat
birimleri) her açılışta yeniden tohumlandığı için sistem "çalışıyor" görünür — kayıp
yalnızca girilen veriyi etkiler, bu yüzden fark edilmesi zordur.

Şu an test amaçlı kullanım için sorun değil; **gerçek veri girilmeden önce mutlaka
çözülmeli.**

### Çözüm seçenekleri

**A) Render kalıcı disk (en az değişiklik)**
Render'da servise bir *persistent disk* ekleyip (ör. `/var/data` bağlama noktası),
ortam değişkenlerini buna yönlendirin:
```
KK_DB_PATH=/var/data/app.db
KK_UPLOAD_DIR=/var/data/uploads
```
Kod değişikliği gerekmez — iki yol da zaten ortam değişkeninden okunuyor
(`backend/src/config.js`). Render'da kalıcı disk ücretli plan gerektirir ve servis
tek kopya (single instance) çalışmak zorundadır.

**B) Postgres'e taşıma (ölçeklenebilir, daha fazla iş)**
`backend/.env` içinde bir Neon Postgres adresi tanımlı ama **kod bunu kullanmıyor**;
veri katmanı `better-sqlite3` üzerine kurulu. Taşıma için sorgu katmanının Postgres'e
uyarlanması gerekir (şema büyük ölçüde uyumlu; `AUTOINCREMENT`, `datetime('now')` ve
göç çalıştırıcısı gibi SQLite'a özgü noktalar değişir). Dosya ekleri için ayrıca bir
nesne depolama (S3/R2 vb.) gerekir — Postgres dosya sorununu çözmez.

**Öneri:** Kısa vadede A, gerçek kullanıma geçerken B.

## Ortam değişkenleri (Render panelinden ayarlanır)

`.env` dosyası artık depoya girmiyor (`.gitignore`). Render'da bu değerler
servis ayarlarındaki *Environment* bölümünden tanımlanır:

| Değişken | Zorunlu | Açıklama |
|---|---|---|
| `KK_JWT_SECRET` | **Evet** | Oturum anahtarı. Uzun ve rastgele olmalı. Ayarlanmazsa üretimde sunucu açılmaz. |
| `KK_DB_PATH` | Önerilir | Kalıcı diske işaret etmeli (yukarıdaki A seçeneği). |
| `KK_UPLOAD_DIR` | Önerilir | Yüklenen dosyaların kalıcı yolu. |
| `KK_SEED_ADMIN_EMAIL` | Üretimde | İlk yönetici hesabının e-postası. |
| `KK_SEED_ADMIN_PASSWORD` | Üretimde | İlk yönetici şifresi. İlk girişte değiştirilmesi zorunlu. |
| `PORT` | Hayır | Render kendi atar. |
| `KK_SEED_DEMO` | **Hayır** | Üretimde **asla** ayarlamayın — sahte kayıtlar yükler. |

## Güvenlik notları

- Depo herkese açık. `README.md`'de yayımlanmış tohum şifreler canlı sistemde
  çalışıyordu; bu kapatıldı, ancak **canlıdaki mevcut hesapların şifreleri
  değiştirilmelidir.**
- ~~`backend/.env` depoya girmiş ve push edilmişti; içindeki Neon parolası git
  geçmişinde duruyordu.~~ **Çözüldü (2026-08-03):** Neon projesi silindi, bağlantı
  adresi artık hiçbir yere gitmiyor. Dosya yine de `.gitignore`'da tutuluyor ki
  bir sonraki gerçek kimlik bilgisi depoya girmesin.
- Uygulama `https://` üzerinden çalışıyor (Render sağlıyor), ancak API'de HTTPS
  zorlaması yok; ters vekil arkasında olduğu için pratikte sorun değil.

## Kalan riskler (denetimden devam eden)

`evidence/REALITY-CHECK.md` §5'teki maddelerden hâlâ açık olanlar:
- Nesne düzeyi yetkilendirme yok — bir saha kullanıcısı başkasının kaydını düzenleyebiliyor
- TC kimlik numaraları veritabanında şifresiz (listelerde maskeleme eklendi)
- Yedekleme ve geri yükleme prosedürü yok (kalıcı disk çözülmeden anlamsız)
- Android/iOS derlemesi hiç doğrulanmadı
