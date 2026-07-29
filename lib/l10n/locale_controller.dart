import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_locale.dart';

/// Tracks the currently selected app language and persists it across
/// app launches via [SharedPreferences]. Held high in the tree so the
/// entire app rebuilds with the new locale when the user changes it.
///
/// Persisted key: `kashf_locale`.
class LocaleController extends ChangeNotifier {
  LocaleController._(this._language);

  /// Loads the persisted language from [SharedPreferences] (if any).
  /// Falls back to Arabic as the default for first-launch installs.
  static Future<LocaleController> load() async {
    AppLanguage initial = AppLanguage.arabic;
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefsKey);
      if (code != null && code.isNotEmpty) {
        initial = AppLanguage.fromCode(code);
      }
    } catch (_) {
      // Storage unavailable; keep Arabic default.
    }
    return LocaleController._(initial);
  }

  /// The persisted key under which the language code is stored.
  static const String _prefsKey = 'kashf_locale';

  AppLanguage _language;

  AppLanguage get language => _language;

  bool get isRtl => _language == AppLanguage.arabic;

  void setLanguage(AppLanguage language) {
    if (language == _language) return;
    _language = language;
    notifyListeners();
    _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, _language.code);
    } catch (_) {
      // Persistence is best-effort; ignored if the plugin fails.
    }
  }
}
