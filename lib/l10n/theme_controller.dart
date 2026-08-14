import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';

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

  /// The lowercase token persisted in [SharedPreferences]. Round-trips
  /// through [fromKey] so the saved selection survives an app restart.
  String get key {
    switch (this) {
      case AppThemeMode.dark:
        return 'dark';
      case AppThemeMode.light:
        return 'light';
      case AppThemeMode.main:
        return 'main';
    }
  }

  /// Reverse lookup for [key]. Falls back to [AppThemeMode.main] when
  /// the stored token is missing or unrecognised (e.g. upgraded users).
  static AppThemeMode fromKey(String? key) {
    switch (key) {
      case 'dark':
        return AppThemeMode.dark;
      case 'light':
        return AppThemeMode.light;
      case 'main':
        return AppThemeMode.main;
      default:
        return AppThemeMode.main;
    }
  }
}

/// Tracks the current theme selection. Held high in the widget tree
/// (in [KashfApp]) so the entire app rebuilds when the user picks a
/// different mode.
///
/// The selection is persisted to [SharedPreferences] so the user's
/// preference survives app restarts. Persistence is best-effort: if
/// the platform plugin is unavailable (e.g. running in a unit test)
/// the controller simply falls back to the in-memory value.
class ThemeController extends ChangeNotifier {
  /// Builds a controller and asynchronously hydrates the saved mode
  /// from [SharedPreferences]. Until the read completes, the
  /// controller uses [initial] (defaults to [AppThemeMode.main]).
  ///
  /// Callers that need to wait for the persisted value (for example,
  /// the splash / first-frame path) should `await` [loaded].
  factory ThemeController.load({AppThemeMode initial = AppThemeMode.main}) {
    final controller = ThemeController._internal(initial);
    // Kick off the async hydration but don't block the constructor.
    controller._hydrate();
    return controller;
  }

  /// In-memory-only controller. Used by tests.
  ThemeController([AppThemeMode initial = AppThemeMode.main])
      : _mode = initial,
        _hydrated = true;

  ThemeController._internal(this._mode) : _hydrated = false;

  /// Persisted key under which the theme mode is stored.
  static const String _prefsKey = 'kashf_theme_mode';

  /// Completes once the persisted theme has been loaded.
  Future<void> get loaded => _loadedCompleter.future;
  final Completer<void> _loadedCompleter = Completer<void>();

  AppThemeMode _mode;
  bool _hydrated;

  AppThemeMode get mode => _mode;

  bool get isDark => _mode != AppThemeMode.light;

  bool get isHydrated => _hydrated;

  /// Sets the new mode. Notifies listeners and persists the choice
  /// in the background so callers don't block on disk I/O.
  ///
  /// The static [KashfPalette.active] is updated *before* the
  /// listeners fire so every screen that rebuilds in response to
  /// the notification already reads the freshly-selected palette —
  /// without this dance the rebuilt widgets would briefly read the
  /// previous palette during the same frame.
  void setMode(AppThemeMode mode) {
    if (mode == _mode) return;
    _mode = mode;
    _syncActivePalette();
    notifyListeners();
    _persist();
  }

  /// Mirrors the current mode into [KashfPalette.active]. Called
  /// from [setMode] and on hydration so the static is always in
  /// lock-step with [_mode].
  void _syncActivePalette() {
    switch (_mode) {
      case AppThemeMode.dark:
        KashfPalette.setActive(KashfPalette.dark);
        break;
      case AppThemeMode.light:
        KashfPalette.setActive(KashfPalette.light);
        break;
      case AppThemeMode.main:
        KashfPalette.setActive(KashfPalette.main);
        break;
    }
  }

  Future<void> _hydrate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_prefsKey);
      final resolved = AppThemeModeX.fromKey(stored);
      if (resolved != _mode) {
        _mode = resolved;
        _syncActivePalette();
        notifyListeners();
      } else {
        // Even when the persisted value matches, make sure the
        // static palette reflects the active mode in case some
        // other code path overrode it.
        _syncActivePalette();
      }
    } catch (_) {
      // Storage unavailable — fall back to the in-memory default.
    } finally {
      _hydrated = true;
      if (!_loadedCompleter.isCompleted) {
        _loadedCompleter.complete();
      }
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, _mode.key);
    } catch (_) {
      // Persistence is best-effort; ignored if the plugin fails.
    }
  }
}
