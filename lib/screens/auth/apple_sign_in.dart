import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../l10n/app_strings.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';

/// Platform-aware Apple sign-in button.
///
/// Strict gating on Android: the widget returns `SizedBox.shrink()`
/// whenever the current `ThemeData.platform` is **not** iOS / macOS,
/// so the button is completely absent from the tree on phones, tablets,
/// and most desktop targets. On iOS / macOS / web (where the package
/// advertises support), it renders the native button via
/// `SignInWithAppleBuilder`.
///
/// The button is also gated on `SignInWithApple.isAvailable()`, which
/// returns `false` on Android in current plugin versions. We poll it
/// once on first build so that a misconfigured Android target (where
/// the platform channel might respond unexpectedly) still hides the
/// button.
class AppleSignInButton extends StatefulWidget {
  const AppleSignInButton({
    super.key,
    required this.label,
  });

  final String label;

  @override
  State<AppleSignInButton> createState() => _AppleSignInButtonState();
}

class _AppleSignInButtonState extends State<AppleSignInButton> {
  /// `null` until the platform channel reports back. After that it's
  /// `true` only on Apple-supported targets.
  bool? _available;

  /// Local cache of the platform so we don't have to read `Theme.of`
  /// on every build (and so we don't risk ThemeOf returning null in
  /// edge cases during tests).
  late final TargetPlatform _platform;

  @override
  void initState() {
    super.initState();
    _platform = defaultTargetPlatform;
    _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    // Hard gate: only iOS/macOS are supported by Apple Sign-In on
    // native mobile. We do this *before* calling into the plugin so
    // we never hit a platform channel on Android that might respond
    // unexpectedly.
    if (_platform != TargetPlatform.iOS && _platform != TargetPlatform.macOS) {
      if (mounted) setState(() => _available = false);
      return;
    }
    try {
      final ok = await SignInWithApple.isAvailable();
      if (!mounted) return;
      setState(() => _available = ok);
    } catch (_) {
      if (!mounted) return;
      setState(() => _available = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Hide the button on every non-Apple target up-front — no flash
    // of a useless control.
    if (_available != true) {
      return const SizedBox.shrink();
    }
    return SignInWithAppleBuilder(
      builder: (_) => AppleButton(
        onTap: () => performAppleSignIn(context),
        label: widget.label,
      ),
      fallbackBuilder: (_) => const SizedBox.shrink(),
    );
  }
}

/// Performs an Apple sign-in and lets the auth gate (`_AuthGate` in
/// `main.dart`, listening to `FirebaseAuth.authStateChanges()`) route
/// the user to the home screen on success. On failure we surface a
/// localised snackbar so the user stays on the auth screen.
///
/// This is the *only* entry point the auth screens should use for
/// the "Continue with Apple" button — never navigate directly to
/// the home shell from the tap handler, otherwise unauthenticated
/// users can land on the app.
Future<void> performAppleSignIn(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final palette = KashfPalette.active;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await AuthService().signInWithApple(language: l.language);
    // The auth gate auto-routes on success — we deliberately do
    // NOT call `navigateToHome(context)` here, because doing so
    // before Firebase has actually flipped `currentUser` can land
    // an unauthenticated user on the home screen.
  } on AuthException catch (e) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Color(0xFFEF4444)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                e.message,
                style: TextStyle(color: palette.textPrimary),
              ),
            ),
          ],
        ),
        backgroundColor: palette.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFEF4444)),
        ),
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          l.t('auth_apple_failed'),
          style: TextStyle(color: palette.textPrimary),
        ),
        backgroundColor: palette.surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
