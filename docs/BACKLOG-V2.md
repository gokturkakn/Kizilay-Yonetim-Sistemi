# TYS v2 — Sprint Durumu

Kaynak: [SPEC-V2.md](SPEC-V2.md) · v1 tabanı: git commit `12cef9f`

## Faz 0 — Hazırlık ✅
- [x] Kapsam analizi ve mimari kararlar (K1 lookups, K2 bölge, K3 üç durumlu statü,
      K4 org_units, K5 dosya ekleri, K6 takvim) → SPEC-V2.md
- [x] **v1 git'e alındı** (`12cef9f`, 181 dosya) — breaking göç öncesi geri dönüş noktası
- [x] `.gitignore` (veritabanı, node_modules, build çıktıları, yüklenen dosyalar hariç)

## Faz A+B — Veri temeli ve API (Backend Architect) 🔄
- [ ] Göç (migration) altyapısı — v1 veritabanı kayıpsız yükseltilmeli
- [ ] K1 lookups: tüm açılır listeler DB'den, kod değişikliği gerektirmeden
- [ ] K2 7 coğrafi bölge, 81 ilin eşlenmesi
- [ ] K3 `is_active` → `status` (aktif/pasif/teşkilat_yok), geriye dönük uyum
- [ ] K4 org_units + görevlendirmeler (il/ilçe başkanlıkları "teşkilat yok" ile başlar)
- [ ] K5 dosya ekleri (fotoğraf/doküman/tutanak/sunum)
- [ ] K6 takvim (bayramlar, resmî günler, önemli gün ve haftalar)
- [ ] Modül API'leri: görevler, eğitimler, etkinlikler, toplantılar v2, lojistik,
      dashboard, tanımlar, kullanıcı yönetimi
- [ ] `docs/API-V2.md` sözleşmesi

## Faz C — Arayüz (UX Architect → Frontend Developer) 🔄
- [ ] `docs/UX-V2.md`: 5 modüllü navigasyon, responsive (mobil/tablet/masaüstü),
      dashboard tasarımı, dinamik form kuralı, üç durumlu statü bileşeni
- [ ] Flutter uygulaması: yeni navigasyon, modül ekranları, dinamik formlar, dashboard

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
