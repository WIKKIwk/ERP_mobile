import '../../../../core/localization/app_localizations.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class WerkaAiSearchException implements Exception {
  const WerkaAiSearchException(this.message);

  final String message;

  @override
  String toString() => message;
}

class WerkaAiSearchSuggestion {
  const WerkaAiSearchSuggestion({
    required this.displayQuery,
    required this.backgroundQueries,
    required this.visibleText,
  });

  final String displayQuery;
  final List<String> backgroundQueries;
  final String visibleText;
}

class WerkaAiSearchService {
  WerkaAiSearchService._();

  static final WerkaAiSearchService instance = WerkaAiSearchService._();
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String _model = String.fromEnvironment(
    'GEMINI_VISION_MODEL',
    defaultValue: 'gemini-flash-lite-latest',
  );

  final ImagePicker _picker = ImagePicker();

  Future<WerkaAiSearchSuggestion?> pickAndInferSuggestion(
    BuildContext context,
  ) async {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    if (_apiKey.trim().isEmpty) {
      throw WerkaAiSearchException(l10n.aiSearchNotConfigured);
    }

    final source = await _pickSource(context);
    if (source == null) {
      return null;
    }

    XFile? image;
    try {
      image = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
    } catch (_) {
      throw WerkaAiSearchException(l10n.imagePickFailed);
    }
    if (image == null) {
      return null;
    }

    final bytes = await image.readAsBytes();
    final suggestion = await inferQueryFromImage(
      locale: locale,
      imageBytes: bytes,
      mimeType: _mimeTypeForName(image.name),
    );
    if (suggestion.displayQuery.isEmpty &&
        suggestion.backgroundQueries.isEmpty) {
      throw WerkaAiSearchException(l10n.aiSearchNoResult);
    }
    return suggestion;
  }

