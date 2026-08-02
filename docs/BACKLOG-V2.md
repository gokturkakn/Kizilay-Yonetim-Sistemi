# TYS v2 — Sprint Durumu

Kaynak: [SPEC-V2.md](SPEC-V2.md) · v1 tabanı: git commit `12cef9f`

## Faz 0 — Hazırlık ✅
- [x] Kapsam analizi ve mimari kararlar (K1 lookups, K2 bölge, K3 üç durumlu statü,
      K4 org_units, K5 dosya ekleri, K6 takvim) → SPEC-V2.md
- [x] **v1 git'e alındı** (`12cef9f`, 181 dosya) — breaking göç öncesi geri dönüş noktası
- [x] `.gitignore` (veritabanı, node_modules, build çıktıları, yüklenen dosyalar hariç)

## Faz A+B — Veri temeli ve API (Backend Architect) ✅ `a179712`
- [x] Göç altyapısı: 10 sıralı migration, `schema_migrations`, açılışta fail-fast
- [x] K1 lookups: 14 kategori / 138 kalem, görev türü→alt görev hiyerarşisi
- [x] K2 7 bölge, 81 il plaka koduyla eşlendi (eşlenmemiş: 0)
- [x] K3 `is_active` → `status`; `is_active` API'de türetiliyor → v1 istemcisi çalışıyor
- [x] K4 1068 org_unit; boşluk raporu `GET /org-units/summary`
- [x] K5 dosya ekleri (UUID adlandırma, MIME beyaz listesi, path traversal test edildi)
- [x] K6 takvim: 68 bayram/resmî gün/önemli gün-hafta
- [x] 79 yeni uç + kullanıcı yönetimi · `docs/API-V2.md`
- [x] **253 kontrol** (63 göç + 13 tohum + 177 duman), hepsi geçiyor
- [x] Geriye dönük uyum v1 Flutter uygulamasıyla tarayıcıda doğrulandı
- [x] Açık kapatma turu `d9caf03`: dashboard `district_id`+`activity_type` filtreleri,
      `/dashboard/timeseries` (boş aylar 0 dolgulu), `/dashboard/provinces`,
      `toplanti_platformu` tanımı, toplantı `participant_count` (migration 011)
- [x] **268 kontrol** (64 göç + 13 tohum + 191 duman), hepsi geçiyor
- [x] **PDF çıktı uçları** `b67544b` — 8 rapor × 2 biçim, rapor tanımları tek kaynakta
      (`src/reports.js`), DejaVu TTF gömülü (Türkçe karakterler), görsel doğrulandı.
      **289 kontrol** (64 göç + 13 tohum + 212 duman)

## Faz C — Arayüz
- [x] `docs/UX-V2.md` (UX Architect) `7241716` — 5 sekme + rail/iki panel kırılımları,
      DynamicForm 12 kuralı, üç durumlu statü, 25 belirsizlik çözüldü
- [x] **Flutter v2 uygulaması** `1482d4b` — 44 ekran (~10.900 satır), 5 modül,
      DynamicForm motoru, uyarlanabilir kabuk. analyze temiz · 88 test · web build ✓
      · tarayıcıda mobil (5 sekme) ve masaüstü (yan ray) görünümü doğrulandı

## Faz D — Doğrulama (sıradaki)
- [ ] API Tester: v2 uçlarının sözleşmeye tam uygunluğu
- [ ] Evidence Collector: uçtan uca akışlar, ekran görüntülü kanıt
- [ ] Reality Checker: v2 için üretim hazırlığı kararı

## Faz D — Doğrulama
- [ ] API Tester: v2 uçlarının sözleşmeye uygunluğu
- [ ] Evidence Collector: uçtan uca akışlar + kanıt
- [ ] Göç testi: gerçek v1 verisi üzerinde kayıpsız yükseltme

## Devralınan açık riskler (v1 denetiminden — REALITY-CHECK.md §5)
- [x] ~~BLOKE-1 sürüm kontrolü yok~~ → çözüldü (`12cef9f`)
- [ ] BLOKE-4 Excel indirme mobilde çalışmıyor
- [ ] BLOKE-5 varsayılan JWT anahtarı sessizce kullanılıyor, şifre değiştirme yok
- [ ] BLOKE-6 Android/iOS derlemesi doğrulanmadı (bu makinede SDK yok)
- [ ] Y-1 KVKK: TC kimlik düz metin, raporda maskesiz
- [ ] Y-2 nesne düzeyi yetki yok → v2 Kullanıcı Yönetimi + kapsam (bölge/il) ile çözülecek
- [ ] Y-3 kaba kuvvet koruması yok
- [ ] Y-4 yedekleme/geri yükleme prosedürü yok
