/// v2 sözlüğü — docs/UX-V2.md §9. Metinler **aynen** kopyalanmıştır.
/// v1 anahtarları (`Str`) değişmedi; bu sınıf onun üstüne biner.
class S2 {
  S2._();

  // ---- 9.1 Ortak ----
  static const dahaFazla = 'Daha Fazla';
  static const filtreler = 'Filtreler';
  static const sirala = 'Sırala';
  static const tumunuGor = 'Tümünü Gör';
  static const ekle = 'Ekle';
  static const kaldir = 'Kaldır';
  static const duzenle = 'Düzenle';
  static const cik = 'Çık';
  static const ac = 'Aç';
  static const kopyala = 'Kopyala';
  static const indir = 'İndir';
  static const filtreleriTemizle = 'Filtreleri Temizle';
  static const tabloGorunumu = 'Tablo görünümü';
  static const gorseliKaydet = 'Görseli kaydet';
  static const excelAktar = "Excel'e aktar";
  static const ilGeneli = 'İl geneli';
  static const devamEdiyor = 'devam ediyor';
  static const toplam = 'Toplam';
  static const sistem = 'Sistem';
  static const kayitYok = 'Kayıt yok';

  // ---- 9.2 Durum ----
  static const aktif = 'Aktif';
  static const pasif = 'Pasif';
  static const teskilatYok = 'Teşkilat Yok';
  static const teskilatYokAlt = 'Teşkilatlanma boşluğu';
  static const gorevliYok = 'Henüz görevli atanmamış.';
  static const gorevliAta = 'Görevli Ata';
  static const gorevliKilit =
      'Bu birimde aktif görevli bulunduğu için "Teşkilat Yok" seçilemez.';
  static const otomatikTeskilatYok =
      'Birimde görevli kalmadığı için durum "Teşkilat Yok" olarak güncellendi.';
  static const otomatikAktif = 'Birim durumu "Aktif" olarak güncellendi.';
  static const durumGuncellendi = 'Durum güncellendi.';

  static const talepTalep = 'Talep Edildi';
  static const talepOnaylandi = 'Onaylandı';
  static const talepGonderildi = 'Gönderildi';
  static const talepTeslimEdildi = 'Teslim Edildi';
  static const talepIptal = 'İptal Edildi';
  static const talepDurumGuncellendi = 'Talep durumu güncellendi.';
  static const gonderiYolda = 'Yolda';
  static const gonderiTeslimEdildi = 'Teslim Edildi';
  static const stokKritik = 'Stok kritik seviyenin altında.';
  static const stokYok = 'Stokta ürün kalmadı.';
  static String stokKritikOzet(int n) =>
      '$n üründe stok kritik seviyenin altında.';
  static String stokYetersiz(int n) => 'Stok yetersiz. Mevcut stok: $n.';

  // ---- 9.3 Navigasyon ve modüller ----
  static const modulDashboard = 'Raporlama ve Dashboard';
  static const modulTeskilatlanma = 'Teşkilatlanma';
  static const modulSaha = 'Saha Faaliyetleri';
  static const modulLojistik = 'Lojistik';
  static const modulYonetim = 'Yönetim Paneli';
  static const modulProfil = 'Profil';
  static const modulDokuman = 'Kılavuz ve Dokümanlar';

  // ---- Modül 6 · Kılavuz ve Dokümanlar (SPEC-V2-M6 §5.3 — aynen) ----
  static const dokBosKategori = 'Bu kategoride henüz doküman yok.';
  static const dokBosSaha = 'Genel merkez doküman eklediğinde burada görünecek.';
  static const dokSuresiDoldu = 'Süresi doldu';
  static const dokKapsamGenel = 'Genel';
  static const dokIndirildi = 'Dosya indirildi.';
  static const dokYayindanKaldirGovde =
      'Bu doküman sahada görünmeyecek. Kayıt silinmez, tekrar yayına alınabilir. '
      'Devam edilsin mi?';

