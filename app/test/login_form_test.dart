import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teskilat_yonetim/core/api.dart';
import 'package:teskilat_yonetim/core/api_client.dart';
import 'package:teskilat_yonetim/core/session.dart';
import 'package:teskilat_yonetim/screens/login_screen.dart';
import 'package:teskilat_yonetim/theme/app_theme.dart';

Widget _wrap() {
  final api = Api(ApiClient());
  final session = Session(api);
  return MultiProvider(
    providers: [
      Provider<Api>.value(value: api),
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
      home: const LoginScreen(),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('boş form gönderiminde yerel doğrulama mesajları görünür',
      (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.tap(find.text('Giriş Yap'));
    await tester.pumpAndSettle();

    expect(find.text('E-posta adresi gerekli.'), findsOneWidget);
    expect(find.text('Şifre gerekli.'), findsOneWidget);
  });

  testWidgets('geçersiz e-posta biçimi doğru mesajı verir', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.enterText(
        find.widgetWithText(TextFormField, 'E-posta'), 'gecersiz-eposta');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Şifre'), 'sifre123');
    await tester.tap(find.text('Giriş Yap'));
    await tester.pumpAndSettle();

    expect(find.text('Geçerli bir e-posta adresi girin.'), findsOneWidget);
    expect(find.text('Şifre gerekli.'), findsNothing);
  });
}
