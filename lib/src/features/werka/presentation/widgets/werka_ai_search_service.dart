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
    final shortQuery =
        _sanitizeSearchQuery(parsed?['short_query'] as String? ?? '');
    final uzQuery = _sanitizeSearchQuery(parsed?['uz_query'] as String? ?? '');
    final enQuery = _sanitizeSearchQuery(parsed?['en_query'] as String? ?? '');
    final ruQuery = _sanitizeSearchQuery(parsed?['ru_query'] as String? ?? '');
    final searchQuery =
        _sanitizeSearchQuery(parsed?['search_query'] as String? ?? '');
    final keywordQueries = _extractKeywordQueries(parsed);
    final displayQuery = _pickDisplayQuery(
      locale,
      shortQuery: shortQuery,
      uzQuery: uzQuery,
      enQuery: enQuery,
      ruQuery: ruQuery,
      fallbackQuery: searchQuery,
    );
    final backgroundQueries = _rankQueries(<String>[
      displayQuery,
      shortQuery,
      uzQuery,
      enQuery,
      ruQuery,
      searchQuery,
      ..._expandPhrasePrefixes(<String>[
        displayQuery,
        shortQuery,
        uzQuery,
        enQuery,
        ruQuery,
        searchQuery,
      ]),
      ...keywordQueries,
      ..._expandQueryTokens(<String>[
        displayQuery,
        shortQuery,
        uzQuery,
        enQuery,
        ruQuery,
        ...keywordQueries,
      ]),
    ]);
    final resolvedDisplayQuery = displayQuery.isNotEmpty
        ? displayQuery
        : (backgroundQueries.isNotEmpty ? backgroundQueries.first : '');
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
        parsed?['visible_text'] as String? ?? '',
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

  List<String> _extractKeywordQueries(Map<String, dynamic>? parsed) {
    if (parsed == null) {
      return const <String>[];
    }
    final queries = <String>[];
    final keywords = parsed['keywords'];
    if (keywords is List) {
      for (final keyword in keywords) {
        queries.add(_sanitizeSearchQuery('$keyword'));
      }
    }
    return _uniqueQueries(queries);
  }

  String _pickDisplayQuery(
    Locale locale, {
    required String shortQuery,
    required String uzQuery,
    required String enQuery,
    required String ruQuery,
    required String fallbackQuery,
  }) {
    final code = locale.languageCode.toLowerCase();
    if (code == 'ru' && ruQuery.isNotEmpty) {
      return ruQuery;
    }
    if (code == 'en' && enQuery.isNotEmpty) {
      return enQuery;
    }
    if (code == 'uz' && uzQuery.isNotEmpty) {
      return uzQuery;
    }
    if (shortQuery.isNotEmpty) {
      return shortQuery;
    }
    if (fallbackQuery.isNotEmpty) {
      return fallbackQuery;
    }
    final fallbacks = _uniqueQueries(<String>[uzQuery, enQuery, ruQuery]);
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

  List<String> _expandQueryTokens(Iterable<String> values) {
    final tokens = <String>[];
    for (final value in values) {
      final normalizedValue = value.replaceAll(RegExp(r"[`'ʻʼ’]"), '');
      for (final token in normalizedValue.split(
        RegExp(r'[^A-Za-z0-9А-Яа-яЁёЎўҚқҒғҲҳ]+'),
      )) {
        final trimmed = _sanitizeSearchQuery(token);
        if (trimmed.length < 3 ||
            trimmed.contains(RegExp(r'\d')) ||
            _stopTokens.contains(trimmed.toLowerCase())) {
          continue;
        }
        tokens.add(trimmed);
      }
    }
    return _uniqueQueries(tokens);
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
      'You are generating retail search queries from packaging for a live server product search. '
      'Goal: maximize retrieval of the correct item family from the server. '
      'Prefer transliterated Uzbek/Russian market spellings that an operator would type manually, '
      'for example xot lanch, kuritsa, ostriy, qulipne, simba chips. '
      'Use visible product family and flavor first; brand alone is weak unless that is all that is visible. '
      'Return strict JSON with keys short_query, uz_query, en_query, ru_query, visible_text, confidence, keywords. '
      'keywords must be a short array of extra search words or short phrases that can help retrieval.';

  static const Set<String> _stopTokens = {
    'and',
    'the',
    'with',
    'for',
    'hot',
    'lunch',
    'tez',
    'tayyorlanadigan',
    'instant',
  };
}
