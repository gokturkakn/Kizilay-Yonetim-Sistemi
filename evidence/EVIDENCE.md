# QA Kanıt Raporu — Teşkilat Yönetim Sistemi MVP

**Tarih:** 2026-08-01 · **Sürüm:** MVP 0.1 · **Yürüten:** Orkestratör (Evidence Collector ajanı
5. adımda durdurulduğu için doğrulama orkestratör tarafından tamamlandı)

**Ortam:** Backend `localhost:4141` (Node + SQLite) · Flutter web derlemesi `localhost:5757`,
tarayıcı 375×812 (mobil) · Ham API çıktıları: [curl-checks.txt](curl-checks.txt)

**Özet karar:** Çekirdek akışların tamamı çalışıyor. **1 majör hata bulundu ve düzeltildi**
(değişiklik günlüğü filtresi), 4 minör/bilgilendirici bulgu açık bırakıldı. Konsolda hata yok.

---

## 1. Akış Sonuçları

| # | Akış | Sonuç | Görülen kanıt |
|---|---|---|---|
| 1 | Yanlış şifre ile giriş | ✅ | HTTP 401, `"E-posta veya şifre hatalı"` — çökme yok |
| 2 | Sağlık kontrolü / tohum veri | ✅ | `{provinces:81, districts:973, commissions:6}` |
| 3 | Yönetim Paneli ana ekran | ✅ | 3 kart (Koordinasyon Kurulu, Komisyonlar, Kadın Teşkilatları), Kızılay kırmızısı başlık, 4 sekmeli navigasyon |
| 4 | Kurul + komisyonlar | ✅ | 7 birim: 1 koordinasyon kurulu + SPEC'teki 6 komisyonun tamamı, adları birebir |
| 5 | Kadın Teşkilatları / il listesi | ✅ | Plaka rozetli liste: 01 Adana, 02 Adıyaman … 81 Düzce; 81 kayıt eksiksiz |
| 6 | Türkçe arama (İ/I duyarlılığı) | ✅ | Birim testi: "istan"→İstanbul eşleşir, "ıspa"→Isparta eşleşir ama İstanbul eşleşmez |
| 7 | Geçersiz TC reddi | ✅ | `12345678901` → HTTP 400 `"TC kimlik no geçersiz (11 hane ve sağlama kuralına uygun olmalı)"` |
| 8 | Kişi oluşturma (geçerli TC) | ✅ | HTTP 201, id=11, tüm SPEC alanları kayıtlı |
| 9 | Mükerrer TC | ✅ | HTTP 409 `"Bu TC kimlik no ile kayıtlı kişi zaten var"` |
| 10 | Aktif → Pasif geçişi | ✅ | HTTP 200, `is_active:0`; Aktif filtresinde 0 kayıt, Pasif filtresinde 1 kayıt |
| 11 | Saha görev formu kaydı | ✅ | Saha rolüyle oluşturuldu; listede "Kan Bağışı Organizasyonu · 28.07.2026 · 14 gönüllü · 230 yararlanıcı · İstanbul" olarak göründü |
| 12 | Yönetsel faaliyet (toplantı) | ✅ | Kurul toplantısı oluşturuldu (tarih/karar/sonuç), HTTP 201 |
| 13 | Görev atamaları listesi | ✅ | 3 atama; kişi adları çözümlü (Merve Şahin, Ayşe Yılmaz, Fatma Demir), renkli durum rozetleri (Atandı / Devam Ediyor / Tamamlandı) |
| 14 | Excel dışa aktarım (4 rapor) | ✅ | Hepsi HTTP 200, ~7 KB, ZIP imzası `PK`; Türkçe başlıklar: "Ad, Soyad, TC Kimlik No, Doğum Tarihi…" / "Görev Alanı, Tarih, Gönüllü Sayısı, Yararlanıcı Sayısı…" |
| 15 | Değişiklik günlüğü | ✅ (düzeltme sonrası) | "Durum değişikliği — Kişiler", "Ekleme — Saha Faaliyetleri", tarih 01.08.2026 19:26 |
| 16 | Rol kısıtları — saha | ✅ | POST /persons 403, POST /assignments 403, GET /audit-logs 403, export 403; GET /assignments 200 |
| 17 | Rol kısıtları — arayüz | ✅ | Saha rolünde yalnız 2 sekme (Saha Çalışmaları, Profil); Yönetim Paneli ve Raporlar hiç render edilmiyor; atama ekranında ekleme butonu yok |
| 18 | Tarayıcı konsolu | ✅ | Tüm akışlar sonrası hata yok |