  // Ekran metinleri (SPEC-V2-M6 §5.1/§5.2 ve UX-V2 sözlüğü ile uyumlu).
  static const dokYalnizBana = 'Yalnız bana ait olanlar';
  static const dokAramaIpucu = 'Doküman ara...';
  static const dokYayindanKaldir = 'Yayından Kaldır';
  static const dokYayinaAl = 'Yayına Al';
  static const dokYayindanKaldirBaslik = 'Yayından kaldır';
  static const dokYayindanKaldirildi = 'Doküman yayından kaldırıldı.';
  static const dokYayinaAlindi = 'Doküman yayına alındı.';
  static const dokKaydedildi = 'Doküman kaydedildi.';
  static const dokYeni = 'Yeni Doküman';
  static const dokDuzenle = 'Dokümanı Düzenle';
  static const dokSilBaslik = 'Doküman silinsin mi?';
  static const dokKapsamBolge = 'Bölge';
  static const dokKapsamIl = 'İl';
  static const dokKapsamIlce = 'İlçe';
  static const dokSurum = 'Sürüm';
  static const dokYayinTarihi = 'Yayın Tarihi';
  static const dokSonGecerlilik = 'Son Geçerlilik';
  static const dokKategori = 'Kategori';
  static const dokKapsam = 'Kapsam';
  static const dokBaslik = 'Başlık';
  static const dokAciklama = 'Açıklama';
  static const dokBilgileri = 'Doküman Bilgileri';
  static const dokKapsamBilgileri = 'Kapsam Bilgileri';
  static const dokIndirmeSayisi = 'İndirme sayısı';
  static String dokDosyaSayisi(int n) => '$n dosya';
  static const dokYalnizBanaAlt =
      'Yalnız kendi kırılımınıza ait belgeler; ülke geneli belgeler gizlenir.';
  static const dokDosyaYok = 'Dosya eklenmemiş';
  static const dokYayindaDegil = 'Yayında değil';
  static const dokIndir = 'İndir';
  static const dokTumu = 'Tüm Dokümanlar';
  static const dokAramaBaslik = 'Doküman Ara';
  static const dokAramaBos = 'Aramanızla eşleşen doküman bulunamadı.';
  static const dokAramaIpucuAlt = 'Başlık ve açıklama içinde aranır.';
  static const dokBosGenel = 'Henüz doküman yok.';
  static const dokKapsamTumu = 'Tümü';
  static const dokDosyaTuru = 'Dosya türü';
  static const dokTumTurler = 'Tüm Türler';
  static const dokAciklamaYok = 'Açıklama girilmemiş.';
  static const dokEkler = 'Ekli Dosyalar';
  static const dokKategoriler = 'Kategoriler';
  static String dokBelgeSayisi(int n) => '$n belge';
  static const vDokKategori = 'Kategori seçin.';
  static const vDokKapsam = 'Kapsam seçin.';
  static const vDokBaslik = 'Başlık girin.';
  static const vDokBolge = 'Bölge seçin.';
  static const vDokIl = 'İl seçin.';
  static const vDokIlce = 'İlçe seçin.';

  // ---- 9.4 Dinamik form ----
  static String onceSecin(String alan) => 'Önce $alan seçin.';
  static const listeYok =
      'Bu liste henüz tanımlanmamış. Yönetim Paneli → Tanımlar bölümünden '
      'ekleyebilirsiniz.';
  static const listeYokSaha =
      'Bu liste henüz tanımlanmamış. Genel merkez ile iletişime geçin.';
  static const tanimEkleUyari =
      'Aradığınız kayıt listede yoksa Yönetim Paneli → Tanımlar bölümünden '
      'eklenmelidir.';
  static const zorunluBanner = 'Lütfen işaretli alanları doldurun.';
  static const aramaBos = 'Aramanızla eşleşen kayıt bulunamadı.';
  static const bolgeOtomatik = 'Seçilen ile göre otomatik belirlendi.';
  static const altGorevYok = 'Bu görev türü için tanımlı alt görev bulunmuyor.';
  static const konuYok = 'Bu kategori ve yöntem için tanımlı konu bulunmuyor.';
  static const gorevDevam = 'Boş bırakılırsa görev devam ediyor sayılır.';
  static const kirliBaslik = 'Değişiklikler kaydedilmedi';
  static const kirliGovde =
      'Bu sayfadan çıkarsanız girdiğiniz bilgiler silinecek.';

