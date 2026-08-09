import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/user_profile_controller.dart';

/// Renders the current user's avatar from a [UserProfileController]:
///   - picked image (if the user picked one)
///   - colored circle with the first letter of their name
///   - fallback: the default KASHF "K" gold logo
///
/// The widget is intentionally small and dependency-free so it can be
/// reused in the top bar, the profile card, the edit screen, etc.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.profile,
    this.size = 32,
    this.borderColor,
    this.borderWidth = 1.2,
  });

  final UserProfile profile;
  final double size;
  final Color? borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    Widget child;

    final imagePath = p.avatarImagePath;
    if (p.avatarKind == AvatarKind.image &&
        imagePath != null &&
        imagePath.isNotEmpty &&
        File(imagePath).existsSync()) {
      child = Image.file(
        File(imagePath),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildInitial(p),
      );
    } else if (p.name.trim().isNotEmpty &&
        p.avatarKind == AvatarKind.initial) {
      child = _buildInitial(p);
    } else {
      // Default: the brand "K" mark on a gold square (mirrors the
      // existing home-screen pill so legacy callers keep working).
      child = Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFD4A33A),
          borderRadius: BorderRadius.circular(size / 4),
        ),
        child: Text(
          'K',
          style: TextStyle(
            color: Colors.black,
            fontSize: size * 0.55,
            fontWeight: FontWeight.w900,
            height: 1.0,
          ),
        ),
      );
    }

    if (borderColor != null) {
      child = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor!, width: borderWidth),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
    }
    return SizedBox(width: size, height: size, child: child);
  }

  Widget _buildInitial(UserProfile p) {
    final color = Color(p.avatarColorValue);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: Text(
        p.initialLetter,
        style: TextStyle(
          color: _onColor(color),
          fontSize: size * 0.45,
          fontWeight: FontWeight.w900,
          height: 1.0,
        ),
      ),
    );
  }

  /// Picks black or white based on the brightness of [bg] so the
  /// initial is always legible.
  Color _onColor(Color bg) {
    final luminance = bg.computeLuminance();
    return luminance > 0.55 ? Colors.black : Colors.white;
  }
}
