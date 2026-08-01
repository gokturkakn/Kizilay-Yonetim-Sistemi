/**
 * K1 — Tohum "Tanımlar" (lookup) verisi.
 *
 * SPEC-V2 §2 K1'deki 14 kategori ve §3'teki kalemler. Bu liste yalnızca BAŞLANGIÇ
 * durumudur; Yönetim Paneli'nden kalem eklenip çıkarılabilir (kod değişikliği gerekmez).
 * Tohumlama idempotenttir ve mevcut kalemleri DEĞİŞTİRMEZ — yalnız eksik olanı ekler.
 */

/** Hiyerarşik kategoriler: alt kalemler `parent_category` içindeki bir kaleme bağlanır. */
export const LOOKUP_CATEGORIES = [
  { code: 'bolge', name: 'Bölge' },
  { code: 'gorev_turu', name: 'Görev Türü' },
  { code: 'alt_gorev', name: 'Alt Görev', parent_category: 'gorev_turu' },
  { code: 'egitim_konusu', name: 'Eğitim Konusu' },
  { code: 'egitim_kategorisi', name: 'Eğitim Kategorisi' },
  { code: 'egitim_yontemi', name: 'Eğitim Yöntemi' },
  { code: 'etkinlik_turu', name: 'Etkinlik Türü' },
  { code: 'etkinlik_adi', name: 'Etkinlik Adı' },
  { code: 'toplanti_turu', name: 'Toplantı Türü' },
  { code: 'toplanti_yontemi', name: 'Toplantı Yöntemi' },
  { code: 'lojistik_urun', name: 'Lojistik Ürünü' },
  { code: 'gonderim_sekli', name: 'Gönderim Şekli' },
  { code: 'gorev_unvani', name: 'Görev / Unvan' },
  { code: 'durum', name: 'Durum' },
];

// SPEC-V2 §3.2A — 12 ana görev başlığı.
const GOREV_TURLERI = [
  'Aşevi',
  'Butik',
  'Gıda Kolisi',
  'Ziyaretler',
  'Kan Hizmetleri',
  'Çocuk',
  'Gençlik',
  'Aile Yılı',
  'Gönüllü Kazanımı',
  'Bağışçı ve Kaynak Geliştirme',
  'Sosyal Destek',
  'Afet',
];

// Alt görevler — ana başlığa bağlı (parent_id). Yönetim Paneli'nden genişletilir.
const ALT_GOREVLER = {
  'Aşevi': ['Sıcak Yemek Dağıtımı', 'Aşevi Gönüllü Desteği', 'İftar Organizasyonu'],
  'Butik': ['Kıyafet Bağışı Toplama', 'Butik Düzenleme', 'Kıyafet Dağıtımı'],
  'Gıda Kolisi': ['Koli Hazırlama', 'Koli Dağıtımı', 'İhtiyaç Tespiti'],
  'Ziyaretler': ['Hasta Ziyareti', 'Yaşlı Ziyareti', 'Şehit Ailesi Ziyareti', 'Huzurevi Ziyareti', 'Yetimhane Ziyareti'],
  'Kan Hizmetleri': ['Kan Bağışı Organizasyonu', 'Kan Bağışı Farkındalık Standı', 'Bağışçı Kazanımı'],
  'Çocuk': ['Çocuk Atölyesi', 'Oyun ve Etkinlik Günü', 'Eğitim Materyali Desteği'],
  'Gençlik': ['Gençlik Buluşması', 'Üniversite Tanıtım Standı', 'Gençlik Kampı'],
  'Aile Yılı': ['Aile Semineri', 'Aile Danışmanlığı Yönlendirmesi', 'Aile Etkinliği'],
  'Gönüllü Kazanımı': ['Gönüllü Tanıtım Toplantısı', 'Gönüllü Kayıt Standı', 'Gönüllü Oryantasyonu'],
  'Bağışçı ve Kaynak Geliştirme': ['Kurumsal Görüşme', 'Bağış Kampanyası', 'Kermes ve Hayır Çarşısı'],
  'Sosyal Destek': ['Nakdi Yardım Yönlendirmesi', 'Ayni Yardım Dağıtımı', 'İhtiyaç Sahibi Tespiti'],
  'Afet': ['Afet Bölgesi Saha Desteği', 'Afet Çantası Hazırlama', 'Afet Bilinçlendirme', 'Psikososyal Destek'],
};

