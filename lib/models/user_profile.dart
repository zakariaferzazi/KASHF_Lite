import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart' show immutable;

/// Immutable snapshot of the user's profile — what name they
/// see in the UI, what email they signed in with, and whether
/// they're using a custom avatar image or just a coloured
/// initial.
@immutable
class UserProfile {
  const UserProfile({
    this.name = '',
    this.email = '',
    this.avatarColor = 0xFFD4A33A,
    this.avatarImagePath,
  });

  final String name;
  final String email;
  final int avatarColor;

  /// Absolute path to the image file the user picked from the
  /// camera or gallery. Null when the user is using the
  /// coloured-initial fallback.
  final String? avatarImagePath;

  UserProfile copyWith({
    String? name,
    String? email,
    int? avatarColor,
    String? avatarImagePath,
    bool clearAvatarImage = false,
  }) {
    return UserProfile(
      name: name ?? this.name,
      email: email ?? this.email,
      avatarColor: avatarColor ?? this.avatarColor,
      avatarImagePath: clearAvatarImage
          ? null
          : (avatarImagePath ?? this.avatarImagePath),
    );
  }

  /// First character of the user's name, or the first character
  /// of their email, or `'?'` if both are empty. Used by
  /// [UserAvatar] when no image is set.
  String get initial {
    final src = name.trim().isNotEmpty ? name.trim() : email.trim();
    if (src.isEmpty) return '?';
    return src.characters.first.toUpperCase();
  }
}
