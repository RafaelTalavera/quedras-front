import 'dart:async';

import 'package:costanorte/core/sync/schedule_sync_event.dart';
import 'package:costanorte/features/maintenance/application/maintenance_app_service.dart';
import 'package:costanorte/features/maintenance/domain/maintenance_models.dart';
import 'package:costanorte/features/maintenance/presentation/maintenance_notification_bell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('campana muestra contador, marca lectura y abre la orden', (
    WidgetTester tester,
  ) async {
    final _NotificationService service = _NotificationService();
    final StreamController<ScheduleSyncEvent> syncEvents =
        StreamController<ScheduleSyncEvent>.broadcast();
    addTearDown(syncEvents.close);
    MaintenanceNotificationModel? opened;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MaintenanceNotificationBell(
            service: service,
            syncEvents: syncEvents.stream,
            onOpenNotification: (MaintenanceNotificationModel notification) {
              opened = notification;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('maintenance-notification-badge')),
      findsOneWidget,
    );
    expect(find.text('1'), findsOneWidget);

    syncEvents.add(
      const ScheduleSyncEvent(
        domain: ScheduleSyncDomain.maintenance,
        action: 'notifications-changed',
        entityId: null,
        dateFrom: null,
        dateTo: null,
      ),
    );
    await tester.pumpAndSettle();
    expect(service.countRequests, 2);

    await tester.tap(find.byKey(const Key('maintenance-notification-bell')));
    await tester.pumpAndSettle();
    expect(find.text('Manutencao atrasada'), findsOneWidget);

    await tester.tap(find.text('Manutencao atrasada'));
    await tester.pumpAndSettle();

    expect(service.readIds, <int>[7]);
    expect(opened?.orderId, 10);
  });

  testWidgets('aviso nuevo abre automaticamente la accion de la orden', (
    WidgetTester tester,
  ) async {
    final _NotificationService service = _NotificationService();
    final StreamController<ScheduleSyncEvent> syncEvents =
        StreamController<ScheduleSyncEvent>.broadcast();
    addTearDown(syncEvents.close);
    MaintenanceNotificationModel? opened;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MaintenanceNotificationBell(
            service: service,
            syncEvents: syncEvents.stream,
            onOpenNotification: (MaintenanceNotificationModel notification) {
              opened = notification;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    service.notifications.add(
      MaintenanceNotificationModel(
        id: 8,
        orderId: 11,
        notificationType: MaintenanceNotificationType.dueToStart,
        status: MaintenanceNotificationStatus.unread,
        title: 'Manutencao pronta para iniciar',
        body: 'Quarto 104 - Revisar tomada',
        dueAt: DateTime(2026, 10, 29, 9),
        readAt: null,
        resolvedAt: null,
        dismissedAt: null,
        createdAt: DateTime(2026, 10, 29, 9, 0, 1),
      ),
    );
    syncEvents.add(
      const ScheduleSyncEvent(
        domain: ScheduleSyncDomain.maintenance,
        action: 'notifications-changed',
        entityId: null,
        dateFrom: null,
        dateTo: null,
      ),
    );
    await tester.pumpAndSettle();

    expect(opened?.id, 8);
    expect(opened?.orderId, 11);
    expect(service.readIds, contains(8));
  });
}

class _NotificationService extends Fake implements MaintenanceAppService {
  final List<int> readIds = <int>[];
  final List<MaintenanceNotificationModel> notifications =
      <MaintenanceNotificationModel>[
        MaintenanceNotificationModel(
          id: 7,
          orderId: 10,
          notificationType: MaintenanceNotificationType.overdue,
          status: MaintenanceNotificationStatus.unread,
          title: 'Manutencao atrasada',
          body: 'Habitacion 209 - Revision nocturna',
          dueAt: DateTime(2026, 5, 1, 2),
          readAt: null,
          resolvedAt: null,
          dismissedAt: null,
          createdAt: DateTime(2026, 5, 1, 2, 1),
        ),
      ];
  int countRequests = 0;

  @override
  Future<int> getUnreadNotificationCount() async {
    countRequests += 1;
    return notifications.length;
  }

  @override
  Future<MaintenanceNotificationPage> listNotifications({
    MaintenanceNotificationStatus? status,
    int page = 0,
    int size = 20,
  }) async {
    return MaintenanceNotificationPage(
      page: page,
      size: size,
      hasNext: false,
      items: List<MaintenanceNotificationModel>.of(notifications),
    );
  }

  @override
  Future<void> markNotificationRead(int notificationId) async {
    readIds.add(notificationId);
  }

  @override
  Future<void> dismissNotification(int notificationId) async {}
}
