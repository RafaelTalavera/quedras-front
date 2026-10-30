import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/sync/schedule_sync_event.dart';
import '../application/maintenance_app_service.dart';
import '../domain/maintenance_models.dart';

class MaintenanceNotificationBell extends StatefulWidget {
  const MaintenanceNotificationBell({
    required this.service,
    required this.syncEvents,
    required this.onOpenNotification,
    this.refreshEvents,
    super.key,
  });

  final MaintenanceAppService service;
  final Stream<ScheduleSyncEvent> syncEvents;
  final ValueChanged<MaintenanceNotificationModel> onOpenNotification;
  final Stream<void>? refreshEvents;

  @override
  State<MaintenanceNotificationBell> createState() =>
      _MaintenanceNotificationBellState();
}

class _MaintenanceNotificationBellState
    extends State<MaintenanceNotificationBell>
    with WidgetsBindingObserver {
  int _unreadCount = 0;
  bool _loadingCount = false;
  bool _loadingNotifications = false;
  bool _primedNotifications = false;
  final Set<int> _knownNotificationIds = <int>{};
  StreamSubscription<ScheduleSyncEvent>? _syncSubscription;
  StreamSubscription<void>? _refreshSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncSubscription = widget.syncEvents.listen(_handleSyncEvent);
    _refreshSubscription = widget.refreshEvents?.listen((_) {
      unawaited(_refreshNotifications(autoOpenNew: true));
    });
    unawaited(_refreshNotifications());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncSubscription?.cancel();
    _refreshSubscription?.cancel();
    super.dispose();
  }

  void _handleSyncEvent(ScheduleSyncEvent event) {
    if (event.domain == ScheduleSyncDomain.maintenance &&
        event.action == 'notifications-changed') {
      unawaited(_refreshNotifications(autoOpenNew: true));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshNotifications());
    }
  }

  Future<void> _refreshNotifications({bool autoOpenNew = false}) async {
    if (_loadingNotifications) return;
    _loadingNotifications = true;
    try {
      final MaintenanceNotificationPage page = await widget.service
          .listNotifications(
            status: MaintenanceNotificationStatus.unread,
            page: 0,
            size: 100,
          );
      if (!mounted) return;
      final List<MaintenanceNotificationModel> newNotifications =
          _primedNotifications && autoOpenNew
          ? page.items
                .where(
                  (MaintenanceNotificationModel item) =>
                      !_knownNotificationIds.contains(item.id),
                )
                .toList()
          : const <MaintenanceNotificationModel>[];
      _knownNotificationIds.addAll(
        page.items.map((MaintenanceNotificationModel item) => item.id),
      );
      _primedNotifications = true;
      await _refreshCount();
      if (newNotifications.isNotEmpty && mounted) {
        newNotifications.sort(
          (MaintenanceNotificationModel a, MaintenanceNotificationModel b) =>
              a.createdAt.compareTo(b.createdAt),
        );
        final MaintenanceNotificationModel notification =
            newNotifications.first;
        try {
          await widget.service.markNotificationRead(notification.id);
        } catch (_) {
          // La accion operativa sigue siendo prioritaria aunque falle la lectura.
        }
        if (mounted) {
          widget.onOpenNotification(notification);
          unawaited(_refreshCount());
        }
      }
    } catch (_) {
      // La campana conserva el ultimo estado conocido y permite reintentar.
    } finally {
      _loadingNotifications = false;
    }
  }

  Future<void> _refreshCount() async {
    if (_loadingCount) return;
    _loadingCount = true;
    try {
      final int count = await widget.service.getUnreadNotificationCount();
      if (mounted) setState(() => _unreadCount = count);
    } catch (_) {
      // La campana sigue disponible; la bandeja mostrara el error detallado.
    } finally {
      _loadingCount = false;
    }
  }

  Future<void> _openInbox() async {
    final MaintenanceNotificationModel? selected =
        await showDialog<MaintenanceNotificationModel>(
          context: context,
          builder: (BuildContext context) => _MaintenanceNotificationDialog(
            service: widget.service,
            syncEvents: widget.syncEvents,
          ),
        );
    await _refreshCount();
    if (selected != null && mounted) {
      widget.onOpenNotification(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String countLabel = _unreadCount > 99 ? '99+' : '$_unreadCount';
    return Semantics(
      button: true,
      label: _unreadCount == 0
          ? 'Notificacoes de manutencao'
          : 'Notificacoes de manutencao, $_unreadCount nao lidas',
      child: Material(
        color: Colors.white.withValues(alpha: 0.94),
        shape: const CircleBorder(),
        elevation: 4,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            IconButton(
              key: const Key('maintenance-notification-bell'),
              tooltip: 'Notificacoes',
              onPressed: _openInbox,
              icon: const Icon(Icons.notifications_outlined),
            ),
            if (_unreadCount > 0)
              Positioned(
                top: -3,
                right: -4,
                child: Container(
                  key: const Key('maintenance-notification-badge'),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    countLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MaintenanceNotificationDialog extends StatefulWidget {
  const _MaintenanceNotificationDialog({
    required this.service,
    required this.syncEvents,
  });

  final MaintenanceAppService service;
  final Stream<ScheduleSyncEvent> syncEvents;

  @override
  State<_MaintenanceNotificationDialog> createState() =>
      _MaintenanceNotificationDialogState();
}

class _MaintenanceNotificationDialogState
    extends State<_MaintenanceNotificationDialog> {
  bool _loading = true;
  String? _error;
  List<MaintenanceNotificationModel> _items =
      const <MaintenanceNotificationModel>[];
  final Set<int> _busyIds = <int>{};
  StreamSubscription<ScheduleSyncEvent>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _syncSubscription = widget.syncEvents.listen(_handleSyncEvent);
    unawaited(_load());
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  void _handleSyncEvent(ScheduleSyncEvent event) {
    if (event.domain == ScheduleSyncDomain.maintenance &&
        event.action == 'notifications-changed') {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final MaintenanceNotificationPage page = await widget.service
          .listNotifications(size: 50);
      if (mounted) {
        setState(() {
          _items = page.items;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString().replaceFirst('Bad state: ', '');
        });
      }
    }
  }

  Future<void> _open(MaintenanceNotificationModel notification) async {
    if (_busyIds.contains(notification.id)) return;
    setState(() => _busyIds.add(notification.id));
    try {
      if (notification.status == MaintenanceNotificationStatus.unread) {
        await widget.service.markNotificationRead(notification.id);
      }
      if (mounted) Navigator.of(context).pop(notification);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busyIds.remove(notification.id);
          _error = error.toString().replaceFirst('Bad state: ', '');
        });
      }
    }
  }

  Future<void> _dismiss(MaintenanceNotificationModel notification) async {
    if (_busyIds.contains(notification.id)) return;
    setState(() => _busyIds.add(notification.id));
    try {
      await widget.service.dismissNotification(notification.id);
      if (mounted) {
        setState(() {
          _busyIds.remove(notification.id);
          _items = _items
              .where(
                (MaintenanceNotificationModel item) =>
                    item.id != notification.id,
              )
              .toList();
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busyIds.remove(notification.id);
          _error = error.toString().replaceFirst('Bad state: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Notificacoes de manutencao'),
      content: SizedBox(
        width: 560,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (_items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Text('Nenhuma notificacao disponivel.'),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (BuildContext context, int index) {
                          final MaintenanceNotificationModel item =
                              _items[index];
                          final bool busy = _busyIds.contains(item.id);
                          return ListTile(
                            key: ValueKey<String>(
                              'maintenance-notification-${item.id}',
                            ),
                            leading: Icon(
                              item.notificationType ==
                                      MaintenanceNotificationType.overdue
                                  ? Icons.warning_amber_rounded
                                  : Icons.schedule_rounded,
                            ),
                            title: Text(
                              item.title,
                              style: TextStyle(
                                fontWeight:
                                    item.status ==
                                        MaintenanceNotificationStatus.unread
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(item.body),
                            onTap: busy ? null : () => _open(item),
                            trailing: IconButton(
                              tooltip: 'Descartar',
                              onPressed: busy ? null : () => _dismiss(item),
                              icon: busy
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.close_rounded),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
      ),
      actions: <Widget>[
        if (_error != null)
          TextButton(onPressed: _load, child: const Text('Tentar novamente')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}
