final class AuditFieldChange {
  const AuditFieldChange({
    required this.field,
    required this.before,
    required this.after,
  });

  final String field;
  final Object? before;
  final Object? after;

  factory AuditFieldChange.fromJson(Map<String, dynamic> json) {
    return AuditFieldChange(
      field: (json['field'] as String? ?? '').trim(),
      before: json['before'],
      after: json['after'],
    );
  }
}

final class AuditEventModel {
  const AuditEventModel({
    required this.id,
    required this.moduleName,
    required this.entityType,
    required this.entityId,
    required this.actionName,
    required this.occurredAt,
    required this.actorUsername,
    required this.actorRole,
    required this.summaryText,
    required this.changes,
  });

  final int id;
  final String moduleName;
  final String entityType;
  final int entityId;
  final String actionName;
  final DateTime? occurredAt;
  final String? actorUsername;
  final String? actorRole;
  final String? summaryText;
  final List<AuditFieldChange> changes;

  factory AuditEventModel.fromJson(Map<String, dynamic> json) {
    final Object? changesRaw = json['changes'];
    return AuditEventModel(
      id: _readInt(json['id']),
      moduleName: _readString(json['moduleName']),
      entityType: _readString(json['entityType']),
      entityId: _readInt(json['entityId']),
      actionName: _readString(json['actionName']),
      occurredAt: _tryParseDateTime(json['occurredAt'] as String?),
      actorUsername: _trimOrNull(json['actorUsername'] as String?),
      actorRole: _trimOrNull(json['actorRole'] as String?),
      summaryText: _trimOrNull(json['summaryText'] as String?),
      changes: changesRaw is List
          ? changesRaw
                .whereType<Map>()
                .map<AuditFieldChange>(
                  (Map<dynamic, dynamic> item) => AuditFieldChange.fromJson(
                    item.map<String, dynamic>(
                      (dynamic key, dynamic value) =>
                          MapEntry<String, dynamic>(key.toString(), value),
                    ),
                  ),
                )
                .toList()
          : const <AuditFieldChange>[],
    );
  }
}

int _readInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

String _readString(Object? value) {
  if (value == null) {
    return '';
  }
  return value.toString();
}

String? _trimOrNull(String? value) {
  if (value == null) {
    return null;
  }
  final String normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

DateTime? _tryParseDateTime(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}
