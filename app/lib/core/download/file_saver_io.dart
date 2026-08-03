import 'dart:io';
import 'dart:typed_data';

/// Mobil/masaüstü: geçici dizine kaydeder ve işletim sistemiyle açmayı dener.
Future<String> saveDownloadedFile(
  Uint8List bytes,
  String fileName, {
  String? mimeType, // yerel dosyada tür uzantıdan okunur; imzayı web ile eşler
}) async {
  final dir = Directory.systemTemp;
  final file = File('${dir.path}${Platform.pathSeparator}$fileName');
  await file.writeAsBytes(bytes, flush: true);
  await _tryOpen(file.path);
  return file.path;
}

Future<void> _tryOpen(String path) async {
  try {
    if (Platform.isMacOS) {
      await Process.run('open', [path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [path]);
    } else if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', path]);
    }
    // Android/iOS: MVP'de dosya geçici dizine kaydedilir; açma işlemi
    // sonraki sürümde platform kanalı/eklenti ile yapılacak.
  } catch (_) {
    // açılamazsa yol yine de kullanıcıya bildirilir
  }
}
