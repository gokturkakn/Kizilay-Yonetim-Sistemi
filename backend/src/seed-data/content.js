// Modül giriş ekranlarındaki bilgilendirme metinleri (SPEC-V2 §3.1).
// Tohumlanan metinler başlangıç içeriğidir; Yönetim Paneli > İçerik Yönetimi'nden değiştirilir.
// Tohumlama var olan bir bloğun metnini ASLA ezmez (yönetici düzenlemesi korunur).

export const CONTENT_BLOCKS = [
  {
    key: 'teskilatlanma.koordinasyon_kurulu',
    title: 'Koordinasyon Kurulu',
    body: 'Kızılay Kadın Koordinasyon Kurulu, teşkilatın genel merkez düzeyindeki karar ve '
      + 'yönlendirme organıdır. Bu ekrandan kurul üyeleri, görevleri ve görev süreleri yönetilir.',
  },
  {
    key: 'teskilatlanma.bolge_temsilcileri',
    title: 'Bölge Temsilcileri',
    body: 'Yedi coğrafi bölgenin her biri için görevlendirilen bölge temsilcileri burada '
      + 'listelenir. Temsilci atanmamış bölgeler "Teşkilat Yok" durumunda görünür.',
  },
  {
    key: 'teskilatlanma.komisyonlar',
    title: 'Komisyonlar',
    body: 'Komisyonlar, belirli çalışma alanlarında faaliyet yürüten uzmanlık birimleridir. '
      + 'Yeni komisyon eklemek için Yönetim Paneli > Tanımlar bölümünü kullanın.',
  },
  {
    key: 'teskilatlanma.il_baskanliklari',
    title: 'İl Kadın Başkanlıkları',
    body: '81 ilin tamamı sistemde tanımlıdır. Başkan ataması yapılmamış iller '
      + '"Teşkilat Yok" durumunda listelenir; teşkilatlanma boşluğu raporu bu bilgiye dayanır.',
  },
  {
    key: 'teskilatlanma.ilce_baskanliklari',
    title: 'İlçe Kadın Başkanlıkları',
    body: 'İlçe başkanlıkları bağlı oldukları il başkanlığı altında yönetilir. '
      + 'Görevlendirme yapıldığında birim otomatik olarak "Aktif" duruma geçer.',
  },
  {
    key: 'teskilatlanma.temsilcilikler',
    title: 'Temsilcilikler',
    body: 'İl ve ilçe başkanlığı yapısı dışında kalan temsilcilikler bu ekrandan yönetilir.',
  },
  {
    key: 'saha.gorevler',
    title: 'Görevler',
    body: 'Saha görevleri 12 ana başlık altında kaydedilir. Alt görev listesi seçilen ana '
      + 'başlığa göre değişir. Fotoğraf ve dokümanlar kayıt oluşturulduktan sonra eklenir.',
  },
  {
    key: 'saha.egitimler',
    title: 'Eğitimler',
    body: 'Eğitimler kategori (Gönüllü / Halka Açık) ve yöntem (Yüz Yüze / Çevrim İçi) '
      + 'kırılımıyla kaydedilir. Katılım listesi ek olarak yüklenmelidir.',
  },
  {
    key: 'saha.etkinlikler',
    title: 'Etkinlikler',
    body: 'Etkinlik adı serbest metin olarak yazılmaz; millî ve dinî bayramlar, resmî günler '
      + 'ile önemli gün ve haftaları içeren takvimden seçilir.',
  },
  {
    key: 'saha.toplantilar',
    title: 'Toplantılar',
    body: 'Yedi toplantı türü tanımlıdır. Yüz yüze toplantılarda toplantı yeri, çevrim içi '
      + 'toplantılarda platform bilgisi istenir. Tutanak ve sunumlar ek olarak yüklenir.',
  },
  {
    key: 'lojistik.genel',
    title: 'Lojistik',
    body: 'Malzeme talebi oluşturulur, gönderi kaydedilir ve stok hareketi otomatik işlenir. '
      + 'Ürün listesi Yönetim Paneli > Tanımlar > Lojistik Ürünü altından yönetilir.',
  },
  {
    key: 'raporlama.genel',
    title: 'Raporlama ve Dashboard',
    body: 'Tüm raporlar bölge, il, ilçe, tarih aralığı ve faaliyet türü filtreleriyle alınabilir. '
      + 'Çıktı biçimi Excel (.xlsx) olarak indirilebilir.',
  },
  {
    key: 'yonetim.genel',
    title: 'Yönetim Paneli',
    body: 'Kullanıcı yönetimi, tanımlar, içerik yönetimi ve sistem ayarları bu bölümdedir. '
      + 'Tanımlar bölümündeki listelere yeni kayıt eklemek kod değişikliği gerektirmez.',
  },
];
