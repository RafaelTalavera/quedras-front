import 'dart:io';
import 'dart:typed_data';

import 'package:costanorte/features/courts/application/partner_coach_report_pdf_exporter.dart';
import 'package:costanorte/features/courts/domain/court_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DefaultPartnerCoachReportPdfExporter gera bytes de PDF validos', () async {
    final DefaultPartnerCoachReportPdfExporter exporter =
        DefaultPartnerCoachReportPdfExporter(loadAssetBytes: _loadPdfAssetBytes);

    final Uint8List bytes = await exporter.buildPdfBytes(
      detail: _detailFixture(),
      startDate: DateTime(2026, 4, 1),
      endDate: DateTime(2026, 4, 30),
    );

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test(
    'DefaultPartnerCoachReportPdfExporter cria un PDF temporal',
    () async {
      final Directory directory = await Directory.systemTemp.createTemp(
        'partner-coach-report-save-',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final DefaultPartnerCoachReportPdfExporter exporter =
          DefaultPartnerCoachReportPdfExporter(
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

PartnerCoachReportDetail _detailFixture() {
  final DateTime bookingDate = DateTime(2026, 4, 10);
  return PartnerCoachReportDetail(
    coachName: 'Carlos',
    summary: const PartnerCoachReportSummary(
      scheduledCount: 2,
      paidCount: 1,
      pendingCount: 1,
      totalHours: 3,
      courtAmount: 280,
      materialsAmount: 40,
      totalAmount: 320,
    ),
    bookings: <CourtBooking>[
      CourtBooking(
        id: 1,
        bookingDate: bookingDate,
        startTime: '08:00:00',
        endTime: '09:30:00',
        durationMinutes: 90,
        customerName: 'Carlos',
        customerReference: 'Aula dupla',
        customerType: CourtCustomerType.partnerCoach,
        pricingPeriod: CourtPricingPeriod.day,
        sunriseEstimate: '06:20',
        sunsetEstimate: '17:55',
        courtAmount: 140,
        materialsAmount: 20,
        totalAmount: 160,
        paid: true,
        paymentMethod: CourtPaymentMethod.pix,
        paymentDate: bookingDate,
        paymentNotes: 'Pago no balcao',
        status: CourtBookingStatus.scheduled,
        cancellationNotes: null,
        recurrenceGroupId: null,
        recurrenceStartDate: null,
        recurrenceEndDate: null,
        materials: const <CourtBookingMaterial>[
          CourtBookingMaterial(
            materialCode: CourtMaterialCode.ball,
            materialLabel: 'Pelota',
            quantity: 2,
            unitPrice: 10,
            totalPrice: 20,
          ),
        ],
        createdAt: bookingDate,
        updatedAt: bookingDate,
        cancelledAt: null,
        createdBy: 'tester',
        updatedBy: 'tester',
        cancelledBy: null,
      ),
      CourtBooking(
        id: 2,
        bookingDate: DateTime(2026, 4, 12),
        startTime: '18:00:00',
        endTime: '19:00:00',
        durationMinutes: 60,
        customerName: 'Carlos',
        customerReference: 'Treino funcional',
        customerType: CourtCustomerType.partnerCoach,
        pricingPeriod: CourtPricingPeriod.night,
        sunriseEstimate: '06:19',
        sunsetEstimate: '17:56',
        courtAmount: 140,
        materialsAmount: 20,
        totalAmount: 160,
        paid: false,
        paymentMethod: null,
        paymentDate: null,
        paymentNotes: null,
        status: CourtBookingStatus.scheduled,
        cancellationNotes: null,
        recurrenceGroupId: null,
        recurrenceStartDate: null,
        recurrenceEndDate: null,
        materials: const <CourtBookingMaterial>[
          CourtBookingMaterial(
            materialCode: CourtMaterialCode.racket,
            materialLabel: 'Raqueta',
            quantity: 1,
            unitPrice: 20,
            totalPrice: 20,
          ),
        ],
        createdAt: bookingDate,
        updatedAt: bookingDate,
        cancelledAt: null,
        createdBy: 'tester',
        updatedBy: 'tester',
        cancelledBy: null,
      ),
    ],
  );
}