  // Form doğrulama mesajları (verbatim)
  static const vToplantiYontemi = 'Toplantı yöntemi seçin.';
  static const vToplantiYeri = 'Toplantı yerini girin.';
  static const vToplantiYeriKisa = 'Toplantı yeri en az 3 karakter olmalıdır.';
  static const vPlatform = 'Platform seçin.';
  static const vPlatformAdi = 'Platform adını girin.';
  static const vGorevTuru = 'Görev türü seçin.';
  static const vAltGorev = 'Alt görev seçin.';
  static const vEgitimKategorisi = 'Eğitim kategorisi seçin.';
  static const vEgitimYontemi = 'Eğitim yöntemi seçin.';
  static const vEgitimKonusu = 'Eğitim konusu seçin.';
  static const vEgitmen = 'Eğitmen adını girin.';
  static const vEtkinlikTuru = 'Etkinlik türü seçin.';
  static const vEtkinlikAdi = 'Etkinlik seçin.';
  static const vGelirFaaliyetAdi = 'Faaliyet adını girin.';
  static const vGelirFaaliyetTuru = 'Faaliyet türü seçin.';
  static const vGelirTutari = 'Gelir tutarını girin.';
  static const vTutarBicim = 'Geçerli bir tutar girin (örn. 62000 veya 62000,50).';
  static const vBolge = 'Bölge seçin.';
  static const vIl = 'İl seçin.';
  static const vKadinTeskilati = 'Kadın teşkilatı seçin.';
  static const vDuzenleyenTeskilat = 'Düzenleyen teşkilat seçin.';
  static const vTeskilatBirimi = 'Teşkilat birimi seçin.';
  static const vKisi = 'Kişi seçin.';
  static const vGorev = 'Görev seçin.';
  static const vBaslamaTarihi = 'Göreve başlama tarihi seçin.';
  static const vBitisTarihi =
      'Görev bitiş tarihi başlama tarihinden önce olamaz.';
  static const vGonulluSayisi = 'Gönüllü sayısı girin.';
  static const vYararlaniciSayisi = 'Yararlanıcı sayısı girin.';
  static const vKatilimciSayisi = 'Katılımcı sayısı girin.';
  static const vSure = 'Süre girin.';
  static const vSureBicim = 'Süreyi saat cinsinden girin (örn. 2,5).';
  static const vSayi = 'Geçerli bir sayı girin.';
  static const vSayiAralik = '0 ile 999.999 arasında bir değer girin.';
  static const vTarih = 'Tarih seçin.';
  static const vIleriTarih = 'İleri tarihli kayıt girilemez.';
  static const vTarihAraligi = 'Bitiş tarihi başlangıç tarihinden önce olamaz.';
  static const vGundem = 'Gündemi girin.';
  static const vKararlar = 'Alınan kararları girin.';
  static const vUrun = 'Ürün seçin.';
  static const vMiktar = 'Miktar girin.';
  static const vGonderimSekli = 'Gönderim şekli seçin.';
  static const vTakipNo = 'Kargo takip numarasını girin.';
  static const vTeslimAlan = 'Teslim alan kişiyi girin.';
  static const vTeslimTarihi =
      'Teslim tarihi gönderi tarihinden önce olamaz.';
  static const vTalep = 'Talep seçin.';
  static const vGonderiMiktar = 'Miktar, talep edilen miktarı aşamaz.';
  static const vAd = 'Ad girin.';
  static const vKodBicim =
      'Kod yalnızca küçük harf, rakam ve alt çizgi içerebilir.';
  static const vKodCakisma = 'Bu kod zaten kullanılıyor.';
  static const vUstTanim = 'Üst tanım seçin.';
  static const vAdSoyad = 'Ad soyad girin.';
  static const vSifreKisa = 'Şifre en az 8 karakter olmalıdır.';
  static const vSifreYeniKisa = 'Yeni şifre en az 8 karakter olmalıdır.';
  static const vSifreEslesmiyor = 'Şifreler eşleşmiyor.';
  static const vMevcutSifre = 'Mevcut şifreyi girin.';
  static const vMevcutSifreHatali = 'Mevcut şifre hatalı.';
  static const vBaslik = 'Başlık girin.';
  static const vMetin = 'Metin girin.';

