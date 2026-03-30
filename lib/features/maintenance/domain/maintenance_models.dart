enum MaintenanceLocationType {
  room('ROOM', 'Quarto'),
  commonArea('COMMON_AREA', 'Area comum');

  const MaintenanceLocationType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static MaintenanceLocationType tryParse(String? rawValue) {
    for (final MaintenanceLocationType value in MaintenanceLocationType.values) {
      if (value.apiValue == rawValue) {
        return value;
      }
    }
    return MaintenanceLocationType.room;
  }
}

enum MaintenanceProviderType {
  internal('INTERNAL', 'Interno'),
  external('EXTERNAL', 'Externo');

  const MaintenanceProviderType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static MaintenanceProviderType tryParse(String? rawValue) {
    for (final MaintenanceProviderType value in MaintenanceProviderType.values) {
      if (value.apiValue == rawValue) {
        return value;
      }
    }
    return MaintenanceProviderType.internal;
  }
}

enum MaintenanceOrderStatus {
  open('OPEN', 'Aberta'),
  scheduled('SCHEDULED', 'Agendada'),
  inProgress('IN_PROGRESS', 'Em andamento'),
  completed('COMPLETED', 'Concluida'),
  cancelled('CANCELLED', 'Cancelada');

  const MaintenanceOrderStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static MaintenanceOrderStatus tryParse(String? rawValue) {
    for (final MaintenanceOrderStatus value in MaintenanceOrderStatus.values) {
      if (value.apiValue == rawValue) {
        return value;
      }
    }
    return MaintenanceOrderStatus.open;
  }
}

enum MaintenancePriority {
  low('LOW', 'Baixa'),
  medium('MEDIUM', 'Media'),
  high('HIGH', 'Alta'),
  urgent('URGENT', 'Urgente');

  const MaintenancePriority(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static MaintenancePriority tryParse(String? rawValue) {
    for (final MaintenancePriority value in MaintenancePriority.values) {
      if (value.apiValue == rawValue) {
        return value;
      }
    }
    return MaintenancePriority.medium;
  }
}

enum MaintenanceAttachmentType {
  photo('PHOTO', 'Foto'),
  attachment('ATTACHMENT', 'Arquivo');

  const MaintenanceAttachmentType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static MaintenanceAttachmentType tryParse(String? rawValue) {
    for (final MaintenanceAttachmentType value
        in MaintenanceAttachmentType.values) {
      if (value.apiValue == rawValue) {
        return value;
      }
    }
    return MaintenanceAttachmentType.attachment;
  }
}

enum MaintenanceSummaryGroupBy {
  provider('PROVIDER'),
  providerType('PROVIDER_TYPE'),
  locationType('LOCATION_TYPE'),
  status('STATUS');

  const MaintenanceSummaryGroupBy(this.apiValue);

  final String apiValue;
}

class MaintenanceLocation {
  const MaintenanceLocation({
    required this.id,
    required this.locationType,
    required this.code,
    required this.label,
    required this.floor,
    required this.description,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.updatedBy,
  });

  final int id;
  final MaintenanceLocationType locationType;
  final String code;
  final String label;
  final String? floor;
  final String? description;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  factory MaintenanceLocation.fromJson(Map<String, dynamic> json) {
    return MaintenanceLocation(
      id: _readInt(json, 'id') ?? 0,
      locationType: MaintenanceLocationType.tryParse(
        _readString(json, 'locationType'),
      ),
      code: _readString(json, 'code') ?? '',
      label: _readString(json, 'label') ?? '',
      floor: _trimOrNull(_readString(json, 'floor')),
      description: _trimOrNull(_readString(json, 'description')),
      active: json['active'] as bool? ?? false,
      createdAt: _tryParseDateTime(_readString(json, 'createdAt')),
      updatedAt: _tryParseDateTime(_readString(json, 'updatedAt')),
      createdBy: _trimOrNull(_readString(json, 'createdBy')),
      updatedBy: _trimOrNull(_readString(json, 'updatedBy')),
    );
  }
}

class MaintenanceProvider {
  const MaintenanceProvider({
    required this.id,
    required this.providerType,
    required this.name,
    required this.serviceLabel,
    required this.scopeDescription,
    required this.contact,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.updatedBy,
  });

