/// Yerel form doğrulama kuralları — docs/UX.md §3.1, §3.9.
class Validators {
  Validators._();

  static final RegExp _digits11 = RegExp(r'^\d{11}$');
  static final RegExp _email =
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  /// TC kimlik numarası checksum doğrulaması (standart algoritma).
  ///
  /// - İlk hane 0 olamaz.
  /// - 10. hane = ((1,3,5,7,9. haneler toplamı × 7) − (2,4,6,8. haneler
  ///   toplamı)) mod 10
  /// - 11. hane = ilk 10 hane toplamı mod 10
  static bool isValidTcChecksum(String tc) {
    if (!_digits11.hasMatch(tc)) return false;
    if (tc.startsWith('0')) return false;
    final d = tc.split('').map(int.parse).toList();
    final oddSum = d[0] + d[2] + d[4] + d[6] + d[8];
    final evenSum = d[1] + d[3] + d[5] + d[7];
    final digit10 = ((oddSum * 7) - evenSum) % 10;
    if (d[9] != digit10) return false;
    final digit11 =
        d.sublist(0, 10).reduce((a, b) => a + b) % 10;
    return d[10] == digit11;
  }

  /// TC kimlik alanı doğrulaması; hata mesajları UX.md §3.9'dan aynen.
  static String? tcNo(String? value) {
    final v = (value ?? '').replaceAll(RegExp(r'\s'), '');
    if (v.isEmpty) return 'TC kimlik numarası gerekli.';
    if (!_digits11.hasMatch(v)) {
      return 'TC kimlik numarası 11 haneli olmalıdır.';
    }
    if (!isValidTcChecksum(v)) return 'Geçersiz TC kimlik numarası.';
    return null;
  }

  /// Telefon: yalnız rakam saklanır; 11 hane ve `05` ile başlamalı.
  static String? phone(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Telefon numarası gerekli.';
    if (digits.length != 11 || !digits.startsWith('05')) {
      return 'Geçerli bir telefon numarası girin (05XX XXX XX XX).';
    }
    return null;
  }

  /// E-posta biçim kontrolü (zorunluluk çağıran tarafta ele alınır).
  static bool isValidEmail(String value) => _email.hasMatch(value.trim());

  /// Giriş ekranı e-posta alanı.
  static String? loginEmail(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'E-posta adresi gerekli.';
    if (!isValidEmail(v)) return 'Geçerli bir e-posta adresi girin.';
    return null;
  }

  /// Giriş ekranı şifre alanı.
  static String? loginPassword(String? value) {
    if (value == null || value.isEmpty) return 'Şifre gerekli.';
    return null;
  }

  /// Kişi formu opsiyonel e-posta alanı.
  static String? optionalEmail(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return null;
    if (!isValidEmail(v)) return 'Geçerli bir e-posta adresi girin.';
    return null;
  }

  /// Zorunlu metin alanı.
  static String? required(String? value, String message) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  /// Pozitif sayı alanı (görev formu sayaçları).
  static String? positiveCount(String? value, String emptyMessage) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return emptyMessage;
    final n = int.tryParse(v);
    if (n == null) return 'Geçerli bir sayı girin.';
    if (n < 0) return emptyMessage;
    return null;
  }
}
