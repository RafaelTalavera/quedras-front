import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/files/file_bytes_saver.dart';
import '../../../core/files/file_save_result.dart';
import '../domain/court_models.dart';

typedef LoadAssetBytes = Future<Uint8List> Function(String assetPath);
typedef GetTemporaryDirectoryCallback = Future<Directory> Function();

class PartnerCoachReportSummary {
  const PartnerCoachReportSummary({
    required this.scheduledCount,
    required this.paidCount,
    required this.pendingCount,
    required this.totalHours,
    required this.courtAmount,
    required this.materialsAmount,
    required this.totalAmount,
  });

  final int scheduledCount;
  final int paidCount;
  final int pendingCount;
  final double totalHours;
  final double courtAmount;
  final double materialsAmount;
  final double totalAmount;
}

class PartnerCoachReportDetail {
  const PartnerCoachReportDetail({
    required this.coachName,
    required this.summary,
    required this.bookings,
  });

  final String coachName;
  final PartnerCoachReportSummary summary;
  final List<CourtBooking> bookings;
}

abstract interface class PartnerCoachReportPdfExporter {
  String buildFileName({
    required PartnerCoachReportDetail detail,
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<Uint8List> buildPdfBytes({
    required PartnerCoachReportDetail detail,
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<FileSaveResult?> savePdf({
    required PartnerCoachReportDetail detail,
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<File> createTemporaryPdf({
    required PartnerCoachReportDetail detail,
    required DateTime startDate,
    required DateTime endDate,
  });
}

final class DefaultPartnerCoachReportPdfExporter
    implements PartnerCoachReportPdfExporter {
  DefaultPartnerCoachReportPdfExporter({
    LoadAssetBytes? loadAssetBytes,
    GetTemporaryDirectoryCallback? getTemporaryDirectoryCallback,
  }) : _loadAssetBytes = loadAssetBytes ?? _defaultLoadAssetBytes,
       _getTemporaryDirectory =
           getTemporaryDirectoryCallback ?? getTemporaryDirectory;

  static const String _logoAssetPath = 'assets/branding/costanorte_logo.png';
  static const String _fontRegularAssetPath = 'assets/fonts/Lato-Regular.ttf';
  static const String _fontBoldAssetPath = 'assets/fonts/Lato-Bold.ttf';
  static const String _hotelName = 'Hotel Costa Norte';
  static const String _reportTitle =
      'Resumo de reservas por professor parceiro';

  final LoadAssetBytes _loadAssetBytes;
  final GetTemporaryDirectoryCallback _getTemporaryDirectory;

  @override
  String buildFileName({
    required PartnerCoachReportDetail detail,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final String coachLabel = _sanitizeFileSegment(detail.coachName);
    return 'resumo_quadras_${coachLabel}_${_formatDateIso(startDate)}_${_formatDateIso(endDate)}.pdf';
  }

  @override
  Future<Uint8List> buildPdfBytes({
    required PartnerCoachReportDetail detail,
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
    final List<CourtBooking> items = List<CourtBooking>.from(detail.bookings)
      ..sort((CourtBooking a, CourtBooking b) {
        final int dateComparison = a.bookingDate.compareTo(b.bookingDate);
        if (dateComparison != 0) {
          return dateComparison;
        }
        return a.startTime.compareTo(b.startTime);
      });

    document.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        header: (pw.Context context) =>
            _buildHeader(logoImage: logoImage, coachName: detail.coachName),
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
              'Detalhe das reservas',
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
              ...items.map(_buildBookingCard),
          ];
        },
      ),
    );

    return document.save();
  }

  @override
  Future<FileSaveResult?> savePdf({
    required PartnerCoachReportDetail detail,
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
    required PartnerCoachReportDetail detail,
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
    required String coachName,
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
                  '$coachName - $_reportTitle',
                  style: const pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Documento preparado para envio ao professor parceiro.',
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
    required PartnerCoachReportDetail detail,
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
            detail.coachName,
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
              _buildOverviewTag('Periodo', _formatDateRange(startDate, endDate)),
              _buildOverviewTag('Emitido em', _formatDateTime(DateTime.now())),
              _buildOverviewTag(
                'Reservas ativas',
                '${detail.summary.scheduledCount}',
              ),
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
          pw.TextSpan(text: value),
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

  pw.Widget _buildSummaryGrid(PartnerCoachReportSummary summary) {
    final List<MapEntry<String, String>> items = <MapEntry<String, String>>[
      MapEntry<String, String>('Reservas', '${summary.scheduledCount}'),
      MapEntry<String, String>('Pagas', '${summary.paidCount}'),
      MapEntry<String, String>('Pendentes', '${summary.pendingCount}'),
      MapEntry<String, String>('Horas', '${summary.totalHours.toStringAsFixed(1)} h'),
      MapEntry<String, String>('Quadra', _formatCurrency(summary.courtAmount)),
      MapEntry<String, String>(
        'Materiais',
        _formatCurrency(summary.materialsAmount),
      ),
      MapEntry<String, String>('Total', _formatCurrency(summary.totalAmount)),
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
                    item.value,
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
        'Nao existem reservas para o periodo informado.',
        style: const pw.TextStyle(fontSize: 11),
      ),
    );
  }

  pw.Widget _buildBookingCard(CourtBooking booking) {
    final bool cancelled = booking.status == CourtBookingStatus.cancelled;
    final String paymentLabel = _buildPaymentLabel(booking);
    final PdfColor accentColor = cancelled
        ? PdfColors.red700
        : booking.paid
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
                    booking.customerName,
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
                    _statusLabel(booking),
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
              'Data: ${_formatDate(booking.bookingDate)} | Horario: ${booking.startTime.substring(0, 5)} - ${booking.endTime.substring(0, 5)}',
              style: const pw.TextStyle(fontSize: 10.5),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              'Referencia: ${_fallback(booking.customerReference)} | Tipo: ${booking.customerType.label} | Periodo: ${booking.pricingPeriod.label}',
              style: const pw.TextStyle(fontSize: 10.5),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              'Quadra: ${_formatCurrency(booking.courtAmount)} | Materiais: ${_formatCurrency(booking.materialsAmount)} | Total: ${_formatCurrency(booking.totalAmount)}',
              style: const pw.TextStyle(fontSize: 10.5),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              'Pagamento: $paymentLabel',
              style: const pw.TextStyle(fontSize: 10.5),
            ),
            if (booking.materials.isNotEmpty) ...<pw.Widget>[
              pw.SizedBox(height: 3),
              pw.Text(
                'Itens: ${booking.materials.map<String>(_formatMaterialItem).join(' | ')}',
                style: const pw.TextStyle(fontSize: 10.5),
              ),
            ],
            if ((booking.paymentNotes ?? '').trim().isNotEmpty) ...<pw.Widget>[
              pw.SizedBox(height: 3),
              pw.Text(
                'Observacoes do pagamento: ${booking.paymentNotes!.trim()}',
                style: const pw.TextStyle(fontSize: 10.5),
              ),
            ],
            if ((booking.cancellationNotes ?? '').trim().isNotEmpty) ...<
              pw.Widget
            >[
              pw.SizedBox(height: 3),
              pw.Text(
                'Motivo do cancelamento: ${booking.cancellationNotes!.trim()}',
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

  static String _buildPaymentLabel(CourtBooking booking) {
    if (booking.status == CourtBookingStatus.cancelled) {
      return 'Cancelada';
    }
    if (!booking.paid) {
      return 'Pendente';
    }
    final String method = booking.paymentMethod?.label ?? 'Meio nao informado';
    final String date = booking.paymentDate == null
        ? 'data nao informada'
        : _formatDate(booking.paymentDate!);
    return 'Pago em $date via $method';
  }

  static String _statusLabel(CourtBooking booking) {
    if (booking.status == CourtBookingStatus.cancelled) {
      return 'Cancelada';
    }
    return booking.paid ? 'Pago' : 'Pendente';
  }

  static String _formatMaterialItem(CourtBookingMaterial item) {
    return '${item.materialLabel} x${item.quantity}';
  }

  static String _fallback(String value) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? '-' : trimmed;
  }

  static String _sanitizeFileSegment(String rawValue) {
    final String normalized = rawValue
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return normalized.isEmpty ? 'professor_parceiro' : normalized;
  }
}