  final int id;
  final MaintenanceProviderType providerType;
  final String name;
  final String serviceLabel;
  final String? scopeDescription;
  final String? contact;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  factory MaintenanceProvider.fromJson(Map<String, dynamic> json) {
    return MaintenanceProvider(
      id: _readInt(json, 'id') ?? 0,
      providerType: MaintenanceProviderType.tryParse(
        _readString(json, 'providerType'),
      ),
      name: _readString(json, 'name') ?? '',
      serviceLabel: _readString(json, 'serviceLabel') ?? '',
      scopeDescription: _trimOrNull(_readString(json, 'scopeDescription')),
      contact: _trimOrNull(_readString(json, 'contact')),
      active: json['active'] as bool? ?? false,
      createdAt: _tryParseDateTime(_readString(json, 'createdAt')),
      updatedAt: _tryParseDateTime(_readString(json, 'updatedAt')),
      createdBy: _trimOrNull(_readString(json, 'createdBy')),
      updatedBy: _trimOrNull(_readString(json, 'updatedBy')),
    );
  }
}

class MaintenanceOrderAttachment {
  const MaintenanceOrderAttachment({
    required this.id,
    required this.attachmentType,
    required this.fileName,
    required this.contentType,
    required this.fileSize,
    required this.createdAt,
    required this.createdBy,
  });

  final int id;
  final MaintenanceAttachmentType attachmentType;
  final String fileName;
  final String contentType;
  final int fileSize;
  final DateTime? createdAt;
  final String? createdBy;

  factory MaintenanceOrderAttachment.fromJson(Map<String, dynamic> json) {
    return MaintenanceOrderAttachment(
      id: _readInt(json, 'id') ?? 0,
      attachmentType: MaintenanceAttachmentType.tryParse(
        _readString(json, 'attachmentType'),
      ),
      fileName: _readString(json, 'fileName') ?? '',
      contentType: _readString(json, 'contentType') ?? '',
      fileSize: _readInt(json, 'fileSize') ?? 0,
      createdAt: _tryParseDateTime(_readString(json, 'createdAt')),
      createdBy: _trimOrNull(_readString(json, 'createdBy')),
    );
  }
}

class MaintenanceOrder {
  const MaintenanceOrder({
    required this.id,
    required this.locationId,
    required this.locationTypeSnapshot,
    required this.locationCodeSnapshot,
    required this.locationLabelSnapshot,
    required this.providerId,
    required this.providerTypeSnapshot,
    required this.providerNameSnapshot,
    required this.serviceLabelSnapshot,
    required this.title,
    required this.description,
    required this.priority,
    required this.status,
    required this.reportedAt,
    required this.scheduledStartAt,
    required this.scheduledEndAt,
    required this.startedAt,
    required this.completedAt,
    required this.resolutionNotes,
    required this.cancellationNotes,
    required this.attachments,
    required this.createdAt,
    required this.updatedAt,
    required this.cancelledAt,
    required this.createdBy,
    required this.updatedBy,
    required this.cancelledBy,
  });

  final int id;
  final int locationId;
  final MaintenanceLocationType locationTypeSnapshot;
  final String locationCodeSnapshot;
  final String locationLabelSnapshot;
  final int providerId;
  final MaintenanceProviderType providerTypeSnapshot;
  final String providerNameSnapshot;
  final String serviceLabelSnapshot;
  final String title;
  final String? description;
  final MaintenancePriority priority;
  final MaintenanceOrderStatus status;
  final DateTime reportedAt;
  final DateTime? scheduledStartAt;
  final DateTime? scheduledEndAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? resolutionNotes;
  final String? cancellationNotes;
  final List<MaintenanceOrderAttachment> attachments;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? cancelledAt;
  final String? createdBy;
  final String? updatedBy;
  final String? cancelledBy;