// SPEC-V2 §3.2B — 18 hazır eğitim konusu.
const EGITIM_KONULARI = [
  'İlk Yardım',
  'Temel Afet Bilinci',
  'Afete Hazırlık ve Müdahale',
  'Psikososyal Destek',
  'Gönüllülük ve Gönüllü Yönetimi',
  'Kan Bağışı Farkındalığı',
  'Sağlıklı Yaşam ve Beslenme',
  'Kadın Sağlığı',
  'Anne ve Çocuk Sağlığı',
  'Evde Bakım Rehberliği',
  'Hijyen ve Bulaşıcı Hastalıklardan Korunma',
  'İletişim Becerileri',
  'Liderlik ve Ekip Yönetimi',
  'Proje Döngüsü Yönetimi',
  'Sosyal Medya ve Dijital İletişim',
  'Kızılay Tarihi ve Kurum Kültürü',
  'Uluslararası İnsancıl Hukuk ve Temel İlkeler',
  'Yangın Güvenliği ve Tahliye',
];

// SPEC-V2 §3.3 — lojistik ürünleri (birebir).
const LOJISTIK_URUNLERI = [
  'Yelek', 'Rozet', 'Bayrak', 'Flama', 'Roll-up', 'Broşür', 'Afiş',
  'Masa Örtüsü', 'Kalem', 'Defter', 'Bez Çanta', 'Kupa', 'Şapka', 'Tişört', 'Diğer',
];

/** kategori kodu → düz kalem listesi (hiyerarşik olmayanlar) */
export const LOOKUP_ITEMS = {
  bolge: ['Marmara', 'Ege', 'Akdeniz', 'İç Anadolu', 'Karadeniz', 'Doğu Anadolu', 'Güneydoğu Anadolu'],

  gorev_turu: GOREV_TURLERI,

  egitim_konusu: EGITIM_KONULARI,
  egitim_kategorisi: ['Gönüllü', 'Halka Açık'],
  egitim_yontemi: ['Yüz Yüze', 'Çevrim İçi'],

  etkinlik_turu: [
    'Millî Bayram', 'Dinî Bayram', 'Resmî Gün', 'Önemli Gün', 'Önemli Hafta',
    'Anma Programı', 'Kutlama Programı', 'Farkındalık Etkinliği',
  ],
  // Etkinliğin ADI takvimden (calendar_events) seçilir — SPEC-V2 §3.2C.
  // Bu kategori, etkinliğin yapılış biçimini adlandırmak için tamamlayıcıdır.
  etkinlik_adi: [
    'Bayramlaşma Programı', 'Anma Töreni', 'Kutlama Programı', 'Farkındalık Standı',
    'Ziyaret Programı', 'Kermes', 'Çelenk Sunma Töreni', 'Söyleşi ve Panel',
  ],

  // SPEC-V2 §3.2D — 7 toplantı türü.
  toplanti_turu: [
    'Koordinasyon Kurulu Toplantısı', 'Bölge Toplantısı', 'İl Toplantısı',
    'İlçe Toplantısı', 'Komisyon Toplantısı', 'Kamp', 'Çalıştay',
  ],
  toplanti_yontemi: ['Yüz Yüze', 'Çevrim İçi'],

  lojistik_urun: LOJISTIK_URUNLERI,
  gonderim_sekli: ['Kargo', 'Elden Teslim', 'Kurye'],

  gorev_unvani: [
    'Başkan', 'Başkan Yardımcısı', 'Sekreter', 'Sayman', 'Üye',
    'Komisyon Başkanı', 'Komisyon Üyesi', 'Bölge Temsilcisi',
    'İl Başkanı', 'İlçe Başkanı', 'Temsilci', 'Gönüllü',
  ],

  durum: ['Aktif', 'Pasif', 'Teşkilat Yok'],
};

/** kategori kodu → { ebeveyn kalem adı: [alt kalem adları] } */
export const HIERARCHICAL_ITEMS = {
  alt_gorev: { parentCategory: 'gorev_turu', items: ALT_GOREVLER },
};

/** Doğrulama için beklenen kalem sayıları (SPEC-V2'deki sayılar). */
export const EXPECTED_ITEM_COUNTS = {
  gorev_turu: 12,
  egitim_konusu: 18,
  toplanti_turu: 7,
  lojistik_urun: 15,
  bolge: 7,
};
