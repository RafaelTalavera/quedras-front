enum LaundryUnitType {
  piece('PIECE', 'Pieza'),
  kilogram('KILOGRAM', 'Kilogramo');

  const LaundryUnitType(this.apiValue, this.label);
  final String apiValue;
  final String label;
  static LaundryUnitType parse(Object? value) => values.firstWhere(
    (LaundryUnitType item) => item.apiValue == value,
    orElse: () => LaundryUnitType.piece,
  );
}

enum LaundryShipmentKind {
  standard('STANDARD', 'Normal'),
  rewash('REWASH', 'RELAVADO · SIN COSTO'),
  receipt('RECEIPT', 'RECIBIDO');

  const LaundryShipmentKind(this.apiValue, this.label);
  final String apiValue;
  final String label;
  static LaundryShipmentKind parse(Object? value) => values.firstWhere(
    (LaundryShipmentKind item) => item.apiValue == value,
    orElse: () => LaundryShipmentKind.standard,
  );
}

enum LaundryShipmentStatus {
  pendingDispatch('PENDING_DISPATCH', 'Pendiente de envío'),
  sent('SENT', 'Enviado'),
  partiallyReceived('PARTIALLY_RECEIVED', 'Recibido parcialmente'),
  received('RECEIVED', 'Recibido'),
  cancelled('CANCELLED', 'Cancelado');

  const LaundryShipmentStatus(this.apiValue, this.label);
  final String apiValue;
  final String label;
  static LaundryShipmentStatus parse(Object? value) => values.firstWhere(
    (LaundryShipmentStatus item) => item.apiValue == value,
    orElse: () => LaundryShipmentStatus.sent,
  );
}

enum LaundryRewashReason {
  stain('STAIN', 'Mancha'),
  odor('ODOR', 'Olor'),
  humidity('HUMIDITY', 'Humedad'),
  incompleteWash('INCOMPLETE_WASH', 'Lavado incompleto'),
  other('OTHER', 'Otro');

  const LaundryRewashReason(this.apiValue, this.label);
  final String apiValue;
  final String label;
  static LaundryRewashReason? tryParse(Object? value) {
    for (final LaundryRewashReason item in values) {
      if (item.apiValue == value) {
        return item;
      }
    }
    return null;
  }
}

final class LaundryProvider {
  const LaundryProvider({
    required this.id,
    required this.name,
    this.contact,
    required this.active,
  });
  final int id;
  final String name;
  final String? contact;
  final bool active;
  factory LaundryProvider.fromJson(Map<String, dynamic> json) =>
      LaundryProvider(
        id: _int(json['id']),
        name: _string(json['name']),
        contact: _nullableString(json['contact']),
        active: json['active'] == true,
      );
}

final class LaundryItem {
  const LaundryItem({
    required this.id,
    required this.name,
    required this.unitType,
    required this.currentUnitPrice,
    required this.active,
  });
  final int id;
  final String name;
  final LaundryUnitType unitType;
  final double currentUnitPrice;
  final bool active;
  factory LaundryItem.fromJson(Map<String, dynamic> json) => LaundryItem(
    id: _int(json['id']),
    name: _string(json['name']),
    unitType: LaundryUnitType.parse(json['unitType']),
    currentUnitPrice: _double(json['currentUnitPrice']),
    active: json['active'] == true,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name.trim(),
    'unitType': unitType.apiValue,
    'currentUnitPrice': currentUnitPrice,
    'active': active,
  };
}

final class CreateLaundryProviderRequest {
  const CreateLaundryProviderRequest({
    required this.name,
    this.contact,
    this.active = true,
  });
  final String name;
  final String? contact;
  final bool active;
  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name.trim(),
    'contact': _nullableString(contact),
    'active': active,
  };
}