  factory MaintenanceOrder.fromJson(Map<String, dynamic> json) {
    final Object? attachmentsRaw = json['attachments'];
    return MaintenanceOrder(
      id: _readInt(json, 'id') ?? 0,
      locationId: _readInt(json, 'locationId') ?? 0,
      locationTypeSnapshot: MaintenanceLocationType.tryParse(
        _readString(json, 'locationTypeSnapshot'),
      ),
      locationCodeSnapshot: _readString(json, 'locationCodeSnapshot') ?? '',
      locationLabelSnapshot: _readString(json, 'locationLabelSnapshot') ?? '',
      providerId: _readInt(json, 'providerId') ?? 0,
      providerTypeSnapshot: MaintenanceProviderType.tryParse(
        _readString(json, 'providerTypeSnapshot'),
      ),
      providerNameSnapshot: _readString(json, 'providerNameSnapshot') ?? '',
      serviceLabelSnapshot: _readString(json, 'serviceLabelSnapshot') ?? '',
      title: _readString(json, 'title') ?? '',
      description: _trimOrNull(_readString(json, 'description')),
      priority: MaintenancePriority.tryParse(_readString(json, 'priority')),
      status: MaintenanceOrderStatus.tryParse(_readString(json, 'status')),
      reportedAt:
          _tryParseDateTime(_readString(json, 'reportedAt')) ?? DateTime.now(),
      scheduledStartAt: _tryParseDateTime(_readString(json, 'scheduledStartAt')),
      scheduledEndAt: _tryParseDateTime(_readString(json, 'scheduledEndAt')),
      startedAt: _tryParseDateTime(_readString(json, 'startedAt')),
      completedAt: _tryParseDateTime(_readString(json, 'completedAt')),
      resolutionNotes: _trimOrNull(_readString(json, 'resolutionNotes')),
      cancellationNotes: _trimOrNull(_readString(json, 'cancellationNotes')),
      attachments: attachmentsRaw is List
          ? attachmentsRaw
                .map<MaintenanceOrderAttachment>(
                  (Object? item) =>
                      MaintenanceOrderAttachment.fromJson(_asMap(item)),
                )
                .toList()
          : const <MaintenanceOrderAttachment>[],
      createdAt: _tryParseDateTime(_readString(json, 'createdAt')),
      updatedAt: _tryParseDateTime(_readString(json, 'updatedAt')),
      cancelledAt: _tryParseDateTime(_readString(json, 'cancelledAt')),
      createdBy: _trimOrNull(_readString(json, 'createdBy')),
      updatedBy: _trimOrNull(_readString(json, 'updatedBy')),
      cancelledBy: _trimOrNull(_readString(json, 'cancelledBy')),
    );
  }

  DateTime get referenceDate => scheduledStartAt ?? reportedAt;
}

class MaintenanceConflict {
  const MaintenanceConflict({
    required this.id,
    required this.title,
    required this.status,
    required this.locationLabelSnapshot,
    required this.providerNameSnapshot,
    required this.scheduledStartAt,
    required this.scheduledEndAt,
  });

  final int id;
  final String title;
  final MaintenanceOrderStatus status;
  final String locationLabelSnapshot;
  final String providerNameSnapshot;
  final DateTime? scheduledStartAt;
  final DateTime? scheduledEndAt;

  factory MaintenanceConflict.fromJson(Map<String, dynamic> json) {
    return MaintenanceConflict(
      id: _readInt(json, 'id') ?? 0,
      title: _readString(json, 'title') ?? '',
      status: MaintenanceOrderStatus.tryParse(_readString(json, 'status')),
      locationLabelSnapshot: _readString(json, 'locationLabelSnapshot') ?? '',
      providerNameSnapshot: _readString(json, 'providerNameSnapshot') ?? '',
      scheduledStartAt: _tryParseDateTime(_readString(json, 'scheduledStartAt')),
      scheduledEndAt: _tryParseDateTime(_readString(json, 'scheduledEndAt')),
    );
  }
}

class MaintenanceSummaryBreakdown {
  const MaintenanceSummaryBreakdown({
    required this.code,
    required this.label,
    required this.openCount,
    required this.scheduledCount,
    required this.inProgressCount,
    required this.completedCount,
    required this.cancelledCount,
    required this.urgentCount,
  });

