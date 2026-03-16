import 'package:erpnext_stock_mobile/src/features/shared/models/app_models.dart';
import 'package:erpnext_stock_mobile/src/features/werka/presentation/werka_recent_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('werka recent renders repeat cards', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WerkaRecentScreen(
          loader: () async => const [
            DispatchRecord(
              id: 'MAT-PRE-1',
              supplierRef: 'comfi',
              supplierName: 'comfi',
              itemCode: 'chers001',
              itemName: 'chers',
              uom: 'Nos',
              sentQty: 5,
              acceptedQty: 5,
              amount: 0,
              currency: '',
              note: '',
              eventType: 'customer_delivery_confirmed',
              highlight: 'Customer mahsulotni qabul qildi',
              status: DispatchStatus.accepted,
              createdLabel: '2026-03-16',
            ),
          ],
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('chers001'), findsOneWidget);
    expect(find.text('Yana jo‘natish'), findsOneWidget);
  });

  testWidgets('werka recent renders with semantics enabled', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: WerkaRecentScreen(
          loader: () async => const [
            DispatchRecord(
              id: 'MAT-PRE-2',
              supplierRef: 'stocker',
              supplierName: 'stocker',
              itemCode: 'nachos003',
              itemName: 'nachos',
              uom: 'Kg',
              sentQty: 1,
              acceptedQty: 0,
              amount: 0,
              currency: '',
              note: '',
              eventType: '',
              highlight: '',
              status: DispatchStatus.pending,
              createdLabel: '2026-03-16',
            ),
          ],
        ),
      ),
    );

    await tester.pump();

    expect(find.text('nachos003'), findsOneWidget);
    expect(find.text('Yana qayd qilish'), findsOneWidget);
    semantics.dispose();
  });
}
