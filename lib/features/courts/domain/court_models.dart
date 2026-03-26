enum CourtCustomerType {
  guest('GUEST', 'Hospede'),
  vip('VIP', 'VIP'),
  external('EXTERNAL', 'Externo'),
  partnerCoach('PARTNER_COACH', 'Professor parceiro');

  const CourtCustomerType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static CourtCustomerType tryParse(String? rawValue) {
    for (final CourtCustomerType value in CourtCustomerType.values) {
      if (value.apiValue == rawValue) {
        return value;
      }
    }
    return CourtCustomerType.guest;
  }
}

enum CourtPricingPeriod {
  day('DAY', 'Diurno'),
  night('NIGHT', 'Noturno');

  const CourtPricingPeriod(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static CourtPricingPeriod tryParse(String? rawValue) {
    for (final CourtPricingPeriod value in CourtPricingPeriod.values) {
      if (value.apiValue == rawValue) {
        return value;
      }
    }
    return CourtPricingPeriod.day;
  }
}

enum CourtBookingStatus {
  scheduled('SCHEDULED'),
  cancelled('CANCELLED');

  const CourtBookingStatus(this.apiValue);

  final String apiValue;

  static CourtBookingStatus tryParse(String? rawValue) {
    for (final CourtBookingStatus value in CourtBookingStatus.values) {
      if (value.apiValue == rawValue) {
        return value;
      }
    }
    return CourtBookingStatus.scheduled;
  }
}

enum CourtPaymentMethod {
  pix('PIX', 'Pix'),
  card('CARD', 'Cartao'),
  cash('CASH', 'Dinheiro'),
  courtesy('COURTESY', 'Cortesia'),
  transfer('TRANSFER', 'Transferencia');

  const CourtPaymentMethod(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static CourtPaymentMethod? tryParse(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) {
      return null;
    }
    for (final CourtPaymentMethod value in CourtPaymentMethod.values) {
      if (value.apiValue == rawValue) {
        return value;
      }
    }
    return null;
  }
}

enum CourtMaterialCode {
  racket('RACKET', 'Raqueta'),
  ball('BALL', 'Pelota');

  const CourtMaterialCode(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static CourtMaterialCode tryParse(String? rawValue) {
    for (final CourtMaterialCode value in CourtMaterialCode.values) {
      if (value.apiValue == rawValue) {
        return value;
      }
    }
    return CourtMaterialCode.racket;
  }
}

class CourtRateSetting {
  const CourtRateSetting({
    required this.id,
    required this.customerType,
    required this.pricingPeriod,
    required this.amount,
    required this.active,
    required this.updatedAt,
    required this.updatedBy,
  });

  final int id;
  final CourtCustomerType customerType;
  final CourtPricingPeriod pricingPeriod;
  final double amount;
  final bool active;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory CourtRateSetting.fromJson(Map<String, dynamic> json) {
    return CourtRateSetting(
      id: _readInt(json, 'id') ?? 0,
      customerType: CourtCustomerType.tryParse(
        _readString(json, 'customerType'),
      ),
      pricingPeriod: CourtPricingPeriod.tryParse(
        _readString(json, 'pricingPeriod'),
      ),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      active: json['active'] as bool? ?? false,
      updatedAt: _tryParseDateTime(_readString(json, 'updatedAt')),
      updatedBy: _trimOrNull(_readString(json, 'updatedBy')),
    );
  }
}

class CourtMaterialSetting {
  const CourtMaterialSetting({
    required this.id,
    required this.code,
    required this.label,
    required this.unitPrice,
    required this.chargeGuest,
    required this.chargeVip,
    required this.chargeExternal,
    required this.chargePartnerCoach,
    required this.active,
    required this.updatedAt,
    required this.updatedBy,
  });