  final String code;
  final String label;
  final int openCount;
  final int scheduledCount;
  final int inProgressCount;
  final int completedCount;
  final int cancelledCount;
  final int urgentCount;

  factory MaintenanceSummaryBreakdown.fromJson(Map<String, dynamic> json) {
    return MaintenanceSummaryBreakdown(
      code: _readString(json, 'code') ?? '',
      label: _readString(json, 'label') ?? '',
      openCount: _readInt(json, 'openCount') ?? 0,
      scheduledCount: _readInt(json, 'scheduledCount') ?? 0,
      inProgressCount: _readInt(json, 'inProgressCount') ?? 0,
      completedCount: _readInt(json, 'completedCount') ?? 0,
      cancelledCount: _readInt(json, 'cancelledCount') ?? 0,
      urgentCount: _readInt(json, 'urgentCount') ?? 0,
    );
  }

  int get totalCount =>
      openCount +
      scheduledCount +
      inProgressCount +
      completedCount +
      cancelledCount;
}

class MaintenanceSummaryReport {
  const MaintenanceSummaryReport({
    required this.openCount,
    required this.scheduledCount,
    required this.inProgressCount,
    required this.completedCount,
    required this.cancelledCount,
    required this.internalCount,
    required this.externalCount,
    required this.roomsCount,
    required this.commonAreasCount,
    required this.urgentCount,
    required this.averageResolutionHours,
    required this.providerBreakdown,
    required this.providerTypeBreakdown,
    required this.locationTypeBreakdown,
    required this.statusBreakdown,
  });

  final int openCount;
  final int scheduledCount;
  final int inProgressCount;
  final int completedCount;
  final int cancelledCount;
  final int internalCount;
  final int externalCount;
  final int roomsCount;
  final int commonAreasCount;
  final int urgentCount;
  final double averageResolutionHours;
  final List<MaintenanceSummaryBreakdown> providerBreakdown;
  final List<MaintenanceSummaryBreakdown> providerTypeBreakdown;
  final List<MaintenanceSummaryBreakdown> locationTypeBreakdown;
  final List<MaintenanceSummaryBreakdown> statusBreakdown;

  factory MaintenanceSummaryReport.fromJson(Map<String, dynamic> json) {
    return MaintenanceSummaryReport(
      openCount: _readInt(json, 'openCount') ?? 0,
      scheduledCount: _readInt(json, 'scheduledCount') ?? 0,
      inProgressCount: _readInt(json, 'inProgressCount') ?? 0,
      completedCount: _readInt(json, 'completedCount') ?? 0,
      cancelledCount: _readInt(json, 'cancelledCount') ?? 0,
      internalCount: _readInt(json, 'internalCount') ?? 0,
      externalCount: _readInt(json, 'externalCount') ?? 0,
      roomsCount: _readInt(json, 'roomsCount') ?? 0,
      commonAreasCount: _readInt(json, 'commonAreasCount') ?? 0,
      urgentCount: _readInt(json, 'urgentCount') ?? 0,
      averageResolutionHours:
          (json['averageResolutionHours'] as num?)?.toDouble() ?? 0,
      providerBreakdown: _readBreakdownList(json['providerBreakdown']),
      providerTypeBreakdown: _readBreakdownList(json['providerTypeBreakdown']),
      locationTypeBreakdown: _readBreakdownList(json['locationTypeBreakdown']),
      statusBreakdown: _readBreakdownList(json['statusBreakdown']),
    );
  }
}

class MaintenanceSummaryDetailItem {
  const MaintenanceSummaryDetailItem({
    required this.orderId,
    required this.locationType,
    required this.locationLabel,
    required this.providerType,
    required this.providerName,
    required this.serviceLabel,
    required this.title,
    required this.priority,
    required this.status,
    required this.reportedAt,
    required this.scheduledStartAt,
    required this.scheduledEndAt,
    required this.startedAt,
    required this.completedAt,
  });

