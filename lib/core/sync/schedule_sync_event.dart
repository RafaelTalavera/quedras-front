enum ScheduleSyncDomain {
  reservations,
  massages,
  courts,
  tours,
  maintenance,
  unknown,
}

final class ScheduleSyncEvent {
  const ScheduleSyncEvent({
    required this.domain,
    required this.action,
    required this.entityId,
    required this.dateFrom,
    required this.dateTo,
  });

  final ScheduleSyncDomain domain;
  final String action;
  final int? entityId;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  bool affectsDay(DateTime date) {
    final DateTime normalized = DateTime(date.year, date.month, date.day);
    final DateTime? start = _normalizedDate(dateFrom);
    final DateTime? end = _normalizedDate(dateTo);
    if (start == null && end == null) {
      return true;
    }
    final DateTime effectiveStart = start ?? end!;
    final DateTime effectiveEnd = end ?? start!;
    return !normalized.isBefore(effectiveStart) &&
        !normalized.isAfter(effectiveEnd);
  }

  bool affectsRange(DateTime start, DateTime end) {
    final DateTime normalizedStart = DateTime(
      start.year,
      start.month,
      start.day,
    );
    final DateTime normalizedEnd = DateTime(end.year, end.month, end.day);
    final DateTime? eventStart = _normalizedDate(dateFrom);
    final DateTime? eventEnd = _normalizedDate(dateTo);
    if (eventStart == null && eventEnd == null) {
      return true;
    }
    final DateTime effectiveEventStart = eventStart ?? eventEnd!;
    final DateTime effectiveEventEnd = eventEnd ?? eventStart!;
    return !effectiveEventEnd.isBefore(normalizedStart) &&
        !effectiveEventStart.isAfter(normalizedEnd);
  }

  static ScheduleSyncEvent fromJson(Map<String, dynamic> json) {
    return ScheduleSyncEvent(
      domain: _parseDomain(json['domain']?.toString()),
      action: json['action']?.toString().trim() ?? '',
      entityId: int.tryParse(json['entityId']?.toString() ?? ''),
      dateFrom: _tryParseDate(json['dateFrom']?.toString()),
      dateTo: _tryParseDate(json['dateTo']?.toString()),
    );
  }

  static ScheduleSyncDomain _parseDomain(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'reservations':
        return ScheduleSyncDomain.reservations;
      case 'massages':
        return ScheduleSyncDomain.massages;
      case 'courts':
        return ScheduleSyncDomain.courts;
      case 'tours':
        return ScheduleSyncDomain.tours;
      case 'maintenance':
        return ScheduleSyncDomain.maintenance;
      default:
        return ScheduleSyncDomain.unknown;
    }
  }

  static DateTime? _tryParseDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final DateTime? parsed = DateTime.tryParse(value.trim());
    if (parsed == null) {
      return null;
    }
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static DateTime? _normalizedDate(DateTime? value) {
    if (value == null) {
      return null;
    }
    return DateTime(value.year, value.month, value.day);
  }
}
