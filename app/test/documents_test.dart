import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teskilat_yonetim/core/document_filter.dart';
import 'package:teskilat_yonetim/core/layout.dart';
import 'package:teskilat_yonetim/forms/field_spec.dart';
import 'package:teskilat_yonetim/forms/form_controller.dart';
import 'package:teskilat_yonetim/models/models.dart';
import 'package:teskilat_yonetim/models/models_v2.dart';
import 'package:teskilat_yonetim/screens/v2/documents/document_form_fields.dart';
import 'package:teskilat_yonetim/screens/v2/documents/document_widgets.dart';
import 'package:teskilat_yonetim/screens/v2/more_screen.dart';
import 'package:teskilat_yonetim/theme/app_theme.dart';

/// Modül 6 · Kılavuz ve Dokümanlar — SPEC-V2-M6 + API-V2 §19.

AppUser _user({
  String role = 'saha',
  int? regionId,
  int? provinceId,
  int? districtId,
}) =>
    AppUser(
      id: 2,
      name: 'Saha Kullanıcısı',
      email: 'saha@kizilay.org.tr',
      role: role,
      regionId: regionId,
      provinceId: provinceId,
      districtId: districtId,
    );

Map<String, dynamic> _docJson({
  int id = 1,
  String title = 'Gönüllü El Kitabı',
  String scope = 'genel',
  String scopeLabel = 'Genel',
  int isExpired = 0,
  int isActive = 1,
  int attachmentCount = 1,
  String? validUntil,
  String? version = 'v2.1',
  String? publishedAt = '2026-01-15',
}) =>
    {
      'id': id,
      'title': title,
      'description': 'Açıklama',
      'category_id': 145,
      'category_name': 'Kılavuzlar',
      'scope': scope,
      'scope_label': scopeLabel,
      'version': version,
      'published_at': publishedAt,
      'valid_until': validUntil,
      'is_expired': isExpired,
      'is_active': isActive,
      'download_count': 12,
      'attachment_count': attachmentCount,
    };

Widget _wrap(Widget child) => MaterialApp(
      theme: buildAppTheme(),
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    );

