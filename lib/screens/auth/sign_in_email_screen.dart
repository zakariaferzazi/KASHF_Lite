import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../main.dart';
import 'sign_up_screen.dart';
import '../../theme.dart';

class SignInEmailScreen extends StatefulWidget {
  const SignInEmailScreen({super.key});

  @override
  State<SignInEmailScreen> createState() => _SignInEmailScreenState();
}

class _SignInEmailScreenState extends State<SignInEmailScreen> {
  bool _showPassword = false;

  Future<void> _handleSignIn() async {
    final l = AppLocalizations.of(context);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.t('auth_signin_snackbar')),
        backgroundColor: KashfColors.gold,
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (!mounted) return;
    navigateToHome(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomTextField(
          hint: l.t('auth_signin_email_hint'),
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        SizedBox(height: AuthSpacing.gapBetweenItems),
        CustomTextField(
          hint: l.t('auth_signin_password_hint'),
          icon: Icons.lock_outline,
          obscureText: !_showPassword,
          suffixIcon: IconButton(
            icon: Icon(
              _showPassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: KashfPalette.active.textSecondary,
            ),
            onPressed: () {
              setState(() => _showPassword = !_showPassword);
            },
          ),
        ),
        SizedBox(height: AuthSpacing.gapBetweenItems),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: GestureDetector(
            onTap: () {},
            child: Text(
              l.t('auth_signin_forgot'),
              style: const TextStyle(
                color: KashfColors.gold,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        SizedBox(height: AuthSpacing.gapBetweenItems),
        KashfPrimaryButton(
          label: l.t('auth_signin_submit'),
          onPressed: _handleSignIn,
        ),
        SizedBox(height: AuthSpacing.gapDividerApple),
        const OrDivider(),
        SizedBox(height: AuthSpacing.gapDividerApple),
        AppleButton(
          onTap: () => navigateToHome(context),
          label: l.t('auth_welcome_body_apple'),
        ),
      ],
    );

    return AuthScaffold(
      title: l.t('auth_signin_title'),
      subtitle: l.t('auth_signin_subtitle'),
      body: body,
      footerPrompt: l.t('auth_signup_agree_fallback'),
      footerAction: l.t('auth_signin_footer_action'),
      logoWidth: 120,
      compact: true,
      onFooterActionTap: () {
        Navigator.pushReplacement(context, kashfRoute(const SignUpScreen()));
      },
    );
  }
}
