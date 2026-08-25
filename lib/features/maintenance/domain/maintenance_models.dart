enum MaintenanceLocationType {
  room('ROOM', 'Quarto'),
  commonArea('COMMON_AREA', 'Area comum');

  const MaintenanceLocationType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static MaintenanceLocationType tryParse(String? rawValue) {
    for (final MaintenanceLocationType value
        in MaintenanceLocationType.values) {
      if (value.apiValue == rawValue) {
        return value;
      }
    }
    return MaintenanceLocationType.room;
  }
}

enum MaintenanceLocationCategory {
  apartment('APARTMENT', 'Apartamento'),
  chalet('CHALET', 'Chalet'),
  commonArea('COMMON_AREA', 'Area comum');

  const MaintenanceLocationCategory(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static MaintenanceLocationCategory tryParse(
    String? rawValue, {
    MaintenanceLocationType? fallbackType,
  }) {
    for (final MaintenanceLocationCategory value
        in MaintenanceLocationCategory.values) {
      if (value.apiValue == rawValue) {
        return value;
      }
    }
    if (fallbackType == MaintenanceLocationType.commonArea) {
      return MaintenanceLocationCategory.commonArea;
    }
    return MaintenanceLocationCategory.apartment;
  }
}

enum MaintenanceProviderType {
  internal('INTERNAL', 'Interno'),
  external('EXTERNAL', 'Externo');

  const MaintenanceProviderType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static MaintenanceProviderType tryParse(String? rawValue) {
    for (final MaintenanceProviderType value
        in MaintenanceProviderType.values) {
      if (value.apiValue == rawValue) {
        return value;
      }
    }
    return MaintenanceProviderType.internal;
  }

  static MaintenanceProviderType? tryParseNullable(String? rawValue) {
    if (rawValue == null) {
      return null;
    }
    for (final MaintenanceProviderType value
        in MaintenanceProviderType.values) {
      if (value.apiValue == rawValue) {
        return value;
      }
    }
    return null;
  }
}

enum MaintenanceProviderSpecialty {
  generalMaintenance('GENERAL_MAINTENANCE', 'Manutencao geral'),
  elevators('ELEVATORS', 'Elevadores'),
  airConditioning('AIR_CONDITIONING', 'Ar-condicionado'),
  internet('INTERNET', 'Internet');

  const MaintenanceProviderSpecialty(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static MaintenanceProviderSpecialty tryParse(String? rawValue) {
    for (final MaintenanceProviderSpecialty value
        in MaintenanceProviderSpecialty.values) {
      if (value.apiValue == rawValue) {
        return value;
      }
    }
    return MaintenanceProviderSpecialty.generalMaintenance;
  }
}

enum MaintenanceOrderKind {
  corrective('CORRECTIVE', 'Corretiva'),
  preventive('PREVENTIVE', 'Preventiva'),
  visit('VISIT', 'Visita');

  const MaintenanceOrderKind(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static MaintenanceOrderKind tryParse(String? rawValue) {
    for (final MaintenanceOrderKind value in MaintenanceOrderKind.values) {
      if (value.apiValue == rawValue) {
        return value;
      }
    }
    return MaintenanceOrderKind.corrective;
  }
}

enum MaintenancePlanRecurrenceUnit {
  monthly('MONTHLY', 'Mensal'),
  yearly('YEARLY', 'Anual');

  const MaintenancePlanRecurrenceUnit(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static MaintenancePlanRecurrenceUnit tryParse(String? rawValue) {
    for (final MaintenancePlanRecurrenceUnit value
        in MaintenancePlanRecurrenceUnit.values) {
      if (value.apiValue == rawValue) {
        return value;
      }
    }
    return MaintenancePlanRecurrenceUnit.monthly;
  }
}

enum MaintenanceOrderStatus {
  open('OPEN', 'Aberta'),
  assigned('ASSIGNED', 'Atribuida'),
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

enum MaintenanceRequestOrigin {
  internalRole('INTERNAL_ROLE', 'Pedido interno'),
  guestRequest('GUEST_REQUEST', 'Pedido de hospede');

