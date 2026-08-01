/**
 * K6 — Etkinlik takvimi tohum verisi (SPEC-V2 §3.2C).
 *
 * Etkinlik modülünde ad YAZILMAZ, bu listeden SEÇİLİR.
 *
 * Kategoriler:
 *   milli_bayram · dini_bayram · dini_gun · resmi_gun · onemli_gun · onemli_hafta
 *
 * `is_fixed = 0` olanlar hicri takvime bağlıdır: ay/gün NULL'dur, gerçek tarih
 * `calendar_event_dates` tablosunda yıl bazında tutulur (MOVABLE_DATES).
 */

export const CALENDAR_EVENTS = [
  // --- Millî bayramlar ve resmî tatiller (sabit) ---------------------------
  { name: 'Yılbaşı', category: 'resmi_gun', month: 1, day: 1 },
  { name: 'Ulusal Egemenlik ve Çocuk Bayramı', category: 'milli_bayram', month: 4, day: 23 },
  { name: 'Emek ve Dayanışma Günü', category: 'resmi_gun', month: 5, day: 1 },
  { name: "Atatürk'ü Anma, Gençlik ve Spor Bayramı", category: 'milli_bayram', month: 5, day: 19 },
  { name: 'Demokrasi ve Millî Birlik Günü', category: 'milli_bayram', month: 7, day: 15 },
  { name: 'Zafer Bayramı', category: 'milli_bayram', month: 8, day: 30 },
  { name: 'Cumhuriyet Bayramı', category: 'milli_bayram', month: 10, day: 29 },

  // --- Dinî bayram ve kandiller (hareketli) --------------------------------
  { name: 'Ramazan Bayramı', category: 'dini_bayram', is_fixed: 0, note: 'Hicri takvime göre değişir (3 gün).' },
  { name: 'Kurban Bayramı', category: 'dini_bayram', is_fixed: 0, note: 'Hicri takvime göre değişir (4 gün).' },
  { name: 'Ramazan Ayı Başlangıcı', category: 'dini_gun', is_fixed: 0, note: 'Hicri takvime göre değişir.' },
  { name: 'Kadir Gecesi', category: 'dini_gun', is_fixed: 0, note: 'Ramazan ayının 27. gecesi.' },
  { name: 'Regaib Kandili', category: 'dini_gun', is_fixed: 0, note: 'Recep ayının ilk cuma gecesi.' },
  { name: 'Miraç Kandili', category: 'dini_gun', is_fixed: 0, note: 'Recep ayının 27. gecesi.' },
  { name: 'Berat Kandili', category: 'dini_gun', is_fixed: 0, note: 'Şaban ayının 15. gecesi.' },
  { name: 'Mevlid Kandili', category: 'dini_gun', is_fixed: 0, note: 'Rebiülevvel ayının 12. gecesi.' },
  { name: 'Aşure Günü', category: 'dini_gun', is_fixed: 0, note: 'Muharrem ayının 10. günü.' },

  // --- Resmî / anma günleri (sabit) ---------------------------------------
  { name: '6 Şubat Depremlerinde Hayatını Kaybedenleri Anma Günü', category: 'resmi_gun', month: 2, day: 6 },
  { name: "İstiklal Marşı'nın Kabulü ve Mehmet Akif Ersoy'u Anma Günü", category: 'resmi_gun', month: 3, day: 12 },
  { name: 'Tıp Bayramı', category: 'resmi_gun', month: 3, day: 14 },
  { name: 'Çanakkale Zaferi ve Şehitleri Anma Günü', category: 'resmi_gun', month: 3, day: 18 },
  { name: 'Öğretmenler Günü', category: 'resmi_gun', month: 11, day: 24 },
  { name: "Atatürk'ü Anma Günü", category: 'resmi_gun', month: 11, day: 10 },
  { name: "Atatürk'ün Ankara'ya Gelişi", category: 'resmi_gun', month: 12, day: 27 },

  // --- Kızılay günleri (kurumsal) -----------------------------------------
  { name: 'Dünya Kızılay ve Kızılhaç Günü', category: 'onemli_gun', month: 5, day: 8 },
  { name: 'Türk Kızılay Kuruluş Yıl Dönümü', category: 'onemli_gun', month: 6, day: 11, note: '1868' },

  // --- Önemli günler ------------------------------------------------------
  { name: 'Dünya Kanser Günü', category: 'onemli_gun', month: 2, day: 4 },
  { name: 'Dünya Kadınlar Günü', category: 'onemli_gun', month: 3, day: 8 },
  { name: 'Dünya Su Günü', category: 'onemli_gun', month: 3, day: 22 },
  { name: 'Dünya Down Sendromu Farkındalık Günü', category: 'onemli_gun', month: 3, day: 21 },
  { name: 'Dünya Otizm Farkındalık Günü', category: 'onemli_gun', month: 4, day: 2 },
  { name: 'Dünya Sağlık Günü', category: 'onemli_gun', month: 4, day: 7 },
  { name: 'Dünya Hemşireler Günü', category: 'onemli_gun', month: 5, day: 12 },
  { name: 'Dünya Aile Günü', category: 'onemli_gun', month: 5, day: 15 },
  { name: 'Dünya Çevre Günü', category: 'onemli_gun', month: 6, day: 5 },
  { name: 'Dünya Gönüllü Kan Bağışçıları Günü', category: 'onemli_gun', month: 6, day: 14 },
  { name: 'Dünya Mülteciler Günü', category: 'onemli_gun', month: 6, day: 20 },
  { name: 'Dünya İnsani Yardım Günü', category: 'onemli_gun', month: 8, day: 19 },
  { name: 'Dünya Gençlik Günü', category: 'onemli_gun', month: 8, day: 12 },
  { name: 'Dünya İlk Yardım Günü', category: 'onemli_gun', is_fixed: 0, note: 'Eylül ayının ikinci cumartesi.' },
  { name: 'Dünya Alzheimer Günü', category: 'onemli_gun', month: 9, day: 21 },
  { name: 'Dünya Yaşlılar Günü', category: 'onemli_gun', month: 10, day: 1 },
  { name: 'Dünya Ruh Sağlığı Günü', category: 'onemli_gun', month: 10, day: 10 },
  { name: 'Dünya Afet Risklerinin Azaltılması Günü', category: 'onemli_gun', month: 10, day: 13 },
  { name: 'Dünya Gıda Günü', category: 'onemli_gun', month: 10, day: 16 },
  { name: 'Dünya Yoksullukla Mücadele Günü', category: 'onemli_gun', month: 10, day: 17 },
  { name: 'Dünya Çocuk Hakları Günü', category: 'onemli_gun', month: 11, day: 20 },
  { name: 'Kadına Yönelik Şiddete Karşı Uluslararası Mücadele Günü', category: 'onemli_gun', month: 11, day: 25 },
  { name: 'Dünya Engelliler Günü', category: 'onemli_gun', month: 12, day: 3 },
  { name: 'Uluslararası Gönüllüler Günü', category: 'onemli_gun', month: 12, day: 5 },
  { name: 'Türk Kadınına Seçme ve Seçilme Hakkının Verilişi', category: 'onemli_gun', month: 12, day: 5 },
  { name: 'Dünya İnsan Hakları Günü', category: 'onemli_gun', month: 12, day: 10 },

  // --- Önemli haftalar (başlangıç–bitiş) ----------------------------------
  { name: 'Yeşilay Haftası', category: 'onemli_hafta', month: 3, day: 1, end_month: 3, end_day: 7 },
  { name: 'Bilim ve Teknoloji Haftası', category: 'onemli_hafta', month: 3, day: 8, end_month: 3, end_day: 14 },
  { name: 'Yaşlılar Haftası', category: 'onemli_hafta', month: 3, day: 18, end_month: 3, end_day: 24 },
  { name: 'Turizm Haftası', category: 'onemli_hafta', month: 4, day: 15, end_month: 4, end_day: 22 },
  { name: 'Karayolu Trafik Güvenliği Haftası', category: 'onemli_hafta', month: 5, day: 1, end_month: 5, end_day: 7 },
  { name: 'Engelliler Haftası', category: 'onemli_hafta', month: 5, day: 10, end_month: 5, end_day: 16 },
  { name: 'Aile Haftası', category: 'onemli_hafta', month: 5, day: 15, end_month: 5, end_day: 21 },
  { name: 'Müzeler Haftası', category: 'onemli_hafta', month: 5, day: 18, end_month: 5, end_day: 24 },
  { name: 'Gençlik Haftası', category: 'onemli_hafta', month: 5, day: 19, end_month: 5, end_day: 25 },
  { name: 'Çevre Koruma Haftası', category: 'onemli_hafta', month: 6, day: 5, end_month: 6, end_day: 11 },
  { name: 'İtfaiye Haftası', category: 'onemli_hafta', month: 9, day: 25, end_month: 10, end_day: 1 },
  { name: 'Hayvanları Koruma Haftası', category: 'onemli_hafta', month: 10, day: 4, end_month: 10, end_day: 10 },
  { name: 'Kızılay Haftası', category: 'onemli_hafta', month: 10, day: 29, end_month: 11, end_day: 4 },
  { name: 'Organ Bağışı Haftası', category: 'onemli_hafta', month: 11, day: 3, end_month: 11, end_day: 9 },
  { name: 'Ağız ve Diş Sağlığı Haftası', category: 'onemli_hafta', month: 11, day: 21, end_month: 11, end_day: 27 },
  { name: 'İnsan Hakları ve Demokrasi Haftası', category: 'onemli_hafta', month: 12, day: 10, end_month: 12, end_day: 16 },
  { name: 'Tutum, Yatırım ve Türk Malları Haftası', category: 'onemli_hafta', month: 12, day: 12, end_month: 12, end_day: 18 },
];

/**
 * Hareketli (hicri) etkinliklerin yıl bazlı tarihleri.
 *
 * DİKKAT: Yalnızca kesin bilinen iki dinî bayram tohumlanır. Kandiller ve
 * "Dünya İlk Yardım Günü" gibi diğer hareketli günlerin tarihleri kasıtlı olarak
 * BOŞ bırakılmıştır — uydurma tarih tohumlamaktansa yöneticinin
 * `POST /calendar-events/:id/dates` ile girmesi doğrudur.
 */
export const MOVABLE_DATES = [
  { name: 'Ramazan Bayramı', year: 2026, start_date: '2026-03-20', end_date: '2026-03-22' },
  { name: 'Ramazan Bayramı', year: 2027, start_date: '2027-03-09', end_date: '2027-03-11' },
  { name: 'Kurban Bayramı', year: 2026, start_date: '2026-05-27', end_date: '2026-05-30' },
  { name: 'Kurban Bayramı', year: 2027, start_date: '2027-05-16', end_date: '2027-05-19' },
];
