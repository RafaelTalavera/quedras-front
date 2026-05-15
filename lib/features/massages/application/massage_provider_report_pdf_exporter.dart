import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/files/file_bytes_saver.dart';
import '../../../core/files/file_save_result.dart';
import '../domain/massage_models.dart';

typedef LoadAssetBytes = Future<Uint8List> Function(String assetPath);
typedef GetTemporaryDirectoryCallback = Future<Directory> Function();

abstract interface class MassageProviderReportPdfExporter {
  String buildFileName({
    required MassageProviderDetailReport detail,
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<Uint8List> buildPdfBytes({
    required MassageProviderDetailReport detail,
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<FileSaveResult?> savePdf({
    required MassageProviderDetailReport detail,
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<File> createTemporaryPdf({
    required MassageProviderDetailReport detail,
    required DateTime startDate,
    required DateTime endDate,
  });
}

final class DefaultMassageProviderReportPdfExporter
    implements MassageProviderReportPdfExporter {
  DefaultMassageProviderReportPdfExporter({
    LoadAssetBytes? loadAssetBytes,
    GetTemporaryDirectoryCallback? getTemporaryDirectoryCallback,
  }) : _loadAssetBytes = loadAssetBytes ?? _defaultLoadAssetBytes,
       _getTemporaryDirectory =
           getTemporaryDirectoryCallback ?? getTemporaryDirectory;

  static const String _logoAssetPath = 'assets/branding/costanorte_logo.png';
  static const String _fontRegularAssetPath = 'assets/fonts/Lato-Regular.ttf';
  static const String _fontBoldAssetPath = 'assets/fonts/Lato-Bold.ttf';
  static const String _hotelName = 'Hotel Costa Norte';
  static const String _reportTitle = 'Resumo de atendimentos por prestador';

  final LoadAssetBytes _loadAssetBytes;
  final GetTemporaryDirectoryCallback _getTemporaryDirectory;

  @override
  String buildFileName({
    required MassageProviderDetailReport detail,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final String providerLabel = _sanitizeFileSegment(
      _ascii(detail.providerName),
    );
    return 'resumo_massagens_${providerLabel}_${_formatDateIso(startDate)}_${_formatDateIso(endDate)}.pdf';
  }

  @override
  Future<Uint8List> buildPdfBytes({
    required MassageProviderDetailReport detail,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final pw.Document document = pw.Document();
    final Uint8List logoBytes = await _loadAssetBytes(_logoAssetPath);
    final Uint8List regularFontBytes = await _loadAssetBytes(
      _fontRegularAssetPath,
    );
    final Uint8List boldFontBytes = await _loadAssetBytes(_fontBoldAssetPath);
    final pw.MemoryImage logoImage = pw.MemoryImage(logoBytes);
    final pw.Font regularFont = pw.Font.ttf(
      regularFontBytes.buffer.asByteData(
        regularFontBytes.offsetInBytes,
        regularFontBytes.lengthInBytes,
      ),
    );
    final pw.Font boldFont = pw.Font.ttf(
      boldFontBytes.buffer.asByteData(
        boldFontBytes.offsetInBytes,
        boldFontBytes.lengthInBytes,
      ),
    );
    final pw.PageTheme pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
    );
    final List<MassageProviderReportItem> items =
        List<MassageProviderReportItem>.from(detail.items)..sort(
          (MassageProviderReportItem a, MassageProviderReportItem b) =>
              a.startAt.compareTo(b.startAt),
        );

    document.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        header: (pw.Context context) => _buildHeader(
          logoImage: logoImage,
          providerName: detail.providerName,
        ),
        footer: (pw.Context context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Pagina ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ),
        build: (pw.Context context) {
          return <pw.Widget>[
            _buildOverview(
              detail: detail,
              startDate: startDate,
              endDate: endDate,
            ),
            pw.SizedBox(height: 18),
            _buildSummaryGrid(detail.summary),
            pw.SizedBox(height: 20),
            pw.Text(
              'Detalhe das atencoes',
              style: pw.TextStyle(
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey900,
              ),
            ),
            pw.SizedBox(height: 10),
            if (items.isEmpty)
              _buildEmptyState()
            else
              ...items.map(_buildItemCard),
          ];
        },
      ),
    );

    return document.save();
  }

  @override
  Future<FileSaveResult?> savePdf({
    required MassageProviderDetailReport detail,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final String fileName = buildFileName(
      detail: detail,
      startDate: startDate,
      endDate: endDate,
    );
    final Uint8List bytes = await buildPdfBytes(
      detail: detail,
      startDate: startDate,
      endDate: endDate,
    );
    return saveFileBytes(
      bytes: bytes,
      dialogTitle: 'Salvar resumo em PDF',
      fileName: fileName,
      mimeType: 'application/pdf',
      allowedExtensions: const <String>['pdf'],
    );
  }

  @override
  Future<File> createTemporaryPdf({
    required MassageProviderDetailReport detail,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final Uint8List bytes = await buildPdfBytes(
      detail: detail,
      startDate: startDate,
      endDate: endDate,
    );
    final Directory directory = await _getTemporaryDirectory();
    final String fileName = buildFileName(
      detail: detail,
      startDate: startDate,
      endDate: endDate,
    );
    final File file = File(
      '${directory.path}${Platform.pathSeparator}$fileName',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<Uint8List> _defaultLoadAssetBytes(String assetPath) async {
    final ByteData data = await rootBundle.load(assetPath);
    return data.buffer.asUint8List();
  }

  pw.Widget _buildHeader({
    required pw.MemoryImage logoImage,
    required String providerName,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: <pw.Widget>[
          _buildLogoBox(logoImage),
          pw.SizedBox(width: 24),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: <pw.Widget>[
                pw.Text(
                  _hotelName,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey900,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '${_ascii(providerName)} - $_reportTitle',
                  style: const pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Documento preparado para envio ao prestador.',
                  style: const pw.TextStyle(
                    fontSize: 9.5,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildOverview({
    required MassageProviderDetailReport detail,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(18),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(
            _reportTitle,
            style: pw.TextStyle(
              fontSize: 19,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey900,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            _ascii(detail.providerName),
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Wrap(
            spacing: 12,
            runSpacing: 8,
            children: <pw.Widget>[
              _buildOverviewTag(
                'Periodo',
                _formatDateRange(startDate, endDate),
              ),
              _buildOverviewTag(
                'Status',
                detail.providerActive ? 'Ativo' : 'Inativo',
              ),
              _buildOverviewTag('Emitido em', _formatDateTime(DateTime.now())),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildOverviewTag(String label, String value) {
    return pw.RichText(
      text: pw.TextSpan(
        style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.black),
        children: <pw.InlineSpan>[
          pw.TextSpan(
            text: '$label: ',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.TextSpan(text: _ascii(value)),
        ],
      ),
    );
  }

  pw.Widget _buildLogoBox(pw.MemoryImage logoImage) {
    return pw.Container(
      width: 106,
      height: 118,
      padding: const pw.EdgeInsets.fromLTRB(10, 9, 10, 8),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#FFF8D8'),
        borderRadius: pw.BorderRadius.circular(18),
      ),
      child: pw.Column(
        children: <pw.Widget>[
          pw.Expanded(
            child: pw.FittedBox(
              fit: pw.BoxFit.contain,
              child: pw.ClipRect(
                child: pw.Align(
                  alignment: const pw.Alignment(-1.0, -0.1),
                  widthFactor: 0.40,
                  child: pw.Image(logoImage, width: 188),
                ),
              ),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'COSTA NORTE',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 8.2,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
          pw.SizedBox(height: 1.5),
          pw.Text(
            'INGLESES',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(
              fontSize: 6.5,
              color: PdfColors.black,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryGrid(MassageProviderSummary summary) {
    final List<MapEntry<String, String>> items = <MapEntry<String, String>>[
      MapEntry<String, String>('Atencoes', '${summary.attendedCount}'),
      MapEntry<String, String>('Canceladas', '${summary.cancelledCount}'),
      MapEntry<String, String>('Pagas', '${summary.paidCount}'),
      MapEntry<String, String>('Pendentes', '${summary.pendingCount}'),
      MapEntry<String, String>('Cobrado', _formatCurrency(summary.paidAmount)),
      MapEntry<String, String>(
        'Pendente R\$',
        _formatCurrency(summary.pendingAmount),
      ),
      MapEntry<String, String>(
        'Total previsto',
        _formatCurrency(summary.grossAmount),
      ),
      MapEntry<String, String>(
        'Ultima atencao',
        summary.lastBookingAt == null
            ? '-'
            : _formatDate(summary.lastBookingAt!),
      ),
    ];

    return pw.Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items
          .map(
            (MapEntry<String, String> item) => pw.Container(
              width: 248,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F7F7F5'),
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: <pw.Widget>[
                  pw.Text(
                    item.key,
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    _ascii(item.value),
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey900,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  pw.Widget _buildEmptyState() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F7F7F5'),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Text(
        'Nao existem atendimentos para o periodo informado.',
        style: const pw.TextStyle(fontSize: 11),
      ),
    );
  }

  pw.Widget _buildItemCard(MassageProviderReportItem item) {
    final bool cancelled = item.status == MassageBookingStatus.cancelled;
    final String paymentLabel = _buildPaymentLabel(item);
    final PdfColor accentColor = cancelled
        ? PdfColors.red700
        : item.paid
        ? PdfColors.green700
        : PdfColors.amber800;

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#F7F7F5'),
          borderRadius: pw.BorderRadius.circular(14),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Expanded(
                  child: pw.Text(
                    _ascii(item.clientName),
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey900,
                    ),
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: pw.Text(
                    _statusLabel(item),
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Data: ${_formatDate(item.bookingDate)} | Hora: ${item.startTime.substring(0, 5)} | Tratamento: ${_ascii(item.treatment)}',
              style: const pw.TextStyle(fontSize: 10.5),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              'Referencia: ${_ascii(item.guestReference)} | Masajista: ${_ascii(item.therapistName)}',
              style: const pw.TextStyle(fontSize: 10.5),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              'Valor: ${_formatCurrency(item.amount)} | Pagamento: ${_ascii(paymentLabel)}',
              style: const pw.TextStyle(fontSize: 10.5),
            ),
            if ((item.paymentNotes ?? '').trim().isNotEmpty) ...<pw.Widget>[
              pw.SizedBox(height: 3),
              pw.Text(
                'Observacoes do pagamento: ${_ascii(item.paymentNotes!.trim())}',
                style: const pw.TextStyle(fontSize: 10.5),
              ),
            ],
            if ((item.cancellationNotes ?? '')
                .trim()
                .isNotEmpty) ...<pw.Widget>[
              pw.SizedBox(height: 3),
              pw.Text(
                'Motivo do cancelamento: ${_ascii(item.cancellationNotes!.trim())}',
                style: const pw.TextStyle(fontSize: 10.5),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatDateRange(DateTime startDate, DateTime endDate) {
    return '${_formatDate(startDate)} a ${_formatDate(endDate)}';
  }

  static String _formatDate(DateTime date) {
    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  static String _formatDateIso(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static String _formatDateTime(DateTime date) {
    final String hour = date.hour.toString().padLeft(2, '0');
    final String minute = date.minute.toString().padLeft(2, '0');
    return '${_formatDate(date)} $hour:$minute';
  }

  static String _formatCurrency(double amount) {
    final bool negative = amount < 0;
    final String fixed = amount.abs().toStringAsFixed(2);
    final List<String> parts = fixed.split('.');
    final String integerPart = parts.first;
    final String decimalPart = parts.last;
    final StringBuffer buffer = StringBuffer();

    for (int index = 0; index < integerPart.length; index++) {
      final int reverseIndex = integerPart.length - index;
      buffer.write(integerPart[index]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write('.');
      }
    }

    return '${negative ? '-' : ''}R\$ ${buffer.toString()},$decimalPart';
  }

  static String _buildPaymentLabel(MassageProviderReportItem item) {
    if (item.status == MassageBookingStatus.cancelled) {
      return 'Cancelado';
    }
    if (!item.paid) {
      return 'Pendente';
    }
    final String method = item.paymentMethod?.label ?? 'Meio nao informado';
    final String date = item.paymentDate == null
        ? 'data nao informada'
        : _formatDate(item.paymentDate!);
    return 'Pago em $date via $method';
  }

  static String _statusLabel(MassageProviderReportItem item) {
    if (item.status == MassageBookingStatus.cancelled) {
      return 'Cancelado';
    }
    return item.paid ? 'Pago' : 'Pendente';
  }

  static String _sanitizeFileSegment(String rawValue) {
    final String normalized = rawValue
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return normalized.isEmpty ? 'prestador' : normalized;
  }

  static String _ascii(String value) {
    const Map<String, String> replacements = <String, String>{
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'Á': 'A',
      'À': 'A',
      'Â': 'A',
      'Ã': 'A',
      'Ä': 'A',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'É': 'E',
      'È': 'E',
      'Ê': 'E',
      'Ë': 'E',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'Í': 'I',
      'Ì': 'I',
      'Î': 'I',
      'Ï': 'I',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'Ó': 'O',
      'Ò': 'O',
      'Ô': 'O',
      'Õ': 'O',
      'Ö': 'O',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'Ú': 'U',
      'Ù': 'U',
      'Û': 'U',
      'Ü': 'U',
      'ç': 'c',
      'Ç': 'C',
      'ñ': 'n',
      'Ñ': 'N',
    };
    final StringBuffer buffer = StringBuffer();
    for (final int rune in value.runes) {
      final String char = String.fromCharCode(rune);
      buffer.write(replacements[char] ?? char);
    }
    return buffer.toString();
  }
}
