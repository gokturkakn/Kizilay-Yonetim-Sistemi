/// Ortak sözlük — docs/UX.md §4.6. Metinler aynen kopyalanmıştır.
class Str {
  Str._();

  // ortak.*
  static const kaydet = 'Kaydet';
  static const vazgec = 'Vazgeç';
  static const sil = 'Sil';
  static const tamam = 'Tamam';
  static const tekrarDene = 'Tekrar Dene';
  static const ara = 'Ara...';
  static const tumu = 'Tümü';
  static const aktif = 'Aktif';
  static const pasif = 'Pasif';
  static const secilmedi = 'Seçilmedi';
  static const bos = '—';
  static const uygula = 'Uygula';
  static const temizle = 'Temizle';
  static const onayla = 'Onayla';
  static const cikar = 'Çıkar';
  static const cikisYap = 'Çıkış Yap';

  // durum.*
  static const atandi = 'Atandı';
  static const devam = 'Devam Ediyor';
  static const tamamlandi = 'Tamamlandı';

  // birim.*
  static const birimIl = 'İl Teşkilatı';
  static const birimIlce = 'İlçe Teşkilatı';
  static const birimTemsilcilik = 'Temsilcilik';

  // hata.*
  static const hataGenel = 'Bir şeyler ters gitti.';
  static const hataAg = 'Sunucuya ulaşılamadı. Bağlantınızı kontrol edin.';
  static const hataYetki = 'Bu işlem için yetkiniz yok.';
  static const hataOturum = 'Oturum süreniz doldu. Lütfen tekrar giriş yapın.';

  /// API durum değeri → ekran metni (§4.6 durum eşlemesi).
  static String assignmentStatusLabel(String status) {
    switch (status) {
      case 'atandi':
        return atandi;
      case 'devam':
        return devam;
      case 'tamamlandi':
        return tamamlandi;
      default:
        return status;
    }
  }

  /// unit_type → ekran metni.
  static String unitTypeLabel(String unitType) {
    switch (unitType) {
      case 'il_teskilati':
        return birimIl;
      case 'ilce_teskilati':
        return birimIlce;
      case 'temsilcilik':
        return birimTemsilcilik;
      default:
        return unitType;
    }
  }
}
