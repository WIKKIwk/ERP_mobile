import 'package:erpnext_stock_mobile/src/core/api/mobile_api.dart';
import 'package:erpnext_stock_mobile/src/features/gscale/gscale_mobile_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('material receipt print request matches RS contract', () {
    const request = GScaleMaterialReceiptPrintRequest(
      driverUrl: ' http://127.0.0.1:39117 ',
      itemCode: ' ITEM-1 ',
      itemName: ' Green Tea ',
      warehouse: ' Stores - A ',
      printer: 'zebra',
      printMode: 'rfid',
      grossQty: 2.5,
      tareEnabled: true,
      tareKg: 0.78,
    );

    expect(request.toJson(), {
      'driver_url': 'http://127.0.0.1:39117',
      'item_code': 'ITEM-1',
      'item_name': 'Green Tea',
      'warehouse': 'Stores - A',
      'printer': 'zebra',
      'print_mode': 'rfid',
      'gross_qty': 2.5,
      'unit': 'kg',
      'tare_enabled': true,
      'tare_kg': 0.78,
    });
  });

  test('material receipt print response reads RS result', () {
    final response = GScaleMaterialReceiptPrintResponse.fromJson({
      'ok': true,
      'status': 'submitted',
      'draft_name': 'MAT-STE-001',
      'epc': '000000000000000000000001',
      'item_code': 'ITEM-1',
      'item_name': 'Green Tea',
      'warehouse': 'Stores - A',
      'qty': 1.72,
      'net_qty': 1.72,
      'gross_qty': 2.5,
      'unit': 'kg',
      'printer': 'zebra',
      'print_mode': 'rfid',
      'printer_status': 'OK',
    });

    expect(response.ok, isTrue);
    expect(response.status, 'submitted');
    expect(response.draftName, 'MAT-STE-001');
    expect(response.netQty, 1.72);
    expect(response.grossQty, 2.5);
    expect(response.printer, 'zebra');
  });

  test('rps batch start request matches RS contract', () {
    const request = GScaleRpsBatchStartRequest(
      clientBatchId: ' batch-1 ',
      driverUrl: ' http://127.0.0.1:39117/ ',
      itemCode: ' ITEM-1 ',
      itemName: ' Green Tea ',
      warehouse: ' Stores - A ',
      printer: 'zebra',
      printMode: 'rfid',
      quantitySource: 'manual',
      manualQtyKg: 2.5,
      tareEnabled: true,
      tareKg: 0.78,
    );

    expect(request.toJson(), {
      'client_batch_id': 'batch-1',
      'driver_url': 'http://127.0.0.1:39117',
      'item_code': 'ITEM-1',
      'item_name': 'Green Tea',
      'warehouse': 'Stores - A',
      'printer': 'zebra',
      'print_mode': 'rfid',
      'quantity_source': 'manual',
      'manual_qty_kg': 2.5,
      'tare_enabled': true,
      'tare_kg': 0.78,
    });
  });

  test('rps batch response reads active RS session', () {
    final response = GScaleRpsBatchResponse.fromJson({
      'ok': true,
      'batch': {
        'id': 'batch-1',
        'active': true,
        'owner_key': 'werka:+998901234567',
        'driver_url': 'http://127.0.0.1:39117',
        'item_code': 'ITEM-1',
        'item_name': 'Green Tea',
        'warehouse': 'Stores - A',
        'printer': 'zebra',
        'print_mode': 'rfid',
        'quantity_source': 'manual',
        'manual_qty_kg': 2.5,
        'tare_enabled': true,
        'tare_kg': 0.78,
      },
    });

    expect(response.ok, isTrue);
    expect(response.batch.active, isTrue);
    expect(response.batch.itemCode, 'ITEM-1');
    expect(response.batch.displayItemName, 'Green Tea');
    expect(response.batch.driverUrl, 'http://127.0.0.1:39117');
    expect(response.batch.quantitySource, 'manual');
    expect(response.batch.tareEnabled, isTrue);
  });

  test('rps batch start helper carries current print controls', () {
    final request = buildGScaleRpsBatchStartRequest(
      driverUrl: 'http://127.0.0.1:39117',
      item: const MobileItem(itemCode: 'ITEM-1', itemName: 'Green Tea'),
      warehouse: 'Stores - A',
      printer: 'zebra',
      printMode: 'rfid',
      quantitySource: 'scale',
      manualQtyKg: 0,
      tareEnabled: true,
      tareKg: 0.78,
    );

    expect(request.toJson(), {
      'client_batch_id': '',
      'driver_url': 'http://127.0.0.1:39117',
      'item_code': 'ITEM-1',
      'item_name': 'Green Tea',
      'warehouse': 'Stores - A',
      'printer': 'zebra',
      'print_mode': 'rfid',
      'quantity_source': 'scale',
      'manual_qty_kg': 0,
      'tare_enabled': true,
      'tare_kg': 0.78,
    });
  });

  test('rps batch print helper sends gross qty and driver url', () {
    final request = buildGScaleRpsBatchPrintRequest(
      grossQtyKg: 2.5,
      driverUrl: ' http://127.0.0.1:39117/ ',
    );

    expect(request.toJson(), {
      'gross_qty': 2.5,
      'unit': 'kg',
      'driver_url': 'http://127.0.0.1:39117',
    });
  });

  test('scale display kg parser accepts monitor label', () {
    expect(parseScaleDisplayKg('2.500 kg'), 2.5);
    expect(parseScaleDisplayKg('2,500 kg'), 2.5);
    expect(parseScaleDisplayKg('--'), isNull);
  });
}
