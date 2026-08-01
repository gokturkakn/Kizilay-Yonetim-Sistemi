import 'dart:typed_data';

import 'file_saver_io.dart'
    if (dart.library.js_interop) 'file_saver_web.dart' as impl;

/// İndirilen dosyayı platforma uygun biçimde kaydeder.
///
/// - Web: tarayıcı indirmesi tetiklenir (blob + anchor).
/// - Mobil/masaüstü: geçici dizine yazılır; dönen değer dosya yoludur.
Future<String> saveDownloadedFile(Uint8List bytes, String fileName) =>
    impl.saveDownloadedFile(bytes, fileName);
