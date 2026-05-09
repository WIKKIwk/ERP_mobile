import 'dart:convert';

import 'package:erpnext_stock_mobile/src/features/werka/presentation/werka_archive_batch_qr.dart';
import 'package:erpnext_stock_mobile/src/features/werka/presentation/werka_archive_batch_qr_lookup_screen.dart';
import 'package:erpnext_stock_mobile/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses legacy archive batch QR payload', () {
    final raw = _archiveUrl([
      'ARCHIVE',
      'sess-1',
      'Akis mega 2-3 kg paket',
      '3.6',
      '01 May 2026 15:23',
    ]);

    final parsed = WerkaArchiveBatchQrPayload.tryParse(raw);

    expect(parsed, isNotNull);
    expect(parsed!.sessionID, 'sess-1');
    expect(parsed.itemName, 'Akis mega 2-3 kg paket');
    expect(parsed.qty, 3.6);
    expect(parsed.nettoQty, 3.6);
    expect(parsed.bruttoQty, 3.6);
    expect(parsed.batchTime, '01 May 2026 15:23');
  });

  test('parses separated brutto and netto archive batch QR payload', () {
    final raw = _archiveUrl([
      'ARCHIVE',
      'sess-2',
      'Akis mega 2-3 kg paket',
      '4.1',
      '3.6',
      '01 May 2026 15:23',
    ]);

    final parsed = WerkaArchiveBatchQrPayload.tryParse(raw);

    expect(parsed, isNotNull);
    expect(parsed!.sessionID, 'sess-2');
    expect(parsed.qty, 3.6);
    expect(parsed.nettoQty, 3.6);
    expect(parsed.bruttoQty, 4.1);
    expect(parsed.batchTime, '01 May 2026 15:23');
  });

  test('batch QR item resolution requires exact item match', () {
    final options = [
      const CustomerItemOption(
        customerRef: 'CUST-1',
        customerName: 'Customer',
        customerPhone: '',
        itemCode: 'Adras aboy 4kg paket',
        itemName: 'Adras aboy 4kg paket',
        uom: 'Kg',
        warehouse: 'Stores - A',
      ),
      const CustomerItemOption(
        customerRef: 'CUST-2',
        customerName: 'Customer 2',
        customerPhone: '',
        itemCode: 'Adras aboy 3kg paekt',
        itemName: 'Adras aboy 3kg paekt',
        uom: 'Kg',
        warehouse: 'Stores - A',
      ),
    ];

    final exact = resolveExactArchiveBatchItemOption(
      'Adras aboy 3kg paekt',
      options,
    );
    final missing = resolveExactArchiveBatchItemOption(
      'Adras aboy 2kg paekt',
      options,
    );

    expect(exact?.itemCode, 'Adras aboy 3kg paekt');
    expect(missing, isNull);
  });

  test('batch QR default customer prefers primary customer', () {
    const option = CustomerItemOption(
      customerRef: 'saidamin',
      customerName: 'saidamin',
      customerPhone: '',
      itemCode: 'Adras aboy 3kg paekt',
      itemName: 'Adras aboy 3kg paekt',
      uom: 'Kg',
      warehouse: 'Stores - A',
    );
    const customers = [
      CustomerDirectoryEntry(ref: 'saidamin', name: 'saidamin', phone: ''),
      CustomerDirectoryEntry(ref: 'umar-oboy', name: 'Umar Oboy', phone: ''),
    ];

    final resolved = resolveArchiveBatchDefaultCustomer(option, customers);

    expect(resolved.ref, 'umar-oboy');
  });

  test('batch QR default customer falls back to item option', () {
    const option = CustomerItemOption(
      customerRef: 'fallback-customer',
      customerName: 'Fallback Customer',
      customerPhone: '+998',
      itemCode: 'Adras aboy 3kg paekt',
      itemName: 'Adras aboy 3kg paekt',
      uom: 'Kg',
      warehouse: 'Stores - A',
    );

    final resolved = resolveArchiveBatchDefaultCustomer(
      option,
      const <CustomerDirectoryEntry>[],
    );

    expect(resolved.ref, 'fallback-customer');
    expect(resolved.name, 'Fallback Customer');
  });
}

String _archiveUrl(List<String> lines) {
  final encoded = base64Url.encode(utf8.encode(lines.join('\n'))).replaceAll(
        '=',
        '',
      );
  return 'https://scan.wspace.sbs/A/$encoded';
}
