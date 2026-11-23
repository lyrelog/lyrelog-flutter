<p align="center">
  <a href="https://lyrelog.com">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://lyrelog.com/readme/flutter-dark.png">
      <img alt="Lyrelog for Flutter" src="https://lyrelog.com/readme/flutter-light.png" width="600">
    </picture>
  </a>
</p>

<p align="center">
  <a href="https://docs.lyrelog.com/sdks/flutter"><b>Documentation</b></a> ·
  <a href="https://docs.lyrelog.com/quickstart">Quickstart</a> ·
  <a href="https://lyrelog.com">lyrelog.com</a>
</p>

Structured logs from your Flutter app to [Lyrelog](https://lyrelog.com), a hosted log service.
iOS 16 and Android 7.0 (API 24) and later, Flutter 3.44 (Dart 3.12) or newer. A thin Dart layer over the native Lyrelog SDKs (Swift
on iOS, Kotlin on Android), so the disk queue, native crash capture, the background flush,
sessions, consent and verified events are theirs. Dart errors nobody caught are reported too.

## Install

From pub.dev:

```yaml
dependencies:
  lyrelog: ^0.9.0
```

### iOS

- **Swift Package Manager must be on**: the plugin brings the Swift SDK as a Swift package. It is
  Flutter's default since 3.44; if you turned it off, `flutter config
  --enable-swift-package-manager` turns it back on. There is no CocoaPods spec (the Swift SDK
  has none).
- **iOS 16** as the app's minimum (the Swift SDK's): set `IPHONEOS_DEPLOYMENT_TARGET = 16.0` in
  `ios/Runner.xcodeproj` (Runner target, General, Minimum Deployments).

### Android

- Flutter's defaults work (compileSdk 36, Kotlin 2.2 or newer); `minSdk` can stay at 24.
- `com.lyrelog:lyrelog-android` comes from Maven Central, which Flutter's template already lists.

The Android library adds the `INTERNET` permission to your app's manifest.

## Use

```dart
import 'package:lyrelog/lyrelog.dart';

void main() {
  Lyrelog.start(const LyrelogConfiguration(
    apiKey: 'lyr_ing_...',        // ingest-only: it can append events, never read them
    consent: Consent.granted,     // or Consent.pending until the person chooses
  ));                             // endpoint: https://ingest.lyrelog.com unless you pass one
  runApp(const MyApp());
}

Lyrelog.setUser(readerId);        // optional; attached to every following event
Lyrelog.info('book_opened', attrs: {'book_id': 'b_12', 'chapter': 7});
Lyrelog.error('sync_failed', category: 'sync', attrs: {'code': 503}, payload: {'response': raw});

try {
  await submitReview();
} catch (e, s) {
  Lyrelog.captureError(e, stackTrace: s, category: 'reviews');   // the `exception` event
}

// One logger per area of the app, like a log tag.
final library = Lyrelog.logger('library');
library.warning('download_retry', attrs: {'attempt': 2});
```

- `message`: a stable event name (`book_opened`), not prose.
- `category`: the area of the app (`library`, `sync`, `store`); the dashboard filters by it.
- `attrs`: small fields to filter and chart by: ids, durations, codes, flags. Strings, numbers,
  booleans, null, lists and nested maps up to 4 levels. A `DateTime` is sent as ISO 8601 text, a
  `Duration` as milliseconds, an enum as its name, anything else as its `toString()`. Strings
  are cut at 64 KiB, and one attrs map or payload holds at most 32,768 values (deeper than 32
  levels a list or map becomes `[...]` or `{...}`), so a log call stays cheap whatever it is
  given; the server keeps far less (see Limits below). The native side of every call runs on one
  background thread, in order, not on the platform's main thread that the UI shares.
- `payload`: the big stuff you only read when you open one event: responses, traces.

`start` calls `WidgetsFlutterBinding.ensureInitialized()`, so it can come first in `main`.
Nothing needs to wait for it: what you log after it reaches the native SDK after it. Events
logged before `start` are ignored; `setUser` and `setConsent` before `start` are kept and
applied when it runs (and that consent wins over the configuration's).

## Errors, crashes and screens

**Errors you catch**: `Lyrelog.captureError(e, stackTrace: s)` (or `logger.captureError`) logs
the `exception` event every Lyrelog SDK sends: level `error`, `error_type` (the runtime type)
and `error_message` (its `toString()`) attributes, and a payload with the description and up to
60 frames of the stack.

**Dart errors nobody catches** are reported on their own (`captureErrors`, on by default), as
`exception` with `handled: false` and a `mechanism`:

| Where Flutter hands it over | `mechanism` | Payload also has |
|---|---|---|
| `FlutterError.onError` (build, layout, paint, gestures) | `flutter_error` | `library`, `context` |
| `PlatformDispatcher.instance.onError` (async code and timers in the root zone) | `platform_dispatcher` | |

`start` installs both handlers once and keeps the ones that were there before: they still run,
after Lyrelog, and `PlatformDispatcher`'s answer is theirs (without one, the engine still prints
the error). If you set your own handlers, set them before `start`, or call `captureError` from
them. At most 10 such errors a minute are sent, and the same one (type, message, top frame) only
once every 10 seconds: a layout error can repeat on every frame. Errors Flutter marks `silent`
(it doesn't report them in release builds either) are left out. A Dart error doesn't end a
Flutter app, so these are never `app_crashed`.

For a zone of your own, report its errors the same way:

```dart
runZonedGuarded(() => runApp(const MyApp()), (error, stack) {
  Lyrelog.captureError(error, stackTrace: stack, handled: false, mechanism: 'zone');
});
```

**Native crashes** come from the native SDKs (`captureNativeCrashes`, on by default) and are
sent on the next launch, at the time they happened, as `app_crashed` (critical, area
`diagnostics`): on iOS MetricKit's crash and hang reports, on Android uncaught JVM exceptions.
Android's native (C/C++) crashes and ANRs aren't reported.

Release builds with `--obfuscate` have obfuscated type names and frames: keep the symbols
(`--split-debug-info`) and run `flutter symbolize` on the frames.

**Screens**: say where the person is and every event that follows carries it as `screen`
(`attachScreen`), plus a `screen_viewed` event with the screen before and the time spent on it.

```dart
MaterialApp(
  navigatorObservers: [LyrelogNavigatorObserver()],
  routes: {'/': (_) => const ShelfPage(), '/settings': (_) => const SettingsPage()},
)
```

The observer names each page route by its `RouteSettings.name` and skips dialogs, sheets and
unnamed routes; `nameExtractor` and `routeFilter` change both. Or call
`Lyrelog.screen('Settings')` yourself.

## What it does for you

Everything below is the native SDK's own behaviour, the same as in a Swift or Kotlin app.

| | iOS | Android |
|---|---|---|
| Never blocks | The call hands the event to the native SDK and returns; a background writer puts it on disk. | Same. |
| Keeps events across launches | Library/Caches/lyrelog, 20 MB and 7 days, oldest first. The system may purge Caches when short of space. | `noBackupFilesDir/lyrelog`, 20 MB and 7 days, never in a backup. |
| When it sends | Every 15 s in the foreground (`flushInterval`, at least 1 s; paused in Low Power Mode), and when the app goes to the background, inside a background task. | Every 15 s while the app's Activity is started (`flushInterval`, at least 1 s), and when it goes to the background. |
| Batches and retries | Up to 500 events or 512 KiB per request, gzip. Backoff from 1 s doubling to 5 min with full jitter, honouring `Retry-After` (at most 1 hour). A refused batch (4xx) is dropped; a revoked key stops sending until the next launch and keeps the data; redirects are never followed. | Same. |
| Monthly quota | A `429` with `plan` waits for its `Retry-After` but isn't counted as a failed attempt (the backoff doesn't grow), plus one warning in the unified log. | The same, the warning in logcat. |
| Network down | After 3 failed uploads in a row, one warning in the unified log, then nothing until an upload goes through. | The same, in logcat. |
| Consent | `pending` keeps events on the device, `granted` sends them, `denied` deletes everything queued and the install id. Nothing is uploaded unless consent is granted. | Same. |
| Context | App id, version, build, OS, device model, locale, environment, platform `ios`, `sdk` `lyrelog-flutter/0.9.0 lyrelog-swift/0.9.0`, a session id (new after 30 min idle) and an install id. | The same with platform `android` and `sdk` `lyrelog-flutter/0.9.0 lyrelog-android/0.9.0`. |
| Redacts secrets | Any field in `attrs` or `payload` whose name, lowercased and without `-`, `_`, `.` or spaces, is or ends with `authorization`, `cookie`, `password`, `passwd`, `secret`, `token`, `apikey`, `privatekey`, `credential(s)`, `accesskey` or `signature` is sent as `"[redacted]"`, before anything is cut. Only names are checked, never a message or an error's text. | Same. |
| Limits | Long strings cut on a character boundary, extra attributes counted in `lyrelog_dropped_attrs`, payloads over 64 KiB summarised. | Same. |

### Endpoint

The default is `https://ingest.lyrelog.com`. If you pass one, a pasted `.../v1/events:batch` or
`.../v1` is cut back to the origin. Only `https` is used; plain `http` only to `localhost`,
`127.0.0.1` or `::1` (the iOS simulator reaches your computer there), and on the Android
emulator to `10.0.2.2` (your computer). For `10.0.2.2` the Android debug build also needs
cleartext allowed for that address in a network security config, and on Android 17 with
targetSdk 37 the permission `android.permission.ACCESS_LOCAL_NETWORK`, declared in the debug
manifest and granted (`adb shell pm grant <your.app> android.permission.ACCESS_LOCAL_NETWORK`);
the example does both. Any other endpoint is refused: nothing is sent and the events stay on the
device.

### Environment

`environment` names it; `null` lets the native SDK detect it. iOS: `development` for a debug
build, the simulator, or a development or ad hoc signed build, `testflight` for a TestFlight
build, `production` otherwise. Android: `development` when the app is debuggable (every debug
build), `production` otherwise. Any name works: lowercase letters, digits, `-` and `_`, up to 32.

### Redaction

`redactedKeys` replaces the list (`null`, the default, is
`LyrelogConfiguration.defaultRedactedKeys`, the same in every Lyrelog SDK); an empty list turns
redaction off:

```dart
redactedKeys: [...LyrelogConfiguration.defaultRedactedKeys, 'pin'],
```

### Flush and stop

`await Lyrelog.flush()` writes everything to the device's queue and sends, waiting at most 5
seconds (`timeout:`); it's true when it finished in time. Rarely needed: going to the background
already sends. `await Lyrelog.stop()` sends what's queued (up to 2 seconds) and stops; `start`
can be called again afterwards (calls made while the stop is finishing wait for it, so
`Lyrelog.stop(); Lyrelog.start(...)` works without the `await`).

## Verified events

On real devices the native SDKs prove the app, and the server stores its events as verified
(`attest`, on by default):

- **iOS, App Attest** (`verified_by = app_attest`): add the App Attest capability to the Runner
  target in Xcode (entitlement `com.apple.developer.devicecheck.appattest-environment`,
  `production` for App Store and TestFlight builds) and the App ID (Team ID and bundle id) in the
  project's settings in Lyrelog.
- **Android, Key Attestation** (`verified_by = key_attestation`): the package name and the
  SHA-256 fingerprint of each signing certificate in the project's settings (Play Console, App
  integrity, for Play's app signing key; `./gradlew signingReport` in `android/` for builds you
  sign yourself).

Sending never waits for it. The simulator, emulators, rooted devices, unlocked bootloaders and
apps not set up send unverified events, as without it.

## Privacy

Declare what your app sends through Lyrelog as the native SDKs' READMEs describe: on the App
Store, Diagnostics (crash, performance and other diagnostic data), Identifiers > Device ID (the
install id), User ID if you call `setUser`, and Product Interaction if you log screens; on Google
Play, App info and performance, Device or other IDs, and App interactions. The Swift SDK ships
its privacy manifest, which Xcode merges into the app's privacy report. The server adds the
country of the sending address; the address itself is not stored.

## Example

`example/` is Lantern, a made-up reading app: see [example/README.md](example/README.md).

## Tests

```bash
flutter test        # the Dart layer, against a fake native side behind the real channels
flutter analyze
```

## Licence

MIT.