  const MaintenanceRequestOrigin(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static MaintenanceRequestOrigin tryParse(String? rawValue) {
    for (final MaintenanceRequestOrigin value
        in MaintenanceRequestOrigin.values) {
      if (value.apiValue == rawValue) {
        return value;
      }
    }
    return MaintenanceRequestOrigin.internalRole;
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
    required this.locationCategory,
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
  final MaintenanceLocationCategory locationCategory;
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
      locationCategory: MaintenanceLocationCategory.tryParse(
        _readString(json, 'locationCategory'),
        fallbackType: MaintenanceLocationType.tryParse(
          _readString(json, 'locationType'),
        ),
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
    required this.specialty,
    required this.name,
    required this.serviceLabel,
    required this.scopeDescription,
    required this.contact,
    this.whatsappNumber,
    this.whatsappEnabled = false,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.updatedBy,
  });

  final int id;
  final MaintenanceProviderType providerType;
  final MaintenanceProviderSpecialty specialty;
  final String name;
  final String serviceLabel;
  final String? scopeDescription;
  final String? contact;
  final String? whatsappNumber;
  final bool whatsappEnabled;
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
      specialty: MaintenanceProviderSpecialty.tryParse(
        _readString(json, 'specialty'),
      ),
      name: _readString(json, 'name') ?? '',
      serviceLabel: _readString(json, 'serviceLabel') ?? '',
      scopeDescription: _trimOrNull(_readString(json, 'scopeDescription')),
      contact: _trimOrNull(_readString(json, 'contact')),
      whatsappNumber: _trimOrNull(_readString(json, 'whatsappNumber')),
      whatsappEnabled: json['whatsappEnabled'] == true,
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
    required this.planId,
    required this.providerTypeSnapshot,
    required this.providerNameSnapshot,
    required this.serviceLabelSnapshot,
    required this.orderKind,
    required this.title,
    required this.description,
    required this.priority,
    required this.requestOrigin,
    required this.requestedForGuest,
    required this.guestName,
    required this.requestedByUsername,
    required this.requestedByRole,
    required this.estimatedExecutionMinutes,
    required this.assignedUsername,
    required this.assignedAt,
    required this.status,
    required this.reportedAt,
    required this.expectedCompletionAt,
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
  final int? providerId;
  final int? planId;
  final MaintenanceProviderType? providerTypeSnapshot;
  final String? providerNameSnapshot;
  final String? serviceLabelSnapshot;
  final MaintenanceOrderKind orderKind;
  final String title;
  final String? description;
  final MaintenancePriority priority;
  final MaintenanceRequestOrigin requestOrigin;
  final bool requestedForGuest;
  final String? guestName;
  final String? requestedByUsername;
  final String? requestedByRole;
  final int? estimatedExecutionMinutes;
  final String? assignedUsername;
  final DateTime? assignedAt;
  final MaintenanceOrderStatus status;
  final DateTime reportedAt;
  final DateTime? expectedCompletionAt;
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
      providerId: _readInt(json, 'providerId'),
      planId: _readInt(json, 'planId'),
      providerTypeSnapshot: MaintenanceProviderType.tryParseNullable(
        _readString(json, 'providerTypeSnapshot'),
      ),
      providerNameSnapshot: _trimOrNull(
        _readString(json, 'providerNameSnapshot'),
      ),
      serviceLabelSnapshot: _trimOrNull(
        _readString(json, 'serviceLabelSnapshot'),
      ),
      orderKind: MaintenanceOrderKind.tryParse(_readString(json, 'orderKind')),
      title: _readString(json, 'title') ?? '',
      description: _trimOrNull(_readString(json, 'description')),
      priority: MaintenancePriority.tryParse(_readString(json, 'priority')),
      requestOrigin: MaintenanceRequestOrigin.tryParse(
        _readString(json, 'requestOrigin'),
      ),
      requestedForGuest: json['requestedForGuest'] as bool? ?? false,
      guestName: _trimOrNull(_readString(json, 'guestName')),
      requestedByUsername: _trimOrNull(
        _readString(json, 'requestedByUsername'),
      ),
      requestedByRole: _trimOrNull(_readString(json, 'requestedByRole')),
      estimatedExecutionMinutes: _readInt(json, 'estimatedExecutionMinutes'),
      assignedUsername: _trimOrNull(_readString(json, 'assignedUsername')),
      assignedAt: _tryParseDateTime(_readString(json, 'assignedAt')),
      status: MaintenanceOrderStatus.tryParse(_readString(json, 'status')),
      reportedAt:
          _tryParseDateTime(_readString(json, 'reportedAt')) ?? DateTime.now(),
      expectedCompletionAt: _tryParseDateTime(
        _readString(json, 'expectedCompletionAt'),
      ),
      scheduledStartAt: _tryParseDateTime(
        _readString(json, 'scheduledStartAt'),
      ),
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

  String get providerLabel =>
      _trimOrNull(providerNameSnapshot) ?? 'Sem responsavel';

  String get serviceLabel =>
      _trimOrNull(serviceLabelSnapshot) ?? 'Servico nao definido';

  String get locationLabel => locationLabelSnapshot.trim();

  String? get locationReference {
    final String code = locationCodeSnapshot.trim();
    return code.isEmpty ? null : code;
  }

  String get locationDisplayLabel {
    final String? reference = locationReference;
    if (reference == null) {
      return locationLabel;
    }
    if (locationLabel.trimLeft().startsWith('$reference -')) {
      return locationLabel;
    }
    return '$locationLabel - Ref. $reference';
  }

  bool get hasGuestContext =>
      requestedForGuest ||
      requestOrigin == MaintenanceRequestOrigin.guestRequest;

  String? get guestLabel => _trimOrNull(guestName);
}

class MaintenancePlan {
  const MaintenancePlan({
    required this.id,
    required this.locationId,
    required this.locationCode,
    required this.locationLabel,
    required this.providerId,
    required this.providerType,
    required this.providerSpecialty,
    required this.providerName,
    required this.serviceLabel,
    required this.title,
    required this.description,
    required this.recurrenceUnit,
    required this.recurrenceInterval,
    required this.nextDueDate,
    required this.lastGeneratedOn,
    required this.active,
    this.whatsappNumber,
    this.whatsappEnabled = false,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.updatedBy,
  });

