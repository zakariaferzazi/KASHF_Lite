import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';

/// SharedPreferences-backed persistence for the [UserProfile]
/// snapshot. Stores one JSON-encoded blob under a single key so
/// reads / writes happen in one round-trip.
class UserProfileStorage {
  UserProfileStorage({SharedPreferences? prefs}) : _prefs = prefs;

  static const _kKey = 'kashf.user_profile.v1';

  /// Process-wide singleton. Set at startup; tests can override
  /// by passing a [SharedPreferences] instance directly.
  static UserProfileStorage instance = UserProfileStorage();

  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensure() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<UserProfile> read() async {
    try {
      final prefs = await _ensure();
      final raw = prefs.getString(_kKey);
      if (raw == null || raw.isEmpty) return const UserProfile();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return UserProfile(
        name: (json['name'] as String?) ?? '',
        email: (json['email'] as String?) ?? '',
        avatarColor: (json['avatar_color'] as int?) ?? 0xFFD4A33A,
        avatarImagePath: json['avatar_image_path'] as String?,
      );
    } catch (_) {
      // Storage corruption shouldn't crash the app; we treat
      // any read failure as "no saved profile" and return the
      // default snapshot.
      return const UserProfile();
    }
  }

  Future<void> write(UserProfile profile) async {
    final prefs = await _ensure();
    final payload = <String, dynamic>{
      'name': profile.name,
      'email': profile.email,
      'avatar_color': profile.avatarColor,
      'avatar_image_path': profile.avatarImagePath,
    };
    await prefs.setString(_kKey, jsonEncode(payload));
  }
}
