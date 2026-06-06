/// Auto-logs every navigation transition to [AnalyticsService]. Wired into
/// the MaterialApp's `navigatorObservers:` once in app.dart so every screen
/// push/replace/pop produces a screen-view event without needing to touch
/// each screen widget.
///
/// Screen names default to the route's `settings.name`. For routes built
/// from anonymous MaterialPageRoute(...) — which is the common pattern in
/// this app — we fall back to the runtime type of the route's builder
/// widget so the event isn't just "null".
library;

import 'package:flutter/widgets.dart';

import 'analytics_service.dart';

class AnalyticsNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _send(route, previousRoute);
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) _send(newRoute, oldRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // Log the route the user *returns* to so the timeline shows their
    // current location, not just the pushed-and-popped one.
    if (previousRoute != null) _send(previousRoute, route);
    super.didPop(route, previousRoute);
  }

  void _send(Route<dynamic> route, Route<dynamic>? from) {
    final name = _nameFor(route);
    if (name == null) return; // anonymous + unknown — skip rather than spam
    final previous = from == null ? null : _nameFor(from);
    AnalyticsService.instance.logScreen(name, previousRoute: previous);
  }

  String? _nameFor(Route<dynamic> route) {
    final n = route.settings.name;
    if (n != null && n.isNotEmpty) return n;
    if (route is PageRoute) {
      // Use the route's runtime type as a best-effort label.
      return route.runtimeType.toString();
    }
    return null;
  }
}
