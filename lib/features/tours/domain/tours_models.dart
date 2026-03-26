enum ToursPaymentMethod {
  pix('PIX', 'Pix'),
  card('CARD', 'Cartao'),
  cash('CASH', 'Dinheiro'),
  transfer('TRANSFER', 'Transferencia');

  const ToursPaymentMethod(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static ToursPaymentMethod? tryParse(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) {
      return null;
    }
    for (final ToursPaymentMethod value in ToursPaymentMethod.values) {
      if (value.apiValue == rawValue) {
        return value;
      }
    }
    return null;
  }
}

enum ToursBookingStatus {
  scheduled('SCHEDULED'),
  cancelled('CANCELLED');

  const ToursBookingStatus(this.apiValue);

  final String apiValue;

  static ToursBookingStatus tryParse(String? rawValue) {
    for (final ToursBookingStatus value in ToursBookingStatus.values) {
      if (value.apiValue == rawValue) {
        return value;
      }
    }
    return ToursBookingStatus.scheduled;
  }
}

enum ToursServiceType {
  tour('TOUR', 'Tour'),
  travel('TRAVEL', 'Viagem');

  const ToursServiceType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static ToursServiceType tryParse(String? rawValue) {
    for (final ToursServiceType value in ToursServiceType.values) {
      if (value.apiValue == rawValue) {
        return value;
      }
    }
    return ToursServiceType.tour;
  }
}

class ToursProvider {
  const ToursProvider({
    required this.id,
    required this.name,
    required this.contact,
    required this.defaultCommissionPercent,
    required this.active,
    required this.updatedAt,
    required this.updatedBy,
  });

  final int id;
  final String name;
  final String contact;
  final double defaultCommissionPercent;
  final bool active;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory ToursProvider.fromJson(Map<String, dynamic> json) {
    return ToursProvider(
      id: _readInt(json, 'id') ?? 0,
      name: _readString(json, 'name') ?? '',
      contact: _readString(json, 'contact') ?? '',
      defaultCommissionPercent:
          (json['defaultCommissionPercent'] as num?)?.toDouble() ??
          (json['commissionPercent'] as num?)?.toDouble() ??
          0,
      active: json['active'] as bool? ?? false,
      updatedAt: _tryParseDateTime(_readString(json, 'updatedAt')),
      updatedBy: _trimOrNull(_readString(json, 'updatedBy')),
    );
  }

