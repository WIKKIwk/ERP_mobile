part of '../mobile_api.dart';

extension MobileApiGScale on MobileApi {
  Future<GScaleRpsBatchResponse> gscaleRpsBatchStart(
    GScaleRpsBatchStartRequest request,
  ) async {
    final response = await _sendAuthorized(
      () => http.post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/rps/batch/start'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(request.toJson()),
      ),
    );
    final payload = _gscaleDecodeObject(response.body);
    if (response.statusCode != 200) {
      throw MobileApiException(
        code: _gscaleText(payload['error'], fallback: 'rps_batch_start_failed'),
        message: _gscaleText(
          payload['detail'],
          fallback: _gscaleText(
            payload['message'],
            fallback: 'RPS batch start failed',
          ),
        ),
        statusCode: response.statusCode,
      );
    }
    return GScaleRpsBatchResponse.fromJson(payload);
  }

  Future<GScaleRpsBatchResponse> gscaleRpsBatchState() async {
    final response = await _sendAuthorized(
      () => http.get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/rps/batch/state'),
        headers: _headers(requireToken()),
      ),
    );
    final payload = _gscaleDecodeObject(response.body);
    if (response.statusCode != 200) {
      throw MobileApiException(
        code: _gscaleText(payload['error'], fallback: 'rps_batch_state_failed'),
        message: _gscaleText(
          payload['detail'],
          fallback: _gscaleText(
            payload['message'],
            fallback: 'RPS batch state failed',
          ),
        ),
        statusCode: response.statusCode,
      );
    }
    return GScaleRpsBatchResponse.fromJson(payload);
  }

  Future<GScaleRpsBatchResponse> gscaleRpsBatchStop() async {
    final response = await _sendAuthorized(
      () => http.post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/rps/batch/stop'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: '{}',
      ),
    );
    final payload = _gscaleDecodeObject(response.body);
    if (response.statusCode != 200) {
      throw MobileApiException(
        code: _gscaleText(payload['error'], fallback: 'rps_batch_stop_failed'),
        message: _gscaleText(
          payload['detail'],
          fallback: _gscaleText(
            payload['message'],
            fallback: 'RPS batch stop failed',
          ),
        ),
        statusCode: response.statusCode,
      );
    }
    return GScaleRpsBatchResponse.fromJson(payload);
  }

  Future<GScaleMaterialReceiptPrintResponse> gscaleRpsBatchPrint(
    GScaleRpsBatchPrintRequest request,
  ) async {
    final response = await _sendAuthorized(
      () => http.post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/rps/batch/print'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(request.toJson()),
      ),
    );
    final payload = _gscaleDecodeObject(response.body);
    if (response.statusCode != 200) {
      throw MobileApiException(
        code: _gscaleText(payload['error'], fallback: 'rps_batch_print_failed'),
        message: _gscaleText(
          payload['detail'],
          fallback: _gscaleText(
            payload['message'],
            fallback: 'RPS batch print failed',
          ),
        ),
        statusCode: response.statusCode,
      );
    }
    return GScaleMaterialReceiptPrintResponse.fromJson(payload);
  }

  Future<GScaleMaterialReceiptPrintResponse> gscaleMaterialReceiptPrint(
    GScaleMaterialReceiptPrintRequest request,
  ) async {
    final response = await _sendAuthorized(
      () => http.post(
        Uri.parse(
            '${MobileApi.baseUrl}/v1/mobile/gscale/material-receipt/print'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(request.toJson()),
      ),
    );
    final payload = _gscaleDecodeObject(response.body);
    if (response.statusCode != 200) {
      throw MobileApiException(
        code: _gscaleText(payload['error'], fallback: 'gscale_print_failed'),
        message: _gscaleText(
          payload['detail'],
          fallback: _gscaleText(
            payload['message'],
            fallback: 'GScale print failed',
          ),
        ),
        statusCode: response.statusCode,
      );
    }
    return GScaleMaterialReceiptPrintResponse.fromJson(payload);
  }
}

class GScaleRpsBatchStartRequest {
  const GScaleRpsBatchStartRequest({
    required this.clientBatchId,
    required this.driverUrl,
    required this.itemCode,
    required this.itemName,
    required this.warehouse,
    required this.printer,
    required this.printMode,
    required this.quantitySource,
    this.manualQtyKg = 0,
    this.tareEnabled = false,
    this.tareKg = 0,
  });

  final String clientBatchId;
  final String driverUrl;
  final String itemCode;
  final String itemName;
  final String warehouse;
  final String printer;
  final String printMode;
  final String quantitySource;
  final double manualQtyKg;
  final bool tareEnabled;
  final double tareKg;

  Map<String, dynamic> toJson() {
    return {
      'client_batch_id': clientBatchId.trim(),
      'driver_url': driverUrl.trim().trimRightSlash(),
      'item_code': itemCode.trim(),
      'item_name': itemName.trim(),
      'warehouse': warehouse.trim(),
      'printer': printer.trim(),
      'print_mode': printMode.trim(),
      'quantity_source': quantitySource.trim(),
      'manual_qty_kg': manualQtyKg,
      'tare_enabled': tareEnabled,
      'tare_kg': tareKg,
    };
  }
}

class GScaleRpsBatchPrintRequest {
  const GScaleRpsBatchPrintRequest({
    required this.grossQty,
    required this.driverUrl,
    this.unit = 'kg',
  });

  final double grossQty;
  final String driverUrl;
  final String unit;

