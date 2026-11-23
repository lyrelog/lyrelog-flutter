// Not exported: the package's own plumbing.
// ignore_for_file: public_member_api_docs

/// The `exception` event every Lyrelog SDK sends, built from a Dart error and its stack.
library;

import 'package:flutter/foundation.dart';

import 'values.dart';

/// Frames kept from a stack, like the Android SDK.
const int maxFrames = 60;

/// Each frame or text is cut to this many characters.
const int maxTextLength = 1024;

/// Uncaught errors: at most this many a minute...
const int uncaughtPerMinute = 10;

/// ...and the same error (type, message, top frame) only once in this window. The same flood
/// guard as the JavaScript SDK: a layout error can repeat on every frame.
const Duration uncaughtRepeat = Duration(seconds: 10);

class ExceptionEvent {
  ExceptionEvent(this.attrs, this.payload);

  final Map<String, Object?> attrs;
  final Map<String, Object?> payload;
}

ExceptionEvent exceptionEvent(
  Object error,
  StackTrace? stackTrace, {
  String? message,
  String? library,
  String? context,
}) {
  final text = message ?? describe(error);
  final payload = <String, Object?>{'description': cut(text)};
  if (library != null) payload['library'] = cut(library);
  if (context != null) payload['context'] = cut(context);
  final frames = framesOf(stackTrace ?? (error is Error ? error.stackTrace : null));
  if (frames.isNotEmpty) {
    payload['frames'] = frames.length > maxFrames ? frames.sublist(0, maxFrames) : frames;
    if (frames.length > maxFrames) payload['frames_omitted'] = frames.length - maxFrames;
  }
  return ExceptionEvent({'error_type': typeName(error), 'error_message': text}, payload);
}

/// The class name as the VM knows it; in an obfuscated build, the obfuscated name.
String typeName(Object error) {
  try {
    return error.runtimeType.toString();
  } catch (_) {
    return 'Object';
  }
}

/// `toString` can be overridden and throw; the event is kept anyway.
String describe(Object error) {
  try {
    return error.toString();
  } catch (_) {
    return typeName(error);
  }
}

List<String> framesOf(StackTrace? stackTrace) {
  if (stackTrace == null) return const [];
  final String text;
  try {
    text = stackTrace.toString();
  } catch (_) {
    return const [];
  }
  return [
    for (final line in text.split('\n'))
      if (line.trim().isNotEmpty) cut(line.trimRight()),
  ];
}

String cut(String text) => cutString(text, maxTextLength);

/// Admits at most [uncaughtPerMinute] uncaught errors a minute, and the same one once per
/// [uncaughtRepeat].
class FloodGuard {
  FloodGuard({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final List<DateTime> _times = [];
  final Map<String, DateTime> _seen = {};
  int skipped = 0;

  bool admit(String fingerprint) {
    final now = _now();
    _times.removeWhere((t) => now.difference(t) >= const Duration(minutes: 1));
    _seen.removeWhere((_, at) => now.difference(at) >= uncaughtRepeat);
    if (_seen.containsKey(fingerprint) || _times.length >= uncaughtPerMinute) {
      skipped += 1;
      return false;
    }
    _seen[fingerprint] = now;
    _times.add(now);
    return true;
  }

  @visibleForTesting
  void reset() {
    _times.clear();
    _seen.clear();
    skipped = 0;
  }
}

String fingerprint(ExceptionEvent event) {
  final frames = event.payload['frames'];
  final top = frames is List && frames.isNotEmpty ? frames.first : '';
  return '${event.attrs['error_type']}|${event.attrs['error_message']}|$top';
}
