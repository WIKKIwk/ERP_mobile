import 'package:erpnext_stock_mobile/src/core/theme/app_theme.dart';
import 'package:erpnext_stock_mobile/src/core/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('earthy light theme swaps page and card surfaces', () {
    final theme = AppTheme.light(AppThemeVariant.earthy);
    final scheme = theme.colorScheme;

    expect(theme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, const Color(0xFFDBCEA5));
    expect(theme.cardColor, const Color(0xFFECE7D1));
    expect(scheme.surfaceContainerHighest, const Color(0xFFECE7D1));
    expect(theme.appBarTheme.backgroundColor, const Color(0xFFC9B987));
    expect(theme.navigationBarTheme.backgroundColor, const Color(0xFFC9B987));
  });
}
