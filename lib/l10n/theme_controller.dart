import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Brightness, ThemeMode;

import '../theme.dart';

/// Three brightness choices the user can pick from in Settings.
enum AppThemeMode { dark, light, main }

extension AppThemeModeX on AppThemeMode {
  /// The [KashfPalette] this mode maps to.
  KashfPalette get palette {
    switch (this) {
      case AppThemeMode.dark:
        return KashfPalette.dark;
      case AppThemeMode.light:
        return KashfPalette.light;
      case AppThemeMode.main:
        return KashfPalette.main;
    }
  }

  /// The Material [Brightness] for this mode.
  Brightness get brightness {
    switch (this) {
      case AppThemeMode.light:
        return Brightness.light;
      case AppThemeMode.dark:
      case AppThemeMode.main:
        return Brightness.dark;
    }
  }

  /// The [ThemeMode] this maps to for MaterialApp.
  ThemeMode get materialMode =>
      this == AppThemeMode.light ? ThemeMode.light : ThemeMode.dark;
}

/// Tracks the current theme selection. Held high in the widget tree
/// (in [KashfApp]) so the entire app rebuilds when the user picks a
/// different mode.
///
/// Importantly, [setMode] also updates [KashfPalette.active] so every
/// screen that reads colors via `KashfPalette.active.foo` reflects the
/// choice immediately.
class ThemeController extends ChangeNotifier {
  /// Default theme when the app launches. The user can switch via the
  /// theme picker in Settings.
  ThemeController([AppThemeMode initial = AppThemeMode.main])
    : _mode = initial {
    // Apply the initial palette so the very first frame is correct.
    KashfPalette.setActive(_mode.palette);
  }

  AppThemeMode _mode;

  AppThemeMode get mode => _mode;

  bool get isDark => _mode != AppThemeMode.light;

  void setMode(AppThemeMode mode) {
    if (mode == _mode) return;
    _mode = mode;
    // Update the global palette so every `KashfPalette.active.*` read
    // in the tree returns the new colors.
    KashfPalette.setActive(mode.palette);
    notifyListeners();
  }
}
