enum ReservationStatus {
  scheduled,
  completed,
  cancelled;

  String toApiValue() {
    switch (this) {
      case ReservationStatus.scheduled:
        return 'SCHEDULED';
      case ReservationStatus.completed:
        return 'COMPLETED';
      case ReservationStatus.cancelled:
        return 'CANCELLED';
    }
  }

  static ReservationStatus fromApiValue(String value) {
    switch (value) {
      case 'SCHEDULED':
        return ReservationStatus.scheduled;
      case 'COMPLETED':
        return ReservationStatus.completed;
      case 'CANCELLED':
        return ReservationStatus.cancelled;
      default:
        throw FormatException('Status de reserva não suportado: $value');
    }
  }
}
