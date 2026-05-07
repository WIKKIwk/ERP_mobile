import 'dart:convert';

class WerkaArchiveBatchQrPayload {
  const WerkaArchiveBatchQrPayload({
    required this.sessionID,
    required this.itemName,
    required this.qtyText,
    required this.qty,
    required this.bruttoText,
    required this.bruttoQty,
    required this.nettoText,
    required this.nettoQty,
    required this.batchTime,
    required this.rawValue,
  });

  final String sessionID;
  final String itemName;
  final String qtyText;
  final double qty;
  final String bruttoText;
  final double bruttoQty;
  final String nettoText;
  final double nettoQty;
  final String batchTime;
  final String rawValue;

  static WerkaArchiveBatchQrPayload? tryParse(String rawValue) {
    final raw = rawValue.trim();
    if (raw.isEmpty) {
      return null;
    }

    final encoded = _archiveEncodedPayload(raw);
    if (encoded == null || encoded.isEmpty) {
      return null;
    }

    final decoded = _decodeBase64Url(encoded);
    if (decoded == null) {
      return null;
    }

    final lines =
        decoded.split('\n').map((line) => line.trim()).toList(growable: false);
    if (lines.length < 5 || lines.first.toUpperCase() != 'ARCHIVE') {
      return null;
    }

    final hasSeparatedWeights = lines.length >= 6;
    final bruttoText = hasSeparatedWeights ? lines[3] : lines[3];
    final nettoText = hasSeparatedWeights ? lines[4] : lines[3];
    final qtyText = nettoText;
    final qty = _parseQty(qtyText);
    final bruttoQty = _parseQty(bruttoText);
    final nettoQty = _parseQty(nettoText);
    if (qty <= 0) {
      return null;
    }

    return WerkaArchiveBatchQrPayload(
      sessionID: lines[1],
      itemName: lines[2],
      qtyText: qtyText,
      qty: qty,
      bruttoText: bruttoText,
      bruttoQty: bruttoQty > 0 ? bruttoQty : qty,
      nettoText: nettoText,
      nettoQty: nettoQty > 0 ? nettoQty : qty,
      batchTime: hasSeparatedWeights ? lines[5] : lines[4],
      rawValue: raw,
    );
  }

  static double _parseQty(String text) {
    final normalized = text
        .trim()
        .replaceAll(',', '.')
        .replaceAll(RegExp(r'[^0-9.\-]'), '');
    return double.tryParse(normalized) ?? 0;
  }

  static String? _archiveEncodedPayload(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.pathSegments.isNotEmpty) {
      final segments = uri.pathSegments
          .where((segment) => segment.trim().isNotEmpty)
          .toList(growable: false);
      if (segments.length >= 2 && segments.first.toUpperCase() == 'A') {
        return segments[1].trim();
      }
    }

    final marker = raw.indexOf('/A/');
    if (marker >= 0) {
      return raw.substring(marker + 3).split('/').first.trim();
    }

    return null;
  }

  static String? _decodeBase64Url(String encoded) {
    try {
      return utf8.decode(base64Url.decode(base64Url.normalize(encoded)));
    } catch (_) {
      return null;
    }
  }
}
