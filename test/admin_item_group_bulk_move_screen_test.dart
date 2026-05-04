import 'package:erpnext_stock_mobile/src/features/admin/presentation/admin_item_group_bulk_move_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:erpnext_stock_mobile/src/core/localization/app_localizations.dart';

void main() {
  testWidgets(
      'admin item group bulk move screen builds without semantics errors',
      (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminItemGroupBulkMoveScreen(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text("Mahsulot group ko'chirish"), findsOneWidget);
    expect(find.text('Uy'), findsOneWidget);
    expect(find.text('Foydalanuvchilar'), findsOneWidget);
    expect(find.text('Faoliyat'), findsOneWidget);
    expect(tester.takeException(), isNull);

    semantics.dispose();
  });
}
