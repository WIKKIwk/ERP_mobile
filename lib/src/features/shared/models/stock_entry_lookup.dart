class StockEntryBarcodeEntry {
  const StockEntryBarcodeEntry({
    required this.stockEntryName,
    required this.stockEntryType,
    required this.docStatus,
    required this.status,
    required this.company,
    required this.postingDate,
    required this.postingTime,
    required this.creation,
    required this.modified,
    required this.remarks,
    required this.lineIndex,
    required this.itemCode,
    required this.itemName,
    required this.qty,
    required this.uom,
    required this.stockUOM,
    required this.barcode,
    required this.sourceWarehouse,
    required this.targetWarehouse,
  });

  final String stockEntryName;
  final String stockEntryType;
  final int docStatus;
  final String status;
  final String company;
  final String postingDate;
  final String postingTime;
  final String creation;
  final String modified;
  final String remarks;
  final int lineIndex;
  final String itemCode;
  final String itemName;
  final double qty;
  final String uom;
  final String stockUOM;
  final String barcode;
  final String sourceWarehouse;
  final String targetWarehouse;

  factory StockEntryBarcodeEntry.fromJson(Map<String, dynamic> json) {
    return StockEntryBarcodeEntry(
      stockEntryName: json['stock_entry_name'] as String? ?? '',
      stockEntryType: json['stock_entry_type'] as String? ?? '',
      docStatus: (json['doc_status'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? '',
      company: json['company'] as String? ?? '',
      postingDate: json['posting_date'] as String? ?? '',
      postingTime: json['posting_time'] as String? ?? '',
      creation: json['creation'] as String? ?? '',
      modified: json['modified'] as String? ?? '',
      remarks: json['remarks'] as String? ?? '',
      lineIndex: (json['line_index'] as num?)?.toInt() ?? 0,
      itemCode: json['item_code'] as String? ?? '',
      itemName: json['item_name'] as String? ?? '',
      qty: (json['qty'] as num?)?.toDouble() ?? 0,
      uom: json['uom'] as String? ?? '',
      stockUOM: json['stock_uom'] as String? ?? '',
      barcode: json['barcode'] as String? ?? '',
      sourceWarehouse: json['source_warehouse'] as String? ?? '',
      targetWarehouse: json['target_warehouse'] as String? ?? '',
    );
  }
}

class StockEntryBarcodeLookup {
  const StockEntryBarcodeLookup({
    required this.barcode,
    required this.count,
    required this.entries,
  });

  final String barcode;
  final int count;
  final List<StockEntryBarcodeEntry> entries;

  bool get hasMultipleEntries => entries.length > 1;

  factory StockEntryBarcodeLookup.fromJson(Map<String, dynamic> json) {
    final entriesJson = json['entries'];
    final entries = entriesJson is List
        ? entriesJson
            .whereType<Map<String, dynamic>>()
            .map(StockEntryBarcodeEntry.fromJson)
            .toList()
        : const <StockEntryBarcodeEntry>[];
    return StockEntryBarcodeLookup(
      barcode: json['barcode'] as String? ?? '',
      count: (json['count'] as num?)?.toInt() ?? entries.length,
      entries: entries,
    );
  }
}
