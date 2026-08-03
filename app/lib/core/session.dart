import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'api.dart';
import 'api_client.dart';

/// Oturum durumu: JWT bellekte + shared_preferences'ta saklanır.
class Session extends ChangeNotifier {
  Session(this.api) {
    _wireCallbacks();
  }

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  final Api api;

  AppUser? _user;
  bool _restored = false;
  bool _expiredNotice = false;

  AppUser? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get restored => _restored;
  bool get isAdmin => _user?.isAdmin ?? false;

  /// API-V2 §1.8 — açıkken uygulama kullanıcıyı şifre formunda tutar.
  bool get mustChangePassword => _user?.mustChangePassword ?? false;

  void _wireCallbacks() {
    api.client.onUnauthorized = expire;
    api.client.onPasswordChangeRequired = flagPasswordChangeRequired;
  }

  /// 403 `PASSWORD_CHANGE_REQUIRED` alan **herhangi** bir istek buraya düşer.
  ///
  /// Oturum kapatılmaz: token geçerlidir, yalnız hesap kilitlidir. Bayrak
  /// kalıcı da yazılır ki uygulama yeniden açıldığında kilit korunsun.
  void flagPasswordChangeRequired() {
    final u = _user;
    if (u == null || u.mustChangePassword) return;
    _user = u.copyWith(mustChangePassword: true);
    _persist();
    notifyListeners();
  }

  /// Şifre başarıyla değiştirildi — aynı token çalışmaya devam eder (§1.8).
  void passwordChanged() {
    final u = _user;
    if (u == null) return;
    _user = u.copyWith(mustChangePassword: false);
    _persist();
    notifyListeners();
  }

  /// `PATCH /auth/me` / `GET /auth/me` sonrası oturumdaki kullanıcıyı tazeler.
  void applyUser(AppUser next) {
    _user = next;
    _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final u = _user;
    if (u == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(u.toJson()));
    } catch (_) {
      // yerel yazma hatası oturumu bozmaz
    }
  }

  /// Oturum 401 ile düştüyse giriş ekranında snackbar göstermek için.
  bool consumeExpiredNotice() {
    final v = _expiredNotice;
    _expiredNotice = false;
    return v;
  }

  /// Uygulama açılışında kayıtlı oturumu geri yükler.
  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      final userJson = prefs.getString(_userKey);
      if (token != null && userJson != null) {
        api.client.token = token;
        _user = AppUser.fromJson(
            (jsonDecode(userJson) as Map).cast<String, dynamic>());
      }
    } catch (_) {
      // bozuk kayıt — oturum yok say
    }
    _wireCallbacks();
    _restored = true;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final (token, user) = await api.login(email, password);
    api.client.token = token;
    _user = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
    notifyListeners();
  }

  /// Kullanıcının kendi isteğiyle çıkışı.
  Future<void> logout() async {
    await _clear();
    notifyListeners();
  }

  /// 401 sonrası oturum düşmesi (UX §4.5).
  void expire() {
    if (_user == null) return;
    _expiredNotice = true;
    _clear();
    notifyListeners();
  }

  Future<void> _clear() async {
    _user = null;
    api.client.token = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
    } catch (_) {
      // yerel temizlik hatası yok sayılır
    }
  }
}

/// ApiException'ı da yakalayan yardımcı: yaygın hataları metne çevirir.
String errorMessage(Object e) {
  if (e is ApiException) return e.displayMessage;
  return 'Bir şeyler ters gitti.';
}
