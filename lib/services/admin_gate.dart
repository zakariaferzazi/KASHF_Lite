import 'package:firebase_auth/firebase_auth.dart' as fb;

/// Centralised, side-effect-free check for whether the currently
/// signed-in user is the KASHF Lite admin account.
///
/// The admin is allowed to use the AI "Content Studio" features
/// (reel + podcast script generation) that are hidden from regular
/// users. The check is intentionally case-insensitive and
/// trim-tolerant so admin hand-off across devices and email-merge
/// quirks stay reliable.
class AdminGate {
  AdminGate._();

  /// The single admin email address that unlocks the script
  /// studio. Stored as a constant so it's grep-able from the
  /// whole codebase and easy to update in one place.
  static const String kAdminEmail = 'Nawaff89@gmail.com';

  /// Returns `true` when [user] is non-null and its email matches
  /// [kAdminEmail] (case-insensitive, trimmed). `false` for
  /// anonymous users, signed-out sessions, or non-matching emails.
  static bool isAdmin(fb.User? user) {
    final email = user?.email;
    if (email == null) return false;
    return email.trim().toLowerCase() == kAdminEmail.trim().toLowerCase();
  }
}
