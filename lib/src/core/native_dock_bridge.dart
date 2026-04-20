import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'native_back_button_bridge.dart';

class NativeDockBridge extends NavigatorObserver with ChangeNotifier {
  NativeDockBridge._();

  static final NativeDockBridge instance = NativeDockBridge._();
  static const MethodChannel _channel = MethodChannel('accord/native_dock');

  bool _initialized = false;
  bool _nativeReady = false;
  bool _systemDockSupported = false;
  bool _supportCheckInFlight = false;
  NativeDockState? _pendingState;
  NativeDockState? _lastSyncedState;
  NativeDockState? _lastVisibleState;
  final Map<String, VoidCallback> _tapHandlers = <String, VoidCallback>{};
  final Map<String, VoidCallback> _holdHandlers = <String, VoidCallback>{};
  final Map<String, VoidCallback> _lastVisibleTapHandlers =
      <String, VoidCallback>{};
  final Map<String, VoidCallback> _lastVisibleHoldHandlers =
      <String, VoidCallback>{};
  final Map<String, NativeDockItem> _itemsById = <String, NativeDockItem>{};
  final Map<String, NativeDockItem> _lastVisibleItemsById =
      <String, NativeDockItem>{};

  static bool get isSupportedPlatform => false;

  bool get isReady => _nativeReady;
  bool get supportsSystemDock => _systemDockSupported;

  Future<void> initialize() async {
    if (_initialized || !isSupportedPlatform) {
      return;
    }
    _initialized = true;
    _channel.setMethodCallHandler(_handleMethodCall);
    _querySupport();
  }

  void register(NativeDockState state) {
    if (!isSupportedPlatform) {
      return;
    }
    if (!_nativeReady && !_supportCheckInFlight) {
      _querySupport();
    }
    if (_pendingState == state && _lastSyncedState == state) {
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
    _itemsById
      ..clear()
      ..addEntries(state.items.map((item) => MapEntry(item.id, item)));
    if (state.visible) {
      _lastVisibleState = state;
      _lastVisibleTapHandlers
        ..clear()
        ..addAll(_tapHandlers);
      _lastVisibleHoldHandlers
        ..clear()
        ..addAll(_holdHandlers);
      _lastVisibleItemsById
        ..clear()
        ..addAll(_itemsById);
    }
    _scheduleSync();
  }

  void clearFromBuild() {
    if (!isSupportedPlatform) {
      return;
    }
    const hiddenState = NativeDockState.hidden();
    if (_pendingState == hiddenState && _lastSyncedState == hiddenState) {
      return;
    }
    _pendingState = hiddenState;
    _tapHandlers.clear();
    _holdHandlers.clear();
    _itemsById.clear();
    _scheduleSync();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (supportsSystemDock) {
      return;
    }
    _restoreLastVisibleDock();
  }

  void _restoreLastVisibleDock() {
    final state = _lastVisibleState;
    if (state == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingState = state;
      _tapHandlers
        ..clear()
        ..addAll(_lastVisibleTapHandlers);
      _holdHandlers
        ..clear()
        ..addAll(_lastVisibleHoldHandlers);
      _itemsById
        ..clear()
        ..addAll(_lastVisibleItemsById);
      unawaited(_sync());
      notifyListeners();
    });
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
    final nextState = _pendingState ?? const NativeDockState.hidden();
    if (_lastSyncedState == nextState) {
      return;
    }
    try {
      await _channel.invokeMethod(
        'setDockState',
        nextState.toMap(),
      );
      _lastSyncedState = nextState;
    } catch (_) {}
  }

  Future<void> _querySupport() async {
    if (!_initialized || _supportCheckInFlight) {
      return;
    }
    _supportCheckInFlight = true;
    try {
      final supported =
          await _channel.invokeMethod<bool>('isSystemDockSupported') ?? false;
      _nativeReady = true;
      _systemDockSupported = supported;
      notifyListeners();
      _scheduleSync();
    } catch (_) {
      // Native dock bridge may not be ready on the very first frame.
    } finally {
      _supportCheckInFlight = false;
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'nativeDockReady':
        _nativeReady = true;
        _systemDockSupported = (call.arguments as bool?) ?? false;
        notifyListeners();
        _scheduleSync();
        return null;
      case 'nativeDockTap':
        final id = call.arguments as String?;
        if (id != null) {
          final item = _itemsById[id] ?? _lastVisibleItemsById[id];
          final navigator =
              NativeBackButtonBridge.instance.navigatorKey.currentState;
          if (item != null &&
              navigator != null &&
              item.routeName != null &&
              !item.active) {
            if (item.replaceStack) {
              navigator.pushNamedAndRemoveUntil(
                item.routeName!,
                (route) => false,
              );
            } else {
              navigator.pushNamed(item.routeName!);
            }
            return null;
          }
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

  @override
  bool operator ==(Object other) {
    return other is NativeDockState &&
        other.visible == visible &&
        other.compact == compact &&
        other.tightToEdges == tightToEdges &&
        listEquals(other.items, items);
  }

  @override
  int get hashCode => Object.hash(
        visible,
        compact,
        tightToEdges,
        Object.hashAll(items),
      );
}

class NativeDockItem {
  const NativeDockItem({
    required this.id,
    required this.label,
    required this.iconCodePoint,
    this.selectedIconCodePoint,
    this.symbol = '',
    this.selectedSymbol,
    required this.active,
    required this.primary,
    required this.showBadge,
    required this.onTap,
    this.onHoldComplete,
    this.routeName,
    this.replaceStack = false,
  });

  final String id;
  final String label;
  final int iconCodePoint;
  final int? selectedIconCodePoint;
  final String symbol;
  final String? selectedSymbol;
  final bool active;
  final bool primary;
  final bool showBadge;
  final VoidCallback onTap;
  final VoidCallback? onHoldComplete;
  final String? routeName;
  final bool replaceStack;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'label': label,
      'iconCodePoint': iconCodePoint,
      'selectedIconCodePoint': selectedIconCodePoint,
      'symbol': symbol,
      'selectedSymbol': selectedSymbol,
      'active': active,
      'primary': primary,
      'showBadge': showBadge,
      'supportsLongPress': onHoldComplete != null,
      'routeName': routeName,
      'replaceStack': replaceStack,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is NativeDockItem &&
        other.id == id &&
        other.label == label &&
        other.iconCodePoint == iconCodePoint &&
        other.selectedIconCodePoint == selectedIconCodePoint &&
        other.symbol == symbol &&
        other.selectedSymbol == selectedSymbol &&
        other.active == active &&
        other.primary == primary &&
        other.showBadge == showBadge &&
        other.routeName == routeName &&
        other.replaceStack == replaceStack &&
        (other.onHoldComplete != null) == (onHoldComplete != null);
  }

  @override
  int get hashCode => Object.hash(
        id,
        label,
        iconCodePoint,
        selectedIconCodePoint,
        symbol,
        selectedSymbol,
        active,
        primary,
        showBadge,
        routeName,
        replaceStack,
        onHoldComplete != null,
      );
}
