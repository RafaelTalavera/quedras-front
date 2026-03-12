final class CreateReservationModel {
  CreateReservationModel({
    required String guestName,
    required this.reservationDate,
    required this.startTime,
    required this.endTime,
    this.notes,
  }) : guestName = guestName.trim();

  final String guestName;
  final String reservationDate;
  final String startTime;
  final String endTime;
  final String? notes;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'guestName': guestName,
      'reservationDate': reservationDate,
      'startTime': startTime,
      'endTime': endTime,
      'notes': notes,
    };
  }
}
