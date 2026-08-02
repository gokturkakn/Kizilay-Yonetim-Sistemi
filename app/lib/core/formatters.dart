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

  // ---- v2 eklemeleri — docs/UX-V2.md §4.4 ----

  static final NumberFormat _int = NumberFormat.decimalPattern('tr_TR');

  /// Binlik ayraçlı tam sayı (`1.284`) — v2 ölçeği büyüktür.
  static String number(num? value) =>
      value == null ? '—' : _int.format(value);

  /// Ondalık saat → Türkçe virgüllü gösterim (`2.5` → `2,5`).
  static String hours(num? value) {
    if (value == null) return '—';
    final s = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
    return s.replaceAll('.', ',');
  }

  /// Dosya boyutu (`184320` → `180,0 KB`).
  static String fileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${hours(double.parse(kb.toStringAsFixed(1)))} KB';
    final mb = kb / 1024;
    return '${hours(double.parse(mb.toStringAsFixed(1)))} MB';
  }

  /// Dosya adı 40 karakteri aşarsa **ortadan** kısaltılır (§7.2);
  /// uzantı görünür kalır.
  static String truncateFileName(String name, {int max = 40}) {
    if (name.length <= max) return name;
    final dot = name.lastIndexOf('.');
    final ext = dot > 0 ? name.substring(dot) : '';
    final base = dot > 0 ? name.substring(0, dot) : name;
    final keep = max - ext.length - 1;
    if (keep <= 4) return '${name.substring(0, max - 1)}…';
    final head = (keep * 0.7).floor();
    final tail = keep - head;
    return '${base.substring(0, head)}…${base.substring(base.length - tail)}$ext';
  }

  static const List<String> monthNames = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];

  /// `23 Nisan` biçimi (takvim etkinlikleri — §4.3e).
  static String dayMonth(int? month, int? day) {
    if (month == null || day == null || month < 1 || month > 12) return '';
    return '$day ${monthNames[month - 1]}';
  }

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
