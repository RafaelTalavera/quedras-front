enum MassagePaymentMethod {
  card('CARD', 'Cartao'),
  cash('CASH', 'Dinheiro'),
  pix('PIX', 'Pix');

  const MassagePaymentMethod(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static MassagePaymentMethod? tryParse(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) {
      return null;
    }
    for (final MassagePaymentMethod value in MassagePaymentMethod.values) {
      if (value.apiValue == rawValue) {
        return value;
      }
    }
    return null;
  }
}

enum MassageBookingStatus {
  scheduled('SCHEDULED'),
  cancelled('CANCELLED');

  const MassageBookingStatus(this.apiValue);

  final String apiValue;

  static MassageBookingStatus tryParse(String? rawValue) {
    for (final MassageBookingStatus value in MassageBookingStatus.values) {
      if (value.apiValue == rawValue) {
        return value;
      }
    }
    return MassageBookingStatus.scheduled;
  }
}

class MassageProvider {
  const MassageProvider({
    required this.id,
    required this.name,
    required this.specialty,
    required this.contact,
    required this.active,
  });

  final int id;
  final String name;
  final String specialty;
  final String contact;
  final bool active;

  factory MassageProvider.fromJson(Map<String, dynamic> json) {
    return MassageProvider(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      specialty: json['specialty'] as String? ?? '',
      contact: json['contact'] as String? ?? '',
      active: json['active'] as bool? ?? false,
    );
  }

  MassageProvider copyWith({
    int? id,
    String? name,
    String? specialty,
    String? contact,
    bool? active,
  }) {
    return MassageProvider(
      id: id ?? this.id,
      name: name ?? this.name,
      specialty: specialty ?? this.specialty,
      contact: contact ?? this.contact,
      active: active ?? this.active,
    );
  }
}

