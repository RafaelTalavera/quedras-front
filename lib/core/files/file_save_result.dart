final class FileSaveResult {
  const FileSaveResult({
    required this.fileName,
    this.path,
    this.triggeredBrowserDownload = false,
  });

  final String fileName;
  final String? path;
  final bool triggeredBrowserDownload;

  bool get hasLocalPath => path != null && path!.trim().isNotEmpty;
}
