import 'dart:async';
import 'dart:convert';

import 'package:characters/characters.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Avatar source picked by the user.
enum AvatarKind { initial, image }

/// A small snapshot of the user's profile that we can render without
/// touching Firebase.
class UserProfile {
  const UserProfile({
    required this.name,
    required this.email,
    required this.avatarKind,
    required this.avatarColorValue,
    this.avatarImagePath,
  });

  /// Display name (e.g. "Noor Audit"). Falls back to the email prefix
  /// when no name has been set yet.
  final String name;

  /// The email address used to sign in. Empty string when the user is
  /// anonymous (e.g. phone-only sign-in).
  final String email;

  /// Where the avatar should come from.
  final AvatarKind avatarKind;

  /// ARGB color shown behind the initial when [avatarKind] is
  /// [AvatarKind.initial].
  final int avatarColorValue;

  /// Filesystem path to the picked image when [avatarKind] is
  /// [AvatarKind.image]. `null` otherwise.
  final String? avatarImagePath;

  UserProfile copyWith({
    String? name,
    String? email,
    AvatarKind? avatarKind,
    int? avatarColorValue,
    String? avatarImagePath,
    bool clearImage = false,
  }) {
    return UserProfile(
      name: name ?? this.name,
      email: email ?? this.email,
      avatarKind: avatarKind ?? this.avatarKind,
      avatarColorValue: avatarColorValue ?? this.avatarColorValue,
      avatarImagePath: clearImage
          ? null
          : (avatarImagePath ?? this.avatarImagePath),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'avatarKind': avatarKind.name,
    'avatarColorValue': avatarColorValue,
    'avatarImagePath': avatarImagePath,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    name: (json['name'] as String?) ?? '',
    email: (json['email'] as String?) ?? '',
    avatarKind: AvatarKind.values.firstWhere(
      (k) => k.name == (json['avatarKind'] as String?),
      orElse: () => AvatarKind.initial,
    ),
    avatarColorValue: (json['avatarColorValue'] as int?) ?? 0xFFD4A33A,
    avatarImagePath: json['avatarImagePath'] as String?,
  );

  /// Returns the first letter (uppercased) of the display name, or "?"
  /// if the name is empty.
  String get initialLetter {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.characters.first.toUpperCase();
  }
}

/// Controller that owns the current user's profile. Sources of truth,
/// in order of precedence:
///   1. The Firebase user (provides email + displayName).
///   2. Locally persisted overrides (avatar kind / image / color and
///      a custom display name override).
///
/// Persists overrides to `shared_preferences` so they survive a
/// sign-out/sign-in cycle for the same device.
class UserProfileController extends ChangeNotifier {
  UserProfileController({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance {
    _hydrateFromPrefs();
    _userSub = _auth.authStateChanges().listen(_onAuthChanged);
    _onAuthChanged(_auth.currentUser);
  }

  final FirebaseAuth _auth;
  late final StreamSubscription<User?> _userSub;

  static const _prefsKey = 'user_profile_v1';
  static const _goldColor = 0xFFD4A33A;

  UserProfile _profile = const UserProfile(
    name: '',
    email: '',
    avatarKind: AvatarKind.initial,
    avatarColorValue: _goldColor,
  );
  UserProfile get profile => _profile;

  Map<String, dynamic>? _overrideJson;

  Future<void> _hydrateFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _overrideJson = decoded;
    } catch (e) {
      // Ignore corrupted prefs and start fresh.
      _overrideJson = null;
    }
  }

  void _onAuthChanged(User? user) {
    final email = user?.email ?? '';
    final firebaseName = user?.displayName ?? '';

    final override = _overrideJson;
    String name;
    if (override != null && (override['name'] as String?)?.isNotEmpty == true) {
      // User has set a custom name; keep it.
      name = override['name'] as String;
    } else if (firebaseName.isNotEmpty) {
      name = firebaseName;
    } else if (email.isNotEmpty) {
      name = email.split('@').first;
    } else {
      name = '';
    }

    final avatarKind = override != null
        ? AvatarKind.values.firstWhere(
            (k) => k.name == override['avatarKind'],
            orElse: () => AvatarKind.initial,
          )
        : AvatarKind.initial;
    final color = override?['avatarColorValue'] as int? ?? _goldColor;
    final imagePath = override?['avatarImagePath'] as String?;

    _profile = UserProfile(
      name: name,
      email: email,
      avatarKind: avatarKind,
      avatarColorValue: color,
      avatarImagePath: imagePath,
    );
    notifyListeners();
  }

  /// Updates the user's display name and persists it.
  Future<void> setName(String name) async {
    _profile = _profile.copyWith(name: name.trim());
    notifyListeners();
    await _persist();
  }

  /// Updates the avatar to use the picked image at [path] (file path on
  /// the device). Pass `null` to revert to the initial avatar.
  Future<void> setAvatarImage(String? path) async {
    _profile = _profile.copyWith(
      avatarKind: path == null ? AvatarKind.initial : AvatarKind.image,
      avatarImagePath: path,
      clearImage: path == null,
    );
    notifyListeners();
    await _persist();
  }

  /// Updates the avatar to show the first-letter initial on a colored
  /// circle.
  Future<void> setAvatarColor(int colorValue) async {
    _profile = _profile.copyWith(
      avatarKind: AvatarKind.initial,
      avatarColorValue: colorValue,
      clearImage: true,
    );
    notifyListeners();
    await _persist();
  }

  /// Resets the avatar back to the initial-letter style with the
  /// default brand gold color.
  Future<void> resetAvatar() async {
    _profile = _profile.copyWith(
      avatarKind: AvatarKind.initial,
      avatarColorValue: _goldColor,
      clearImage: true,
    );
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_profile.toJson()));
      _overrideJson = _profile.toJson();
    } catch (_) {
      // Best-effort: if disk fails the in-memory state still wins.
    }
  }

  /// Called when the user signs out to clear the in-memory snapshot.
  /// The persisted overrides remain on disk so they re-apply when the
  /// user signs back in on the same device.
  void clearForSignOut() {
    _profile = const UserProfile(
      name: '',
      email: '',
      avatarKind: AvatarKind.initial,
      avatarColorValue: _goldColor,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _userSub.cancel();
    super.dispose();
  }
}
