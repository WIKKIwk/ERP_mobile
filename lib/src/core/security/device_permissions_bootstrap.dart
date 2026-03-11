import '../notifications/local_notification_service.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DevicePermissionsBootstrap {
  DevicePermissionsBootstrap._();

  static final DevicePermissionsBootstrap instance =
      DevicePermissionsBootstrap._();
  static const String _biometricPromptedKey = 'device_biometric_prompted';
  static const String _notificationPromptedKey = 'device_notification_prompted';

  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _running = false;

  Future<void> runOnce() async {
    if (_running) {
      return;
    }
    _running = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool biometricPrompted =
          prefs.getBool(_biometricPromptedKey) ?? false;

      if (!biometricPrompted) {
        await _requestBiometricAccess();
        await prefs.setBool(_biometricPromptedKey, true);
      }
      final bool notificationPrompted =
          prefs.getBool(_notificationPromptedKey) ?? false;
      if (!notificationPrompted) {
        await LocalNotificationService.instance.requestPermission();
        await prefs.setBool(_notificationPromptedKey, true);
      }
    } catch (_) {
      // Best-effort startup permissions bootstrap.
    } finally {
      _running = false;
    }
  }

  Future<void> _requestBiometricAccess() async {
    try {
      final bool supported = await _localAuth.isDeviceSupported();
      final bool canCheck = await _localAuth.canCheckBiometrics;
      final biometrics = await _localAuth.getAvailableBiometrics();
      if (!supported || !canCheck || biometrics.isEmpty) {
        return;
      }
      await _localAuth.authenticate(
        localizedReason:
            'Accord ilovasida Face ID yoki fingerprint imkoniyatini tayyorlash',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      // Some devices expose biometrics but do not support prompting here.
    }
  }
}