  final int id;
  final CourtMaterialCode code;
  final String label;
  final double unitPrice;
  final bool chargeGuest;
  final bool chargeVip;
  final bool chargeExternal;
  final bool chargePartnerCoach;
  final bool active;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory CourtMaterialSetting.fromJson(Map<String, dynamic> json) {
    return CourtMaterialSetting(
      id: _readInt(json, 'id') ?? 0,
      code: CourtMaterialCode.tryParse(_readString(json, 'code')),
      label: _readString(json, 'label') ?? '',
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
      chargeGuest: json['chargeGuest'] as bool? ?? false,
      chargeVip: json['chargeVip'] as bool? ?? false,
      chargeExternal: json['chargeExternal'] as bool? ?? false,
      chargePartnerCoach: json['chargePartnerCoach'] as bool? ?? false,
      active: json['active'] as bool? ?? false,
      updatedAt: _tryParseDateTime(_readString(json, 'updatedAt')),
      updatedBy: _trimOrNull(_readString(json, 'updatedBy')),
    );
  }
}

class CourtPartnerCoach {
  const CourtPartnerCoach({
    required this.id,
    required this.name,
    required this.active,
    required this.updatedAt,
    required this.updatedBy,
  });

  final int id;
  final String name;
  final bool active;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory CourtPartnerCoach.fromJson(Map<String, dynamic> json) {
    return CourtPartnerCoach(
      id: _readInt(json, 'id') ?? 0,
      name: _readString(json, 'name') ?? '',
      active: json['active'] as bool? ?? false,
      updatedAt: _tryParseDateTime(_readString(json, 'updatedAt')),
      updatedBy: _readString(json, 'updatedBy'),
    );
  }
}

class CreateCourtPartnerCoachModel {
  const CreateCourtPartnerCoachModel({required this.name});

  final String name;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'name': name.trim()};
  }
}

class UpdateCourtPartnerCoachModel extends CreateCourtPartnerCoachModel {
  const UpdateCourtPartnerCoachModel({
    required super.name,
    required this.active,
  });

  final bool active;

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{'name': name.trim(), 'active': active};
  }
}

