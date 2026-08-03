@Tags(['live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teskilat_yonetim/core/api.dart';
import 'package:teskilat_yonetim/core/api_client.dart';
import 'package:teskilat_yonetim/core/api_v2.dart';
import 'package:teskilat_yonetim/core/document_filter.dart';
import 'package:teskilat_yonetim/core/lookup_cache.dart';
import 'package:teskilat_yonetim/core/status.dart';
import 'package:teskilat_yonetim/forms/dynamic_form.dart';
import 'package:teskilat_yonetim/forms/field_spec.dart';
import 'package:teskilat_yonetim/forms/form_controller.dart';
import 'package:teskilat_yonetim/models/models.dart';
import 'package:teskilat_yonetim/models/models_v2.dart';
import 'package:teskilat_yonetim/screens/v2/documents/document_widgets.dart';
import 'package:teskilat_yonetim/screens/v2/shared.dart';
import 'package:teskilat_yonetim/theme/app_theme.dart';

/// Canlı arka uca (localhost:4141) karşı bütünleşme sınaması.
///
/// Üretim kod yollarını (ApiV2 · LookupCache · FormController · gerçek ekran
/// widget'ları) gerçek sunucu verisiyle çalıştırır.
/// Çalıştırma: `flutter test test/live_backend_test.dart`
/// Arka uç kapalıysa testler atlanır.
void main() {
  const base = 'http://localhost:4141/api/v1';
  late ApiClient client;
  late Api api;
  late ApiV2 api2;
  late LookupCache cache;
  var backendUp = false;

  setUpAll(() async {
    // flutter_test varsayılan olarak tüm HTTP isteklerini 400 ile keser;
    // canlı arka uca bağlanabilmek için gerçek HttpClient geri alınır.
    HttpOverrides.global = null;
    await initializeDateFormatting('tr_TR');
    SharedPreferences.setMockInitialValues({});
    client = ApiClient(baseUrl: base);
    api = Api(client);
    api2 = ApiV2(client);
    cache = LookupCache(api2);
    try {
      final socket = await Socket.connect('localhost', 4141,
          timeout: const Duration(seconds: 2));
      socket.destroy();
      backendUp = true;
    } catch (_) {
      backendUp = false;
    }
    if (backendUp) {
      final (token, _) = await api.login('admin@kizilay.org.tr', 'Admin!2026');
      client.token = token;
    }
  });

  /// `pumpAndSettle` yerine sınırlı pump: dinamik formun 150 ms geçiş
  /// animasyonları ve yükleme göstergeleri sürekli kare ürettiği için
  /// sonsuz beklemeyi önler.
  Future<void> settle(WidgetTester tester, {int frames = 20}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  void skipIfDown() {
    if (!backendUp) markTestSkipped('Arka uç çalışmıyor (localhost:4141)');
  }

  test('giriş: JWT alınır ve sonraki isteklerde kullanılır', () async {
    skipIfDown();
    if (!backendUp) return;
    expect(client.token, isNotNull);
    expect(client.token!.length, greaterThan(20));
  }, skip: false);

  test('dashboard: summary · timeseries · provinces modelleri ayrışır',
      () async {
    skipIfDown();
    if (!backendUp) return;

    final summary = await api2.dashboardSummary(activityType: 'gorev');
    expect(summary.orgTotal, greaterThan(0));
    expect(summary.orgAktif + summary.orgPasif + summary.orgTeskilatYok,
        summary.orgTotal);

    final series = await api2.dashboardTimeseries(
        metric: 'gorev', interval: 'month');
    expect(series, isNotNull, reason: 'uç mevcut olmalı');
    expect(series!.length, 12, reason: 'son 12 ay sıfırla doldurulur');
    expect(series.first.shortMonthLabel.length, greaterThan(2));

    final provinces = await api2.dashboardProvinces();
    expect(provinces, isNotNull);
    expect(provinces!.length, 81);
    expect(provinces.first.provinceName, isNotEmpty);
    expect(provinces.first.total, greaterThan(0));
  });

  test('teşkilat birimi listesi ve üç durumlu filtre canlı veride çalışır',
      () async {
    skipIfDown();
    if (!backendUp) return;

    final page = await api2.orgUnits(
        type: OrgUnitType.ilBaskanligi, limit: 100);
    expect(page.total, 81);

    final gap = StatusFilter.forOrgUnits().select(OrgStatus.teskilatYok);
    final gaps = gap.apply(page.data, (u) => u.status).toList();
    final active = StatusFilter.forOrgUnits()
        .select(OrgStatus.aktif)
        .apply(page.data, (u) => u.status)
        .toList();
    expect(gaps.length + active.length, lessThanOrEqualTo(page.data.length));
    expect(gaps.every((u) => u.status == 'teskilat_yok'), isTrue);

    // Sunucu tarafı filtre ile istemci tarafı süzme aynı sonucu vermeli.
    final serverSide = await api2
        .orgUnits(type: OrgUnitType.ilBaskanligi, statuses: ['teskilat_yok']);
    expect(serverSide.total, gaps.length);
  });

  test('bilgilendirme metni (content_blocks) canlı olarak okunur', () async {
    skipIfDown();
    if (!backendUp) return;
    final block = await api2.contentBlock('teskilatlanma.il_baskanliklari');
    expect(block.title, isNotEmpty);
    expect(block.isEmpty, isFalse);
  });

  test('Tanımlar CRUD: yeni tanım kod değişikliği olmadan forma düşer',
      () async {
    skipIfDown();
    if (!backendUp) return;

    final before = await cache.items('gorev_turu');
    final beforeCount = before.length;

    await api2.createLookupItem({
      'category_code': 'gorev_turu',
      'name': 'Canlı Test Görevi',
      'code': 'canli_test_gorevi',
    });
    cache.invalidate('gorev_turu');

    final after = await cache.items('gorev_turu');
    expect(after.length, beforeCount + 1);
    final created = after.firstWhere((i) => i.code == 'canli_test_gorevi');
    expect(created.name, 'Canlı Test Görevi');

    // Pasif yapılan tanım yeni formlarda görünmez.
    await api2.setLookupItemActive(created.id, false);
    cache.invalidate('gorev_turu');
    final activeOnly = await cache.items('gorev_turu');
    expect(activeOnly.any((i) => i.id == created.id), isFalse);

    await api2.deleteLookupItem(created.id);
    cache.invalidate('gorev_turu');
    final restored = await cache.items('gorev_turu');
    expect(restored.length, beforeCount);
  });

  test('canlı lookup verisinde kod boş gelse de dal kodu türetilir', () async {
    skipIfDown();
    if (!backendUp) return;
    final methods = await api2.lookups('toplanti_yontemi');
    expect(methods.length, 2);
    final codes = methods
        .map((m) => FormOption(value: m.id, label: m.name, code: m.code)
            .effectiveCode)
        .toList();
    expect(codes, containsAll(['yuz_yuze', 'cevrim_ici']));

    final platforms = await api2.lookups('toplanti_platformu');
    expect(platforms.map((p) => p.name), contains('Diğer'));
    final other = platforms.firstWhere((p) => p.name == 'Diğer');
    expect(
        FormOption(value: other.id, label: other.name, code: other.code)
            .effectiveCode,
        'diger');
  });

  testWidgets(
      'E-49 Toplantı Formu: Yüz Yüze → Toplantı Yeri, Çevrim İçi → Platform',
      (tester) async {
    skipIfDown();
    if (!backendUp) return;

    // testWidgets sahte zaman kullanır; gerçek HTTP yalnız runAsync içinde
    // ilerler. Lookup'lar önceden ısıtılır, form önbellekten okur.
    late List<LookupItem> methods;
    late List<LookupItem> platforms;
    await tester.runAsync(() async {
      methods = await cache.items('toplanti_yontemi');
      platforms = await cache.items('toplanti_platformu');
    });
    final faceToFace = methods.firstWhere((m) =>
        FormOption(value: m.id, label: m.name, code: m.code).effectiveCode ==
        'yuz_yuze');
    final online = methods.firstWhere((m) =>
        FormOption(value: m.id, label: m.name, code: m.code).effectiveCode ==
        'cevrim_ici');
    final other = platforms.firstWhere((p) => p.name == 'Diğer');

    // E-49'un canlı veriyle kurulan gerçek alan tanımları (§4.3c).
    final controller = FormController(
      lookupResolver: lookupResolverFor(cache),
      fields: const [
        FieldSpec(
          key: 'method_id',
          label: 'Toplantı Yöntemi',
          type: FieldType.lookup,
          lookupCategory: 'toplanti_yontemi',
          required: true,
        ),
        FieldSpec(
          key: 'location',
          label: 'Toplantı Yeri',
          type: FieldType.text,
          required: true,
          visibleWhen: VisibleWhen.code('method_id', 'yuz_yuze'),
          omitWhenHidden: true,
        ),
        FieldSpec(
          key: 'platform_id',
          label: 'Platform',
          type: FieldType.lookup,
          lookupCategory: 'toplanti_platformu',
          required: true,
          visibleWhen: VisibleWhen.code('method_id', 'cevrim_ici'),
          omitWhenHidden: true,
        ),
        FieldSpec(
          key: 'platform_name',
          label: 'Platform Adı',
          type: FieldType.text,
          required: true,
          visibleWhen: VisibleWhen.code('platform_id', 'diger'),
        ),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: SingleChildScrollView(child: DynamicForm(controller: controller)),
      ),
    ));
    await settle(tester);

    // 1) Yöntem boşken iki dal da DOM'da yok (R2.1).
    expect(find.text('Toplantı Yöntemi'), findsOneWidget);
    expect(find.text('Toplantı Yeri'), findsNothing);
    expect(find.text('Platform'), findsNothing);
    expect(controller.buildBody().containsKey('location'), isFalse);
    expect(controller.buildBody().containsKey('platform_id'), isFalse);

    // 2) Yüz Yüze → Toplantı Yeri görünür, Platform gizli.
    controller.setValue('method_id', faceToFace.id);
    await settle(tester);
    expect(find.text('Toplantı Yeri'), findsOneWidget);
    expect(find.text('Platform'), findsNothing);
    expect(controller.buildBody().containsKey('platform_id'), isFalse,
        reason: 'uymayan dal anahtarı gövdeye konmaz (sunucu 400 döner)');

    // 3) Çevrim İçi → alanlar yer değiştirir.
    controller.setValue('method_id', online.id);
    await tester.runAsync(() => controller.loadOptions(
        controller.specFor('platform_id')!, force: true));
    await settle(tester);
    expect(find.text('Platform'), findsOneWidget);
    expect(find.text('Toplantı Yeri'), findsNothing);
    expect(controller.buildBody().containsKey('location'), isFalse);

    // 4) Platform = Diğer → zincirli koşullu alan açılır (R2.6).
    controller.setValue('platform_id', other.id);
    await settle(tester);
    expect(find.text('Platform Adı'), findsOneWidget);
  });

  test('toplantı kaydı: iki dal da sunucuya doğru gövdeyle gider', () async {
    skipIfDown();
    if (!backendUp) return;

    final methods = await api2.lookups('toplanti_yontemi');
    final faceToFace = methods.firstWhere((m) =>
        FormOption(value: m.id, label: m.name, code: m.code).effectiveCode ==
        'yuz_yuze');
    final online = methods.firstWhere((m) =>
        FormOption(value: m.id, label: m.name, code: m.code).effectiveCode ==
        'cevrim_ici');

    // Yüz Yüze: `platform` anahtarı gövdeye HİÇ konmaz.
    final id1 = await api2.createMeeting({
      'meeting_date': '2026-07-25',
      'method_id': faceToFace.id,
      'location': 'Canlı Test Salonu',
      'agenda': 'Bütünleşme sınaması',
      'decision': 'Kaydedildi',
      'participant_count': 5,
    });
    expect(id1, greaterThan(0));

    // Çevrim İçi: `location` anahtarı gövdeye HİÇ konmaz.
    final id2 = await api2.createMeeting({
      'meeting_date': '2026-07-26',
      'method_id': online.id,
      'platform': 'Zoom',
      'agenda': 'Çevrim içi sınama',
      'decision': 'Kaydedildi',
      'participant_count': 9,
    });
    expect(id2, greaterThan(0));

    final page = await api2.meetings(limit: 200);
    final m1 = page.data.firstWhere((m) => m.id == id1);
    final m2 = page.data.firstWhere((m) => m.id == id2);
    expect(m1.location, 'Canlı Test Salonu');
    expect(m1.platform, isNull);
    expect(m1.participantCount, 5);
    expect(m2.platform, 'Zoom');
    expect(m2.location, isNull);
    expect(m2.isOnline, isTrue);

    await api2.deleteMeeting(id1);
    await api2.deleteMeeting(id2);
  });

  // -------------------------------------------------------------------------
  // Modül 6 · Kılavuz ve Dokümanlar — SPEC-V2-M6, API-V2 §19
  // -------------------------------------------------------------------------

  /// Demo tohumundaki Çankaya (Ankara) — `applicable_to` sınamasının çapası.
  Future<int> cankayaId() async {
    final provinces = await cache.provinces();
    final ankara = provinces.firstWhere((p) => p.name == 'Ankara');
    final districts = await cache.districts(ankara.id);
    return districts.firstWhere((d) => d.name == 'Çankaya').id;
  }

  test('§19.4a — "bana uygulananlar" en dardan en genişe kapsar', () async {
    skipIfDown();
    if (!backendUp) return;
    final district = await cankayaId();

    final inclusive = await api2.documents(
        const DocumentFilter().params(_scopedUser(districtId: district)));
    // İlçe + il + genel: dört kırılımın tamamı tek istekte gelir.
    expect(inclusive.data.length, greaterThanOrEqualTo(4));
    expect(inclusive.data.map((d) => d.scope).toList().sublist(0, 3),
        ['ilce', 'il', 'genel']);
    expect(inclusive.data.first.scopeLabel, 'Çankaya');
    expect(inclusive.data.map((d) => d.scopeLabel), contains('Ankara'));
    expect(inclusive.data.map((d) => d.scopeLabel), contains('Genel'));
  });

  test('§19.4a — "Yalnız bana ait olanlar" birebir eşleşmeye daralır',
      () async {
    skipIfDown();
    if (!backendUp) return;
    final district = await cankayaId();

    final exact = await api2.documents(const DocumentFilter(onlyMine: true)
        .params(_scopedUser(districtId: district)));
    expect(exact.data.length, 1);
    expect(exact.data.single.scope, 'ilce');
    expect(exact.data.single.scopeLabel, 'Çankaya');
    // Ülke geneli belgeler bu modda görünmez — anahtarın amacı budur.
    expect(exact.data.any((d) => d.scope == 'genel'), isFalse);
  });

  test('§19.4a — iki mod aynı istekte gönderilemez (sunucuya gitmez)',
      () async {
    skipIfDown();
    if (!backendUp) return;
    final district = await cankayaId();
    expect(
      () => api2.documents({
        'applicable_to': 'district:$district',
        'district_id': district,
      }),
      throwsArgumentError,
    );
  });

  test('§19.2 — süresi dolmuş belge sunucuda işaretlenir', () async {
    skipIfDown();
    if (!backendUp) return;
    final page = await api2.documents(const {});
    final expired = page.data.where((d) => d.isExpired).toList();
    expect(expired, isNotEmpty,
        reason: 'demo tohumunda süresi geçmiş bir izin belgesi vardır');
    expect(expired.first.validUntil, isNotNull);
    expect(expired.first.scopeLabel, isNotEmpty);
  });

  testWidgets('E-61 kartı canlı veriyle kapsam ve süre rozetlerini basar',
      (tester) async {
    skipIfDown();
    if (!backendUp) return;
    // testWidgets sahte zaman kullanır; gerçek HTTP yalnız runAsync içinde
    // ilerler (yukarıdaki E-49 sınamasının aynısı).
    late DocumentRecord expired;
    await tester.runAsync(() async {
      final page = await api2.documents(const {});
      expired = page.data.firstWhere((d) => d.isExpired);
    });

    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: DocumentCard(document: expired)),
    ));
    await settle(tester, frames: 3);

    expect(find.text(expired.title), findsOneWidget);
    expect(find.text('Süresi doldu'), findsOneWidget);
    expect(find.text(expired.scopeLabel), findsOneWidget);
  });

  test('§19.4 — indirme: önce sayaç, sonra dosya', () async {
    skipIfDown();
    if (!backendUp) return;
    final page = await api2.documents(const {});
    final doc = page.data.first;

    // Tohumda doküman eki yok; indirme yolu gerçek bir dosyayla sınanır.
    // Tür `Content-Type` başlığından okunur — uzantı tek başına yetmez.
    final bytes = utf8.encode('%PDF-1.4\n% canlı sınama\n%%EOF\n');
    final uploaded = await api2.uploadAttachment(
      entity: 'documents',
      entityId: doc.id,
      kind: 'dokuman',
      fileName: 'canli-sinama.pdf',
      bytes: bytes,
    );
    expect(uploaded.mime, 'application/pdf');
    expect(uploaded.id, greaterThan(0));

    final before = (await api2.document(doc.id)).downloadCount;
    final attachments = await api2.registerDocumentDownload(doc.id);
    expect(attachments.map((a) => a.id), contains(uploaded.id));
    expect((await api2.document(doc.id)).downloadCount, before + 1);

    final downloaded = await api2.downloadAttachment(uploaded.id);
    expect(downloaded.length, bytes.length);
    expect(downloaded.toList(), bytes);

    // Ek listesi tek istekte gruplanabilir (liste ekranında N+1 yok).
    final all = await api2.attachments(entity: 'documents');
    expect(DocumentFiles.groupBy(all)[doc.id]!.items.map((a) => a.id),
        contains(uploaded.id));

    await api2.deleteAttachment(uploaded.id);
  });

  test('§19.4 — yayından kaldırma kaydı silmez, geri alınabilir', () async {
    skipIfDown();
    if (!backendUp) return;
    final categories = await cache.items('dokuman_kategorisi');
    final id = await api2.createDocument({
      'title': 'Canlı Sınama Belgesi',
      'category_id': categories.first.id,
      'scope': 'genel',
      'version': 'v0',
    });

    await api2.setDocumentActive(id, false);
    expect((await api2.document(id)).isActive, isFalse);
    await api2.setDocumentActive(id, true);
    expect((await api2.document(id)).isActive, isTrue);

    await api2.deleteDocument(id);
  });

  test('§19.4 — arama Türkçe büyük/küçük harf duyarsızdır', () async {
    skipIfDown();
    if (!backendUp) return;
    final lower = await api2.documents(
        const DocumentFilter(query: 'gönüllü').params(null));
    final upper = await api2.documents(
        const DocumentFilter(query: 'GÖNÜLLÜ').params(null));
    expect(lower.total, greaterThan(0));
    expect(upper.total, lower.total);
  });
}

/// Kapsamı verilen kullanıcı — filtre üretimini canlı veriyle sınamak için.
///
/// Tohumdaki hesaplarda `province_id` boştur; iki modu ayırt etmek için
/// kırılım burada açıkça kurulur.
AppUser _scopedUser({int? regionId, int? provinceId, int? districtId}) =>
    AppUser(
      id: 1,
      name: 'Genel Merkez Admin',
      email: 'admin@kizilay.org.tr',
      role: 'genel_merkez',
      regionId: regionId,
      provinceId: provinceId,
      districtId: districtId,
    );