  // ---- 9.5 Dashboard ve raporlama ----
  static const dashBaslik = 'Dashboard';
  static const dashTeskilatlanmaDurumu = 'Teşkilatlanma Durumu';
  static const dashTeskilatlanmaKirilimi = 'Teşkilatlanma Kırılımı';
  static const dashFaaliyetOzeti = 'Faaliyet Özeti';
  static const dashEgitimDagilimi = 'Eğitim Dağılımı (Kategori × Yöntem)';
  static const dashLojistik = 'Lojistik';
  static const dashDurumDagilimi = 'Durum Dağılımı';
  static const dashBolgeBazli = 'Bölge Bazlı Teşkilatlanma';
  static const dashIlBazli = 'İl Bazlı Teşkilatlanma';
  static const dashAylikTrend = 'Aylık Faaliyet Trendi';
  static const dashUrunBazli = 'Ürün Bazlı Gönderim';
  static const dashToplamBirim = 'Toplam Birim';
  static String dashToplamOran(int n) => "Toplamın %$n'i";
  static const dashOncekiDonem = 'önceki döneme göre';
  static const dashTumKayitlar = 'Tüm kayıtlar gösteriliyor.';
  static const dashIlceTekIl = 'İlçe filtresi için önce il seçin.';
  static const dashVeriYok = 'Seçilen filtrelerle gösterilecek veri bulunamadı.';
  static const dashBuAy = 'Bu Ay';
  static const dashSon3Ay = 'Son 3 Ay';
  static const dashBuYil = 'Bu Yıl';
  static const dashOzel = 'Özel';
  static const dashFiltreUygulanmadi =
      'İlçe ve faaliyet türü filtreleri özet grafiklere uygulanmaz; '
      'ayrıntı listelerinde geçerlidir.';
  static const dashTekBolge =
      'Özet grafiklerde tek bölge/il dikkate alınır.';

  static const raporMerkezi = 'Rapor Merkezi';
  static const raporOnizleme = 'Rapor Önizleme';
  static const raporDisaAktar = 'Dışa Aktar';
  static const raporExcel = 'Excel (.xlsx)';
  static const raporPdf = 'PDF (.pdf)';
  static const raporFiltreNotu = 'Rapor, seçili filtrelere göre oluşturulur.';
  static const raporIndirildi = 'Rapor indirildi.';
  static const raporIndirilemedi = 'Rapor indirilemedi. Tekrar deneyin.';
  static const raporKayitYok = 'Seçilen filtrelerle kayıt bulunamadı.';
  static const raporDosyaKaydedilemedi =
      'Dosya kaydedilemedi. Depolama iznini kontrol edin.';