  final int id;
  final int locationId;
  final String locationCode;
  final String locationLabel;
  final int? providerId;
  final MaintenanceProviderType? providerType;
  final MaintenanceProviderSpecialty? providerSpecialty;
  final String? providerName;
  final String? serviceLabel;
  final String title;
  final String? description;
  final MaintenancePlanRecurrenceUnit recurrenceUnit;
  final int recurrenceInterval;
  final DateTime? nextDueDate;
  final DateTime? lastGeneratedOn;
  final bool active;
  final String? whatsappNumber;
  final bool whatsappEnabled;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  factory MaintenancePlan.fromJson(Map<String, dynamic> json) {
    return MaintenancePlan(
      id: _readInt(json, 'id') ?? 0,
      locationId: _readInt(json, 'locationId') ?? 0,
      locationCode: _readString(json, 'locationCode') ?? '',
      locationLabel: _readString(json, 'locationLabel') ?? '',
      providerId: _readInt(json, 'providerId'),
      providerType: MaintenanceProviderType.tryParseNullable(
        _readString(json, 'providerType'),
      ),
      providerSpecialty: _tryParseProviderSpecialty(
        _readString(json, 'providerSpecialty'),
      ),
      providerName: _trimOrNull(_readString(json, 'providerName')),
      serviceLabel: _trimOrNull(_readString(json, 'serviceLabel')),
      title: _readString(json, 'title') ?? '',
      description: _trimOrNull(_readString(json, 'description')),
      recurrenceUnit: MaintenancePlanRecurrenceUnit.tryParse(
        _readString(json, 'recurrenceUnit'),
      ),
      recurrenceInterval: _readInt(json, 'recurrenceInterval') ?? 1,
      nextDueDate: _tryParseDate(_readString(json, 'nextDueDate')),
      lastGeneratedOn: _tryParseDate(_readString(json, 'lastGeneratedOn')),
      active: json['active'] as bool? ?? false,
      createdAt: _tryParseDateTime(_readString(json, 'createdAt')),
      updatedAt: _tryParseDateTime(_readString(json, 'updatedAt')),
      createdBy: _trimOrNull(_readString(json, 'createdBy')),
      updatedBy: _trimOrNull(_readString(json, 'updatedBy')),
    );
  }

  String get recurrenceLabel {
    final String interval = recurrenceInterval == 1
        ? ''
        : '$recurrenceInterval ';
    return '$interval${recurrenceUnit.label}'.trim();
  }
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
  final String? providerNameSnapshot;
  final DateTime? scheduledStartAt;
  final DateTime? scheduledEndAt;

