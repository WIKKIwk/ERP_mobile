import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/stock_entry_lookup.dart';
import 'werka_stock_entry_lookup_screen.dart';

class WerkaStockEntryQrScanScreen extends StatefulWidget {
  const WerkaStockEntryQrScanScreen({super.key});

  @override
  State<WerkaStockEntryQrScanScreen> createState() =>
      _WerkaStockEntryQrScanScreenState();
}

class _WerkaStockEntryQrScanScreenState
    extends State<WerkaStockEntryQrScanScreen> {
  final bool _scannerSupported = _supportsLiveScanner;
  MobileScannerController? _controller;
  bool _processing = false;
  String _statusText = 'QR kodni ramkaga keltiring';

  @override
  void initState() {
    super.initState();
    if (_scannerSupported) {
      _controller = MobileScannerController(
        autoStart: false,
        facing: CameraFacing.back,
        detectionSpeed: DetectionSpeed.noDuplicates,
        formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_startScanner());
      });
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) {
      unawaited(controller.dispose());
    }
    super.dispose();
  }

  static bool get _supportsLiveScanner {
    if (kIsWeb) {
      return true;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  Future<void> _startScanner() async {
    final controller = _controller;
    if (!mounted || controller == null) {
      return;
    }
    try {
      await controller.start();
      if (!mounted) {
        return;
      }
      setState(() {
        _processing = false;
        _statusText = 'QR kodni ramkaga keltiring';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _processing = false;
        _statusText = 'Kamera ochilmadi';
      });
    }
  }

  Future<void> _stopScanner() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    try {
      await controller.stop();
    } catch (_) {
      // Best-effort stop.
    }
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (_processing) {
      return;
    }

    final rawValue = _firstBarcodeValue(capture);
    final lookupBarcode = _extractLookupBarcode(rawValue);
    if (lookupBarcode == null || lookupBarcode.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() => _statusText = 'Bu QR stock entry uchun emas');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu QR stock entry uchun emas.')),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _processing = true;
      _statusText = 'Barcode tekshirilmoqda...';
    });
    await _stopScanner();

    try {
      if (!mounted) {
        return;
      }
      await Navigator.of(context).pushReplacementNamed(
        AppRoutes.werkaStockEntryLookup,
        arguments: WerkaStockEntryLookupArgs(
          scannedBarcode: lookupBarcode,
          rawValue: rawValue,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = _messageForError(error);
      setState(() {
        _processing = false;
        _statusText = message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      await _startScanner();
    }
  }

  String _messageForError(Object error) {
    if (error is MobileApiException) {
      return switch (error.code) {
        'stock_entry_not_found' => 'Bu barcode bo‘yicha stock entry topilmadi.',
        'direct_db_lookup_unavailable' =>
          'Barcode lookup vaqtincha ishlamayapti.',
        'stock_entry_lookup_bad_request' => 'Barcode bo‘sh yoki noto‘g‘ri.',
        _ => error.message.isEmpty
            ? 'Barcode tekshirishda xatolik.'
            : error.message,
      };
    }
    return 'Barcode tekshirishda xatolik.';
  }

  String? _extractLookupBarcode(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.pathSegments.isNotEmpty) {
      final queryBarcode =
          (uri.queryParameters['barcode'] ?? uri.queryParameters['epc'] ?? '')
              .trim();
      if (queryBarcode.isNotEmpty) {
        return queryBarcode;
      }

      final segments = uri.pathSegments.where((segment) {
        return segment.trim().isNotEmpty;
      }).toList(growable: false);
      if (segments.isEmpty) {
        return null;
      }

      if (segments.first.trim().toUpperCase() == 'A') {
        return null;
      }

      return segments.last.trim();
    }

    if (trimmed.contains('/A/')) {
      return null;
    }

    return trimmed;
  }

  String _firstBarcodeValue(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue?.trim() ?? '';
      if (rawValue.isNotEmpty) {
        return rawValue;
      }
      final displayValue = barcode.displayValue?.trim() ?? '';
      if (displayValue.isNotEmpty) {
        return displayValue;
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final backgroundColor =
        _scannerSupported ? Colors.black : scheme.surfaceContainerLow;
    final appBarTheme = theme.appBarTheme.copyWith(
      backgroundColor: backgroundColor,
      foregroundColor: _scannerSupported ? Colors.white : scheme.onSurface,
      titleTextStyle: theme.textTheme.titleLarge?.copyWith(
        color: _scannerSupported ? Colors.white : scheme.onSurface,
        fontWeight: FontWeight.w800,
      ),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    );

    return Theme(
      data: theme.copyWith(appBarTheme: appBarTheme),
      child: AppShell(
        title: 'QR scan',
        subtitle: '',
        nativeTopBar: true,
        nativeTitleTextStyle: theme.textTheme.titleLarge?.copyWith(
          color: _scannerSupported ? Colors.white : scheme.onSurface,
          fontWeight: FontWeight.w800,
          fontSize: 24,
        ),
        backgroundColor: backgroundColor,
        contentPadding: EdgeInsets.zero,
        child: _scannerSupported
            ? Stack(
                children: [
                  Positioned.fill(
                    child: MobileScanner(
                      controller: _controller,
                      fit: BoxFit.cover,
                      useAppLifecycleState: true,
                      onDetect: _handleDetect,
                      errorBuilder: (context, error) {
                        return _ScannerErrorView(
                          message:
                              'Kamera ochilmadi. Ruxsatlarni tekshirib qayta urinib ko‘ring.',
                          onRetry: _startScanner,
                        );
                      },
                      placeholderBuilder: (context) {
                        return const ColoredBox(
                          color: Colors.black,
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.18),
                              Colors.black.withValues(alpha: 0.06),
                              Colors.black.withValues(alpha: 0.34),
                            ],
                            stops: const [0.0, 0.52, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 68),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final double frameWidth =
                                    (constraints.maxWidth * 0.78).clamp(
                                  220.0,
                                  320.0,
                                );
                                final double frameHeight =
                                    (constraints.maxHeight * 0.42).clamp(
                                  220.0,
                                  340.0,
                                );
                                return Center(
                                  child: Container(
                                    width: frameWidth,
                                    height: frameHeight,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.88,
                                        ),
                                        width: 2.5,
                                      ),
                                      color:
                                          Colors.white.withValues(alpha: 0.04),
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: 18,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withValues(
                                            alpha: 0.78,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 18),
                          _ScanStatusPill(
                            text: _statusText,
                            isBusy: _processing,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : _UnsupportedScannerView(
                onBack: () => Navigator.of(context).maybePop(),
              ),
      ),
    );
  }
}

class _ScanStatusPill extends StatelessWidget {
  const _ScanStatusPill({
    required this.text,
    required this.isBusy,
  });

  final String text;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: Card.filled(
        key: ValueKey<String>(text),
        margin: EdgeInsets.zero,
        color: Colors.white.withValues(alpha: 0.14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.18),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isBusy) ...[
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
              ] else ...[
                Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 18,
                  color: scheme.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
              ],
              Flexible(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannerErrorView extends StatelessWidget {
  const _ScannerErrorView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerLow,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Card.filled(
              margin: EdgeInsets.zero,
              color: scheme.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.no_photography_rounded,
                      size: 44,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Kamera xatosi',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        unawaited(onRetry());
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Qayta urinish'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UnsupportedScannerView extends StatelessWidget {
  const _UnsupportedScannerView({
    required this.onBack,
  });

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card.filled(
            margin: EdgeInsets.zero,
            color: scheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 72,
                    width: 72,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 34,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'QR scan faqat mobil qurilmalarda ishlaydi',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bu ekranda kamera ochish Android yoki iOS qurilmada ishlaydi.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Ortga'),
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
