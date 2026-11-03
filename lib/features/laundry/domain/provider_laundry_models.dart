enum ProviderLaundryStockBucket {
  processing('PROVIDER_PROCESSING'),
  rewash('PROVIDER_REWASH');

  const ProviderLaundryStockBucket(this.apiValue);
  final String apiValue;
}

final class ProviderLaundryResultPage<T> {
  const ProviderLaundryResultPage({
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

final class ProviderLaundryDocumentSummary {
  const ProviderLaundryDocumentSummary({
    required this.id,
    required this.reference,
    required this.documentType,
    required this.status,
    required this.effectiveAt,
    this.submittedAt,
    required this.version,
  });

  final int id;
  final String reference;
  final String documentType;
  final String status;
  final DateTime effectiveAt;
  final DateTime? submittedAt;
  final int version;

  factory ProviderLaundryDocumentSummary.fromJson(Map<String, dynamic> json) =>
      ProviderLaundryDocumentSummary(
        id: _requiredInt(json, 'id'),
        reference: _requiredString(json, 'reference'),
        documentType: _requiredString(json, 'documentType'),
        status: _requiredString(json, 'status'),
        effectiveAt: _requiredDateTime(json, 'effectiveAt'),
        submittedAt: _optionalDateTime(json['submittedAt']),
        version: _requiredInt(json, 'version'),
      );
}

final class ProviderLaundryReturnSummary {
  const ProviderLaundryReturnSummary({
    required this.id,
    required this.reference,
    required this.status,
    required this.effectiveAt,
    this.submittedAt,
    this.confirmedAt,
    required this.version,
  });

  final int id;
  final String reference;
  final String status;
  final DateTime effectiveAt;
  final DateTime? submittedAt;
  final DateTime? confirmedAt;
  final int version;

  factory ProviderLaundryReturnSummary.fromJson(Map<String, dynamic> json) =>
      ProviderLaundryReturnSummary(
        id: _requiredInt(json, 'id'),
        reference: _requiredString(json, 'reference'),
        status: _requiredString(json, 'status'),
        effectiveAt: _requiredDateTime(json, 'effectiveAt'),
        submittedAt: _optionalDateTime(json['submittedAt']),
        confirmedAt: _optionalDateTime(json['confirmedAt']),
        version: _requiredInt(json, 'version'),
      );
}

final class ProviderLaundryStockRow {
  const ProviderLaundryStockRow({
    required this.itemId,
    required this.itemName,
    required this.unitType,
    required this.bucket,
    required this.quantity,
    this.oldestEffectiveAt,
    required this.ageDays,
    required this.version,
  });

  final int itemId;
  final String itemName;
  final String unitType;
  final String bucket;
  final double quantity;
  final DateTime? oldestEffectiveAt;
  final int ageDays;
  final int version;

  factory ProviderLaundryStockRow.fromJson(Map<String, dynamic> json) =>
      ProviderLaundryStockRow(
        itemId: _requiredInt(json, 'itemId'),
        itemName: _requiredString(json, 'itemName'),
        unitType: _requiredString(json, 'unitType'),
        bucket: _requiredString(json, 'bucket'),
        quantity: _requiredDouble(json, 'quantity'),
        oldestEffectiveAt: _optionalDateTime(json['oldestEffectiveAt']),
        ageDays: _requiredInt(json, 'ageDays'),
        version: _requiredInt(json, 'version'),
      );
}

ProviderLaundryResultPage<T> parseProviderLaundryPage<T>(
  Map<String, dynamic> json,
  T Function(Map<String, dynamic>) parseItem,
) {
  final Object? rawItems = json['items'];
  if (rawItems is! List) {
    throw const FormatException('items must be a list');
  }
  return ProviderLaundryResultPage<T>(
    page: _requiredInt(json, 'page'),
    size: _requiredInt(json, 'size'),
    hasNext: json['hasNext'] == true,
    items: rawItems
        .map<T>((Object? value) {
          if (value is! Map) {
            throw const FormatException('page item must be an object');
          }
          return parseItem(
            value.map<String, dynamic>(
              (Object? key, Object? value) => MapEntry(key.toString(), value),
            ),
          );
        })
        .toList(growable: false),
  );
}

String _requiredString(Map<String, dynamic> json, String key) {
  final String value = json[key]?.toString().trim() ?? '';
  if (value.isEmpty) throw FormatException('$key is required');
  return value;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final int? value = int.tryParse(json[key]?.toString() ?? '');
  if (value == null) throw FormatException('$key must be an integer');
  return value;
}

double _requiredDouble(Map<String, dynamic> json, String key) {
  final double? value = double.tryParse(json[key]?.toString() ?? '');
  if (value == null) throw FormatException('$key must be numeric');
  return value;
}

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  final DateTime? value = _optionalDateTime(json[key]);
  if (value == null) throw FormatException('$key must be a date-time');
  return value;
}

DateTime? _optionalDateTime(Object? raw) {
  final String value = raw?.toString().trim() ?? '';
  return value.isEmpty ? null : DateTime.tryParse(value);
}
