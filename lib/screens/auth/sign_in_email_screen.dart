import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../main.dart';
import '../../services/auth_service.dart';
import 'sign_up_screen.dart';
import '../../theme.dart';

class SignInEmailScreen extends StatefulWidget {
  const SignInEmailScreen({super.key});

  @override
  State<SignInEmailScreen> createState() => _SignInEmailScreenState();
}

class _SignInEmailScreenState extends State<SignInEmailScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final AuthService _auth = AuthService();

  bool _showPassword = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (_isLoading) return;
    final l = AppLocalizations.of(context);
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      _showError(l.t('auth_signin_missing_credentials'));
      return;
    }

    // Dismiss the keyboard so the spinner isn't fighting the IME.
    FocusManager.instance.primaryFocus?.unfocus();

    // Flip the loading flag BEFORE the Firebase call so the button
    // is disabled for the entire network round-trip and the spinner
    // is visible immediately.
    setState(() => _isLoading = true);
    try {
      await _auth.signInWithEmail(
        email: email,
        password: password,
        language: l.language,
      );
      // Show the success popup on the root overlay while we navigate.
      // We don't await it so the redirect is never blocked by the
      // popup's animation lifecycle.
      if (!mounted) return;
      // ignore: discarded_futures
      SuccessPopup.show(
        context,
        title: l.t('auth_signin_snackbar'),
        message: l.t('auth_signin_welcome_back'),
      );
      // Safety net: explicitly push HomeShell so the redirect is
      // guaranteed even if the auth gate's stream listener is slow.
      if (!mounted) return;
      navigateToHome(context);
    } on AuthException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    if (_isLoading) return;
    final l = AppLocalizations.of(context);
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _showError(l.t('auth_signin_forgot_need_email'));
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isLoading = true);
    try {
      await _auth.raw.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.tp('auth_signin_forgot_sent', {'email': email})),
          backgroundColor: KashfColors.gold,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomTextField(
          controller: _emailCtrl,
          hint: l.t('auth_signin_email_hint'),
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        SizedBox(height: AuthSpacing.gapBetweenItems),
        CustomTextField(
          controller: _passwordCtrl,
          hint: l.t('auth_signin_password_hint'),
          icon: Icons.lock_outline,
          obscureText: !_showPassword,
          textInputAction: TextInputAction.done,
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
            onTap: _handleForgotPassword,
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
          label: _isLoading
              ? l.t('auth_signin_loading')
              : l.t('auth_signin_submit'),
          onPressed: _handleSignIn,
          enabled: true,
          loading: _isLoading,
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
