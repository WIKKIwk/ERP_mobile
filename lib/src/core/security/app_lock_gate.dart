import 'dart:ui';

import 'device_permissions_bootstrap.dart';
import 'security_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLockGate extends StatefulWidget {
  const AppLockGate({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> {
  bool _biometricAttempted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DevicePermissionsBootstrap.instance.runOnce();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SecurityController.instance,
      builder: (context, _) {
        if (!SecurityController.instance.locked) {
          _biometricAttempted = false;
          return widget.child;
        }

        if (!_biometricAttempted &&
            SecurityController.instance.biometricEnabledForCurrentUser) {
          _biometricAttempted = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            SecurityController.instance.unlockWithBiometric();
          });
        }

        return Stack(
          children: [
            widget.child,
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  color: const Color(0xAA000000),
                ),
              ),
            ),
            const _PinUnlockOverlay(),
          ],
        );
      },
    );
  }
}

class _PinUnlockOverlay extends StatefulWidget {
  const _PinUnlockOverlay();

  @override
  State<_PinUnlockOverlay> createState() => _PinUnlockOverlayState();
}

class _PinUnlockOverlayState extends State<_PinUnlockOverlay> {
  final TextEditingController _pinController = TextEditingController();
  String? _error;
  bool _unlocking = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    setState(() {
      _unlocking = true;
      _error = null;
    });
    try {
      final ok = await SecurityController.instance
          .unlockWithPin(_pinController.text.trim());
      if (!ok && mounted) {
        setState(() {
          _pinController.clear();
          _error = 'PIN noto‘g‘ri';
        });
      }
      if (ok) {
        _pinController.clear();
      }
    } finally {
      if (mounted) {
        setState(() {
          _unlocking = false;
        });
      }
    }
  }

  Future<void> _unlockWithBiometric() async {
    setState(() {
      _unlocking = true;
      _error = null;
    });
    try {
      final ok = await SecurityController.instance.unlockWithBiometric();
      if (!ok && mounted) {
        setState(() {
          _error = 'Biometrik tasdiq bajarilmadi';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _unlocking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF050505),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFF2A2A2A)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'App qulfi',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '4 xonali PIN kiriting',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _pinController,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        enableSuggestions: false,
                        autocorrect: false,
                        autofillHints: null,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        textInputAction: TextInputAction.done,
                        autofocus: true,
                        onSubmitted: (_) => _unlock(),
                        decoration: const InputDecoration(
                          labelText: 'PIN',
                          counterText: '',
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _unlocking ? null : _unlock,
                          child:
                              Text(_unlocking ? 'Tekshirilmoqda...' : 'Ochish'),
                        ),
                      ),
                      if (SecurityController
                          .instance.biometricEnabledForCurrentUser) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed:
                                _unlocking ? null : _unlockWithBiometric,
                            child: const Text('Face ID / Fingerprint'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
