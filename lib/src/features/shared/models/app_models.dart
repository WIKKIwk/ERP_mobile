enum UserRole {
  supplier,
  werka,
}

enum DispatchStatus {
  draft,
  pending,
  accepted,
  partial,
  rejected,
  cancelled,
}

class SupplierItem {
  const SupplierItem({
    required this.code,
    required this.name,
    required this.uom,
    required this.warehouse,
  });

  final String code;
  final String name;
  final String uom;
  final String warehouse;

  factory SupplierItem.fromJson(Map<String, dynamic> json) {
    return SupplierItem(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      uom: json['uom'] as String? ?? '',
      warehouse: json['warehouse'] as String? ?? '',
    );
  }
}

class DispatchRecord {
  const DispatchRecord({
    required this.id,
    required this.supplierName,
    required this.itemCode,
    required this.itemName,
    required this.uom,
    required this.sentQty,
    required this.acceptedQty,
    required this.status,
    required this.createdLabel,
  });

  final String id;
  final String supplierName;
  final String itemCode;
  final String itemName;
  final String uom;
  final double sentQty;
  final double acceptedQty;
  final DispatchStatus status;
  final String createdLabel;

  factory DispatchRecord.fromJson(Map<String, dynamic> json) {
    return DispatchRecord(
      id: json['id'] as String? ?? '',
      supplierName: json['supplier_name'] as String? ?? '',
      itemCode: json['item_code'] as String? ?? '',
      itemName: json['item_name'] as String? ?? '',
      uom: json['uom'] as String? ?? '',
      sentQty: (json['sent_qty'] as num?)?.toDouble() ?? 0,
      acceptedQty: (json['accepted_qty'] as num?)?.toDouble() ?? 0,
      status: parseDispatchStatus(json['status'] as String? ?? ''),
      createdLabel: json['created_label'] as String? ?? '',
    );
  }
}

class SessionProfile {
  const SessionProfile({
    required this.role,
    required this.displayName,
    required this.legalName,
    required this.ref,
    required this.phone,
    required this.avatarUrl,
  });

  final UserRole role;
  final String displayName;
  final String legalName;
  final String ref;
  final String phone;
  final String avatarUrl;

  factory SessionProfile.fromJson(Map<String, dynamic> json) {
    final String roleValue =
        (json['role'] as String? ?? '').trim().toLowerCase();
    return SessionProfile(
      role: roleValue == 'werka' ? UserRole.werka : UserRole.supplier,
      displayName: json['display_name'] as String? ?? '',
      legalName: json['legal_name'] as String? ?? '',
      ref: json['ref'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? '',
    );
  }

  SessionProfile copyWith({
    UserRole? role,
    String? displayName,
    String? legalName,
    String? ref,
    String? phone,
    String? avatarUrl,
  }) {
    return SessionProfile(
      role: role ?? this.role,
      displayName: displayName ?? this.displayName,
      legalName: legalName ?? this.legalName,
      ref: ref ?? this.ref,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}

DispatchStatus parseDispatchStatus(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'accepted':
      return DispatchStatus.accepted;
    case 'partial':
      return DispatchStatus.partial;
    case 'rejected':
      return DispatchStatus.rejected;
    case 'cancelled':
      return DispatchStatus.cancelled;
    case 'draft':
      return DispatchStatus.draft;
    default:
      return DispatchStatus.pending;
  }
}
