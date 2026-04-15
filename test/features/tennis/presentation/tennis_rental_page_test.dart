import 'dart:io';
import 'dart:typed_data';

import 'package:costanorte/features/courts/application/court_app_service.dart';
import 'package:costanorte/features/courts/application/partner_coach_report_pdf_exporter.dart';
import 'package:costanorte/features/courts/domain/court_models.dart';
import 'package:costanorte/features/tennis/presentation/tennis_rental_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'TennisRentalPage muestra detalle de profesor parceiro con acciones de PDF',
    (WidgetTester tester) async {
      final _FakeCourtAppService service = _FakeCourtAppService();
      final _FakePartnerCoachReportPdfExporter exporter =
          _FakePartnerCoachReportPdfExporter();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TennisRentalPage(
              courtAppService: service,
              partnerCoachReportPdfExporter: exporter,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Professores parceiros por nome'), findsOneWidget);
      expect(find.text('Carlos'), findsOneWidget);

      final Finder coachCell = find.text('Carlos');
      await tester.ensureVisible(coachCell);
      await tester.tap(coachCell);
      await tester.pumpAndSettle();

      expect(find.text('Detalhe de Carlos'), findsOneWidget);
      expect(find.text('Baixar PDF'), findsOneWidget);
      expect(find.text('Compartilhar PDF'), findsOneWidget);

      await tester.tap(find.text('Baixar PDF'));
      await tester.pumpAndSettle();

      expect(exporter.savedDetail?.coachName, 'Carlos');
    },
  );
}

final class _FakeCourtAppService implements CourtAppService {
  _FakeCourtAppService()
    : _bookingDate = DateTime(DateTime.now().year, DateTime.now().month, 10);

  final DateTime _bookingDate;

