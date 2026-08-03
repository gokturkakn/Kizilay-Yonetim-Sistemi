import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teskilat_yonetim/core/api.dart';
import 'package:teskilat_yonetim/core/api_client.dart';
import 'package:teskilat_yonetim/core/api_v2.dart';
import 'package:teskilat_yonetim/core/filepick/file_pick.dart';
import 'package:teskilat_yonetim/core/lookup_cache.dart';
import 'package:teskilat_yonetim/core/password_rules.dart';
import 'package:teskilat_yonetim/core/ref_data.dart';
import 'package:teskilat_yonetim/core/session.dart';
import 'package:teskilat_yonetim/core/strings_v2.dart';
import 'package:teskilat_yonetim/forms/field_spec.dart';
import 'package:teskilat_yonetim/forms/form_controller.dart';
import 'package:teskilat_yonetim/main.dart';
import 'package:teskilat_yonetim/models/models_v2.dart';
import 'package:teskilat_yonetim/screens/profile/password_change_screen.dart';
import 'package:teskilat_yonetim/screens/profile/profile_form.dart';
import 'package:teskilat_yonetim/screens/profile/profile_screen.dart';
import 'package:teskilat_yonetim/screens/v2/admin/user_list_screen.dart';
import 'package:teskilat_yonetim/theme/app_theme.dart';
import 'package:teskilat_yonetim/widgets/user_avatar.dart';

/// Profil öz servisi — UX-V2 §6.6 (E-80) + API-V2 §1.8/§11.

// ---------------------------------------------------------------------------
// Sahte veri ve yardımcılar
// ---------------------------------------------------------------------------

const _regions = [
  FormOption(value: 1, label: 'İç Anadolu'),
  FormOption(value: 2, label: 'Marmara'),
];

const _provinces = {
  1: [FormOption(value: 6, label: 'Ankara'), FormOption(value: 68, label: 'Aksaray')],
  2: [FormOption(value: 34, label: 'İstanbul')],
};

const _districts = {
  6: [FormOption(value: 601, label: 'Çankaya'), FormOption(value: 602, label: 'Keçiören')],
  34: [FormOption(value: 341, label: 'Kadıköy')],
};

int? _asInt(Object? v) => v is int ? v : int.tryParse(v?.toString() ?? '');

/// 1×1 saydam PNG — gerçek bir görsel çözücüden geçer.
final Uint8List _pngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

FormController _profileController({
  Map<String, Object?> initialValues = const {},
}) =>
    FormController(
      initialValues: initialValues,
      fields: profileFieldSpecs(
        regions: (_) async => _regions,
        provinces: (values) async =>
            _provinces[_asInt(values[ProfileFields.regionId])] ?? const [],
        districts: (values) async =>
            _districts[_asInt(values[ProfileFields.provinceId])] ?? const [],
      ),
    );

FieldSpec _spec(FormController c, String key) => c.specFor(key)!;

Map<String, dynamic> _meJson({
  String name = 'Ayşe Yılmaz',
  String role = 'saha',
  String? phone = '05321234567',
  int? regionId = 1,
  int? provinceId = 6,
  int? districtId,
  Map<String, dynamic>? avatar,
  int mustChangePassword = 0,
}) =>
    {
      'id': 7,
      'name': name,
      'email': 'ayse@kizilay.org.tr',
      'role': role,
      'phone': phone,
      'region_id': regionId,
      'province_id': provinceId,
      'district_id': districtId,
      'region_name': 'İç Anadolu',
      'province_name': 'Ankara',
      'is_active': 1,
      'must_change_password': mustChangePassword,
      'avatar': avatar,
    };

