import 'package:flutter_test/flutter_test.dart';
import 'package:teskilat_yonetim/core/formatters.dart';
import 'package:teskilat_yonetim/core/validators.dart';

void main() {
  group('TC kimlik doğrulama', () {
    test('geçerli TC numaraları kabul edilir', () {
      expect(Validators.isValidTcChecksum('10000000146'), isTrue);
      expect(Validators.tcNo('10000000146'), isNull);
    });

    test('boş / eksik hane / rakam dışı doğru mesajları verir', () {
      expect(Validators.tcNo(''), 'TC kimlik numarası gerekli.');
      expect(Validators.tcNo(null), 'TC kimlik numarası gerekli.');
      expect(
          Validators.tcNo('12345'), 'TC kimlik numarası 11 haneli olmalıdır.');
      expect(Validators.tcNo('1234567890a'),
          'TC kimlik numarası 11 haneli olmalıdır.');
    });

    test('checksum geçmeyen numara reddedilir', () {
      // Son hane bozuk.
      expect(Validators.tcNo('10000000147'), 'Geçersiz TC kimlik numarası.');
      // 10. hane bozuk.
      expect(Validators.tcNo('10000000156'), 'Geçersiz TC kimlik numarası.');
      // İlk hane 0 olamaz.
      expect(Validators.tcNo('01000000146'), 'Geçersiz TC kimlik numarası.');
    });
  });

  group('Telefon doğrulama ve biçimleme', () {
    test('geçerli telefon: 11 hane, 05 ile başlar', () {
      expect(Validators.phone('0(532) 123 45 67'), isNull);
      expect(Validators.phone('05321234567'), isNull);
    });

    test('boş ve biçim hatası mesajları', () {
      expect(Validators.phone(''), 'Telefon numarası gerekli.');
      expect(Validators.phone('0212 123 45 67'),
          'Geçerli bir telefon numarası girin (05XX XXX XX XX).');
      expect(Validators.phone('0532 123'),
          'Geçerli bir telefon numarası girin (05XX XXX XX XX).');
    });

    test('gösterim biçimi 0XXX XXX XX XX', () {
      expect(Formats.phone('05321234567'), '0532 123 45 67');
    });
  });

  group('TR duyarsız arama', () {
    test('İ/i ve I/ı dönüşümleri doğru yapılır', () {
      expect(Formats.trLower('İSTANBUL'), 'istanbul');
      expect(Formats.trLower('IĞDIR'), 'ığdır');
      expect(Formats.trContains('İstanbul', 'ist'), isTrue);
      expect(Formats.trContains('Iğdır', 'ığ'), isTrue);
      expect(Formats.trContains('Ankara', 'izmir'), isFalse);
    });
  });
}
