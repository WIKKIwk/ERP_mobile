import 'package:device_preview/device_preview.dart';
import 'src/app/app.dart';
import 'src/core/app_preview.dart';
import 'src/core/notifications/local_notification_service.dart';
import 'src/core/security/security_controller.dart';
import 'src/core/session/app_session.dart';
import 'src/core/theme/theme_controller.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalNotificationService.instance.initialize();
  await AppSession.instance.load();
  await SecurityController.instance.load();
  await ThemeController.instance.load();
  runApp(
    DevicePreview(
      enabled: AppPreview.enabled,
      builder: (_) => const ErpnextStockMobileApp(),
    ),
  );
}
