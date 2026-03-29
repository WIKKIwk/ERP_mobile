import '../api/mobile_api.dart';
import '../localization/app_localizations.dart';
import '../security/security_controller.dart';
import 'm3_confirm_dialog.dart';
import 'package:flutter/material.dart';

Future<void> showLogoutPrompt(BuildContext context) async {
  final confirmed = await showM3ConfirmDialog(
    context: context,
    title: context.l10n.logoutTitle,
    message: context.l10n.logoutPrompt,
    cancelLabel: context.l10n.no,
    confirmLabel: context.l10n.yes,
    blurBackground: true,
  );
  if (confirmed != true || !context.mounted) {
    return;
  }

  await MobileApi.instance.logout();
  await SecurityController.instance.clearForLogout();
  if (!context.mounted) {
    return;
  }
  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
}
