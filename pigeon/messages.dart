// The contract between the Dart API and the native SDKs (lyrelog-swift, lyrelog-android).
// After editing, regenerate the three outputs:
//   dart run pigeon --input pigeon/messages.dart
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartPackageName: 'lyrelog',
    dartOut: 'lib/src/messages.g.dart',
    kotlinOut: 'android/src/main/kotlin/com/lyrelog/flutter/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.lyrelog.flutter'),
    swiftOut: 'lyrelog_ios/ios/lyrelog_ios/Sources/lyrelog_ios/Messages.g.swift',
  ),
)
enum LevelMessage { trace, debug, info, notice, warning, error, critical }

enum ConsentMessage { pending, granted, denied }

/// `LyrelogConfiguration`, flattened for the channel. Durations are milliseconds.
class StartMessage {
  StartMessage({
    required this.apiKey,
    required this.endpoint,
    required this.consent,
    required this.minimumLevel,
    required this.flushIntervalMs,
    required this.maxBatchBytes,
    required this.maxBatchEvents,
    required this.maxDiskBytes,
    required this.maxEventAgeMs,
    required this.sessionTimeoutMs,
    required this.captureNativeCrashes,
    required this.attachScreen,
    required this.attest,
    required this.mirrorToConsole,
    required this.pauseUploadsInLowPowerMode,
  });

  String apiKey;
  String endpoint;
  ConsentMessage consent;
  LevelMessage minimumLevel;
  int flushIntervalMs;
  int maxBatchBytes;
  int maxBatchEvents;
  int maxDiskBytes;
  int maxEventAgeMs;
  int sessionTimeoutMs;
  String? environment;
  String? platform;
  List<String>? redactedKeys;
  bool captureNativeCrashes;
  bool attachScreen;
  bool attest;
  bool mirrorToConsole;
  bool pauseUploadsInLowPowerMode;
}

/// Every method runs on one serial background queue of the native side, not on the platform's
/// main thread, which Flutter shares with the UI: the native work of a log call (copying the
/// event, the native SDK's lock) never takes time from a frame. One queue, so the calls keep the
/// order Dart made them in: a `flush` or a `stop` comes after the events logged before it. The
/// asynchronous ones (`flush`, `stop`) only begin there and go on elsewhere, so they never hold
/// the queue.
@HostApi()
abstract class LyrelogHostApi {
  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  void start(StartMessage configuration);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  void log(
    LevelMessage level,
    String message,
    String? category,
    Map<String, Object?>? attrs,
    Object? payload,
  );

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  void setUser(String? id);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  void setConsent(ConsentMessage consent);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  void screen(String name, Map<String, Object?>? attrs);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  String? sessionId();

  /// Writes everything to disk and sends. True when it finished within the timeout; the flush
  /// carries on after it.
  @async
  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  bool flush(int timeoutMs);

  /// Sends what's queued (up to 2 seconds), then stops.
  @async
  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  void stop();
}