---

## 2. Bulgular

### BULGU-1 — MAJÖR — Değişiklik günlüğü filtresi sessizce boş sonuç veriyordu ✅ DÜZELTİLDİ
`audit_log_screen.dart` filtre değeri olarak `field-activities` (tire) gönderiyordu; backend
audit kayıtlarını `field_activities` (alt çizgi) olarak yazıyor. Aynı uyuşmazlık eylem
etiketinde de vardı (`active-toggle` ↔ `active_toggle`).

**Etkisi:** "Saha Faaliyetleri" filtresi seçildiğinde günlük hiç kayıt yokmuş gibi boş
görünüyordu; durum değişikliği satırları ise çevrilmemiş ham `active_toggle` metniyle
listeleniyordu. Denetim izi SPEC §2.1'in açık gereksinimi olduğu için majör sayıldı.

**Kanıt:** `entity=field-activities` → 0 kayıt · `entity=field_activities` → 2 kayıt
**Düzeltme:** [audit_log_screen.dart:25-37](../app/lib/screens/reports/audit_log_screen.dart)
değerleri backend ile eşitlendi; eski tireli değer geriye dönük etiket eşlemesinde korundu.
**Doğrulama:** `flutter analyze` temiz, 16 test geçti, arayüzde etiketler Türkçe render ediliyor.

### BULGU-2 — MİNÖR — Simge butonlarında erişilebilirlik etiketi yok
Değişiklik günlüğü ve saha faaliyetleri ekranlarındaki filtre simgesi butonlarının
`aria-label`/tooltip'i yok (semantik ağaçta boş etiketli buton olarak görünüyor).
Ekran okuyucu kullanan gönüllüler için engel; `Tooltip`/`Semantics` sarmalayıcı ile çözülür.

### BULGU-3 — MİNÖR — Atama durum çipleri yatayda taşıyor
375 px genişlikte "Tamamlandı" çipi ekran dışında kalıyor (yatay kaydırma gerekiyor).
İşlevsel kayıp yok ama küçük ekranda dördüncü seçenek görünmüyor; sarmalayan (`Wrap`)
düzen önerilir.

### BULGU-4 — BİLGİ — QA test verisi veritabanında kaldı
Durdurulan QA ajanının ve bu doğrulamanın oluşturduğu kayıtlar (kişi id=10, id=11;
faaliyet id=5,6; toplantı id=4,5) demo veritabanında duruyor. Üretime çıkarken
`backend/data/app.db` silinip yeniden tohumlanmalı.

### BULGU-5 — BİLGİ — Otomasyon aracı Flutter canvas'ına tıklayamıyor
Tarayıcı otomasyonunun sentetik tıklama ve metin girişi Flutter web canvas'ına ulaşmıyor;
doğrulama, erişilebilirlik semantik ağacı üzerinden DOM tıklamasıyla yapıldı. **Ürün hatası
değildir** — gerçek kullanıcı girdisi etkilenmez; ancak ileride otomatik regresyon testi
kurulacaksa Flutter'ın `integration_test` paketi kullanılmalıdır.

---

## 3. Kapsanmayanlar (bilinçli)
- Android/iOS cihaz derlemesi: bu makinede Xcode ve Android SDK kurulu değil; kod tabanı
  üç platformu hedefliyor ancak mağaza derlemesi doğrulanmadı.
- Excel'den toplu kişi içe aktarma: uç nokta backend duman testinde doğrulandı, arayüzü MVP dışı.
- Yük/performans testi ve güvenlik denetimi yapılmadı (JWT gizli anahtarı hâlâ varsayılan).
