import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'configuration.dart';
import 'errors.dart';
import 'messages.g.dart';
import 'values.dart';

/// Lyrelog: structured logs from your Flutter app to Lyrelog, a hosted log service.
///
/// ```dart
/// void main() {
///   Lyrelog.start(const LyrelogConfiguration(apiKey: 'lyr_ing_...'));
///   runApp(const MyApp());
/// }
///
/// Lyrelog.setUser('player-123');
/// Lyrelog.info('level_cleared', attrs: {'level': 12, 'moves': 31});
/// final store = Lyrelog.logger('store');
/// store.warning('purchase_retry', attrs: {'attempt': 2});
/// ```
///
/// A thin layer over the native SDKs (Swift on iOS, Kotlin on Android): they keep events on
/// disk, batch, retry, capture native crashes, keep sessions and consent and verify the app.
/// Logging never blocks and never throws: the event is handed to the native SDK and the call
/// returns. Events logged before [start] are ignored; [setUser] and [setConsent] before [start]
/// are kept and applied when it runs.
abstract final class Lyrelog {
  /// This package's version, named in `resource.sdk` before the native SDK's
  /// (`lyrelog-flutter/1.0.0 lyrelog-swift/1.0.0`).
  static const String version = '1.0.0';

  static LyrelogHostApi _api = LyrelogHostApi();
  static bool _started = false;
  static LogLevel _minimumLevel = LogLevel.debug;
  static bool _captureErrors = false;
  static bool _handlersInstalled = false;
  static FloodGuard _flood = FloodGuard();

  /// A `stop` the native SDK is still finishing (its last upload, up to 2 seconds). Calls made
  /// meanwhile wait for it: a `start` reaching the native SDK before the stop is over would be
  /// ignored as a second start, and the stop would then leave it off.
  static Future<void>? _stopping;

  /// Start once, as early as possible: in `main`, before `runApp`. A second call while running
  /// is ignored. Calls `WidgetsFlutterBinding.ensureInitialized()`, so it can come first.
  ///
  /// With [LyrelogConfiguration.captureErrors] (the default) it also reports Dart errors nobody
  /// caught, from `FlutterError.onError` and `PlatformDispatcher.instance.onError`; the handlers
  /// that were there before keep running after it.
  ///
  /// Nothing needs to wait for the returned future: calls made after `start` reach the native
  /// SDK after it.
  static Future<void> start(LyrelogConfiguration configuration) {
    if (_started) return Future.value();
    _started = true;
    _minimumLevel = configuration.minimumLevel;
    _captureErrors = configuration.captureErrors;
    try {
      WidgetsFlutterBinding.ensureInitialized();
      if (configuration.captureErrors) _installErrorHandlers();
    } catch (_) {
      // never throws
    }
    return _send(() => _api.start(_startMessage(configuration)));
  }

  /// Sends what was logged (waiting at most 2 seconds), then stops; [start] can be called
  /// again afterwards. What couldn't be sent stays on the device for the next launch.
  static Future<void> stop() {
    if (!_started) return Future.value();
    _started = false;
    _captureErrors = false;
    final stopping = _send(() => _api.stop());
    _stopping = stopping;
    // Registered first, so it runs before the calls queued behind the stop, in their order.
    stopping.whenComplete(() {
      if (identical(_stopping, stopping)) _stopping = null;
    });
    return stopping;
  }

  /// Writes everything logged so far to the device's queue and tries to send it now. Rarely
  /// needed: going to the background already sends. True when it finished within [timeout].
  static Future<bool> flush({Duration timeout = const Duration(seconds: 5)}) async {
    if (!_started) return false;
    try {
      // After the `start` queued behind a stop, like every other call.
      await _stopping;
      return await _api.flush(timeout.inMilliseconds);
    } catch (_) {
      return false;
    }
  }

  /// Your own player or account id on every following event; `null` clears it. Before
  /// [start], it applies from the start.
  static void setUser(String? id) {
    _send(() => _api.setUser(id));
  }

  /// The person's choice, applied at once: a denial deletes what is on the device (and the
  /// install id) and records nothing more. Before [start], it wins over
  /// [LyrelogConfiguration.consent].
  static void setConsent(Consent consent) {
    _send(() => _api.setConsent(ConsentMessage.values[consent.index]));
  }

  /// Says which screen the person is on: logs `screen_viewed` (area `navigation`, with the
  /// screen before and the seconds spent on it) and, unless `attachScreen` is off, tags every
  /// following event with `screen`. The same name twice logs nothing.
  /// [LyrelogNavigatorObserver] calls it for each route.
  static void screen(String name, {Map<String, Object?>? attrs}) {
    if (!_started || name.isEmpty) return;
    _send(() => _api.screen(name, encodeAttributes(attrs)));
  }

  /// The current session id, e.g. to show in a support screen.
  static Future<String?> sessionId() async {
    try {
      return await _api.sessionId();
    } catch (_) {
      return null;
    }
  }

