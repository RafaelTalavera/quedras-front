// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:typed_data';

import 'file_save_result.dart';

Future<FileSaveResult?> saveFileBytesImpl({
  required Uint8List bytes,
  required String dialogTitle,
  required String fileName,
  required String mimeType,
  required List<String> allowedExtensions,
}) async {
  final html.Blob blob = html.Blob(<Object>[bytes], mimeType);
  final String objectUrl = html.Url.createObjectUrlFromBlob(blob);
  final html.AnchorElement anchor = html.AnchorElement(href: objectUrl)
    ..download = fileName
    ..style.display = 'none';

  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(objectUrl);

  return FileSaveResult(
    fileName: fileName,
    triggeredBrowserDownload: true,
  );
}
