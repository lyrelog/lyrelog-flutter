import 'lyrelog.dart';

/// How serious an event is. The same seven levels in every Lyrelog SDK, in this order.
enum LogLevel {
  /// The finest detail, usually off.
  trace,

  /// What a developer needs to follow the flow.
  debug,

  /// Something worth knowing happened.
  info,

  /// Normal but significant.
  notice,

  /// Something went wrong and was recovered from.
  warning,

  /// Something failed.
  error,

  /// The app can't go on as it should.
  critical,
}

/// Whether the person agreed to send diagnostics.
///
/// [pending] keeps events on the device without sending them, [granted] sends them (and those
/// kept while pending), [denied] deletes everything queued and the install id, and records
/// nothing until consent changes.
enum Consent {
  /// Not asked yet: events are kept on the device, not sent.
  pending,

  /// Events are sent, those kept while pending too.
  granted,

  /// Nothing is recorded; what was on the device is deleted.
  denied,
}

/// Everything Lyrelog can be told at start. Only [apiKey] is required; the rest has the native
/// SDKs' defaults (a mobile SDK with an on-disk queue).
class LyrelogConfiguration {
  /// A configuration with the native SDKs' defaults for everything but [apiKey].
  const LyrelogConfiguration({
    required this.apiKey,
    this.endpoint = defaultEndpoint,
    this.consent = Consent.granted,
    this.minimumLevel = LogLevel.debug,
    this.flushInterval = const Duration(seconds: 15),
    this.maxBatchBytes = 512 * 1024,
    this.maxBatchEvents = 500,
    this.maxDiskBytes = 20 * 1024 * 1024,
    this.maxEventAge = const Duration(days: 7),
    this.sessionTimeout = const Duration(minutes: 30),
    this.environment,
    this.platform,
    this.redactedKeys,
    this.captureErrors = true,
    this.captureNativeCrashes = true,
    this.attachScreen = true,
    this.attest = true,
    this.mirrorToConsole = false,
    this.pauseUploadsInLowPowerMode = true,
  });

  /// The hosted ingest, used when no endpoint is given.
  static const String defaultEndpoint = 'https://ingest.lyrelog.com';

  /// What `redactedKeys: null` redacts, the same list in every Lyrelog SDK.
  static const List<String> defaultRedactedKeys = [
    'authorization',
    'cookie',
    'password',
    'passwd',
    'secret',
    'token',
    'apikey',
    'privatekey',
    'credential',
    'credentials',
    'accesskey',
    'signature',
  ];

  /// The project's ingest key (`lyr_ing_...`). It can only append events, so it is fine
  /// inside the app.
  final String apiKey;

  /// The ingest origin. A pasted `.../v1/events:batch` or `.../v1` is cut back. `https` only;
  /// plain `http` only to `localhost`, `127.0.0.1`, `::1`, and on the Android emulator to
  /// `10.0.2.2`. Any other endpoint is refused: nothing is sent, events stay on the device.
  final String endpoint;

  /// The person's choice at start ([Consent.granted] unless you ask first). A
  /// [Lyrelog.setConsent] made before start wins over it.
  final Consent consent;

  /// Events below this level are dropped before they reach the device's queue.
  final LogLevel minimumLevel;

  /// How often the uploader runs while the app is in the foreground. At least 1 second: the
  /// native SDKs raise anything smaller to it.
  final Duration flushInterval;

  /// A batch (one file, one request) closes at whichever comes first of [maxBatchBytes] and
  /// [maxBatchEvents]; kept within 2,000 events and 4 MiB.
  final int maxBatchBytes;

  /// See [maxBatchBytes].
  final int maxBatchEvents;

  /// Hard cap on the bytes waiting on the device; the oldest go first.
  final int maxDiskBytes;

  /// Events older than this are dropped from the device without being sent.
  final Duration maxEventAge;

  /// A new session starts after this long without any event.
  final Duration sessionTimeout;

  /// Which environment these events belong to. `null` detects it natively: on iOS
  /// `development` (debug builds, the simulator, development and ad hoc signing),
  /// `testflight` or `production`; on Android `development` when the app is debuggable,
  /// `production` otherwise. Any name works: lowercase letters, digits, `-` and `_`, up to 32.
  final String? environment;

  /// Which part of the product sends these events. `null` is the OS: `ios` or `android`.
  final String? platform;

  /// Field names whose values are sent as `"[redacted]"`, in attrs and payload at any depth.
  /// `null` is [defaultRedactedKeys]; your list replaces it (add with
  /// `[...LyrelogConfiguration.defaultRedactedKeys, 'pin']`); an empty list turns redaction off.
  final List<String>? redactedKeys;

  /// Report Dart errors nobody caught (`FlutterError.onError` and
  /// `PlatformDispatcher.instance.onError`) as `exception` with `handled: false`. The handlers
  /// that were there before still run.
  final bool captureErrors;

  /// Native crashes: on iOS MetricKit's crash and hang reports, on Android uncaught JVM
  /// exceptions. Both are sent on the next launch as `app_crashed` (area `diagnostics`).
  final bool captureNativeCrashes;

  /// Tag every event with the screen set by [Lyrelog.screen] (`screen` attribute).
  final bool attachScreen;

  /// Verified events: App Attest on iOS, Key Attestation on Android. Needs the app set up in
  /// the project's settings; never delays an event.
  final bool attest;

  /// Also print every event to the native log (Xcode's console and Console on iOS, logcat
  /// on Android).
  final bool mirrorToConsole;

  /// iOS only: periodic uploads pause in Low Power Mode; going to the background still sends.
  final bool pauseUploadsInLowPowerMode;

  /// The key never shows in a log that prints the configuration.
  @override
  String toString() =>
      'LyrelogConfiguration(endpoint: $endpoint, consent: ${consent.name}, '
      'environment: $environment, platform: $platform, apiKey: <redacted>)';
}