  Future<WerkaAiSearchSuggestion> inferQueryFromImage({
    required Locale locale,
    required List<int> imageBytes,
    required String mimeType,
  }) async {
    final payload = <String, Object?>{
      'contents': [
        {
          'parts': [
            {
              'text': _prompt,
            },
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Encode(imageBytes),
              },
            },
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0,
        'responseMimeType': 'application/json',
      },
    };

    final response = await http.post(
      Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/'
        '$_model:generateContent?key=$_apiKey',
      ),
      headers: const {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    Map<String, dynamic>? data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      data = null;
    }

    if (response.statusCode != 200) {
      final message = data?['error'] is Map<String, dynamic>
          ? (data?['error']['message'] as String? ?? '').trim()
          : '';
      throw WerkaAiSearchException(
          message.isNotEmpty ? message : 'AI search request failed');
    }

    final candidates = data?['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      return const WerkaAiSearchSuggestion(
        displayQuery: '',
        backgroundQueries: <String>[],
        visibleText: '',
      );
    }
    final content = candidates.first['content'];
    if (content is! Map<String, dynamic>) {
      return const WerkaAiSearchSuggestion(
        displayQuery: '',
        backgroundQueries: <String>[],
        visibleText: '',
      );
    }
    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) {
      return const WerkaAiSearchSuggestion(
        displayQuery: '',
        backgroundQueries: <String>[],
        visibleText: '',
      );
    }
    final rawText = (parts.first['text'] as String? ?? '').trim();
    final parsed = _decodeJsonObject(rawText);
    final searchQuery = _normalizeServerFriendlyQuery(
      _sanitizeSearchQuery(parsed?['search_query'] as String? ?? ''),
    );
    final altQuery = _normalizeServerFriendlyQuery(
      _sanitizeSearchQuery(parsed?['alt_query'] as String? ?? ''),
    );
    final visibleBrand =
        _sanitizeSearchQuery(parsed?['visible_brand'] as String? ?? '');
    final displayQuery = searchQuery.isNotEmpty
        ? searchQuery
        : _pickFallbackDisplayQuery(
            visibleBrand: visibleBrand,
            altQuery: altQuery,
          );
    final backgroundQueries = _rankQueries(<String>[
      displayQuery,
      altQuery,
      visibleBrand,
      ..._expandPhrasePrefixes(<String>[
        displayQuery,
        altQuery,
        visibleBrand,
      ]),
    ]);
    final resolvedDisplayQuery = _normalizeServerFriendlyQuery(
      displayQuery.isNotEmpty
        ? displayQuery
        : (backgroundQueries.isNotEmpty ? backgroundQueries.first : ''),
    );
    debugPrint(
      'ai search suggestion '
      'display="$resolvedDisplayQuery" '
      'queries=${jsonEncode(backgroundQueries)} '
      'visible="${_sanitizeSearchQuery(parsed?['visible_text'] as String? ?? '')}"',
    );
    return WerkaAiSearchSuggestion(
      displayQuery: resolvedDisplayQuery,
      backgroundQueries: backgroundQueries,
      visibleText: _sanitizeSearchQuery(
        parsed?['visible_text'] as String? ?? visibleBrand,
      ),
    );
  }

  Future<ImageSource?> _pickSource(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return showModalBottomSheet<ImageSource>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: Text(l10n.aiSearchTakePhoto),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: Text(l10n.aiSearchChoosePhoto),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
  }

  Map<String, dynamic>? _decodeJsonObject(String rawText) {
    if (rawText.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(rawText) as Map<String, dynamic>;
    } catch (_) {
      final match = RegExp(r'\{.*\}', dotAll: true).firstMatch(rawText);
      if (match == null) {
        return null;
      }
      try {
        return jsonDecode(match.group(0)!) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }
  }

  String _sanitizeSearchQuery(String raw) {
    var value = raw.trim();
    if (value.isEmpty) {
      return '';
    }
    value = value.split(RegExp(r'[\r\n]+')).first.trim();
    value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    const edgeChars = ['"', "'", '`', '“', '”', '‘', '’'];
    while (value.isNotEmpty && edgeChars.any(value.startsWith)) {
      value = value.substring(1).trimLeft();
    }
    while (value.isNotEmpty && edgeChars.any(value.endsWith)) {
      value = value.substring(0, value.length - 1).trimRight();
    }
    if (value.length > 64) {
      value = value.substring(0, 64).trimRight();
    }
    return value;
  }

  String _normalizeServerFriendlyQuery(String raw) {
    final value = _sanitizeSearchQuery(raw);
    if (value.isEmpty) {
      return '';
    }
    final lower = value.toLowerCase();
    final tokens = lower
        .split(RegExp(r'[^a-z0-9а-яёўқғҳ]+'))
        .where((token) => token.trim().isNotEmpty)
        .where((token) => !_brandNoiseTokens.contains(token))
        .toList(growable: false);
    if (tokens.isNotEmpty && tokens.length <= 2) {
      final compact = tokens.join(' ');
      if (compact == 'nivea') {
        return 'nivea';
      }
      if (compact == 'musaffo') {
        return 'musaffo';
      }
    }
    if (lower.contains('hot lunch') || lower.contains('xot lanch')) {
      return lower.contains('xot lanch') ? 'xot lanch' : 'hot lunch';
    }
    if (lower.contains('musaffo') || lower.contains('мусаффо')) {
      return 'musaffo';
    }
    if (lower.contains('simba') && lower.contains('chips')) {
      return 'simba chips';
    }
    if (lower.contains('mini') &&
        (lower.contains('rulet') || lower.contains('рулет'))) {
      return 'mini rulet';
    }
    if (lower.contains('nivea') || lower.contains('нивеа')) {
      return 'nivea';
    }
    return value;
  }

  String _pickFallbackDisplayQuery({
    required String visibleBrand,
    required String altQuery,
  }) {
    final fallbacks = _uniqueQueries(<String>[visibleBrand, altQuery]);
    return fallbacks.isNotEmpty ? fallbacks.first : '';
  }

  List<String> _uniqueQueries(Iterable<String> values) {
    final unique = <String>[];
    final seen = <String>{};
    for (final raw in values) {
      final value = _sanitizeSearchQuery(raw);
      if (value.isEmpty) {
        continue;
      }
      final key = value.toLowerCase();
      if (!seen.add(key)) {
        continue;
      }
      unique.add(value);
    }
    return unique;
  }

  List<String> _expandPhrasePrefixes(Iterable<String> values) {
    final phrases = <String>[];
    for (final value in values) {
      final normalized = _sanitizeSearchQuery(value);
      if (normalized.isEmpty) {
        continue;
      }
      final tokens = normalized
          .split(RegExp(r'[^A-Za-z0-9А-Яа-яЁёЎўҚқҒғҲҳ]+'))
          .where((token) => token.trim().isNotEmpty)
          .toList(growable: false);
      if (tokens.length < 2) {
        continue;
      }
      phrases.add(tokens.take(2).join(' '));
      if (tokens.length >= 3) {
        phrases.add(tokens.take(3).join(' '));
      }
    }
    return _uniqueQueries(phrases);
  }

  List<String> _rankQueries(Iterable<String> values) {
    final unique = _uniqueQueries(values);
    unique.sort((left, right) {
      final tokenDelta =
          _queryTokenCount(right).compareTo(_queryTokenCount(left));
      if (tokenDelta != 0) {
        return tokenDelta;
      }
      return right.length.compareTo(left.length);
    });
    return unique;
  }

  int _queryTokenCount(String value) {
    return value
        .split(RegExp(r'[^A-Za-z0-9А-Яа-яЁёЎўҚқҒғҲҳ]+'))
        .where((token) => token.trim().length >= 2)
        .length;
  }

  String _mimeTypeForName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  static const String _prompt =
      'Look at the package image and identify only the main brand or product family name that a warehouse worker should type for search. '
      'If there is a clear standalone brand, return only that brand. '
      'Do not include care words, category words, flavor, size, or descriptors such as cream, care, soap, sovun, milk, dairy, spicy. '
      'Prefer the shortest searchable family query and server-friendly retail spelling or transliteration. '
      'Examples: HOTLUNCH spicy chicken -> hot lunch, Musaffo -> musaffo, Simba Chips -> simba chips, Yashkino Mini-Rulet -> mini rulet, Nivea Creme Care -> nivea. '
      'Return strict JSON with keys search_query, alt_query, visible_brand, visible_text, confidence.';

  static const Set<String> _brandNoiseTokens = {
    'cream',
    'care',
    'soap',
    'sovun',
    'milk',
    'dairy',
    'soft',
    'creme',
    'molochnaya',
    'mahsulotlari',
    'products',
    'product',
    'spicy',
  };
}