  // ---- 9.6 Ekler ----
  static const ekFotograf = 'Fotoğraf';
  static const ekDokuman = 'Doküman';
  static const ekTutanak = 'Tutanak';
  static const ekSunum = 'Sunum';
  static const ekKatilimListesi = 'Katılım Listesi';
  static const ekDosyaEkle = 'Dosya Ekle';
  static const ekFotografCek = 'Fotoğraf Çek';
  static const ekGaleridenSec = 'Galeriden Seç';
  static const ekDosyaSec = 'Dosya Seç';
  static const ekFotografSec = 'Fotoğraf Seç';
  static const ekBuraya = 'Dosyaları buraya bırakın';
  static const ekPanoEklendi = 'Panodaki görsel eklendi.';
  static const ekBosDurum = 'Henüz dosya eklenmedi.';
  static const ekDetayBos = 'Bu kayda eklenmiş dosya bulunmuyor.';
  static const ekSirada = 'Sırada';
  static const ekYukleniyorUyari = 'Dosyalar yükleniyor, lütfen bekleyin.';
  static const ekCikisBaslik = 'Yükleme sürüyor';
  static const ekCikisGovde =
      'Devam eden dosya yüklemeleri iptal edilecek. Çıkmak istiyor musunuz?';
  static const ekSilBaslik = 'Eki sil';
  static String ekSilGovde(String dosya) =>
      '$dosya silinecek. Bu işlem geri alınamaz.';
  static const ekSilindi = 'Ek silindi.';
  static const ekIndirildi = 'Dosya indirildi.';
  static const ekIndirilemedi = 'Dosya indirilemedi. Tekrar deneyin.';
  static const ekHataAg =
      'Dosya yüklenemedi. Bağlantınızı kontrol edip tekrar deneyin.';
  static const ekHataSunucu = 'Dosya yüklenemedi. Lütfen tekrar deneyin.';
  static const ekHataBoyut = 'Dosya boyutu en fazla 10 MB olabilir.';
  static const ekHataFotoTur =
      'Yalnızca JPG, PNG, WEBP ve GIF dosyaları yükleyebilirsiniz.';
  static const ekHataDokTur =
      'Yalnızca PDF, Word (.docx) ve Excel (.xlsx) dosyaları yükleyebilirsiniz.';
  static const ekHataBicim =
      'Bu fotoğraf biçimi desteklenmiyor. JPG veya PNG olarak kaydedip '
      'tekrar deneyin.';
  static const ekKuyrukNotu = 'Dosyalar kayıt tamamlandığında yüklenecek.';
  static String ekKismiHata(int n) =>
      'Kayıt oluşturuldu, ancak $n dosya yüklenemedi. Tekrar deneyebilir veya '
      'bu sayfadan çıkabilirsiniz.';
  static const ekHataAdet = 'Bir kayda en fazla 20 dosya ekleyebilirsiniz.';
  static const ekHataBos = 'Dosya boş görünüyor. Başka bir dosya seçin.';
  static const ekFotografKaldirBaslik = 'Fotoğrafı kaldır';
  static const ekFotografKaldirGovde =
      'Bu fotoğraf silinecek. Devam edilsin mi?';

  // ---- 9.7 Boş durumlar ----
  static const bosKurul = 'Kurulda görevli bulunmuyor.';
  static const bosBolge = 'Seçilen duruma uyan bölge bulunmuyor.';
  static const bosKomisyon = 'Henüz komisyon tanımlanmamış.';
  static const bosIlBaskanlik = 'Seçilen duruma uyan il başkanlığı bulunmuyor.';
  static const bosIlceSecilmedi =
      'İlçe başkanlıklarını görmek için önce bir il seçin.';
  static const bosIlce = 'Bu ilde ilçe başkanlığı kaydı bulunmuyor.';
  static const bosTemsilcilik = 'Kayıtlı temsilcilik bulunmuyor.';
  static const bosGorevliler = 'Bu birimde görevli bulunmuyor.';
  static const bosAltBirim = 'Bu ile bağlı alt birim kaydı bulunmuyor.';
  static const bosGorevlendirme = 'Bu kişinin görevlendirmesi bulunmuyor.';
  static const bosGorev = 'Henüz görev kaydı yok.';
  static const bosEgitim = 'Henüz eğitim kaydı yok.';
  static const bosEtkinlik = 'Henüz etkinlik kaydı yok.';
  static const bosTakvim = 'Bu tür için takvimde etkinlik bulunmuyor.';
  static const bosTakvimAlt =
      'Etkinlik takvimi Yönetim Paneli → Tanımlar bölümünden yönetilir.';
  static const bosTakvimArama = 'Aramanızla eşleşen etkinlik bulunamadı.';
  static const bosToplanti = 'Henüz toplantı kaydı yok.';
  static const bosGelir = 'Henüz gelir getirici faaliyet kaydı yok.';
  static const bosTalep = 'Henüz malzeme talebi yok.';
  static const bosGonderi = 'Henüz gönderi kaydı yok.';
  static const bosStok = 'Stok kaydı bulunmuyor.';
  static const bosStokKritik = 'Kritik seviyenin altında ürün bulunmuyor.';
  static const bosStokHareket = 'Bu ürün için hareket kaydı bulunmuyor.';
  static const bosKullanici = 'Kayıtlı kullanıcı bulunamadı.';
  static const bosKullaniciArama = 'Aramanızla eşleşen kullanıcı bulunamadı.';
  static const bosTanim = 'Bu kategoride henüz tanım yok.';
  static const bosIcerik = 'Tanımlı içerik bulunmuyor.';
  static const bosListeAlt = 'İlk kaydı eklemek için + butonuna dokunun.';
  static const bosTablo = 'Gösterilecek veri bulunamadı.';