  factory MaintenanceConflict.fromJson(Map<String, dynamic> json) {
    return MaintenanceConflict(
      id: _readInt(json, 'id') ?? 0,
      title: _readString(json, 'title') ?? '',
      status: MaintenanceOrderStatus.tryParse(_readString(json, 'status')),
      locationLabelSnapshot: _readString(json, 'locationLabelSnapshot') ?? '',
      providerNameSnapshot: _trimOrNull(
        _readString(json, 'providerNameSnapshot'),
      ),
      scheduledStartAt: _tryParseDateTime(
        _readString(json, 'scheduledStartAt'),
      ),
      scheduledEndAt: _tryParseDateTime(_readString(json, 'scheduledEndAt')),
    );
  }
}

class MaintenanceSummaryBreakdown {
  const MaintenanceSummaryBreakdown({
    required this.groupKey,
    required this.code,
    required this.label,
    required this.openCount,
    required this.scheduledCount,
    required this.inProgressCount,
    required this.completedCount,
    required this.cancelledCount,
    required this.urgentCount,
  });

  final String groupKey;
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
      groupKey:
          _readString(json, 'groupKey') ?? _readString(json, 'code') ?? '',
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
    required this.assignedCount,
    required this.scheduledCount,
    required this.inProgressCount,
    required this.completedCount,
    required this.cancelledCount,
    required this.internalCount,
    required this.externalCount,
    required this.unassignedCount,
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
  final int assignedCount;
  final int scheduledCount;
  final int inProgressCount;
  final int completedCount;
  final int cancelledCount;
  final int internalCount;
  final int externalCount;
  final int unassignedCount;
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
      assignedCount: _readInt(json, 'assignedCount') ?? 0,
      scheduledCount: _readInt(json, 'scheduledCount') ?? 0,
      inProgressCount: _readInt(json, 'inProgressCount') ?? 0,
      completedCount: _readInt(json, 'completedCount') ?? 0,
      cancelledCount: _readInt(json, 'cancelledCount') ?? 0,
      internalCount: _readInt(json, 'internalCount') ?? 0,
      externalCount: _readInt(json, 'externalCount') ?? 0,
      unassignedCount: _readInt(json, 'unassignedCount') ?? 0,
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

class MaintenanceDailyExecutiveReport {
  const MaintenanceDailyExecutiveReport({
    required this.carryOverOpenCount,
    required this.dayOpenCount,
    required this.totalOpenCount,
    required this.urgentCount,
    required this.scheduledCount,
    required this.inProgressCount,
    required this.unassignedCount,
    required this.carryOverOrders,
    required this.dayOpenOrders,
  });

  final int carryOverOpenCount;
  final int dayOpenCount;
  final int totalOpenCount;
  final int urgentCount;
  final int scheduledCount;
  final int inProgressCount;
  final int unassignedCount;
  final List<MaintenanceOrder> carryOverOrders;
  final List<MaintenanceOrder> dayOpenOrders;

  List<MaintenanceOrder> get allOpenOrders =>
      <MaintenanceOrder>[...carryOverOrders, ...dayOpenOrders]
        ..sort((MaintenanceOrder a, MaintenanceOrder b) {
          final int byReference = a.referenceDate.compareTo(b.referenceDate);
          if (byReference != 0) {
            return byReference;
          }
          return a.id.compareTo(b.id);
        });

  factory MaintenanceDailyExecutiveReport.fromJson(Map<String, dynamic> json) {
    return MaintenanceDailyExecutiveReport(
      carryOverOpenCount: _readInt(json, 'carryOverOpenCount') ?? 0,
      dayOpenCount: _readInt(json, 'dayOpenCount') ?? 0,
      totalOpenCount: _readInt(json, 'totalOpenCount') ?? 0,
      urgentCount: _readInt(json, 'urgentCount') ?? 0,
      scheduledCount: _readInt(json, 'scheduledCount') ?? 0,
      inProgressCount: _readInt(json, 'inProgressCount') ?? 0,
      unassignedCount: _readInt(json, 'unassignedCount') ?? 0,
      carryOverOrders: _readOrderList(json['carryOverOrders']),
      dayOpenOrders: _readOrderList(json['dayOpenOrders']),
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
    required this.requestOrigin,
    required this.requestedForGuest,
    required this.assignedUsername,
    required this.estimatedExecutionMinutes,
    required this.status,
    required this.reportedAt,
    required this.expectedCompletionAt,
    required this.scheduledStartAt,
    required this.scheduledEndAt,
    required this.startedAt,
    required this.completedAt,
  });

