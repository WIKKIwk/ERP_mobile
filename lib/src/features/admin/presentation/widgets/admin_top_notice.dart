import 'package:flutter/material.dart';

ScaffoldFeatureController<MaterialBanner, MaterialBannerClosedReason>?
    _currentAdminTopNotice;

void showAdminTopNotice(
  BuildContext context,
  String message, {
  IconData? icon,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    return;
  }
  messenger.hideCurrentMaterialBanner();

  final controller = messenger.showMaterialBanner(
    MaterialBanner(
      elevation: 0,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      dividerColor: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      leading: icon == null ? null : Icon(icon),
      content: Text(message),
      contentTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
      actions: const [SizedBox.shrink()],
      minActionBarHeight: 0,
    ),
  );
  _currentAdminTopNotice = controller;
  Future<void>.delayed(const Duration(milliseconds: 1850), () {
    if (_currentAdminTopNotice == controller) {
      messenger.hideCurrentMaterialBanner();
      _currentAdminTopNotice = null;
    }
  });
}
