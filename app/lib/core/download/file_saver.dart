import 'dart:typed_data';

import 'file_saver_io.dart'
    if (dart.library.js_interop) 'file_saver_web.dart' as impl;

/// İndirilen dosyayı platforma uygun biçimde kaydeder.
///
/// - Web: tarayıcı indirmesi tetiklenir (blob + anchor).
/// - Mobil/masaüstü: geçici dizine yazılır; dönen değer dosya yoludur.
///
/// [mimeType] doküman kütüphanesi için gerekir: aynı kayıtta PDF, Word ve
/// Excel birlikte bulunabilir; blob türü sunucudan gelen `mime` ile kurulur.
/// Verilmezse rapor indirmelerinin (yalnız `.xlsx`) mevcut davranışı korunur.
Future<String> saveDownloadedFile(
  Uint8List bytes,
  String fileName, {
  String? mimeType,
}) =>
    impl.saveDownloadedFile(bytes, fileName, mimeType: mimeType);