  // ---- 9.8 Başarı bildirimleri ----
  static const basariGorev = 'Görev kaydedildi.';
  static const basariEgitim = 'Eğitim kaydedildi.';
  static const basariEtkinlik = 'Etkinlik kaydedildi.';
  static const basariToplanti = 'Toplantı kaydedildi.';
  static const basariGelir = 'Gelir getirici faaliyet kaydedildi.';
  static const basariGorevlendirme = 'Görevlendirme kaydedildi.';
  static const basariTalep = 'Talep kaydedildi.';
  static const basariGonderi = 'Gönderi kaydedildi.';
  static const basariTeslim = 'Teslim bilgisi kaydedildi.';
  static const basariGonderiStok = 'Gönderi kaydedildi. Stok güncellendi.';
  static const basariKritikSeviye = 'Kritik seviye güncellendi.';
  static const basariSifreBelirle = 'Şifre güncellendi.';
  static const basariTanim = 'Tanım kaydedildi.';
  static const basariSiralama = 'Sıralama güncellendi.';
  static const basariKullanici = 'Kullanıcı kaydedildi.';
  static const basariYetki = 'Yetkiler güncellendi.';
  static const basariBildirimAyar = 'Bildirim ayarları kaydedildi.';
  static const basariAyarlar = 'Ayarlar kaydedildi.';
  static const basariFormAyar = 'Form ayarları kaydedildi.';
  static const basariIcerik = 'İçerik kaydedildi.';
  static const basariSifre = 'Şifreniz güncellendi.';
  static const basariTakipKopya = 'Takip numarası kopyalandı.';
  static const basariKisi = 'Kişi kaydedildi.';

  // ---- 9.9 Onay dialogları ----
  static const dlgDurumBaslik = 'Durumu değiştir';
  static String dlgDurumGovde(String birim, String durum) =>
      '$birim durumu "$durum" olarak güncellenecek. Onaylıyor musunuz?';
  static const dlgGoreviSonlandir = 'Görevi sonlandır';
  static const dlgGoreviSonlandirGovde = 'Görev bitiş tarihini seçin.';
  static const dlgGorevdenCikar = 'Görevden çıkar';
  static const dlgGorevdenCikarGovde =
      'Bu kişi listeden kaldırılacak. Devam edilsin mi?';
  static const dlgGorevSil = 'Görev kaydı silinsin mi?';
  static const dlgToplantiSil = 'Toplantı kaydı silinsin mi?';
  static const dlgGeriAlinamaz = 'Bu işlem geri alınamaz.';
  static const dlgTalepIptal = 'Talebi iptal et';
  static const dlgTalepIptalGovde =
      'Bu talep iptal edilecek. Devam edilsin mi?';
  static const dlgTalepSilinemez = 'Talep silinemiyor';
  static const dlgTalepSilinemezGovde =
      'Bu talebe bağlı gönderi kaydı olduğu için silinemez. '
      'Talebi iptal edebilirsiniz.';
  static const dlgSifreBelirle = 'Şifre belirle';
  static String dlgSifreBelirleGovde(String ad) =>
      '$ad için yeni bir şifre belirleyin.';
  static const dlgSonYonetici = 'İşlem yapılamıyor';
  static const dlgSonYoneticiGovde =
      'Sistemdeki son genel merkez hesabı pasif yapılamaz.';
  static const dlgTanimSilinemez = 'Tanım silinemiyor';
  static const dlgTanimSilinemezGovde =
      'Bu tanım kayıtlarda kullanıldığı için silinemez. Pasif yapabilirsiniz.';
  static const dlgGorevliKalmadi = 'Birimde görevli kalmadı';
  static const dlgGorevliKalmadiGovde =
      'Birim durumunu "Teşkilat Yok" olarak güncellemek ister misiniz?';
  static const evet = 'Evet';
  static const hayir = 'Hayır';

