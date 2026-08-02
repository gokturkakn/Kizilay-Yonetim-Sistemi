import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/api.dart';
import 'core/api_client.dart';
import 'core/api_v2.dart';
import 'core/lookup_cache.dart';
import 'core/ref_data.dart';
import 'core/session.dart';
import 'core/strings.dart';
import 'screens/login_screen.dart';
import 'screens/v2/adaptive_shell.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR');
  final api = Api(ApiClient());
  final apiV2 = ApiV2(api.client);
  final session = Session(api);
  await session.restore();
  runApp(TeskilatApp(
    api: api,
    apiV2: apiV2,
    lookupCache: LookupCache(apiV2),
    session: session,
  ));
}

class TeskilatApp extends StatelessWidget {
  const TeskilatApp({
    super.key,
    required this.api,
    required this.apiV2,
    required this.lookupCache,
    required this.session,
  });

  final Api api;
  final ApiV2 apiV2;
  final LookupCache lookupCache;
  final Session session;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<Api>.value(value: api),
        // v2 uçları aynı ApiClient örneğini (ve JWT'yi) paylaşır.
        Provider<ApiV2>.value(value: apiV2),
        // LookupCache bir ChangeNotifier'dır (Tanımlar değişince dinleyicileri
        // uyarır) — düz Provider ile kaydedilemez.
        ChangeNotifierProvider<LookupCache>.value(value: lookupCache),
        Provider<RefData>(create: (_) => RefData(api)),
        ChangeNotifierProvider<Session>.value(value: session),
      ],
      child: MaterialApp(
        title: 'Teşkilat Yönetim Sistemi',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        themeMode: ThemeMode.light,
        locale: const Locale('tr'),
        supportedLocales: const [Locale('tr')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    if (!session.restored) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!session.isLoggedIn) {
      return const LoginScreen();
    }
    // Kullanıcı değişince iskelet sıfırlanır.
    return AdaptiveShell(key: ValueKey('shell-${session.user!.id}'));
  }
}

/// Oturum düşmesi snackbar'ı — giriş ekranı açıldığında gösterilir.
void maybeShowSessionExpired(BuildContext context, Session session) {
  if (session.consumeExpiredNotice()) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(const SnackBar(
        content: Text(Str.hataOturum),
        duration: Duration(seconds: 3),
      ));
    });
  }
}
