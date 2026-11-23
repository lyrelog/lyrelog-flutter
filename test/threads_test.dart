import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The native side of every call runs on one serial background queue, never on the platform main
// thread the UI shares. That's decided in the Pigeon contract and carried out by the generated
// code and the plugins; these checks read the sources (run from the package root, as
// `flutter test` does), since a Dart test can't see a native thread.

String read(String path) => File(path).readAsStringSync();

const contract = 'pigeon/messages.dart';
const kotlinMessages = 'android/src/main/kotlin/com/lyrelog/flutter/Messages.g.kt';
const kotlinPlugin = 'android/src/main/kotlin/com/lyrelog/flutter/LyrelogPlugin.kt';
const swiftMessages = 'lyrelog_ios/ios/lyrelog_ios/Sources/lyrelog_ios/Messages.g.swift';
const swiftPlugin = 'lyrelog_ios/ios/lyrelog_ios/Sources/lyrelog_ios/LyrelogIosPlugin.swift';

/// The host API's methods, each with the annotations written above it.
Map<String, String> hostMethods() {
  final source = read(contract);
  final body = RegExp(r'@HostApi\(\)\s*abstract class LyrelogHostApi \{([\s\S]*?)\n\}').firstMatch(source);
  expect(body, isNotNull, reason: 'no LyrelogHostApi in $contract');
  final methods = <String, String>{};
  // A method: its doc comments and annotations, then `Type name(`.
  final method = RegExp(r'((?:\s*(?:///.*|@\w+(?:\([^)]*\))?)\n)*)\s*[\w<>?]+ (\w+)\(');
  for (final match in method.allMatches(body!.group(1)!)) {
    methods[match.group(2)!] = match.group(1)!;
  }
  return methods;
}

void main() {
  test('every host method is on the serial background queue', () {
    final methods = hostMethods();
    expect(methods.keys, containsAll(['start', 'log', 'setUser', 'setConsent', 'screen', 'sessionId', 'flush', 'stop']));
    for (final MapEntry(:key, :value) in methods.entries) {
      expect(value, contains('@TaskQueue(type: TaskQueueType.serialBackgroundThread)'), reason: key);
    }
  });

  test('Android: every channel is made with the background task queue', () {
    final source = read(kotlinMessages);
    expect(source, contains('val taskQueue = binaryMessenger.makeBackgroundTaskQueue()'));
    final channels = RegExp(r'BasicMessageChannel<Any\?>\(binaryMessenger, "dev\.flutter\.pigeon\.lyrelog\.LyrelogHostApi\.(\w+)[^)]*\)')
        .allMatches(source)
        .toList();
    expect(channels.map((m) => m.group(1)), containsAll(hostMethods().keys));
    for (final channel in channels) {
      expect(channel.group(0), endsWith('codec, taskQueue)'), reason: channel.group(1));
    }
    // The suspending ones begin on that thread and never hop to the main one.
    expect(source, isNot(contains('Dispatchers.Main')));
    expect(read(kotlinPlugin), isNot(contains('Dispatchers.Main')));
  });

  test('iOS: every channel is made with the background task queue', () {
    final source = read(swiftMessages);
    expect(source, contains('let taskQueue = binaryMessenger.makeBackgroundTaskQueue?()'));
    final channels = RegExp(r': FlutterBasicMessageChannel\(name: "dev\.flutter\.pigeon\.lyrelog\.LyrelogHostApi\.(\w+)[^\n]*')
        .allMatches(source)
        .toList();
    expect(channels.map((m) => m.group(1)), containsAll(hostMethods().keys));
    for (final channel in channels) {
      expect(channel.group(0), endsWith('taskQueue: taskQueue)'), reason: channel.group(1));
    }
  });

  test('iOS: the plugin is not bound to the main actor', () {
    // A main-actor plugin would run `flush` and `stop` (async) on the main thread, and its sync
    // methods would be called off the actor it claims.
    final source = read(swiftPlugin);
    expect(source, isNot(contains('@MainActor')));
    expect(source, isNot(contains('DispatchQueue.main')));
    expect(source, isNot(contains('MainActor.run')));
  });
}
