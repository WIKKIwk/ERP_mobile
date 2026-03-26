part of 'mobile_api.dart';

extension MobileApiWerka on MobileApi {
  String get baseUrl => MobileApi.baseUrl;

  Future<List<DispatchRecord>> werkaPending() async {
    final http.Response response = await _sendAuthorized(
      () => http.get(
        Uri.parse('$baseUrl/v1/mobile/werka/pending'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Werka pending failed');
    }
    final List<dynamic> json = jsonDecode(response.body) as List<dynamic>;
    return json
        .map((item) => DispatchRecord.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<SupplierDirectoryEntry>> werkaSuppliers() async {
    final http.Response response = await _sendAuthorized(
      () => http.get(
        Uri.parse('$baseUrl/v1/mobile/werka/suppliers'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Werka suppliers failed');
    }
    final List<dynamic> json = jsonDecode(response.body) as List<dynamic>;
    return json
        .map(
          (item) => SupplierDirectoryEntry.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<List<CustomerDirectoryEntry>> werkaCustomers({
    String query = '',
  }) async {
    final response = await _sendAuthorized(
      () => http.get(
        Uri.parse('$baseUrl/v1/mobile/werka/customers').replace(
          queryParameters: query.trim().isEmpty ? null : {'q': query.trim()},
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Werka customers failed');
    }
    final List<dynamic> json = jsonDecode(response.body) as List<dynamic>;
    return json
        .map(
          (item) => CustomerDirectoryEntry.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<List<SupplierItem>> werkaSupplierItems({
    required String supplierRef,
    String query = '',
  }) async {
    final response = await _sendAuthorized(
      () => http.get(
        Uri.parse('$baseUrl/v1/mobile/werka/supplier-items').replace(
          queryParameters: {
            'supplier_ref': supplierRef,
            if (query.trim().isNotEmpty) 'q': query.trim(),
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Werka supplier items failed');
    }
    final List<dynamic> json = jsonDecode(response.body) as List<dynamic>;
    return json
        .map((item) => SupplierItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<SupplierItem>> werkaCustomerItems({
    required String customerRef,
    String query = '',
  }) async {
    final response = await _sendAuthorized(
      () => http.get(
        Uri.parse('$baseUrl/v1/mobile/werka/customer-items').replace(
          queryParameters: {
            'customer_ref': customerRef,
            if (query.trim().isNotEmpty) 'q': query.trim(),
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Werka customer items failed');
    }
    final List<dynamic> json = jsonDecode(response.body) as List<dynamic>;
    return json
        .map((item) => SupplierItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<CustomerItemOption>> werkaCustomerItemOptions({
    String query = '',
  }) async {
    final response = await _sendAuthorized(
      () => http.get(
        Uri.parse('$baseUrl/v1/mobile/werka/customer-item-options').replace(
          queryParameters: query.trim().isEmpty ? null : {'q': query.trim()},
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Werka customer item options failed');
    }
    final List<dynamic> json = jsonDecode(response.body) as List<dynamic>;
    return json
        .map(
          (item) => CustomerItemOption.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<DispatchRecord> createWerkaUnannouncedDraft({
    required String supplierRef,
    required String itemCode,
    required double qty,
  }) async {
    final response = await _sendAuthorized(
      () => http.post(
        Uri.parse('$baseUrl/v1/mobile/werka/unannounced/create'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'supplier_ref': supplierRef,
          'item_code': itemCode,
          'qty': qty,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Werka unannounced create failed');
    }
    return DispatchRecord.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<WerkaCustomerIssueRecord> createWerkaCustomerIssue({
    required String customerRef,
    required String itemCode,
    required double qty,
  }) async {
    final response = await _sendAuthorized(
      () => http.post(
        Uri.parse('$baseUrl/v1/mobile/werka/customer-issue/create'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'customer_ref': customerRef,
          'item_code': itemCode,
          'qty': qty,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Werka customer issue create failed');
    }
    return WerkaCustomerIssueRecord.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<WerkaHomeSummary> werkaSummary() async {
    final http.Response response = await _sendAuthorized(
      () => http.get(
        Uri.parse('$baseUrl/v1/mobile/werka/summary'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Werka summary failed');
    }
    return WerkaHomeSummary.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<WerkaStatusBreakdownEntry>> werkaStatusBreakdown(
    WerkaStatusKind kind,
  ) async {
    final http.Response response = await _sendAuthorized(
      () => http.get(
        Uri.parse('$baseUrl/v1/mobile/werka/status-breakdown').replace(
          queryParameters: {'kind': kind.name},
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Werka status breakdown failed');
    }
    final List<dynamic> json = jsonDecode(response.body) as List<dynamic>;
    return json
        .map(
          (item) => WerkaStatusBreakdownEntry.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<List<DispatchRecord>> werkaStatusDetails({
    required WerkaStatusKind kind,
    required String supplierRef,
  }) async {
    final http.Response response = await _sendAuthorized(
      () => http.get(
        Uri.parse('$baseUrl/v1/mobile/werka/status-details').replace(
          queryParameters: {
            'kind': kind.name,
            'supplier_ref': supplierRef,
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Werka status details failed');
    }
    final List<dynamic> json = jsonDecode(response.body) as List<dynamic>;
    return json
        .map((item) => DispatchRecord.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<DispatchRecord>> werkaHistory() async {
    final http.Response response = await _sendAuthorized(
      () => http.get(
        Uri.parse('$baseUrl/v1/mobile/werka/history'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Werka history failed');
    }
    final List<dynamic> json = jsonDecode(response.body) as List<dynamic>;
    return json
        .map((item) => DispatchRecord.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<DispatchRecord> confirmReceipt({
    required String receiptID,
    required double acceptedQty,
    double returnedQty = 0,
    String returnReason = '',
    String returnComment = '',
  }) async {
    final http.Response response = await _sendAuthorized(
      () => http.post(
        Uri.parse('$baseUrl/v1/mobile/werka/confirm'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'receipt_id': receiptID,
          'accepted_qty': acceptedQty,
          'returned_qty': returnedQty,
          'return_reason': returnReason,
          'return_comment': returnComment,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Confirm receipt failed');
    }
    return DispatchRecord.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
