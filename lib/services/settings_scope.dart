import 'package:flutter/widgets.dart';

import 'settings_preferences.dart';

/// Inherited widget that exposes the global [SettingsPreferences]
/// (notification toggles, default search filters, the bell inbox
/// "mark as read" sentinel) to any descendant.
///
/// Use [SettingsScope.of] to read the current value, and wrap any
/// subtree that needs to rebuild when the preferences change in
/// `AnimatedBuilder(animation: SettingsScope.of(context)...)` or
/// `ListenableBuilder`.
class SettingsScope extends InheritedNotifier<SettingsPreferences> {
  const SettingsScope({
    super.key,
    required SettingsPreferences prefs,
    required super.child,
  }) : super(notifier: prefs);

  /// Returns the closest [SettingsPreferences]. Throws when used
  /// outside a `SettingsScope` — that's a programming error and
  /// should be caught during development.
  static SettingsPreferences of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(
      scope != null,
      'SettingsScope.of() called with a context that does not contain a SettingsScope.',
    );
    return scope!.notifier!;
  }
}
