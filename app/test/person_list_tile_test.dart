import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teskilat_yonetim/models/models.dart';
import 'package:teskilat_yonetim/theme/app_theme.dart';
import 'package:teskilat_yonetim/widgets/person_list_tile.dart';

Person _person({bool isActive = true, String unitType = 'ilce_teskilati'}) =>
    Person(
      id: 1,
      firstName: 'Ayşe',
      lastName: 'Yılmaz',
      tcNo: '10000000146',
      birthDate: '1985-04-12',
      phone: '05321234567',
      unitType: unitType,
      provinceId: 6,
      districtId: 100,
      isActive: isActive,
    );

Widget _wrap(Widget child) => MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('aktif kişi kartı: ad, konum, Aktif rozeti ve baş harfler',
      (tester) async {
    await tester.pumpWidget(_wrap(PersonListTile(
      person: _person(),
      locationLabel: 'Ankara / Çankaya',
    )));

    expect(find.text('Ayşe Yılmaz'), findsOneWidget);
    expect(find.text('Ankara / Çankaya'), findsOneWidget);
    expect(find.text('Aktif'), findsOneWidget);
    expect(find.text('Pasif'), findsNothing);
    expect(find.text('AY'), findsOneWidget); // avatar baş harfleri
  });

  testWidgets('pasif kişi kartında Pasif rozeti görünür', (tester) async {
    await tester.pumpWidget(_wrap(PersonListTile(
      person: _person(isActive: false),
      locationLabel: 'Ankara / Çankaya',
    )));

    expect(find.text('Pasif'), findsOneWidget);
    expect(find.text('Aktif'), findsNothing);
  });

  testWidgets('temsilcilik rozeti konum satırının yerine geçer',
      (tester) async {
    await tester.pumpWidget(_wrap(PersonListTile(
      person: _person(unitType: 'temsilcilik'),
      locationLabel: 'Ankara — Temsilcilik',
      showRepresentationBadge: true,
    )));

    expect(find.text('Temsilcilik'), findsOneWidget);
    expect(find.text('Ankara — Temsilcilik'), findsNothing);
  });
}