  final int orderId;
  final MaintenanceLocationType locationType;
  final String locationLabel;
  final MaintenanceProviderType? providerType;
  final String? providerName;
  final String? serviceLabel;
  final String title;
  final MaintenancePriority priority;
  final MaintenanceRequestOrigin requestOrigin;
  final bool requestedForGuest;
  final String? assignedUsername;
  final int? estimatedExecutionMinutes;
  final MaintenanceOrderStatus status;
  final DateTime? reportedAt;
  final DateTime? expectedCompletionAt;
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
      providerType: MaintenanceProviderType.tryParseNullable(
        _readString(json, 'providerType'),
      ),
      providerName: _trimOrNull(_readString(json, 'providerName')),
      serviceLabel: _trimOrNull(_readString(json, 'serviceLabel')),
      title: _readString(json, 'title') ?? '',
      priority: MaintenancePriority.tryParse(_readString(json, 'priority')),
      requestOrigin: MaintenanceRequestOrigin.tryParse(
        _readString(json, 'requestOrigin'),
      ),
      requestedForGuest: json['requestedForGuest'] as bool? ?? false,
      assignedUsername: _trimOrNull(_readString(json, 'assignedUsername')),
      estimatedExecutionMinutes: _readInt(json, 'estimatedExecutionMinutes'),
      status: MaintenanceOrderStatus.tryParse(_readString(json, 'status')),
      reportedAt: _tryParseDateTime(_readString(json, 'reportedAt')),
      expectedCompletionAt: _tryParseDateTime(
        _readString(json, 'expectedCompletionAt'),
      ),
      scheduledStartAt: _tryParseDateTime(
        _readString(json, 'scheduledStartAt'),
      ),
      scheduledEndAt: _tryParseDateTime(_readString(json, 'scheduledEndAt')),
      startedAt: _tryParseDateTime(_readString(json, 'startedAt')),
      completedAt: _tryParseDateTime(_readString(json, 'completedAt')),
    );
  }
}

class MaintenanceSummaryDetail {
  const MaintenanceSummaryDetail({
    required this.groupBy,
    required this.groupKey,
    required this.code,
    required this.label,
    required this.summary,
    required this.items,
  });

  final MaintenanceSummaryGroupBy groupBy;
  final String groupKey;
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
      groupKey:
          _readString(json, 'groupKey') ?? _readString(json, 'code') ?? '',
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
    required this.locationCategory,
    required this.code,
    required this.label,
    required this.floor,
    required this.description,
    required this.active,
  });

  final MaintenanceLocationType locationType;
  final MaintenanceLocationCategory locationCategory;
  final String code;
  final String label;
  final String? floor;
  final String? description;
  final bool active;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'locationType': locationType.apiValue,
      'locationCategory': locationCategory.apiValue,
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
    required super.locationCategory,
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
    required this.specialty,
    required this.name,
    required this.serviceLabel,
    required this.scopeDescription,
    required this.contact,
    required this.active,
    this.whatsappNumber,
    this.whatsappEnabled = false,
  });

  final MaintenanceProviderType providerType;
  final MaintenanceProviderSpecialty specialty;
  final String name;
  final String serviceLabel;
  final String? scopeDescription;
  final String? contact;
  final bool active;
  final String? whatsappNumber;
  final bool whatsappEnabled;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'providerType': providerType.apiValue,
      'specialty': specialty.apiValue,
      'name': name.trim(),
      'serviceLabel': serviceLabel.trim(),
      'scopeDescription': _trimOrNull(scopeDescription),
      'contact': _trimOrNull(contact),
      'active': active,
      'whatsappNumber': _trimOrNull(whatsappNumber),
      'whatsappEnabled': whatsappEnabled,
    };
  }
}

