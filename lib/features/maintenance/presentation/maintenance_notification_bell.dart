import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/sync/schedule_sync_event.dart';
import '../../../core/theme/costa_norte_brand.dart';
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
  final Set<int> _locallyReadIds = <int>{};
  bool _markingAllRead = false;
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
        _locallyReadIds.add(notification.id);
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

  bool _isUnread(MaintenanceNotificationModel notification) {
    return notification.status == MaintenanceNotificationStatus.unread &&
        !_locallyReadIds.contains(notification.id);
  }

  Future<void> _markRead(MaintenanceNotificationModel notification) async {
    if (_busyIds.contains(notification.id) || !_isUnread(notification)) return;
    setState(() => _busyIds.add(notification.id));
    try {
      await widget.service.markNotificationRead(notification.id);
      if (mounted) {
        setState(() {
          _busyIds.remove(notification.id);
          _locallyReadIds.add(notification.id);
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

  Future<void> _markAllRead() async {
    if (_markingAllRead) return;
    final List<MaintenanceNotificationModel> unreadItems = _items
        .where(_isUnread)
        .toList();
    if (unreadItems.isEmpty) return;
    setState(() {
      _markingAllRead = true;
      _error = null;
    });
    try {
      for (final MaintenanceNotificationModel item in unreadItems) {
        await widget.service.markNotificationRead(item.id);
        _locallyReadIds.add(item.id);
      }
    } catch (error) {
      _error = error.toString().replaceFirst('Bad state: ', '');
    } finally {
      if (mounted) setState(() => _markingAllRead = false);
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
    final Size screen = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: screen.height * 0.86,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Seus pendentes',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    if (_items.any(_isUnread))
                      TextButton(
                        key: const Key('mark-all-notifications-read'),
                        onPressed: _markingAllRead ? null : _markAllRead,
                        child: _markingAllRead
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Marcar tudo como lido'),
                      ),
                    IconButton(
                      tooltip: 'Fechar',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _load,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              Flexible(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: CostaNorteBrand.mist,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _items.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 48),
                            child: Text('Nenhum pendente no momento.'),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          itemCount: _items.length,
                          separatorBuilder: (_, _) => const Divider(
                            height: 1,
                            indent: 24,
                            endIndent: 24,
                          ),
                          itemBuilder: (BuildContext context, int index) =>
                              _buildPendingItem(_items[index]),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingItem(MaintenanceNotificationModel item) {
    final bool busy = _busyIds.contains(item.id);
    final bool unread = _isUnread(item);
    final bool overdue =
        item.notificationType == MaintenanceNotificationType.overdue;
    final Color accent = overdue
        ? CostaNorteBrand.error
        : CostaNorteBrand.royalBlue;
    return Padding(
      key: ValueKey<String>('maintenance-notification-${item.id}'),
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              overdue ? Icons.warning_amber_rounded : Icons.schedule_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (unread) ...<Widget>[
                      Container(
                        key: ValueKey<String>('unread-dot-${item.id}'),
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(top: 6, right: 10),
                        decoration: const BoxDecoration(
                          color: CostaNorteBrand.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                    Expanded(
                      child: Text(
                        item.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: unread
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(item.body),
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed: busy ? null : () => _open(item),
                  child: const Text('Ver ordem'),
                ),
              ],
            ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            PopupMenuButton<_NotificationAction>(
              key: ValueKey<String>('notification-menu-${item.id}'),
              tooltip: 'Mais opções',
              onSelected: (_NotificationAction action) {
                switch (action) {
                  case _NotificationAction.open:
                    unawaited(_open(item));
                  case _NotificationAction.markRead:
                    unawaited(_markRead(item));
                  case _NotificationAction.dismiss:
                    unawaited(_dismiss(item));
                }
              },
              itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<_NotificationAction>>[
                    const PopupMenuItem<_NotificationAction>(
                      value: _NotificationAction.open,
                      child: Text('Ver ordem'),
                    ),
                    if (unread)
                      const PopupMenuItem<_NotificationAction>(
                        value: _NotificationAction.markRead,
                        child: Text('Marcar como lido'),
                      ),
                    const PopupMenuItem<_NotificationAction>(
                      value: _NotificationAction.dismiss,
                      child: Text('Descartar'),
                    ),
                  ],
            ),
        ],
      ),
    );
  }
}

enum _NotificationAction { open, markRead, dismiss }
