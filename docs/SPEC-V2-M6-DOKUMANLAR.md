# Modül 6 — Kılavuz ve Dokümanlar (SPEC-V2 eki)

**Sürüm:** 2.1 · **Tarih:** 2026-08-02 · v2 üzerine eklenen 6. ana modül

## 1. Amaç
Genel merkezin sahadaki gönüllülere ulaştırmak istediği tüm basılı/dijital içeriğin
tek yerden dağıtıldığı kütüphane: kılavuzlar, formlar, matbu izin belgeleri, proje
dokümanları, yönetsel yazılar.

Saha tarafı için **okuma ve indirme** odaklıdır — asıl iş "doğru belgeyi hızlıca bulup
indirmek". Yükleme ve yayından kaldırma genel merkez yetkisindedir.

## 2. Tasarım Kararı — iki ayrı eksen (önemli)

Müşteri iki gruplama önerdi: *"proje dokümanları / yönetsel dokümanlar / formlar"*
**veya** *"yerelde kullanılacak olanlar"*. Bunlar **aynı listenin alternatifleri değil,
birbirine dik iki eksendir**:

- **Tür (ne olduğu):** kılavuz mu, form mu, proje dokümanı mı?
- **Kapsam (kime ait olduğu):** ülke geneli mi, yalnız bir bölgeye/ile/ilçeye mi ait?

Tek listeye sıkıştırılırsa "Ankara'da kullanılacak izin formu" hangi başlığa gireceği
belirsiz kalır ve kullanıcı belgeyi bulamaz. Bu yüzden:

