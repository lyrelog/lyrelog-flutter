import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lyrelog/src/messages.g.dart';

/// One call that reached the native side: the method and its decoded arguments.
class HostCall {
  HostCall(this.method, this.args);

  final String method;
  final List<Object?> args;

  @override
  String toString() => 'HostCall($method, $args)';
}

/// Answers every `LyrelogHostApi` channel the way the native plugins do, through the real
/// Pigeon codec, and records what Dart sent.
class FakeHost {
  FakeHost() {
    for (final method in methods) {
      final channel = 'dev.flutter.pigeon.lyrelog.LyrelogHostApi.$method';
      _messenger.setMockMessageHandler(channel, (ByteData? message) async {
        final args = codec.decodeMessage(message) as List<Object?>? ?? const [];
        calls.add(HostCall(method, args));
        // The native SDKs: a start while running is ignored, and stop ends the SDK only once its
        // last upload is over (up to 2 s), handled off the thread that takes the next call.
        if (method == 'start' && !running) running = true;
        if (method == 'stop') {
          await holdStop?.future;
          running = false;
        }
        if (failing) {
          return codec.encodeMessage(<Object?>['error', 'boom', null]);
        }
        return codec.encodeMessage(<Object?>[_answer(method)]);
      });
    }
  }

  static const methods = ['start', 'log', 'setUser', 'setConsent', 'screen', 'sessionId', 'flush', 'stop'];
  static const codec = LyrelogHostApi.pigeonChannelCodec;

  final List<HostCall> calls = [];

  /// Every call answers with a platform error, as a broken native side would.
  bool failing = false;

  String? sessionId = 'session-1';

  /// Whether the native SDK would be running now.
  bool running = false;

  /// While set, a `stop` doesn't finish until it completes, as a native stop sending its last
  /// batch.
  Completer<void>? holdStop;

  BinaryMessenger get messengerForTests => _messenger;

  TestDefaultBinaryMessenger get _messenger => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Object? _answer(String method) => switch (method) {
    'sessionId' => sessionId,
    'flush' => true,
    _ => null,
  };

  List<HostCall> of(String method) => calls.where((c) => c.method == method).toList();

  /// The `log` calls as (level, message, category, attrs, payload).
  List<HostCall> get logs => of('log');

  void dispose() {
    for (final method in methods) {
      _messenger.setMockMessageHandler('dev.flutter.pigeon.lyrelog.LyrelogHostApi.$method', null);
    }
  }
}

/// Lets queued channel messages arrive.
Future<void> settle() => Future<void>.delayed(Duration.zero);
