/// Uygulama genel yapılandırması.
///
/// API taban adresi tek yerden yönetilir; ortam değiştirmek için
/// yalnızca bu dosya güncellenir.
class AppConfig {
  AppConfig._();

  /// REST API taban adresi (bkz. docs/API.md).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4141/api/v1',
  );

  /// Uygulama sürümü (Profil ekranında gösterilir).
  static const String appVersion = '0.1.0';
}
