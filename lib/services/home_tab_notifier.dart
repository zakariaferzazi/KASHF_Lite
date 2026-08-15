import 'package:flutter/foundation.dart';

/// Tab indices for [HomeShell]. Kept here so non-shell widgets
/// (e.g. the home screen avatar tap) can request a tab change
/// without holding a direct reference to the shell.
class HomeTabs {
  HomeTabs._();

  static const int home = 0;
  static const int explore = 1;
  static const int reports = 2;
  static const int settings = 3;
}

/// Lightweight `ChangeNotifier` the home shell listens to so
/// any descendant can ask it to switch tabs.
///
/// Usage:
///   * [HomeShell] subscribes in `initState`, calls
///     `_index = newIndex` + `setState(() {})` on each notify.
///   * Anything inside the home subtree (e.g. the avatar button
///     on the home app bar) calls [requestTab] when it wants
///     to navigate via the shell instead of pushing a new route.
class HomeTabNotifier extends ChangeNotifier {
  /// Currently-selected tab. Mirrors `_HomeShellState._index`.
  int _index = HomeTabs.home;
  int get index => _index;

  /// Ask the shell to switch to [tab] without pushing a new
  /// route. Silently ignored when the tab is already active.
  void requestTab(int tab) {
    if (_index == tab) return;
    _index = tab;
    notifyListeners();
  }
}