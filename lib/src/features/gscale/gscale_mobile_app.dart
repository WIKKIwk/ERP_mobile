import 'dart:async';
import 'dart:convert';

import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/navigation/native_back_button.dart';
import '../../core/widgets/navigation/app_navigation_bar.dart';
import 'network_candidates_stub.dart'
    if (dart.library.io) 'network_candidates_io.dart' as network_candidates;

// Keep in sync with gscale-zebra mobileapi approved ports.
const _defaultApiPort = 39117;
const _discoveryPort = 18081;
const _fastProbeTimeout = Duration(milliseconds: 180);
const _manualProbeTimeout = Duration(seconds: 2);
const _udpDiscoveryTimeout = Duration(milliseconds: 450);
const _fallbackProbeTimeout = Duration(milliseconds: 240);
const _fallbackProbeConcurrency = 24;
const _directProbePorts = <int>[39117, 41257, 43391, 45533, 47681];
const _enableAutomaticSubnetSweep = false;
const _lastServerKey = 'last_server_base_url';
const _cachedServersKey = 'cached_servers_v1';
const _controlDraftKey = 'operator_control_draft_v1';
const _defaultWifiServerAddress = 'http://gscale.local:39117';
const _bonjourDiscoveryTimeout = Duration(milliseconds: 350);
const _bonjourDiscoveryChannel = MethodChannel('gscale/bonjour');
const _minManualPrintKg = 0.100;
const _configuredApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: _defaultWifiServerAddress,
);
const _m3Surface = Color(0xFFF4EEFF);
const _m3Container = Color(0xFFDCD6F7);
const _m3Accent = Color(0xFFA6B1E1);
const _m3Primary = Color(0xFF424874);

bool get previewEnabled {
  if (kReleaseMode) {
    return false;
  }
  if (kIsWeb) {
    return true;
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
      return false;
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.fuchsia:
      return true;
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (previewEnabled) {
    runApp(
      DevicePreview(
        enabled: true,
        isToolbarVisible: true,
        tools: const [...DevicePreview.defaultTools],
        builder: (context) => const GScaleMobileApp(),
      ),
    );
    return;
  }
  runApp(const GScaleMobileApp());
}

class GScaleMobileApp extends StatefulWidget {
  const GScaleMobileApp({
    super.key,
    this.onExitMode = SystemNavigator.pop,
  });

  final Future<void> Function() onExitMode;

  @override
  State<GScaleMobileApp> createState() => _GScaleMobileAppState();
}

class _GScaleMobileAppState extends State<GScaleMobileApp> {
  DiscoveredServer? _selectedServer;

  Future<void> _openServer(DiscoveredServer server) async {
    await saveLastUsedServer(server.endpoint);
    await saveCachedDiscoveredServers([server]);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedServer = server;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'GScale Mobile',
          debugShowCheckedModeBanner: false,
          locale: previewEnabled ? DevicePreview.locale(context) : null,
          builder: previewEnabled ? DevicePreview.appBuilder : null,
          themeMode: ThemeController.instance.themeMode,
          theme: AppTheme.light(ThemeController.instance.variant),
          darkTheme: AppTheme.dark(ThemeController.instance.variant),
          home: _selectedServer == null
              ? ServerPickerPage(
                  onOpenServer: _openServer,
                  onExitMode: widget.onExitMode,
                )
              : OperatorDashboardPage(
                  server: _selectedServer!,
                  onChangeServer: () {
                    setState(() {
                      _selectedServer = null;
                    });
                  },
                ),
        );
      },
    );
  }
}

class ServerPickerPage extends StatefulWidget {
  const ServerPickerPage({
    required this.onOpenServer,
    required this.onExitMode,
    super.key,
  });

  final ValueChanged<DiscoveredServer> onOpenServer;
  final Future<void> Function() onExitMode;

  @override
  State<ServerPickerPage> createState() => _ServerPickerPageState();
}

class _ServerPickerPageState extends State<ServerPickerPage> {
  final http.Client _client = http.Client();

