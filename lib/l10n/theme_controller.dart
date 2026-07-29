import 'package:flutter/material.dart';

/// Three brightness choices the user can pick from in Settings.
enum AppThemeMode { dark, light, main }

extension AppThemeModeX on AppThemeMode {
  /// The Material [ThemeMode] this app mode maps to.
  ThemeMode get materialMode {
    switch (this) {
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.main:
        return ThemeMode.dark;
    }
  }
}

/// Tracks the current theme selection. Held high in the widget tree
/// (in [KashfApp]) so the entire app rebuilds when the user picks a
/// different mode.
class ThemeController extends ChangeNotifier {
  /// Default theme when the app launches. The user can switch via the
  /// theme picker in Settings.
  ThemeController([AppThemeMode initial = AppThemeMode.main]) : _mode = initial;

  AppThemeMode _mode;

  AppThemeMode get mode => _mode;

  bool get isDark => _mode != AppThemeMode.light;

  void setMode(AppThemeMode mode) {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
  }
}
