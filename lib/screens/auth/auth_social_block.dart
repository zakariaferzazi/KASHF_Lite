import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../theme.dart';
import 'apple_sign_in.dart';

/// "Or — Continue with Apple" block.
///
/// Hides itself entirely (including the "or" divider) on platforms
/// where Apple Sign-In isn't available, so Android users never see
/// a useless control. On iOS / macOS / web the block renders the
/// divider + button.
///
/// Use this in any auth screen that wants to expose Apple as an
/// alternative to email / phone.
class AuthSocialBlock extends StatefulWidget {
  const AuthSocialBlock({super.key});

  @override
  State<AuthSocialBlock> createState() => _AuthSocialBlockState();
}

class _AuthSocialBlockState extends State<AuthSocialBlock> {
  /// Tracks whether the Apple button would render. Mirrors the
  /// platform-gate inside `AppleSignInButton` so the surrounding
  /// divider is hidden in lockstep.
  bool? _appleAvailable;

  @override
  void initState() {
    super.initState();
    // Same gate as the button — we just mirror it so the divider
    // can disappear in lockstep.
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      // Optimistic on iOS/macOS; the button widget will still run its
      // own availability check on first build.
      _appleAvailable = true;
    } else {
      _appleAvailable = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_appleAvailable != true) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AuthSpacing.gapDividerApple),
        const OrDivider(),
        const SizedBox(height: AuthSpacing.gapDividerApple),
        AppleSignInButton(label: l.t('auth_welcome_body_apple')),
      ],
    );
  }
}
