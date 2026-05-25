import 'reservation_status.dart';

final class ReservationModel {
  ReservationModel({
    required this.id,
    required String guestName,
    required this.reservationDate,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.updatedBy,
    required this.cancelledAt,
    required this.cancelledBy,
  }) : guestName = guestName.trim();

  final int? id;
  final String guestName;
  final String reservationDate;
  final String startTime;
  final String endTime;
  final ReservationStatus status;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final DateTime? cancelledAt;
  final String? cancelledBy;

  factory ReservationModel.fromJson(Map<String, dynamic> json) {
    return ReservationModel(
      id: json['id'] as int?,
      guestName: json['guestName'] as String? ?? '',
      reservationDate: json['reservationDate'] as String? ?? '',
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
      status: ReservationStatus.fromApiValue(json['status'] as String),
      notes: json['notes'] as String?,
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
      createdBy: _trimOrNull(json['createdBy'] as String?),
      updatedBy: _trimOrNull(json['updatedBy'] as String?),
      cancelledAt: _parseDateTime(json['cancelledAt']),
      cancelledBy: _trimOrNull(json['cancelledBy'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'guestName': guestName,
      'reservationDate': reservationDate,
      'startTime': startTime,
      'endTime': endTime,
      'status': status.toApiValue(),
      'notes': notes,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      'cancelledAt': cancelledAt?.toIso8601String(),
      'cancelledBy': cancelledBy,
    };
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static String? _trimOrNull(String? value) {
    if (value == null) {
      return null;
    }
    final String normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}