  /// A logger for one area of the app; every event it records carries [category].
  static LyrelogLogger logger(String category) => LyrelogLogger(category);

  /// Records one event: [message] is a short, stable name (`level_cleared`, not a sentence),
  /// [attrs] the small fields to filter and chart by, [payload] anything larger (any JSON-like
  /// value, kept but not searchable). Below [LyrelogConfiguration.minimumLevel], or before
  /// [start], nothing is done. Values the channel can't carry become text (see the README);
  /// the native SDK fits the event to the server's limits and redacts secrets.
  static void log(
    LogLevel level,
    String message, {
    String? category,
    Map<String, Object?>? attrs,
    Object? payload,
  }) {
    if (!_started || level.index < _minimumLevel.index) return;
    _send(() {
      return _api.log(
        LevelMessage.values[level.index],
        cutString(message),
        category,
        encodeAttributes(attrs),
        encodeValue(payload),
      );
    });
  }

  /// [log] at [LogLevel.trace].
  static void trace(String message, {String? category, Map<String, Object?>? attrs, Object? payload}) =>
      log(LogLevel.trace, message, category: category, attrs: attrs, payload: payload);

  /// [log] at [LogLevel.debug].
  static void debug(String message, {String? category, Map<String, Object?>? attrs, Object? payload}) =>
      log(LogLevel.debug, message, category: category, attrs: attrs, payload: payload);

  /// [log] at [LogLevel.info].
  static void info(String message, {String? category, Map<String, Object?>? attrs, Object? payload}) =>
      log(LogLevel.info, message, category: category, attrs: attrs, payload: payload);

  /// [log] at [LogLevel.notice].
  static void notice(String message, {String? category, Map<String, Object?>? attrs, Object? payload}) =>
      log(LogLevel.notice, message, category: category, attrs: attrs, payload: payload);

  /// [log] at [LogLevel.warning].
  static void warning(String message, {String? category, Map<String, Object?>? attrs, Object? payload}) =>
      log(LogLevel.warning, message, category: category, attrs: attrs, payload: payload);

  /// [log] at [LogLevel.error].
  static void error(String message, {String? category, Map<String, Object?>? attrs, Object? payload}) =>
      log(LogLevel.error, message, category: category, attrs: attrs, payload: payload);

  /// [log] at [LogLevel.critical].
  static void critical(String message, {String? category, Map<String, Object?>? attrs, Object? payload}) =>
      log(LogLevel.critical, message, category: category, attrs: attrs, payload: payload);

  /// The `exception` event every Lyrelog SDK sends: level `error`, attributes `error_type`
  /// (the runtime type) and `error_message` (its `toString()`), and a payload with the
  /// description and up to 60 frames of [stackTrace] (or of the error's own, for an [Error]).
  /// Your [attrs] are added; theirs win.
  ///
  /// For an error nobody caught that you report yourself (a zone's handler, an isolate's
  /// error port), pass `handled: false` and a [mechanism]; the event then carries both, like
  /// the ones Lyrelog reports on its own.
  static void captureError(
    Object error, {
    StackTrace? stackTrace,
    String? category,
    Map<String, Object?>? attrs,
    LogLevel level = LogLevel.error,
    bool handled = true,
    String? mechanism,
  }) {
    if (!_started) return;
    try {
      final built = exceptionEvent(error, stackTrace);
      _exception(built, level: level, category: category, attrs: attrs, handled: handled, mechanism: mechanism);
    } catch (_) {
      // never throws
    }
  }

  static void _exception(
    ExceptionEvent built, {
    required LogLevel level,
    String? category,
    Map<String, Object?>? attrs,
    bool handled = true,
    String? mechanism,
  }) {
    final attributes = <String, Object?>{...?attrs, ...built.attrs};
    if (!handled) {
      attributes['handled'] = false;
      attributes['mechanism'] = mechanism ?? 'manual';
    }
    log(level, 'exception', category: category, attrs: attributes, payload: built.payload);
  }

  // MARK: - Uncaught Dart errors

  static void _installErrorHandlers() {
    if (_handlersInstalled) return;
    _handlersInstalled = true;

    final previousFlutter = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      _flutterError(details);
      previousFlutter?.call(details);
    };