  bool _scanning = false;
  DiscoveryResult? _result;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_scan());
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_scan());
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _client.close();
    super.dispose();
  }

  Future<void> _scan() async {
    if (_scanning) {
      return;
    }

    setState(() {
      _scanning = true;
    });

    try {
      final preferredEndpoint = await loadLastUsedServer();
      final fastResultFuture = discoverServersFast(
        _client,
        preferredEndpoint: preferredEndpoint,
      );
      final fastResult = await fastResultFuture;
      if (!mounted) {
        return;
      }
      setState(() {
        _result = fastResult;
        _scanning = false;
      });
      if (fastResult.servers.isNotEmpty) {
        unawaited(saveCachedDiscoveredServers(fastResult.servers));
      } else {
        unawaited(clearCachedDiscoveredServers());
      }
      unawaited(_finishBackgroundScan(preferredEndpoint));
    } catch (_) {
      if (!mounted) {
        return;
      }
      unawaited(clearCachedDiscoveredServers());
      setState(() {
        _result = const DiscoveryResult(
          servers: <DiscoveredServer>[],
          candidateCount: 0,
        );
        _scanning = false;
      });
    }
  }

  Future<void> _finishBackgroundScan(ServerEndpoint? preferredEndpoint) async {
    try {
      final result = await discoverServers(
        _client,
        preferredEndpoint: preferredEndpoint,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _result = result;
      });
      if (result.servers.isNotEmpty) {
        await saveCachedDiscoveredServers(result.servers);
      } else {
        await clearCachedDiscoveredServers();
      }
    } catch (_) {}
  }

  Future<void> _openManualEntrySheet() async {
    final server = await showModalBottomSheet<DiscoveredServer>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => ManualServerSheet(client: _client),
    );
    if (server == null || !mounted) {
      return;
    }
    widget.onOpenServer(server);
  }

  Future<void> _confirmExitAndClose() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Ilovadan chiqish'),
          content: const Text('Ilovadan rostdan chiqib ketasizmi?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Yo\'q'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Ha'),
            ),
          ],
        );
      },
    );
    if (shouldExit == true && mounted) {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final servers = _result?.servers ?? const <DiscoveredServer>[];

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          unawaited(_confirmExitAndClose());
        }
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: AppTheme.appBarHeight,
          leading: NativeBackButtonSlot(
            onPressed: widget.onExitMode,
          ),
          title: const Text('gscale-zebra'),
          actions: [
            IconButton(
              onPressed: _openManualEntrySheet,
              icon: const Icon(Icons.add_link_rounded),
              tooltip: 'Add',
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _scan,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
            children: [
              if (_scanning && servers.isEmpty) const _ScanningState(),
              if (!_scanning && servers.isEmpty)
                _EmptyServerState(onManualAdd: _openManualEntrySheet),
              if (servers.isNotEmpty)
                _ServerList(
                  servers: servers,
                  onOpenServer: widget.onOpenServer,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class OperatorDashboardPage extends StatefulWidget {
  const OperatorDashboardPage({
    required this.server,
    required this.onChangeServer,
    super.key,
  });

  final DiscoveredServer server;
  final VoidCallback onChangeServer;

  @override
  State<OperatorDashboardPage> createState() => _OperatorDashboardPageState();
}

class _OperatorDashboardPageState extends State<OperatorDashboardPage> {
  final http.Client _client = http.Client();
  final TextEditingController _erpUrlController = TextEditingController();
  final TextEditingController _erpApiKeyController = TextEditingController();
  final TextEditingController _erpApiSecretController = TextEditingController();
  final TextEditingController _defaultWarehouseController =
      TextEditingController();
  final TextEditingController _babinaWeightController = TextEditingController();
  final TextEditingController _manualQtyController = TextEditingController();
  final TextEditingController _warehouseSearchController =
      TextEditingController();
  final FocusNode _warehouseSearchFocusNode = FocusNode();
  StreamSubscription<String>? _streamSubscription;
  int _streamGeneration = 0;
  int _selectedSection = 0;
  Timer? _warehouseSearchDebounce;

  bool _manualLoading = false;
  bool _manualPrintLoading = false;
  bool _requestInFlight = false;
  bool _warehousesLoading = false;
  bool _batchActionLoading = false;
  bool _erpSetupLoading = false;
  bool _warehouseSetupLoading = false;
  bool _archiveLoading = false;
  String _archivePrintLoadingSessionId = '';
  bool _connected = false;
  bool _erpSetupExpanded = false;
  bool _warehouseSetupExpanded = false;
  String _statusText = 'idle';
  String _errorText = '';
  String _warehousesError = '';
  String _erpSetupError = '';
  String _warehouseSetupError = '';
  String _archiveError = '';
  bool _erpWriteConfigured = false;
  bool _erpReadConfigured = false;
  String _erpConfiguredUrl = '';
  String _warehouseMode = 'manual';
  String _defaultWarehouse = '';
  String _batchPrintMode = 'rfid';
  String _batchPrinter = 'zebra';
  String _quantitySource = 'scale';
  bool _babinaEnabled = false;
  MonitorSnapshot _snapshot = MonitorSnapshot.empty();
  List<MobileWarehouse> _warehouses = const [];
  List<MobileArchiveSession> _archiveSessions = const [];
  MobileItem? _selectedItem;
  MobileWarehouse? _selectedWarehouse;
  Timer? _pingTimer;
  Timer? _printerStatusTimer;
  Timer? _controlPrefsDebounce;
  String _printerStatusOverride = '';
  bool _suspendControlPrefsSave = false;

  @override
  void initState() {
    super.initState();
    _warehouseSearchController.addListener(_scheduleWarehouseSearch);
    _manualQtyController.addListener(_scheduleSaveControlPrefs);
    _babinaWeightController.addListener(_scheduleSaveControlPrefs);
    _warehouseSearchFocusNode.addListener(_handleSearchFocusChanged);
    _snapshot = MonitorSnapshot.empty().copyWithLatency(
      widget.server.latencyMs,
    );
    _loadControlDraftPreferences();
    _startLiveStream();
    _startPingLoop();
    unawaited(_refreshSetupStatus());
  }

  @override
  void dispose() {
    _warehouseSearchDebounce?.cancel();
    _pingTimer?.cancel();
    _printerStatusTimer?.cancel();
    _controlPrefsDebounce?.cancel();
    _erpUrlController.dispose();
    _erpApiKeyController.dispose();
    _erpApiSecretController.dispose();
    _defaultWarehouseController.dispose();
    _babinaWeightController.dispose();
    _manualQtyController.dispose();
    _warehouseSearchController.dispose();
    _warehouseSearchFocusNode.dispose();
    _stopLiveStream();
    _client.close();
    super.dispose();
  }

  void _handleSearchFocusChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _startLiveStream() {
    _streamGeneration++;
    final generation = _streamGeneration;
    unawaited(_runLiveStream(generation));
  }

  void _startPingLoop() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_refreshLatency());
    });
    unawaited(_refreshLatency());
  }

  void _stopLiveStream() {
    _streamGeneration++;
    unawaited(_streamSubscription?.cancel());
    _streamSubscription = null;
  }

  void _runWithoutSavingControlPrefs(void Function() action) {
    _suspendControlPrefsSave = true;
    try {
      action();
    } finally {
      _suspendControlPrefsSave = false;
    }
  }

  void _scheduleSaveControlPrefs() {
    if (_suspendControlPrefsSave) {
      return;
    }
    _controlPrefsDebounce?.cancel();
    _controlPrefsDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted || _suspendControlPrefsSave) {
        return;
      }
      unawaited(_saveControlDraftPreferences());
    });
  }

  Future<void> _loadControlDraftPreferences() async {
    final draft = await loadOperatorControlDraft();
    if (!mounted || _snapshot.batchActive) {
      return;
    }

    _runWithoutSavingControlPrefs(() {
      setState(() {
        if (draft.itemCode.trim().isNotEmpty) {
          _selectedItem = MobileItem(
            itemCode: draft.itemCode,
            itemName:
                draft.itemName.isNotEmpty ? draft.itemName : draft.itemCode,
          );
        }
        if (_selectedItem != null && draft.warehouse.trim().isNotEmpty) {
          _selectedWarehouse = MobileWarehouse(warehouse: draft.warehouse);
        }
        _batchPrintMode =
            draft.printMode.isNotEmpty ? draft.printMode : _batchPrintMode;
        _batchPrinter =
            draft.printer.isNotEmpty ? draft.printer : _batchPrinter;
        if (_batchPrinter == 'godex') {
          _batchPrintMode = 'label';
        }
        _quantitySource = draft.quantitySource.isNotEmpty
            ? draft.quantitySource
            : _quantitySource;
        _babinaEnabled = draft.babinaEnabled;
        _manualQtyController.text = draft.manualQtyText;
        _babinaWeightController.text = draft.babinaText;
      });
    });

    if (_selectedItem != null) {
      unawaited(_loadWarehouses(itemCode: _selectedItem!.itemCode));
    }
  }

  Future<void> _saveControlDraftPreferences() async {
    final draft = OperatorControlDraft(
      itemCode: _selectedItem?.itemCode ?? '',
      itemName: _selectedItem?.itemName ?? '',
      warehouse: _selectedWarehouse?.warehouse ?? '',
      printMode: _batchPrinter == 'godex'
          ? 'label'
          : (_batchPrintMode == 'label' ? 'label' : 'rfid'),
      printer: normalizePrinterChoice(_batchPrinter),
      quantitySource: normalizeQuantitySource(_quantitySource),
      manualQtyText: _manualQtyController.text.trim(),
      babinaEnabled: _babinaEnabled,
      babinaText: _babinaWeightController.text.trim(),
    );
    await saveOperatorControlDraft(draft);
  }

  Future<void> _refreshLatency() async {
    if (!mounted) {
      return;
    }

    final server = widget.server;
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _client
          .get(Uri.parse('${server.endpoint.baseUrl}/healthz'))
          .timeout(const Duration(seconds: 2));
      if (response.statusCode < 200 || response.statusCode > 299) {
        return;
      }
      stopwatch.stop();
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = _snapshot.copyWithLatency(stopwatch.elapsedMilliseconds);
        _connected = true;
      });
    } catch (_) {
      return;
    }
  }

  Future<void> _runLiveStream(int generation) async {
    while (mounted && generation == _streamGeneration) {
      try {
        if (mounted) {
          setState(() {
            _statusText = _connected ? 'reconnecting' : 'connecting';
          });
        }
        await _connectLiveStreamOnce(generation);
      } catch (error) {
        if (!mounted || generation != _streamGeneration) {
          return;
        }
        setState(() {
          _connected = false;
          _statusText = 'offline';
          _errorText = error.toString();
        });
      }

      if (!mounted || generation != _streamGeneration) {
        return;
      }
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  Future<void> _connectLiveStreamOnce(int generation) async {
    final request = http.Request(
      'GET',
      Uri.parse('${widget.server.endpoint.baseUrl}/v1/mobile/monitor/stream'),
    );
    request.headers['Accept'] = 'text/event-stream';

    final response =
        await _client.send(request).timeout(const Duration(seconds: 4));
    if (response.statusCode < 200 || response.statusCode > 299) {
      throw Exception('stream ${response.statusCode}');
    }

    final completer = Completer<void>();
    final dataLines = <String>[];

    await _streamSubscription?.cancel();
    _streamSubscription = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (line) {
        if (!mounted || generation != _streamGeneration) {
          return;
        }
        if (line.isEmpty) {
          if (dataLines.isEmpty) {
            return;
          }
          final payloadText = dataLines.join('\n');
          dataLines.clear();
          final payload = jsonDecode(payloadText) as Map<String, dynamic>;
          if (payload.containsKey('error') && payload['ok'] != true) {
            setState(() {
              _connected = false;
              _statusText = 'offline';
              _errorText = payload['error'].toString();
            });
            return;
          }
          setState(() {
            _applySnapshot(MonitorSnapshot.fromJson(payload));
            _connected = true;
            _statusText = 'live';
            _errorText = '';
          });
          unawaited(_refreshSetupStatus());
          return;
        }
        if (line.startsWith(':')) {
          return;
        }
        if (line.startsWith('data:')) {
          dataLines.add(line.substring(5).trimLeft());
        }
      },
      onError: (error, _) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      cancelOnError: true,
    );

    await completer.future;
  }

  Future<void> _refresh({bool manual = false}) async {
    if (_requestInFlight) {
      return;
    }

    _requestInFlight = true;
    if (manual && mounted) {
      setState(() {
        _manualLoading = true;
        _errorText = '';
        _statusText = 'refreshing';
      });
    }

    try {
      final health = await _client
          .get(Uri.parse('${widget.server.endpoint.baseUrl}/healthz'))
          .timeout(const Duration(seconds: 4));
      if (health.statusCode < 200 || health.statusCode > 299) {
        throw Exception('healthz ${health.statusCode}');
      }

      final monitor = await _client
          .get(
            Uri.parse(
              '${widget.server.endpoint.baseUrl}/v1/mobile/monitor/state',
            ),
          )
          .timeout(const Duration(seconds: 4));
      if (monitor.statusCode < 200 || monitor.statusCode > 299) {
        throw Exception('monitor ${monitor.statusCode}');
      }

      final payload = jsonDecode(monitor.body) as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _applySnapshot(MonitorSnapshot.fromJson(payload));
          _connected = true;
          _statusText = 'connected';
          _errorText = '';
        });
      }
      await _refreshSetupStatus();
    } catch (error) {
      if (mounted) {
        setState(() {
          _connected = false;
          _statusText = 'offline';
          _errorText = error.toString();
        });
      }
    } finally {
      _requestInFlight = false;
      if (manual && mounted) {
        setState(() {
          _manualLoading = false;
        });
      }
    }
  }

  Future<void> _refreshSetupStatus() async {
    try {
      final response = await _client
          .get(
            Uri.parse(
              '${widget.server.endpoint.baseUrl}/v1/mobile/setup/status',
            ),
          )
          .timeout(const Duration(seconds: 4));
      if (response.statusCode < 200 || response.statusCode > 299) {
        return;
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) {
        return;
      }
      final previousDefaultWarehouse = _defaultWarehouse;
      setState(() {
        final writeConfigured = payload['erp_write_configured'] == true;
        final readConfigured = payload['erp_read_configured'] == true;
        _erpWriteConfigured = writeConfigured;
        _erpReadConfigured = readConfigured;
        _erpConfiguredUrl = _text(payload['erp_url']);
        if (!writeConfigured && !readConfigured) {
          _erpSetupExpanded = true;
        }
        final nextWarehouseMode = _text(
          payload['warehouse_mode'],
          fallback: 'manual',
        );
        _warehouseMode = nextWarehouseMode == 'default' ? 'default' : 'manual';
        _defaultWarehouse = _text(payload['default_warehouse']);
        if (_defaultWarehouseController.text.trim().isEmpty ||
            _defaultWarehouseController.text.trim() ==
                previousDefaultWarehouse) {
          _defaultWarehouseController.text = _defaultWarehouse;
        }
        if (_warehouseMode == 'default' && _defaultWarehouse.trim().isEmpty) {
          _warehouseSetupExpanded = true;
        }
      });
    } catch (_) {
      return;
    }
  }

  void _resetERPSetupEditors() {
    _erpUrlController.text = _erpConfiguredUrl;
    _erpApiKeyController.clear();
    _erpApiSecretController.clear();
  }

  String get _currentDefaultWarehouse {
    final controllerValue = _defaultWarehouseController.text.trim();
    if (controllerValue.isNotEmpty) {
      return controllerValue;
    }
    return _defaultWarehouse.trim();
  }

  void _applySnapshot(MonitorSnapshot snapshot) {
    final previous = _snapshot;
    _snapshot = snapshot.copyWithLatency(_snapshot.latencyMs);
    if (snapshot.batchActive) {
      if (snapshot.batchItemCode.isNotEmpty) {
        _selectedItem = MobileItem(
          itemCode: snapshot.batchItemCode,
          itemName: snapshot.batchItemName.isEmpty
              ? snapshot.batchItemCode
              : snapshot.batchItemName,
        );
      }
      if (snapshot.batchWarehouse.isNotEmpty) {
        _selectedWarehouse = MobileWarehouse(
          warehouse: snapshot.batchWarehouse,
        );
      }
      if (snapshot.batchPrintMode.isNotEmpty) {
        _batchPrintMode = snapshot.batchPrintMode;
      }
      if (snapshot.batchPrinter.isNotEmpty) {
        _batchPrinter = snapshot.batchPrinter;
      }
      if (snapshot.batchActive) {
        _quantitySource = snapshot.batchQuantitySource;
        _babinaEnabled = snapshot.batchTareEnabled;
        if (snapshot.batchTareKg > 0) {
          _babinaWeightController.text = formatCompactKg(snapshot.batchTareKg);
        }
      }
    } else {
      final livePrinter = snapshot.livePrinterChoice;
      if (livePrinter.isNotEmpty && livePrinter != _batchPrinter) {
        _batchPrinter = livePrinter;
        if (livePrinter == 'godex') {
          _batchPrintMode = 'label';
        }
        _scheduleSaveControlPrefs();
      }
    }
    if (!mounted) {
      return;
    }
    if (snapshot.printerEventKey.isNotEmpty &&
        snapshot.printerEventKey != previous.printerEventKey) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      _printerStatusTimer?.cancel();
      _printerStatusOverride = snapshot.printerEventMessage;
      _printerStatusTimer = Timer(const Duration(seconds: 4), () {
        if (!mounted) {
          return;
        }
        setState(() {
          _printerStatusOverride = '';
        });
      });
      if (messenger != null) {
        if (snapshot.printerState == 'done') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text(snapshot.printerEventMessage)),
              );
          });
        } else if (snapshot.printerState == 'error') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text(snapshot.printerEventMessage)),
              );
          });
        }
      }
    }
  }

  Uri _apiUri(String path, [Map<String, String?> query = const {}]) {
    final filtered = <String, String>{};
    for (final entry in query.entries) {
      final value = entry.value?.trim() ?? '';
      if (value.isNotEmpty) {
        filtered[entry.key] = value;
      }
    }
    return Uri.parse(
      '${widget.server.endpoint.baseUrl}$path',
    ).replace(queryParameters: filtered.isEmpty ? null : filtered);
  }

  void _scheduleWarehouseSearch() {
    if (_selectedItem == null) {
      return;
    }
    _warehouseSearchDebounce?.cancel();
    final query = _warehouseSearchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _warehouses = const [];
        _warehousesLoading = false;
        _warehousesError = '';
      });
      return;
    }
    _warehouseSearchDebounce = Timer(const Duration(milliseconds: 220), () {
      unawaited(
        _loadWarehouses(itemCode: _selectedItem!.itemCode, query: query),
      );
    });
  }

  Future<List<MobileItem>> _fetchItems({String query = ''}) async {
    final response = await _client
        .get(_apiUri('/v1/mobile/items', {'query': query, 'limit': '12'}))
        .timeout(const Duration(seconds: 3));
    if (response.statusCode < 200 || response.statusCode > 299) {
      throw Exception('items ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final rawItems =
        (payload['items'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    return rawItems.map(MobileItem.fromJson).toList(growable: false);
  }

  Future<List<MobileWarehouse>> _fetchWarehouses({
    required String itemCode,
    String query = '',
  }) async {
    final response = await _client
        .get(
          _apiUri(
            '/v1/mobile/items/${Uri.encodeComponent(itemCode)}/warehouses',
            {'query': query, 'limit': '12'},
          ),
        )
        .timeout(const Duration(seconds: 3));
    if (response.statusCode < 200 || response.statusCode > 299) {
      throw Exception('warehouses ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final rawWarehouses =
        (payload['warehouses'] as List?)?.cast<Map<String, dynamic>>() ??
            const [];
    return rawWarehouses.map(MobileWarehouse.fromJson).toList(growable: false);
  }

  Future<List<MobileWarehouse>> _fetchAllWarehouses({String query = ''}) async {
    final response = await _client
        .get(_apiUri('/v1/mobile/warehouses', {'query': query, 'limit': '30'}))
        .timeout(const Duration(seconds: 3));
    if (response.statusCode < 200 || response.statusCode > 299) {
      throw Exception('warehouses ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final rawWarehouses =
        (payload['warehouses'] as List?)?.cast<Map<String, dynamic>>() ??
            const [];
    return rawWarehouses.map(MobileWarehouse.fromJson).toList(growable: false);
  }

  Future<void> _loadWarehouses({
    required String itemCode,
    String query = '',
  }) async {
    if (!mounted) {
      return;
    }
    setState(() {
      _warehousesLoading = true;
      _warehousesError = '';
    });
    try {
      final response = await _client
          .get(
            _apiUri(
              '/v1/mobile/items/${Uri.encodeComponent(itemCode)}/warehouses',
              {'query': query, 'limit': '12'},
            ),
          )
          .timeout(const Duration(seconds: 3));
      if (response.statusCode < 200 || response.statusCode > 299) {
        throw Exception('warehouses ${response.statusCode}');
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final rawWarehouses =
          (payload['warehouses'] as List?)?.cast<Map<String, dynamic>>() ??
              const [];
      final warehouses =
          rawWarehouses.map(MobileWarehouse.fromJson).toList(growable: false);
      if (!mounted) {
        return;
      }
      setState(() {
        _warehouses = warehouses;
        _warehousesLoading = false;
        if (_selectedWarehouse != null &&
            warehouses.every(
              (warehouse) =>
                  warehouse.warehouse != _selectedWarehouse!.warehouse,
            ) &&
            !_snapshot.batchActive) {
          _selectedWarehouse = null;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _warehousesLoading = false;
        _warehousesError = error.toString();
      });
    }
  }

  Future<void> _openDefaultWarehousePicker() async {
    final warehouse = await showModalBottomSheet<MobileWarehouse>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => _WarehousePickerSheet(
        title: 'Default ombor tanlang',
        queryHint: 'Ombor qidiring',
        emptyText: 'Ombor topilmadi.',
        initialWarehouse: MobileWarehouse(warehouse: _currentDefaultWarehouse),
        fetchWarehouses: ({required String query}) =>
            _fetchAllWarehouses(query: query),
      ),
    );
    if (warehouse == null || !mounted) {
      return;
    }
    await _persistWarehouseSetup(
      mode: 'default',
      defaultWarehouse: warehouse.warehouse,
    );
  }

  Future<void> _persistWarehouseSetup({
    required String mode,
    required String defaultWarehouse,
  }) async {
    if (_warehouseSetupLoading) {
      return;
    }
    if (mode == 'default' && defaultWarehouse.trim().isEmpty) {
      setState(() {
        _warehouseSetupError = 'Default ombor tanlang';
        _warehouseSetupExpanded = true;
      });
      return;
    }

    setState(() {
      _warehouseSetupLoading = true;
      _warehouseSetupError = '';
    });

    try {
      final response = await _client
          .post(
            _apiUri('/v1/mobile/setup/warehouse'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'warehouse_mode': mode,
              'default_warehouse': defaultWarehouse.trim(),
            }),
          )
          .timeout(const Duration(seconds: 6));
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode > 299) {
        throw Exception(
          _text(
            payload['message'],
            fallback: _text(
              payload['error'],
              fallback: 'Warehouse setup failed',
            ),
          ),
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _warehouseMode =
            _text(payload['warehouse_mode'], fallback: 'manual') == 'default'
                ? 'default'
                : 'manual';
        _defaultWarehouse = _text(payload['default_warehouse']);
        _defaultWarehouseController.text = _defaultWarehouse;
        _warehouseSetupExpanded = false;
        _selectedWarehouse = null;
        _warehouseSetupLoading = false;
      });
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Warehouse setup saqlandi')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _warehouseSetupLoading = false;
        _warehouseSetupError = error.toString();
      });
    }
  }

  Future<void> _selectItem(MobileItem item) async {
    setState(() {
      _selectedItem = item;
      _selectedWarehouse = null;
      _warehouses = const [];
      _warehouseSearchController.clear();
    });
    _scheduleSaveControlPrefs();
    await _loadWarehouses(itemCode: item.itemCode);
  }

  Future<void> _openItemPicker() async {
    final item = await showModalBottomSheet<MobileItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => _ItemPickerSheet(
        initialItem: _selectedItem,
        fetchItems: ({required String query}) => _fetchItems(query: query),
      ),
    );
    if (item == null) {
      return;
    }
    await _selectItem(item);
  }

  Future<void> _openWarehousePicker() async {
    final selectedItem = _selectedItem;
    if (selectedItem == null) {
      return;
    }
    final warehouse = await showModalBottomSheet<MobileWarehouse>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => _WarehousePickerSheet(
        title: 'Warehouse tanlang',
        queryHint: 'Warehouse qidiring',
        emptyText: 'Warehouse topilmadi.',
        initialWarehouse: _selectedWarehouse,
        fetchWarehouses: ({required String query}) =>
            _fetchWarehouses(itemCode: selectedItem.itemCode, query: query),
      ),
    );
    if (warehouse == null || !mounted) {
      return;
    }
    setState(() {
      _selectedWarehouse = warehouse;
    });
    _scheduleSaveControlPrefs();
  }

  Future<void> _startBatch() async {
    final item = _selectedItem;
    final warehouse = _warehouseMode == 'default'
        ? _currentDefaultWarehouse
        : _selectedWarehouse?.warehouse;
    if (item == null || warehouse == null || _batchActionLoading) {
      return;
    }
    setState(() {
      _batchActionLoading = true;
      _warehousesError = '';
    });
    try {
      final printer = normalizePrinterChoice(_batchPrinter);
      final printMode = printer == 'godex' ? 'label' : _batchPrintMode;
      final quantitySource = normalizeQuantitySource(_quantitySource);
      final manualQtyKg = quantitySource == 'manual'
          ? parsePositiveKg(_manualQtyController.text)
          : null;
      final tareKg =
          _babinaEnabled ? parsePositiveKg(_babinaWeightController.text) : null;
      if (_babinaEnabled && tareKg == null) {
        throw Exception("Babina og'irligini kg da to'g'ri kiriting");
      }
      final response = await _client
          .post(
            _apiUri('/v1/mobile/batch/start'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'item_code': item.itemCode,
              'item_name': item.itemName,
              'warehouse': warehouse,
              'print_mode': printMode,
              'printer': printer,
              'quantity_source': quantitySource,
              'manual_qty_kg': manualQtyKg ?? 0,
              'tare_enabled': _babinaEnabled,
              'tare_kg': tareKg ?? 0,
            }),
          )
          .timeout(const Duration(seconds: 4));
      if (response.statusCode < 200 || response.statusCode > 299) {
        throw Exception('batch start ${response.statusCode}');
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final batch =
          (payload['batch'] as Map?)?.cast<String, dynamic>() ?? const {};
      if (!mounted) {
        return;
      }
      setState(() {
        final startedBatch = MobileBatchState.fromJson(batch);
        _snapshot = _snapshot.copyWithBatch(startedBatch);
        if (startedBatch.printMode.isNotEmpty) {
          _batchPrintMode = startedBatch.printMode;
        }
        if (startedBatch.printer.isNotEmpty) {
          _batchPrinter = startedBatch.printer;
        }
        _quantitySource = startedBatch.quantitySource;
        _babinaEnabled = startedBatch.tareEnabled;
        if (startedBatch.tareKg > 0) {
          _babinaWeightController.text = formatCompactKg(startedBatch.tareKg);
        }
        _batchActionLoading = false;
      });
      _scheduleSaveControlPrefs();
      unawaited(_refreshArchive());
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _batchActionLoading = false;
        _warehousesError = error.toString();
      });
    }
  }

  Future<void> _printManualBatch() async {
    if (_manualPrintLoading || _batchActionLoading || _requestInFlight) {
      return;
    }
    final manualQtyKg = parsePositiveKg(_manualQtyController.text);
    if (!canTriggerManualPrint(
      qtyText: _manualQtyController.text,
      babinaEnabled: _babinaEnabled,
      babinaText: _babinaWeightController.text,
    )) {
      setState(() {
        _errorText = "Manual kg ni to'g'ri kiriting";
      });
      return;
    }
    if (!_snapshot.batchActive || _snapshot.batchQuantitySource != 'manual') {
      setState(() {
        _errorText = 'Avval manual batch start qiling';
      });
      return;
    }

    setState(() {
      _manualPrintLoading = true;
      _errorText = '';
    });
    try {
      final response = await _client
          .post(
            _apiUri('/v1/mobile/batch/manual-print'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'manual_qty_kg': manualQtyKg}),
          )
          .timeout(const Duration(seconds: 4));
      if (response.statusCode < 200 || response.statusCode > 299) {
        throw Exception('manual print ${response.statusCode}');
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final batch =
          (payload['batch'] as Map?)?.cast<String, dynamic>() ?? const {};
      if (!mounted) {
        return;
      }
      setState(() {
        final updatedBatch = MobileBatchState.fromJson(batch);
        _snapshot = _snapshot.copyWithBatch(updatedBatch);
        _quantitySource = updatedBatch.quantitySource;
        _manualPrintLoading = false;
      });
      _scheduleSaveControlPrefs();
      unawaited(_refreshArchive());
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _manualPrintLoading = false;
        _errorText = error.toString();
      });
    }
  }

  Future<void> _stopBatch() async {
    if (_batchActionLoading) {
      return;
    }
    setState(() {
      _batchActionLoading = true;
      _warehousesError = '';
    });
    try {
      final response = await _client
          .post(_apiUri('/v1/mobile/batch/stop'))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode < 200 || response.statusCode > 299) {
        throw Exception('batch stop ${response.statusCode}');
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final batch =
          (payload['batch'] as Map?)?.cast<String, dynamic>() ?? const {};
      final message = _text(payload['message'], fallback: 'Batch to\'xtadi');
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = _snapshot.copyWithBatch(MobileBatchState.fromJson(batch));
        _batchActionLoading = false;
      });
      unawaited(_refreshArchive());
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _batchActionLoading = false;
        _warehousesError = error.toString();
      });
    }
  }

  Future<void> _refreshArchive() async {
    if (_archiveLoading || !mounted) {
      return;
    }

    setState(() {
      _archiveLoading = true;
      _archiveError = '';
    });

    try {
      final response = await _client
          .get(_apiUri('/v1/mobile/archive', {'limit': '50'}))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode < 200 || response.statusCode > 299) {
        throw Exception('archive ${response.statusCode}');
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final rawSessions =
          (payload['archive'] as List?)?.cast<Map<String, dynamic>>() ??
              const [];
      final sessions = rawSessions
          .map(MobileArchiveSession.fromJson)
          .toList(growable: false);
      if (!mounted) {
        return;
      }
      setState(() {
        _archiveSessions = sessions;
        _archiveLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _archiveLoading = false;
        _archiveError = error.toString();
      });
    }
  }

  String _currentArchivePrinterChoice() {
    final livePrinter = _snapshot.livePrinterChoice;
    if (livePrinter.isNotEmpty) {
      return livePrinter;
    }
    if (_snapshot.printerLabel.trim().toLowerCase() == 'ulanmagan') {
      return '';
    }
    final batchPrinter = normalizePrinterChoice(_batchPrinter);
    if (batchPrinter.isNotEmpty) {
      return batchPrinter;
    }
    return '';
  }

  Future<void> _confirmArchivePrint(MobileArchiveSession session) async {
    if (_archivePrintLoadingSessionId.isNotEmpty || !mounted) {
      return;
    }
    final itemName = session.displayItemName;
    final qtyText =
        '${formatCompactKg(session.totalQty)} ${session.displayUnit}';
    final batchTime = session.endedAt.isNotEmpty
        ? formatArchiveTimestamp(session.endedAt)
        : formatArchiveTimestamp(session.startedAt);
    final shouldPrint = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Batch QR print'),
          content: Text(
            [
              'Shu batch uchun QR print qilamizmi?',
              '',
              'Mahsulot: ${itemName.isEmpty ? '-' : itemName}',
              'Jami: $qtyText',
              'Sana: $batchTime',
            ].join('\n'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Yo\'q'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Ha'),
            ),
          ],
        );
      },
    );
    if (shouldPrint == true) {
      await _printArchiveSession(session);
    }
  }

  Future<void> _printArchiveSession(MobileArchiveSession session) async {
    if (_archivePrintLoadingSessionId.isNotEmpty || !mounted) {
      return;
    }
    final printer = _currentArchivePrinterChoice();
    if (printer.isEmpty) {
      setState(() {
        _archiveError = 'Printer ulanmagan';
      });
      return;
    }

    final requestBody = {'session_id': session.sessionId, 'printer': printer};

    setState(() {
      _archivePrintLoadingSessionId = session.sessionId;
      _archiveError = '';
    });
    try {
      final response = await _client
          .post(
            _apiUri('/v1/mobile/archive/print'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode < 200 || response.statusCode > 299) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(
          _text(payload['error'], fallback: 'Archive print failed'),
        );
      }
      if (!mounted) {
        return;
      }
      final displayName =
          session.displayItemName.isEmpty ? 'Batch' : session.displayItemName;
      setState(() {
        _archivePrintLoadingSessionId = '';
      });
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('$displayName uchun QR print yuborildi')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _archivePrintLoadingSessionId = '';
        _archiveError = error.toString();
      });
    }
  }

  Future<void> _submitERPSetup() async {
    if (_erpSetupLoading) {
      return;
    }
    setState(() {
      _erpSetupLoading = true;
      _erpSetupError = '';
    });
    try {
      final response = await _client
          .post(
            _apiUri('/v1/mobile/setup/erp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'erp_url': _erpUrlController.text.trim(),
              'erp_api_key': _erpApiKeyController.text.trim(),
              'erp_api_secret': _erpApiSecretController.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 6));
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode > 299) {
        throw Exception(
          _text(
            payload['message'],
            fallback: _text(payload['error'], fallback: 'ERP setup failed'),
          ),
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _erpWriteConfigured = payload['erp_write_configured'] == true;
        _erpReadConfigured = payload['erp_read_configured'] == true;
        _erpConfiguredUrl = _text(payload['erp_url']);
        _erpSetupExpanded = false;
        _erpUrlController.clear();
        _erpApiKeyController.clear();
        _erpApiSecretController.clear();
        _erpSetupLoading = false;
      });
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text('ERP setup saqlandi')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _erpSetupLoading = false;
        _erpSetupError = error.toString();
      });
    }
  }

  Future<void> _clearERPSetup() async {
    if (_erpSetupLoading) {
      return;
    }
    setState(() {
      _erpSetupLoading = true;
      _erpSetupError = '';
    });
    try {
      final response = await _client
          .delete(_apiUri('/v1/mobile/setup/erp'))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode < 200 || response.statusCode > 299) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(_text(payload['error'], fallback: 'ERP clear failed'));
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _erpWriteConfigured = false;
        _erpReadConfigured = false;
        _erpConfiguredUrl = '';
        _erpSetupExpanded = true;
        _erpUrlController.clear();
        _erpApiKeyController.clear();
        _erpApiSecretController.clear();
        _erpSetupLoading = false;
      });
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text('ERP setup tozalandi')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _erpSetupLoading = false;
        _erpSetupError = error.toString();
      });
    }
  }

  Future<void> _submitWarehouseSetup() async {
    await _persistWarehouseSetup(
      mode: _warehouseMode == 'default' ? 'default' : 'manual',
      defaultWarehouse: _defaultWarehouseController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final server = widget.server;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          widget.onChangeServer();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: AppTheme.appBarHeight,
          leading: IconButton(
            onPressed: widget.onChangeServer,
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Change server',
          ),
          title: Text(server.handshake.serverName),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 18),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.speed_outlined, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    _snapshot.latencyMs > 0 ? '${_snapshot.latencyMs} ms' : '—',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: switch (_selectedSection) {
            0 => _DashboardScrollView(
                key: const ValueKey('control-section'),
                child: _buildControlSection(context, theme, scheme, server),
              ),
            1 => _DashboardScrollView(
                key: const ValueKey('archive-section'),
                child: _buildArchiveSection(context, theme, scheme, server),
              ),
            _ => _DashboardScrollView(
                key: const ValueKey('server-section'),
                child: _buildServerSection(context, theme, scheme, server),
              ),
          },
        ),
        bottomNavigationBar: AppNavigationBar(
          height: 64,
          selectedIndex: _selectedSection,
          onDestinationSelected: (index) {
            setState(() {
              _selectedSection = index;
            });
            if (index == 1) {
              unawaited(_refreshArchive());
            }
          },
          destinations: const [
            AppNavigationDestination(
              label: 'Control',
              icon: Icon(Icons.tune_outlined),
              selectedIcon: Icon(Icons.tune),
            ),
            AppNavigationDestination(
              label: 'Archive',
              icon: Icon(Icons.archive_outlined),
              selectedIcon: Icon(Icons.archive),
            ),
            AppNavigationDestination(
              label: 'Server',
              icon: Icon(Icons.health_and_safety_outlined),
              selectedIcon: Icon(Icons.health_and_safety),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerSection(
    BuildContext context,
    ThemeData theme,
    ColorScheme scheme,
    DiscoveredServer server,
  ) {
    final hasConfiguredERP = _erpWriteConfigured ||
        _erpReadConfigured ||
        _erpConfiguredUrl.isNotEmpty;
    final defaultWarehouse = _currentDefaultWarehouse;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text(server.handshake.role.toUpperCase())),
            Chip(label: Text(server.handshake.serverRef)),
          ],
        ),
        if (_errorText.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            _errorText,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
        ],
        const SizedBox(height: 22),
        _SectionLabel(title: 'ERP setup', subtitle: ''),
        const SizedBox(height: 12),
        _MiniIconRow(
          icon: Icons.key_outlined,
          text: _erpWriteConfigured
              ? 'ERP write configured'
              : 'ERP write not configured',
        ),
        const SizedBox(height: 12),
        _MiniIconRow(
          icon: Icons.storage_outlined,
          text: _erpReadConfigured
              ? 'Catalog service linked'
              : 'Catalog service topilmadi',
        ),
        if (_erpConfiguredUrl.isNotEmpty) ...[
          const SizedBox(height: 12),
          _MiniIconRow(icon: Icons.link_rounded, text: _erpConfiguredUrl),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _erpSetupLoading
                    ? null
                    : () {
                        setState(() {
                          if (!_erpSetupExpanded) {
                            _resetERPSetupEditors();
                          }
                          _erpSetupExpanded = !_erpSetupExpanded;
                        });
                      },
                icon: Icon(
                  _erpSetupExpanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                ),
                label: Text(
                  hasConfiguredERP
                      ? (_erpSetupExpanded ? 'Hide setup' : 'Show setup')
                      : 'ERP setup',
                ),
              ),
            ),
            if (hasConfiguredERP) ...[
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _erpSetupLoading ? null : _clearERPSetup,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Clear ERP'),
                ),
              ),
            ],
          ],
        ),
        if (_erpSetupExpanded || !hasConfiguredERP) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _erpUrlController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'ERP URL',
              hintText: 'http://localhost:8000',
              prefixIcon: Icon(Icons.link_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _erpApiKeyController,
            decoration: const InputDecoration(
              labelText: 'ERP API key',
              hintText: 'API key',
              prefixIcon: Icon(Icons.vpn_key_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _erpApiSecretController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'ERP API secret',
              hintText: 'API secret',
              prefixIcon: Icon(Icons.password_rounded),
            ),
          ),
        ],
        if (_erpSetupError.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            _erpSetupError,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
        ],
        const SizedBox(height: 28),
        _SectionLabel(title: 'Warehouse setup', subtitle: ''),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              selected: _warehouseMode == 'manual',
              onSelected: _warehouseSetupLoading
                  ? null
                  : (_) {
                      unawaited(
                        _persistWarehouseSetup(
                          mode: 'manual',
                          defaultWarehouse: _defaultWarehouse,
                        ),
                      );
                    },
              label: const Text('Manual'),
            ),
            FilterChip(
              selected: _warehouseMode == 'default',
              onSelected: _warehouseSetupLoading
                  ? null
                  : (_) {
                      unawaited(_openDefaultWarehousePicker());
                    },
              label: const Text('Default'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_warehouseMode == 'default') ...[
          if (defaultWarehouse.isEmpty)
            Text(
              'Default ombor tanlanmagan.',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
            )
          else
            Row(
              children: [
                const Icon(Icons.flag_rounded, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Default warehouse: $defaultWarehouse',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                TextButton(
                  onPressed: _warehouseSetupLoading
                      ? null
                      : () {
                          unawaited(_openDefaultWarehousePicker());
                        },
                  child: const Text('Change'),
                ),
              ],
            ),
        ] else if (defaultWarehouse.isNotEmpty) ...[
          _MiniIconRow(
            icon: Icons.bookmark_outline,
            text: 'Stored default: $defaultWarehouse',
          ),
        ],
        if (_warehouseSetupError.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            _warehouseSetupError,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _manualLoading ? null : () => _refresh(manual: true),
                child: const Icon(Icons.refresh_rounded),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: (_erpSetupLoading ||
                        (!_erpSetupExpanded && hasConfiguredERP))
                    ? null
                    : _submitERPSetup,
                icon: const Icon(Icons.save_outlined),
                label: Text(_erpSetupLoading ? 'Saving...' : 'Save ERP'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: widget.onChangeServer,
                child: const Icon(Icons.dns_rounded),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildArchiveSection(
    BuildContext context,
    ThemeData theme,
    ColorScheme scheme,
    DiscoveredServer server,
  ) {
    final sessions = _archiveSessions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Archive',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${sessions.length} ta batch • ${server.handshake.serverName}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed:
                  _archiveLoading ? null : () => unawaited(_refreshArchive()),
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh archive',
            ),
          ],
        ),
        if (_archiveError.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            _archiveError,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
        ],
        if (_archiveLoading) ...[
          const SizedBox(height: 14),
          const LinearProgressIndicator(minHeight: 2),
        ],
        const SizedBox(height: 18),
        if (sessions.isEmpty && !_archiveLoading) ...[
          Text(
            "Archive hali bo'sh.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ] else ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sessions.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.6),
            ),
            itemBuilder: (context, index) {
              final session = sessions[index];
              return _buildArchiveSessionTile(session, theme, scheme);
            },
          ),
        ],
      ],
    );
  }

  String _formatArchiveSessionSubtitle(MobileArchiveSession session) {
    final parts = <String>[];
    parts.add(session.active ? 'ACTIVE' : 'CLOSED');
    if (session.startedAt.isNotEmpty) {
      parts.add('Started ${formatArchiveTimestamp(session.startedAt)}');
    }
    if (session.endedAt.isNotEmpty) {
      parts.add('Ended ${formatArchiveTimestamp(session.endedAt)}');
    }
    if (session.warehouse.isNotEmpty) {
      parts.add(session.warehouse);
    }
    return parts.join(' • ');
  }

  String formatArchiveTimestamp(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw;
    }
    final local = parsed.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day ${months[local.month - 1]} $hour:$minute';
  }

  Widget _buildArchiveSessionTile(
    MobileArchiveSession session,
    ThemeData theme,
    ColorScheme scheme,
  ) {
    final unit = session.displayUnit;
    final title = session.displayItemName;
    final subtitle = _formatArchiveSessionSubtitle(session);
    final totalLabel = session.totalQty == 0
        ? '0.000 $unit'
        : '${session.totalQty.toStringAsFixed(3)} $unit';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: _archivePrintLoadingSessionId.isNotEmpty
          ? null
          : () => unawaited(_confirmArchivePrint(session)),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(left: 12, right: 0, bottom: 12),
        shape: const Border(),
        collapsedShape: const Border(),
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        iconColor: scheme.primary,
        collapsedIconColor: scheme.primary,
        leading: Icon(
          session.active ? Icons.timelapse_rounded : Icons.archive_outlined,
          color: session.active ? scheme.tertiary : scheme.primary,
        ),
        title: Text(
          title.isEmpty ? '-' : title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              totalLabel,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${session.printCount} print',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        children: [
          if (session.prints.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Text(
                "Print history hali yo'q.",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...session.prints.map(
              (entry) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.playlist_add_check_rounded,
                  size: 18,
                  color: scheme.primary,
                ),
                title: Text(
                  '${entry.qty.toStringAsFixed(3)} ${entry.unit}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  [
                    formatArchiveTimestamp(entry.printedAt),
                    if (entry.draftName.isNotEmpty) entry.draftName,
                  ].join(' • '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlSection(
    BuildContext context,
    ThemeData theme,
    ColorScheme scheme,
    DiscoveredServer server,
  ) {
    final selectedProduct = _selectedItem;
    final selectedWarehouse = _selectedWarehouse;
    final batchRunning = _snapshot.batchActive;
    final defaultWarehouse = _currentDefaultWarehouse;
    final defaultMode = _warehouseMode == 'default';
    final modeLocked = batchRunning || _batchActionLoading;
    final printerLocked = batchRunning || _batchActionLoading;
    final selectedPrinter = normalizePrinterChoice(_batchPrinter);
    final selectedQuantitySource = normalizeQuantitySource(_quantitySource);
    final manualQtyKg = selectedQuantitySource == 'manual'
        ? parsePositiveKg(_manualQtyController.text)
        : null;
    final manualPrintReady = canTriggerManualPrint(
      qtyText: _manualQtyController.text,
      babinaEnabled: _babinaEnabled,
      babinaText: _babinaWeightController.text,
    );
    final manualQtyInvalid = selectedQuantitySource == 'manual' &&
        _manualQtyController.text.trim().isNotEmpty &&
        manualQtyKg == null;
    final babinaKg =
        _babinaEnabled ? parsePositiveKg(_babinaWeightController.text) : null;
    final babinaInvalid = _babinaEnabled &&
        _babinaWeightController.text.trim().isNotEmpty &&
        babinaKg == null;
    final printerStatusText = _printerStatusOverride.isNotEmpty
        ? _printerStatusOverride
        : _snapshot.printerLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _MetricSummary(
                title: 'Live kg',
                value: _snapshot.scaleValue,
                caption: _snapshot.scaleCaption,
                icon: Icons.scale_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MiniIconRow(
                      icon: Icons.print_outlined,
                      text: printerStatusText,
                    ),
                    const SizedBox(height: 8),
                    _MiniIconRow(
                      icon: Icons.scale_outlined,
                      text: _snapshot.scaleConnectionLabel,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        _SectionLabel(title: 'Item selection', subtitle: ''),
        const SizedBox(height: 8),
        _PickerField(
          icon: Icons.search_rounded,
          label: 'Mahsulot tanlang',
          value: selectedProduct?.itemCode,
          subtitle: null,
          onTap: batchRunning ? null : _openItemPicker,
        ),
        const SizedBox(height: 28),
        _SectionLabel(title: 'Warehouse selection', subtitle: ''),
        const SizedBox(height: 8),
        if (defaultMode) ...[
          if (defaultWarehouse.isEmpty)
            Text(
              'Default ombor tanlanmagan.',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
            )
          else
            _MiniIconRow(
              icon: Icons.flag_rounded,
              text: 'Default warehouse: $defaultWarehouse',
            ),
        ] else if (selectedProduct == null) ...[
          const SizedBox(height: 10),
          Text(
            'Item tanlang, keyin warehouse chiqadi.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ] else ...[
          _PickerField(
            icon: Icons.warehouse_outlined,
            label: 'Warehouse tanlang',
            value: selectedWarehouse?.warehouse,
            subtitle: null,
            onTap: batchRunning ? null : _openWarehousePicker,
          ),
          if (_warehousesError.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              _warehousesError,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
          ],
        ],
        const SizedBox(height: 28),
        Text(
          'Babina',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: false,
                  label: Text("Yo'q"),
                  icon: Icon(Icons.close_rounded),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text('Bor'),
                  icon: Icon(Icons.functions_rounded),
                ),
              ],
              selected: <bool>{_babinaEnabled},
              onSelectionChanged: printerLocked
                  ? null
                  : (selection) {
                      if (selection.isEmpty) {
                        return;
                      }
                      setState(() {
                        _babinaEnabled = selection.first;
                      });
                      _scheduleSaveControlPrefs();
                    },
            ),
          ],
        ),
        if (_babinaEnabled) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _babinaWeightController,
            enabled: !printerLocked,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            maxLines: 1,
            minLines: 1,
            textAlignVertical: TextAlignVertical.center,
            decoration: InputDecoration(
              labelText: 'Babina',
              suffixText: 'kg',
              hintText: '0.78',
              errorText: babinaInvalid ? 'Masalan: 0.78' : null,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
        const SizedBox(height: 14),
        IgnorePointer(
          ignoring: printerLocked,
          child: Opacity(
            opacity: printerLocked ? 0.6 : 1,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(
                  value: 'scale',
                  label: Text('Scale kg'),
                  icon: Icon(Icons.scale_outlined),
                ),
                ButtonSegment<String>(
                  value: 'manual',
                  label: Text('Manual kg'),
                  icon: Icon(Icons.edit_note_rounded),
                ),
              ],
              selected: <String>{selectedQuantitySource},
              onSelectionChanged: (selection) {
                if (selection.isEmpty) {
                  return;
                }
                setState(() {
                  _quantitySource = normalizeQuantitySource(selection.first);
                });
                _scheduleSaveControlPrefs();
              },
            ),
          ),
        ),
        if (selectedQuantitySource == 'manual') ...[
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: TextField(
                    controller: _manualQtyController,
                    enabled: !_batchActionLoading && !_manualPrintLoading,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    textAlignVertical: TextAlignVertical.center,
                    decoration: InputDecoration(
                      labelText: 'Manual brutto kg',
                      suffixText: 'kg',
                      hintText: '5',
                      errorText:
                          manualQtyInvalid ? 'Masalan: 5 yoki 4.22' : null,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: SizedBox(
                  height: 56,
                  width: 56,
                  child: IconButton.filled(
                    tooltip: 'Print',
                    onPressed: batchRunning &&
                            selectedQuantitySource == 'manual' &&
                            manualPrintReady &&
                            !_manualPrintLoading &&
                            !_batchActionLoading
                        ? _printManualBatch
                        : null,
                    icon: _manualPrintLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                  ),
                ),
              ),
            ],
          ),
          if (_manualPrintLoading) ...[
            const SizedBox(height: 6),
            Text(
              'Print yuborilmoqda...',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 14),
        ],
        ExpansionTile(
          key: const PageStorageKey<String>('batch_actions_tile'),
          initiallyExpanded: false,
          maintainState: true,
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: Text(
            'Batch actions',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          children: [
            IgnorePointer(
              ignoring: printerLocked,
              child: Opacity(
                opacity: printerLocked ? 0.6 : 1,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment<String>(
                      value: 'zebra',
                      label: Text('Zebra'),
                      icon: Icon(Icons.memory_rounded),
                    ),
                    ButtonSegment<String>(
                      value: 'godex',
                      label: Text('GoDEX'),
                      icon: Icon(Icons.local_printshop_outlined),
                    ),
                  ],
                  selected: <String>{selectedPrinter},
                  onSelectionChanged: (selection) {
                    if (selection.isEmpty) {
                      return;
                    }
                    final nextPrinter = normalizePrinterChoice(selection.first);
                    if (nextPrinter == selectedPrinter) {
                      return;
                    }
                    setState(() {
                      _batchPrinter = nextPrinter;
                      if (nextPrinter == 'godex') {
                        _batchPrintMode = 'label';
                      }
                    });
                    _scheduleSaveControlPrefs();
                  },
                ),
              ),
            ),
            if (selectedPrinter == 'godex') ...[
              const SizedBox(height: 8),
              _MiniIconRow(
                icon: Icons.info_outline_rounded,
                text: 'GoDEX label-only chop qiladi, RFID encode qilmaydi.',
              ),
            ],
            const SizedBox(height: 10),
            IgnorePointer(
              ignoring: modeLocked || selectedPrinter == 'godex',
              child: Opacity(
                opacity: modeLocked || selectedPrinter == 'godex' ? 0.6 : 1,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment<String>(
                      value: 'rfid',
                      label: Text('RFID'),
                      icon: Icon(Icons.memory_rounded),
                    ),
                    ButtonSegment<String>(
                      value: 'label',
                      label: Text('Label only'),
                      icon: Icon(Icons.local_printshop_outlined),
                    ),
                  ],
                  selected: <String>{_batchPrintMode},
                  onSelectionChanged: (selection) {
                    if (selection.isEmpty) {
                      return;
                    }
                    final nextMode = selection.first;
                    if (nextMode == _batchPrintMode) {
                      return;
                    }
                    setState(() {
                      _batchPrintMode = nextMode;
                    });
                    _scheduleSaveControlPrefs();
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed:
                    batchRunning && !_batchActionLoading ? _stopBatch : null,
                icon: const Icon(Icons.stop_rounded),
                label: Text(_batchActionLoading ? 'Stopping...' : 'Batch Stop'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: selectedProduct == null ||
                        (defaultMode
                            ? defaultWarehouse.isEmpty
                            : selectedWarehouse == null) ||
                        (_babinaEnabled && babinaKg == null) ||
                        batchRunning ||
                        _batchActionLoading
                    ? null
                    : _startBatch,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  _batchActionLoading ? 'Starting...' : 'Batch Start',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DashboardScrollView extends StatelessWidget {
  const _DashboardScrollView({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return ListView(
      padding: EdgeInsets.fromLTRB(18, 8, 18, 24 + bottomInset + 96),
      children: [child],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        if (subtitle.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasValue = (value ?? '').trim().isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: InputDecoration(
          prefixIcon: Icon(icon),
          suffixIcon: const Icon(Icons.expand_more_rounded),
          labelText: label,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hasValue ? value!.trim() : 'Tanlash uchun bosing',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: hasValue ? scheme.onSurface : scheme.onSurfaceVariant,
                fontWeight: hasValue ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if ((subtitle ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!.trim(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricSummary extends StatelessWidget {
  const _MetricSummary({
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
  });

  final String title;
  final String value;
  final String caption;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: scheme.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                caption,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniIconRow extends StatelessWidget {
  const _MiniIconRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: scheme.primary, size: 20),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: child,
    );
  }
}

class _ServerHeaderCard extends StatelessWidget {
  const _ServerHeaderCard({
    required this.connected,
    required this.statusText,
    required this.displayName,
    required this.endpoint,
    required this.role,
    required this.serverRef,
    required this.latencyMs,
  });

  final bool connected;
  final String statusText;
  final String displayName;
  final String endpoint;
  final String role;
  final String serverRef;
  final int latencyMs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: connected
                      ? scheme.secondaryContainer
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  connected ? 'Connected' : 'Selected server',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: connected
                        ? scheme.onSecondaryContainer
                        : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                statusText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            displayName,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            endpoint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(role.toUpperCase())),
              Chip(label: Text(serverRef)),
              if (latencyMs > 0) Chip(label: Text('$latencyMs ms')),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiveMetricCard extends StatelessWidget {
  const _LiveMetricCard({
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
  });

  final String title;
  final String value;
  final String caption;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.primary, size: 20),
          const SizedBox(height: 18),
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemOptionTile extends StatelessWidget {
  const _ItemOptionTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final MobileItem item;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.itemCode,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected ? scheme.primary : scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.itemName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (selected) Icon(Icons.check_rounded, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}

class _WarehouseOptionTile extends StatelessWidget {
  const _WarehouseOptionTile({
    required this.warehouse,
    required this.selected,
    required this.onTap,
  });

  final MobileWarehouse warehouse;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    warehouse.warehouse,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected ? scheme.primary : scheme.onSurface,
                    ),
                  ),
                  if (warehouse.caption.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      warehouse.caption,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (selected) Icon(Icons.check_rounded, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}

class _ItemPickerSheet extends StatefulWidget {
  const _ItemPickerSheet({required this.fetchItems, this.initialItem});

  final Future<List<MobileItem>> Function({required String query}) fetchItems;
  final MobileItem? initialItem;

  @override
  State<_ItemPickerSheet> createState() => _ItemPickerSheetState();
}

class _ItemPickerSheetState extends State<_ItemPickerSheet> {
  late final TextEditingController _controller;
  Timer? _debounce;
  bool _loading = false;
  String _error = '';
  List<MobileItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_loadItems(query: ''));
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      unawaited(_loadItems());
    });
  }

  Future<void> _loadItems({String? query}) async {
    final search = (query ?? _controller.text).trim();
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final items = await widget.fetchItems(query: search);
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _items = const [];
        _loading = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: FractionallySizedBox(
        heightFactor: 0.82,
        child: Material(
          color: theme.scaffoldBackgroundColor,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Mahsulot tanlang',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    onChanged: (_) => _scheduleSearch(),
                    decoration: const InputDecoration(
                      hintText: 'Mahsulot qidiring',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        color: scheme.surfaceContainerLow,
                        child: _loading
                            ? const Center(child: CircularProgressIndicator())
                            : _error.isNotEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Text(
                                        _error,
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          color: scheme.error,
                                        ),
                                      ),
                                    ),
                                  )
                                : _items.isEmpty
                                    ? Center(
                                        child: Text(
                                          'Mahsulot topilmadi.',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      )
                                    : ListView.separated(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                          vertical: 12,
                                        ),
                                        itemCount: _items.length,
                                        separatorBuilder: (context, index) =>
                                            Divider(
                                          height: 1,
                                          color:
                                              scheme.outlineVariant.withValues(
                                            alpha: 0.7,
                                          ),
                                        ),
                                        itemBuilder: (context, index) {
                                          final item = _items[index];
                                          final selected =
                                              widget.initialItem?.itemCode ==
                                                  item.itemCode;
                                          return _ItemOptionTile(
                                            item: item,
                                            selected: selected,
                                            onTap: () {
                                              Navigator.of(context).pop(item);
                                            },
                                          );
                                        },
                                      ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WarehousePickerSheet extends StatefulWidget {
  const _WarehousePickerSheet({
    required this.title,
    required this.queryHint,
    required this.emptyText,
    required this.fetchWarehouses,
    this.initialWarehouse,
  });

  final String title;
  final String queryHint;
  final String emptyText;
  final Future<List<MobileWarehouse>> Function({required String query})
      fetchWarehouses;
  final MobileWarehouse? initialWarehouse;

  @override
  State<_WarehousePickerSheet> createState() => _WarehousePickerSheetState();
}

class _WarehousePickerSheetState extends State<_WarehousePickerSheet> {
  late final TextEditingController _controller;
  Timer? _debounce;
  bool _loading = false;
  String _error = '';
  List<MobileWarehouse> _warehouses = const [];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_loadWarehouses(query: ''));
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      unawaited(_loadWarehouses());
    });
  }

  Future<void> _loadWarehouses({String? query}) async {
    final search = (query ?? _controller.text).trim();
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final warehouses = await widget.fetchWarehouses(query: search);
      if (!mounted) {
        return;
      }
      setState(() {
        _warehouses = warehouses;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _warehouses = const [];
        _loading = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: FractionallySizedBox(
        heightFactor: 0.82,
        child: Material(
          color: theme.scaffoldBackgroundColor,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    onChanged: (_) => _scheduleSearch(),
                    decoration: InputDecoration(
                      hintText: widget.queryHint,
                      prefixIcon: const Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        color: scheme.surfaceContainerLow,
                        child: _loading
                            ? const Center(child: CircularProgressIndicator())
                            : _error.isNotEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Text(
                                        _error,
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          color: scheme.error,
                                        ),
                                      ),
                                    ),
                                  )
                                : _warehouses.isEmpty
                                    ? Center(
                                        child: Text(
                                          widget.emptyText,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      )
                                    : ListView.separated(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                          vertical: 12,
                                        ),
                                        itemCount: _warehouses.length,
                                        separatorBuilder: (context, index) =>
                                            Divider(
                                          height: 1,
                                          color:
                                              scheme.outlineVariant.withValues(
                                            alpha: 0.7,
                                          ),
                                        ),
                                        itemBuilder: (context, index) {
                                          final warehouse = _warehouses[index];
                                          final selected = widget
                                                  .initialWarehouse
                                                  ?.warehouse ==
                                              warehouse.warehouse;
                                          return _WarehouseOptionTile(
                                            warehouse: warehouse,
                                            selected: selected,
                                            onTap: () {
                                              Navigator.of(context)
                                                  .pop(warehouse);
                                            },
                                          );
                                        },
                                      ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanningState extends StatelessWidget {
  const _ScanningState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.6),
          ),
          const SizedBox(width: 14),
          Text(
            'Scanning...',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyServerState extends StatelessWidget {
  const _EmptyServerState({required this.onManualAdd});

  final VoidCallback onManualAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No servers',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pull down to refresh or add address.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onManualAdd, child: const Text('Add address')),
        ],
      ),
    );
  }
}

class _ServerCard extends StatelessWidget {
  const _ServerCard({required this.server, required this.onOpen});

  final DiscoveredServer server;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surfaceContainerLow,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Icon(
                _wifiIconForLatency(server.latencyMs),
                color: scheme.primary,
                size: 28,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      server.handshake.serverName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      server.endpoint.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Connect',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServerList extends StatelessWidget {
  const _ServerList({required this.servers, required this.onOpenServer});

  final List<DiscoveredServer> servers;
  final ValueChanged<DiscoveredServer> onOpenServer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        for (var i = 0; i < servers.length; i++) ...[
          _ServerCard(
            server: servers[i],
            onOpen: () => onOpenServer(servers[i]),
          ),
          if (i != servers.length - 1)
            Divider(
              height: 1,
              color: scheme.outlineVariant,
            ),
        ],
      ],
    );
  }
}

IconData _wifiIconForLatency(int latencyMs) {
  if (latencyMs <= 20) {
    return Icons.signal_wifi_4_bar_rounded;
  }
  if (latencyMs <= 60) {
    return Icons.network_wifi_2_bar_rounded;
  }
  return Icons.network_wifi_1_bar_rounded;
}

class ManualServerSheet extends StatefulWidget {
  const ManualServerSheet({required this.client, super.key});

  final http.Client client;

  @override
  State<ManualServerSheet> createState() => _ManualServerSheetState();
}

class _ManualServerSheetState extends State<ManualServerSheet> {
  late final TextEditingController _controller;
  bool _checking = false;
  String _errorText = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _sanitizeManualServerAddress(_configuredApiBaseUrl),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_checking) {
      return;
    }

    setState(() {
      _checking = true;
      _errorText = '';
    });

    final endpoint = parseServerEndpoint(_controller.text);
    if (endpoint == null) {
      setState(() {
        _checking = false;
        _errorText = 'Address format is invalid';
      });
      return;
    }
    if (_shouldSkipDiscoveryHost(endpoint.host)) {
      setState(() {
        _checking = false;
        _errorText = 'Use Wi-Fi server address, not localhost';
      });
      return;
    }

    final server = await probeServer(
      widget.client,
      endpoint,
      timeout: _manualProbeTimeout,
    );
    if (!mounted) {
      return;
    }

    if (server == null) {
      setState(() {
        _checking = false;
        _errorText = 'Handshake failed for this server';
      });
      return;
    }

    Navigator.of(context).pop(server);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, bottomInset + 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add server',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Example: 192.168.1.12:39117',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Server address',
              hintText: 'http://192.168.1.12:39117',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (_errorText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(_errorText, style: TextStyle(color: scheme.error)),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _checking ? null : _submit,
            icon: const Icon(Icons.link_rounded),
            label: Text(_checking ? 'Checking...' : 'Connect to server'),
          ),
        ],
      ),
    );
  }
}

class _StatusGrid extends StatelessWidget {
  const _StatusGrid({required this.snapshot});

  final MonitorSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _StatusRow(
          title: 'Scale',
          value: snapshot.scaleValue,
          caption: snapshot.scaleCaption,
          icon: Icons.scale_outlined,
        ),
        Divider(color: Theme.of(context).colorScheme.outlineVariant),
        _StatusRow(
          title: 'Zebra',
          value: snapshot.zebraValue,
          caption: snapshot.zebraCaption,
          icon: Icons.print_outlined,
        ),
        Divider(color: Theme.of(context).colorScheme.outlineVariant),
        _StatusRow(
          title: 'Batch',
          value: snapshot.batchValue,
          caption: snapshot.batchCaption,
          icon: Icons.inventory_2_outlined,
        ),
        Divider(color: Theme.of(context).colorScheme.outlineVariant),
        _StatusRow(
          title: 'Bridge',
          value: snapshot.bridgeValue,
          caption: snapshot.bridgeCaption,
          icon: Icons.sync_outlined,
        ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
  });

  final String title;
  final String value;
  final String caption;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.primary, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  caption,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodoRow extends StatelessWidget {
  const _TodoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: scheme.onSecondaryContainer),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class MonitorSnapshot {
  const MonitorSnapshot({
    required this.scaleValue,
    required this.scaleCaption,
    required this.scaleConnectionLabel,
    required this.zebraValue,
    required this.zebraCaption,
    required this.batchValue,
    required this.batchCaption,
    required this.bridgeValue,
    required this.bridgeCaption,
    required this.serverLabel,
    required this.monitorLabel,
    required this.printerLabel,
    required this.printerKind,
    required this.printerState,
    required this.printerEventKey,
    required this.printerEventMessage,
    required this.batchActive,
    required this.batchItemCode,
    required this.batchItemName,
    required this.batchWarehouse,
    required this.batchPrintMode,
    required this.batchPrinter,
    required this.batchQuantitySource,
    required this.batchManualQtyKg,
    required this.batchTareEnabled,
    required this.batchTareKg,
    required this.latencyMs,
  });

  factory MonitorSnapshot.empty() {
    return const MonitorSnapshot(
      scaleValue: '--',
      scaleCaption: 'Live qty',
      scaleConnectionLabel: 'Scale: ulanmagan',
      zebraValue: 'Idle',
      zebraCaption: 'Printer state',
      batchValue: 'Stopped',
      batchCaption: 'Workflow',
      bridgeValue: 'Ready',
      bridgeCaption: 'Shared state',
      serverLabel: 'API: idle',
      monitorLabel: 'Scale, Zebra, batch va print request holati',
      printerLabel: 'ulanmagan',
      printerKind: '',
      printerState: 'idle',
      printerEventKey: '',
      printerEventMessage: '',
      batchActive: false,
      batchItemCode: '',
      batchItemName: '',
      batchWarehouse: '',
      batchPrintMode: 'rfid',
      batchPrinter: 'zebra',
      batchQuantitySource: 'scale',
      batchManualQtyKg: 0,
      batchTareEnabled: false,
      batchTareKg: 0,
      latencyMs: 0,
    );
  }

  factory MonitorSnapshot.fromJson(Map<String, dynamic> json) {
    final state = (json['state'] as Map?)?.cast<String, dynamic>() ?? const {};
    final scale = (state['scale'] as Map?)?.cast<String, dynamic>() ?? const {};
    final zebra = (state['zebra'] as Map?)?.cast<String, dynamic>() ?? const {};
    final batch = (state['batch'] as Map?)?.cast<String, dynamic>() ?? const {};
    final printRequest =
        (state['print_request'] as Map?)?.cast<String, dynamic>() ?? const {};

    final scaleWeight = scale['weight'];
    final scaleUnit = _text(scale['unit'], fallback: 'kg');
    final scaleStable = scale['stable'] == true ? 'stable' : 'live';
    final scaleConnectionLabel = buildScaleConnectionLabel(
      source: _text(scale['source']),
      port: _text(scale['port']),
      error: _text(scale['error']),
    );

    final zebraVerify = _text(zebra['verify'], fallback: 'idle');
    final zebraAction = _text(zebra['action'], fallback: 'printer state');

    final batchActive = batch['active'] == true;
    final batchItemCode = _text(batch['item_code']);
    final batchItem = _text(batch['item_name'], fallback: batchItemCode);
    final batchWarehouse = _text(batch['warehouse']);
    final batchPrintMode = _text(batch['print_mode']);
    final batchPrinter = normalizePrinterChoice(_text(batch['printer']));
    final batchQuantitySource = normalizeQuantitySource(
      _text(batch['quantity_source']),
    );
    final batchManualQtyKg = (batch['manual_qty_kg'] as num?)?.toDouble() ?? 0;
    final batchTareEnabled = batch['tare'] == true;
    final batchTareKg = (batch['tare_kg'] as num?)?.toDouble() ?? 0;

    final printStatus = _text(printRequest['status'], fallback: 'idle');
    final printerStateJson =
        (state['printer'] as Map?)?.cast<String, dynamic>() ?? const {};
    final printerConnected = printerStateJson['connected'] == true;
    final printerLabel = _text(
      printerStateJson['label'],
      fallback: 'ulanmagan',
    );
    final printerKind = _text(printerStateJson['kind']);
    final printRequestEpc = _text(printRequest['epc']);
    final printRequestError = _text(printRequest['error']);

    return MonitorSnapshot(
      scaleValue: scaleWeight == null ? '--' : '$scaleWeight $scaleUnit',
      scaleCaption: scaleStable,
      scaleConnectionLabel: scaleConnectionLabel,
      zebraValue: zebraVerify.toUpperCase(),
      zebraCaption: zebraAction,
      batchValue: batchActive ? 'Active' : 'Stopped',
      batchCaption: batchItem.isEmpty ? 'Workflow' : batchItem,
      bridgeValue: printStatus == 'idle' ? 'Ready' : printStatus,
      bridgeCaption: _text(printRequest['epc'], fallback: 'Shared state'),
      serverLabel: _text(json['ok'], fallback: 'unknown') == 'true'
          ? 'API: online'
          : 'API: offline',
      monitorLabel: batchItem.isEmpty ? 'No active batch' : 'Batch: $batchItem',
      printerLabel: printerConnected ? printerLabel : 'ulanmagan',
      printerKind: printerConnected ? printerKind : '',
      printerState: derivePrinterState(
        printStatus: printStatus,
        latestPrinterStatus: printStatus,
        activePrinterEPC: printStatus == 'processing' ? printRequestEpc : '',
      ),
      printerEventKey: buildPrinterEventKey(
        latestPrinterStatus: printStatus,
        latestPrinterEPC: printRequestEpc,
        latestPrinterError: printRequestError,
        printStatus: printStatus,
      ),
      printerEventMessage: buildPrinterEventMessage(
        printStatus: printStatus,
        latestPrinterStatus: printStatus,
        latestPrinterEPC: printRequestEpc,
        latestPrinterError: printRequestError,
        printerChoice: batchPrinter,
      ),
      batchActive: batchActive,
      batchItemCode: batchItemCode,
      batchItemName: batchItem,
      batchWarehouse: batchWarehouse,
      batchPrintMode: batchPrintMode,
      batchPrinter: batchPrinter,
      batchQuantitySource: batchQuantitySource,
      batchManualQtyKg: batchManualQtyKg,
      batchTareEnabled: batchTareEnabled,
      batchTareKg: batchTareKg,
      latencyMs: 0,
    );
  }

  MonitorSnapshot copyWithBatch(MobileBatchState batch) {
    final itemName = batch.displayItemName;
    return MonitorSnapshot(
      scaleValue: scaleValue,
      scaleCaption: scaleCaption,
      scaleConnectionLabel: scaleConnectionLabel,
      zebraValue: zebraValue,
      zebraCaption: zebraCaption,
      batchValue: batch.active ? 'Active' : 'Stopped',
      batchCaption: itemName.isEmpty ? 'Workflow' : itemName,
      bridgeValue: bridgeValue,
      bridgeCaption: bridgeCaption,
      serverLabel: serverLabel,
      monitorLabel: itemName.isEmpty ? 'No active batch' : 'Batch: $itemName',
      printerLabel: printerLabel,
      printerKind: printerKind,
      printerState: printerState,
      printerEventKey: printerEventKey,
      printerEventMessage: printerEventMessage,
      batchActive: batch.active,
      batchItemCode: batch.itemCode,
      batchItemName: itemName,
      batchWarehouse: batch.warehouse,
      batchPrintMode: batch.active
          ? (batch.printMode.isNotEmpty ? batch.printMode : batchPrintMode)
          : batchPrintMode,
      batchPrinter: batch.active
          ? (batch.printer.isNotEmpty ? batch.printer : batchPrinter)
          : batchPrinter,
      batchQuantitySource:
          batch.active ? batch.quantitySource : batchQuantitySource,
      batchManualQtyKg: batch.active ? batch.manualQtyKg : batchManualQtyKg,
      batchTareEnabled: batch.active ? batch.tareEnabled : batchTareEnabled,
      batchTareKg: batch.active ? batch.tareKg : batchTareKg,
      latencyMs: latencyMs,
    );
  }

  final String scaleValue;
  final String scaleCaption;
  final String scaleConnectionLabel;
  final String zebraValue;
  final String zebraCaption;
  final String batchValue;
  final String batchCaption;
  final String bridgeValue;
  final String bridgeCaption;
  final String serverLabel;
  final String monitorLabel;
  final String printerLabel;
  final String printerKind;
  final String printerState;
  final String printerEventKey;
  final String printerEventMessage;
  final bool batchActive;
  final String batchItemCode;
  final String batchItemName;
  final String batchWarehouse;
  final String batchPrintMode;
  final String batchPrinter;
  final String batchQuantitySource;
  final double batchManualQtyKg;
  final bool batchTareEnabled;
  final double batchTareKg;
  final int latencyMs;

  MonitorSnapshot copyWithLatency(int latencyMs) {
    return MonitorSnapshot(
      scaleValue: scaleValue,
      scaleCaption: scaleCaption,
      scaleConnectionLabel: scaleConnectionLabel,
      zebraValue: zebraValue,
      zebraCaption: zebraCaption,
      batchValue: batchValue,
      batchCaption: batchCaption,
      bridgeValue: bridgeValue,
      bridgeCaption: bridgeCaption,
      serverLabel: serverLabel,
      monitorLabel: monitorLabel,
      printerLabel: printerLabel,
      printerKind: printerKind,
      printerState: printerState,
      printerEventKey: printerEventKey,
      printerEventMessage: printerEventMessage,
      batchActive: batchActive,
      batchItemCode: batchItemCode,
      batchItemName: batchItemName,
      batchWarehouse: batchWarehouse,
      batchPrintMode: batchPrintMode,
      batchPrinter: batchPrinter,
      batchQuantitySource: batchQuantitySource,
      batchManualQtyKg: batchManualQtyKg,
      batchTareEnabled: batchTareEnabled,
      batchTareKg: batchTareKg,
      latencyMs: latencyMs,
    );
  }

  String get livePrinterChoice {
    final kind = printerKind.trim().toLowerCase();
    if (kind == 'zebra' || kind == 'godex') {
      return kind;
    }
    final label = printerLabel.trim().toLowerCase();
    if (label.startsWith('zebra')) {
      return 'zebra';
    }
    if (label.startsWith('godex') || label.startsWith('go-dex')) {
      return 'godex';
    }
    return '';
  }
}

String normalizePrinterChoice(String printer) {
  switch (printer.trim().toLowerCase()) {
    case 'godex':
    case 'go-dex':
    case 'g500':
      return 'godex';
    case 'zebra':
    case 'zpl':
    case 'rfid':
    default:
      return 'zebra';
  }
}

String displayPrinterChoice(String printer) {
  return normalizePrinterChoice(printer) == 'godex' ? 'GoDEX' : 'Zebra';
}

String normalizeQuantitySource(String source) {
  return source.trim().toLowerCase() == 'manual' ? 'manual' : 'scale';
}

double? parsePositiveKg(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  if (normalized.isEmpty) {
    return null;
  }
  final parsed = double.tryParse(normalized);
  if (parsed == null || parsed <= 0) {
    return null;
  }
  return parsed;
}

bool canTriggerManualPrint({
  required String qtyText,
  required bool babinaEnabled,
  required String babinaText,
}) {
  final manualQtyKg = parsePositiveKg(qtyText);
  if (manualQtyKg == null) {
    return false;
  }
  final double? babinaKg = babinaEnabled ? parsePositiveKg(babinaText) : null;
  if (babinaEnabled && babinaKg == null) {
    return false;
  }
  final netQty = manualQtyKg - (babinaKg ?? 0);
  return manualQtyKg > (babinaKg ?? 0) && netQty >= _minManualPrintKg;
}

String formatCompactKg(double value) {
  var text = value.toStringAsFixed(3);
  while (text.contains('.') && text.endsWith('0')) {
    text = text.substring(0, text.length - 1);
  }
  if (text.endsWith('.')) {
    text = text.substring(0, text.length - 1);
  }
  return text;
}

String buildScaleConnectionLabel({
  required String source,
  required String port,
  required String error,
}) {
  if (error.trim().isNotEmpty) {
    return 'Scale: ulanmagan';
  }
  if (source.trim().isNotEmpty || port.trim().isNotEmpty) {
    return 'Scale: ulangan';
  }
  return 'Scale: ulanmagan';
}

String derivePrinterState({
  required String printStatus,
  required String latestPrinterStatus,
  required String activePrinterEPC,
}) {
  final requestState = _text(printStatus, fallback: 'idle').toLowerCase();
  final historyState = _text(
    latestPrinterStatus,
    fallback: 'idle',
  ).toLowerCase();
  if (activePrinterEPC.isNotEmpty ||
      requestState == 'processing' ||
      historyState == 'processing') {
    return 'processing';
  }
  if (historyState == 'done' || requestState == 'done') {
    return 'done';
  }
  if (historyState == 'error' || requestState == 'error') {
    return 'error';
  }
  return 'idle';
}

String buildPrinterEventKey({
  required String latestPrinterStatus,
  required String latestPrinterEPC,
  required String latestPrinterError,
  required String printStatus,
}) {
  final state = derivePrinterState(
    printStatus: printStatus,
    latestPrinterStatus: latestPrinterStatus,
    activePrinterEPC: '',
  );
  if (state == 'idle' || state == 'processing') {
    return '';
  }
  final epc = _text(latestPrinterEPC);
  final err = _text(latestPrinterError);
  return '$state|$epc|$err';
}

String buildPrinterEventMessage({
  required String printStatus,
  required String latestPrinterStatus,
  required String latestPrinterEPC,
  required String latestPrinterError,
  required String printerChoice,
}) {
  final state = derivePrinterState(
    printStatus: printStatus,
    latestPrinterStatus: latestPrinterStatus,
    activePrinterEPC: '',
  );
  final epc = _text(latestPrinterEPC);
  final err = _text(latestPrinterError);
  final printerName =
      normalizePrinterChoice(printerChoice) == 'godex' ? 'godex' : 'zebra';
  if (state == 'done') {
    return epc.isEmpty
        ? '$printerName: print qildi'
        : '$printerName: print qildi • $epc';
  }
  if (state == 'error') {
    if (err.isNotEmpty) {
      return '$printerName: failed • $err';
    }
    return epc.isEmpty ? '$printerName: failed' : '$printerName: failed • $epc';
  }
  return '';
}

class MobileItem {
  const MobileItem({required this.itemCode, required this.itemName});

  factory MobileItem.fromJson(Map<String, dynamic> json) {
    final itemCode = _text(json['item_code'], fallback: _text(json['name']));
    final itemName = _text(json['item_name'], fallback: itemCode);
    return MobileItem(itemCode: itemCode, itemName: itemName);
  }

  final String itemCode;
  final String itemName;
}

class MobileWarehouse {
  const MobileWarehouse({
    required this.warehouse,
    this.actualQty,
    this.company,
  });

  factory MobileWarehouse.fromJson(Map<String, dynamic> json) {
    return MobileWarehouse(
      warehouse: _text(json['warehouse']),
      actualQty: (json['actual_qty'] as num?)?.toDouble(),
      company: _text(json['company']),
    );
  }

  final String warehouse;
  final double? actualQty;
  final String? company;

  String get caption {
    final companyText = company?.trim() ?? '';
    if (companyText.isNotEmpty) {
      return companyText;
    }
    if (actualQty != null) {
      return 'Qoldiq: ${actualQty!.toStringAsFixed(3)}';
    }
    return '';
  }

  String get label => actualQty == null
      ? warehouse
      : '$warehouse • ${actualQty!.toStringAsFixed(3)}';
}

class MobileBatchState {
  const MobileBatchState({
    required this.active,
    required this.itemCode,
    required this.itemName,
    required this.warehouse,
    required this.printMode,
    required this.printer,
    required this.quantitySource,
    required this.manualQtyKg,
    required this.tareEnabled,
    required this.tareKg,
  });

  factory MobileBatchState.fromJson(Map<String, dynamic> json) {
    return MobileBatchState(
      active: json['active'] == true,
      itemCode: _text(json['item_code']),
      itemName: _text(json['item_name']),
      warehouse: _text(json['warehouse']),
      printMode: _text(json['print_mode']),
      printer: normalizePrinterChoice(_text(json['printer'])),
      quantitySource: normalizeQuantitySource(_text(json['quantity_source'])),
      manualQtyKg: (json['manual_qty_kg'] as num?)?.toDouble() ?? 0,
      tareEnabled: json['tare'] == true,
      tareKg: (json['tare_kg'] as num?)?.toDouble() ?? 0,
    );
  }

  final bool active;
  final String itemCode;
  final String itemName;
  final String warehouse;
  final String printMode;
  final String printer;
  final String quantitySource;
  final double manualQtyKg;
  final bool tareEnabled;
  final double tareKg;

  String get displayItemName => itemName.isEmpty ? itemCode : itemName;
  String get displayPrintMode => printMode.isEmpty ? 'rfid' : printMode;
  String get displayPrinter => displayPrinterChoice(printer);
}

class MobileArchivePrintEntry {
  const MobileArchivePrintEntry({
    required this.itemCode,
    required this.itemName,
    required this.qty,
    required this.unit,
    required this.printedAt,
    required this.draftName,
    required this.epc,
  });

  factory MobileArchivePrintEntry.fromJson(Map<String, dynamic> json) {
    return MobileArchivePrintEntry(
      itemCode: _text(json['item_code']),
      itemName: _text(json['item_name']),
      qty: (json['qty'] as num?)?.toDouble() ?? 0,
      unit: _text(json['unit'], fallback: 'kg'),
      printedAt: _text(json['printed_at']),
      draftName: _text(json['draft_name']),
      epc: _text(json['epc']),
    );
  }

  final String itemCode;
  final String itemName;
  final double qty;
  final String unit;
  final String printedAt;
  final String draftName;
  final String epc;
}

class MobileArchiveSession {
  const MobileArchiveSession({
    required this.sessionId,
    required this.active,
    required this.itemCode,
    required this.itemName,
    required this.warehouse,
    required this.startedAt,
    required this.endedAt,
    required this.totalQty,
    required this.unit,
    required this.printCount,
    required this.prints,
  });

  factory MobileArchiveSession.fromJson(Map<String, dynamic> json) {
    final rawPrints =
        (json['prints'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    return MobileArchiveSession(
      sessionId: _text(json['session_id']),
      active: json['active'] == true,
      itemCode: _text(json['item_code']),
      itemName: _text(json['item_name']),
      warehouse: _text(json['warehouse']),
      startedAt: _text(json['started_at']),
      endedAt: _text(json['ended_at']),
      totalQty: (json['total_qty'] as num?)?.toDouble() ?? 0,
      unit: _text(json['unit'], fallback: 'kg'),
      printCount: (json['print_count'] as num?)?.toInt() ?? rawPrints.length,
      prints: rawPrints
          .map(MobileArchivePrintEntry.fromJson)
          .toList(growable: false),
    );
  }

  final String sessionId;
  final bool active;
  final String itemCode;
  final String itemName;
  final String warehouse;
  final String startedAt;
  final String endedAt;
  final double totalQty;
  final String unit;
  final int printCount;
  final List<MobileArchivePrintEntry> prints;

  String get displayItemName => itemName.isEmpty ? itemCode : itemName;
  String get displayUnit => unit.isEmpty ? 'kg' : unit;
}

class DiscoveryResult {
  const DiscoveryResult({required this.servers, required this.candidateCount});

  final List<DiscoveredServer> servers;
  final int candidateCount;
}

class DiscoveredServer {
  const DiscoveredServer({
    required this.endpoint,
    required this.handshake,
    required this.latencyMs,
  });

  final ServerEndpoint endpoint;
  final ServerHandshake handshake;
  final int latencyMs;

  String get discoveryKey {
    final ref = handshake.serverRef.trim().toLowerCase();
    final name = handshake.serverName.trim().toLowerCase();
    if (ref.isNotEmpty && ref != 'unknown' && ref != 'legacy-healthz') {
      return '$ref|$name';
    }
    return endpoint.label.toLowerCase();
  }
}

class ServerEndpoint {
  const ServerEndpoint({
    required this.host,
    required this.port,
    required this.baseUrl,
  });

  final String host;
  final int port;
  final String baseUrl;

  String get label => '$host:$port';
}

class ServerHandshake {
  const ServerHandshake({
    required this.serverName,
    required this.displayName,
    required this.role,
    required this.serverRef,
  });

  factory ServerHandshake.fromJson(Map<String, dynamic> json) {
    return ServerHandshake(
      serverName: _text(json['server_name'], fallback: 'gscale-zebra'),
      displayName: _text(json['display_name'], fallback: 'Operator'),
      role: _text(json['role'], fallback: 'operator'),
      serverRef: _text(json['server_ref'], fallback: 'unknown'),
    );
  }

  final String serverName;
  final String displayName;
  final String role;
  final String serverRef;
}

Future<DiscoveryResult> discoverServersFast(
  http.Client client, {
  ServerEndpoint? preferredEndpoint,
}) async {
  final candidates = await _loadCandidateHosts();
  final configuredEndpoint = parseServerEndpoint(_configuredApiBaseUrl);
  final probeTargets = _buildDirectProbeTargets(
    candidates: candidates,
    preferredEndpoint: preferredEndpoint,
    configuredEndpoint: configuredEndpoint,
  );

  final results = await _probeServers(
    client,
    probeTargets,
    timeout: _fastProbeTimeout,
    concurrency: 8,
  );
  results.sort((left, right) {
    if (preferredEndpoint != null) {
      final leftPreferred = left.endpoint.baseUrl == preferredEndpoint.baseUrl;
      final rightPreferred =
          right.endpoint.baseUrl == preferredEndpoint.baseUrl;
      if (leftPreferred != rightPreferred) {
        return leftPreferred ? -1 : 1;
      }
    }
    final latencyCmp = left.latencyMs.compareTo(right.latencyMs);
    if (latencyCmp != 0) {
      return latencyCmp;
    }
    return left.endpoint.baseUrl.compareTo(right.endpoint.baseUrl);
  });

  return DiscoveryResult(servers: results, candidateCount: probeTargets.length);
}

DiscoveryResult buildSeededDiscoveryResult({
  ServerEndpoint? preferredEndpoint,
}) {
  final configuredEndpoint = parseServerEndpoint(_configuredApiBaseUrl);
  final servers = <DiscoveredServer>[];
  final seen = <String>{};

  void addSeed(ServerEndpoint? endpoint, String displayName) {
    if (endpoint == null || _shouldSkipDiscoveryHost(endpoint.host)) {
      return;
    }
    if (!seen.add(endpoint.baseUrl)) {
      return;
    }
    servers.add(
      DiscoveredServer(
        endpoint: endpoint,
        handshake: ServerHandshake(
          serverName: endpoint.host,
          displayName: displayName,
          role: 'operator',
          serverRef: 'seed',
        ),
        latencyMs: 1,
      ),
    );
  }

  addSeed(preferredEndpoint, 'Recent server');
  addSeed(configuredEndpoint, 'Configured server');
  return DiscoveryResult(servers: servers, candidateCount: servers.length);
}

Future<DiscoveryResult> discoverServers(
  http.Client client, {
  ServerEndpoint? preferredEndpoint,
}) async {
  final announcementsFuture = _loadDiscoveryAnnouncements();
  final bonjourServersFuture = _loadBonjourDiscoveredServers();
  final candidates = await _loadCandidateHosts();
  final configuredEndpoint = parseServerEndpoint(_configuredApiBaseUrl);
  final resultsByKey = <String, DiscoveredServer>{};
  final probeTargets = _buildDirectProbeTargets(
    candidates: candidates,
    preferredEndpoint: preferredEndpoint,
    configuredEndpoint: configuredEndpoint,
  );
  final seenBaseUrls = probeTargets.map((endpoint) => endpoint.baseUrl).toSet();

  var candidateCount = probeTargets.length;
  final directScanned = await _probeServers(
    client,
    probeTargets,
    timeout: _fastProbeTimeout,
  );
  _mergeDiscoveredServers(resultsByKey, directScanned);

  final announcements = await announcementsFuture;
  for (final announcement in announcements) {
    final server = DiscoveredServer(
      endpoint: ServerEndpoint(
        host: announcement.host,
        port: announcement.httpPort,
        baseUrl: 'http://${announcement.host}:${announcement.httpPort}',
      ),
      handshake: ServerHandshake(
        serverName: announcement.serverName,
        displayName: announcement.displayName,
        role: announcement.role,
        serverRef: announcement.serverRef,
      ),
      latencyMs: announcement.latencyMs,
    );
    _mergeDiscoveredServer(resultsByKey, server);
  }

  if (resultsByKey.isEmpty) {
    final bonjourServers = await bonjourServersFuture;
    _mergeDiscoveredServers(resultsByKey, bonjourServers);
  }

  if (_enableAutomaticSubnetSweep && resultsByKey.isEmpty) {
    final subnetHosts = await _loadSubnetCandidateHosts();
    final fallbackTargets = <ServerEndpoint>[];
    for (final host in subnetHosts) {
      final endpoint = ServerEndpoint(
        host: host,
        port: _defaultApiPort,
        baseUrl: 'http://$host:$_defaultApiPort',
      );
      if (seenBaseUrls.add(endpoint.baseUrl)) {
        fallbackTargets.add(endpoint);
      }
    }
    candidateCount += fallbackTargets.length;
    final fallbackScanned = await _probeServers(
      client,
      fallbackTargets,
      timeout: _fallbackProbeTimeout,
      concurrency: _fallbackProbeConcurrency,
    );
    _mergeDiscoveredServers(resultsByKey, fallbackScanned);
  }

  final results = resultsByKey.values.toList();

  results.sort((left, right) {
    if (preferredEndpoint != null) {
      final leftPreferred = left.endpoint.baseUrl == preferredEndpoint.baseUrl;
      final rightPreferred =
          right.endpoint.baseUrl == preferredEndpoint.baseUrl;
      if (leftPreferred != rightPreferred) {
        return leftPreferred ? -1 : 1;
      }
    }
    final latencyCmp = left.latencyMs.compareTo(right.latencyMs);
    if (latencyCmp != 0) {
      return latencyCmp;
    }
    return left.endpoint.baseUrl.compareTo(right.endpoint.baseUrl);
  });

  return DiscoveryResult(servers: results, candidateCount: candidateCount);
}

List<ServerEndpoint> _buildDirectProbeTargets({
  required List<String> candidates,
  ServerEndpoint? preferredEndpoint,
  ServerEndpoint? configuredEndpoint,
}) {
  final probeTargets = <ServerEndpoint>[];
  final seenBaseUrls = <String>{};

  void addTarget(ServerEndpoint endpoint) {
    if (seenBaseUrls.add(endpoint.baseUrl)) {
      probeTargets.add(endpoint);
    }
  }

  void addLikelyTargets(String host, {int? preferredPort}) {
    final ports = <int>{};
    if (preferredPort != null) {
      ports.add(preferredPort);
    }
    ports.addAll(_directProbePorts);
    for (final port in ports) {
      addTarget(
        ServerEndpoint(host: host, port: port, baseUrl: 'http://$host:$port'),
      );
    }
  }

  if (preferredEndpoint != null &&
      !_shouldSkipDiscoveryHost(preferredEndpoint.host)) {
    addLikelyTargets(
      preferredEndpoint.host,
      preferredPort: preferredEndpoint.port,
    );
  }
  if (configuredEndpoint != null &&
      !_shouldSkipDiscoveryHost(configuredEndpoint.host)) {
    addLikelyTargets(
      configuredEndpoint.host,
      preferredPort: configuredEndpoint.port,
    );
  }
  for (final host in candidates) {
    if (_shouldSkipDiscoveryHost(host)) {
      continue;
    }
    addLikelyTargets(host);
  }

  return probeTargets;
}

Future<List<String>> _loadCandidateHosts() async {
  try {
    return await network_candidates.collectCandidateHosts();
  } catch (_) {
    return const ['gscale.local'];
  }
}

Future<List<String>> _loadSubnetCandidateHosts() async {
  try {
    return await network_candidates.collectSubnetCandidateHosts();
  } catch (_) {
    return const [];
  }
}

Future<List<network_candidates.DiscoveryAnnouncement>>
    _loadDiscoveryAnnouncements() async {
  try {
    return await network_candidates.discoverAnnouncements(
      port: _discoveryPort,
      timeout: _udpDiscoveryTimeout,
    );
  } catch (_) {
    return const <network_candidates.DiscoveryAnnouncement>[];
  }
}

void _mergeDiscoveredServers(
  Map<String, DiscoveredServer> resultsByKey,
  Iterable<DiscoveredServer> servers,
) {
  for (final server in servers) {
    _mergeDiscoveredServer(resultsByKey, server);
  }
}

void _mergeDiscoveredServer(
  Map<String, DiscoveredServer> resultsByKey,
  DiscoveredServer server,
) {
  final existing = resultsByKey[server.discoveryKey];
  if (existing == null || server.latencyMs < existing.latencyMs) {
    resultsByKey[server.discoveryKey] = server;
  }
}

Future<List<DiscoveredServer>> _probeServers(
  http.Client client,
  List<ServerEndpoint> endpoints, {
  Duration timeout = _fastProbeTimeout,
  int concurrency = 12,
}) async {
  if (endpoints.isEmpty) {
    return const [];
  }

  final results = <DiscoveredServer>[];
  var nextIndex = 0;
  final workerCount =
      endpoints.length < concurrency ? endpoints.length : concurrency;

  Future<void> worker() async {
    while (nextIndex < endpoints.length) {
      final endpoint = endpoints[nextIndex++];
      final server = await probeServer(client, endpoint, timeout: timeout);
      if (server != null) {
        results.add(server);
      }
    }
  }

  await Future.wait(List.generate(workerCount, (_) => worker()));
  return results;
}

Future<DiscoveredServer?> probeServer(
  http.Client client,
  ServerEndpoint endpoint, {
  Duration timeout = _fastProbeTimeout,
}) async {
  final stopwatch = Stopwatch()..start();
  Map<String, dynamic>? handshakeJson;

  try {
    final handshakeResponse = await client
        .get(Uri.parse('${endpoint.baseUrl}/v1/mobile/handshake'))
        .timeout(timeout);
    if (handshakeResponse.statusCode >= 200 &&
        handshakeResponse.statusCode < 300) {
      final json = jsonDecode(handshakeResponse.body) as Map<String, dynamic>;
      if (_text(json['service']) != 'mobileapi') {
        return null;
      }
      handshakeJson = json;
    }
  } catch (_) {
    // Fall through to /healthz so transient handshake hiccups don't hide the server.
  }

  if (handshakeJson != null) {
    stopwatch.stop();
    return DiscoveredServer(
      endpoint: endpoint,
      handshake: ServerHandshake.fromJson(handshakeJson),
      latencyMs: stopwatch.elapsedMilliseconds,
    );
  }

  try {
    final healthResponse = await client
        .get(Uri.parse('${endpoint.baseUrl}/healthz'))
        .timeout(timeout);
    if (healthResponse.statusCode < 200 || healthResponse.statusCode > 299) {
      return null;
    }

    final health = jsonDecode(healthResponse.body) as Map<String, dynamic>;
    if (_text(health['service']) != 'mobileapi') {
      return null;
    }

    stopwatch.stop();
    return DiscoveredServer(
      endpoint: endpoint,
      handshake: ServerHandshake(
        serverName: endpoint.host,
        displayName: 'Operator',
        role: 'operator',
        serverRef: 'legacy-healthz',
      ),
      latencyMs: stopwatch.elapsedMilliseconds,
    );
  } catch (_) {
    return null;
  }
}

Future<List<DiscoveredServer>> _loadBonjourDiscoveredServers() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
    return const [];
  }
  try {
    final raw = await _bonjourDiscoveryChannel.invokeMethod<List<Object?>>(
      'discoverBonjourServices',
      {'timeout_ms': _bonjourDiscoveryTimeout.inMilliseconds},
    );
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final out = <DiscoveredServer>[];
    for (final item in raw) {
      final json = (item as Map?)?.cast<Object?, Object?>();
      if (json == null) {
        continue;
      }
      final host = _text(json['host']);
      if (host.isEmpty || _shouldSkipDiscoveryHost(host)) {
        continue;
      }
      final port = _intValue(json['http_port']) ?? _defaultApiPort;
      out.add(
        DiscoveredServer(
          endpoint: ServerEndpoint(
            host: host,
            port: port,
            baseUrl: 'http://$host:$port',
          ),
          handshake: ServerHandshake(
            serverName: _text(json['server_name'], fallback: host),
            displayName: _text(json['display_name'], fallback: 'Operator'),
            role: _text(json['role'], fallback: 'operator'),
            serverRef: _text(json['server_ref']),
          ),
          latencyMs: _intValue(json['latency_ms']) ??
              _fallbackProbeTimeout.inMilliseconds,
        ),
      );
    }
    return out;
  } catch (_) {
    return const [];
  }
}

int? _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(_text(value));
}

ServerEndpoint? parseServerEndpoint(String raw) {
  var value = raw.trim();
  if (value.isEmpty) {
    return null;
  }
  if (!value.contains('://')) {
    value = 'http://$value';
  }

  final uri = Uri.tryParse(value);
  if (uri == null || (uri.host.isEmpty && uri.path.isEmpty)) {
    return null;
  }

  final host = uri.host.isNotEmpty ? uri.host : uri.path;
  if (host.trim().isEmpty) {
    return null;
  }

  final port = uri.hasPort ? uri.port : _defaultApiPort;
  final scheme = uri.scheme.isEmpty ? 'http' : uri.scheme;
  return ServerEndpoint(
    host: host,
    port: port,
    baseUrl: '$scheme://$host:$port',
  );
}

String _text(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) {
    return fallback;
  }
  return text;
}

class OperatorControlDraft {
  const OperatorControlDraft({
    required this.itemCode,
    required this.itemName,
    required this.warehouse,
    required this.printMode,
    required this.printer,
    required this.quantitySource,
    required this.manualQtyText,
    required this.babinaEnabled,
    required this.babinaText,
  });

  final String itemCode;
  final String itemName;
  final String warehouse;
  final String printMode;
  final String printer;
  final String quantitySource;
  final String manualQtyText;
  final bool babinaEnabled;
  final String babinaText;

  Map<String, dynamic> toJson() {
    return {
      'item_code': itemCode,
      'item_name': itemName,
      'warehouse': warehouse,
      'print_mode': printMode,
      'printer': printer,
      'quantity_source': quantitySource,
      'manual_qty_text': manualQtyText,
      'babina_enabled': babinaEnabled,
      'babina_text': babinaText,
    };
  }

  factory OperatorControlDraft.fromJson(Map<String, dynamic> json) {
    return OperatorControlDraft(
      itemCode: _text(json['item_code']),
      itemName: _text(json['item_name']),
      warehouse: _text(json['warehouse']),
      printMode: _text(json['print_mode']),
      printer: normalizePrinterChoice(_text(json['printer'])),
      quantitySource: normalizeQuantitySource(_text(json['quantity_source'])),
      manualQtyText: _text(json['manual_qty_text']),
      babinaEnabled: json['babina_enabled'] == true,
      babinaText: _text(json['babina_text']),
    );
  }
}

Future<void> saveOperatorControlDraft(OperatorControlDraft draft) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_controlDraftKey, jsonEncode(draft.toJson()));
}

Future<OperatorControlDraft> loadOperatorControlDraft() async {
  final prefs = await SharedPreferences.getInstance();
  final value = prefs.getString(_controlDraftKey);
  if (value == null || value.trim().isEmpty) {
    return const OperatorControlDraft(
      itemCode: '',
      itemName: '',
      warehouse: '',
      printMode: '',
      printer: '',
      quantitySource: '',
      manualQtyText: '',
      babinaEnabled: false,
      babinaText: '',
    );
  }

  try {
    final payload = jsonDecode(value);
    final json = (payload as Map?)?.cast<String, dynamic>();
    if (json == null) {
      return const OperatorControlDraft(
        itemCode: '',
        itemName: '',
        warehouse: '',
        printMode: '',
        printer: '',
        quantitySource: '',
        manualQtyText: '',
        babinaEnabled: false,
        babinaText: '',
      );
    }
    return OperatorControlDraft.fromJson(json);
  } catch (_) {
    return const OperatorControlDraft(
      itemCode: '',
      itemName: '',
      warehouse: '',
      printMode: '',
      printer: '',
      quantitySource: '',
      manualQtyText: '',
      babinaEnabled: false,
      babinaText: '',
    );
  }
}

Future<void> saveLastUsedServer(ServerEndpoint endpoint) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_lastServerKey, endpoint.baseUrl);
}