class MassageBooking {
  const MassageBooking({
    required this.id,
    required this.bookingDate,
    required this.startTime,
    required this.clientName,
    required this.guestReference,
    required this.treatment,
    required this.amount,
    required this.providerId,
    required this.providerName,
    required this.providerActive,
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
  final DateTime bookingDate;
  final String startTime;
  final String clientName;
  final String guestReference;
  final String treatment;
  final double amount;
  final int providerId;
  final String providerName;
  final bool providerActive;
  final bool paid;
  final MassagePaymentMethod? paymentMethod;
  final DateTime? paymentDate;
  final String? paymentNotes;
  final MassageBookingStatus status;
  final String? cancellationNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? cancelledAt;
  final String? createdBy;
  final String? updatedBy;
  final String? cancelledBy;

  factory MassageBooking.fromJson(Map<String, dynamic> json) {
    return MassageBooking(
      id: (json['id'] as num).toInt(),
      bookingDate: DateTime.parse(json['bookingDate'] as String),
      startTime: _normalizeTime(json['startTime'] as String? ?? '00:00:00'),
      clientName: json['clientName'] as String? ?? '',
      guestReference: json['guestReference'] as String? ?? '',
      treatment: json['treatment'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      providerId: (json['providerId'] as num).toInt(),
      providerName: json['providerName'] as String? ?? 'Prestador',
      providerActive: json['providerActive'] as bool? ?? false,
      paid: json['paid'] as bool? ?? false,
      paymentMethod: MassagePaymentMethod.tryParse(
        json['paymentMethod'] as String?,
      ),
      paymentDate: _tryParseDate(json['paymentDate'] as String?),
      paymentNotes: _normalizeNullable(json['paymentNotes'] as String?),
      status: MassageBookingStatus.tryParse(json['status'] as String?),
      cancellationNotes: _normalizeNullable(
        (json['cancellationNotes'] ?? json['cancellationReason']) as String?,
      ),
      createdAt: _tryParseDateTime(json['createdAt'] as String?),
      updatedAt: _tryParseDateTime(json['updatedAt'] as String?),
      cancelledAt: _tryParseDateTime(json['cancelledAt'] as String?),
      createdBy: _normalizeNullable(json['createdBy'] as String?),
      updatedBy: _normalizeNullable(json['updatedBy'] as String?),
      cancelledBy: _normalizeNullable(json['cancelledBy'] as String?),
    );
  }

  DateTime get startAt {
    final List<String> parts = startTime.split(':');
    return DateTime(
      bookingDate.year,
      bookingDate.month,
      bookingDate.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  MassageBooking copyWith({
    DateTime? bookingDate,
    String? startTime,
    String? clientName,
    String? guestReference,
    String? treatment,
    double? amount,
    int? providerId,
    String? providerName,
    bool? providerActive,
    bool? paid,
    MassagePaymentMethod? paymentMethod,
    DateTime? paymentDate,
    String? paymentNotes,
    MassageBookingStatus? status,
    String? cancellationNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? cancelledAt,
    String? createdBy,
    String? updatedBy,
    String? cancelledBy,
  }) {
    return MassageBooking(
      id: id,
      bookingDate: bookingDate ?? this.bookingDate,
      startTime: startTime ?? this.startTime,
      clientName: clientName ?? this.clientName,
      guestReference: guestReference ?? this.guestReference,
      treatment: treatment ?? this.treatment,
      amount: amount ?? this.amount,
      providerId: providerId ?? this.providerId,
      providerName: providerName ?? this.providerName,
      providerActive: providerActive ?? this.providerActive,
      paid: paid ?? this.paid,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentDate: paymentDate ?? this.paymentDate,
      paymentNotes: paymentNotes ?? this.paymentNotes,
      status: status ?? this.status,
      cancellationNotes: cancellationNotes ?? this.cancellationNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      cancelledBy: cancelledBy ?? this.cancelledBy,
    );
  }

  static String _normalizeTime(String rawValue) {
    if (rawValue.length >= 8) {
      return rawValue.substring(0, 8);
    }
    if (rawValue.length == 5) {
      return '$rawValue:00';
    }
    return rawValue;
  }

  static DateTime? _tryParseDate(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(rawValue);
  }

  static DateTime? _tryParseDateTime(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(rawValue);
  }

  static String? _normalizeNullable(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value.trim();
  }
}

class CreateMassageBookingModel {
  const CreateMassageBookingModel({
    required this.bookingDate,
    required this.startTime,
    required this.clientName,
    required this.guestReference,
    required this.treatment,
    required this.amount,
    required this.providerId,
    required this.paid,
    required this.paymentMethod,
    required this.paymentDate,
    required this.paymentNotes,
  });

  final String bookingDate;
  final String startTime;
  final String clientName;
  final String guestReference;
  final String treatment;
  final double amount;
  final int providerId;
  final bool paid;
  final MassagePaymentMethod? paymentMethod;
  final String? paymentDate;
  final String? paymentNotes;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'bookingDate': bookingDate,
      'startTime': startTime,
      'clientName': clientName,
      'guestReference': guestReference,
      'treatment': treatment,
      'amount': amount,
      'providerId': providerId,
      'paid': paid,
      'paymentMethod': paymentMethod?.apiValue,
      'paymentDate': paymentDate,
      'paymentNotes': _trimOrNull(paymentNotes),
    };
  }
}

class UpdateMassagePaymentModel {
  const UpdateMassagePaymentModel({
    required this.paymentMethod,
    required this.paymentDate,
    required this.paymentNotes,
  });

  final MassagePaymentMethod paymentMethod;
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

class UpdateMassageBookingModel {
  const UpdateMassageBookingModel({
    required this.bookingDate,
    required this.startTime,
    required this.clientName,
    required this.guestReference,
    required this.treatment,
    required this.amount,
    required this.providerId,
    required this.paid,
    required this.paymentMethod,
    required this.paymentDate,
    required this.paymentNotes,
  });

  final String bookingDate;
  final String startTime;
  final String clientName;
  final String guestReference;
  final String treatment;
  final double amount;
  final int providerId;
  final bool paid;
  final MassagePaymentMethod? paymentMethod;
  final String? paymentDate;
  final String? paymentNotes;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'bookingDate': bookingDate,
      'startTime': startTime,
      'clientName': clientName,
      'guestReference': guestReference,
      'treatment': treatment,
      'amount': amount,
      'providerId': providerId,
      'paid': paid,
      'paymentMethod': paymentMethod?.apiValue,
      'paymentDate': paymentDate,
      'paymentNotes': _trimOrNull(paymentNotes),
    };
  }
}

class CancelMassageBookingModel {
  const CancelMassageBookingModel({required this.cancellationNotes});

  final String cancellationNotes;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'cancellationNotes': _trimOrNull(cancellationNotes),
    };
  }
}

class CreateMassageProviderModel {
  const CreateMassageProviderModel({
    required this.name,
    required this.specialty,
    required this.contact,
  });

  final String name;
  final String specialty;
  final String contact;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'specialty': specialty,
      'contact': contact,
    };
  }
}

class UpdateMassageProviderModel {
  const UpdateMassageProviderModel({
    required this.name,
    required this.specialty,
    required this.contact,
    required this.active,
  });

  final String name;
  final String specialty;
  final String contact;
  final bool active;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'specialty': specialty,
      'contact': contact,
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
