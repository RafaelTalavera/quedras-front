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

  static const String _fontRegularAssetPath = 'assets/fonts/Lato-Regular.ttf';
  static const String _fontBoldAssetPath = 'assets/fonts/Lato-Bold.ttf';
  static const String _hotelName = 'Hotel Costa Norte';
  static const String _reportTitle = 'Resumo de atendimentos por prestador';

  static final PdfColor _inkColor = PdfColor.fromHex('#000000');
  static final PdfColor _headlineColor = PdfColor.fromHex('#000000');
  static final PdfColor _mutedColor = PdfColor.fromHex('#4A4A4A');
  static final PdfColor _borderColor = PdfColor.fromHex('#9A9A9A');
  static final PdfColor _accentColor = PdfColor.fromHex('#000000');

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
    final Uint8List regularFontBytes = await _loadAssetBytes(
      _fontRegularAssetPath,
    );
    final Uint8List boldFontBytes = await _loadAssetBytes(_fontBoldAssetPath);
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

    final DateTime generatedAt = DateTime.now();

    document.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        header: (pw.Context context) => _buildHeader(
          providerName: detail.providerName,
          generatedAt: generatedAt,
        ),
        footer: (pw.Context context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: _borderColor, width: 0.7),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: <pw.Widget>[
              pw.Text(
                _ascii(_hotelName),
                style: pw.TextStyle(fontSize: 8.5, color: _mutedColor),
              ),
              pw.Text(
                'Pagina ${context.pageNumber} de ${context.pagesCount}',
                style: pw.TextStyle(fontSize: 8.5, color: _mutedColor),
              ),
            ],
          ),
        ),
        build: (pw.Context context) {
          return <pw.Widget>[
            _buildOverview(
              detail: detail,
              startDate: startDate,
              endDate: endDate,
              generatedAt: generatedAt,
            ),
            pw.SizedBox(height: 16),
            _buildSummaryGrid(detail.summary),
            pw.SizedBox(height: 18),
            pw.Text(
              'Detalhe das atencoes',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: _headlineColor,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Relacao analitica dos atendimentos incluidos no periodo.',
              style: pw.TextStyle(fontSize: 9.5, color: _mutedColor),
            ),
            pw.SizedBox(height: 10),
            if (items.isEmpty) _buildEmptyState() else ...items.map(_buildItemCard),
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

  pw.BoxDecoration _printBorder({double width = 0.6}) {
    return pw.BoxDecoration(
      border: pw.Border.all(color: _borderColor, width: width),
    );
  }

  pw.Widget _buildHeader({
    required String providerName,
    required DateTime generatedAt,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 14),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: _borderColor, width: 0.8),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Text(
                  _ascii(_hotelName).toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _accentColor,
                    letterSpacing: 1.1,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  _reportTitle,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: _headlineColor,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'Prestador: ${_ascii(providerName)}',
                  style: pw.TextStyle(fontSize: 10, color: _mutedColor),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 20),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: <pw.Widget>[
              pw.Text(
                'Relatorio executivo',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: _headlineColor,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Emitido em ${_formatDateTime(generatedAt)}',
                style: pw.TextStyle(fontSize: 9, color: _mutedColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildOverview({
    required MassageProviderDetailReport detail,
    required DateTime startDate,
    required DateTime endDate,
    required DateTime generatedAt,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: _printBorder(width: 0.7),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(
            'Visao geral do periodo',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: _headlineColor,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            _ascii(detail.providerName),
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: _inkColor,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Documento consolidado para acompanhamento operacional e financeiro do prestador.',
            style: pw.TextStyle(fontSize: 9.2, color: _mutedColor),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              pw.Expanded(
                child: _buildOverviewField(
                  'Periodo analisado',
                  _formatDateRange(startDate, endDate),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: _buildOverviewField(
                  'Situacao do prestador',
                  detail.providerActive ? 'Ativo' : 'Inativo',
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: _buildOverviewField(
                  'Data de emissao',
                  _formatDateTime(generatedAt),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildOverviewField(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(left: 8, top: 2, bottom: 2),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(color: _borderColor, width: 1),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(
            label.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 7.8,
              fontWeight: pw.FontWeight.bold,
              color: _mutedColor,
              letterSpacing: 0.5,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            _ascii(value),
            style: pw.TextStyle(
              fontSize: 9.8,
              fontWeight: pw.FontWeight.bold,
              color: _inkColor,
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
      children: items.map(_buildMetricCard).toList(),
    );
  }

  pw.Widget _buildMetricCard(MapEntry<String, String> item) {
    return pw.Container(
      width: 248,
      padding: const pw.EdgeInsets.all(10),
      decoration: _printBorder(width: 0.6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(
            item.key.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: _mutedColor,
              letterSpacing: 0.5,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            _ascii(item.value),
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: _headlineColor,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildEmptyState() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: _printBorder(width: 0.6),
      child: pw.Text(
        'Nao existem atendimentos para o periodo informado.',
        style: pw.TextStyle(fontSize: 10.2, color: _inkColor),
      ),
    );
  }

  pw.Widget _buildItemCard(MassageProviderReportItem item) {
    final String paymentLabel = _buildPaymentLabel(item);

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(10),
        decoration: _printBorder(width: 0.6),
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
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: _headlineColor,
                    ),
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: _printBorder(width: 0.5),
                  child: pw.Text(
                    _statusLabel(item).toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: _headlineColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            _buildDetailLine(
              'Agenda',
              '${_formatDate(item.bookingDate)} | ${item.startTime.substring(0, 5)}',
            ),
            pw.SizedBox(height: 3),
            _buildDetailLine('Tratamento', item.treatment),
            pw.SizedBox(height: 3),
            _buildDetailLine('Referencia', item.guestReference),
            pw.SizedBox(height: 3),
            _buildDetailLine('Massagista', item.therapistName),
            pw.SizedBox(height: 3),
            _buildDetailLine(
              'Valor do atendimento',
              _formatCurrency(item.amount),
            ),
            pw.SizedBox(height: 3),
            _buildDetailLine('Situacao do pagamento', paymentLabel),
            if ((item.paymentNotes ?? '').trim().isNotEmpty) ...<pw.Widget>[
              pw.SizedBox(height: 3),
              _buildDetailLine(
                'Observacoes do pagamento',
                item.paymentNotes!.trim(),
              ),
            ],
            if ((item.cancellationNotes ?? '').trim().isNotEmpty) ...<pw.Widget>[
              pw.SizedBox(height: 3),
              _buildDetailLine(
                'Motivo do cancelamento',
                item.cancellationNotes!.trim(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  pw.Widget _buildDetailLine(String label, String value) {
    return pw.RichText(
      text: pw.TextSpan(
        style: pw.TextStyle(fontSize: 9.8, color: _inkColor),
        children: <pw.InlineSpan>[
          pw.TextSpan(
            text: '$label: ',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: _headlineColor,
            ),
          ),
          pw.TextSpan(text: _ascii(value)),
        ],
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