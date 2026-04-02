import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NativeDockBridge extends NavigatorObserver with ChangeNotifier {
  NativeDockBridge._();

  static final NativeDockBridge instance = NativeDockBridge._();
  static const MethodChannel _channel = MethodChannel('accord/native_dock');

  bool _initialized = false;
  bool _nativeReady = false;
  NativeDockState? _pendingState;
  final Map<String, VoidCallback> _tapHandlers = <String, VoidCallback>{};
  final Map<String, VoidCallback> _holdHandlers = <String, VoidCallback>{};

  static bool get isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  bool get isReady => _nativeReady;

  Future<void> initialize() async {
    if (_initialized || !isSupportedPlatform) {
      return;
    }
    _initialized = true;
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  void register(NativeDockState state) {
    if (!isSupportedPlatform) {
      return;
    }
    _pendingState = state;
    _tapHandlers
      ..clear()
      ..addEntries(
        state.items.map((item) => MapEntry(item.id, item.onTap)),
      );
    _holdHandlers
      ..clear()
      ..addEntries(
        state.items
            .where((item) => item.onHoldComplete != null)
            .map((item) => MapEntry(item.id, item.onHoldComplete!)),
      );
    _scheduleSync();
  }

  void clearFromBuild() {
    if (!isSupportedPlatform) {
      return;
    }
    _pendingState = const NativeDockState.hidden();
    _tapHandlers.clear();
    _holdHandlers.clear();
    _scheduleSync();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    clearFromBuild();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    clearFromBuild();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    clearFromBuild();
  }

  @override
  void didReplace({
    Route<dynamic>? newRoute,
    Route<dynamic>? oldRoute,
  }) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    clearFromBuild();
  }

  void _scheduleSync() {
    if (!_initialized) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_sync());
    });
  }

  Future<void> _sync() async {
    if (!_initialized) {
      return;
    }
    try {
      await _channel.invokeMethod(
        'setDockState',
        (_pendingState ?? const NativeDockState.hidden()).toMap(),
      );
    } catch (_) {}
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'nativeDockReady':
        _nativeReady = true;
        notifyListeners();
        _scheduleSync();
        return null;
      case 'nativeDockTap':
        final id = call.arguments as String?;
        if (id != null) {
          _tapHandlers[id]?.call();
        }
        return null;
      case 'nativeDockLongPress':
        final id = call.arguments as String?;
        if (id != null) {
          _holdHandlers[id]?.call();
        }
        return null;
      default:
        throw MissingPluginException('Unknown method ${call.method}');
    }
  }
}

class NativeDockState {
  const NativeDockState({
    required this.visible,
    required this.compact,
    required this.tightToEdges,
    required this.items,
  });

  const NativeDockState.hidden()
      : visible = false,
        compact = true,
        tightToEdges = true,
        items = const <NativeDockItem>[];

  final bool visible;
  final bool compact;
  final bool tightToEdges;
  final List<NativeDockItem> items;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'visible': visible,
      'compact': compact,
      'tightToEdges': tightToEdges,
      'items': items.map((item) => item.toMap()).toList(),
    };
  }
}

class NativeDockItem {
  const NativeDockItem({
    required this.id,
    required this.symbol,
    this.selectedSymbol,
    required this.active,
    required this.primary,
    required this.showBadge,
    required this.onTap,
    this.onHoldComplete,
  });

  final String id;
  final String symbol;
  final String? selectedSymbol;
  final bool active;
  final bool primary;
  final bool showBadge;
  final VoidCallback onTap;
  final VoidCallback? onHoldComplete;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'symbol': symbol,
      'selectedSymbol': selectedSymbol,
      'active': active,
      'primary': primary,
      'showBadge': showBadge,
      'supportsLongPress': onHoldComplete != null,
    };
  }
}
