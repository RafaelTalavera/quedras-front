import 'dart:io';
import 'dart:typed_data';

import 'package:costanorte/features/massages/application/massage_provider_report_pdf_exporter.dart';
import 'package:costanorte/features/massages/domain/massage_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'DefaultMassageProviderReportPdfExporter gera bytes de PDF validos',
    () async {
      final DefaultMassageProviderReportPdfExporter exporter =
          DefaultMassageProviderReportPdfExporter(
            loadAssetBytes: _loadPdfAssetBytes,
          );

      final Uint8List bytes = await exporter.buildPdfBytes(
        detail: _detailFixture(),
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 30),
      );

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    },
  );

  test(
    'DefaultMassageProviderReportPdfExporter cria un PDF temporal',
    () async {
      final Directory directory = await Directory.systemTemp.createTemp(
        'massage-report-save-',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final DefaultMassageProviderReportPdfExporter exporter =
          DefaultMassageProviderReportPdfExporter(
            loadAssetBytes: _loadPdfAssetBytes,
            getTemporaryDirectoryCallback: () async => directory,
          );

      final File file = await exporter.createTemporaryPdf(
        detail: _detailFixture(),
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 30),
      );

      expect(file.path, contains(directory.path));
      expect(await file.exists(), isTrue);
      final List<int> bytes = await file.readAsBytes();
      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    },
  );
}

Future<Uint8List> _loadPdfAssetBytes(String assetPath) {
  return File(assetPath).readAsBytes();
}

MassageProviderDetailReport _detailFixture() {
  final DateTime bookingDate = DateTime(2026, 4, 10);
  return MassageProviderDetailReport(
    providerId: 1,
    providerName: 'Danuska',
    providerActive: true,
    summary: MassageProviderSummary(
      providerId: 1,
      providerName: 'Danuska',
      providerActive: true,
      therapistsCount: 1,
      scheduledCount: 2,
      cancelledCount: 1,
      attendedCount: 2,
      paidCount: 1,
      pendingCount: 1,
      grossAmount: 500,
      paidAmount: 250,
      pendingAmount: 250,
      lastBookingAt: bookingDate,
    ),
    items: <MassageProviderReportItem>[
      MassageProviderReportItem(
        bookingId: 1,
        bookingDate: bookingDate,
        startTime: '16:00:00',
        clientName: 'Maria',
        guestReference: 'Apto 202',
        treatment: 'Relaxante',
        therapistId: 101,
        therapistName: 'Danuska',
        amount: 250,
        paid: true,
        paymentMethod: MassagePaymentMethod.card,
        paymentDate: bookingDate,
        paymentNotes: 'Pago na recepcao',
        status: MassageBookingStatus.scheduled,
        cancellationNotes: null,
      ),
      MassageProviderReportItem(
        bookingId: 2,
        bookingDate: DateTime(2026, 4, 12),
        startTime: '17:00:00',
        clientName: 'Ana',
        guestReference: 'Apto 305',
        treatment: 'Drenagem corporal',
        therapistId: 101,
        therapistName: 'Danuska',
        amount: 250,
        paid: false,
        paymentMethod: null,
        paymentDate: null,
        paymentNotes: null,
        status: MassageBookingStatus.scheduled,
        cancellationNotes: null,
      ),
    ],
  );
}