  final int orderId;
  final MaintenanceLocationType locationType;
  final String locationLabel;
  final MaintenanceProviderType providerType;
  final String providerName;
  final String serviceLabel;
  final String title;
  final MaintenancePriority priority;
  final MaintenanceOrderStatus status;
  final DateTime? reportedAt;
  final DateTime? scheduledStartAt;
  final DateTime? scheduledEndAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  factory MaintenanceSummaryDetailItem.fromJson(Map<String, dynamic> json) {
    return MaintenanceSummaryDetailItem(
      orderId: _readInt(json, 'orderId') ?? 0,
      locationType: MaintenanceLocationType.tryParse(
        _readString(json, 'locationType'),
      ),
      locationLabel: _readString(json, 'locationLabel') ?? '',
      providerType: MaintenanceProviderType.tryParse(
        _readString(json, 'providerType'),
      ),
      providerName: _readString(json, 'providerName') ?? '',
      serviceLabel: _readString(json, 'serviceLabel') ?? '',
      title: _readString(json, 'title') ?? '',
      priority: MaintenancePriority.tryParse(_readString(json, 'priority')),
      status: MaintenanceOrderStatus.tryParse(_readString(json, 'status')),
      reportedAt: _tryParseDateTime(_readString(json, 'reportedAt')),
      scheduledStartAt: _tryParseDateTime(_readString(json, 'scheduledStartAt')),
      scheduledEndAt: _tryParseDateTime(_readString(json, 'scheduledEndAt')),
      startedAt: _tryParseDateTime(_readString(json, 'startedAt')),
      completedAt: _tryParseDateTime(_readString(json, 'completedAt')),
    );
  }
}

class MaintenanceSummaryDetail {
  const MaintenanceSummaryDetail({
    required this.groupBy,
    required this.code,
    required this.label,
    required this.summary,
    required this.items,
  });

  final MaintenanceSummaryGroupBy groupBy;
  final String code;
  final String label;
  final MaintenanceSummaryBreakdown summary;
  final List<MaintenanceSummaryDetailItem> items;

  factory MaintenanceSummaryDetail.fromJson(Map<String, dynamic> json) {
    final Object? itemsRaw = json['items'];
    return MaintenanceSummaryDetail(
      groupBy: MaintenanceSummaryGroupBy.values.firstWhere(
        (MaintenanceSummaryGroupBy value) =>
            value.apiValue == _readString(json, 'groupBy'),
        orElse: () => MaintenanceSummaryGroupBy.status,
      ),
      code: _readString(json, 'code') ?? '',
      label: _readString(json, 'label') ?? '',
      summary: MaintenanceSummaryBreakdown.fromJson(_asMap(json['summary'])),
      items: itemsRaw is List
          ? itemsRaw
                .map<MaintenanceSummaryDetailItem>(
                  (Object? item) =>
                      MaintenanceSummaryDetailItem.fromJson(_asMap(item)),
                )
                .toList()
          : const <MaintenanceSummaryDetailItem>[],
    );
  }
}

class CreateMaintenanceLocationModel {
  const CreateMaintenanceLocationModel({
    required this.locationType,
    required this.code,
    required this.label,
    required this.floor,
    required this.description,
    required this.active,
  });

  final MaintenanceLocationType locationType;
  final String code;
  final String label;
  final String? floor;
  final String? description;
  final bool active;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'locationType': locationType.apiValue,
      'code': code.trim(),
      'label': label.trim(),
      'floor': _trimOrNull(floor),
      'description': _trimOrNull(description),
      'active': active,
    };
  }
}

class UpdateMaintenanceLocationModel extends CreateMaintenanceLocationModel {
  const UpdateMaintenanceLocationModel({
    required super.locationType,
    required super.code,
    required super.label,
    required super.floor,
    required super.description,
    required super.active,
  });
}

