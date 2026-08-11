import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai/ai_model_options.dart';

/// Persists user preferences that live outside of [ThemeController]
/// and [LocaleController]: notification toggles, default search
/// filters, the chosen OpenRouter model id, and the "all
/// notifications read" sentinel used by the bell icon on the home
/// shell.
///
/// All getters fall back to a sensible default when the key has
/// never been written, so existing installations keep working after
/// upgrade.
class SettingsPreferences extends ChangeNotifier {
  SettingsPreferences._(this._prefs);

  static Future<SettingsPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsPreferences._(prefs);
  }

  /// The global handle exposed for [OpenRouterConfig] so it can
  /// resolve the user's chosen model without pulling in an
  /// InheritedWidget from a settings screen we don't own. Wired
  /// in [KashfApp] at startup so [OpenRouterConfig.model] (a static
  /// getter — it can't reach into the widget tree) can read the
  /// user's chosen model without circular dependencies.
  static SettingsPreferences? instance;

  final SharedPreferences _prefs;

  // --- Notification toggles -------------------------------------------

  static const _kNotifPush = 'notif_push';
  static const _kNotifEmail = 'notif_email';
  static const _kNotifInvestigation = 'notif_investigation';
  static const _kNotifMonitor = 'notif_monitor';

  bool get notificationsPush => _prefs.getBool(_kNotifPush) ?? true;
  bool get notificationsEmail => _prefs.getBool(_kNotifEmail) ?? true;
  bool get notificationsInvestigation =>
      _prefs.getBool(_kNotifInvestigation) ?? true;
  bool get notificationsMonitor => _prefs.getBool(_kNotifMonitor) ?? true;

  Future<void> setNotificationsPush(bool value) async {
    await _prefs.setBool(_kNotifPush, value);
    notifyListeners();
  }

  Future<void> setNotificationsEmail(bool value) async {
    await _prefs.setBool(_kNotifEmail, value);
    notifyListeners();
  }

  Future<void> setNotificationsInvestigation(bool value) async {
    await _prefs.setBool(_kNotifInvestigation, value);
    notifyListeners();
  }

  Future<void> setNotificationsMonitor(bool value) async {
    await _prefs.setBool(_kNotifMonitor, value);
    notifyListeners();
  }

  // --- Search preferences ---------------------------------------------

  static const _kSearchEntity = 'search_default_entity';
  static const _kSearchRegion = 'search_default_region';
  static const _kSearchSafe = 'search_safe';

  /// The country the user picked during sign-up. When set it becomes
  /// the implicit default region for every AI-driven investigation.
  /// Stored alongside the user since KASHF Lite does not use Firestore.
  static const _kUserCountry = 'user_country';

  String get defaultEntity => _prefs.getString(_kSearchEntity) ?? 'company';
  String get defaultRegion =>
      _prefs.getString(_kSearchRegion) ?? userCountry ?? 'global';
  bool get safeSearch => _prefs.getBool(_kSearchSafe) ?? true;

  /// Country the user picked at signup, if any. Null for users who
  /// signed up before the country picker existed or who skipped it.
  String? get userCountry => _prefs.getString(_kUserCountry);

  Future<void> setDefaultEntity(String value) async {
    await _prefs.setString(_kSearchEntity, value);
    notifyListeners();
  }

  Future<void> setDefaultRegion(String value) async {
    await _prefs.setString(_kSearchRegion, value);
    notifyListeners();
  }

  Future<void> setSafeSearch(bool value) async {
    await _prefs.setBool(_kSearchSafe, value);
    notifyListeners();
  }

  /// Persists the country the user picked at signup. Also promotes
  /// it to the default search region so the AI prompt picks up the
  /// user's locale automatically.
  Future<void> setUserCountry(String dialCode) async {
    await _prefs.setString(_kUserCountry, dialCode);
    // Make the picked country the default region everywhere it
    // matters (search, home, market, monitoring) without forcing the
    // user to re-visit Settings → Search preferences.
    await _prefs.setString(_kSearchRegion, dialCode);
    notifyListeners();
  }

  // --- Bell inbox -----------------------------------------------------

  static const _kBellReadAt = 'bell_read_at';

  /// Timestamp of the last "mark all as read" action. The bell icon
  /// shows a badge for any notification newer than this.
  DateTime get lastBellReadAt {
    final stored = _prefs.getString(_kBellReadAt);
    if (stored == null) return DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.tryParse(stored) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> markAllBellRead() async {
    await _prefs.setString(
      _kBellReadAt,
      DateTime.now().toUtc().toIso8601String(),
    );
    notifyListeners();
  }

  // --- AI model --------------------------------------------------------

  static const _kAiModelId = 'ai_model_id';

  /// The OpenRouter model id the user picked in Settings → AI model.
  /// Falls back to the bundled default ([kDefaultAiModelId]) when no
  /// choice has been persisted yet.
  String get aiModelId {
    final stored = _prefs.getString(_kAiModelId);
    if (stored == null || stored.isEmpty) return kDefaultAiModelId;
    return stored;
  }

  /// Persists the user's chosen model id. Unknown ids are normalized
  /// back to the default so a typo from an old version never wedges
  /// the app.
  Future<void> setAiModelId(String? id) async {
    final resolved = resolveAiModelOption(id).id;
    await _prefs.setString(_kAiModelId, resolved);
    notifyListeners();
  }

  /// The resolved [AiModelOption] for [aiModelId].
  AiModelOption get aiModel => resolveAiModelOption(aiModelId);
}
