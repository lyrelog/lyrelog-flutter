## 1.0.5

- Over the Swift SDK 1.1.2, whose crash reporter is fixed: `start` after `stop`, crashes MetricKit
  reports that it didn't catch, other crash reporters' handlers.
- The README's upload command saves the obfuscation map inside the symbols' folder, which every
  CLI from 1.7.0 reads.
- The example app's Xcode project signs with no team: pick yours to run it on a device.
- `lyrelog_ios` 1.0.5: over the Swift SDK 1.1.2.

## 1.0.4

- Readable release stacks: a build's Dart symbols (`--split-debug-info`) and obfuscation map,
  uploaded with `lyrelog symbols upload`, turn its Dart frames and obfuscated types back into
  your code on Lyrelog. The README says how. No change to the Dart API.
- `lyrelog_ios` 1.0.4: no change but its version, in step.

## 1.0.3

- Over the Android SDK 1.1.1: a native crash names the app's own libraries, so Lyrelog asks only
  for their symbols (`lyrelog symbols upload`), never Android's. The Dart API is unchanged.
- `lyrelog_ios` 1.0.3: no change but its version, in step.

## 1.0.2

- Over the Android SDK 1.1.0: ANRs and native (C/C++) crashes, the Flutter engine's included, are
  reported on the next launch from Android's own records (Android 11+; a native crash's frames
  from Android 12). The Dart API is unchanged.
- `lyrelog_ios` 1.0.2: no change but its version, in step.

## 1.0.1

- Over the Swift SDK 1.1.1: iOS crashes are caught in the app's own process the moment they
  happen and sent on the next launch, instead of waiting for MetricKit (which can take hours).
  `resource.sdk` is `lyrelog-flutter/1.0.1 lyrelog-swift/1.1.1` (or `... lyrelog-android/1.0.0`).
  The Dart API is unchanged.
- `lyrelog_ios` 1.0.1, over the Swift SDK from 1.1.1 up to (not including) 2.0.0.

## 1.0.0

- Version 1.0.0, over the Swift and Android SDKs 1.0.0 (`resource.sdk` is
  `lyrelog-flutter/1.0.0 lyrelog-swift/1.0.0` or `... lyrelog-android/1.0.0`). The Dart API is
  the same as 0.9.0.
- `lyrelog_ios` 1.0.0, over the Swift SDK from 1.0.0 up to (not including) 2.0.0.

## 0.9.0

- Version 0.9.0, over the Swift and Android SDKs 0.9.0 (`resource.sdk` is
  `lyrelog-flutter/0.9.0 lyrelog-swift/0.9.0` or `... lyrelog-android/0.9.0`).
- The native side of every call runs on one serial background queue (Pigeon's `@TaskQueue`),
  not on the platform's main thread that the UI shares, in the order Dart made the calls.
- Needs Flutter 3.44 (Dart 3.12) or newer, down from 3.50 (Dart 3.14). iOS needs Swift Package
  Manager on (Flutter's default since 3.44); there is no podspec.
- From the native SDKs: `Retry-After` capped at 1 hour, `flushInterval` at least 1 second, a
  monthly quota `429` no longer counted as a failed attempt, and one warning when uploads keep
  failing (3 in a row).
- Metadata: homepage https://lyrelog.com, repository and issues on github.com/lyrelog; licence
  `Copyright (c) 2026 Lyrelog`.

## 0.1.0

- First version (never published): `Lyrelog.start`, the seven levels, area loggers,
  `setUser`, `setConsent`, `screen` and `LyrelogNavigatorObserver`, `captureError`, `flush`,
  `stop`, `sessionId`, over the Lyrelog Swift SDK on iOS and the Android SDK.
- Dart errors nobody caught (`FlutterError.onError`, `PlatformDispatcher.instance.onError`)
  sent as `exception` with `handled: false` and `mechanism` `flutter_error` or
  `platform_dispatcher`, at most 10 a minute and the same one once per 10 seconds. The handlers
  that were there before keep running.
- A log call stays cheap whatever it is given: strings cut at 64 KiB, at most 32,768 values per
  attrs map or payload, and a value that holds another many times over is never walked or
  printed out in full.
- `start` right after `stop`, without awaiting it, leaves the SDK running (calls wait for the
  stop to finish).
- iOS: `flush(timeout:)` answers when the time is up, as on Android, even while the flush goes
  on.
