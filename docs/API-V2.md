# API Contract — Teşkilat Yönetim Sistemi **v2**

**Sürüm:** 2.0 · **Tarih:** 2026-08-01 · **Durum:** Faz A + Faz B (veri temeli + API) — bağlayıcı sözleşme

Base URL: `http://localhost:4141/api/v1` · JSON · JWT bearer auth (`POST /auth/login` hariç).
Hata gövdesi: `{ "error": { "code": string, "message": string } }`.
Tüm liste uçları `?page=1&limit=50` alır ve `{ "data": [...], "total": n }` döndürür
(varsayılan `limit=50`, azami `1000`).

> **Bu doküman v1'in (`docs/API.md`) yerine geçmez, üstüne biner.**
> `docs/API.md` içindeki **her uç nokta aynen çalışmaya devam eder**. Bu dokümanda yalnızca
> v1'e göre *değişen* davranışlar ve *yeni* uçlar tanımlanır. Çelişki halinde bu doküman geçerlidir.

---

## 0. v1 istemcisi için geriye dönük uyum garantileri

| Konu | Garanti |
|---|---|
| `persons.is_active` | Alan **her yanıtta durmaya devam eder** (0/1). Artık `status`'tan türetilir: `is_active = (status === 'aktif') ? 1 : 0`. |
| `PATCH /persons/:id/active` | Aynen çalışır. `true → status='aktif'`, `false → status='pasif'`. |
| `POST/PUT /persons` `is_active` | Aynen kabul edilir. `status` gönderilirse `status` kazanır. |
| `GET /persons?is_active=1` | `status='aktif'` demektir. `is_active=0` → `status IN ('pasif','teskilat_yok')`. |
| `GET /provinces` | Aynı alanlar + **yeni** `region_id`. Alan ekleme kırıcı değildir. |
| `POST /meetings` | Aynı gövde çalışır. `decision` artık **zorunlu değil** (sözleşme gevşetildi, bkz. §7). |
| `/bodies`, `/commissions`, `/task-areas`, `/memberships`, `/field-activities`, `/assignments`, `/audit-logs`, `/export/*.xlsx` | Değişmedi. |
| `GET /health` | Aynı gövde + `seeded` altında yeni v2 sayaçları. |

**Kırıcı olan tek şey veritabanı sütunudur, API değil:** `persons.is_active` sütunu
`persons.status`'a dönüştürülmüştür. Doğrudan SQL çalıştıran hiçbir istemci yok.

---

## 1. Ortak kavramlar

### 1.1 Üç durumlu statü (`status`)
`'aktif' | 'pasif' | 'teskilat_yok'` — `persons`, `org_units`, `org_assignments` için.
`teskilat_yok` özellikle il/ilçe başkanlıkları ve temsilcilikler içindir: **birim tanımlı ama
kimse atanmamış**. Teşkilatlanma boşluğu raporunun temeli budur.

### 1.2 Tanım (lookup) referansları
Formlardaki her açılır liste `lookup_items` içinden gelir. İstemci **kod yazmaz**, kategori
kodu ile listeyi çeker: `GET /lookups/gorev_turu`. Alt liste: `GET /lookups/alt_gorev?parent_id=<gorev_turu item id>`.

### 1.3 Coğrafya
`region_id` → `regions` (7 coğrafi bölge) · `province_id` → `provinces` (81) · `district_id` → `districts` (973).
Faaliyet kayıtlarında `region_id` gönderilmezse **sunucu `province_id`'den otomatik türetir**.

### 1.4 Dosya alanları
Fotoğraf / doküman / tutanak / sunum / katılım listesi **gövdede taşınmaz**. Önce kayıt
oluşturulur, sonra `POST /attachments` ile `entity` + `entity_id` verilerek yüklenir (§9).

### 1.5 Denetim izi
Tüm v2 yazma işlemleri `audit_logs`'a yazar; `GET /audit-logs` yanıtı `changed_by_name` içerir.
Yeni `entity` değerleri: `lookup_items`, `lookup_categories`, `org_units`, `org_assignments`,
`tasks`, `trainings`, `events`, `material_requests`, `shipments`, `stock_movements`,
`attachments`, `calendar_events`, `content_blocks`, `users`.

### 1.6 Roller
`genel_merkez` (tam yetki) · `saha` (faaliyet girişi + okuma).
Yönetim Paneli uçları (`/users`, `/lookup-*`, `/calendar-events` yazma, `/content-blocks` yazma,
`/org-units` yazma) **yalnız `genel_merkez`**.

---

## 2. Tanımlar (lookups) — Yönetim Paneli

### `GET /lookup-categories`
→ `{data:[{id, code, name, is_system, item_count}], total}`

Tohumlanan kategoriler (14): `bolge`, `gorev_turu`, `alt_gorev`, `egitim_konusu`,
`egitim_kategorisi`, `egitim_yontemi`, `etkinlik_turu`, `etkinlik_adi`, `toplanti_turu`,
`toplanti_yontemi`, `lojistik_urun`, `gonderim_sekli`, `gorev_unvani`, `durum`.

