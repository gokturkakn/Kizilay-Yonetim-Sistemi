# TYS v2 — Kızılay Kadın Teşkilat Yönetim Bilgi Sistemi

**Sürüm:** 2.0 · **Tarih:** 2026-08-01 · **Durum:** Kapsam genişletmesi (v1 MVP üzerine)

v1 (MVP) teslim edildi: 81 il / 973 ilçe, kurul + 6 komisyon, kişi kayıtları, basit görev
formu, toplantılar, atamalar, Excel raporu, denetim izi. **v2** bunu kurumsal bir Yönetim
Bilgi Sistemine dönüştürür.

## 0. Tasarım İlkesi
**Tanımla → Seç → Kaydet → Raporla.** Serbest metin minimumda; standart veriler
Yönetim Paneli'ndeki **Tanımlar** modülünden yönetilen listelerden seçilir.
Yeni bir görev türü, eğitim konusu veya ürün eklemek **kod değişikliği gerektirmez**.

---

## 1. Ana Menü (v1'de 2 alan vardı → v2'de 5 modül)

| # | Modül | v1 durumu |
|---|---|---|
| 1 | Teşkilatlanma | kısmen var (kurul, komisyon, il/ilçe kişileri) |
| 2 | Saha Faaliyetleri | kısmen var (tek görev formu + toplantı) |
| 3 | Lojistik | **yeni** |
| 4 | Raporlama ve Dashboard | kısmen var (yalnız Excel) |
| 5 | Yönetim Paneli | **yeni** (v1'de yalnız raporlar vardı) |

---

## 2. Mimari Kararlar (v2'nin omurgası)

### K1 — Genel "Tanımlar" (lookup) altyapısı
Tüm açılır listeler tek bir genel yapıda toplanır:

```
lookup_categories(id, code, name, is_system)      -- ör. gorev_turu, egitim_konusu
lookup_items(id, category_id, parent_id, name, code, sort_order, is_active)
```
`parent_id` hiyerarşi sağlar: **Görev Türü → Alt Görev**. Yönetim Paneli bu tabloları
CRUD ile yönetir. Kodda sabit liste kalmaz. Bu, "yeni kayıtlar kod geliştirmeden
eklenebilmelidir" gereksiniminin karşılığıdır.

Başlangıç kategorileri: `bolge`, `gorev_turu`, `alt_gorev`, `egitim_konusu`,
`egitim_kategorisi`, `egitim_yontemi`, `etkinlik_turu`, `etkinlik_adi`, `toplanti_turu`,
`toplanti_yontemi`, `lojistik_urun`, `gonderim_sekli`, `gorev_unvani`, `durum`.

### K2 — Bölge boyutu
`regions` tablosu (7 coğrafi bölge) eklenir; `provinces.region_id` ile bağlanır.
Tüm raporlar bölge kırılımı alabilir.

### K3 — Üç durumlu statü (BREAKING)
v1'deki `is_active INTEGER` → `status TEXT CHECK(status IN ('aktif','pasif','teskilat_yok'))`.
"Teşkilat Yok" özellikle İl/İlçe Başkanlıkları ve Temsilcilikler için raporlanabilir olmalı —
bu, teşkilatlanma boşluğunu gösteren asıl yönetsel metriktir.
Geriye dönük uyum: API `is_active` alanını türetilmiş olarak döndürmeye devam eder
(`status == 'aktif'`), böylece v1 istemcisi kırılmaz.

### K4 — Teşkilat birimi (org_units) modeli
v1'de kişi doğrudan il/ilçeye bağlıydı. v2'de teşkilat yapısı kendi başına bir varlıktır:

```
org_units(id, type, name, region_id, province_id, district_id, parent_id, status, ...)
  type: koordinasyon_kurulu | bolge_temsilciligi | komisyon |
        il_baskanligi | ilce_baskanligi | temsilcilik
```
Bir ilin başkanlığı "Teşkilat Yok" durumunda olabilir — kişi olmasa bile birim kaydı vardır.
Görevlendirmeler `assignments_org` ile kişiyi birime bağlar (görev, başlama/bitiş tarihi).

### K5 — Dosya ekleri
`attachments(id, entity, entity_id, kind, file_name, mime, size, path, uploaded_by, created_at)`
`kind`: `fotograf | dokuman | tutanak | sunum | katilim_listesi`.
Yerel disk (`backend/uploads/`), üretimde nesne depolamaya taşınabilir soyutlama.

### K6 — Etkinlik takvimi
`calendar_events(id, name, category, month, day, is_fixed, note)` — millî/dinî bayramlar,
resmî günler, önemli gün ve haftalar sistemle hazır gelir, yöneticiden güncellenebilir.
Dinî bayramlar hicri takvime bağlı olduğundan `is_fixed=0` ve yıl bazlı tarih tablosu
(`calendar_event_dates`) ile yönetilir.

---

## 3. Modül Detayları

### 3.1 Teşkilatlanma
Alt modüller: Koordinasyon Kurulu · Bölge Temsilcileri · Komisyonlar ·
İl Kadın Başkanlıkları · İlçe Kadın Başkanlıkları · Temsilcilikler.
Her modülün giriş ekranında **bilgilendirme metni** (İçerik Yönetimi'nden düzenlenebilir:
`content_blocks(key, title, body)`).

Ortak kişi/görev alanları: Ad Soyad · Görev · **Fotoğraf** · Telefon · E-posta ·
**Göreve Başlama Tarihi** · **Görev Bitiş Tarihi** · Açıklama · Durum.
(v1'deki TC kimlik, doğum tarihi, meslek alanları korunur.)

### 3.2 Saha Faaliyetleri
**A. Görevler** — 12 ana başlık (Aşevi, Butik, Gıda Kolisi, Ziyaretler, Kan Hizmetleri,
Çocuk, Gençlik, Aile Yılı, Gönüllü Kazanımı, Bağışçı ve Kaynak Geliştirme, Sosyal Destek,
Afet). Alt görevler Yönetim Paneli'nden tanımlanır.
Kayıt alanları: Tarih · Bölge · İl · İlçe · **Şube** · Kadın Teşkilatı · Görev Türü ·
Alt Görev · Gönüllü Sayısı · Yararlanıcı Sayısı · **Süre** · Açıklama · Fotoğraf · Doküman.

**B. Eğitimler** — Kategori (Gönüllü / Halka Açık) × Yöntem (Yüz Yüze / Çevrim İçi),
18 hazır konu. Alanlar: Tarih · Bölge · İl · Düzenleyen Teşkilat · Eğitmen · Konu ·
Yöntem · Katılımcı Sayısı · Gönüllü Sayısı · Süre · Açıklama · Katılım Listesi ·
Fotoğraf · Doküman.

**C. Etkinlikler** — Etkinlik adı **yazılmaz, listeden seçilir** (millî/dinî bayramlar,
resmî günler, önemli gün ve haftalar). Alanlar: Tarih · Bölge · İl · Düzenleyen Teşkilat ·
Katılımcı · Gönüllü · Yararlanıcı Sayısı · Açıklama · Fotoğraf · Doküman.

**D. Toplantılar** — 7 tür (Koordinasyon Kurulu, Bölge, İl, İlçe, Komisyon, Kamp, Çalıştay).
Alanlar: Tür · Tarih · Yöntem · **Yüz yüze ise Toplantı Yeri / Çevrim içi ise Platform
(dinamik alan)** · Düzenleyen Teşkilat · Katılımcılar · Gündem · Alınan Kararlar ·
Tutanak · Sunum · Fotoğraf.

### 3.3 Lojistik
`material_requests` (talep) → `shipments` (gönderi) → `stock_items` / `stock_movements`.
Gönderi alanları: Talep Tarihi · Gönderi Tarihi · Gönderim Şekli (Kargo/Elden/Kurye) ·
Kargo Takip No · Miktar · Teslim Alan · Teslim Tarihi · Açıklama.
Ürünler `lookup_items(lojistik_urun)` içinde (yelek, rozet, bayrak, flama, roll-up,
broşür, afiş, masa örtüsü, kalem, defter, bez çanta, kupa, şapka, tişört, diğer).

### 3.4 Raporlama ve Dashboard
`GET /dashboard/summary` — durum dağılımı (aktif/pasif/teşkilat yok), il ve bölge bazlı
teşkilatlanma, gönüllü/faaliyet/eğitim/etkinlik/toplantı sayıları, lojistik hareketleri.
Tüm raporlar **Bölge · İl · İlçe · Tarih Aralığı · Faaliyet Türü** filtreleriyle.
Çıktı: Excel (v1'de var) + **PDF** (yeni). Harita görünümü il bazlı yoğunluk.

### 3.5 Yönetim Paneli
Kullanıcı Yönetimi (v1'de yoktu — denetim raporundaki Y-2 riskinin çözümü) ·
Tanımlar (K1) · Yetkilendirme (rol/kapsam: bölge/il sınırlı kullanıcı) · Bildirimler ·
Sistem Ayarları · Form Yönetimi · İçerik Yönetimi.

---

## 4. Uygulama Sırası (bağımlılığa göre)
1. **Faz A — Veri temeli:** lookups, regions, org_units, status geçişi, attachments,
   calendar. Göç (migration) altyapısı + v1 verisinin taşınması.
2. **Faz B — API:** modül uçları (teşkilatlanma, görevler, eğitimler, etkinlikler,
   toplantılar, lojistik, dashboard, tanımlar, kullanıcılar).
3. **Faz C — Arayüz:** 5 modüllü navigasyon, dinamik formlar, dashboard.
4. **Faz D — Doğrulama:** API Tester + Evidence Collector.

## 5. Kapsam Dışı (v2.1'e)
Harita görünümü (önce veri), bildirim gönderimi, PDF şablon özelleştirme,
çevrimdışı senkronizasyon.
