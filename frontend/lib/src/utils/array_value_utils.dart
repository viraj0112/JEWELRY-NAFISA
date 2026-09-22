import 'dart:convert';

/// Normalizes array values received from CSV, AI-fill output, and Postgres.
class ArrayValueUtils {
  static List<String>? parse(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      final values = value
          .expand((item) => parse(item) ?? <String>[])
          .map(_cleanToken)
          .where((item) => item.isNotEmpty)
          .toList();
      return values.isEmpty ? null : values;
    }

    final raw = value.toString().trim();
    if (_isEmpty(raw)) return null;

    if ((raw.startsWith('[') && raw.endsWith(']'))) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return parse(decoded);
      } catch (_) {
        // Continue with tolerant parsing for malformed AI output.
      }
    }

    var inner = raw;
    if ((inner.startsWith('[') && inner.endsWith(']')) ||
        (inner.startsWith('{') && inner.endsWith('}'))) {
      inner = inner.substring(1, inner.length - 1).trim();
    }

    final separator = inner.contains('|') ? '|' : ',';
    final values = inner
        .split(separator)
        .map(_cleanToken)
        .where((item) => item.isNotEmpty)
        .toList();
    return values.isEmpty ? null : values;
  }

  static String _cleanToken(String value) {
    var token = value.trim();
    while (token.length >= 2 &&
        ((token.startsWith('"') && token.endsWith('"')) ||
            (token.startsWith("'") && token.endsWith("'")))) {
      token = token.substring(1, token.length - 1).trim();
    }
    return _isEmpty(token) ? '' : token;
  }

  static bool _isEmpty(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.isEmpty ||
        normalized == 'null' ||
        normalized == 'none' ||
        normalized == 'n/a' ||
        normalized == 'na' ||
        normalized == '{}' ||
        normalized == '[]' ||
        normalized == '{null}' ||
        normalized == '[null]';
  }
}
