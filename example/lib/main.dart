// Lantern, a made-up reading app that shows the lyrelog plugin: events, an area logger, a
// handled error, Dart errors nobody catches, screens from the navigator and the consent choice.
//
// The key and endpoint come from a file that is never committed:
//   flutter run --dart-define-from-file=lyrelog.local.json
// with {"LYRELOG_KEY": "lyr_ing_...", "LYRELOG_ENDPOINT": "http://127.0.0.1:8090"}
// (http://10.0.2.2:8090 on the Android emulator).
import 'dart:async';

import 'package:lyrelog/lyrelog.dart';
import 'package:material_ui/material_ui.dart';

const _key = String.fromEnvironment('LYRELOG_KEY');
const _endpoint = String.fromEnvironment('LYRELOG_ENDPOINT', defaultValue: LyrelogConfiguration.defaultEndpoint);
// `--dart-define=LYRELOG_TOUR=true` presses every button once after launch, for checks.
const _tour = bool.fromEnvironment('LYRELOG_TOUR');
final _navigator = GlobalKey<NavigatorState>();

void main() {
  if (_key.isNotEmpty) {
    Lyrelog.start(const LyrelogConfiguration(apiKey: _key, endpoint: _endpoint, mirrorToConsole: true));
  }
  Lyrelog.setUser('reader-42');
  runApp(const LanternApp());
}

final _library = Lyrelog.logger('library');

class LanternApp extends StatelessWidget {
  const LanternApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lantern',
      theme: ThemeData(colorSchemeSeed: Colors.amber),
      navigatorKey: _navigator,
      navigatorObservers: [LyrelogNavigatorObserver()],
      initialRoute: '/',
      routes: {
        '/': (_) => const ShelfPage(),
        '/book': (_) => const BookPage(),
        '/settings': (_) => const SettingsPage(),
      },
    );
  }
}

class ShelfPage extends StatefulWidget {
  const ShelfPage({super.key});

  @override
  State<ShelfPage> createState() => _ShelfPageState();
}

class _ShelfPageState extends State<ShelfPage> {
  String _status = _key.isEmpty ? 'No key: run with --dart-define-from-file=lyrelog.local.json' : 'Started';
  bool _broken = false;

  void _say(String text) {
    if (mounted) setState(() => _status = text);
  }

  @override
  void initState() {
    super.initState();
    if (_tour) WidgetsBinding.instance.addPostFrameCallback((_) => _runTour());
  }

  Future<void> _runTour() async {
    Future<void> pause() => Future<void>.delayed(const Duration(milliseconds: 800));
    await pause();
    _library.info('book_opened', attrs: {'book_id': 'b_12', 'chapter': 7, 'offline': false});
    unawaited(_navigator.currentState!.pushNamed('/book'));
    await pause();
    _library.notice('chapter_finished', attrs: {'book_id': 'b_12', 'chapter': 7, 'minutes': 12.5});
    _navigator.currentState!.pop();
    await pause();
    unawaited(_navigator.currentState!.pushNamed('/settings'));
    await pause();
    _navigator.currentState!.pop();
    await pause();
    _handledError();
    setState(() => _broken = true);
    await pause();
    _asyncError();
    await pause();
    await _flush();
    // Left for the flush that going to the background does.
    _library.debug('tour_finished');
  }

  Future<void> _flush() async {
    final done = await Lyrelog.flush();
    final session = await Lyrelog.sessionId();
    _say('Flush ${done ? 'done' : 'not finished'} (session ${session ?? 'none'})');
  }

  void _handledError() {
    try {
      throw const FormatException('chapter 7 has no title');
    } catch (e, s) {
      _library.captureError(e, stackTrace: s, attrs: {'book_id': 'b_12'});
    }
    _say('Sent a handled error');
  }

  void _asyncError() {
    // Nobody awaits this: it reaches PlatformDispatcher.instance.onError.
    Future<void>.delayed(Duration.zero, () => throw StateError('sync token expired'));
    _say('Threw an async error');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lantern'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_status, key: const Key('status')),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('open_book'),
            onPressed: () {
              _library.info('book_opened', attrs: {'book_id': 'b_12', 'chapter': 7, 'offline': false});
              Navigator.pushNamed(context, '/book');
            },
            child: const Text('Open a book'),
          ),
          OutlinedButton(
            key: const Key('handled_error'),
            onPressed: _handledError,
            child: const Text('Handled error'),
          ),
          OutlinedButton(
            key: const Key('flutter_error'),
            onPressed: () {
              setState(() => _broken = true);
              _say('Built a broken widget');
            },
            child: const Text('Flutter error (in build)'),
          ),
          OutlinedButton(
            key: const Key('async_error'),
            onPressed: _asyncError,
            child: const Text('Async error'),
          ),
          OutlinedButton(key: const Key('flush'), onPressed: _flush, child: const Text('Flush')),
          if (_broken) const _BrokenCover(),
        ],
      ),
    );
  }
}

/// Throws while building: FlutterError.onError reports it, and Flutter shows its error widget.
class _BrokenCover extends StatelessWidget {
  const _BrokenCover();

  @override
  Widget build(BuildContext context) => throw StateError('cover image has no size');
}

class BookPage extends StatelessWidget {
  const BookPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('The Lighthouse')),
      body: Center(
        child: FilledButton(
          onPressed: () {
            _library.notice('chapter_finished', attrs: {'book_id': 'b_12', 'chapter': 7, 'minutes': 12.5});
            Navigator.pop(context);
          },
          child: const Text('Finish the chapter'),
        ),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Consent _consent = Consent.granted;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: RadioGroup<Consent>(
        groupValue: _consent,
        onChanged: (value) {
          if (value == null) return;
          setState(() => _consent = value);
          Lyrelog.setConsent(value);
        },
        child: const Column(
          children: [
            ListTile(title: Text('Send diagnostics')),
            RadioListTile(value: Consent.granted, title: Text('Yes')),
            RadioListTile(value: Consent.pending, title: Text('Ask me later')),
            RadioListTile(value: Consent.denied, title: Text('No')),
          ],
        ),
      ),
    );
  }
}
