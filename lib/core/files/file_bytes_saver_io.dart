import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'file_save_result.dart';

Future<FileSaveResult?> saveFileBytesImpl({
  required Uint8List bytes,
  required String dialogTitle,
  required String fileName,
  required String mimeType,
  required List<String> allowedExtensions,
}) async {
  final String? outputPath = await FilePicker.platform.saveFile(
    dialogTitle: dialogTitle,
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: allowedExtensions,
    lockParentWindow: true,
  );
  if (outputPath == null || outputPath.trim().isEmpty) {
    return null;
  }

  final String normalizedPath = _ensureExtension(
    outputPath: outputPath,
    allowedExtensions: allowedExtensions,
  );
  final File file = File(normalizedPath);
  await file.writeAsBytes(bytes, flush: true);
  return FileSaveResult(fileName: fileName, path: file.path);
}

String _ensureExtension({
  required String outputPath,
  required List<String> allowedExtensions,
}) {
  if (allowedExtensions.isEmpty) {
    return outputPath;
  }

  final String lowerPath = outputPath.toLowerCase();
  for (final String extension in allowedExtensions) {
    final String normalizedExtension = extension.toLowerCase();
    if (lowerPath.endsWith('.$normalizedExtension')) {
      return outputPath;
    }
  }

  return '$outputPath.${allowedExtensions.first}';
}
