import 'package:erpnext_stock_mobile/src/app/app_router.dart';
import 'package:erpnext_stock_mobile/src/core/api/mobile_api.dart';
import 'package:erpnext_stock_mobile/src/core/localization/app_localizations.dart';
import 'package:erpnext_stock_mobile/src/features/shared/models/app_models.dart';
import 'package:erpnext_stock_mobile/src/features/shared/models/stock_entry_lookup.dart';
import 'package:erpnext_stock_mobile/src/features/werka/presentation/werka_stock_entry_lookup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('QR result submit preserves stock entry source metadata',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = _FakeStockEntryLookupApi(
      lookup: _lookup(
        scannedBarcode: 'SCANNED-QR',
        entryBarcode: 'ENTRY-BARCODE',
      ),
      customers: const [
        CustomerDirectoryEntry(ref: 'saidamin', name: 'saidamin', phone: ''),
        CustomerDirectoryEntry(ref: 'umar-oboy', name: 'Umar Oboy', phone: ''),
      ],
    );

    await tester.pumpWidget(
      _wrap(
        WerkaStockEntryLookupScreen(
          args: const WerkaStockEntryLookupArgs(
            scannedBarcode: 'SCANNED-QR',
            rawValue: 'https://scan.wspace.sbs/L/ACCORD/item/SCANNED-QR',
          ),
          api: api,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Umar Oboy'), findsWidgets);
    expect(find.text('Customerga jo‘natish'), findsOneWidget);

    await tester.tap(find.text('Customerga jo‘natish'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(api.createCalls, 1);
    expect(api.lastCustomerRef, 'umar-oboy');
    expect(api.lastItemCode, 'Adras aboy 3kg paekt');
    expect(api.lastQty, 6.4);
    expect(api.lastSourceBarcode, 'ENTRY-BARCODE');
    expect(api.lastSourceStockEntryName, 'MAT-STE-2026-00572');
    expect(api.lastSourceLineIndex, 3);
  });

  testWidgets('QR result submit falls back to scanned barcode for source',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = _FakeStockEntryLookupApi(
      lookup: _lookup(
        scannedBarcode: 'SCANNED-FALLBACK',
        entryBarcode: '',
      ),
      customers: const [
        CustomerDirectoryEntry(ref: 'umar-oboy', name: 'Umar Oboy', phone: ''),
      ],
    );

    await tester.pumpWidget(
      _wrap(
        WerkaStockEntryLookupScreen(
          args: const WerkaStockEntryLookupArgs(
            scannedBarcode: 'SCANNED-FALLBACK',
          ),
          api: api,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Customerga jo‘natish'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(api.createCalls, 1);
    expect(api.lastSourceBarcode, 'SCANNED-FALLBACK');
    expect(api.lastSourceStockEntryName, 'MAT-STE-2026-00572');
    expect(api.lastSourceLineIndex, 3);
  });

  testWidgets('QR result duplicate source error is shown to user',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = _FakeStockEntryLookupApi(
      lookup: _lookup(
        scannedBarcode: 'SCANNED-DUP',
        entryBarcode: 'ENTRY-DUP',
      ),
      customers: const [
        CustomerDirectoryEntry(ref: 'umar-oboy', name: 'Umar Oboy', phone: ''),
      ],
      duplicateOnCreate: true,
    );

    await tester.pumpWidget(
      _wrap(
        WerkaStockEntryLookupScreen(
          args: const WerkaStockEntryLookupArgs(scannedBarcode: 'SCANNED-DUP'),
          api: api,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Customerga jo‘natish'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(api.createCalls, 1);
    expect(find.text('Bu QR oldin customerga jo‘natilgan.'), findsOneWidget);
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('uz'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    onGenerateRoute: AppRouter.onGenerateRoute,
    home: child,
  );
}

StockEntryBarcodeLookup _lookup({
  required String scannedBarcode,
  required String entryBarcode,
}) {
  return StockEntryBarcodeLookup(
    barcode: scannedBarcode,
    count: 1,
    entries: [
      StockEntryBarcodeEntry(
        stockEntryName: 'MAT-STE-2026-00572',
        stockEntryType: 'Material Receipt',
        docStatus: 1,
        status: 'Submitted',
        company: 'Accord',
        postingDate: '2026-05-07',
        postingTime: '12:24:00',
        creation: '2026-05-07 12:24:00',
        modified: '2026-05-07 12:24:00',
        remarks: '',
        lineIndex: 3,
        itemCode: 'Adras aboy 3kg paekt',
        itemName: 'Adras aboy 3kg paekt',
        qty: 6.4,
        uom: 'Kg',
        stockUOM: 'Kg',
        barcode: entryBarcode,
        sourceWarehouse: '',
        targetWarehouse: 'Stores - A',
      ),
    ],
  );
}

class _FakeStockEntryLookupApi implements WerkaStockEntryLookupApi {
  _FakeStockEntryLookupApi({
    required this.lookup,
    required this.customers,
    this.duplicateOnCreate = false,
  });

  final StockEntryBarcodeLookup lookup;
  final List<CustomerDirectoryEntry> customers;
  final bool duplicateOnCreate;
  int createCalls = 0;
  String lastCustomerRef = '';
  String lastItemCode = '';
  double lastQty = 0;
  String lastSourceBarcode = '';
  String lastSourceStockEntryName = '';
  int lastSourceLineIndex = 0;

  @override
  Future<StockEntryBarcodeLookup> stockEntryLookup({
    required String barcode,
  }) async {
    return lookup;
  }

  @override
  Future<List<CustomerDirectoryEntry>> customersForItem({
    required String itemCode,
    required String itemName,
    String query = '',
    required int limit,
    int offset = 0,
  }) async {
    return customers;
  }

  @override
  Future<WerkaCustomerIssueRecord> createCustomerIssue({
    required String customerRef,
    required String itemCode,
    required double qty,
    required String sourceBarcode,
    required String sourceStockEntryName,
    required int sourceLineIndex,
  }) async {
    createCalls += 1;
    lastCustomerRef = customerRef;
    lastItemCode = itemCode;
    lastQty = qty;
    lastSourceBarcode = sourceBarcode;
    lastSourceStockEntryName = sourceStockEntryName;
    lastSourceLineIndex = sourceLineIndex;
    if (duplicateOnCreate) {
      throw const MobileApiException(
        code: 'duplicate_customer_issue_source',
        message: 'Duplicate customer issue source',
        statusCode: 409,
      );
    }
    return WerkaCustomerIssueRecord(
      entryID: 'DN-TEST-1',
      customerRef: customerRef,
      customerName: customerRef,
      itemCode: itemCode,
      itemName: itemCode,
      uom: 'Kg',
      qty: qty,
      createdLabel: 'now',
    );
  }
}