  ToursProvider copyWith({
    int? id,
    String? name,
    String? contact,
    double? defaultCommissionPercent,
    bool? active,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return ToursProvider(
      id: id ?? this.id,
      name: name ?? this.name,
      contact: contact ?? this.contact,
      defaultCommissionPercent:
          defaultCommissionPercent ?? this.defaultCommissionPercent,
      active: active ?? this.active,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}

class ToursProviderSummary {
  const ToursProviderSummary({
    required this.providerId,
    required this.providerName,
    required this.providerActive,
    required this.scheduledCount,
    required this.cancelledCount,
    required this.paidCount,
    required this.pendingCount,
    required this.grossAmount,
    required this.paidAmount,
    required this.pendingAmount,
    required this.commissionAmount,
    required this.lastBookingAt,
  });

  final int providerId;
  final String providerName;
  final bool providerActive;
  final int scheduledCount;
  final int cancelledCount;
  final int paidCount;
  final int pendingCount;
  final double grossAmount;
  final double paidAmount;
  final double pendingAmount;
  final double commissionAmount;
  final DateTime? lastBookingAt;

  factory ToursProviderSummary.fromJson(Map<String, dynamic> json) {
    return ToursProviderSummary(
      providerId: _readInt(json, 'providerId') ?? 0,
      providerName: _readString(json, 'providerName') ?? 'Fornecedor',
      providerActive: json['providerActive'] as bool? ?? false,
      scheduledCount: _readInt(json, 'scheduledCount') ?? 0,
      cancelledCount: _readInt(json, 'cancelledCount') ?? 0,
      paidCount: _readInt(json, 'paidCount') ?? 0,
      pendingCount: _readInt(json, 'pendingCount') ?? 0,
      grossAmount: (json['grossAmount'] as num?)?.toDouble() ?? 0,
      paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0,
      pendingAmount: (json['pendingAmount'] as num?)?.toDouble() ?? 0,
      commissionAmount: (json['commissionAmount'] as num?)?.toDouble() ?? 0,
      lastBookingAt: _tryParseDateTime(_readString(json, 'lastBookingAt')),
    );
  }
}

class ToursBooking {
  const ToursBooking({
    required this.id,
    required this.serviceType,
    required this.startAt,
    required this.endAt,
    required this.clientName,
    required this.guestReference,
    required this.providerId,
    required this.providerName,
    required this.providerActive,
    required this.amount,
    required this.commissionPercent,
    required this.commissionAmount,
    required this.description,
    required this.paid,
    required this.paymentMethod,
    required this.paymentDate,
    required this.paymentNotes,
    required this.status,
    required this.cancellationNotes,
    required this.createdAt,
    required this.updatedAt,
    required this.cancelledAt,
    required this.createdBy,
    required this.updatedBy,
    required this.cancelledBy,
  });

  final int id;
  final ToursServiceType serviceType;
  final DateTime startAt;
  final DateTime endAt;
  final String clientName;
  final String guestReference;
  final int providerId;
  final String providerName;
  final bool providerActive;
  final double amount;
  final double commissionPercent;
  final double commissionAmount;
  final String? description;
  final bool paid;
  final ToursPaymentMethod? paymentMethod;
  final DateTime? paymentDate;
  final String? paymentNotes;
  final ToursBookingStatus status;
  final String? cancellationNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? cancelledAt;
  final String? createdBy;
  final String? updatedBy;
  final String? cancelledBy;

  factory ToursBooking.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? provider = _asMapOrNull(json['provider']);
    return ToursBooking(
      id: _readInt(json, 'id') ?? 0,
      serviceType: ToursServiceType.tryParse(_readString(json, 'serviceType')),
      startAt: DateTime.parse(_readString(json, 'startAt') ?? ''),
      endAt: DateTime.parse(_readString(json, 'endAt') ?? ''),
      clientName: _readString(json, 'clientName') ?? '',
      guestReference: _readString(json, 'guestReference') ?? '',
      providerId: _readInt(json, 'providerId') ?? _readInt(provider, 'id') ?? 0,
      providerName:
          _readString(json, 'providerName') ??
          _readString(provider, 'name') ??
          'Fornecedor',
      providerActive:
          (json['providerActive'] as bool?) ??
          (provider?['active'] as bool?) ??
          false,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      commissionPercent: (json['commissionPercent'] as num?)?.toDouble() ?? 0,
      commissionAmount: (json['commissionAmount'] as num?)?.toDouble() ?? 0,
      description: _trimOrNull(_readString(json, 'description')),
      paid: json['paid'] as bool? ?? false,
      paymentMethod: ToursPaymentMethod.tryParse(
        _readString(json, 'paymentMethod'),
      ),
      paymentDate: _tryParseDate(_readString(json, 'paymentDate')),
      paymentNotes: _trimOrNull(_readString(json, 'paymentNotes')),
      status: ToursBookingStatus.tryParse(_readString(json, 'status')),
      cancellationNotes: _trimOrNull(_readString(json, 'cancellationNotes')),
      createdAt: _tryParseDateTime(_readString(json, 'createdAt')),
      updatedAt: _tryParseDateTime(_readString(json, 'updatedAt')),
      cancelledAt: _tryParseDateTime(_readString(json, 'cancelledAt')),
      createdBy: _trimOrNull(_readString(json, 'createdBy')),
      updatedBy: _trimOrNull(_readString(json, 'updatedBy')),
      cancelledBy: _trimOrNull(_readString(json, 'cancelledBy')),
    );
  }
}

class CreateToursBookingModel {
  const CreateToursBookingModel({
    required this.serviceType,
    required this.startAt,
    required this.endAt,
    required this.clientName,
    required this.guestReference,
    required this.providerId,
    required this.amount,
    required this.commissionPercent,
    required this.description,
    required this.paid,
    required this.paymentMethod,
    required this.paymentDate,
    required this.paymentNotes,
  });

  final ToursServiceType serviceType;
  final String startAt;
  final String endAt;
  final String clientName;
  final String guestReference;
  final int providerId;
  final double amount;
  final double commissionPercent;
  final String? description;
  final bool paid;
  final ToursPaymentMethod? paymentMethod;
  final String? paymentDate;
  final String? paymentNotes;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'serviceType': serviceType.apiValue,
      'startAt': startAt,
      'endAt': endAt,
      'clientName': clientName.trim(),
      'guestReference': guestReference.trim(),
      'providerId': providerId,
      'amount': amount,
      'commissionPercent': commissionPercent,
      'description': _trimOrNull(description),
      'paid': paid,
      'paymentMethod': paymentMethod?.apiValue,
      'paymentDate': paymentDate,
      'paymentNotes': _trimOrNull(paymentNotes),
    };
  }
}

class UpdateToursBookingModel extends CreateToursBookingModel {
  const UpdateToursBookingModel({
    required super.serviceType,
    required super.startAt,
    required super.endAt,
    required super.clientName,
    required super.guestReference,
    required super.providerId,
    required super.amount,
    required super.commissionPercent,
    required super.description,
    required super.paid,
    required super.paymentMethod,
    required super.paymentDate,
    required super.paymentNotes,
  });
}

class UpdateToursPaymentModel {
  const UpdateToursPaymentModel({
    required this.paymentMethod,
    required this.paymentDate,
    required this.paymentNotes,
  });

  final ToursPaymentMethod paymentMethod;
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

class CancelToursBookingModel {
  const CancelToursBookingModel({required this.cancellationNotes});

  final String cancellationNotes;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'cancellationNotes': _trimOrNull(cancellationNotes),
    };
  }
}

class CreateToursProviderModel {
  const CreateToursProviderModel({
    required this.name,
    required this.contact,
    required this.defaultCommissionPercent,
  });

  final String name;
  final String contact;
  final double defaultCommissionPercent;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name.trim(),
      'contact': contact.trim(),
      'defaultCommissionPercent': defaultCommissionPercent,
    };
  }
}

class UpdateToursProviderModel extends CreateToursProviderModel {
  const UpdateToursProviderModel({
    required super.name,
    required super.contact,
    required super.defaultCommissionPercent,
    required this.active,
  });

  final bool active;

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name.trim(),
      'contact': contact.trim(),
      'defaultCommissionPercent': defaultCommissionPercent,
      'active': active,
    };
  }
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

Map<String, dynamic>? _asMapOrNull(Object? value) {
  if (value is! Map) {
    return null;
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
