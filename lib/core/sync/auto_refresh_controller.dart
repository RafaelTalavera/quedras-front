import 'dart:async';

import 'package:flutter/widgets.dart';

final class AutoRefreshController {
  AutoRefreshController({
    required Duration interval,
    required Future<void> Function() onRefresh,
    bool Function()? canRefresh,
  }) : _interval = interval,
       _onRefresh = onRefresh,
       _canRefresh = canRefresh;

  final Duration _interval;
  final Future<void> Function() _onRefresh;
  final bool Function()? _canRefresh;

  Timer? _timer;
  bool _refreshing = false;

  bool get enabled => _interval > Duration.zero;

  void start() {
    if (!enabled || _timer != null) {
      return;
    }
    _timer = Timer.periodic(_interval, (_) {
      unawaited(refreshNow());
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> refreshNow() async {
    if (_refreshing) {
      return;
    }
    if (_canRefresh != null && !_canRefresh()) {
      return;
    }
    _refreshing = true;
    try {
      await _onRefresh();
    } finally {
      _refreshing = false;
    }
  }

  void handleLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        start();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        stop();
    }
  }

  void dispose() {
    stop();
  }
}
