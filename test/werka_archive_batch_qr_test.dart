import 'dart:convert';

import 'package:erpnext_stock_mobile/src/features/werka/presentation/werka_archive_batch_qr.dart';
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
}

String _archiveUrl(List<String> lines) {
  final encoded = base64Url.encode(utf8.encode(lines.join('\n'))).replaceAll(
        '=',
        '',
      );
  return 'https://scan.wspace.sbs/A/$encoded';
}