### `POST /lookup-categories` *(genel_merkez)*
`{code, name}` → 201 `{id, code, name, is_system:0, item_count:0}`

### `GET /lookups/:categoryCode`
Kısayol. `?parent_id=&is_active=&q=`
→ `{data:[{id, category_id, category_code, parent_id, code, name, sort_order, is_active}], total}`
404 `NOT_FOUND` — kategori kodu yoksa.

### `GET /lookup-items?category_code=&category_id=&parent_id=&is_active=&q=`
Aynı gövde, genel filtreli sürüm. `?parent_id=null` → yalnız kök kalemler.

### `GET /lookup-items/:id`
Tek kalem.

### `POST /lookup-items` *(genel_merkez)*
`{category_code | category_id, name, parent_id?, code?, sort_order?}` → 201
`parent_id`, ancak kategori hiyerarşik ise (`alt_gorev`) anlamlıdır; verilirse ebeveynin
var olması gerekir. Aynı kategori+ebeveyn altında aynı `name` → 409 `CONFLICT`.

### `PUT /lookup-items/:id` *(genel_merkez)*
`{name?, code?, parent_id?, sort_order?, is_active?}` → 200

### `PATCH /lookup-items/:id/active` *(genel_merkez)*
`{is_active}` → 200. **Silme yerine pasifleştirme önerilir** (geçmiş kayıtlar bozulmasın).

### `DELETE /lookup-items/:id` *(genel_merkez)*
→ 204. Kalem herhangi bir faaliyet kaydında kullanılıyorsa **409 `IN_USE`** döner
(o zaman `PATCH .../active {is_active:false}` kullanın).

---

## 3. Bölgeler (K2)

### `GET /regions`
→ `{data:[{id, code, name, sort_order, province_count}], total}` — 7 satır.
`code`: `marmara | ege | akdeniz | ic_anadolu | karadeniz | dogu_anadolu | guneydogu_anadolu`

### `GET /regions/:id/provinces`
→ `{data:[{id, code, name, region_id}], total}`

### `GET /provinces?region_id=`
v1 ucu; artık `region_id` alanını da döndürür ve `region_id` ile filtrelenebilir.

---

## 4. Teşkilat birimleri (K4)

### Model — `org_unit`
```jsonc
{
  "id": 1,
  "type": "koordinasyon_kurulu|bolge_temsilciligi|komisyon|il_baskanligi|ilce_baskanligi|temsilcilik",
  "name": "Ankara İl Kadın Başkanlığı",
  "code": "IL-06",
  "region_id": 4, "province_id": 6, "district_id": null,
  "parent_id": null,
  "body_id": null,              // komisyon/kurul ise v1 bodies satırına köprü
  "status": "teskilat_yok",
  "notes": null,
  "assignment_count": 0,        // yalnız listede/detayda: aktif görevlendirme sayısı
  "region_name": "İç Anadolu", "province_name": "Ankara", "district_name": null,
  "created_at": "...", "updated_at": "..."
}
```

### `GET /org-units?type=&status=&region_id=&province_id=&district_id=&parent_id=&q=`
→ `{data:[org_unit], total}`. `status` çoklu verilebilir: `?status=pasif&status=teskilat_yok`.

### `GET /org-units/:id` → `org_unit`
### `POST /org-units` *(genel_merkez)* → 201
`{type, name, region_id?, province_id?, district_id?, parent_id?, status?, code?, notes?}`
`region_id` verilmezse `province_id`'den türetilir. Aynı `(type, province_id, district_id)`
ikinci kez → 409 `CONFLICT`.
### `PUT /org-units/:id` *(genel_merkez)* → 200
### `PATCH /org-units/:id/status` *(genel_merkez)* `{status}` → 200

