import 'package:flutter_test/flutter_test.dart';
import 'package:teskilat_yonetim/core/status.dart';

/// Üç durumlu statü — docs/UX-V2.md §3.
class _Unit {
  const _Unit(this.name, this.status);
  final String name;
  final String status;
}

void main() {
  const units = [
    _Unit('Ankara İl Kadın Başkanlığı', 'aktif'),
    _Unit('İstanbul İl Kadın Başkanlığı', 'aktif'),
    _Unit('İzmir İl Kadın Başkanlığı', 'pasif'),
    _Unit('Ağrı İl Kadın Başkanlığı', 'teskilat_yok'),
    _Unit('Bitlis İl Kadın Başkanlığı', 'teskilat_yok'),
  ];

  group('§3.1 — durum eşlemesi ve görünüm', () {
    test('API değerleri üç duruma eşlenir', () {
      expect(orgStatusFromApi('aktif'), OrgStatus.aktif);
      expect(orgStatusFromApi('pasif'), OrgStatus.pasif);
      expect(orgStatusFromApi('teskilat_yok'), OrgStatus.teskilatYok);
    });

    test('bilinmeyen değer sessizce pasif sayılır', () {
      expect(orgStatusFromApi(null), OrgStatus.pasif);
      expect(orgStatusFromApi('bilinmeyen'), OrgStatus.pasif);
    });

    test('rozet metinleri kısaltılmaz', () {
      expect(OrgStatus.aktif.label, 'Aktif');
      expect(OrgStatus.pasif.label, 'Pasif');
      expect(OrgStatus.teskilatYok.label, 'Teşkilat Yok');
      expect(OrgStatus.teskilatYok.label, isNot(contains('Tşk.')));
    });

    test('§1.4 — her durumun ayırt edici ikonu vardır (renk tek başına yasak)',
        () {
      final icons = OrgStatus.values.map((s) => s.icon).toSet();
      expect(icons.length, 3);
    });

    test('§3.2 — Teşkilat Yok hata rengiyle gösterilmez', () {
      // kError = 0xFFC5221F; kWarning = 0xFFB26A00
      expect(OrgStatus.teskilatYok.foreground.toARGB32(), 0xFFB26A00);
    });

    test('§3.3b — teskilat_yok bir kişinin durumu olamaz', () {
      expect(OrgStatus.aktif.allowedForPerson, isTrue);
      expect(OrgStatus.pasif.allowedForPerson, isTrue);
      expect(OrgStatus.teskilatYok.allowedForPerson, isFalse);
    });
  });

  group('§3.3c — filtre çipleri ve süzme', () {
    test('birim listelerinde 4 çip, varsayılan Tümü', () {
      final f = StatusFilter.forOrgUnits();
      expect(f.value, isNull);
      expect(f.chips, [
        null,
        OrgStatus.aktif,
        OrgStatus.pasif,
        OrgStatus.teskilatYok,
      ]);
      expect(f.chips.map(StatusFilter.chipLabel).toList(),
          ['Tümü', 'Aktif', 'Pasif', 'Teşkilat Yok']);
    });

    test('kişi listelerinde 3 çip, varsayılan Aktif; Teşkilat Yok render edilmez',
        () {
      final f = StatusFilter.forPersons();
      expect(f.value, OrgStatus.aktif);
      expect(f.chips.contains(OrgStatus.teskilatYok), isFalse);
      expect(f.chips.length, 3);
    });

    test('kişi filtresinde teskilat_yok seçilemez', () {
      final f = StatusFilter.forPersons().select(OrgStatus.teskilatYok);
      expect(f.value, OrgStatus.aktif, reason: 'seçim yok sayılır');
    });

    test('Tümü tüm kayıtları geçirir', () {
      final f = StatusFilter.forOrgUnits();
      final result = f.apply(units, (u) => u.status).toList();
      expect(result.length, 5);
    });

    test('Aktif yalnız aktif birimleri geçirir', () {
      final f = StatusFilter.forOrgUnits().select(OrgStatus.aktif);
      final result = f.apply(units, (u) => u.status).toList();
      expect(result.map((u) => u.name),
          ['Ankara İl Kadın Başkanlığı', 'İstanbul İl Kadın Başkanlığı']);
    });

    test('Teşkilat Yok yalnız boşluk birimlerini geçirir', () {
      final f = StatusFilter.forOrgUnits().select(OrgStatus.teskilatYok);
      final result = f.apply(units, (u) => u.status).toList();
      expect(result.length, 2);
      expect(result.every((u) => u.status == 'teskilat_yok'), isTrue);
    });

    test('Pasif seçimi teskilat_yok kayıtlarını içermez', () {
      final f = StatusFilter.forOrgUnits().select(OrgStatus.pasif);
      final result = f.apply(units, (u) => u.status).toList();
      expect(result.single.name, 'İzmir İl Kadın Başkanlığı');
    });

    test('sorgu parametresi yalnız seçiliyken gönderilir', () {
      expect(StatusFilter.forOrgUnits().queryValue, isNull);
      expect(StatusFilter.forOrgUnits().select(OrgStatus.teskilatYok).queryValue,
          'teskilat_yok');
    });

    test('çip seçimi includeTeskilatYok bayrağını korur', () {
      final f = StatusFilter.forPersons().select(OrgStatus.pasif);
      expect(f.includeTeskilatYok, isFalse);
      expect(f.value, OrgStatus.pasif);
    });
  });

  group('§6.3 — talep ve gönderi durumları', () {
    test('talep durumları API değerleriyle birebir eşlenir', () {
      expect(RequestStatus.label('talep'), 'Talep Edildi');
      expect(RequestStatus.label('onaylandi'), 'Onaylandı');
      expect(RequestStatus.label('gonderildi'), 'Gönderildi');
      expect(RequestStatus.label('teslim_edildi'), 'Teslim Edildi');
      expect(RequestStatus.label('iptal'), 'İptal Edildi');
    });

    test('açık talep = talep + onaylandi', () {
      expect(RequestStatus.isOpen('talep'), isTrue);
      expect(RequestStatus.isOpen('onaylandi'), isTrue);
      expect(RequestStatus.isOpen('gonderildi'), isFalse);
      expect(RequestStatus.isOpen('iptal'), isFalse);
    });

    test('§10/24 — gönderi durumu received_date\'ten türetilir', () {
      expect(ShipmentStatus.label(null), 'Yolda');
      expect(ShipmentStatus.label(''), 'Yolda');
      expect(ShipmentStatus.label('2026-07-05'), 'Teslim Edildi');
      expect(ShipmentStatus.isDelivered('2026-07-05'), isTrue);
    });
  });
}