Future<ServerEndpoint?> loadLastUsedServer() async {
  final prefs = await SharedPreferences.getInstance();
  final value = prefs.getString(_lastServerKey);
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  final endpoint = parseServerEndpoint(value);
  if (endpoint == null || _shouldSkipDiscoveryHost(endpoint.host)) {
    await prefs.remove(_lastServerKey);
    return null;
  }
  return endpoint;
}

Future<void> saveCachedDiscoveredServers(List<DiscoveredServer> servers) async {
  final prefs = await SharedPreferences.getInstance();
  final payload = servers
      .take(8)
      .map(
        (server) => {
          'host': server.endpoint.host,
          'port': server.endpoint.port,
          'base_url': server.endpoint.baseUrl,
          'server_name': server.handshake.serverName,
          'display_name': server.handshake.displayName,
          'role': server.handshake.role,
          'server_ref': server.handshake.serverRef,
          'latency_ms': server.latencyMs,
        },
      )
      .toList(growable: false);
  await prefs.setString(_cachedServersKey, jsonEncode(payload));
}

Future<void> clearCachedDiscoveredServers() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_cachedServersKey);
}

Future<List<DiscoveredServer>> loadCachedDiscoveredServers() async {
  final prefs = await SharedPreferences.getInstance();
  final value = prefs.getString(_cachedServersKey);
  if (value == null || value.trim().isEmpty) {
    final endpoint = await loadLastUsedServer();
    if (endpoint == null) {
      return const [];
    }
    return [
      DiscoveredServer(
        endpoint: endpoint,
        handshake: ServerHandshake(
          serverName: endpoint.host,
          displayName: 'Recent server',
          role: 'operator',
          serverRef: 'cached',
        ),
        latencyMs: 1,
      ),
    ];
  }

  try {
    final payload = jsonDecode(value) as List<dynamic>;
    final out = <DiscoveredServer>[];
    for (final item in payload) {
      final json = (item as Map?)?.cast<String, dynamic>();
      if (json == null) {
        continue;
      }
      final endpoint = parseServerEndpoint(_text(json['base_url']));
      if (endpoint == null || _shouldSkipDiscoveryHost(endpoint.host)) {
        continue;
      }
      out.add(
        DiscoveredServer(
          endpoint: endpoint,
          handshake: ServerHandshake(
            serverName: _text(json['server_name'], fallback: endpoint.host),
            displayName: _text(json['display_name'], fallback: 'Operator'),
            role: _text(json['role'], fallback: 'operator'),
            serverRef: _text(json['server_ref'], fallback: 'cached'),
          ),
          latencyMs: _intValue(json['latency_ms']) ?? 1,
        ),
      );
    }
    if (out.isNotEmpty) {
      return out;
    }
  } catch (_) {
    // Ignore cache parse issues and rebuild below from last endpoint.
  }

  final endpoint = await loadLastUsedServer();
  if (endpoint == null) {
    return const [];
  }
  return [
    DiscoveredServer(
      endpoint: endpoint,
      handshake: ServerHandshake(
        serverName: endpoint.host,
        displayName: 'Recent server',
        role: 'operator',
        serverRef: 'cached',
      ),
      latencyMs: 1,
    ),
  ];
}

bool _shouldSkipDiscoveryHost(String host) {
  final normalized = host.trim().toLowerCase();
  return normalized == '127.0.0.1' ||
      normalized == 'localhost' ||
      normalized == '::1' ||
      normalized == '[::1]' ||
      normalized == '10.0.2.2';
}

String _sanitizeManualServerAddress(String raw) {
  final endpoint = parseServerEndpoint(raw);
  if (endpoint == null || _shouldSkipDiscoveryHost(endpoint.host)) {
    return _defaultWifiServerAddress;
  }
  return endpoint.baseUrl;
}