void main() {
  // -------------------------------------------------------------------------
  group('§19.4a — iki kapsam modu birbirini dışlar', () {
    test('varsayılan görünüm "bana uygulananlar" modunu kullanır', () {
      final p = const DocumentFilter()
          .params(_user(regionId: 3, provinceId: 6, districtId: 64));
      expect(p['applicable_to'], 'district:64');
      // Birebir eşleşme anahtarları HİÇ gönderilmez — birlikte 400 alınır.
      for (final k in DocumentFilter.exactGeoKeys) {
        expect(p.containsKey(k), isFalse, reason: k);
      }
      expect(DocumentFilter.hasConflict(p), isFalse);
    });

    test('"Yalnız bana ait olanlar" birebir eşleşmeye geçer', () {
      final p = const DocumentFilter(onlyMine: true)
          .params(_user(regionId: 3, provinceId: 6, districtId: 64));
      expect(p['district_id'], 64);
      expect(p.containsKey('applicable_to'), isFalse);
      expect(DocumentFilter.hasConflict(p), isFalse);
    });

    test('en dar düzey seçilir: ilçe > il > bölge', () {
      expect(
          const DocumentFilter().params(_user(regionId: 3, provinceId: 6))[
              'applicable_to'],
          'province:6');
      expect(const DocumentFilter().params(_user(regionId: 3))['applicable_to'],
          'region:3');
      expect(
          const DocumentFilter(onlyMine: true)
              .params(_user(regionId: 3, provinceId: 6))['province_id'],
          6);
      expect(
          const DocumentFilter(onlyMine: true)
              .params(_user(regionId: 3))['region_id'],
          3);
    });

    test('kırılımı olmayan hesapta hiçbir coğrafya parametresi gönderilmez',
        () {
      final user = _user(role: 'genel_merkez');
      final acik = const DocumentFilter().params(user);
      final dar = const DocumentFilter(onlyMine: true).params(user);
      expect(acik.containsKey('applicable_to'), isFalse);
      for (final k in DocumentFilter.exactGeoKeys) {
        expect(acik.containsKey(k), isFalse);
        expect(dar.containsKey(k), isFalse);
      }
    });

    test('kategori, kapsam çipi, arama ve is_active birlikte gider', () {
      final p = const DocumentFilter(
        categoryId: 145,
        scope: DocumentScope.il,
        query: '  izin  ',
        isActive: false,
      ).params(_user(provinceId: 6));
      expect(p['category_id'], 145);
      // `scope` çipi `applicable_to` ile çakışmaz; çakışan yalnız kimliklerdir.
      expect(p['scope'], 'il');
      expect(p['applicable_to'], 'province:6');
      expect(p['q'], 'izin');
      expect(p['is_active'], 0);
      expect(DocumentFilter.hasConflict(p), isFalse);
    });

    test('boş arama metni q parametresi üretmez', () {
      final p = const DocumentFilter(query: '   ').params(null);
      expect(p.containsKey('q'), isFalse);
    });

    test('iki mod el ile birleştirilirse çakışma yakalanır', () {
      expect(
        DocumentFilter.hasConflict(
            {'applicable_to': 'district:64', 'district_id': 64}),
        isTrue,
      );
    });
  });

  // -------------------------------------------------------------------------
  group('§5.2/4 — Kapsam koşullu görünürlüğü (R2)', () {
    FormController form() => FormController(
          fields: documentFormFields(
            regions: (_) async =>
                const [FormOption(value: 3, label: 'İç Anadolu')],
            provinces: (_) async => const [FormOption(value: 6, label: 'Ankara')],
            districts: (_) async =>
                const [FormOption(value: 64, label: 'Çankaya')],
          ),
          initialValues: const {'scope': DocumentScope.genel},
        );

    test('genel: Bölge/İl/İlçe alanlarının hiçbiri görünmez', () {
      final c = form();
      expect(c.isVisibleKey('region_id'), isFalse);
      expect(c.isVisibleKey('province_id'), isFalse);
      expect(c.isVisibleKey('district_id'), isFalse);
    });

    test('bolge: yalnız Bölge açılır', () {
      final c = form()..setValue('scope', DocumentScope.bolge);
      expect(c.isVisibleKey('region_id'), isTrue);
      expect(c.isVisibleKey('province_id'), isFalse);
      expect(c.isVisibleKey('district_id'), isFalse);
    });

    test('il: İl açılır, İlçe kapalı kalır', () {
      final c = form()..setValue('scope', DocumentScope.il);
      expect(c.isVisibleKey('region_id'), isFalse);
      expect(c.isVisibleKey('province_id'), isTrue);
      expect(c.isVisibleKey('district_id'), isFalse);
    });

    test('ilce: İl ve İlçe birlikte açılır, İlçe İl\'e kademelidir', () {
      final c = form()..setValue('scope', DocumentScope.ilce);
      expect(c.isVisibleKey('province_id'), isTrue);
      expect(c.isVisibleKey('district_id'), isTrue);
      final ilce = c.specFor('district_id')!;
      expect(c.isEnabled(ilce), isFalse); // R1.1 — önce İl
      c.setValue('province_id', 6);
      expect(c.isEnabled(ilce), isTrue);
    });

    test('görünen kapsam alanı zorunludur, gizli alan doğrulanmaz (R3)', () {
      final c = form()..setValue('scope', DocumentScope.il);
      c.setValue('title', 'Etkinlik İzin Belgesi');
      c.setValue('category_id', 145);
      expect(c.validateAll(), 'province_id');
      c.setValue('province_id', 6);
      expect(c.validateAll(), isNull); // İlçe gizli → doğrulanmaz
    });

    test('kapsam daraltılıp genişletilince gövde eski coğrafyayı taşımaz', () {
      final c = form()
        ..setValue('title', 'Aile Yılı Bilgi Notu')
        ..setValue('category_id', 145)
        ..setValue('scope', DocumentScope.ilce)
        ..setValue('province_id', 6)
        ..setValue('district_id', 64);
      var body = c.buildBody();
      expect(body['scope'], 'ilce');
      expect(body['province_id'], 6);
      expect(body['district_id'], 64);

      c.setValue('scope', DocumentScope.genel);
      body = c.buildBody();
      // R2.2 — gizli alanlar açıkça null gider; sunucu eskisini temizler.
      expect(body['scope'], 'genel');
      expect(body.containsKey('region_id'), isTrue);
      expect(body['region_id'], isNull);
      expect(body['province_id'], isNull);
      expect(body['district_id'], isNull);
    });

    test('kapsam seçenekleri sözleşmedeki dört değerdir', () {
      expect(kDocumentScopeOptions.map((o) => o.value).toList(),
          DocumentScope.all);
      expect(kDocumentScopeOptions.map((o) => o.effectiveCode).toList(),
          ['genel', 'bolge', 'il', 'ilce']);
      expect(kDocumentScopeOptions.map((o) => o.label).toList(),
          ['Genel', 'Bölge', 'İl', 'İlçe']);
    });
  });

  // -------------------------------------------------------------------------
  group('§19.2/§19.5 — sunucudan gelen alanlar yeniden hesaplanmaz', () {
    test('is_expired, scope_label ve attachment_count ayrışır', () {
      final d = DocumentRecord.fromJson(_docJson(
        scope: 'il',
        scopeLabel: 'Ankara',
        isExpired: 1,
        validUntil: '2026-06-30',
        attachmentCount: 2,
      ));
      expect(d.scopeLabel, 'Ankara');
      expect(d.isExpired, isTrue);
      expect(d.attachmentCount, 2);
      expect(d.isActive, isTrue);
    });

    test('yayından kaldırılmış kayıt is_active=0 ile gelir', () {
      final d = DocumentRecord.fromJson(_docJson(isActive: 0));
      expect(d.isActive, isFalse);
    });

    test('valid_until dolu ama sunucu is_expired=0 dediyse rozet çıkmaz', () {
      // Tarih karşılaştırması istemcide TEKRARLANMAZ (§19.5): sunucunun
      // `date('now')` değeri tek doğrudur.
      final d =
          DocumentRecord.fromJson(_docJson(validUntil: '2020-01-01'));
      expect(d.isExpired, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  group('§5.2/2 — doküman kartı', () {
    testWidgets('süresi dolan belgede "Süresi doldu" rozeti çıkar',
        (tester) async {
      await tester.pumpWidget(_wrap(DocumentCard(
        document: DocumentRecord.fromJson(_docJson(
          title: 'Etkinlik İzin Belgesi Şablonu',
          scope: 'il',
          scopeLabel: 'Ankara',
          isExpired: 1,
          validUntil: '2026-06-30',
          version: '2026 Revizyon',
        )),
      )));
      expect(find.text('Etkinlik İzin Belgesi Şablonu'), findsOneWidget);
      expect(find.text('Süresi doldu'), findsOneWidget);
      expect(find.text('Ankara'), findsOneWidget); // kapsam rozeti
      expect(find.textContaining('2026 Revizyon'), findsOneWidget);
    });

    testWidgets('süresi dolmayan belgede rozet yoktur', (tester) async {
      await tester.pumpWidget(_wrap(DocumentCard(
        document: DocumentRecord.fromJson(_docJson()),
      )));
      expect(find.text('Süresi doldu'), findsNothing);
      expect(find.text('Genel'), findsOneWidget);
      expect(find.text('Yayında değil'), findsNothing);
    });

    testWidgets('yayından kaldırılmış belge genel merkeze işaretlenir',
        (tester) async {
      await tester.pumpWidget(_wrap(DocumentCard(
        document: DocumentRecord.fromJson(_docJson(isActive: 0)),
      )));
      expect(find.text('Yayında değil'), findsOneWidget);
    });

    testWidgets('dosya türü ikonu ve boyutu ek listesinden gelir',
        (tester) async {
      final files = DocumentFiles.groupBy([
        Attachment.fromJson(const {
          'id': 1,
          'entity': 'documents',
          'entity_id': 1,
          'kind': 'dokuman',
          'file_name': 'el-kitabi.pdf',
          'mime': 'application/pdf',
          'size': 184320,
        }),
      ]);
      await tester.pumpWidget(_wrap(DocumentCard(
        document: DocumentRecord.fromJson(_docJson()),
        files: files[1],
      )));
      expect(find.textContaining('PDF'), findsOneWidget);
      expect(find.textContaining('180 KB'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
    });

    test('dosya türü, ad ve MIME üzerinden ayrışır', () {
      expect(FileTypeVisual.of('a.pdf').label, 'PDF');
      expect(FileTypeVisual.of('a.docx').label, 'Word');
      expect(FileTypeVisual.of('a.xlsx').label, 'Excel');
      expect(FileTypeVisual.of('a.png').label, 'Görsel');
      expect(FileTypeVisual.of('a.bin').label, 'Dosya');
      expect(FileTypeVisual.of('ek', 'application/pdf').label, 'PDF');
    });
  });

  // -------------------------------------------------------------------------
  group('§5.1 — Daha Fazla yerleşimi', () {
    testWidgets('genel merkez: Kılavuz ve Dokümanlar Daha Fazla altındadır',
        (tester) async {
      AppDestination? opened;
      await tester.pumpWidget(_wrap(
        MoreScreen(role: 'genel_merkez', onOpen: (d) => opened = d),
      ));
      expect(find.text('Kılavuz ve Dokümanlar'), findsOneWidget);
      expect(find.text('Yönetim Paneli'), findsOneWidget);
      expect(find.text('Profil'), findsOneWidget);

      await tester.tap(find.text('Kılavuz ve Dokümanlar'));
      await tester.pumpAndSettle();
      expect(opened, AppDestination.dokuman);
    });

    testWidgets('saha: Daha Fazla listesi boştur (hepsi sekmedir)',
        (tester) async {
      await tester.pumpWidget(_wrap(
        MoreScreen(role: 'saha', onOpen: (_) {}),
      ));
      expect(find.text('Kılavuz ve Dokümanlar'), findsNothing);
      expect(find.text('Yönetim Paneli'), findsNothing);
    });
  });
}