class CreateMaintenanceProviderModel {
  const CreateMaintenanceProviderModel({
    required this.providerType,
    required this.name,
    required this.serviceLabel,
    required this.scopeDescription,
    required this.contact,
    required this.active,
  });

  final MaintenanceProviderType providerType;
  final String name;
  final String serviceLabel;
  final String? scopeDescription;
  final String? contact;
  final bool active;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'providerType': providerType.apiValue,
      'name': name.trim(),
      'serviceLabel': serviceLabel.trim(),
      'scopeDescription': _trimOrNull(scopeDescription),
      'contact': _trimOrNull(contact),
      'active': active,
    };
  }
}

class UpdateMaintenanceProviderModel extends CreateMaintenanceProviderModel {
  const UpdateMaintenanceProviderModel({
    required super.providerType,
    required super.name,
    required super.serviceLabel,
    required super.scopeDescription,
    required super.contact,
    required super.active,
  });
}

class CreateMaintenanceOrderModel {
  const CreateMaintenanceOrderModel({
    required this.locationId,
    required this.providerId,
    required this.title,
    required this.description,
    required this.priority,
    required this.scheduledStartAt,
    required this.scheduledEndAt,
  });

  final int locationId;
  final int providerId;
  final String title;
  final String? description;
  final MaintenancePriority priority;
  final String? scheduledStartAt;
  final String? scheduledEndAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'locationId': locationId,
      'providerId': providerId,
      'title': title.trim(),
      'description': _trimOrNull(description),
      'priority': priority.apiValue,
      'scheduledStartAt': _trimOrNull(scheduledStartAt),
      'scheduledEndAt': _trimOrNull(scheduledEndAt),
    };
  }
}

class UpdateMaintenanceOrderModel extends CreateMaintenanceOrderModel {
  const UpdateMaintenanceOrderModel({
    required super.locationId,
    required super.providerId,
    required super.title,
    required super.description,
    required super.priority,
    required super.scheduledStartAt,
    required super.scheduledEndAt,
  });
}

class StartMaintenanceOrderModel {
  const StartMaintenanceOrderModel({this.startedAt});

  final String? startedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'startedAt': _trimOrNull(startedAt)};
  }
}

class CompleteMaintenanceOrderModel {
  const CompleteMaintenanceOrderModel({
    required this.completedAt,
    required this.resolutionNotes,
  });

  final String? completedAt;
  final String resolutionNotes;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'completedAt': _trimOrNull(completedAt),
      'resolutionNotes': resolutionNotes.trim(),
    };
  }
}

class CancelMaintenanceOrderModel {
  const CancelMaintenanceOrderModel({required this.cancellationNotes});

  final String cancellationNotes;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'cancellationNotes': cancellationNotes.trim(),
    };
  }
}

class AddMaintenanceAttachmentModel {
  const AddMaintenanceAttachmentModel({
    required this.attachmentType,
    required this.fileName,
    required this.contentType,
    required this.base64Content,
  });

  final MaintenanceAttachmentType attachmentType;
  final String fileName;
  final String contentType;
  final String base64Content;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'attachmentType': attachmentType.apiValue,
      'fileName': fileName,
      'contentType': contentType,
      'base64Content': base64Content,
    };
  }
}

List<MaintenanceSummaryBreakdown> _readBreakdownList(Object? rawValue) {
  if (rawValue is! List) {
    return const <MaintenanceSummaryBreakdown>[];
  }
  return rawValue
      .map<MaintenanceSummaryBreakdown>(
        (Object? item) => MaintenanceSummaryBreakdown.fromJson(_asMap(item)),
      )
      .toList();
}

String? _trimOrNull(String? value) {
  if (value == null) {
    return null;
  }
  final String normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

DateTime? _tryParseDateTime(String? rawValue) {
  if (rawValue == null || rawValue.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(rawValue)?.toLocal();
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is! Map) {
    return const <String, dynamic>{};
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