### `GET /org-units/summary?type=&region_id=`
**Teşkilatlanma boşluğu raporu** (v2'nin asıl yönetsel metriği).
Temiz kurulumda gerçek çıktı (`by_status`): `{"aktif": 7, "pasif": 0, "teskilat_yok": 1061}`

```jsonc
{
  "total": 1068,
  "by_status": { "aktif": 7, "pasif": 0, "teskilat_yok": 1061 },
  "by_type": [ { "type": "il_baskanligi", "aktif": 0, "pasif": 0, "teskilat_yok": 81, "total": 81 }, ... ],
  "by_region": [ { "region_id": 1, "region_name": "Marmara", "aktif": 0, "pasif": 0, "teskilat_yok": 205, "total": 205 }, ... ]
}
```

---

## 5. Görevlendirmeler (org_assignments)

Kişi ↔ teşkilat birimi bağı. (v1'in `memberships` tablosu kurul/komisyon için **çalışmaya
devam eder**; `org_assignments` onun genelleştirilmiş halidir ve il/ilçe birimlerini de kapsar.)

```jsonc
{
  "id": 1, "org_unit_id": 88, "person_id": 3,
  "role_title": "İl Başkanı", "role_id": 130,       // role_id → lookup_items(gorev_unvani)
  "start_date": "2026-01-15", "end_date": null,
  "status": "aktif", "notes": null,
  "person_name": "Zeynep Kaya", "org_unit_name": "İstanbul İl Kadın Başkanlığı",
  "created_at": "...", "updated_at": "..."
}
```

- `GET /org-assignments?org_unit_id=&person_id=&status=&role_id=&active_on=YYYY-MM-DD`
  (`active_on`: o tarihte yürürlükte olanlar)
- `GET /org-units/:id/assignments` — kısayol
- `POST /org-assignments` *(genel_merkez)* `{org_unit_id, person_id, role_title?, role_id?, start_date, end_date?, status?, notes?}` → 201
  **Yan etki:** birim `teskilat_yok` durumundayken ilk aktif görevlendirme eklenince birim
  otomatik `aktif` olur.
- `PUT /org-assignments/:id` *(genel_merkez)* · `PATCH /org-assignments/:id/status` `{status}`
- `DELETE /org-assignments/:id` *(genel_merkez)* → 204

---

## 6. Saha Faaliyetleri

### 6.1 Görevler — `/tasks` (SPEC-V2 §3.2A)
```jsonc
{
  "id": 1,
  "task_date": "2026-07-05",
  "region_id": 4, "province_id": 6, "district_id": 25,
  "branch": "Çankaya Şubesi",            // Şube (serbest metin)
  "org_unit_id": 88,                     // Kadın Teşkilatı
  "task_type_id": 20,                    // lookup_items(gorev_turu) — 12 ana başlık
  "sub_task_id": 45,                     // lookup_items(alt_gorev), task_type_id'nin çocuğu
  "volunteer_count": 12, "beneficiary_count": 240,
  "duration_hours": 4.5,                 // Süre (saat, ondalıklı)
  "notes": "…",
  "attachment_count": 2,
  "task_type_name": "Kan Hizmetleri", "sub_task_name": "Kan Bağışı Organizasyonu",
  "province_name": "Ankara", "district_name": "Çankaya", "region_name": "İç Anadolu",
  "created_by": 2, "created_by_name": "Saha Kullanıcısı",
  "created_at": "...", "updated_at": "..."
}
```
- `GET /tasks?task_type_id=&sub_task_id=&region_id=&province_id=&district_id=&org_unit_id=&from=&to=&q=`
- `POST /tasks` — zorunlu: `task_date`, `task_type_id`. `sub_task_id` verilirse ebeveyni
  `task_type_id` olmalı, aksi halde 400 `VALIDATION_ERROR`.
- `GET /tasks/:id` · `PUT /tasks/:id` · `DELETE /tasks/:id` *(genel_merkez)*

### 6.2 Eğitimler — `/trainings` (§3.2B)
```jsonc
{
  "id": 1, "training_date": "2026-06-10",
  "region_id": 1, "province_id": 34, "district_id": null,
  "org_unit_id": 96,                     // Düzenleyen Teşkilat
  "trainer": "Dr. Ayşe Yılmaz",          // Eğitmen
  "topic_id": 60,                        // lookup_items(egitim_konusu) — 18 hazır konu
  "category_id": 78,                     // lookup_items(egitim_kategorisi) — Gönüllü / Halka Açık
  "method_id": 80,                       // lookup_items(egitim_yontemi) — Yüz Yüze / Çevrim İçi
  "participant_count": 45, "volunteer_count": 6, "duration_hours": 3,
  "notes": "…", "attachment_count": 1,
  "topic_name": "İlk Yardım", "category_name": "Gönüllü", "method_name": "Yüz Yüze",
  "created_by": 2, "created_by_name": "…", "created_at": "…", "updated_at": "…"
}
```
- `GET /trainings?topic_id=&category_id=&method_id=&region_id=&province_id=&org_unit_id=&from=&to=`
- `POST` (zorunlu: `training_date`, `topic_id`) · `GET/PUT/DELETE /trainings/:id`

### 6.3 Etkinlikler — `/events` (§3.2C)
Etkinlik adı **yazılmaz, `calendar_events`'ten seçilir**.
```jsonc
{
  "id": 1, "event_date": "2026-10-29",
  "calendar_event_id": 7,                // ZORUNLU — takvimden seçilen etkinlik
  "event_type_id": 92,                   // lookup_items(etkinlik_turu), opsiyonel
  "region_id": 1, "province_id": 34, "district_id": null,
  "org_unit_id": 96,                     // Düzenleyen Teşkilat
  "participant_count": 120, "volunteer_count": 15, "beneficiary_count": 300,
  "notes": "…", "attachment_count": 0,
  "calendar_event_name": "Cumhuriyet Bayramı", "event_type_name": "Millî Bayram",
  "created_by": 2, "created_by_name": "…", "created_at": "…", "updated_at": "…"
}
```
- `GET /events?calendar_event_id=&event_type_id=&region_id=&province_id=&org_unit_id=&from=&to=`
- `POST` (zorunlu: `event_date`, `calendar_event_id`) · `GET/PUT/DELETE /events/:id`

### 6.4 Toplantılar v2 — `/meetings` (§3.2D)
**v1 ucu genişletildi, yeni uç açılmadı.** v1 alanları (`body_id`, `meeting_date`,
`decision`, `outcome`) aynen durur.
```jsonc
{
  "id": 1,
  "body_id": 1,                          // ARTIK OPSİYONEL (kamp/çalıştay için null)
  "meeting_type_id": 100,                // lookup_items(toplanti_turu) — 7 tür
  "method_id": 108,                      // lookup_items(toplanti_yontemi)
  "location": "Genel Merkez Toplantı Salonu",  // yalnız Yüz Yüze ise
  "platform": null,                      // yalnız Çevrim İçi ise
  "org_unit_id": 1,                      // Düzenleyen Teşkilat
  "region_id": null, "province_id": null,
  "meeting_date": "2026-07-01",
  "participants": "12 kurul üyesi",      // Katılımcılar
  "agenda": "2026 sonbahar kampanya takvimi",  // Gündem
  "decision": "Takvim onaylandı",        // Alınan Kararlar
  "outcome": "Oy birliği",
  "attachment_count": 3,                 // tutanak / sunum / fotoğraf
  "meeting_type_name": "Koordinasyon Kurulu Toplantısı", "method_name": "Yüz Yüze",
  "created_by": 1, "created_by_name": "…", "created_at": "…"
}
```
**Dinamik alan kuralı (sunucu tarafında zorlanır):** `method_id` "Yüz Yüze" ise `platform`
gönderilemez (400), "Çevrim İçi" ise `location` gönderilemez (400).

- `GET /meetings?body_id=&meeting_type_id=&method_id=&org_unit_id=&region_id=&province_id=&from=&to=`
- `POST /meetings` — zorunlu yalnız `meeting_date`. *(v1'de `body_id` ve `decision` zorunluydu;
  sözleşme **gevşetildi**, v1 istemcisi etkilenmez.)*
- `PUT /meetings/:id` · `DELETE /meetings/:id` *(genel_merkez)*

---

## 7. Lojistik (§3.3)

Akış: **talep → gönderi → stok hareketi**.

### 7.1 `material_requests`
```jsonc
{
  "id": 1, "request_date": "2026-07-01",
  "org_unit_id": 88, "region_id": 4, "province_id": 6, "district_id": null,
  "product_id": 112,                     // lookup_items(lojistik_urun)
  "quantity": 50,
  "status": "talep|onaylandi|gonderildi|teslim_edildi|iptal",
  "requested_by_person_id": 3, "notes": "…",
  "product_name": "Yelek", "org_unit_name": "…", "shipped_quantity": 0,
  "created_by": 1, "created_by_name": "…", "created_at": "…", "updated_at": "…"
}
```
- `GET /material-requests?status=&product_id=&org_unit_id=&region_id=&province_id=&from=&to=`
- `POST` (zorunlu: `request_date`, `product_id`, `quantity>0`) · `GET/PUT /material-requests/:id`
- `PATCH /material-requests/:id/status` `{status}` *(genel_merkez)*
- `DELETE /material-requests/:id` *(genel_merkez)* → 204 (gönderisi varsa 409 `IN_USE`)

### 7.2 `shipments`
```jsonc
{
  "id": 1, "request_id": 1,
  "shipment_date": "2026-07-03",
  "shipping_method_id": 128,             // lookup_items(gonderim_sekli): Kargo/Elden Teslim/Kurye
  "tracking_no": "1234567890",
  "quantity": 50,
  "received_by": "Ayşe Yılmaz", "received_date": "2026-07-05",
  "notes": "…",
  "product_id": 112, "product_name": "Yelek", "shipping_method_name": "Kargo",
  "request_date": "2026-07-01",          // Talep Tarihi (talepten okunur)
  "created_by": 1, "created_by_name": "…", "created_at": "…", "updated_at": "…"
}
```
- `GET /shipments?request_id=&shipping_method_id=&product_id=&from=&to=`
- `POST /shipments` — zorunlu: `request_id`, `shipment_date`, `quantity>0`.
  **Yan etkiler (tek transaction):** ilgili ürün için `stock_movements` `cikis` satırı yazılır,
  `stock_items.quantity` düşürülür, talebin durumu `gonderildi` olur.
  `received_date` verilirse talep `teslim_edildi` olur.
- `GET/PUT /shipments/:id` · `DELETE /shipments/:id` *(genel_merkez, stok hareketini geri alır)*

### 7.3 Stok
- `GET /stock-items?product_id=&low_only=1` → `{data:[{product_id, product_name, quantity, min_quantity, is_low}], total}`
- `PUT /stock-items/:productId` *(genel_merkez)* `{min_quantity}` → 200
- `POST /stock-movements` *(genel_merkez)* `{product_id, direction:"giris"|"cikis", quantity, reason?}` → 201
  (stok girişi/düzeltmesi; `stock_items` otomatik güncellenir. `cikis` stoğu eksiye düşürürse 400 `INSUFFICIENT_STOCK`.)
- `GET /stock-movements?product_id=&direction=&from=&to=`

---

## 8. Etkinlik takvimi (K6)

```jsonc
{
  "id": 7, "name": "Cumhuriyet Bayramı",
  "category": "milli_bayram|dini_bayram|dini_gun|resmi_gun|onemli_gun|onemli_hafta",
  "month": 10, "day": 29, "end_month": null, "end_day": null,
  "is_fixed": 1, "note": null, "is_active": 1,
  "dates": [ { "id": 1, "year": 2026, "start_date": "2026-03-20", "end_date": "2026-03-22" } ]
}
```
`is_fixed=0` (dinî bayramlar, hicri takvim) → `month/day` **null**, gerçek tarih
`calendar_event_dates` üzerinden yıl bazlı yönetilir.

- `GET /calendar-events?category=&month=&is_fixed=&year=&q=`
  `year` verilirse `is_fixed=0` kayıtların o yıla ait tarihi `resolved_date` alanıyla döner.
- `GET /calendar-events/:id` (dates dahil) · `POST` / `PUT` / `DELETE` *(genel_merkez)*
- `GET /calendar-events/:id/dates` · `POST /calendar-events/:id/dates` `{year, start_date, end_date?}` *(genel_merkez)*
- `DELETE /calendar-event-dates/:id` *(genel_merkez)*

---

## 9. Dosya ekleri (K5)

Yerel disk: `backend/uploads/`. **İstemciden gelen dosya adına asla güvenilmez** — sunucu
rastgele bir ad üretir (`<uuid>.<ext>`), orijinal ad yalnız görüntüleme için saklanır.

- **Boyut sınırı:** 10 MB · **İzinli türler:** `image/jpeg`, `image/png`, `image/webp`,
  `image/gif`, `application/pdf`, `.docx`, `.xlsx`. Diğerleri → 400 `UNSUPPORTED_FILE_TYPE`.

```jsonc
{
  "id": 1, "entity": "tasks", "entity_id": 1,
  "kind": "fotograf|dokuman|tutanak|sunum|katilim_listesi",
  "file_name": "kan-bagisi.jpg",          // orijinal (temizlenmiş) — yalnız gösterim
  "mime": "image/jpeg", "size": 184320,
  "uploaded_by": 2, "uploaded_by_name": "Saha Kullanıcısı",
  "download_url": "/api/v1/attachments/1/download",
  "created_at": "…"
}
```
Geçerli `entity` değerleri: `tasks`, `trainings`, `events`, `meetings`, `persons`,
`org_units`, `material_requests`, `shipments`, `field_activities`.

- `POST /attachments` — **multipart/form-data**: `file` (dosya), `entity`, `entity_id`, `kind` → 201
- `GET /attachments?entity=&entity_id=&kind=` → `{data:[…], total}`
- `GET /attachments/:id` → meta
- `GET /attachments/:id/download` → dosya (`Content-Disposition: attachment`)
- `DELETE /attachments/:id` — yükleyen kullanıcı veya `genel_merkez` → 204 (diskten de siler)

---

## 10. İçerik blokları (bilgilendirme metinleri)

Her modülün giriş ekranındaki metin. Anahtarla erişilir.
- `GET /content-blocks` → `{data:[{id, key, title, body, updated_at, updated_by_name}], total}`
- `GET /content-blocks/:key` → tek blok (yoksa 404)
- `PUT /content-blocks/:key` *(genel_merkez)* `{title, body}` → 200 (yoksa oluşturur)

Tohumlanan anahtarlar (13): `teskilatlanma.koordinasyon_kurulu`, `teskilatlanma.bolge_temsilcileri`,
`teskilatlanma.komisyonlar`, `teskilatlanma.il_baskanliklari`, `teskilatlanma.ilce_baskanliklari`,
`teskilatlanma.temsilcilikler`, `saha.gorevler`, `saha.egitimler`, `saha.etkinlikler`,
`saha.toplantilar`, `lojistik.genel`, `raporlama.genel`, `yonetim.genel`.

---

## 11. Kullanıcı yönetimi (Yönetim Paneli — denetim raporu Y-2)

v1'de ülke genelinde **tek paylaşımlı `saha` hesabı** vardı; `created_by` anlamsızdı.
Artık genel merkez kullanıcı açabilir ve kapsam verebilir.

```jsonc
{
  "id": 3, "name": "Ankara Saha Sorumlusu", "email": "ankara@kizilay.org.tr",
  "role": "genel_merkez|saha",
  "region_id": 4, "province_id": 6,      // yetki kapsamı (bilgi amaçlı; zorlanmaz — bkz. not)
  "is_active": 1, "created_at": "…", "updated_at": "…"
}
```
`password_hash` **hiçbir yanıtta dönmez.**

- `GET /users?role=&is_active=&q=` *(genel_merkez)*
- `POST /users` *(genel_merkez)* `{name, email, password, role, region_id?, province_id?}` → 201
  Şifre en az 8 karakter olmalı (400 `WEAK_PASSWORD`). E-posta benzersiz (409).
- `GET /users/:id` · `PUT /users/:id` `{name?, email?, role?, region_id?, province_id?}`
- `PATCH /users/:id/active` `{is_active}` — **pasif kullanıcı giriş yapamaz** (401 `ACCOUNT_DISABLED`).
  Son aktif `genel_merkez` hesabı pasifleştirilemez → 409 `LAST_ADMIN`.
- `PUT /users/:id/password` *(genel_merkez)* `{password}` → 200 `{ok:true}`
- `POST /auth/change-password` *(her kullanıcı, kendi hesabı)* `{current_password, new_password}` → 200

> **Not (kapsam zorlaması):** `region_id`/`province_id` bu sürümde **kaydedilir ve raporlanır,
> ancak yazma yetkisini henüz kısıtlamaz**. Denetim raporundaki Y-2'nin *"tek paylaşımlı saha
> hesabı"* kısmı bu uçlarla kapanır; *"nesne düzeyinde yetkilendirme"* kısmı **hâlâ açıktır**
> ve v2.1'e bırakılmıştır. Bir `saha` kullanıcısı hâlâ başkasının faaliyet kaydını
> düzenleyebilir — bu bilinçli bir kapsam kararıdır, gözden kaçmış bir hata değildir.

---

## 12. Dashboard / özet

### `GET /dashboard/summary?region_id=&province_id=&from=&to=`
```jsonc
{
  "filters": { "region_id": null, "province_id": null, "from": null, "to": null },
  "organization": {
    "persons": { "aktif": 8, "pasif": 1, "teskilat_yok": 0, "total": 9 },
    "org_units": { "aktif": 7, "pasif": 0, "teskilat_yok": 1061, "total": 1068 },
    "by_type": [ { "type": "il_baskanligi", "aktif": 0, "teskilat_yok": 81, "total": 81 }, … ],
    "by_region": [ { "region_id": 1, "region_name": "Marmara", "org_units_total": 205,
                     "org_units_aktif": 0, "persons_aktif": 2 }, … ]
  },
  "activity": {
    "tasks":      { "count": 4, "volunteers": 40, "beneficiaries": 435, "hours": 14.5 },
    "trainings":  { "count": 2, "participants": 70, "volunteers": 9, "hours": 6 },
    "events":     { "count": 1, "participants": 120, "volunteers": 15, "beneficiaries": 300 },
    "meetings":   { "count": 3 },
    "field_activities": { "count": 4, "volunteers": 40, "beneficiaries": 435 }  // v1 tablosu
  },
  "logistics": {
    "requests": { "talep": 1, "onaylandi": 0, "gonderildi": 1, "teslim_edildi": 0, "iptal": 0, "total": 2 },
    "shipments": { "count": 1, "quantity": 50 },
    "stock": { "products": 15, "total_quantity": 500, "low_stock": 0 }
  },
  "top_task_types": [ { "task_type_id": 20, "name": "Kan Hizmetleri", "count": 2 }, … ]
}
```

### `GET /dashboard/by-region?from=&to=`
Bölge kırılımlı ısı haritası verisi:
`{data:[{region_id, region_name, tasks, trainings, events, meetings, org_units_aktif, org_units_teskilat_yok, province_count}], total:7}`

---

## 13. Kişiler — v2 değişiklikleri

`GET/POST/PUT /persons` yanıtına eklenen alanlar:
`status` · `region_id` · `region_name` · `province_name` · `district_name` ·
`start_date` · `end_date` · `notes` · `attachment_count`.
`is_active` **kaldırılmadı** (§0). v1'in tüm alanları aynı adla durmaya devam eder.

`start_date` / `end_date` = SPEC-V2 §3.1'deki **Göreve Başlama / Görev Bitiş Tarihi**;
kişi formu bunları düz alan olarak yazar. Yapısal (birim bazlı) görev geçmişi için
`org_assignments` kullanılır — ikisi birbirinin yerine geçmez:
kişi kartındaki tarih "bu gönüllünün teşkilattaki genel görev süresi",
`org_assignments` ise "hangi birimde, hangi unvanla, hangi tarihler arasında" sorusunu yanıtlar.

Fotoğraf: `POST /attachments` ile `entity=persons`, `kind=fotograf`.

- `GET /persons?status=aktif&region_id=4&…` — yeni filtreler (`status`, `region_id`)
- `PATCH /persons/:id/status` *(genel_merkez)* `{status}` → 200 — `teskilat_yok` **yalnız buradan** atanır
- `PATCH /persons/:id/active` — v1 ucu, aynen çalışır (`true→aktif`, `false→pasif`)

---

## 14. Sağlık ucu

### `GET /health` (kök) ve `GET /api/v1/health` (**yeni**, denetim D-1)
Gerçek çıktı (temiz kurulum, referans veri):
```json
{
  "status": "ok",
  "db": "ok",
  "schema_version": "010_users_v2",
  "migrations_applied": 10,
  "seeded": {
    "provinces": 81,
    "districts": 973,
    "commissions": 6,
    "regions": 7,
    "provinces_mapped_to_region": 81,
    "lookup_categories": 14,
    "lookup_items": 138,
    "org_units": 1068,
    "calendar_events": 68,
    "content_blocks": 13,
    "stock_items": 15
  }
}
```

---

## 15. Hata kodları

| Kod | HTTP | Anlam |
|---|---|---|
| `VALIDATION_ERROR` | 400 | Alan doğrulaması başarısız |
| `INVALID_JSON` | 400 | Gövde JSON değil |
| `INVALID_TC_NO` | 400 | TC kimlik sağlaması geçersiz |
| `UNSUPPORTED_FILE_TYPE` | 400 | Ek türü izinli listede değil |
| `FILE_TOO_LARGE` | 400 | 10 MB üstü |
| `WEAK_PASSWORD` | 400 | Şifre 8 karakterden kısa |
| `INSUFFICIENT_STOCK` | 400 | Stok çıkışı bakiyeyi eksiye düşürür |
| `UNAUTHORIZED` | 401 | Token yok/geçersiz |
| `ACCOUNT_DISABLED` | 401 | Kullanıcı pasif |
| `FORBIDDEN` | 403 | Rol yetersiz |
| `NOT_FOUND` | 404 | Kayıt yok |
| `CONFLICT` | 409 | Benzersizlik ihlali |
| `IN_USE` | 409 | Bağımlı kayıt var, silinemez |
| `LAST_ADMIN` | 409 | Son genel_merkez hesabı pasifleştirilemez |
| `INTERNAL` | 500 | Beklenmeyen hata |

---

## 16. Göç (migration) altyapısı

`backend/src/migrations/*.js` — sıralı, idempotent, **sunucu açılışında otomatik** çalışır.
`schema_migrations(id, applied_at)` tablosu uygulananları tutar. Her göç kendi
transaction'ında çalışır; hata halinde geri alınır ve sunucu **açılmaz** (fail-fast).

| # | Göç | İçerik |
|---|---|---|
| 001 | `001_baseline` | v1 şeması (mevcut v1 veritabanlarında no-op) |
| 002 | `002_lookups` | `lookup_categories`, `lookup_items` |
| 003 | `003_regions` | `regions`, `provinces.region_id` |
| 004 | `004_person_status` | `persons.is_active` → `persons.status` (tablo yeniden inşası, **veri korunur**) |
| 005 | `005_org_units` | `org_units`, `org_assignments` |
| 006 | `006_attachments` | `attachments` |
| 007 | `007_calendar` | `calendar_events`, `calendar_event_dates` |
| 008 | `008_content_blocks` | `content_blocks` |
| 009 | `009_field_modules` | `tasks`, `trainings`, `events`, `meetings` v2 sütunları, lojistik tabloları |
| 010 | `010_users_v2` | `users.is_active/region_id/province_id/updated_at` |

v1 veritabanı yerinde yükseltilir; `persons`, `meetings`, `field_activities`, `memberships`,
`assignments`, `audit_logs` verisi **kaybolmaz** (`backend/test/migration.mjs` bunu kanıtlar).

`004` ve `009` SQLite'ın resmî tablo yeniden inşa prosedürünü uygular (yeni tablo → kopyala →
eski tabloyu düşür → yeniden adlandır). Çalıştırıcı bu süre boyunca `foreign_keys`i kapatır ve
sonunda `PRAGMA foreign_key_check` ile bütünlüğü doğrular; ihlal varsa açılış durur.

