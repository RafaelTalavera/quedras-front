import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/files/file_bytes_saver.dart';
import '../../../core/files/file_save_result.dart';
import '../domain/maintenance_models.dart';

typedef LoadAssetBytes = Future<Uint8List> Function(String assetPath);
typedef GetTemporaryDirectoryCallback = Future<Directory> Function();

abstract interface class MaintenanceDailyReportPdfExporter {
  String buildFileName({required DateTime date});

  Future<Uint8List> buildPdfBytes({
    required DateTime date,
    required MaintenanceDailyExecutiveReport report,
  });

  Future<FileSaveResult?> savePdf({
    required DateTime date,
    required MaintenanceDailyExecutiveReport report,
  });

  Future<File> createTemporaryPdf({
    required DateTime date,
    required MaintenanceDailyExecutiveReport report,
  });
}

final class DefaultMaintenanceDailyReportPdfExporter
    implements MaintenanceDailyReportPdfExporter {
  DefaultMaintenanceDailyReportPdfExporter({
    LoadAssetBytes? loadAssetBytes,
    GetTemporaryDirectoryCallback? getTemporaryDirectoryCallback,
  }) : _loadAssetBytes = loadAssetBytes ?? _defaultLoadAssetBytes,
       _getTemporaryDirectory =
           getTemporaryDirectoryCallback ?? getTemporaryDirectory;

  static const String _fontRegularAssetPath = 'assets/fonts/Lato-Regular.ttf';
  static const String _fontBoldAssetPath = 'assets/fonts/Lato-Bold.ttf';
  static const String _hotelName = 'Hotel Costa Norte';
  static const String _reportTitle =
      'Resumo executivo de ordens abertas de manutencao';

  static final PdfColor _inkColor = PdfColor.fromHex('#000000');
  static final PdfColor _mutedColor = PdfColor.fromHex('#4A4A4A');
  static final PdfColor _borderColor = PdfColor.fromHex('#9A9A9A');

  final LoadAssetBytes _loadAssetBytes;
  final GetTemporaryDirectoryCallback _getTemporaryDirectory;

  @override
  String buildFileName({required DateTime date}) {
    return 'ordens_abertas_manutencao_${_formatDateIso(date)}.pdf';
  }

  @override
  Future<Uint8List> buildPdfBytes({
    required DateTime date,
    required MaintenanceDailyExecutiveReport report,
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

    final List<MaintenanceOrder> carryOverOrders =
        List<MaintenanceOrder>.of(report.carryOverOrders)
          ..sort((MaintenanceOrder a, MaintenanceOrder b) {
            return a.referenceDate.compareTo(b.referenceDate);
          });
    final List<MaintenanceOrder> dayOpenOrders =
        List<MaintenanceOrder>.of(report.dayOpenOrders)
          ..sort((MaintenanceOrder a, MaintenanceOrder b) {
            return a.referenceDate.compareTo(b.referenceDate);
          });
    final List<MaintenanceOrder> openOrders = <MaintenanceOrder>[
      ...carryOverOrders,
      ...dayOpenOrders,
    ];
    final DateTime generatedAt = DateTime.now();
    final int guestCount = openOrders
        .where((MaintenanceOrder order) => order.hasGuestContext)
        .length;

    final pw.PageTheme pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
    );

    document.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        header: (pw.Context context) =>
            _buildHeader(date: date, generatedAt: generatedAt),
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
                _hotelName,
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
              date: date,
              generatedAt: generatedAt,
              dayOrdersCount: report.dayOpenCount,
              openOrdersCount: report.totalOpenCount,
              carryOverOpenCount: report.carryOverOpenCount,
            ),
            pw.SizedBox(height: 16),
            _buildMetricsGrid(
              openOrdersCount: report.totalOpenCount,
              scheduledCount: report.scheduledCount,
              inProgressCount: report.inProgressCount,
              urgentCount: report.urgentCount,
              unassignedCount: report.unassignedCount,
              guestCount: guestCount,
            ),
            pw.SizedBox(height: 18),
            if (openOrders.isEmpty) _buildEmptyState(),
            if (carryOverOrders.isNotEmpty) ...<pw.Widget>[
              _buildSectionTitle(
                'Pendentes de dias anteriores',
                'Ordens ainda abertas antes da data selecionada.',
              ),
              ...carryOverOrders.map(_buildOrderCard),
              pw.SizedBox(height: 14),
            ],
            if (dayOpenOrders.isNotEmpty) ...<pw.Widget>[
              _buildSectionTitle(
                'Ordens abertas do dia',
                'Relacao consolidada das ordens abertas registradas ou agendadas para a data selecionada.',
              ),
              ...dayOpenOrders.map(_buildOrderCard),
            ],
          ];
        },
      ),
    );

    return document.save();
  }

  @override
  Future<FileSaveResult?> savePdf({
    required DateTime date,
    required MaintenanceDailyExecutiveReport report,
  }) async {
    final Uint8List bytes = await buildPdfBytes(date: date, report: report);
    return saveFileBytes(
      bytes: bytes,
      dialogTitle: 'Salvar resumo diario em PDF',
      fileName: buildFileName(date: date),
      mimeType: 'application/pdf',
      allowedExtensions: const <String>['pdf'],
    );
  }

  @override
  Future<File> createTemporaryPdf({
    required DateTime date,
    required MaintenanceDailyExecutiveReport report,
  }) async {
    final Uint8List bytes = await buildPdfBytes(date: date, report: report);
    final Directory directory = await _getTemporaryDirectory();
    final File file = File(
      '${directory.path}${Platform.pathSeparator}${buildFileName(date: date)}',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<Uint8List> _defaultLoadAssetBytes(String assetPath) async {
    final ByteData data = await rootBundle.load(assetPath);
    return data.buffer.asUint8List();
  }

  pw.Widget _buildHeader({
    required DateTime date,
    required DateTime generatedAt,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 14),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: _borderColor, width: 0.8),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(
            _hotelName,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: _inkColor,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            _reportTitle,
            style: pw.TextStyle(
              fontSize: 17,
              fontWeight: pw.FontWeight.bold,
              color: _inkColor,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            'Dia ${_formatDatePt(date)} • Emitido em ${_formatDateTimePt(generatedAt)}',
            style: pw.TextStyle(fontSize: 9.5, color: _mutedColor),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildOverview({
    required DateTime date,
    required DateTime generatedAt,
    required int dayOrdersCount,
    required int openOrdersCount,
    required int carryOverOpenCount,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderColor, width: 0.7),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(
            'Pantallazo ejecutivo',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: _inkColor,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Este reporte consolida las ordens abertas de manutencao de ${_formatDatePt(date)}. Abertas do dia: $dayOrdersCount. Pendentes operacionais: $openOrdersCount. Arrastre anterior: $carryOverOpenCount.',
            style: pw.TextStyle(
              fontSize: 9.5,
              color: _mutedColor,
              lineSpacing: 1.4,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Gerado automaticamente em ${_formatDateTimePt(generatedAt)}.',
            style: pw.TextStyle(fontSize: 9, color: _mutedColor),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildMetricsGrid({
    required int openOrdersCount,
    required int scheduledCount,
    required int inProgressCount,
    required int urgentCount,
    required int unassignedCount,
    required int guestCount,
  }) {
    final List<MapEntry<String, String>> metrics = <MapEntry<String, String>>[
      MapEntry<String, String>('Ordens abertas', '$openOrdersCount'),
      MapEntry<String, String>('Agendadas', '$scheduledCount'),
      MapEntry<String, String>('Em andamento', '$inProgressCount'),
      MapEntry<String, String>('Urgentes', '$urgentCount'),
      MapEntry<String, String>('Sem prestador', '$unassignedCount'),
      MapEntry<String, String>('Com hospede', '$guestCount'),
    ];

    return pw.Wrap(
      spacing: 8,
      runSpacing: 8,
      children: metrics
          .map(
            (MapEntry<String, String> metric) => pw.Container(
              width: 165,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _borderColor, width: 0.7),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: <pw.Widget>[
                  pw.Text(
                    metric.key,
                    style: pw.TextStyle(fontSize: 8.5, color: _mutedColor),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    metric.value,
                    style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                      color: _inkColor,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  pw.Widget _buildSectionTitle(String title, String subtitle) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: _inkColor,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          subtitle,
          style: pw.TextStyle(fontSize: 9.5, color: _mutedColor),
        ),
        pw.SizedBox(height: 10),
      ],
    );
  }

  pw.Widget _buildOrderCard(MaintenanceOrder order) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderColor, width: 0.7),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: <pw.Widget>[
                    pw.Text(
                      order.title,
                      style: pw.TextStyle(
                        fontSize: 11.5,
                        fontWeight: pw.FontWeight.bold,
                        color: _inkColor,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      '${order.locationDisplayLabel} • ${order.providerLabel}',
                      style: pw.TextStyle(fontSize: 9.2, color: _mutedColor),
                    ),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _borderColor, width: 0.6),
                ),
                child: pw.Text(
                  order.status.label,
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _inkColor,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <pw.Widget>[
              _buildInlineTag('Servico: ${order.serviceLabel}'),
              _buildInlineTag('Prioridade: ${order.priority.label}'),
              _buildInlineTag('Operacao: ${order.businessPriority.label}'),
              _buildInlineTag('Agenda: ${_scheduleLabel(order)}'),
              if (order.assignedUsername != null &&
                  order.assignedUsername!.trim().isNotEmpty)
                _buildInlineTag('Atribuido a ${order.assignedUsername!}'),
              if (order.guestLabel != null)
                _buildInlineTag('Hospede: ${order.guestLabel!}'),
            ],
          ),
          if (order.description != null && order.description!.trim().isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 8),
              child: pw.Text(
                order.description!.trim(),
                style: pw.TextStyle(fontSize: 9, color: _mutedColor),
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _buildInlineTag(String label) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderColor, width: 0.6),
      ),
      child: pw.Text(
        label,
        style: pw.TextStyle(fontSize: 8.3, color: _mutedColor),
      ),
    );
  }

  pw.Widget _buildEmptyState() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderColor, width: 0.7),
      ),
      child: pw.Text(
        'Nao ha ordens abertas para o dia selecionado.',
        style: pw.TextStyle(fontSize: 10, color: _mutedColor),
      ),
    );
  }
}

String _scheduleLabel(MaintenanceOrder order) {
  if (order.scheduledStartAt == null || order.scheduledEndAt == null) {
    return 'Sem agenda definida';
  }
  return '${_formatDateTimePt(order.scheduledStartAt!)} a ${_formatTime(order.scheduledEndAt!)}';
}

String _formatDateIso(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _formatDatePt(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String _formatDateTimePt(DateTime value) =>
    '${_formatDatePt(value)} ${_formatTime(value)}';

String _formatTime(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
