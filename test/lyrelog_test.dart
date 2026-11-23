import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lyrelog/lyrelog.dart';
import 'package:lyrelog/src/messages.g.dart';
import 'package:lyrelog/src/values.dart';

import 'fake_host.dart';

enum Tile { red }

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeHost host;

  // The handlers Lyrelog finds when it installs its own (once per process), to check it chains.
  final flutterErrorsSeen = <FlutterErrorDetails>[];
  final dispatcherErrorsSeen = <Object>[];
  FlutterError.onError = flutterErrorsSeen.add;
  PlatformDispatcher.instance.onError = (error, stack) {
    dispatcherErrorsSeen.add(error);
    return true;
  };

  setUp(() {
    host = FakeHost();
    Lyrelog.debugReset();
    host.running = false;
    flutterErrorsSeen.clear();
    dispatcherErrorsSeen.clear();
  });

  tearDown(() => host.dispose());

  Future<void> start([LyrelogConfiguration? configuration]) async {
    await Lyrelog.start(configuration ?? const LyrelogConfiguration(apiKey: 'lyr_ing_test'));
    host.calls.clear();
  }

  group('start', () {
    test('sends the configuration with the native defaults', () async {
      await Lyrelog.start(const LyrelogConfiguration(apiKey: 'lyr_ing_test'));
      final sent = host.of('start').single.args.single! as StartMessage;
      expect(sent.apiKey, 'lyr_ing_test');
      expect(sent.endpoint, 'https://ingest.lyrelog.com');
      expect(sent.consent, ConsentMessage.granted);
      expect(sent.minimumLevel, LevelMessage.debug);
      expect(sent.flushIntervalMs, 15000);
      expect(sent.maxBatchBytes, 512 * 1024);
      expect(sent.maxBatchEvents, 500);
      expect(sent.maxDiskBytes, 20 * 1024 * 1024);
      expect(sent.maxEventAgeMs, 7 * 24 * 3600 * 1000);
      expect(sent.sessionTimeoutMs, 30 * 60 * 1000);
      expect(sent.environment, isNull);
      expect(sent.platform, isNull);
      expect(sent.redactedKeys, isNull);
      expect(sent.captureNativeCrashes, isTrue);
      expect(sent.attachScreen, isTrue);
      expect(sent.attest, isTrue);
      expect(sent.mirrorToConsole, isFalse);
      expect(sent.pauseUploadsInLowPowerMode, isTrue);
    });

    test('passes every option', () async {
      await Lyrelog.start(const LyrelogConfiguration(
        apiKey: 'lyr_ing_test',
        endpoint: 'http://10.0.2.2:8090',
        consent: Consent.pending,
        minimumLevel: LogLevel.info,
        flushInterval: Duration(seconds: 3),
        environment: 'staging',
        platform: 'app',
        redactedKeys: [...LyrelogConfiguration.defaultRedactedKeys, 'pin'],
        captureNativeCrashes: false,
        attachScreen: false,
        attest: false,
        mirrorToConsole: true,
        pauseUploadsInLowPowerMode: false,
      ));
      final sent = host.of('start').single.args.single! as StartMessage;
      expect(sent.endpoint, 'http://10.0.2.2:8090');
      expect(sent.consent, ConsentMessage.pending);
      expect(sent.minimumLevel, LevelMessage.info);
      expect(sent.flushIntervalMs, 3000);
      expect(sent.environment, 'staging');
      expect(sent.platform, 'app');
      expect(sent.redactedKeys, hasLength(13));
      expect(sent.redactedKeys!.last, 'pin');
      expect(sent.captureNativeCrashes, isFalse);
      expect(sent.attachScreen, isFalse);
      expect(sent.attest, isFalse);
      expect(sent.mirrorToConsole, isTrue);
      expect(sent.pauseUploadsInLowPowerMode, isFalse);
    });

    test('a second start while running is ignored', () async {
      await Lyrelog.start(const LyrelogConfiguration(apiKey: 'lyr_ing_a'));
      await Lyrelog.start(const LyrelogConfiguration(apiKey: 'lyr_ing_b'));
      expect(host.of('start'), hasLength(1));
    });

    test('the configuration never prints its key', () {
      expect(const LyrelogConfiguration(apiKey: 'lyr_ing_secret').toString(), isNot(contains('lyr_ing_secret')));
    });

    test('the default redaction list is the one every SDK shares', () {
      expect(LyrelogConfiguration.defaultRedactedKeys, [
        'authorization', 'cookie', 'password', 'passwd', 'secret', 'token', 'apikey', 'privatekey',
        'credential', 'credentials', 'accesskey', 'signature',
      ]);
    });
  });

  group('logging', () {
    test('nothing is sent before start', () async {
      Lyrelog.info('too_early');
      Lyrelog.screen('Home');
      Lyrelog.captureError(StateError('x'));
      await settle();
      expect(host.logs, isEmpty);
      expect(host.of('screen'), isEmpty);
    });

    test('events logged right after start, without awaiting it, arrive after it', () async {
      Lyrelog.start(const LyrelogConfiguration(apiKey: 'lyr_ing_test'));
      Lyrelog.info('first');
      await settle();
      expect(host.calls.map((c) => c.method), ['start', 'log']);
    });

    test('each level, with category, attrs and payload', () async {
      await start(const LyrelogConfiguration(apiKey: 'lyr_ing_test', minimumLevel: LogLevel.trace));
      Lyrelog.trace('a');
      Lyrelog.debug('b');
      Lyrelog.info('checkout_done', category: 'checkout', attrs: {'items': 3, 'ok': true}, payload: {'raw': 'x'});
      Lyrelog.notice('d');
      Lyrelog.warning('e');
      Lyrelog.error('f');
      Lyrelog.critical('g');
      await settle();
      expect(host.logs.map((c) => c.args[0]), LevelMessage.values);
      final info = host.logs[2].args;
      expect(info[1], 'checkout_done');
      expect(info[2], 'checkout');
      expect(info[3], {'items': 3, 'ok': true});
      expect(info[4], {'raw': 'x'});
    });

    test('below the minimum level nothing crosses the channel', () async {
      await start(const LyrelogConfiguration(apiKey: 'lyr_ing_test', minimumLevel: LogLevel.warning));
      Lyrelog.info('quiet');
      Lyrelog.warning('loud');
      await settle();
      expect(host.logs.map((c) => c.args[1]), ['loud']);
    });

    test('values become what the channel carries', () async {
      await start();
      final cyclic = <String, Object?>{};
      cyclic['self'] = cyclic;
      Lyrelog.info('values', attrs: {
        'at': DateTime.utc(2026, 11, 20, 10),
        'took': const Duration(milliseconds: 1500),
        'tile': Tile.red,
        'nan': double.nan,
        'tags': {'a', 'b'},
        'nested': {1: 'one'},
        'uri': Uri.parse('https://example.com/a'),
      }, payload: cyclic);
      await settle();
      final attrs = host.logs.single.args[3]! as Map;
      expect(attrs['at'], '2026-11-20T10:00:00.000Z');
      expect(attrs['took'], 1500.0);
      expect(attrs['tile'], 'red');
      expect(attrs['nan'], isNull);
      expect(attrs['tags'], ['a', 'b']);
      expect(attrs['nested'], {'1': 'one'});
      expect(attrs['uri'], 'https://example.com/a');
      // A map that contains itself is cut at a depth, never an endless loop.
      expect(host.logs.single.args[4], isA<Map>());
    });

    test('values that share themselves many times over stay small (no exponential walk)', () async {
      await start();
      // Each level holds the one below twice: 2^24 leaves if walked, though only 25 maps exist.
      Object? shared = 'leaf';
      for (var i = 0; i < 24; i++) {
        shared = [shared, shared];
      }
      final cyclic = <String, Object?>{};
      cyclic['a'] = cyclic;
      cyclic['b'] = cyclic;
      Lyrelog.info('shared', attrs: {'tree': shared}, payload: cyclic);
      await settle();
      int leaves(Object? v) => v is List ? v.fold(0, (n, e) => n + leaves(e)) : v is Map ? v.values.fold(0, (n, e) => n + leaves(e)) : 1;
      final call = host.logs.single.args;
      expect(leaves(call[3]), lessThanOrEqualTo(maxEncodedValues));
      expect(leaves(call[4]), lessThanOrEqualTo(maxEncodedValues));
    });

    test('a deep value that holds another twice is not printed out either', () async {
      await start();
      Object? shared = 'leaf';
      for (var i = 0; i < 60; i++) {
        shared = [shared, shared];
      }
      Lyrelog.info('deep', payload: shared);
      await settle();
      expect(host.logs.single.args[4], isA<List>());
    });

    test('a huge string or byte list is cut before it crosses the channel', () async {
      await start();
      final big = 'x' * (8 * 1024 * 1024);
      Lyrelog.info(big, attrs: {'body': big}, payload: Uint8List(4 * 1024 * 1024));
      await settle();
      final call = host.logs.single.args;
      expect((call[1]! as String).length, maxStringLength);
      expect(((call[3]! as Map)['body'] as String).length, maxStringLength);
      expect((call[4]! as List).length, lessThanOrEqualTo(maxEncodedValues));
    });

    test('a cut never splits a surrogate pair', () {
      final text = '${'a' * (maxStringLength - 1)}😀';
      final cut = encodeValue(text)! as String;
      expect(cut.length, maxStringLength - 1);
    });

    test('a logger stamps its category', () async {
      await start();
      final store = Lyrelog.logger('store');
      store.warning('purchase_retry', attrs: {'attempt': 2});
      store.captureError(const FormatException('bad'));
      await settle();
      expect(host.logs.map((c) => c.args[2]), ['store', 'store']);
      expect(host.logs.first.args[0], LevelMessage.warning);
      expect(host.logs.last.args[1], 'exception');
    });

    test('a broken native side never throws into the app', () async {
      await start();
      host.failing = true;
      Lyrelog.info('x');
      Lyrelog.setUser('u');
      Lyrelog.screen('Home');
      expect(await Lyrelog.flush(), isFalse);
      expect(await Lyrelog.sessionId(), isNull);
      await Lyrelog.stop();
    });

    test('without a native side at all (a platform without the plugin) nothing throws', () async {
      host.dispose();
      await Lyrelog.start(const LyrelogConfiguration(apiKey: 'lyr_ing_test'));
      Lyrelog.info('x');
      expect(await Lyrelog.flush(), isFalse);
      await Lyrelog.stop();
    });
  });

  group('user, consent, session, flush and stop', () {
    test('setUser and setConsent are sent even before start (the native SDK keeps them)', () async {
      Lyrelog.setUser('player-1');
      Lyrelog.setConsent(Consent.denied);
      Lyrelog.setUser(null);
      await settle();
      expect(host.of('setUser').map((c) => c.args.single), ['player-1', null]);
      expect(host.of('setConsent').single.args.single, ConsentMessage.denied);
    });

    test('flush and sessionId answer from the native side', () async {
      await start();
      expect(await Lyrelog.flush(timeout: const Duration(seconds: 2)), isTrue);
      expect(host.of('flush').single.args.single, 2000);
      expect(await Lyrelog.sessionId(), 'session-1');
    });

    test('flush before start sends nothing', () async {
      expect(await Lyrelog.flush(), isFalse);
      expect(host.of('flush'), isEmpty);
    });

    test('start right after stop, without awaiting it, still leaves the SDK running', () async {
      await start();
      host.holdStop = Completer<void>();
      Lyrelog.stop();
      Lyrelog.setUser('after-restart');
      Lyrelog.start(const LyrelogConfiguration(apiKey: 'lyr_ing_test'));
      Lyrelog.info('after_restart');
      final flushed = Lyrelog.flush();
      await settle();
      host.holdStop!.complete();
      expect(await flushed, isTrue);
      expect(host.calls.map((c) => c.method), ['stop', 'setUser', 'start', 'log', 'flush']);
      expect(host.running, isTrue);
    });

    test('after stop events are ignored, and start works again', () async {
      await start();
      await Lyrelog.stop();
      Lyrelog.info('after_stop');
      await settle();
      expect(host.of('stop'), hasLength(1));
      expect(host.logs, isEmpty);
      await Lyrelog.start(const LyrelogConfiguration(apiKey: 'lyr_ing_test'));
      expect(host.of('start'), hasLength(1));
    });
  });

  group('errors', () {
    test('captureError: exception, its type and message, the frames in the payload', () async {
      await start();
      try {
        throw StateError('no tiles left');
      } catch (e, s) {
        Lyrelog.captureError(e, stackTrace: s, category: 'game', attrs: {'level': 3, 'error_type': 'mine'});
      }
      await settle();
      final call = host.logs.single.args;
      expect(call[0], LevelMessage.error);
      expect(call[1], 'exception');
      expect(call[2], 'game');
      final attrs = call[3]! as Map;
      expect(attrs['error_type'], 'StateError');
      expect(attrs['error_message'], 'Bad state: no tiles left');
      expect(attrs['level'], 3);
      expect(attrs.containsKey('handled'), isFalse);
      final payload = call[4]! as Map;
      expect(payload['description'], 'Bad state: no tiles left');
      expect((payload['frames']! as List).first, contains('lyrelog_test.dart'));
    });

    test('captureError with handled: false carries handled and the mechanism', () async {
      await start();
      Lyrelog.captureError(Exception('zone'), stackTrace: StackTrace.current, handled: false, mechanism: 'zone');
      await settle();
      final attrs = host.logs.single.args[3]! as Map;
      expect(attrs['handled'], isFalse);
      expect(attrs['mechanism'], 'zone');
    });

    test('a long stack keeps 60 frames and says how many it left out', () async {
      await start();
      final stack = StackTrace.fromString(List.generate(100, (i) => '#$i      f$i (file:///a.dart:$i:1)').join('\n'));
      Lyrelog.captureError(Exception('deep'), stackTrace: stack, level: LogLevel.warning);
      await settle();
      expect(host.logs.single.args[0], LevelMessage.warning);
      final payload = host.logs.single.args[4]! as Map;
      expect(payload['frames'], hasLength(60));
      expect(payload['frames_omitted'], 40);
    });

    test('FlutterError.onError: exception with handled false, mechanism flutter_error, then the handler before', () async {
      await start();
      final details = FlutterErrorDetails(
        exception: FlutterError('A RenderFlex overflowed by 42 pixels on the right.'),
        stack: StackTrace.current,
        library: 'rendering library',
        context: ErrorDescription('during layout'),
      );
      FlutterError.onError!(details);
      await settle();
      final call = host.logs.single.args;
      expect(call[1], 'exception');
      expect(call[2], isNull);
      final attrs = call[3]! as Map;
      expect(attrs['error_type'], 'FlutterError');
      expect(attrs['error_message'], contains('RenderFlex overflowed'));
      expect(attrs['handled'], isFalse);
      expect(attrs['mechanism'], 'flutter_error');
      final payload = call[4]! as Map;
      expect(payload['library'], 'rendering library');
      expect(payload['context'], 'during layout');
      expect(flutterErrorsSeen, [details]);
    });

    test('silent Flutter errors are left out, and still reach the handler before', () async {
      await start();
      final details = FlutterErrorDetails(exception: Exception('image failed'), silent: true);
      FlutterError.onError!(details);
      await settle();
      expect(host.logs, isEmpty);
      expect(flutterErrorsSeen, [details]);
    });

    test('PlatformDispatcher.onError: mechanism platform_dispatcher, and the earlier answer stands', () async {
      await start();
      final error = StateError('async boom');
      final handled = PlatformDispatcher.instance.onError!(error, StackTrace.current);
      await settle();
      expect(handled, isTrue);
      expect(dispatcherErrorsSeen, [error]);
      final attrs = host.logs.single.args[3]! as Map;
      expect(attrs['mechanism'], 'platform_dispatcher');
      expect(attrs['handled'], isFalse);
    });

    test('the same uncaught error repeating is sent once, and at most 10 a minute', () async {
      await start();
      final stack = StackTrace.current;
      for (var i = 0; i < 5; i++) {
        PlatformDispatcher.instance.onError!(StateError('same'), stack);
      }
      for (var i = 0; i < 20; i++) {
        PlatformDispatcher.instance.onError!(StateError('different $i'), stack);
      }
      await settle();
      expect(host.logs, hasLength(10));
      expect(Lyrelog.debugSkippedErrors, 15);
    });

    test('with captureErrors off, uncaught errors are not reported (the handlers before still run)', () async {
      await start(const LyrelogConfiguration(apiKey: 'lyr_ing_test', captureErrors: false));
      PlatformDispatcher.instance.onError!(StateError('x'), StackTrace.current);
      FlutterError.onError!(FlutterErrorDetails(exception: Exception('y')));
      await settle();
      expect(host.logs, isEmpty);
      expect(dispatcherErrorsSeen, hasLength(1));
      expect(flutterErrorsSeen, hasLength(1));
    });
  });

  group('LyrelogNavigatorObserver', () {
    PageRoute<void> page(String? name) =>
        PageRouteBuilder<void>(pageBuilder: (_, _, _) => const SizedBox(), settings: RouteSettings(name: name));

    test('a pushed, replaced or uncovered page is the screen; dialogs and unnamed routes are not', () async {
      await start();
      final observer = LyrelogNavigatorObserver();
      final home = page('/');
      final settings = page('/settings');
      final dialog = RawDialogRoute<void>(
        pageBuilder: (_, _, _) => const SizedBox(),
        settings: const RouteSettings(name: 'confirm'),
      );
      observer.didPush(home, null);
      observer.didPush(settings, home);
      observer.didPush(dialog, settings);
      observer.didPop(dialog, settings);
      observer.didPop(settings, home);
      observer.didPush(page(null), home);
      observer.didReplace(newRoute: page('/profile'), oldRoute: home);
      await settle();
      expect(host.of('screen').map((c) => c.args[0]), ['/', '/settings', '/settings', '/', '/profile']);
    });

    test('names and filters can be changed', () async {
      await start();
      final observer = LyrelogNavigatorObserver(
        nameExtractor: (s) => s.name?.replaceFirst('/', '').toUpperCase(),
        routeFilter: (_) => true,
      );
      observer.didPush(page('/home'), null);
      await settle();
      expect(host.of('screen').single.args[0], 'HOME');
    });

    test('Lyrelog.screen passes extra attrs', () async {
      await start();
      Lyrelog.screen('Settings', attrs: {'tab': 'privacy'});
      Lyrelog.screen('');
      await settle();
      expect(host.of('screen').single.args, ['Settings', {'tab': 'privacy'}]);
    });
  });
}