  // ---- 11.2 Hata kodu → metin ----
  static const hataHesapPasif =
      'Hesabınız pasif durumda. Genel merkez ile iletişime geçin.';
  static const hataBulunamadi = 'Kayıt bulunamadı. Silinmiş olabilir.';
  static const hataDogrulama =
      'Girdiğiniz bilgilerde hata var. Lütfen kontrol edin.';
  static const hataTcGecersiz = 'Geçersiz TC kimlik numarası.';

  // ---- Diğer ekran metinleri ----
  static const surum = 'Sürüm 2.0.0';
  static const kapsamUyari =
      'Kapsam bilgisi bu sürümde yalnız raporlama içindir; kullanıcının veri '
      'erişimini kısıtlamaz.';
  static const yetkiSabit =
      'Rol yetkileri bu sürümde sabittir ve yalnızca görüntülenebilir.';
  static const kapsamRaporlama =
      'Kapsam bilgisi raporlama içindir; veri erişimini kısıtlamaz.';
  static const bildirimDevreDisi =
      'Bildirim gönderimi bu sürümde devre dışıdır; ayarlar kaydedilir.';
  static const dosyaKisitSunucu =
      'Dosya kısıtları sunucu tarafından belirlenir.';
  static const formAyarNotu =
      'Değişiklikler kullanıcıların bir sonraki form açılışında geçerli olur.';
  static const tanimKullanilmiyor = 'Bu liste arayüzde kullanılmıyor.';
  static const tanimSilinemezIpucu =
      'Bu tanım kayıtlarda kullanıldığı için silinemez. Pasif yapabilirsiniz.';
  static const herUrunAyriTalep = 'Her ürün için ayrı talep oluşturulur.';
  static const acikTalepYok = 'Gönderilecek açık talep bulunmuyor.';
  static const yeniTalepOlustur = 'Yeni Talep Oluştur';
  static const teslimHelper =
      'Doldurulursa talep "Teslim Edildi" olarak işaretlenir.';
  static const kisiZatenGorevli = 'Bu kişi bu birimde zaten görevli.';
  static const epostaCakisma =
      'Bu e-posta adresi ile kayıtlı bir kullanıcı zaten var.';
  static const sifreGuvenliKanal =
      'Şifreyi kullanıcıya güvenli bir kanaldan iletin.';
  static const urunKirilimRapor =
      "Ürün kırılımı için Rapor Merkezi'ni kullanın.";
  static const etkinlikListesiGuncellendi =
      'Seçilen tarihe göre etkinlik listesi güncellendi.';
  static const bilgiMetniGoster = 'Bilgilendirme metnini göster';
  static const dahaFazlaGoster = 'Daha fazla göster';
  static const dahaAzGoster = 'Daha az göster';
  static const sistemAlanZorunlu = 'Bu alan sistem tarafından zorunlu tutulur.';

