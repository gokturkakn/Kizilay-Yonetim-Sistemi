import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Web: blob oluşturup görünmez bir bağlantı ile tarayıcı indirmesini
/// tetikler.
Future<String> saveDownloadedFile(
  Uint8List bytes,
  String fileName, {
  String? mimeType,
}) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(
      type: mimeType ??
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    ),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
  return fileName;
}
