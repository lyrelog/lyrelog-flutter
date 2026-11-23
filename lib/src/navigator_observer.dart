import 'package:flutter/widgets.dart';

import 'lyrelog.dart';

/// Calls [Lyrelog.screen] for each route that comes to the top of a [Navigator], named by its
/// [RouteSettings.name].
///
/// ```dart
/// MaterialApp(
///   navigatorObservers: [LyrelogNavigatorObserver()],
///   routes: {'/': (_) => const HomePage(), '/settings': (_) => const SettingsPage()},
/// )
/// ```
///
/// By default only page routes count (dialogs, sheets and menus don't change the screen), and
/// a route without a name is skipped. Going back to a page logs it again, since it is the
/// screen once more; a dialog closing over the same page logs nothing.
class LyrelogNavigatorObserver extends NavigatorObserver {
  /// An observer naming each screen with [nameExtractor] and counting only the routes
  /// [routeFilter] accepts.
  LyrelogNavigatorObserver({
    this.nameExtractor = defaultNameExtractor,
    this.routeFilter = defaultRouteFilter,
  });

  /// The screen's name for a route's settings; `null` or empty skips it.
  final String? Function(RouteSettings settings) nameExtractor;

  /// Which routes are screens.
  final bool Function(Route<dynamic> route) routeFilter;

  /// The route's [RouteSettings.name].
  static String? defaultNameExtractor(RouteSettings settings) => settings.name;

  /// Page routes only: dialogs, sheets and menus don't change the screen.
  static bool defaultRouteFilter(Route<dynamic> route) => route is PageRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _show(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _show(newRoute);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _show(previousRoute);

  void _show(Route<dynamic>? route) {
    try {
      if (route == null || !routeFilter(route)) return;
      final name = nameExtractor(route.settings);
      if (name != null && name.isNotEmpty) Lyrelog.screen(name);
    } catch (_) {
      // never throws
    }
  }
}