http.Response _json(Object body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

http.Response _error(int status, String code, String message) => http.Response(
      jsonEncode({
        'error': {'code': code, 'message': message}
      }),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// Profil ekranını gerçek `ApiV2` + sahte HTTP ile kurar.
class _Harness {
  _Harness({required this.handler, this.user}) {
    client = ApiClient(client: MockClient(handler), baseUrl: 'http://x/api/v1');
    client.token = 'test-token';
    api = Api(client);
    api2 = ApiV2(client);
    cache = LookupCache(api2);
    session = Session(api);
  }

  final Future<http.Response> Function(http.Request) handler;
  late final ApiClient client;
  late final Api api;
  late final ApiV2 api2;
  late final LookupCache cache;
  late final Session session;
  Map<String, dynamic>? user;

  Future<void> restore() async {
    SharedPreferences.setMockInitialValues({
      if (user != null) 'auth_token': 'test-token',
      if (user != null) 'auth_user': jsonEncode(user),
    });
    await session.restore();
  }

  Widget wrap(Widget child) => MultiProvider(
        providers: [
          Provider<Api>.value(value: api),
          Provider<ApiV2>.value(value: api2),
          ChangeNotifierProvider<LookupCache>.value(value: cache),
          Provider<RefData>(create: (_) => RefData(api)),
          ChangeNotifierProvider<Session>.value(value: session),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          locale: const Locale('tr'),
          supportedLocales: const [Locale('tr')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: child,
        ),
      );
}

/// Standart profil senaryosunun HTTP yanıtları.
Future<http.Response> Function(http.Request) _defaultHandler({
  List<http.Request>? log,
  Map<String, dynamic>? me,
  http.Response? patchResponse,
}) {
  return (request) async {
    log?.add(request);
    final path = request.url.path;
    if (path.endsWith('/auth/me') && request.method == 'GET') {
      return _json(me ?? _meJson());
    }
    if (path.endsWith('/auth/me') && request.method == 'PATCH') {
      return patchResponse ??
          _json({...(me ?? _meJson()), ...jsonDecode(request.body) as Map});
    }
    if (path.endsWith('/regions')) {
      return _json({
        'data': [
          {'id': 1, 'code': 1, 'name': 'İç Anadolu'},
          {'id': 2, 'code': 2, 'name': 'Marmara'},
        ]
      });
    }
    if (path.endsWith('/provinces')) {
      final region = _asInt(request.url.queryParameters['region_id']);
      return _json({
        'data': [
          if (region == null || region == 1)
            {'id': 6, 'code': 6, 'name': 'Ankara', 'region_id': 1},
          if (region == null || region == 2)
            {'id': 34, 'code': 34, 'name': 'İstanbul', 'region_id': 2},
        ]
      });
    }
    if (path.contains('/districts')) {
      return _json({
        'data': [
          {'id': 601, 'name': 'Çankaya', 'province_id': 6},
        ]
      });
    }
    return _json({'data': <Object>[]});
  };
}

/// Profil uzun bir formdur: varsayılan 800×600 yüzeyde alanların bir kısmı
/// görüntü dışında kalır ve `tap()` ıskalar. Testler uzun bir yüzey kullanır
/// (genişlik 840'ın altında tutulur ki tek panelli düzen korunsun).
void _tallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Kilit kalkınca açılan iskeleti dar (alt çubuklu) düzende sınar: gezinme
/// kartı ızgarası orta genişlikte iki sütuna düşer ve bu testin konusuyla
/// ilgisiz taşma uyarıları üretir.
void _compactSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // -------------------------------------------------------------------------
  group('Teşkilat kademeli seçimi (§4.2 R1)', () {
    test('Bölge boşken İl, İl boşken İlçe devre dışıdır', () {
      final c = _profileController();
      expect(c.isEnabled(_spec(c, ProfileFields.provinceId)), isFalse);
      expect(c.disabledHint(_spec(c, ProfileFields.provinceId)),
          'Önce ${S2.profilBolge} seçin.');
      expect(c.isEnabled(_spec(c, ProfileFields.districtId)), isFalse);
      expect(c.disabledHint(_spec(c, ProfileFields.districtId)),
          'Önce ${S2.profilIl} seçin.');
    });

    test('İl listesi seçilen bölgeye göre daralır', () async {
      final c = _profileController();
      c.setValue(ProfileFields.regionId, 1);
      await c.loadOptions(_spec(c, ProfileFields.provinceId), force: true);
      expect(c.optionsFor(ProfileFields.provinceId).options.map((o) => o.label),
          ['Ankara', 'Aksaray']);

      c.setValue(ProfileFields.regionId, 2);
      await c.loadOptions(_spec(c, ProfileFields.provinceId), force: true);
      expect(c.optionsFor(ProfileFields.provinceId).options.map((o) => o.label),
          ['İstanbul']);
    });

    test('İlçe listesi seçilen ile göre daralır', () async {
      final c = _profileController();
      c.setValue(ProfileFields.regionId, 1);
      c.setValue(ProfileFields.provinceId, 6);
      await c.loadOptions(_spec(c, ProfileFields.districtId), force: true);
      expect(c.optionsFor(ProfileFields.districtId).options.map((o) => o.label),
          ['Çankaya', 'Keçiören']);
    });

    test('Bölge değişince İl ve İlçe koşulsuz temizlenir', () {
      final c = _profileController(initialValues: {
        ProfileFields.regionId: 1,
        ProfileFields.provinceId: 6,
        ProfileFields.districtId: 601,
      });
      c.setValue(ProfileFields.regionId, 2);
      expect(c.value(ProfileFields.provinceId), isNull);
      expect(c.value(ProfileFields.districtId), isNull);
    });

    test('İl değişince yalnız İlçe temizlenir, Bölge korunur', () {
      final c = _profileController(initialValues: {
        ProfileFields.regionId: 1,
        ProfileFields.provinceId: 6,
        ProfileFields.districtId: 601,
      });
      c.setValue(ProfileFields.provinceId, 68);
      expect(c.value(ProfileFields.regionId), 1);
      expect(c.value(ProfileFields.provinceId), 68);
      expect(c.value(ProfileFields.districtId), isNull);
    });

    test('teşkilat boş bırakılabilir — zorunlu alan değildir', () {
      final c = _profileController(initialValues: {
        ProfileFields.name: 'Ayşe Yılmaz',
        ProfileFields.email: 'ayse@kizilay.org.tr',
      });
      expect(c.validateAll(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  group('PATCH /auth/me gövdesi', () {
    test('yalnız ad, e-posta, telefon ve teşkilat alanlarını taşır', () {
      final c = _profileController(initialValues: {
        ProfileFields.name: 'Ayşe Yılmaz',
        ProfileFields.email: 'Ayse@Kizilay.org.tr',
        ProfileFields.phone: '05321234567',
        ProfileFields.roleLabel: 'Genel Merkez',
        ProfileFields.regionId: 1,
        ProfileFields.provinceId: 6,
        ProfileFields.districtId: 601,
      });
      final body = profileUpdateBody(c);
      expect(body.keys.toSet(), ProfileFields.bodyKeys.toSet());
      expect(body['email'], 'ayse@kizilay.org.tr'); // küçük harfe indirilir
      expect(body['district_id'], 601);
    });

    test('role / is_active / must_change_password gövdeye asla girmez', () {
      final c = _profileController(initialValues: {
        ProfileFields.name: 'Ayşe Yılmaz',
        ProfileFields.roleLabel: 'Genel Merkez',
      });
      final body = profileUpdateBody(c);
      expect(body.containsKey('role'), isFalse);
      expect(body.containsKey('is_active'), isFalse);
      expect(body.containsKey('must_change_password'), isFalse);
      expect(profileBodyIsSafe(body), isTrue);
    });

    test('boş telefon null gider (alan temizlenebilir)', () {
      final c = _profileController(initialValues: {
        ProfileFields.name: 'Ayşe Yılmaz',
        ProfileFields.phone: '   ',
      });
      expect(profileUpdateBody(c)['phone'], isNull);
    });

    test('ApiV2.updateMe yasaklı alan görürse istek göndermez', () async {
      var called = false;
      final api = ApiV2(ApiClient(
        client: MockClient((_) async {
          called = true;
          return _json({});
        }),
        baseUrl: 'http://x/api/v1',
      ));
      expect(
        () => api.updateMe({'name': 'X', 'role': 'genel_merkez'}),
        throwsArgumentError,
      );
      expect(
        () => api.updateMe({'name': 'X', 'is_active': false}),
        throwsArgumentError,
      );
      await Future<void>.delayed(Duration.zero);
      expect(called, isFalse);
    });

    test('ApiV2.updateMe izinli gövdeyi PATCH ile yollar', () async {
      http.Request? sent;
      final api = ApiV2(ApiClient(
        client: MockClient((r) async {
          sent = r;
          return _json(_meJson(name: 'Yeni Ad'));
        }),
        baseUrl: 'http://x/api/v1',
      ));
      final result = await api.updateMe({
        'name': 'Yeni Ad',
        'email': 'ayse@kizilay.org.tr',
        'phone': null,
        'region_id': 1,
        'province_id': 6,
        'district_id': null,
      });
      expect(sent!.method, 'PATCH');
      expect(sent!.url.path, '/api/v1/auth/me');
      final body = jsonDecode(sent!.body) as Map<String, dynamic>;
      expect(body.keys.any(ApiV2.selfForbiddenKeys.contains), isFalse);
      expect(result.name, 'Yeni Ad');
    });
  });

  // -------------------------------------------------------------------------
  group('Şifre doğrulaması (API-V2 §11 aynası)', () {
    test('mevcut şifre zorunludur', () {
      final e = PasswordRules.validate(
          current: '', next: 'Sifre123', repeat: 'Sifre123');
      expect(e[PasswordRules.fieldCurrent], S2.vMevcutSifre);
    });

    test('yeni şifre 8 karakterden kısa olamaz', () {
      final e = PasswordRules.validate(
          current: 'Eski123', next: 'Kisa1', repeat: 'Kisa1');
      expect(e[PasswordRules.fieldNew], S2.vSifreYeniKisa);
    });

    test('yeni şifre harf ve rakam içermelidir', () {
      expect(
        PasswordRules.validate(
            current: 'Eski1234',
            next: 'sadeceharf',
            repeat: 'sadeceharf')[PasswordRules.fieldNew],
        S2.vSifreHarfRakam,
      );
      expect(
        PasswordRules.validate(
            current: 'Eski1234',
            next: '12345678',
            repeat: '12345678')[PasswordRules.fieldNew],
        S2.vSifreHarfRakam,
      );
    });

    test('Türkçe harf de harf sayılır', () {
      expect(PasswordRules.hasLetterAndDigit('şifreÇĞ1'), isTrue);
    });

    test('yeni şifre mevcut şifreyle aynı olamaz', () {
      final e = PasswordRules.validate(
          current: 'Sifre123', next: 'Sifre123', repeat: 'Sifre123');
      expect(e[PasswordRules.fieldNew], S2.vSifreAyni);
    });

    test('tekrar alanı eşleşmezse hata verir', () {
      final e = PasswordRules.validate(
          current: 'Eski1234', next: 'Sifre123', repeat: 'Sifre124');
      expect(e[PasswordRules.fieldRepeat], S2.vSifreEslesmiyor);
    });

    test('geçerli girdi hata üretmez', () {
      expect(
          PasswordRules.isValid(
              current: 'Eski1234', next: 'Sifre123', repeat: 'Sifre123'),
          isTrue);
    });

    testWidgets('form hatalı girdide Türkçe mesajları gösterir',
        (tester) async {
      final h = _Harness(handler: _defaultHandler());
      await h.restore();
      await tester.pumpWidget(h.wrap(const PasswordChangeScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(1), 'kisa');
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      expect(find.text(S2.vMevcutSifre), findsOneWidget);
      expect(find.text(S2.vSifreYeniKisa), findsOneWidget);
    });

    testWidgets('sunucu 401 verirse mevcut şifre alanı hatalanır',
        (tester) async {
      final h = _Harness(handler: (request) async {
        if (request.url.path.endsWith('/auth/change-password')) {
          return _error(401, 'UNAUTHORIZED', 'Mevcut şifre hatalı');
        }
        return _json({});
      });
      await h.restore();
      await tester.pumpWidget(h.wrap(const PasswordChangeScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'YanlisEski1');
      await tester.enterText(find.byType(TextField).at(1), 'Sifre1234');
      await tester.enterText(find.byType(TextField).at(2), 'Sifre1234');
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      expect(find.text(S2.vMevcutSifreHatali), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  group('must_change_password akışı (API-V2 §1.8)', () {
    testWidgets('bayrak açıkken uygulama şifre formunda kalır',
        (tester) async {
      _tallSurface(tester);
      final h = _Harness(
        handler: _defaultHandler(),
        user: {
          'id': 7,
          'name': 'Ayşe Yılmaz',
          'email': 'ayse@kizilay.org.tr',
          'role': 'saha',
          'must_change_password': true,
        },
      );
      await h.restore();
      expect(h.session.mustChangePassword, isTrue);

      await tester.pumpWidget(TeskilatApp(
        api: h.api,
        apiV2: h.api2,
        lookupCache: h.cache,
        session: h.session,
      ));
      await tester.pumpAndSettle();

      expect(find.text(S2.sifreZorunluBaslik), findsOneWidget);
      expect(find.text(S2.sifreZorunluGovde), findsOneWidget);
      // Kilit ekranında tek çıkış yolu şifre değiştirmek ya da çıkış yapmaktır.
      expect(find.text('Vazgeç'), findsNothing);
      expect(find.text('Çıkış Yap'), findsOneWidget);
    });

    testWidgets('şifre değişince kilit kalkar ve iskelet açılır',
        (tester) async {
      _compactSurface(tester);
      final h = _Harness(
        handler: (request) async {
          if (request.url.path.endsWith('/auth/change-password')) {
            return _json({'ok': true});
          }
          return _defaultHandler()(request);
        },
        user: {
          'id': 7,
          'name': 'Ayşe Yılmaz',
          'email': 'ayse@kizilay.org.tr',
          'role': 'saha',
          'must_change_password': true,
        },
      );
      await h.restore();
      await tester.pumpWidget(TeskilatApp(
        api: h.api,
        apiV2: h.api2,
        lookupCache: h.cache,
        session: h.session,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'Eski1234');
      await tester.enterText(find.byType(TextField).at(1), 'Sifre1234');
      await tester.enterText(find.byType(TextField).at(2), 'Sifre1234');
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      expect(h.session.mustChangePassword, isFalse);
      expect(find.text(S2.sifreZorunluBaslik), findsNothing);
    });

    test('403 PASSWORD_CHANGE_REQUIRED oturumu global olarak kilitler',
        () async {
      final h = _Harness(
        handler: (_) async => _error(403, 'PASSWORD_CHANGE_REQUIRED',
            'Bu hesap için şifre değişikliği zorunludur.'),
        user: {
          'id': 7,
          'name': 'Ayşe',
          'email': 'a@b.c',
          'role': 'saha',
          'must_change_password': false,
        },
      );
      await h.restore();
      expect(h.session.mustChangePassword, isFalse);

      await expectLater(h.api2.users(), throwsA(isA<ApiException>()));
      // Herhangi bir uçtan gelen 403 kullanıcıyı şifre formuna yönlendirir.
      expect(h.session.mustChangePassword, isTrue);
    });

    test('hata kodu Türkçe metne çevrilir', () {
      final message = v2ErrorMessage(const ApiException(
          403, 'PASSWORD_CHANGE_REQUIRED', 'ingilizce olmayan sunucu metni'));
      expect(message, S2.sifreDegistirmeZorunlu);
    });
  });

  // -------------------------------------------------------------------------
  group('Profil fotoğrafı', () {
    test('avatar nesnesi JSON\'dan okunur, yoksa null kalır', () {
      final withAvatar = UserAccount.fromJson(_meJson(avatar: {
        'attachment_id': 12,
        'url': '/attachments/12/download',
        'mime': 'image/png',
        'size': 4096,
      }));
      expect(withAvatar.avatar!.attachmentId, 12);
      expect(withAvatar.avatar!.url, '/attachments/12/download');
      expect(UserAccount.fromJson(_meJson()).avatar, isNull);
    });

    test('yerel doğrulama: boyut, tür ve boş dosya', () {
      PickedFile file(String name, int size) => PickedFile(
            name: name,
            bytes: Uint8List(size),
            mime: '',
          );
      expect(avatarPickError(file('a.png', 0)), S2.avatarHataBos);
      expect(avatarPickError(file('a.png', Avatar.maxBytes + 1)),
          S2.avatarHataBoyut);
      expect(avatarPickError(file('a.gif', 100)), S2.avatarHataTur);
      expect(avatarPickError(file('a.pdf', 100)), S2.avatarHataTur);
      expect(avatarPickError(file('a.png', 100)), isNull);
      expect(avatarPickError(file('a.JPG', 100)), isNull);
    });

    test('göreli ve mutlak adresler doğru çözülür', () {
      final client = ApiClient(baseUrl: 'http://localhost:4141/api/v1');
      expect(client.resolveUrl('https://cdn/x.png').toString(),
          'https://cdn/x.png');
      expect(client.resolveUrl('/attachments/9/download').toString(),
          'http://localhost:4141/api/v1/attachments/9/download');
      expect(client.resolveUrl('/api/v1/attachments/9/download').toString(),
          'http://localhost:4141/api/v1/attachments/9/download');
    });

    test('baytlar önbelleğe alınır — aynı adres bir kez indirilir', () async {
      var hits = 0;
      final api = ApiV2(ApiClient(
        client: MockClient((_) async {
          hits++;
          return http.Response.bytes([1, 2, 3], 200);
        }),
        baseUrl: 'http://x/api/v1',
      ));
      await api.avatarBytes('/attachments/1/download');
      await api.avatarBytes('/attachments/1/download');
      expect(hits, 1);
      api.clearAvatarCache();
      await api.avatarBytes('/attachments/1/download');
      expect(hits, 2);
    });

    test('baş harfler addan türetilir', () {
      // İlk iki kelimenin baş harfi (v1 davranışı korunur).
      expect(UserAvatar.initialsOf('Ayşe Nur Yılmaz'), 'AN');
      expect(UserAvatar.initialsOf('Fatma Demir'), 'FD');
      expect(UserAvatar.initialsOf('ayşe'), 'A');
      expect(UserAvatar.initialsOf('   '), '?');
    });

    testWidgets('fotoğraf yoksa baş harf dairesi çizilir', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: UserAvatar(name: 'Ayşe Yılmaz')),
      ));
      await tester.pumpAndSettle();
      expect(find.text('AY'), findsOneWidget);
    });

    testWidgets('fotoğraf varsa görsel çizilir, baş harf gizlenir',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: UserAvatar(
            name: 'Ayşe Yılmaz',
            avatar: const Avatar(attachmentId: 1, url: '/a.png'),
            loader: (_) async => _pngBytes,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('AY'), findsNothing);
      expect(find.byType(CircleAvatar), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  group('Profil ekranı', () {
    testWidgets('kendi bilgilerini düzenlenebilir alanlarda gösterir',
        (tester) async {
      _tallSurface(tester);
      final h = _Harness(handler: _defaultHandler());
      await h.restore();
      await tester.pumpWidget(h.wrap(const ProfileScreen()));
      await tester.pumpAndSettle();

      expect(find.text(S2.profilAdSoyad), findsOneWidget);
      expect(find.text(S2.profilEposta), findsOneWidget);
      expect(find.text('${S2.profilTelefon} (isteğe bağlı)'), findsOneWidget);
      expect(find.text(S2.profilBolge), findsOneWidget);
      expect(find.text(S2.profilIl), findsOneWidget);
      expect(find.text(S2.profilIlce), findsOneWidget);
      expect(find.text(S2.sifreDegistir), findsOneWidget);
      expect(find.text('Çıkış Yap'), findsOneWidget);
    });

    testWidgets('Rol salt okunur gösterilir, düzenlenebilir kontrol yoktur',
        (tester) async {
      _tallSurface(tester);
      final h = _Harness(
          handler: _defaultHandler(me: _meJson(role: 'genel_merkez')));
      await h.restore();
      await tester.pumpWidget(h.wrap(const ProfileScreen()));
      await tester.pumpAndSettle();

      expect(find.text(S2.profilRol), findsOneWidget);
      expect(find.text(S2.profilRolNotu), findsOneWidget);
      // Rol için ne segment ne de açılır liste vardır.
      expect(find.widgetWithText(SegmentedButton<Object>, 'Genel Merkez'),
          findsNothing);
    });

    testWidgets('İlçe, İl seçilene kadar kilitlidir (kademeli zincir)',
        (tester) async {
      _tallSurface(tester);
      final h = _Harness(
          handler: _defaultHandler(
              me: _meJson(regionId: null, provinceId: null)));
      await h.restore();
      await tester.pumpWidget(h.wrap(const ProfileScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Önce ${S2.profilBolge} seçin.'), findsOneWidget);
      expect(find.text('Önce ${S2.profilIl} seçin.'), findsOneWidget);

      await tester.tap(find.byType(DropdownButtonFormField<Object?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('İç Anadolu').last);
      await tester.pumpAndSettle();

      // Bölge doldu → İl açıldı, İlçe hâlâ İl'i bekliyor.
      expect(find.text('Önce ${S2.profilBolge} seçin.'), findsNothing);
      expect(find.text('Önce ${S2.profilIl} seçin.'), findsOneWidget);
    });

    testWidgets('kaydetme yalnız izinli alanları gönderir', (tester) async {
      _tallSurface(tester);
      final log = <http.Request>[];
      final h = _Harness(handler: _defaultHandler(log: log));
      await h.restore();
      await tester.pumpWidget(h.wrap(const ProfileScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Ayşe Nur Yılmaz');
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      final patch = log.firstWhere((r) => r.method == 'PATCH');
      final body = jsonDecode(patch.body) as Map<String, dynamic>;
      expect(body['name'], 'Ayşe Nur Yılmaz');
      expect(body.keys.toSet(), ProfileFields.bodyKeys.toSet());
      expect(profileBodyIsSafe(body), isTrue);
      expect(find.text(S2.profilKaydedildi), findsOneWidget);
      // Oturumdaki ad da tazelenir.
      expect(h.session.user!.name, 'Ayşe Nur Yılmaz');
    });

    testWidgets('geçersiz telefon sunucuya gitmeden yakalanır',
        (tester) async {
      _tallSurface(tester);
      final log = <http.Request>[];
      final h = _Harness(handler: _defaultHandler(log: log));
      await h.restore();
      await tester.pumpWidget(h.wrap(const ProfileScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(2), '123');
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      expect(find.text(S2.vTelefonGecersiz), findsOneWidget);
      expect(log.any((r) => r.method == 'PATCH'), isFalse);
    });

    testWidgets('uç yoksa (404) çökmez, Türkçe uyarı gösterir',
        (tester) async {
      _tallSurface(tester);
      final h = _Harness(
        handler: (request) async {
          if (request.method == 'PATCH') {
            return _error(404, 'NOT_FOUND', 'yok');
          }
          return _defaultHandler()(request);
        },
      );
      await h.restore();
      await tester.pumpWidget(h.wrap(const ProfileScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Ayşe N. Yılmaz');
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      expect(find.text(S2.profilUcYok), findsWidgets);
    });
  });

  // -------------------------------------------------------------------------
  group('Kullanıcı Yönetimi', () {
    testWidgets('liste satırlarında fotoğraf/baş harf dairesi bulunur',
        (tester) async {
      _tallSurface(tester);
      final h = _Harness(handler: (request) async {
        if (request.url.path.endsWith('/users')) {
          return _json({
            'data': [
              _meJson(name: 'Ayşe Yılmaz', avatar: {
                'attachment_id': 3,
                'url': '/attachments/3/download',
              }),
              _meJson(name: 'Fatma Demir')..['id'] = 8,
            ]
          });
        }
        if (request.url.path.contains('/attachments/')) {
          return http.Response.bytes(_pngBytes, 200);
        }
        return _defaultHandler()(request);
      });
      await h.restore();
      await tester.pumpWidget(h.wrap(const UserListScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(UserAvatar), findsNWidgets(2));
      // Fotoğrafı olmayan kullanıcı baş harfleriyle görünür.
      expect(find.text('FD'), findsOneWidget);
    });
  });
}