class CourtBookingMaterial {
  const CourtBookingMaterial({
    required this.materialCode,
    required this.materialLabel,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  final CourtMaterialCode materialCode;
  final String materialLabel;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  factory CourtBookingMaterial.fromJson(Map<String, dynamic> json) {
    return CourtBookingMaterial(
      materialCode: CourtMaterialCode.tryParse(
        _readString(json, 'materialCode'),
      ),
      materialLabel: _readString(json, 'materialLabel') ?? '',
      quantity: _readInt(json, 'quantity') ?? 0,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
      totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0,
    );
  }
}

class CourtBooking {
  const CourtBooking({
    required this.id,
    required this.bookingDate,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.customerName,
    required this.customerReference,
    required this.customerType,
    required this.pricingPeriod,
    required this.sunriseEstimate,
    required this.sunsetEstimate,
    required this.courtAmount,
    required this.materialsAmount,
    required this.totalAmount,
    required this.paid,
    required this.paymentMethod,
    required this.paymentDate,
    required this.paymentNotes,
    required this.status,
    required this.cancellationNotes,
    required this.materials,
    required this.createdAt,
    required this.updatedAt,
    required this.cancelledAt,
    required this.createdBy,
    required this.updatedBy,
    required this.cancelledBy,
  });

  final int id;
  final DateTime bookingDate;
  final String startTime;
  final String endTime;
  final int durationMinutes;
  final String customerName;
  final String customerReference;
  final CourtCustomerType customerType;
  final CourtPricingPeriod pricingPeriod;
  final String sunriseEstimate;
  final String sunsetEstimate;
  final double courtAmount;
  final double materialsAmount;
  final double totalAmount;
  final bool paid;
  final CourtPaymentMethod? paymentMethod;
  final DateTime? paymentDate;
  final String? paymentNotes;
  final CourtBookingStatus status;
  final String? cancellationNotes;
  final List<CourtBookingMaterial> materials;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? cancelledAt;
  final String? createdBy;
  final String? updatedBy;
  final String? cancelledBy;

  factory CourtBooking.fromJson(Map<String, dynamic> json) {
    final Object? materialsRaw = json['materials'];
    return CourtBooking(
      id: _readInt(json, 'id') ?? 0,
      bookingDate: DateTime.parse(_readString(json, 'bookingDate') ?? ''),
      startTime: _normalizeTime(_readString(json, 'startTime') ?? '00:00:00'),
      endTime: _normalizeTime(_readString(json, 'endTime') ?? '00:00:00'),
      durationMinutes: _readInt(json, 'durationMinutes') ?? 0,
      customerName: _readString(json, 'customerName') ?? '',
      customerReference: _readString(json, 'customerReference') ?? '',
      customerType: CourtCustomerType.tryParse(
        _readString(json, 'customerType'),
      ),
      pricingPeriod: CourtPricingPeriod.tryParse(
        _readString(json, 'pricingPeriod'),
      ),
      sunriseEstimate: _readString(json, 'sunriseEstimate') ?? '',
      sunsetEstimate: _readString(json, 'sunsetEstimate') ?? '',
      courtAmount: (json['courtAmount'] as num?)?.toDouble() ?? 0,
      materialsAmount: (json['materialsAmount'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      paid: json['paid'] as bool? ?? false,
      paymentMethod: CourtPaymentMethod.tryParse(
        _readString(json, 'paymentMethod'),
      ),
      paymentDate: _tryParseDate(_readString(json, 'paymentDate')),
      paymentNotes: _trimOrNull(_readString(json, 'paymentNotes')),
      status: CourtBookingStatus.tryParse(_readString(json, 'status')),
      cancellationNotes: _trimOrNull(_readString(json, 'cancellationNotes')),
      materials: materialsRaw is List
          ? materialsRaw
                .map<CourtBookingMaterial>(
                  (Object? item) => CourtBookingMaterial.fromJson(_asMap(item)),
                )
                .toList()
          : const <CourtBookingMaterial>[],
      createdAt: _tryParseDateTime(_readString(json, 'createdAt')),
      updatedAt: _tryParseDateTime(_readString(json, 'updatedAt')),
      cancelledAt: _tryParseDateTime(_readString(json, 'cancelledAt')),
      createdBy: _trimOrNull(_readString(json, 'createdBy')),
      updatedBy: _trimOrNull(_readString(json, 'updatedBy')),
      cancelledBy: _trimOrNull(_readString(json, 'cancelledBy')),
    );
  }

  double get durationHours => durationMinutes / 60;
}

class CourtSummaryReport {
  const CourtSummaryReport({
    required this.scheduledCount,
    required this.cancelledCount,
    required this.paidCount,
    required this.pendingCount,
    required this.totalHours,
    required this.guestHours,
    required this.vipHours,
    required this.externalHours,
    required this.partnerCoachHours,
    required this.paidAmount,
    required this.pendingAmount,
    required this.courtAmount,
    required this.materialsAmount,
    required this.expectedAmount,
    required this.averageTicket,
    required this.customerTypeBreakdown,
    required this.pricingPeriodBreakdown,
    required this.paymentMethodBreakdown,
  });

  final int scheduledCount;
  final int cancelledCount;
  final int paidCount;
  final int pendingCount;
  final double totalHours;
  final double guestHours;
  final double vipHours;
  final double externalHours;
  final double partnerCoachHours;
  final double paidAmount;
  final double pendingAmount;
  final double courtAmount;
  final double materialsAmount;
  final double expectedAmount;
  final double averageTicket;
  final List<CourtSummaryBreakdown> customerTypeBreakdown;
  final List<CourtSummaryBreakdown> pricingPeriodBreakdown;
  final List<CourtSummaryBreakdown> paymentMethodBreakdown;

  factory CourtSummaryReport.fromJson(Map<String, dynamic> json) {
    final Object? customerTypeBreakdownRaw = json['customerTypeBreakdown'];
    final Object? pricingPeriodBreakdownRaw = json['pricingPeriodBreakdown'];
    final Object? paymentMethodBreakdownRaw = json['paymentMethodBreakdown'];
    return CourtSummaryReport(
      scheduledCount: _readInt(json, 'scheduledCount') ?? 0,
      cancelledCount: _readInt(json, 'cancelledCount') ?? 0,
      paidCount: _readInt(json, 'paidCount') ?? 0,
      pendingCount: _readInt(json, 'pendingCount') ?? 0,
      totalHours: (json['totalHours'] as num?)?.toDouble() ?? 0,
      guestHours: (json['guestHours'] as num?)?.toDouble() ?? 0,
      vipHours: (json['vipHours'] as num?)?.toDouble() ?? 0,
      externalHours: (json['externalHours'] as num?)?.toDouble() ?? 0,
      partnerCoachHours: (json['partnerCoachHours'] as num?)?.toDouble() ?? 0,
      paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0,
      pendingAmount: (json['pendingAmount'] as num?)?.toDouble() ?? 0,
      courtAmount: (json['courtAmount'] as num?)?.toDouble() ?? 0,
      materialsAmount: (json['materialsAmount'] as num?)?.toDouble() ?? 0,
      expectedAmount: (json['expectedAmount'] as num?)?.toDouble() ?? 0,
      averageTicket: (json['averageTicket'] as num?)?.toDouble() ?? 0,
      customerTypeBreakdown: customerTypeBreakdownRaw is List
          ? customerTypeBreakdownRaw
                .map<CourtSummaryBreakdown>(
                  (Object? item) =>
                      CourtSummaryBreakdown.fromJson(_asMap(item)),
                )
                .toList()
          : const <CourtSummaryBreakdown>[],
      pricingPeriodBreakdown: pricingPeriodBreakdownRaw is List
          ? pricingPeriodBreakdownRaw
                .map<CourtSummaryBreakdown>(
                  (Object? item) =>
                      CourtSummaryBreakdown.fromJson(_asMap(item)),
                )
                .toList()
          : const <CourtSummaryBreakdown>[],
      paymentMethodBreakdown: paymentMethodBreakdownRaw is List
          ? paymentMethodBreakdownRaw
                .map<CourtSummaryBreakdown>(
                  (Object? item) =>
                      CourtSummaryBreakdown.fromJson(_asMap(item)),
                )
                .toList()
          : const <CourtSummaryBreakdown>[],
    );
  }
}

class CourtSummaryBreakdown {
  const CourtSummaryBreakdown({
    required this.code,
    required this.label,
    required this.scheduledCount,
    required this.paidCount,
    required this.pendingCount,
    required this.totalHours,
    required this.courtAmount,
    required this.materialsAmount,
    required this.totalAmount,
  });

  final String code;
  final String label;
  final int scheduledCount;
  final int paidCount;
  final int pendingCount;
  final double totalHours;
  final double courtAmount;
  final double materialsAmount;
  final double totalAmount;

  factory CourtSummaryBreakdown.fromJson(Map<String, dynamic> json) {
    return CourtSummaryBreakdown(
      code: _readString(json, 'code') ?? '',
      label: _readString(json, 'label') ?? '',
      scheduledCount: _readInt(json, 'scheduledCount') ?? 0,
      paidCount: _readInt(json, 'paidCount') ?? 0,
      pendingCount: _readInt(json, 'pendingCount') ?? 0,
      totalHours: (json['totalHours'] as num?)?.toDouble() ?? 0,
      courtAmount: (json['courtAmount'] as num?)?.toDouble() ?? 0,
      materialsAmount: (json['materialsAmount'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class CreateCourtBookingModel {
  const CreateCourtBookingModel({
    required this.bookingDate,
    required this.startTime,
    required this.endTime,
    required this.customerName,
    required this.customerReference,
    required this.customerType,
    required this.paid,
    required this.paymentMethod,
    required this.paymentDate,
    required this.paymentNotes,
    required this.materials,
  });

  final String bookingDate;
  final String startTime;
  final String endTime;
  final String customerName;
  final String customerReference;
  final CourtCustomerType customerType;
  final bool paid;
  final CourtPaymentMethod? paymentMethod;
  final String? paymentDate;
  final String? paymentNotes;
  final List<CreateCourtBookingMaterialModel> materials;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'bookingDate': bookingDate,
      'startTime': startTime,
      'endTime': endTime,
      'customerName': customerName,
      'customerReference': customerReference,
      'customerType': customerType.apiValue,
      'paid': paid,
      'paymentMethod': paymentMethod?.apiValue,
      'paymentDate': paymentDate,
      'paymentNotes': _trimOrNull(paymentNotes),
      'materials': materials
          .map<Map<String, dynamic>>(
            (CreateCourtBookingMaterialModel item) => item.toJson(),
          )
          .toList(),
    };
  }
}

class CreateCourtBookingMaterialModel {
  const CreateCourtBookingMaterialModel({
    required this.materialCode,
    required this.quantity,
  });

  final CourtMaterialCode materialCode;
  final int quantity;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'materialCode': materialCode.apiValue,
      'quantity': quantity,
    };
  }
}

class UpdateCourtBookingModel extends CreateCourtBookingModel {
  const UpdateCourtBookingModel({
    required super.bookingDate,
    required super.startTime,
    required super.endTime,
    required super.customerName,
    required super.customerReference,
    required super.customerType,
    required super.paid,
    required super.paymentMethod,
    required super.paymentDate,
    required super.paymentNotes,
    required super.materials,
  });
}

class UpdateCourtPaymentModel {
  const UpdateCourtPaymentModel({
    required this.paymentMethod,
    required this.paymentDate,
    required this.paymentNotes,
  });

  final CourtPaymentMethod paymentMethod;
  final String paymentDate;
  final String? paymentNotes;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'paymentMethod': paymentMethod.apiValue,
      'paymentDate': paymentDate,
      'paymentNotes': _trimOrNull(paymentNotes),
    };
  }
}

class CancelCourtBookingModel {
  const CancelCourtBookingModel({required this.cancellationNotes});

  final String cancellationNotes;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'cancellationNotes': _trimOrNull(cancellationNotes),
    };
  }
}

class UpdateCourtRateSettingModel {
  const UpdateCourtRateSettingModel({
    required this.amount,
    required this.active,
  });

