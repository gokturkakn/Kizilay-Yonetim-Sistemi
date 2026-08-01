# Kızılay Kadın — Teşkilat Yönetim Sistemi (MVP Spec)

**Sürüm:** 0.1 · **Tarih:** 2026-08-01 · **Durum:** Onaylı MVP kapsamı

## 1. Amaç
Kızılay Kadın teşkilatının genel merkez tarafından atanan gönüllülerinin ve bunların
sahadaki çalışmalarının kayıt altına alınıp raporlanabildiği, mobil öncelikli bir uygulama.

## 2. Ana Yapı — İki Ana Alan

### 2.1 Yönetim Paneli (Kızılay Kadın)
Ana başlıklar:
1. **Koordinasyon Kurulu** — üye listesi (kayıtlı kişilerden atanır)
2. **Komisyonlar** — alt başlıklar (tohum veri, genişletilebilir):
   - Eğitim Komisyonu
   - Proje Komisyonu
   - Gönüllü Kazanım ve İşbirlikleri Komisyonu
   - Sosyal Medya ve İletişim Komisyonu
   - Sağlıklı Yaşam Komisyonu
   - Evde Bakım Rehberliği Komisyonu
3. **Kadın Teşkilatları** — 81 il ve ilçeleri önceden tanımlı (tohum veri).
   Kişiler bu teşkilatlara bağlanır. (İleride Excel'den toplu kişi aktarımı yapılacak;
   MVP'de içe aktarma altyapısı hazır uç nokta olarak bırakılır.)

**Kişi kaydı alanları:** ad, soyad, bağlı olduğu il teşkilatı, ilçe teşkilatı **veya**
temsilcilik işareti (birim türü: `il_teskilati | ilce_teskilati | temsilcilik`),
doğum tarihi, TC kimlik no (11 hane, doğrulamalı), telefon, e-posta, meslek,
**aktif/pasif** durumu (tik).

**Panel genelinde:** aktif ve pasifte kalanlar her listede filtrelenebilir/görülebilir;
tüm listeler **Excel olarak raporlanabilir**; tüm değişiklikler **değişiklik günlüğüne
(audit log)** düzenli olarak işlenir ve panelden görüntülenir.

### 2.2 Saha Çalışmaları
İki bölüm:

**a) Sahadaki etkinlik ve faaliyetler — Görev Formu**
- Görev alanı (önceden tanımlı liste, genişletilebilir — tohum veri; gerçek liste geldiğinde güncellenecek)
- Tarih
- Katılan gönüllü sayısı
- Yararlanıcı sayısı
- (Opsiyonel: il/ilçe, açıklama — genişletmeye açık şema)

**b) Yönetsel faaliyetler**
- **Koordinasyon Kurulu:** toplantı tarihi, toplantı kararı, sonuç
- **Komisyonlar:** toplantı/aktivite tarihi, karar/konu, sonuç
- Şema genişletilebilir (ek alan eklenebilir yapıda)

**c) Görev atamaları:** Genel merkez personelinin sahaya atadığı tüm görevler,
kayıtlı tüm isimler için görülebilir liste (kişi, görev başlığı, tarih, durum).

## 3. Roller (MVP)
- `genel_merkez`: tam yetki (kişi/atama/tanım yönetimi, tüm raporlar)
- `saha`: görev formu ve yönetsel faaliyet girişi, atamaları görüntüleme
- MVP'de basit e-posta+şifre girişi, JWT; tohum kullanıcı: genel merkez admin.

## 4. Raporlama
- Excel (.xlsx) dışa aktarım: kişiler (filtreli), saha faaliyetleri, yönetsel
  faaliyetler (toplantılar), görev atamaları.
- Değişiklik günlüğü ekranı (kim/ne zaman/ne değişti).

## 5. Teknik Kararlar
- **Mobil uygulama:** Flutter (Android + iOS hedefli kod tabanı; bu makinede QA
  web hedefinde mobil görünümle yapılır, mağaza derlemeleri SDK kurulunca alınır).
- **Backend:** Node.js + Express + SQLite (dosya tabanlı, dış servis yok;
  sonradan PostgreSQL'e taşınabilir şema). Excel: `exceljs`.
- **API:** REST, `docs/API.md` sözleşmesine birebir uyum. Port: 4141.
- Tüm ekran metinleri **Türkçe**.

## 6. MVP Dışı (sonraki sürümler)
- Excel'den toplu kişi içe aktarma UI'ı (uç nokta iskeleti MVP'de var)
- Bildirimler, çevrimdışı senkronizasyon, SSO/Kızılay kimlik entegrasyonu
- Büyüme/iletişim çalışmaları (runbook 3. hafta Growth Team fazı)
