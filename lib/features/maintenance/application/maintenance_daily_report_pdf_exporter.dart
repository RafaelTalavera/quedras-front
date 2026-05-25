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
      'Folha de rota de ordens abertas de manutencao';

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

    final List<MaintenanceOrder> openOrders = report.allOpenOrders;
    final DateTime generatedAt = DateTime.now();
    final int guestCount = openOrders
        .where((MaintenanceOrder order) => order.hasGuestContext)
        .length;

    final pw.PageTheme pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(22, 24, 22, 20),
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
                style: pw.TextStyle(fontSize: 8.3, color: _mutedColor),
              ),
              pw.Text(
                'Pagina ${context.pageNumber} de ${context.pagesCount}',
                style: pw.TextStyle(fontSize: 8.3, color: _mutedColor),
              ),
            ],
          ),
        ),
        build: (pw.Context context) {
          return <pw.Widget>[
            _buildSummaryStrip(
              dayOrdersCount: report.dayOpenCount,
              openOrdersCount: report.totalOpenCount,
              carryOverOpenCount: report.carryOverOpenCount,
              scheduledCount: report.scheduledCount,
              inProgressCount: report.inProgressCount,
              urgentCount: report.urgentCount,
              unassignedCount: report.unassignedCount,
              guestCount: guestCount,
            ),
            pw.SizedBox(height: 10),
            _buildRouteSheetGuide(date: date, generatedAt: generatedAt),
            pw.SizedBox(height: 10),
            if (openOrders.isEmpty) _buildEmptyState(),
            if (openOrders.isNotEmpty) _buildRouteSheetTable(openOrders, date),
            if (openOrders.isNotEmpty) ...<pw.Widget>[
              pw.SizedBox(height: 8),
              _buildLegend(),
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
      padding: const pw.EdgeInsets.only(bottom: 12),
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
              fontSize: 10.5,
              fontWeight: pw.FontWeight.bold,
              color: _inkColor,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            _reportTitle,
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
              color: _inkColor,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            'Dia ${_formatDatePt(date)} | Emitido em ${_formatDateTimePt(generatedAt)}',
            style: pw.TextStyle(fontSize: 9, color: _mutedColor),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryStrip({
    required int dayOrdersCount,
    required int openOrdersCount,
    required int carryOverOpenCount,
    required int scheduledCount,
    required int inProgressCount,
    required int urgentCount,
    required int unassignedCount,
    required int guestCount,
  }) {
    final List<MapEntry<String, String>> metrics = <MapEntry<String, String>>[
      MapEntry<String, String>('Abertas', '$openOrdersCount'),
      MapEntry<String, String>('Do dia', '$dayOrdersCount'),
      MapEntry<String, String>('Arrastre', '$carryOverOpenCount'),
      MapEntry<String, String>('Agendadas', '$scheduledCount'),
      MapEntry<String, String>('Andamento', '$inProgressCount'),
      MapEntry<String, String>('Urgentes', '$urgentCount'),
      MapEntry<String, String>('Sem prest.', '$unassignedCount'),
      MapEntry<String, String>('Hospede', '$guestCount'),
    ];

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderColor, width: 0.7),
      ),
      child: pw.Wrap(
        spacing: 6,
        runSpacing: 6,
        children: metrics
            .map(
              (MapEntry<String, String> metric) => pw.Container(
                width: 62,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 5,
                ),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _borderColor, width: 0.6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: <pw.Widget>[
                    pw.Text(
                      metric.key,
                      style: pw.TextStyle(fontSize: 7.2, color: _mutedColor),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      metric.value,
                      style: pw.TextStyle(
                        fontSize: 11.5,
                        fontWeight: pw.FontWeight.bold,
                        color: _inkColor,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  pw.Widget _buildRouteSheetGuide({
    required DateTime date,
    required DateTime generatedAt,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderColor, width: 0.7),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          pw.Expanded(
            child: pw.Text(
              'Hoja de ruta operativa para execucao rapida. Cada linha resume uma ordem com foco em faixa, local, tarefa e responsavel.',
              style: pw.TextStyle(fontSize: 8.4, color: _mutedColor),
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Text(
            'Corte ${_formatDatePt(date)} | ${_formatTime(generatedAt)}',
            style: pw.TextStyle(fontSize: 8.2, color: _mutedColor),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildRouteSheetTable(
    List<MaintenanceOrder> orders,
    DateTime selectedDate,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: _borderColor, width: 0.55),
      columnWidths: <int, pw.TableColumnWidth>{
        0: const pw.FixedColumnWidth(56),
        1: const pw.FixedColumnWidth(118),
        2: const pw.FlexColumnWidth(2.1),
        3: const pw.FlexColumnWidth(1.45),
        4: const pw.FlexColumnWidth(1.4),
      },
      children: <pw.TableRow>[
        _buildTableHeaderRow(),
        ...orders.map(
          (MaintenanceOrder order) => _buildTableDataRow(
            order: order,
            selectedDate: selectedDate,
          ),
        ),
      ],
    );
  }

  pw.TableRow _buildTableHeaderRow() {
    return pw.TableRow(
      children: <pw.Widget>[
        _buildTableCell('Bloco', bold: true, fontSize: 8),
        _buildTableCell('Local', bold: true, fontSize: 8),
        _buildTableCell('Tarefa', bold: true, fontSize: 8),
        _buildTableCell('Execucao', bold: true, fontSize: 8),
        _buildTableCell('Contexto', bold: true, fontSize: 8),
      ],
    );
  }

  pw.TableRow _buildTableDataRow({
    required MaintenanceOrder order,
    required DateTime selectedDate,
  }) {
    return pw.TableRow(
      verticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: <pw.Widget>[
        _buildTableCell(
          _compactTimeBlock(order, selectedDate),
          fontSize: 7.6,
        ),
        _buildTableCell(
          _truncate(order.locationDisplayLabel, 34),
          fontSize: 7.8,
        ),
        _buildTableCell(
          _compactTaskLabel(order),
          fontSize: 7.8,
        ),
        _buildTableCell(
          _compactExecutionLabel(order),
          fontSize: 7.6,
        ),
        _buildTableCell(
          _compactContextLabel(order, selectedDate),
          fontSize: 7.4,
          color: _mutedColor,
        ),
      ],
    );
  }

  pw.Widget _buildLegend() {
    return pw.Text(
      'Bloco: DIA = aberta do dia, ARR = pendencia anterior, PEND = sem faixa definida. Contexto resume status, prioridade, duracao e apoio de hospede quando existir.',
      style: pw.TextStyle(fontSize: 7.8, color: _mutedColor),
    );
  }

  pw.Widget _buildTableCell(
    String text, {
    bool bold = false,
    double fontSize = 8,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4.5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? _inkColor,
          lineSpacing: 1.2,
        ),
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

String _compactTimeBlock(MaintenanceOrder order, DateTime selectedDate) {
  final bool isCarryOver = !_isSameDate(order.referenceDate, selectedDate);
  final String origin = isCarryOver ? 'ARR' : 'DIA';
  if (order.scheduledStartAt != null && order.scheduledEndAt != null) {
    return '$origin\n${_formatTime(order.scheduledStartAt!)}-${_formatTime(order.scheduledEndAt!)}';
  }
  return '$origin\nPEND';
}

String _compactTaskLabel(MaintenanceOrder order) {
  final String base = _truncate(order.title.trim(), 48);
  final String? description = order.description == null
      ? null
      : _truncate(order.description!.trim(), 52);
  if (description == null || description.isEmpty) {
    return base;
  }
  return '$base\n$description';
}

String _compactExecutionLabel(MaintenanceOrder order) {
  final List<String> lines = <String>[
    _truncate(order.providerLabel, 28),
    _truncate(order.serviceLabel, 28),
  ];
  if (order.assignedUsername != null && order.assignedUsername!.trim().isNotEmpty) {
    lines.add('Resp. ${_truncate(order.assignedUsername!.trim(), 22)}');
  }
  return lines.join('\n');
}

String _compactContextLabel(MaintenanceOrder order, DateTime selectedDate) {
  final List<String> parts = <String>[
    order.status.label,
    order.priority.label,
    if (order.estimatedExecutionMinutes != null)
      '${order.estimatedExecutionMinutes} min',
    if (!_isSameDate(order.referenceDate, selectedDate))
      'Desde ${_formatDatePt(order.referenceDate)}',
  ];

  final String source = order.guestLabel != null
      ? 'Hospede ${_truncate(order.guestLabel!, 24)}'
      : order.requestedByRole != null && order.requestedByRole!.trim().isNotEmpty
      ? 'Origem ${_truncate(order.requestedByRole!.trim(), 20)}'
      : order.requestOrigin.label;
  parts.add(source);

  return _truncate(parts.join(' | '), 70);
}

bool _isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _formatDateIso(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _formatDatePt(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String _formatDateTimePt(DateTime value) =>
    '${_formatDatePt(value)} ${_formatTime(value)}';

String _formatTime(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _truncate(String value, int maxLength) {
  final String normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.length <= maxLength) {
    return normalized;
  }
  if (maxLength <= 1) {
    return normalized.substring(0, maxLength);
  }
  return '${normalized.substring(0, maxLength - 1)}...';
}
