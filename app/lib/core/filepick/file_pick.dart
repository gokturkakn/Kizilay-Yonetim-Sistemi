import 'dart:typed_data';

import 'file_pick_stub.dart'
    if (dart.library.js_interop) 'file_pick_web.dart' as impl;

/// Seçilen dosya (bellekte).
class PickedFile {
  const PickedFile({
    required this.name,
    required this.bytes,
    required this.mime,
  });

  final String name;
  final Uint8List bytes;
  final String mime;

  int get size => bytes.length;

  String get extension {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }
}

/// Sistem dosya seçicisini açar — docs/UX-V2.md §7.5.
///
/// [accept] MIME/uzantı süzgeci; seçicinin tür süzgeci desteklenmeyen
/// biçimleri **hiç göstermez** (§7.2).
Future<List<PickedFile>> pickFiles({
  required List<String> accept,
  bool multiple = true,
}) =>
    impl.pickFilesImpl(accept: accept, multiple: multiple);

/// Ek türüne göre izinli uzantılar — §7.2 (API-V2 §9 ile birebir).
class AttachmentRules {
  const AttachmentRules._();

  static const maxBytes = 10 * 1024 * 1024; // 10 MB — sunucuda sabit
  static const maxPerRecord = 20; // istemci kuralı

  static const photoExtensions = ['jpg', 'jpeg', 'png', 'webp', 'gif'];
  static const documentExtensions = ['pdf', 'docx', 'xlsx'];

  static bool isPhotoKind(String kind) => kind == 'fotograf';

  static List<String> extensionsFor(String kind) =>
      isPhotoKind(kind) ? photoExtensions : documentExtensions;

  static List<String> acceptFor(String kind) =>
      extensionsFor(kind).map((e) => '.$e').toList();

  /// Uzantı → MIME. Sunucudaki beyaz listeyle **birebir** aynıdır (API-V2 §9);
  /// tarayıcı/işletim sistemi tür bildirmediğinde yedek kaynaktır.
  static const mimeByExtension = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'gif': 'image/gif',
    'pdf': 'application/pdf',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xlsx':
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  };

  static String? mimeForFileName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0) return null;
    return mimeByExtension[fileName.substring(dot + 1).toLowerCase()];
  }

  /// Dosyayı doğrular; sorun yoksa `null` döner (metinler §7.2'den aynen).
  static String? validate(PickedFile file, String kind) {
    if (file.size == 0) return 'Dosya boş görünüyor. Başka bir dosya seçin.';
    if (file.size > maxBytes) {
      return 'Dosya boyutu en fazla 10 MB olabilir.';
    }
    if (!extensionsFor(kind).contains(file.extension)) {
      return isPhotoKind(kind)
          ? 'Yalnızca JPG, PNG, WEBP ve GIF dosyaları yükleyebilirsiniz.'
          : 'Yalnızca PDF, Word (.docx) ve Excel (.xlsx) dosyaları '
              'yükleyebilirsiniz.';
    }
    return null;
  }
}