final class LaundryShipmentLine {
  const LaundryShipmentLine({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.unitType,
    required this.sentQuantity,
    required this.acceptedQuantity,
    required this.rewashQuantity,
    required this.missingQuantity,
    required this.damagedQuantity,
    required this.pendingQuantity,
    required this.unitPrice,
    required this.billableAmount,
    this.originLineId,
    this.rewashReason,
  });
  final int id;
  final int itemId;
  final String itemName;
  final LaundryUnitType unitType;
  final double sentQuantity,
      acceptedQuantity,
      rewashQuantity,
      missingQuantity,
      damagedQuantity,
      pendingQuantity,
      unitPrice,
      billableAmount;
  final int? originLineId;
  final LaundryRewashReason? rewashReason;
  factory LaundryShipmentLine.fromJson(Map<String, dynamic> json) =>
      LaundryShipmentLine(
        id: _int(json['id']),
        itemId: _int(json['itemId']),
        itemName: _string(json['itemName']),
        unitType: LaundryUnitType.parse(json['unitType']),
        sentQuantity: _double(json['sentQuantity']),
        acceptedQuantity: _double(json['acceptedQuantity']),
        rewashQuantity: _double(json['rewashQuantity']),
        missingQuantity: _double(json['missingQuantity']),
        damagedQuantity: _double(json['damagedQuantity']),
        pendingQuantity: _double(json['pendingQuantity']),
        unitPrice: _double(json['unitPrice']),
        billableAmount: _double(json['billableAmount']),
        originLineId: _nullableInt(json['originLineId']),
        rewashReason: LaundryRewashReason.tryParse(json['rewashReason']),
      );
  double get classifiedQuantity =>
      acceptedQuantity + rewashQuantity + missingQuantity + damagedQuantity;
}

final class LaundryShipment {
  const LaundryShipment({
    required this.id,
    required this.shipmentNumber,
    required this.providerId,
    required this.providerName,
    required this.kind,
    required this.status,
    this.sentAt,
    this.receivedAt,
    this.notes,
    this.cancellationNotes,
    required this.version,
    required this.totalQuantity,
    required this.billableAmount,
    required this.lines,
    this.createdBy,
    this.updatedBy,
  });
  final int id, providerId, version;
  final String shipmentNumber, providerName;
  final LaundryShipmentKind kind;
  final LaundryShipmentStatus status;
  final DateTime? sentAt;
  final DateTime? receivedAt;
  final String? notes, cancellationNotes, createdBy, updatedBy;
  final double totalQuantity, billableAmount;
  final List<LaundryShipmentLine> lines;
  factory LaundryShipment.fromJson(Map<String, dynamic> json) =>
      LaundryShipment(
        id: _int(json['id']),
        shipmentNumber: _string(json['shipmentNumber']),
        providerId: _int(json['providerId']),
        providerName: _string(json['providerName']),
        kind: LaundryShipmentKind.parse(json['kind']),
        status: LaundryShipmentStatus.parse(json['status']),
        sentAt: DateTime.tryParse(_string(json['sentAt'])),
        receivedAt: DateTime.tryParse(_string(json['receivedAt'])),
        notes: _nullableString(json['notes']),
        cancellationNotes: _nullableString(json['cancellationNotes']),
        version: _int(json['version']),
        totalQuantity: _double(json['totalQuantity']),
        billableAmount: _double(json['billableAmount']),
        lines: (json['lines'] as List<Object?>? ?? const <Object?>[])
            .whereType<Map>()
            .map((Map value) => LaundryShipmentLine.fromJson(_map(value)))
            .toList(),
        createdBy: _nullableString(json['createdBy']),
        updatedBy: _nullableString(json['updatedBy']),
      );
  double get pendingQuantity => lines.fold(
    0,
    (double sum, LaundryShipmentLine line) => sum + line.pendingQuantity,
  );
  bool get isPending =>
      status == LaundryShipmentStatus.sent ||
      status == LaundryShipmentStatus.partiallyReceived;
  bool get isPendingDispatch =>
      kind == LaundryShipmentKind.rewash &&
      status == LaundryShipmentStatus.pendingDispatch;
  double get displayedBillableAmount =>
      kind == LaundryShipmentKind.standard ? billableAmount : 0;
}

final class CreateLaundryShipmentLineRequest {
  const CreateLaundryShipmentLineRequest({
    required this.itemId,
    required this.quantity,
    this.rewashReason,
  });
  final int itemId;
  final double quantity;
  final LaundryRewashReason? rewashReason;
  Map<String, dynamic> toJson() => <String, dynamic>{
    'itemId': itemId,
    'quantity': quantity,
    'rewashReason': rewashReason?.apiValue,
  };
}

