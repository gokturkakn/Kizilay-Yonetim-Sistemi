import '../../core/filepick/file_pick.dart';

/// Web dışı hedeflerde sistem dosya seçicisi bir eklenti gerektirir;
/// bu sürümde masaüstü/web hedefi desteklenir ve mobilde boş liste döner.
Future<List<PickedFile>> pickFilesImpl({
  required List<String> accept,
  bool multiple = true,
}) async =>
    const <PickedFile>[];
