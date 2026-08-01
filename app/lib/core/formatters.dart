import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Biçimler — docs/UX.md §4.4.
class Formats {
  Formats._();

  static final DateFormat _date = DateFormat('dd.MM.yyyy', 'tr_TR');
  static final DateFormat _dateTime = DateFormat('dd.MM.yyyy HH:mm', 'tr_TR');
  static final DateFormat _api = DateFormat('yyyy-MM-dd');

  /// Ekran gösterimi: `dd.MM.yyyy`.
  static String date(DateTime d) => _date.format(d);

  /// Ekran gösterimi: `dd.MM.yyyy HH:mm`.
  static String dateTime(DateTime d) => _dateTime.format(d);

  /// API biçimi: `YYYY-MM-DD`.
  static String apiDate(DateTime d) => _api.format(d);

  /// API'den gelen tarih dizesini ayrıştırır; başarısızsa null.
  static DateTime? parseApiDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  /// API tarih dizesi → `dd.MM.yyyy`; ayrıştırılamazsa ham değer.
  static String dateFromApi(String? raw) {
    final d = parseApiDate(raw);
    return d == null ? (raw ?? '—') : date(d);
  }

  /// API tarih-saat dizesi → `dd.MM.yyyy HH:mm`.
  static String dateTimeFromApi(String? raw) {
    final d = parseApiDate(raw);
    return d == null ? (raw ?? '—') : dateTime(d.toLocal());
  }

  /// Saklanan `05XXXXXXXXX` → gösterim `0XXX XXX XX XX`.
  static String phone(String stored) {
    final digits = stored.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 11) return stored;
    return '${digits.substring(0, 4)} ${digits.substring(4, 7)} '
        '${digits.substring(7, 9)} ${digits.substring(9, 11)}';
  }

  /// Girdiden yalnız rakamları ayıklar (telefon saklama biçimi).
  static String phoneDigits(String input) =>
      input.replaceAll(RegExp(r'\D'), '');

  /// Türkçe duyarlı küçük harfe çevirme (İ→i, I→ı) — §4.4 TR arama.
  static String trLower(String s) =>
      s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();

  /// TR duyarsız arama eşleşmesi.
  static bool trContains(String haystack, String needle) =>
      trLower(haystack).contains(trLower(needle));

  /// Ad soyaddan baş harfler (avatar için).
  static String initials(String first, String last) {
    final f = first.trim().isEmpty ? '' : first.trim()[0];
    final l = last.trim().isEmpty ? '' : last.trim()[0];
    return '$f$l'.toUpperCase();
  }
}

/// Telefon giriş maskesi: `0(5XX) XXX XX XX` — docs/UX.md §3.9.
class TrPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 11) digits = digits.substring(0, 11);
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 1) buf.write('(');
      if (i == 4) buf.write(') ');
      if (i == 7 || i == 9) buf.write(' ');
      buf.write(digits[i]);
    }
    final text = buf.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
