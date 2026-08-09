import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around `SharedPreferences` that stores JSON-encoded
/// blobs keyed by a per-screen string id.
///
/// Used by [AiHomeService] and [NewsService] to persist the last
/// successful payload across app restarts so the user sees their
/// recently-fetched AI / news data immediately, and only re-fetches
/// when they explicitly tap refresh.
///
/// Each entry has its own optional TTL — if older than the TTL the
/// entry is treated as a miss so subsequent calls re-fetch.
class DiskCache {
  DiskCache._(this._prefs);

  final SharedPreferences _prefs;

  static const String _prefix = 'kashf.disk_cache.';

  /// Initialize once at app startup (see `main.dart`).
  static Future<DiskCache> create() async {
    final prefs = await SharedPreferences.getInstance();
    return DiskCache._(prefs);
  }

  String _k(String key) => '$_prefix$key';

  /// Returns the decoded JSON payload for [key], or `null` if the
  /// entry is missing or older than [ttl].
  Future<Map<String, dynamic>?> readJson(
    String key, {
    Duration ttl = const Duration(hours: 24),
  }) async {
    final raw = _prefs.getString(_k(key));
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final atMs = map['_at'];
      if (atMs is! num) return null;
      final at = DateTime.fromMillisecondsSinceEpoch(atMs.toInt());
      if (DateTime.now().difference(at) > ttl) return null;
      final data = map['data'];
      if (data is Map<String, dynamic>) return data;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Persists [payload] under [key] along with the current timestamp.
  Future<void> writeJson(String key, Map<String, dynamic> payload) async {
    final wrapped = <String, dynamic>{
      '_at': DateTime.now().millisecondsSinceEpoch,
      'data': payload,
    };
    await _prefs.setString(_k(key), jsonEncode(wrapped));
  }

  /// Removes the entry for [key]. Used by `clearCache` and tests.
  Future<void> remove(String key) async {
    await _prefs.remove(_k(key));
  }
}