---

## 17. Tohumlanan referans veri (doğrulanmış sayılar)

| Veri | Adet | Not |
|---|---|---|
| Bölge | 7 | Marmara 11 · Ege 8 · Akdeniz 8 · İç Anadolu 13 · Karadeniz 18 · Doğu Anadolu 14 · Güneydoğu 9 = **81 il** |
| Tanım kategorisi | 14 | SPEC-V2 §2 K1'deki liste birebir |
| Tanım kalemi | 138 | `gorev_turu` 12 · `alt_gorev` 39 · `egitim_konusu` 18 · `toplanti_turu` 7 · `lojistik_urun` 15 · `gorev_unvani` 12 · `etkinlik_turu` 8 · `etkinlik_adi` 8 · `bolge` 7 · `durum` 3 · `gonderim_sekli` 3 · `egitim_kategorisi` 2 · `egitim_yontemi` 2 · `toplanti_yontemi` 2 |
| Teşkilat birimi | 1068 | 1 kurul + 6 komisyon + 7 bölge temsilciliği + 81 il + 973 ilçe |
| Takvim kaydı | 68 | 5 millî bayram · 9 resmî gün · 2 dinî bayram · 7 dinî gün · 28 önemli gün · 17 önemli hafta |
| Takvim yıl tarihi | 4 | Ramazan/Kurban Bayramı × 2026, 2027 |
| İçerik bloğu | 13 | Her modül için bir bilgilendirme metni |
| Stok kalemi | 15 | Her lojistik ürünü için 0 bakiyeli kayıt |

