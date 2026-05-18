import 'package:erpnext_stock_mobile/src/features/gscale/gscale_catalog.dart';
import 'package:erpnext_stock_mobile/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('customer options become unique GScale catalog items', () {
    final items = gscaleCatalogItemsFromCustomerOptions([
      _option(itemCode: 'ITEM-001', itemName: 'Rice', warehouse: 'Stores - A'),
      _option(itemCode: 'ITEM-001', itemName: 'Rice', warehouse: 'Stores - B'),
      _option(itemCode: 'ITEM-002', itemName: '', warehouse: 'Stores - A'),
    ]);

    expect(items, hasLength(2));
    expect(items[0].itemCode, 'ITEM-001');
    expect(items[0].itemName, 'Rice');
    expect(items[1].itemCode, 'ITEM-002');
    expect(items[1].itemName, 'ITEM-002');
  });

  test('customer options expose exact item warehouses only', () {
    final warehouses = gscaleWarehousesFromCustomerOptions(
      [
        _option(itemCode: 'ITEM-001', warehouse: 'Stores - A'),
        _option(itemCode: 'ITEM-001', warehouse: 'Stores - A'),
        _option(itemCode: 'ITEM-001', warehouse: 'Stores - B'),
        _option(itemCode: 'ITEM-002', warehouse: 'Stores - C'),
      ],
      itemCode: 'ITEM-001',
      query: 'b',
    );

    expect(warehouses, hasLength(1));
    expect(warehouses.single.warehouse, 'Stores - B');
  });

  test('admin supplier items map default warehouse for selected item', () {
    final warehouses = gscaleWarehousesFromSupplierItems(
      const [
        SupplierItem(
          code: 'ITEM-001',
          name: 'Rice',
          uom: 'kg',
          warehouse: 'Stores - CH',
        ),
        SupplierItem(
          code: 'ITEM-002',
          name: 'Sugar',
          uom: 'kg',
          warehouse: 'Stores - B',
        ),
      ],
      itemCode: 'ITEM-001',
    );

    expect(warehouses, hasLength(1));
    expect(warehouses.single.warehouse, 'Stores - CH');
  });
}

CustomerItemOption _option({
  required String itemCode,
  String itemName = 'Item',
  required String warehouse,
}) {
  return CustomerItemOption(
    customerRef: 'CUST-001',
    customerName: 'Customer',
    customerPhone: '+998',
    itemCode: itemCode,
    itemName: itemName,
    uom: 'kg',
    warehouse: warehouse,
  );
}
