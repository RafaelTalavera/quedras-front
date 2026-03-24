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
    required this.therapists,
  });

  final int id;
  final String name;
  final String specialty;
  final String contact;
  final bool active;
  final List<MassageTherapist> therapists;

  factory MassageProvider.fromJson(Map<String, dynamic> json) {
    final Object? therapistsRaw =
        json['therapists'] ?? json['masseuses'] ?? json['massageTherapists'];
    final Map<String, dynamic>? contactPerson = _asMapOrNull(json['provider']);
    return MassageProvider(
      id: _readInt(json, 'id') ?? _readInt(contactPerson, 'id') ?? 0,
      name:
          _readString(json, 'name') ?? _readString(contactPerson, 'name') ?? '',
      specialty:
          _readString(json, 'specialty') ??
          _readString(contactPerson, 'specialty') ??
          '',
      contact:
          _readString(json, 'contact') ??
          _readString(contactPerson, 'contact') ??
          '',
      active: json['active'] as bool? ?? false,
      therapists: therapistsRaw is List
          ? therapistsRaw
                .map<MassageTherapist>(
                  (Object? item) => MassageTherapist.fromJson(
                    _asMapOrNull(item) ?? const <String, dynamic>{},
                  ),
                )
                .toList()
          : const <MassageTherapist>[],
    );
  }

  MassageProvider copyWith({
    int? id,
    String? name,
    String? specialty,
    String? contact,
    bool? active,
    List<MassageTherapist>? therapists,
  }) {
    return MassageProvider(
      id: id ?? this.id,
      name: name ?? this.name,
      specialty: specialty ?? this.specialty,
      contact: contact ?? this.contact,
      active: active ?? this.active,
      therapists: therapists ?? this.therapists,
    );
  }
}

class MassageTherapist {
  const MassageTherapist({
    required this.id,
    required this.name,
    required this.active,
  });

  final int id;
  final String name;
  final bool active;

  factory MassageTherapist.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? nested = _asMapOrNull(
      json['therapist'] ?? json['masseuse'],
    );
    return MassageTherapist(
      id: _readInt(json, 'id') ?? _readInt(nested, 'id') ?? 0,
      name: _readString(json, 'name') ?? _readString(nested, 'name') ?? '',
      active:
          (json['active'] as bool?) ?? (nested?['active'] as bool?) ?? false,
    );
  }

  MassageTherapist copyWith({int? id, String? name, bool? active}) {
    return MassageTherapist(
      id: id ?? this.id,
      name: name ?? this.name,
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
    required this.therapistId,
    required this.therapistName,
    required this.therapistActive,
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
  final int therapistId;
  final String therapistName;
  final bool therapistActive;
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
    final Map<String, dynamic>? provider = _asMapOrNull(json['provider']);
    final Map<String, dynamic>? therapist = _asMapOrNull(
      json['therapist'] ?? json['masseuse'],
    );
    return MassageBooking(
      id: (json['id'] as num).toInt(),
      bookingDate: DateTime.parse(json['bookingDate'] as String),
      startTime: _normalizeTime(json['startTime'] as String? ?? '00:00:00'),
      clientName: json['clientName'] as String? ?? '',
      guestReference: json['guestReference'] as String? ?? '',
      treatment: json['treatment'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      providerId: _readInt(json, 'providerId') ?? _readInt(provider, 'id') ?? 0,
      providerName:
          _readString(json, 'providerName') ??
          _readString(provider, 'name') ??
          'Prestador',
      providerActive:
          (json['providerActive'] as bool?) ??
          (provider?['active'] as bool?) ??
          false,
      therapistId:
          _readInt(json, 'therapistId') ??
          _readInt(json, 'masseuseId') ??
          _readInt(therapist, 'id') ??
          0,
      therapistName:
          _readString(json, 'therapistName') ??
          _readString(json, 'masseuseName') ??
          _readString(therapist, 'name') ??
          'Masajista',
      therapistActive:
          (json['therapistActive'] as bool?) ??
          (json['masseuseActive'] as bool?) ??
          (therapist?['active'] as bool?) ??
          false,
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
    int? therapistId,
    String? therapistName,
    bool? therapistActive,
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
      therapistId: therapistId ?? this.therapistId,
      therapistName: therapistName ?? this.therapistName,
      therapistActive: therapistActive ?? this.therapistActive,
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
    required this.therapistId,
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
  final int therapistId;
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
      'therapistId': therapistId,
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
    required this.therapistId,
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
  final int therapistId;
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
      'therapistId': therapistId,
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

class CreateMassageTherapistModel {
  const CreateMassageTherapistModel({required this.name});

  final String name;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'name': name};
  }
}

class UpdateMassageTherapistModel {
  const UpdateMassageTherapistModel({required this.name, required this.active});

  final String name;
  final bool active;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'name': name, 'active': active};
  }
}

String? _trimOrNull(String? value) {
  if (value == null) {
    return null;
  }
  final String normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
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
