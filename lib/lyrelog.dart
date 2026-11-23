/// Structured logs from your Flutter app to Lyrelog, a hosted log service.
///
/// Start once in `main`, then log from anywhere:
///
/// ```dart
/// void main() {
///   Lyrelog.start(const LyrelogConfiguration(apiKey: 'lyr_ing_...'));
///   runApp(const MyApp());
/// }
/// ```
library;

export 'src/configuration.dart' show Consent, LogLevel, LyrelogConfiguration;
export 'src/lyrelog.dart' show Lyrelog, LyrelogLogger;
export 'src/navigator_observer.dart' show LyrelogNavigatorObserver;
