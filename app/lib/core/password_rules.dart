import 'strings_v2.dart';

/// Şifre değiştirme doğrulaması — sunucu kuralının istemci aynası.
///
/// API-V2 §11: `POST /auth/change-password` mevcut şifreyi **zorunlu** tutar,
/// yeni şifre en az 8 karakter olmalı ve en az bir harf + bir rakam içermeli,
/// ayrıca mevcut şifreyle aynı olamaz. Buradaki kurallar birebir aynıdır ki
/// kullanıcı ağ turu beklemeden hatayı görsün; sunucu yine son sözü söyler.
class PasswordRules {
  const PasswordRules._();

  static const minLength = 8;

  static const fieldCurrent = 'current_password';
  static const fieldNew = 'new_password';
  static const fieldRepeat = 'new_password_repeat';

  /// Türkçe harfler de harf sayılır (`Şifre1` geçerlidir).
  static final RegExp _letter = RegExp(r'[A-Za-zÇĞİıÖŞÜçğöşü]');
  static final RegExp _digit = RegExp(r'\d');

  static bool hasLetterAndDigit(String value) =>
      _letter.hasMatch(value) && _digit.hasMatch(value);

  /// Alan anahtarı → Türkçe hata metni. Boş harita = form geçerli.
  static Map<String, String> validate({
    required String current,
    required String next,
    required String repeat,
  }) {
    final errors = <String, String>{};
    if (current.isEmpty) errors[fieldCurrent] = S2.vMevcutSifre;

    if (next.length < minLength) {
      errors[fieldNew] = S2.vSifreYeniKisa;
    } else if (!hasLetterAndDigit(next)) {
      errors[fieldNew] = S2.vSifreHarfRakam;
    } else if (current.isNotEmpty && next == current) {
      errors[fieldNew] = S2.vSifreAyni;
    }

    // Tekrar alanı, yeni şifre kendi içinde geçerliyse anlamlıdır.
    if (!errors.containsKey(fieldNew) && repeat != next) {
      errors[fieldRepeat] = S2.vSifreEslesmiyor;
    }
    return errors;
  }

  static bool isValid({
    required String current,
    required String next,
    required String repeat,
  }) =>
      validate(current: current, next: next, repeat: repeat).isEmpty;
}