**Tohumlama idempotenttir ve yönetici düzenlemelerini ezmez:** var olan bir tanım kalemi
güncellenmez, var olan bir birimin durumu değiştirilmez, var olan bir içerik bloğunun metni
korunur. Yalnız eksik olan eklenir.

### Başlangıç durumları
- Koordinasyon kurulu ve komisyonlar → v1 `bodies.is_active` değerinden taşınır (**7 birim aktif**).
- Bölge temsilcilikleri, il ve ilçe başkanlıkları → **`teskilat_yok`** (1061 birim).
  SPEC-V2 K3 bu durumu açıkça İl/İlçe Başkanlıkları ve Temsilcilikler için tanımlar;
  teşkilatlanma boşluğu raporu ilk günden anlamlıdır.
- İlk aktif görevlendirme eklenince birim otomatik `aktif` olur; son aktif görevlendirme
  kalkınca `teskilat_yok`a döner.

---

## 18. v1'e göre bilinçli sapmalar

| # | Sapma | Gerekçe |
|---|---|---|
| 1 | `POST /meetings` artık `body_id` ve `decision` istemiyor | Kamp/Çalıştay bir kurula bağlı değil; kararlar toplantı sonrası girilir. **Sözleşme gevşetildi**, v1 istemcisi etkilenmez. |
| 2 | `GET /persons?is_active=0` artık `pasif` **ve** `teskilat_yok` döndürür | Üç durumlu statüde "aktif değil" iki değeri kapsar. Kesin ayrım için `?status=` kullanın. |
| 3 | `bolge` hem `regions` tablosu hem `lookup_items` kategorisi olarak var | SPEC-V2 K1 kategori listesinde `bolge` geçiyor, K2 ise ayrı bir tablo istiyor. Raporlamanın tek doğru kaynağı **`regions`**; `lookup_items(bolge)` yalnız genel form altyapısı içindir. |
| 4 | `etkinlik_adi` kategorisi takvimden ayrı | SPEC-V2 §3.2C etkinlik adının **takvimden** seçilmesini şart koşuyor (`calendar_event_id` zorunlu). `etkinlik_adi` tamamlayıcı program adıdır (ör. "Çelenk Sunma Töreni"). |
| 5 | Hareketli dinî günlerin yalnız 2 tanesine yıl tarihi tohumlandı | Ramazan ve Kurban Bayramı 2026–2027 dışındaki kandillerin tarihi uydurulmadı; yönetici `POST /calendar-events/:id/dates` ile girer. |
| 6 | `users.region_id/province_id` kaydediliyor ama yazma yetkisini kısıtlamıyor | Nesne düzeyinde yetkilendirme (denetim Y-2'nin tamamı) v2.1 kapsamındadır. |
| 7 | Süre alanı `duration_hours REAL` (saat) | SPEC "Süre" diyor, birim vermiyor; saat ondalıklı olarak (4.5) tutulur, dashboard toplar. |
| 8 | 7 bölge temsilciliği birimi de tohumlandı | SPEC-V2 §3.1 "Bölge Temsilcileri" alt modülünü ve K4 `bolge_temsilciligi` türünü istiyor; il başkanlıkları bunların altına bağlanır. |

## Rapor dışa aktarım (Excel + PDF)

`GET /export/{rapor}.{xlsx|pdf}` — `genel_merkez` yetkisi gerekir.

Raporlar: `persons` · `org-units` · `tasks` · `trainings` · `events` · `meetings` ·
`assignments` · `field-activities` (v1 uyumu için korundu).

- Rapor tanımları (sorgu + Türkçe sütunlar) `src/reports.js` içinde tek yerde durur;
  Excel ve PDF aynı tanımı kullandığından iki biçim ayrışamaz.
- Filtreler ilgili liste ucuyla aynıdır: `region_id`, `province_id`, `district_id`,
  `from`, `to`, `status`, `type`, `q` (rapora göre değişir). Sayfalama uygulanmaz.
- PDF: yatay A4, Kızılay kırmızısı başlık bandı, başlık altında uygulanan filtrelerin
  özeti ve kayıt sayısı, sayfa numaraları. **Türkçe karakterler için DejaVu Sans TTF
  gömülür** (PDFKit'in varsayılan Helvetica'sı WinAnsi olduğundan ş/ğ/İ/ı karakterlerini
  bozar). Kayıt yoksa "Seçilen filtrelere uygun kayıt bulunamadı." yazar.
- Bilinmeyen rapor adı → 404.

