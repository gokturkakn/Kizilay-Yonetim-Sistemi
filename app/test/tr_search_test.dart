import 'package:flutter_test/flutter_test.dart';
import 'package:teskilat_yonetim/core/formatters.dart';

void main() {
  group('Türkçe arama (il listesi filtresi)', () {
    test('İstanbul, noktasız "istan" ile bulunur', () {
      expect(Formats.trContains('İstanbul', 'istan'), isTrue);
      expect(Formats.trContains('İstanbul', 'İSTAN'), isTrue);
    });

    test('Isparta ve İstanbul birbirine karışmaz', () {
      expect(Formats.trContains('Isparta', 'ıspa'), isTrue);
      expect(Formats.trContains('İstanbul', 'ıspa'), isFalse);
    });

    test('Şanlıurfa, Ağrı, Düzce kısmi sorgularla bulunur', () {
      expect(Formats.trContains('Şanlıurfa', 'şanlı'), isTrue);
      expect(Formats.trContains('Ağrı', 'ağr'), isTrue);
      expect(Formats.trContains('Düzce', 'düz'), isTrue);
    });

    test('eşleşmeyen sorgu false döner', () {
      expect(Formats.trContains('Adana', 'zzz'), isFalse);
    });
  });
}
