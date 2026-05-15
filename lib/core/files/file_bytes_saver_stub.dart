import 'dart:typed_data';

import 'file_save_result.dart';

Future<FileSaveResult?> saveFileBytesImpl({
  required Uint8List bytes,
  required String dialogTitle,
  required String fileName,
  required String mimeType,
  required List<String> allowedExtensions,
}) {
  throw UnsupportedError('Saving files is not supported on this platform.');
}