  final double amount;
  final bool active;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'amount': amount, 'active': active};
  }
}

class UpdateCourtMaterialSettingModel {
  const UpdateCourtMaterialSettingModel({
    required this.label,
    required this.unitPrice,
    required this.chargeGuest,
    required this.chargeVip,
    required this.chargeExternal,
    required this.chargePartnerCoach,
    required this.active,
  });

  final String label;
  final double unitPrice;
  final bool chargeGuest;
  final bool chargeVip;
  final bool chargeExternal;
  final bool chargePartnerCoach;
  final bool active;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'label': label,
      'unitPrice': unitPrice,
      'chargeGuest': chargeGuest,
      'chargeVip': chargeVip,
      'chargeExternal': chargeExternal,
      'chargePartnerCoach': chargePartnerCoach,
      'active': active,
    };
  }
}

String _normalizeTime(String rawValue) {
  if (rawValue.length >= 8) {
    return rawValue.substring(0, 8);
  }
  if (rawValue.length == 5) {
    return '$rawValue:00';
  }
  return rawValue;
}

String? _trimOrNull(String? value) {
  if (value == null) {
    return null;
  }
  final String normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

DateTime? _tryParseDate(String? rawValue) {
  if (rawValue == null || rawValue.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(rawValue);
}

DateTime? _tryParseDateTime(String? rawValue) {
  if (rawValue == null || rawValue.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(rawValue);
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is! Map) {
    return const <String, dynamic>{};
  }
  return value.map<String, dynamic>(
    (Object? key, Object? mapValue) =>
        MapEntry<String, dynamic>(key.toString(), mapValue),
  );
}

String? _readString(Map<String, dynamic>? json, String key) {
  final Object? value = json?[key];
  return value is String ? value : null;
}

int? _readInt(Map<String, dynamic>? json, String key) {
  final Object? value = json?[key];
  return value is num ? value.toInt() : null;
}