class UpdateMaintenanceProviderModel extends CreateMaintenanceProviderModel {
  const UpdateMaintenanceProviderModel({
    required super.providerType,
    required super.specialty,
    required super.name,
    required super.serviceLabel,
    required super.scopeDescription,
    required super.contact,
    required super.active,
    super.whatsappNumber,
    super.whatsappEnabled,
  });
}

class CreateMaintenanceOrderModel {
  const CreateMaintenanceOrderModel({
    required this.locationId,
    required this.providerId,
    required this.planId,
    required this.orderKind,
    required this.title,
    required this.description,
    required this.requestOrigin,
    required this.requestedForGuest,
    required this.guestName,
    required this.scheduledStartAt,
    required this.scheduledEndAt,
  });

  final int locationId;
  final int? providerId;
  final int? planId;
  final MaintenanceOrderKind orderKind;
  final String title;
  final String? description;
  final MaintenanceRequestOrigin requestOrigin;
  final bool requestedForGuest;
  final String? guestName;
  final String? scheduledStartAt;
  final String? scheduledEndAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'locationId': locationId,
      'providerId': providerId,
      'planId': planId,
      'orderKind': orderKind.apiValue,
      'title': title.trim(),
      'description': _trimOrNull(description),
      'requestOrigin': requestOrigin.apiValue,
      'requestedForGuest': requestedForGuest,
      'guestName': _trimOrNull(guestName),
      'scheduledStartAt': _trimOrNull(scheduledStartAt),
      'scheduledEndAt': _trimOrNull(scheduledEndAt),
    };
  }
}

class UpdateMaintenanceOrderModel extends CreateMaintenanceOrderModel {
  const UpdateMaintenanceOrderModel({
    required super.locationId,
    required super.providerId,
    required super.planId,
    required super.orderKind,
    required super.title,
    required super.description,
    required super.requestOrigin,
    required super.requestedForGuest,
    required super.guestName,
    required super.scheduledStartAt,
    required super.scheduledEndAt,
  });
}

class CreateMaintenancePlanModel {
  const CreateMaintenancePlanModel({
    required this.locationId,
    required this.providerId,
    required this.title,
    required this.description,
    required this.recurrenceUnit,
    required this.recurrenceInterval,
    required this.nextDueDate,
    required this.active,
  });

  final int locationId;
  final int? providerId;
  final String title;
  final String? description;
  final MaintenancePlanRecurrenceUnit recurrenceUnit;
  final int recurrenceInterval;
  final String nextDueDate;
  final bool active;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'locationId': locationId,
      'providerId': providerId,
      'title': title.trim(),
      'description': _trimOrNull(description),
      'recurrenceUnit': recurrenceUnit.apiValue,
      'recurrenceInterval': recurrenceInterval,
      'nextDueDate': nextDueDate,
      'active': active,
    };
  }
}

class UpdateMaintenancePlanModel extends CreateMaintenancePlanModel {
  const UpdateMaintenancePlanModel({
    required super.locationId,
    required super.providerId,
    required super.title,
    required super.description,
    required super.recurrenceUnit,
    required super.recurrenceInterval,
    required super.nextDueDate,
    required super.active,
  });
}

class GenerateMaintenancePlanOrderModel {
  const GenerateMaintenancePlanOrderModel({
    required this.scheduledStartAt,
    required this.scheduledEndAt,
  });

  final String? scheduledStartAt;
  final String? scheduledEndAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'scheduledStartAt': _trimOrNull(scheduledStartAt),
      'scheduledEndAt': _trimOrNull(scheduledEndAt),
    };
  }
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
    return <String, dynamic>{'cancellationNotes': cancellationNotes.trim()};
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

List<MaintenanceOrder> _readOrderList(Object? rawValue) {
  if (rawValue is! List) {
    return const <MaintenanceOrder>[];
  }
  return rawValue
      .map<MaintenanceOrder>(
        (Object? item) => MaintenanceOrder.fromJson(_asMap(item)),
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

DateTime? _tryParseDate(String? rawValue) {
  if (rawValue == null || rawValue.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(rawValue);
}

MaintenanceProviderSpecialty? _tryParseProviderSpecialty(String? rawValue) {
  if (rawValue == null) {
    return null;
  }
  for (final MaintenanceProviderSpecialty value
      in MaintenanceProviderSpecialty.values) {
    if (value.apiValue == rawValue) {
      return value;
    }
  }
  return null;
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