final class CreateLaundryShipmentRequest {
  const CreateLaundryShipmentRequest({
    required this.providerId,
    this.kind = LaundryShipmentKind.standard,
    required this.sentAt,
    this.notes,
    required this.lines,
  });
  final int providerId;
  final LaundryShipmentKind kind;
  final DateTime sentAt;
  final String? notes;
  final List<CreateLaundryShipmentLineRequest> lines;
  Map<String, dynamic> toJson() => <String, dynamic>{
    'providerId': providerId,
    'kind': kind.apiValue,
    'sentAt': sentAt.toUtc().toIso8601String(),
    'notes': _nullableString(notes),
    'lines': lines
        .map((CreateLaundryShipmentLineRequest line) => line.toJson())
        .toList(),
  };
}

final class ReceiveLaundryLineRequest {
  const ReceiveLaundryLineRequest({
    required this.lineId,
    required this.acceptedQuantity,
    required this.rewashQuantity,
    required this.missingQuantity,
    required this.damagedQuantity,
    this.rewashReason,
  });
  final int lineId;
  final double acceptedQuantity,
      rewashQuantity,
      missingQuantity,
      damagedQuantity;
  final LaundryRewashReason? rewashReason;
  double get total =>
      acceptedQuantity + rewashQuantity + missingQuantity + damagedQuantity;
  String? validate(double pendingQuantity) {
    if (<double>[
      acceptedQuantity,
      rewashQuantity,
      missingQuantity,
      damagedQuantity,
    ].any((double value) => value < 0)) {
      return 'Las cantidades no pueden ser negativas.';
    }
    if (total <= 0) {
      return 'Clasifica al menos una cantidad.';
    }
    if (total > pendingQuantity + 0.000001) {
      return 'La cantidad clasificada supera el pendiente.';
    }
    if (rewashQuantity > 0 && rewashReason == null) {
      return 'Selecciona el motivo del relavado.';
    }
    return null;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'lineId': lineId,
    'acceptedQuantity': acceptedQuantity,
    'rewashQuantity': rewashQuantity,
    'missingQuantity': missingQuantity,
    'damagedQuantity': damagedQuantity,
    'rewashReason': rewashQuantity > 0 ? rewashReason?.apiValue : null,
  };
}

final class ReceiveLaundryShipmentRequest {
  const ReceiveLaundryShipmentRequest({
    required this.receivedAt,
    required this.version,
    required this.lines,
  });
  final DateTime receivedAt;
  final int version;
  final List<ReceiveLaundryLineRequest> lines;
  Map<String, dynamic> toJson() => <String, dynamic>{
    'receivedAt': receivedAt.toUtc().toIso8601String(),
    'version': version,
    'lines': lines
        .map((ReceiveLaundryLineRequest line) => line.toJson())
        .toList(),
  };
}

final class ReceiveLaundryShipmentResult {
  const ReceiveLaundryShipmentResult({
    required this.shipment,
    this.generatedRewashShipmentId,
  });
  final LaundryShipment shipment;
  final int? generatedRewashShipmentId;
  factory ReceiveLaundryShipmentResult.fromJson(Map<String, dynamic> json) =>
      ReceiveLaundryShipmentResult(
        shipment: LaundryShipment.fromJson(_map(json['shipment'])),
        generatedRewashShipmentId: _nullableInt(
          json['generatedRewashShipmentId'],
        ),
      );
}

final class DispatchLaundryShipmentRequest {
  const DispatchLaundryShipmentRequest({
    required this.sentAt,
    required this.version,
    this.notes,
  });
  final DateTime sentAt;
  final int version;
  final String? notes;
  Map<String, dynamic> toJson() => <String, dynamic>{
    'sentAt': sentAt.toUtc().toIso8601String(),
    'version': version,
    'notes': _nullableString(notes),
  };
}

Map<String, dynamic> _map(Object? value) => value is Map
    ? value.map((Object? key, Object? value) => MapEntry(key.toString(), value))
    : <String, dynamic>{};
int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
int? _nullableInt(Object? value) => value == null ? null : _int(value);
double _double(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
String _string(Object? value) => value is String ? value : '';
String? _nullableString(Object? value) {
  final String text = _string(value).trim();
  return text.isEmpty ? null : text;
}
