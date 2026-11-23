// Not exported: the package's own plumbing.
// ignore_for_file: public_member_api_docs

/// Turns what an app logs into what the platform channel carries: null, booleans, numbers,
/// strings, lists and string-keyed maps. The native SDKs then fit it to the server's limits and
/// redact secrets.
///
/// Coarse bounds keep a log call cheap on the UI isolate whatever it is given (a 5 MB response
/// body, a byte list, a value that holds itself twice). They are well above anything the
/// server keeps (strings up to 1,024 bytes in attrs, a payload up to 64 KiB serialized, a line
/// up to 1 MiB), so what the native SDK makes of the event is the same.
library;

/// Deeper than this, a list or map is sent as `[...]` or `{...}` (it also stops a value that
/// contains itself), and any other value as its text.
const int maxDepth = 32;

/// At most this many values (leaves, lists and maps) from one attrs map or one payload; the
/// rest is left out. Serialized, this many values is already more than a 64 KiB payload.
const int maxEncodedValues = 32 * 1024;

/// Strings (the message too) are cut to this many UTF-16 code units, more than a payload holds.
const int maxStringLength = 64 * 1024 + 1;

Map<String, Object?>? encodeAttributes(Map<String, Object?>? attrs) {
  if (attrs == null || attrs.isEmpty) return null;
  return _Encoder().map(attrs, 1);
}

Object? encodeValue(Object? value, [int depth = 0]) => _Encoder().value(value, depth);

/// [text] cut to [max] code units, never between the two halves of a surrogate pair.
String cutString(String text, [int max = maxStringLength]) {
  if (text.length <= max) return text;
  var end = max;
  final last = text.codeUnitAt(end - 1);
  if (last >= 0xD800 && last <= 0xDBFF) end -= 1;
  return text.substring(0, end);
}

/// One attrs map or one payload: [maxEncodedValues] is shared by everything in it.
class _Encoder {
  int _left = maxEncodedValues;

  Object? value(Object? value, int depth) {
    _left -= 1;
    if (value == null || value is bool || value is int) return value;
    if (value is String) return cutString(value);
    if (value is double) return value.isFinite ? value : null;
    if (value is num) return value.toDouble();
    if (value is DateTime) return value.toUtc().toIso8601String();
    // Milliseconds, like every `*_ms` attribute and the Swift SDK's LogValue(duration).
    if (value is Duration) return value.inMicroseconds / 1000;
    if (value is Enum) return value.name;
    // Not their `toString()`: a list that holds another twice, 60 levels down, would print
    // 2^28 times.
    if (value is Map) return depth >= maxDepth ? '{...}' : map(value, depth + 1);
    if (value is Iterable) {
      if (depth >= maxDepth) return '[...]';
      final out = <Object?>[];
      for (final item in value) {
        if (_left <= 0) break;
        out.add(this.value(item, depth + 1));
      }
      return out;
    }
    return _text(value);
  }

  Map<String, Object?> map(Map<Object?, Object?> map, int depth) {
    final out = <String, Object?>{};
    for (final entry in map.entries) {
      if (_left <= 0) break;
      out[_text(entry.key)] = value(entry.value, depth);
    }
    return out;
  }
}

String _text(Object? value) {
  try {
    return cutString(value.toString());
  } catch (_) {
    return value.runtimeType.toString();
  }
}