  Map<String, dynamic> toJson() {
    return {
      'gross_qty': grossQty,
      'unit': unit.trim().isEmpty ? 'kg' : unit.trim(),
      'driver_url': driverUrl.trim().trimRightSlash(),
    };
  }
}

class GScaleRpsBatchResponse {
  const GScaleRpsBatchResponse({
    required this.ok,
    required this.batch,
  });

  factory GScaleRpsBatchResponse.fromJson(Map<String, dynamic> json) {
    final batch = (json['batch'] as Map?)?.cast<String, dynamic>() ?? const {};
    return GScaleRpsBatchResponse(
      ok: json['ok'] == true,
      batch: GScaleRpsBatchSession.fromJson(batch),
    );
  }

  final bool ok;
  final GScaleRpsBatchSession batch;
}

class GScaleRpsBatchSession {
  const GScaleRpsBatchSession({
    required this.id,
    required this.active,
    required this.driverUrl,
    required this.itemCode,
    required this.itemName,
    required this.warehouse,
    required this.printer,
    required this.printMode,
    required this.quantitySource,
    required this.manualQtyKg,
    required this.tareEnabled,
    required this.tareKg,
  });

  factory GScaleRpsBatchSession.fromJson(Map<String, dynamic> json) {
    return GScaleRpsBatchSession(
      id: _gscaleText(json['id']),
      active: json['active'] == true,
      driverUrl: _gscaleText(json['driver_url']),
      itemCode: _gscaleText(json['item_code']),
      itemName: _gscaleText(json['item_name']),
      warehouse: _gscaleText(json['warehouse']),
      printer: _gscaleText(json['printer']),
      printMode: _gscaleText(json['print_mode']),
      quantitySource: _gscaleText(json['quantity_source'], fallback: 'scale'),
      manualQtyKg: _gscaleNumber(json['manual_qty_kg']),
      tareEnabled: json['tare_enabled'] == true || json['tare'] == true,
      tareKg: _gscaleNumber(json['tare_kg']),
    );
  }

  final String id;
  final bool active;
  final String driverUrl;
  final String itemCode;
  final String itemName;
  final String warehouse;
  final String printer;
  final String printMode;
  final String quantitySource;
  final double manualQtyKg;
  final bool tareEnabled;
  final double tareKg;

  String get displayItemName => itemName.isEmpty ? itemCode : itemName;
}

class GScaleMaterialReceiptPrintRequest {
  const GScaleMaterialReceiptPrintRequest({
    required this.driverUrl,
    required this.itemCode,
    required this.itemName,
    required this.warehouse,
    required this.printer,
    required this.printMode,
    required this.grossQty,
    this.unit = 'kg',
    this.tareEnabled = false,
    this.tareKg = 0,
  });

  final String driverUrl;
  final String itemCode;
  final String itemName;
  final String warehouse;
  final String printer;
  final String printMode;
  final double grossQty;
  final String unit;
  final bool tareEnabled;
  final double tareKg;

  Map<String, dynamic> toJson() {
    return {
      'driver_url': driverUrl.trim(),
      'item_code': itemCode.trim(),
      'item_name': itemName.trim(),
      'warehouse': warehouse.trim(),
      'printer': printer.trim(),
      'print_mode': printMode.trim(),
      'gross_qty': grossQty,
      'unit': unit.trim().isEmpty ? 'kg' : unit.trim(),
      'tare_enabled': tareEnabled,
      'tare_kg': tareKg,
    };
  }
}

class GScaleMaterialReceiptPrintResponse {
  const GScaleMaterialReceiptPrintResponse({
    required this.ok,
    required this.status,
    required this.draftName,
    required this.epc,
    required this.itemCode,
    required this.itemName,
    required this.warehouse,
    required this.qty,
    required this.netQty,
    required this.grossQty,
    required this.unit,
    required this.printer,
    required this.printMode,
    required this.printerStatus,
  });

  factory GScaleMaterialReceiptPrintResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return GScaleMaterialReceiptPrintResponse(
      ok: json['ok'] == true,
      status: _gscaleText(json['status']),
      draftName: _gscaleText(json['draft_name']),
      epc: _gscaleText(json['epc']),
      itemCode: _gscaleText(json['item_code']),
      itemName: _gscaleText(json['item_name']),
      warehouse: _gscaleText(json['warehouse']),
      qty: _gscaleNumber(json['qty']),
      netQty: _gscaleNumber(json['net_qty']),
      grossQty: _gscaleNumber(json['gross_qty']),
      unit: _gscaleText(json['unit'], fallback: 'kg'),
      printer: _gscaleText(json['printer']),
      printMode: _gscaleText(json['print_mode']),
      printerStatus: _gscaleText(json['printer_status']),
    );
  }

  final bool ok;
  final String status;
  final String draftName;
  final String epc;
  final String itemCode;
  final String itemName;
  final String warehouse;
  final double qty;
  final double netQty;
  final double grossQty;
  final String unit;
  final String printer;
  final String printMode;
  final String printerStatus;
}

Map<String, dynamic> _gscaleDecodeObject(String body) {
  try {
    return (jsonDecode(body) as Map?)?.cast<String, dynamic>() ?? const {};
  } catch (_) {
    return const {};
  }
}

double _gscaleNumber(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String _gscaleText(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

extension _GScaleStringTrim on String {
  String trimRightSlash() {
    return replaceFirst(RegExp(r'/+$'), '');
  }
}
