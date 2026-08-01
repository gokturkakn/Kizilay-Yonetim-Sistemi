# NEXUS-Sprint Backlog — Startup MVP Build

Orkestratör bu dosyayı fazlar ilerledikçe günceller.

## Faz 0 — Keşif & Sprint Planı (Orchestrator + Senior PM + Sprint Prioritizer)
- [x] Ortam doğrulama (Flutter 3.41.9 ✓, web hedefi ✓, iOS/Android SDK yok — not edildi)
- [x] SPEC.md, API.md yazıldı
- [x] Görev dağılımı (bu dosya)

## Faz 1 — Mimari & Tasarım (paralel)
- [x] **Backend Architect:** `backend/` — Express+SQLite API, tohum veri (81 il+973 ilçe,
      6 komisyon, görev alanları, 2 kullanıcı), exceljs export, audit log,
      46/46 duman testi ✓ (tamamlandı)
- [x] **UX Architect:** `docs/UX.md` — ekran haritası, navigasyon, Kızılay marka
      renkleri/tema token'ları, Flutter widget rehberi ✓ (tamamlandı)

## Faz 2 — Uygulama Geliştirme
- [x] **Frontend Developer:** `app/` — 21 ekran, Provider, analyze 0 hata,
      12 test ✓, `flutter build web` ✓ (tamamlandı)

## Faz 3 — QA & Kanıt
- [x] Uçtan uca doğrulama tamamlandı → `evidence/EVIDENCE.md` + `evidence/curl-checks.txt`
      (Evidence Collector ajanı 5. adımda durduruldu; doğrulamayı orkestratör tamamladı)
- [x] 18 akışın tamamı geçti; 5 bulgu kaydedildi
- [x] BULGU-1 (majör, audit filtresi tire/alt çizgi uyuşmazlığı) düzeltildi ve doğrulandı
- [ ] BULGU-2/3 (minör: erişilebilirlik etiketleri, çip taşması) — sonraki sürüme

## Faz 4 — Gerçeklik Kontrolü & Teslim
- [x] **Reality Checker:** bağımsız denetim → `evidence/REALITY-CHECK.md`
      **KARAR: NEEDS WORK** (6 bloke edici madde)
- [x] BLOKE-2 (kişi formundaki aktif/pasif tiki yazılmıyordu) düzeltildi + regresyon testi
- [x] BLOKE-3 (denetim izinde "kim" yoktu) düzeltildi + regresyon testi
- [x] Duman testi 46 → 51 kontrol, hepsi geçiyor
- [x] Demo veri referans veriden ayrıldı: `npm start` artık sahte kişi yüklemiyor
      (`start:demo` / `seed:demo` ile isteğe bağlı), `npm run db:reset` temizlik aracı
      eklendi, `test/seed-modes.mjs` (9 kontrol) sızıntıyı engelliyor
- [x] README + çalıştırma talimatları

### Açık bloke ediciler (kod değil, karar/altyapı gerektirir)
- [ ] BLOKE-1: Proje sürüm kontrolünde değil — tek commit yok, tohum veri dosyasının
      tek kopyası bu makinede. **En acil madde.**
- [ ] BLOKE-4: Excel indirme mobil hedefte çalışmıyor (web'de çalışıyor)
- [ ] BLOKE-5: Varsayılan JWT anahtarı sessizce kullanılıyor; şifre değiştirme ucu yok;
      tohum şifreler README'de açık
- [ ] BLOKE-6: Android/iOS derlemesi hiç doğrulanmadı (bu makinede SDK yok)
- [ ] Yüksek riskler: KVKK (TC kimlik düz metin, maskesiz rapor), nesne düzeyi yetki
      yok (saha herkesin kaydını düzenleyebiliyor), kaba kuvvet koruması yok, yedekleme yok

## Faz 5 (3. hafta+) — Growth Team
- Beklemede (kullanıcı talebiyle şimdilik devre dışı)

## Faz 5 (3. hafta+) — Growth Team
- [ ] Growth Hacker / Content Creator / Social Media Strategist — MVP canlıya
      çıkıp gerçek kullanıcı alana kadar BEKLEMEDE (runbook gereği hafta 3+)

## Kurallar
- Ajanlar commit/push YAPMAZ (kullanıcı istemedikçe).
- Flutter yolu: `/Users/grravitie/flutter/bin/flutter`
- Backend portu 4141; API.md sözleşmesi bağlayıcı.
