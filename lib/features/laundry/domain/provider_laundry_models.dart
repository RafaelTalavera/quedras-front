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

final class ProviderLaundryDocumentLine {
  const ProviderLaundryDocumentLine({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.quantity,
  });

  final int id;
  final int itemId;
  final String itemName;
  final double quantity;

  factory ProviderLaundryDocumentLine.fromJson(Map<String, dynamic> json) =>
      ProviderLaundryDocumentLine(
        id: _requiredInt(json, 'id'),
        itemId: _requiredInt(json, 'itemId'),
        itemName: _requiredString(json, 'itemName'),
        quantity: _requiredDouble(json, 'quantity'),
      );
}

final class ProviderLaundryConfirmation {
  const ProviderLaundryConfirmation({
    required this.id,
    required this.action,
    this.notes,
    required this.actorRole,
    required this.createdAt,
  });

  final int id;
  final String action;
  final String? notes;
  final String actorRole;
  final DateTime createdAt;

  factory ProviderLaundryConfirmation.fromJson(Map<String, dynamic> json) =>
      ProviderLaundryConfirmation(
        id: _requiredInt(json, 'id'),
        action: _requiredString(json, 'action'),
        notes: _optionalString(json['notes']),
        actorRole: _requiredString(json, 'actorRole'),
        createdAt: _requiredDateTime(json, 'createdAt'),
      );
}

final class ProviderLaundryDocument {
  const ProviderLaundryDocument({
    required this.id,
    required this.reference,
    required this.documentType,
    required this.status,
    required this.providerId,
    required this.providerName,
    required this.effectiveAt,
    this.notes,
    this.submittedAt,
    required this.version,
    required this.lines,
    required this.confirmations,
  });

  final int id;
  final String reference;
  final String documentType;
  final String status;
  final int providerId;
  final String providerName;
  final DateTime effectiveAt;
  final String? notes;
  final DateTime? submittedAt;
  final int version;
  final List<ProviderLaundryDocumentLine> lines;
  final List<ProviderLaundryConfirmation> confirmations;

  bool get canDecide => status == 'SUBMITTED';

  factory ProviderLaundryDocument.fromJson(Map<String, dynamic> json) =>
      ProviderLaundryDocument(
        id: _requiredInt(json, 'id'),
        reference: _requiredString(json, 'reference'),
        documentType: _requiredString(json, 'documentType'),
        status: _requiredString(json, 'status'),
        providerId: _requiredInt(json, 'providerId'),
        providerName: _requiredString(json, 'providerName'),
        effectiveAt: _requiredDateTime(json, 'effectiveAt'),
        notes: _optionalString(json['notes']),
        submittedAt: _optionalDateTime(json['submittedAt']),
        version: _requiredInt(json, 'version'),
        lines: _parseList(json['lines'], ProviderLaundryDocumentLine.fromJson),
        confirmations: _parseList(
          json['confirmations'],
          ProviderLaundryConfirmation.fromJson,
        ),
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

final class ProviderLaundryReturnLine {
  const ProviderLaundryReturnLine({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.declaredClean,
    required this.declaredRetained,
    required this.acceptedClean,
    required this.returnedDirty,
    required this.retained,
    required this.missing,
    required this.damaged,
  });

  final int id;
  final int itemId;
  final String itemName;
  final double declaredClean;
  final double declaredRetained;
  final double acceptedClean;
  final double returnedDirty;
  final double retained;
  final double missing;
  final double damaged;

  factory ProviderLaundryReturnLine.fromJson(Map<String, dynamic> json) =>
      ProviderLaundryReturnLine(
        id: _requiredInt(json, 'id'),
        itemId: _requiredInt(json, 'itemId'),
        itemName: _requiredString(json, 'itemName'),
        declaredClean: _requiredDouble(json, 'declaredClean'),
        declaredRetained: _requiredDouble(json, 'declaredRetained'),
        acceptedClean: _requiredDouble(json, 'acceptedClean'),
        returnedDirty: _requiredDouble(json, 'returnedDirty'),
        retained: _requiredDouble(json, 'retained'),
        missing: _requiredDouble(json, 'missing'),
        damaged: _requiredDouble(json, 'damaged'),
      );
}

final class ProviderLaundryReturn {
  const ProviderLaundryReturn({
    required this.id,
    required this.reference,
    required this.status,
    required this.providerId,
    required this.providerName,
    required this.effectiveAt,
    this.notes,
    this.submittedAt,
    this.confirmedAt,
    this.correctionNotes,
    required this.version,
    required this.lines,
  });

  final int id;
  final String reference;
  final String status;
  final int providerId;
  final String providerName;
  final DateTime effectiveAt;
  final String? notes;
  final DateTime? submittedAt;
  final DateTime? confirmedAt;
  final String? correctionNotes;
  final int version;
  final List<ProviderLaundryReturnLine> lines;

  bool get isDraft => status == 'DRAFT';

  factory ProviderLaundryReturn.fromJson(Map<String, dynamic> json) =>
      ProviderLaundryReturn(
        id: _requiredInt(json, 'id'),
        reference: _requiredString(json, 'reference'),
        status: _requiredString(json, 'status'),
        providerId: _requiredInt(json, 'providerId'),
        providerName: _requiredString(json, 'providerName'),
        effectiveAt: _requiredDateTime(json, 'effectiveAt'),
        notes: _optionalString(json['notes']),
        submittedAt: _optionalDateTime(json['submittedAt']),
        confirmedAt: _optionalDateTime(json['confirmedAt']),
        correctionNotes: _optionalString(json['correctionNotes']),
        version: _requiredInt(json, 'version'),
        lines: _parseList(json['lines'], ProviderLaundryReturnLine.fromJson),
      );
}

final class ProviderLaundryReturnLineInput {
  const ProviderLaundryReturnLineInput({
    required this.itemId,
    required this.declaredClean,
    required this.declaredRetained,
  });

  final int itemId;
  final double declaredClean;
  final double declaredRetained;

  Map<String, Object> toJson() => <String, Object>{
    'itemId': itemId,
    'declaredClean': declaredClean,
    'declaredRetained': declaredRetained,
  };
}

final class ProviderLaundryReturnInput {
  const ProviderLaundryReturnInput({
    required this.version,
    required this.effectiveAt,
    this.notes,
    required this.lines,
  });

  final int version;
  final DateTime effectiveAt;
  final String? notes;
  final List<ProviderLaundryReturnLineInput> lines;

  Map<String, Object?> toJson() => <String, Object?>{
    'version': version,
    'effectiveAt': effectiveAt.toUtc().toIso8601String(),
    'notes': _optionalString(notes),
    'lines': lines
        .map((ProviderLaundryReturnLineInput line) => line.toJson())
        .toList(growable: false),
  };
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

String? _optionalString(Object? raw) {
  final String value = raw?.toString().trim() ?? '';
  return value.isEmpty ? null : value;
}

List<T> _parseList<T>(Object? raw, T Function(Map<String, dynamic>) parser) {
  if (raw is! List) {
    throw const FormatException('value must be a list');
  }
  return raw
      .map<T>((Object? value) {
        if (value is! Map) {
          throw const FormatException('item must be an object');
        }
        return parser(
          value.map<String, dynamic>(
            (Object? key, Object? value) => MapEntry(key.toString(), value),
          ),
        );
      })
      .toList(growable: false);
}
