String normalizeForSearch(String input) {
  if (input.trim().isEmpty) {
    return '';
  }

  final buffer = StringBuffer();
  final lower = input.toLowerCase();
  for (final rune in lower.runes) {
    buffer.write(_mapRune(String.fromCharCode(rune)));
  }

  return buffer
      .toString()
      .replaceAll(RegExp(r"['`ʻʼ’]"), '')
      .replaceAll('x', 'h')
      .replaceAll('ғ', 'g')
      .replaceAll('қ', 'q')
      .replaceAll('ҳ', 'h')
      .replaceAll('ў', 'o')
      .replaceAll('ё', 'yo')
      .replaceAll('ю', 'yu')
      .replaceAll('я', 'ya')
      .replaceAll('ъ', '')
      .replaceAll('ь', '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool searchMatches(String query, Iterable<String> values) {
  final needle = normalizeForSearch(query);
  if (needle.isEmpty) {
    return true;
  }

  final normalizedValues = values
      .map(normalizeForSearch)
      .where((value) => value.isNotEmpty)
      .toList();
  for (final value in normalizedValues) {
    if (value.contains(needle)) {
      return true;
    }
  }

  final queryTokens = needle
      .split(RegExp(r'[^a-z0-9]+'))
      .where((token) => token.length >= 2)
      .toList(growable: false);
  if (queryTokens.isEmpty) {
    return false;
  }

  for (final token in queryTokens) {
    final matched = normalizedValues.any((value) {
      if (value.contains(token)) {
        return true;
      }
      final compactValue = _compactForSearch(value);
      final compactToken = _compactForSearch(token);
      if (compactToken.isEmpty) {
        return false;
      }
      return compactValue.contains(compactToken) ||
          _containsFuzzy(compactValue, compactToken, maxDistance: 1);
    });
    if (!matched) {
      return false;
    }
  }

  if (queryTokens.length >= 2) {
    return true;
  }

  return false;
}

int compareSearchRelevance({
  required String query,
  required String leftPrimary,
  Iterable<String> leftSecondary = const <String>[],
  required String rightPrimary,
  Iterable<String> rightSecondary = const <String>[],
}) {
  final leftScore = _scoreSearchRelevance(
    query,
    primary: leftPrimary,
    secondary: leftSecondary,
  );
  final rightScore = _scoreSearchRelevance(
    query,
    primary: rightPrimary,
    secondary: rightSecondary,
  );
  return rightScore.compareTo(leftScore);
}

int searchRelevanceScore({
  required String query,
  required String primary,
  Iterable<String> secondary = const <String>[],
}) {
  return _scoreSearchRelevance(
    query,
    primary: primary,
    secondary: secondary,
  );
}

int _scoreSearchRelevance(
  String query, {
  required String primary,
  Iterable<String> secondary = const <String>[],
}) {
  final normalizedQuery = normalizeForSearch(query);
  final compactQuery = _compactForSearch(query);
  if (normalizedQuery.isEmpty || compactQuery.isEmpty) {
    return 0;
  }

  var best =
      _scoreField(normalizedQuery, compactQuery, primary, isPrimary: true);
  for (final value in secondary) {
    final score = _scoreField(
      normalizedQuery,
      compactQuery,
      value,
      isPrimary: false,
    );
    if (score > best) {
      best = score;
    }
  }
  return best;
}

int _scoreField(
  String normalizedQuery,
  String compactQuery,
  String value, {
  required bool isPrimary,
}) {
  final normalizedValue = normalizeForSearch(value);
  final compactValue = _compactForSearch(value);
  if (normalizedValue.isEmpty || compactValue.isEmpty) {
    return 0;
  }

  final weight = isPrimary ? 1000 : 0;
  if (compactValue == compactQuery) {
    return weight + 9000;
  }
  if (normalizedValue == normalizedQuery) {
    return weight + 8800;
  }
  if (compactValue.startsWith(compactQuery)) {
    return weight + 8200;
  }
  if (_startsWithFuzzy(compactValue, compactQuery, maxDistance: 1)) {
    return weight + 7900;
  }

  final tokens = normalizedValue
      .split(RegExp(r'[^a-z0-9]+'))
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
  if (tokens
      .any((token) => token == compactQuery || token == normalizedQuery)) {
    return weight + 7600;
  }
  if (tokens.any((token) => token.startsWith(compactQuery))) {
    return weight + 7300;
  }
  if (tokens.any(
    (token) =>
        token.length >= compactQuery.length &&
        _boundedLevenshtein(
              token.substring(0, compactQuery.length),
              compactQuery,
              maxDistance: 1,
            ) !=
            null,
  )) {
    return weight + 7000;
  }
  if (compactValue.contains(compactQuery)) {
    return weight + 6200;
  }
  if (normalizedValue.contains(normalizedQuery)) {
    return weight + 5800;
  }
  if (_containsFuzzy(compactValue, compactQuery, maxDistance: 1)) {
    return weight + 5400;
  }
  return 0;
}

bool _startsWithFuzzy(String compactValue, String compactQuery,
    {required int maxDistance}) {
  if (compactValue.length < compactQuery.length) {
    return false;
  }
  final prefix = compactValue.substring(0, compactQuery.length);
  return _boundedLevenshtein(prefix, compactQuery, maxDistance: maxDistance) !=
      null;
}

bool _containsFuzzy(String compactValue, String compactQuery,
    {required int maxDistance}) {
  if (compactQuery.isEmpty || compactValue.length < compactQuery.length) {
    return false;
  }
  for (var start = 0;
      start <= compactValue.length - compactQuery.length;
      start++) {
    final slice = compactValue.substring(start, start + compactQuery.length);
    if (_boundedLevenshtein(slice, compactQuery, maxDistance: maxDistance) !=
        null) {
      return true;
    }
  }
  return false;
}

int? _boundedLevenshtein(String left, String right,
    {required int maxDistance}) {
  if ((left.length - right.length).abs() > maxDistance) {
    return null;
  }

  var previous = List<int>.generate(right.length + 1, (index) => index);
  for (var i = 0; i < left.length; i++) {
    final current = List<int>.filled(right.length + 1, 0);
    current[0] = i + 1;
    var rowMin = current[0];
    for (var j = 0; j < right.length; j++) {
      final cost = left[i] == right[j] ? 0 : 1;
      current[j + 1] = [
        current[j] + 1,
        previous[j + 1] + 1,
        previous[j] + cost,
      ].reduce((a, b) => a < b ? a : b);
      if (current[j + 1] < rowMin) {
        rowMin = current[j + 1];
      }
    }
    if (rowMin > maxDistance) {
      return null;
    }
    previous = current;
  }
  final distance = previous.last;
  return distance <= maxDistance ? distance : null;
}

String _compactForSearch(String input) => normalizeForSearch(
      input,
    ).replaceAll(RegExp(r'[^a-z0-9]+'), '');

String _mapRune(String char) {
  switch (char) {
    case 'а':
      return 'a';
    case 'б':
      return 'b';
    case 'в':
      return 'v';
    case 'г':
      return 'g';
    case 'д':
      return 'd';
    case 'е':
      return 'e';
    case 'ё':
      return 'yo';
    case 'ж':
      return 'j';
    case 'з':
      return 'z';
    case 'и':
      return 'i';
    case 'й':
      return 'y';
    case 'к':
      return 'k';
    case 'л':
      return 'l';
    case 'м':
      return 'm';
    case 'н':
      return 'n';
    case 'о':
      return 'o';
    case 'п':
      return 'p';
    case 'р':
      return 'r';
    case 'с':
      return 's';
    case 'т':
      return 't';
    case 'у':
      return 'u';
    case 'ф':
      return 'f';
    case 'х':
      return 'x';
    case 'ц':
      return 'ts';
    case 'ч':
      return 'ch';
    case 'ш':
      return 'sh';
    case 'щ':
      return 'sh';
    case 'ъ':
      return '';
    case 'ы':
      return 'i';
    case 'ь':
      return '';
    case 'э':
      return 'e';
    case 'ю':
      return 'yu';
    case 'я':
      return 'ya';
    case 'қ':
      return 'q';
    case 'ғ':
      return 'g';
    case 'ҳ':
      return 'h';
    case 'ў':
      return 'o';
    default:
      return char;
  }
}
