// K2 — 7 coğrafi bölge ve 81 ilin plaka koduyla eşlenmesi.
// Eşleme plaka kodu üzerinden yapılır (isim yazımı/encoding'e bağımlı değildir).

export const REGIONS = [
  { code: 'marmara', name: 'Marmara', sort_order: 1 },
  { code: 'ege', name: 'Ege', sort_order: 2 },
  { code: 'akdeniz', name: 'Akdeniz', sort_order: 3 },
  { code: 'ic_anadolu', name: 'İç Anadolu', sort_order: 4 },
  { code: 'karadeniz', name: 'Karadeniz', sort_order: 5 },
  { code: 'dogu_anadolu', name: 'Doğu Anadolu', sort_order: 6 },
  { code: 'guneydogu_anadolu', name: 'Güneydoğu Anadolu', sort_order: 7 },
];

/** bölge kodu → o bölgedeki illerin plaka kodları */
export const REGION_PROVINCE_CODES = {
  // 11 il
  marmara: [34, 22, 39, 59, 17, 10, 16, 77, 41, 54, 11],
  // 8 il
  ege: [35, 45, 9, 20, 48, 3, 43, 64],
  // 8 il
  akdeniz: [7, 32, 15, 33, 1, 80, 31, 46],
  // 13 il
  ic_anadolu: [6, 42, 26, 40, 71, 66, 58, 50, 51, 68, 70, 38, 18],
  // 18 il
  karadeniz: [14, 81, 67, 74, 78, 37, 57, 55, 5, 19, 60, 52, 28, 61, 53, 8, 29, 69],
  // 14 il
  dogu_anadolu: [25, 24, 4, 36, 75, 76, 65, 49, 13, 12, 23, 62, 44, 30],
  // 9 il
  guneydogu_anadolu: [27, 79, 63, 2, 21, 47, 72, 56, 73],
};

/** Beklenen il sayıları — tohumlama sonrası doğrulama için (toplam 81). */
export const EXPECTED_PROVINCE_COUNTS = {
  marmara: 11,
  ege: 8,
  akdeniz: 8,
  ic_anadolu: 13,
  karadeniz: 18,
  dogu_anadolu: 14,
  guneydogu_anadolu: 9,
};