**Tür → kategori (Tanımlar'dan yönetilir) · Kapsam → ayrı alan ve filtre.**

### 2.1 Kategoriler (`lookup_categories.code = 'dokuman_kategorisi'`)
Tohumla gelen, Yönetim Paneli → Tanımlar'dan **kod değişikliği olmadan** genişletilebilir:

| Kategori | İçerik |
|---|---|
| **Kılavuzlar** | Uygulama/süreç rehberleri, el kitapları, eğitim materyalleri |
| **Formlar ve Matbu Belgeler** | Doldurulacak boş formlar, izin belgesi şablonları, tutanak örnekleri |
| **Proje Dokümanları** | Belirli projelere ait içerik, sunum, afiş, bilgi notu |
| **Yönetsel Dokümanlar** | Genelge, talimat, yönerge, kurul kararları |

Alt kategori gerekirse `parent_id` ile aynı Tanımlar altyapısı kullanılır (K1) —
ör. "Proje Dokümanları → Aile Yılı".

### 2.2 Kapsam (`scope`)
`genel | bolge | il | ilce` + ilgili `region_id` / `province_id` / `district_id`.

- `genel`: herkes görür (varsayılan)
- `bolge` / `il` / `ilce`: yalnız o kırılıma bağlı kullanıcılar için öne çıkar
- Liste ekranında **"Yalnız bana ait olanlar"** anahtarı bu alanla çalışır.

Böylece "yerelde kullanılacak olanlar" bir kategori değil, her kategoride
kullanılabilen bir filtre olur.

## 3. Veri Modeli

```
documents(
  id, title, description,
  category_id      → lookup_items (dokuman_kategorisi)
  scope            TEXT CHECK (scope IN ('genel','bolge','il','ilce')) DEFAULT 'genel'
  region_id, province_id, district_id   -- scope'a göre doldurulur
  version          TEXT      -- ör. "v2.1" veya "2026 Revizyon"
  published_at     TEXT      -- yayın tarihi (geriye dönük tarih verilebilir)
  valid_until      TEXT      -- son geçerlilik (izin belgeleri için); geçince "Süresi doldu" rozeti
  is_active        INTEGER   -- yayından kaldırma (silme değil — geçmiş korunur)
  download_count   INTEGER   -- hangi belgenin gerçekten kullanıldığını görmek için
  created_by, created_at, updated_at
)
```

Dosyanın kendisi **mevcut `attachments` altyapısını** kullanır
(`entity='documents'`, `entity_id=documents.id`, `kind='dokuman'`) — K5'te kurulan
UUID adlandırma, MIME beyaz listesi ve path-traversal koruması aynen geçerlidir.
Bir dokümanın birden çok dosyası olabilir (ör. Word + PDF sürümü).

**Not:** `valid_until` özellikle matbu izin belgeleri için eklendi — süresi geçmiş bir
izin belgesinin sahada kullanılması gerçek bir risk.

## 4. API

- `GET /documents?category_id=&scope=&region_id=&province_id=&district_id=&q=&is_active=`
  → `{data, total}`; saha rolü yalnız `is_active=1` görür.
- `GET /documents/:id` (ekleri ile birlikte)
- `POST /documents` · `PUT /documents/:id` · `PATCH /documents/:id/active` — `genel_merkez`
- `DELETE /documents/:id` — `genel_merkez` (ekleri de temizler)
- `POST /documents/:id/download` → `download_count` artırır (indirme öncesi çağrılır)
- Dosya ekleme/indirme mevcut `/attachments` uçlarıyla.
- `GET /export/documents.{xlsx|pdf}` — doküman envanteri raporu.
- Tüm yazma işlemleri denetim izine düşer.

## 5. Arayüz

### 5.1 Navigasyon
Mobilde alt navigasyon 5 sekmeyle dolu. Yerleşim role göre:

| Rol | Yerleşim |
|---|---|
| `genel_merkez` | **Daha Fazla → Kılavuz ve Dokümanlar** (Yönetim Paneli ve Profil ile birlikte) |
| `saha` | **Doğrudan alt sekme** — sahanın en sık kullanacağı modül; saha 3 sekmeden 4'e çıkar (Saha · Lojistik · Dokümanlar · Profil) |

Tablet/masaüstünde (≥600) yan rayda **tam hedef** olarak görünür — "Daha Fazla"nın
diğer çocukları gibi terfi eder.

### 5.2 Ekranlar
1. **Dokümanlar ana ekranı** — kategori kartları (her kartta belge sayısı),
   üstte arama kutusu, "Yalnız bana ait olanlar" anahtarı.
2. **Kategori listesi** — belge kartları: başlık, sürüm, yayın tarihi, dosya türü ikonu
   ve boyutu, kapsam rozeti (Genel / Ankara / Çankaya), süresi dolmuşsa uyarı rozeti.
   Filtre çipleri: kapsam ve dosya türü.
3. **Belge detayı** — açıklama, sürüm geçmişi yerine `version` alanı, ekli dosyalar
   listesi, **İndir** birincil eylemi, genel merkez için Düzenle / Yayından Kaldır.
4. **Belge formu** (genel merkez) — DynamicForm ile: Kategori (Tanımlar'dan), Kapsam
   (seçime göre Bölge/İl/İlçe alanları **dinamik açılır** — K1/R2 kuralı), başlık,
   açıklama, sürüm, yayın tarihi, son geçerlilik, dosya ekleme.
5. **Arama** — başlık + açıklama üzerinde, Türkçe büyük/küçük harf duyarsız.

### 5.3 Türkçe metinler
- Modül adı: **Kılavuz ve Dokümanlar**
- Boş durum: "Bu kategoride henüz doküman yok."
- Saha için boş durum: "Genel merkez doküman eklediğinde burada görünecek."
- Süresi dolmuş rozeti: "Süresi doldu"
- Kapsam rozetleri: "Genel", "<Bölge adı>", "<İl adı>", "<İlçe adı>"
- İndirme: "İndir" · indirme sonrası "Dosya indirildi."
- Yayından kaldırma onayı: "Bu doküman sahada görünmeyecek. Kayıt silinmez, tekrar
  yayına alınabilir. Devam edilsin mi?"

## 6. Kapsam Dışı (v2.2)
- Sürüm geçmişi (aynı belgenin eski sürümlerini saklama)
- Okundu bilgisi / zorunlu okuma takibi
- Çevrimdışı indirme kuyruğu
- Doküman içi tam metin arama (PDF içeriğinde arama)
