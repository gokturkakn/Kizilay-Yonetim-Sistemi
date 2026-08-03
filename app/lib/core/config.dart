/// Uygulama genel yapılandırması.
///
/// API taban adresi tek yerden yönetilir; ortam değiştirmek için
/// yalnızca bu dosya güncellenir.
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // http://localhost:4141/api/v1
    defaultValue: 'https://kizilaykadin.onrender.com/api/v1', 
  );

  static const String appVersion = '0.1.0';
}