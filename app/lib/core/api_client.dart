import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

import 'config.dart';
import 'strings.dart';

/// API hatası. [statusCode] 0 ise ağ hatasıdır.
class ApiException implements Exception {
  const ApiException(this.statusCode, this.code, this.message);

  final int statusCode;
  final String code;
  final String message;

  bool get isNetwork => statusCode == 0;
  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isConflict => statusCode == 409;

  /// Kullanıcıya gösterilecek genel metin.
  String get displayMessage {
    if (isNetwork) return Str.hataAg;
    if (isForbidden) return Str.hataYetki;
    return message.isNotEmpty ? message : Str.hataGenel;
  }

  @override
  String toString() => 'ApiException($statusCode, $code, $message)';
}

/// HTTP istemcisi: JWT başlığı, JSON çözme, hata modeli, 401 yakalama.
class ApiClient {
  ApiClient({http.Client? client, String baseUrl = AppConfig.apiBaseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl;

  final http.Client _client;
  final String _baseUrl;

  String? token;

  /// 401 alındığında çağrılır (oturum düşmesi) — HomeShell'e dönüş için.
  VoidCallback? onUnauthorized;

  Map<String, String> _headers({bool json = true}) => {
        if (json) 'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$_baseUrl$path');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: {...uri.queryParameters, ...query});
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, Object? body) =>
      _send('POST', path, body: body);

  Future<dynamic> put(String path, Object? body) =>
      _send('PUT', path, body: body);

  Future<dynamic> patch(String path, Object? body) =>
      _send('PATCH', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  /// İkili içerik indirir (Excel raporları).
  Future<Uint8List> getBytes(String path,
      {Map<String, String>? query}) async {
    http.Response resp;
    try {
      resp = await _client.get(_uri(path, query),
          headers: _headers(json: false));
    } catch (_) {
      throw const ApiException(0, 'network', Str.hataAg);
    }
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return resp.bodyBytes;
    }
    throw _errorFrom(resp);
  }

  /// Çok parçalı yükleme (dosya ekleri — API-V2 §9).
  ///
  /// [contentType] **gönderilmelidir**: sunucu beyaz listesi parçanın
  /// `Content-Type` başlığına bakar ve `http` paketinin varsayılanı
  /// (`application/octet-stream`) her yüklemeyi 400 ile reddettirir.
  Future<dynamic> postMultipart(
    String path, {
    required List<int> bytes,
    required String fileName,
    required Map<String, String> fields,
    String? contentType,
  }) async {
    http.Response resp;
    try {
      final request = http.MultipartRequest('POST', _uri(path));
      request.headers.addAll(_headers(json: false));
      request.fields.addAll(fields);
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
          contentType: contentType == null || contentType.isEmpty
              ? null
              : MediaType.parse(contentType),
        ),
      );
      final streamed = await _client.send(request);
      resp = await http.Response.fromStream(streamed);
    } catch (_) {
      throw const ApiException(0, 'network', Str.hataAg);
    }
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (resp.body.isEmpty) return null;
      try {
        return jsonDecode(utf8.decode(resp.bodyBytes));
      } catch (_) {
        return null;
      }
    }
    throw _errorFrom(resp);
  }

  Future<dynamic> _send(String method, String path,
      {Map<String, String>? query, Object? body}) async {
    http.Response resp;
    try {
      final request = http.Request(method, _uri(path, query));
      request.headers.addAll(_headers());
      if (body != null) request.body = jsonEncode(body);
      final streamed = await _client.send(request);
      resp = await http.Response.fromStream(streamed);
    } catch (_) {
      throw const ApiException(0, 'network', Str.hataAg);
    }
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (resp.body.isEmpty) return null;
      try {
        return jsonDecode(utf8.decode(resp.bodyBytes));
      } catch (_) {
        return null;
      }
    }
    throw _errorFrom(resp);
  }

  ApiException _errorFrom(http.Response resp) {
    var code = 'unknown';
    var message = '';
    try {
      final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
      final err = decoded is Map ? decoded['error'] : null;
      if (err is Map) {
        code = err['code']?.toString() ?? code;
        message = err['message']?.toString() ?? '';
      }
    } catch (_) {
      // gövde JSON değil — varsayılanlar kalır
    }
    final ex = ApiException(resp.statusCode, code, message);
    if (ex.isUnauthorized && token != null) {
      onUnauthorized?.call();
    }
    return ex;
  }
}
