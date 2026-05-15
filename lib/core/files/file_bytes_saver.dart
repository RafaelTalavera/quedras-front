import 'dart:typed_data';

import 'file_save_result.dart';
import 'file_bytes_saver_stub.dart'
    if (dart.library.html) 'file_bytes_saver_web.dart'
    if (dart.library.io) 'file_bytes_saver_io.dart';

Future<FileSaveResult?> saveFileBytes({
  required Uint8List bytes,
  required String dialogTitle,
  required String fileName,
  required String mimeType,
  required List<String> allowedExtensions,
}) {
  return saveFileBytesImpl(
    bytes: bytes,
    dialogTitle: dialogTitle,
    fileName: fileName,
    mimeType: mimeType,
    allowedExtensions: allowedExtensions,
  );
}