  @override
  Future<List<CourtBooking>> listBookings({
    String? bookingDate,
    String? dateFrom,
    String? dateTo,
    CourtCustomerType? customerType,
    bool? paid,
  }) async {
    final List<CourtBooking> items = <CourtBooking>[
      CourtBooking(
        id: 1,
        bookingDate: _bookingDate,
        startTime: '08:00:00',
        endTime: '09:00:00',
        durationMinutes: 60,
        customerName: 'Carlos',
        customerReference: 'Aula dupla',
        customerType: CourtCustomerType.partnerCoach,
        pricingPeriod: CourtPricingPeriod.day,
        sunriseEstimate: '06:20',
        sunsetEstimate: '17:55',
        courtAmount: 120,
        materialsAmount: 20,
        totalAmount: 140,
        paid: true,
        paymentMethod: CourtPaymentMethod.pix,
        paymentDate: _bookingDate,
        paymentNotes: 'Pago no balcao',
        status: CourtBookingStatus.scheduled,
        cancellationNotes: null,
        materials: const <CourtBookingMaterial>[
          CourtBookingMaterial(
            materialCode: CourtMaterialCode.ball,
            materialLabel: 'Pelota',
            quantity: 2,
            unitPrice: 10,
            totalPrice: 20,
          ),
        ],
        createdAt: _bookingDate,
        updatedAt: _bookingDate,
        cancelledAt: null,
        createdBy: 'tester',
        updatedBy: 'tester',
        cancelledBy: null,
      ),
    ];

    return items.where((CourtBooking item) {
      if (bookingDate != null &&
          bookingDate.isNotEmpty &&
          _formatDate(item.bookingDate) != bookingDate) {
        return false;
      }
      if (customerType != null && item.customerType != customerType) {
        return false;
      }
      if (paid != null && item.paid != paid) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Future<CourtSummaryReport> getSummaryReport({
    required String dateFrom,
    required String dateTo,
  }) async {
    return CourtSummaryReport(
      scheduledCount: 1,
      cancelledCount: 0,
      paidCount: 1,
      pendingCount: 0,
      totalHours: 1,
      guestHours: 0,
      vipHours: 0,
      externalHours: 0,
      partnerCoachHours: 1,
      paidAmount: 140,
      pendingAmount: 0,
      courtAmount: 120,
      materialsAmount: 20,
      expectedAmount: 140,
      averageTicket: 140,
      customerTypeBreakdown: const <CourtSummaryBreakdown>[
        CourtSummaryBreakdown(
          code: 'PARTNER_COACH',
          label: 'Professor parceiro',
          scheduledCount: 1,
          paidCount: 1,
          pendingCount: 0,
          totalHours: 1,
          courtAmount: 120,
          materialsAmount: 20,
          totalAmount: 140,
        ),
      ],
      pricingPeriodBreakdown: const <CourtSummaryBreakdown>[
        CourtSummaryBreakdown(
          code: 'DAY',
          label: 'Diurno',
          scheduledCount: 1,
          paidCount: 1,
          pendingCount: 0,
          totalHours: 1,
          courtAmount: 120,
          materialsAmount: 20,
          totalAmount: 140,
        ),
      ],
      paymentMethodBreakdown: const <CourtSummaryBreakdown>[
        CourtSummaryBreakdown(
          code: 'PIX',
          label: 'Pix',
          scheduledCount: 1,
          paidCount: 1,
          pendingCount: 0,
          totalHours: 1,
          courtAmount: 120,
          materialsAmount: 20,
          totalAmount: 140,
        ),
      ],
    );
  }

  @override
  Future<List<CourtRateSetting>> listRates() async => <CourtRateSetting>[];

  @override
  Future<List<CourtPartnerCoach>> listPartnerCoaches({
    bool activeOnly = true,
  }) async {
    return const <CourtPartnerCoach>[];
  }

  @override
  Future<CourtPartnerCoach> createPartnerCoach(
    CreateCourtPartnerCoachModel input,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<CourtPartnerCoach> updatePartnerCoach(
    int partnerCoachId,
    UpdateCourtPartnerCoachModel input,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<CourtRateSetting> updateRate(
    int rateId,
    UpdateCourtRateSettingModel input,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<List<CourtMaterialSetting>> listMaterials() async =>
      <CourtMaterialSetting>[];

  @override
  Future<CourtMaterialSetting> updateMaterial(
    int materialId,
    UpdateCourtMaterialSettingModel input,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<CourtBooking> createBooking(CreateCourtBookingModel input) {
    throw UnimplementedError();
  }

  @override
  Future<CourtBooking> updateBooking(
    int bookingId,
    UpdateCourtBookingModel input,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<CourtBooking> updatePayment(
    int bookingId,
    UpdateCourtPaymentModel input,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<CourtBooking> cancelBooking(
    int bookingId,
    CancelCourtBookingModel input,
  ) {
    throw UnimplementedError();
  }
}

final class _FakePartnerCoachReportPdfExporter
    implements PartnerCoachReportPdfExporter {
  PartnerCoachReportDetail? savedDetail;

  @override
  String buildFileName({
    required PartnerCoachReportDetail detail,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return 'resumo_${detail.coachName}.pdf';
  }

  @override
  Future<Uint8List> buildPdfBytes({
    required PartnerCoachReportDetail detail,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return Uint8List.fromList(<int>[37, 80, 68, 70]);
  }

  @override
  Future<File> createTemporaryPdf({
    required PartnerCoachReportDetail detail,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'coach-share-',
    );
    final File file = File(
      '${directory.path}${Platform.pathSeparator}${buildFileName(detail: detail, startDate: startDate, endDate: endDate)}',
    );
    await file.writeAsString('pdf');
    return file;
  }

  @override
  Future<File?> savePdf({
    required PartnerCoachReportDetail detail,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    savedDetail = detail;
    final Directory directory = await Directory.systemTemp.createTemp(
      'coach-save-',
    );
    final File file = File(
      '${directory.path}${Platform.pathSeparator}${buildFileName(detail: detail, startDate: startDate, endDate: endDate)}',
    );
    await file.writeAsString('pdf');
    return file;
  }
}

String _formatDate(DateTime date) {
  final String month = date.month.toString().padLeft(2, '0');
  final String day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
