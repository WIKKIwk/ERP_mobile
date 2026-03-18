import 'package:device_preview/device_preview.dart';
import 'src/app/app.dart';
import 'src/core/app_preview.dart';
import 'src/core/localization/locale_controller.dart';
import 'src/core/notifications/local_notification_service.dart';
import 'src/core/notifications/push_messaging_service.dart';
import 'src/core/notifications/notification_unread_store.dart';
import 'src/core/security/security_controller.dart';
import 'src/core/session/app_session.dart';
import 'src/core/theme/theme_controller.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalNotificationService.instance.initialize();
  await AppSession.instance.load();
  await NotificationUnreadStore.instance.load();
  await SecurityController.instance.load();
  await ThemeController.instance.load();
  await LocaleController.instance.load();
  runApp(
    DevicePreview(
      enabled: AppPreview.enabled,
      builder: (_) => const ErpnextStockMobileApp(),
    ),
  );
  if (!kIsWeb) {
    unawaited(PushMessagingService.instance.initialize());
  }
}
