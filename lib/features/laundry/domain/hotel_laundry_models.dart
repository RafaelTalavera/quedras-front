import 'provider_laundry_models.dart';

final class HotelLaundryPage<T> {
  const HotelLaundryPage({
    required this.page,
    required this.size,
    required this.hasNext,
    required this.items,
  });

  final int page;
  final int size;
  final bool hasNext;
  final List<T> items;
}

final class HotelLaundryStockTotals {
  const HotelLaundryStockTotals({
    required this.hotelAvailable,
    required this.hotelRewashQueue,
    required this.providerProcessing,
    required this.providerRewash,
    required this.missing,
    required this.damaged,
    required this.total,
  });

  final double hotelAvailable;
  final double hotelRewashQueue;
  final double providerProcessing;
  final double providerRewash;
  final double missing;
  final double damaged;
  final double total;

  factory HotelLaundryStockTotals.fromJson(Map<String, dynamic> json) =>
      HotelLaundryStockTotals(
        hotelAvailable: _double(json, 'hotelAvailable'),
        hotelRewashQueue: _double(json, 'hotelRewashQueue'),
        providerProcessing: _double(json, 'providerProcessing'),
        providerRewash: _double(json, 'providerRewash'),
        missing: _double(json, 'missing'),
        damaged: _double(json, 'damaged'),
        total: _double(json, 'total'),
      );
}

final class HotelLaundryDocumentSummary {
  const HotelLaundryDocumentSummary({
    required this.id,
    required this.reference,
    required this.documentType,
    required this.status,
    required this.providerId,
    required this.providerName,
    required this.effectiveAt,
    this.submittedAt,
    required this.version,
  });

  final int id;
  final String reference;
  final String documentType;
  final String status;
  final int providerId;
  final String providerName;
  final DateTime effectiveAt;
  final DateTime? submittedAt;
  final int version;

  factory HotelLaundryDocumentSummary.fromJson(Map<String, dynamic> json) =>
      HotelLaundryDocumentSummary(
        id: _int(json, 'id'),
        reference: _string(json, 'reference'),
        documentType: _string(json, 'documentType'),
        status: _string(json, 'status'),
        providerId: _int(json, 'providerId'),
        providerName: _string(json, 'providerName'),
        effectiveAt: _date(json, 'effectiveAt'),
        submittedAt: _optionalDate(json['submittedAt']),
        version: _int(json, 'version'),
      );
}

final class HotelLaundryReturnSummary {
  const HotelLaundryReturnSummary({
    required this.id,
    required this.reference,
    required this.status,
    required this.providerId,
    required this.providerName,
    required this.effectiveAt,
    this.submittedAt,
    this.confirmedAt,
    required this.version,
  });

  final int id;
  final String reference;
  final String status;
  final int providerId;
  final String providerName;
  final DateTime effectiveAt;
  final DateTime? submittedAt;
  final DateTime? confirmedAt;
  final int version;

  factory HotelLaundryReturnSummary.fromJson(Map<String, dynamic> json) =>
      HotelLaundryReturnSummary(
        id: _int(json, 'id'),
        reference: _string(json, 'reference'),
        status: _string(json, 'status'),
        providerId: _int(json, 'providerId'),
        providerName: _string(json, 'providerName'),
        effectiveAt: _date(json, 'effectiveAt'),
        submittedAt: _optionalDate(json['submittedAt']),
        confirmedAt: _optionalDate(json['confirmedAt']),
        version: _int(json, 'version'),
      );
}

final class HotelLaundryDispatchLineInput {
  const HotelLaundryDispatchLineInput({
    required this.itemId,
    required this.quantity,
  });
  final int itemId;
  final double quantity;
  Map<String, Object> toJson() => <String, Object>{
    'itemId': itemId,
    'quantity': quantity,
  };
}

final class HotelLaundryDispatchInput {
  const HotelLaundryDispatchInput({
    required this.version,
    required this.providerId,
    required this.effectiveAt,
    this.notes,
    required this.lines,
  });
  final int version;
  final int providerId;
  final DateTime effectiveAt;
  final String? notes;
  final List<HotelLaundryDispatchLineInput> lines;
  Map<String, Object?> toJson() => <String, Object?>{
    'version': version,
    'providerId': providerId,
    'effectiveAt': effectiveAt.toUtc().toIso8601String(),
    'notes': _trimmed(notes),
    'lines': lines
        .map((HotelLaundryDispatchLineInput line) => line.toJson())
        .toList(growable: false),
  };
}

final class HotelLaundryReturnClassificationInput {
  const HotelLaundryReturnClassificationInput({
    required this.itemId,
    required this.acceptedClean,
    required this.returnedDirty,
    required this.retained,
    required this.missing,
    required this.damaged,
  });
  final int itemId;
  final double acceptedClean;
  final double returnedDirty;
  final double retained;
  final double missing;
  final double damaged;
  Map<String, Object> toJson() => <String, Object>{
    'itemId': itemId,
    'acceptedClean': acceptedClean,
    'returnedDirty': returnedDirty,
    'retained': retained,
    'missing': missing,
    'damaged': damaged,
  };
}

final class HotelLaundryReturnConfirmationInput {
  const HotelLaundryReturnConfirmationInput({
    required this.version,
    this.correctionNotes,
    required this.lines,
  });
  final int version;
  final String? correctionNotes;
  final List<HotelLaundryReturnClassificationInput> lines;
  Map<String, Object?> toJson() => <String, Object?>{
    'version': version,
    'correctionNotes': _trimmed(correctionNotes),
    'lines': lines
        .map((HotelLaundryReturnClassificationInput line) => line.toJson())
        .toList(growable: false),
  };
}

HotelLaundryPage<T> parseHotelLaundryPage<T>(
  Map<String, dynamic> json,
  T Function(Map<String, dynamic>) parser,
) {
  final Object? rawItems = json['items'];
  if (rawItems is! List) throw const FormatException('items must be a list');
  return HotelLaundryPage<T>(
    page: _int(json, 'page'),
    size: _int(json, 'size'),
    hasNext: json['hasNext'] == true,
    items: rawItems.map<T>((Object? raw) => parser(_map(raw))).toList(),
  );
}

ProviderLaundryReturn parseHotelLaundryReturn(Map<String, dynamic> json) =>
    ProviderLaundryReturn.fromJson(json);

Map<String, dynamic> _map(Object? raw) {
  if (raw is! Map) throw const FormatException('object expected');
  return raw.map<String, dynamic>(
    (Object? key, Object? value) => MapEntry(key.toString(), value),
  );
}

String _string(Map<String, dynamic> json, String key) {
  final String value = json[key]?.toString().trim() ?? '';
  if (value.isEmpty) throw FormatException('$key is required');
  return value;
}

int _int(Map<String, dynamic> json, String key) {
  final int? value = int.tryParse(json[key]?.toString() ?? '');
  if (value == null) throw FormatException('$key must be an integer');
  return value;
}

double _double(Map<String, dynamic> json, String key) {
  final double? value = double.tryParse(json[key]?.toString() ?? '');
  if (value == null) throw FormatException('$key must be numeric');
  return value;
}

DateTime _date(Map<String, dynamic> json, String key) {
  final DateTime? value = _optionalDate(json[key]);
  if (value == null) throw FormatException('$key must be a date-time');
  return value;
}

DateTime? _optionalDate(Object? raw) =>
    DateTime.tryParse(raw?.toString() ?? '');
String? _trimmed(String? value) {
  final String normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}
