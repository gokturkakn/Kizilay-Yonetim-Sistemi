import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'file_pick.dart';

/// Web: görünmez `<input type="file">` ile sistem seçicisini açar.
Future<List<PickedFile>> pickFilesImpl({
  required List<String> accept,
  bool multiple = true,
}) async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = accept.join(',')
    ..multiple = multiple
    ..style.display = 'none';
  web.document.body?.append(input);

  final completer = Completer<List<PickedFile>>();
  var settled = false;

  void finish(List<PickedFile> files) {
    if (settled) return;
    settled = true;
    input.remove();
    completer.complete(files);
  }

  input.onchange = (web.Event _) {
    final fileList = input.files;
    if (fileList == null || fileList.length == 0) {
      finish(const []);
      return;
    }
    final futures = <Future<PickedFile>>[];
    for (var i = 0; i < fileList.length; i++) {
      final file = fileList.item(i);
      if (file == null) continue;
      futures.add(_read(file));
    }
    Future.wait(futures).then(finish, onError: (_) => finish(const []));
  }.toJS;

  // Kullanıcı seçiciyi iptal ederse `change` olayı gelmez.
  input.oncancel = (web.Event _) {
    finish(const []);
  }.toJS;

  input.click();
  return completer.future;
}

Future<PickedFile> _read(web.File file) {
  final completer = Completer<PickedFile>();
  final reader = web.FileReader();
  reader.onload = (web.Event _) {
    final result = reader.result;
    final buffer = result as JSArrayBuffer?;
    final bytes = buffer == null
        ? Uint8List(0)
        : buffer.toDart.asUint8List();
    completer.complete(
        PickedFile(name: file.name, bytes: bytes, mime: file.type));
  }.toJS;
  reader.onerror = (web.Event _) {
    completer.completeError(StateError('read-failed'));
  }.toJS;
  reader.readAsArrayBuffer(file);
  return completer.future;
}