  // ---- Profil (E-80) ----
  static const profilBilgileri = 'Profil Bilgileri';
  static const profilTeskilat = 'Teşkilat Bilgileri';
  static const profilAdSoyad = 'Ad Soyad';
  static const profilEposta = 'E-posta';
  static const profilTelefon = 'Telefon';
  static const profilRol = 'Rol';
  static const profilBolge = 'Bölge';
  static const profilIl = 'İl';
  static const profilIlce = 'İlçe';
  static const profilTumBolgeler = 'Bölge seçilmedi';
  static const profilTumIller = 'İl seçilmedi';
  static const profilTumIlceler = 'İlçe seçilmedi';
  static const profilRolNotu =
      'Rolünüzü yalnızca genel merkez değiştirebilir.';
  static const profilTeskilatNotu =
      'Bölge → İl → İlçe sırasıyla seçilir; üsttekini değiştirdiğinizde '
      'alttakiler temizlenir.';
  static const profilKaydedildi = 'Profiliniz güncellendi.';
  static const profilYuklenemedi =
      'Profil bilgileri yüklenemedi. Tekrar deneyin.';
  static const profilUcYok =
      'Profil düzenleme sunucuda henüz etkin değil. Genel merkez ile '
      'iletişime geçin.';
  static const profilKapsamYok = 'Teşkilat bilgisi girilmemiş.';
  static String profilKapsam(String deger) => 'Kapsam: $deger';
  static const vTelefonGecersiz =
      'Geçerli bir telefon numarası girin (05XX XXX XX XX).';
  static const vEposta = 'Geçerli bir e-posta adresi girin.';
  static const vEpostaZorunlu = 'E-posta adresi gerekli.';

  // ---- Profil fotoğrafı ----
  static const avatarBaslik = 'Profil Fotoğrafı';
  static const avatarSec = 'Fotoğraf Seç';
  static const avatarDegistir = 'Fotoğrafı Değiştir';
  static const avatarKaldir = 'Fotoğrafı Kaldır';
  static const avatarKaldirBaslik = 'Fotoğrafı kaldır';
  static const avatarKaldirGovde =
      'Profil fotoğrafınız silinecek. Devam edilsin mi?';
  static const avatarYukleniyor = 'Fotoğraf yükleniyor...';
  static const avatarYuklendi = 'Profil fotoğrafı güncellendi.';
  static const avatarSilindi = 'Profil fotoğrafı kaldırıldı.';
  static const avatarHataBoyut = 'Fotoğraf boyutu en fazla 2 MB olabilir.';
  static const avatarHataTur =
      'Yalnızca JPG, PNG ve WEBP dosyaları yükleyebilirsiniz.';
  static const avatarHataBos = 'Dosya boş görünüyor. Başka bir dosya seçin.';
  static const avatarHataSunucu =
      'Fotoğraf yüklenemedi. Lütfen tekrar deneyin.';
  static const avatarUcYok =
      'Profil fotoğrafı sunucuda henüz etkin değil. Genel merkez ile '
      'iletişime geçin.';
  static const avatarYok = 'Fotoğraf eklenmemiş.';

  // ---- Şifre değiştirme (E-80 · API-V2 §1.8) ----
  static const sifreDegistir = 'Şifre Değiştir';
  static const sifreMevcut = 'Mevcut Şifre';
  static const sifreYeni = 'Yeni Şifre';
  static const sifreYeniTekrar = 'Yeni Şifre (Tekrar)';
  static const sifreKurali =
      'En az 8 karakter; en az bir harf ve bir rakam içermelidir.';
  static const vSifreHarfRakam =
      'Yeni şifre en az bir harf ve bir rakam içermelidir.';
  static const vSifreAyni = 'Yeni şifre mevcut şifreden farklı olmalıdır.';
  static const sifreDegistirmeZorunlu =
      'Devam etmek için şifrenizi değiştirmeniz gerekiyor.';
  static const sifreZorunluBaslik = 'Şifrenizi Değiştirin';
  static const sifreZorunluGovde =
      'Hesabınız ilk girişte şifre değişikliği gerektiriyor. Yeni şifrenizi '
      'belirlemeden diğer ekranlar açılmaz.';
}