    final dispatcher = PlatformDispatcher.instance;
    final previousDispatcher = dispatcher.onError;
    dispatcher.onError = (Object error, StackTrace stack) {
      _uncaught(exceptionEvent(error, stack), 'platform_dispatcher');
      // The engine's default (print it) unless an earlier handler says it handled it.
      return previousDispatcher?.call(error, stack) ?? false;
    };
  }

  static void _flutterError(FlutterErrorDetails details) {
    // `silent` errors are the ones Flutter itself doesn't report in release builds (an image
    // that failed to load, for one).
    if (details.silent) return;
    try {
      final built = exceptionEvent(
        details.exception,
        details.stack,
        message: details.exceptionAsString(),
        library: details.library,
        context: details.context?.toDescription(),
      );
      _uncaught(built, 'flutter_error');
    } catch (_) {
      // never throws
    }
  }

  static void _uncaught(ExceptionEvent built, String mechanism) {
    try {
      if (!_started || !_captureErrors) return;
      if (!_flood.admit(fingerprint(built))) return;
      _exception(built, level: LogLevel.error, handled: false, mechanism: mechanism);
    } catch (_) {
      // never throws
    }
  }

  // MARK: - Plumbing

  /// Every channel call: errors (no native side in a test, a platform without the plugin)
  /// are swallowed.
  static Future<void> _send(Future<void> Function() call) {
    final stopping = _stopping;
    if (stopping != null) return stopping.then((_) => _send(call));
    try {
      return call().catchError((Object _) {});
    } catch (_) {
      return Future.value();
    }
  }

  static StartMessage _startMessage(LyrelogConfiguration c) => StartMessage(
    apiKey: c.apiKey,
    endpoint: c.endpoint,
    consent: ConsentMessage.values[c.consent.index],
    minimumLevel: LevelMessage.values[c.minimumLevel.index],
    flushIntervalMs: c.flushInterval.inMilliseconds,
    maxBatchBytes: c.maxBatchBytes,
    maxBatchEvents: c.maxBatchEvents,
    maxDiskBytes: c.maxDiskBytes,
    maxEventAgeMs: c.maxEventAge.inMilliseconds,
    sessionTimeoutMs: c.sessionTimeout.inMilliseconds,
    environment: c.environment,
    platform: c.platform,
    redactedKeys: c.redactedKeys,
    captureNativeCrashes: c.captureNativeCrashes,
    attachScreen: c.attachScreen,
    attest: c.attest,
    mirrorToConsole: c.mirrorToConsole,
    pauseUploadsInLowPowerMode: c.pauseUploadsInLowPowerMode,
  );

  /// Forgets everything Lyrelog knows in Dart, for tests. Error handlers stay installed (they
  /// do nothing until the next start).
  @visibleForTesting
  static void debugReset({LyrelogHostApi? api}) {
    _api = api ?? LyrelogHostApi();
    _started = false;
    _captureErrors = false;
    _minimumLevel = LogLevel.debug;
    _flood = FloodGuard();
    _stopping = null;
  }

  /// Uncaught errors the flood guard kept out since start.
  @visibleForTesting
  static int get debugSkippedErrors => _flood.skipped;
}

/// A logger for one area of the app: every event it records carries [category], like a log
/// tag or OSLog's category. Get one with `Lyrelog.logger('checkout')`. Cheap to make and keep;
/// it logs into whatever SDK is running when it is called (nothing before `start`).
class LyrelogLogger {
  /// A logger whose events carry [category]; the same as [Lyrelog.logger].
  const LyrelogLogger(this.category);

  /// The area of the app every event from this logger carries.
  final String category;

  /// [Lyrelog.log] in this logger's category.
  void log(LogLevel level, String message, {Map<String, Object?>? attrs, Object? payload}) =>
      Lyrelog.log(level, message, category: category, attrs: attrs, payload: payload);

  /// [log] at [LogLevel.trace].
  void trace(String message, {Map<String, Object?>? attrs, Object? payload}) =>
      log(LogLevel.trace, message, attrs: attrs, payload: payload);

  /// [log] at [LogLevel.debug].
  void debug(String message, {Map<String, Object?>? attrs, Object? payload}) =>
      log(LogLevel.debug, message, attrs: attrs, payload: payload);

  /// [log] at [LogLevel.info].
  void info(String message, {Map<String, Object?>? attrs, Object? payload}) =>
      log(LogLevel.info, message, attrs: attrs, payload: payload);

  /// [log] at [LogLevel.notice].
  void notice(String message, {Map<String, Object?>? attrs, Object? payload}) =>
      log(LogLevel.notice, message, attrs: attrs, payload: payload);

  /// [log] at [LogLevel.warning].
  void warning(String message, {Map<String, Object?>? attrs, Object? payload}) =>
      log(LogLevel.warning, message, attrs: attrs, payload: payload);

  /// [log] at [LogLevel.error].
  void error(String message, {Map<String, Object?>? attrs, Object? payload}) =>
      log(LogLevel.error, message, attrs: attrs, payload: payload);

  /// [log] at [LogLevel.critical].
  void critical(String message, {Map<String, Object?>? attrs, Object? payload}) =>
      log(LogLevel.critical, message, attrs: attrs, payload: payload);

  /// [Lyrelog.captureError] in this logger's category.
  void captureError(
    Object error, {
    StackTrace? stackTrace,
    Map<String, Object?>? attrs,
    LogLevel level = LogLevel.error,
  }) => Lyrelog.captureError(error, stackTrace: stackTrace, category: category, attrs: attrs, level: level);
}
