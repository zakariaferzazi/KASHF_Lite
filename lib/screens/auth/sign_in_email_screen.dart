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
  bool _isLoading = false;

  Future<void> _handleSignIn() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    // Demo mode: show loading for 1.5 seconds, then let user in
    await Future.delayed(const Duration(milliseconds: 1500));

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
        _LoadingButton(
          label: l.t('auth_signin_submit'),
          onPressed: _handleSignIn,
          isLoading: _isLoading,
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

class _LoadingButton extends StatefulWidget {
  const _LoadingButton({
    required this.label,
    required this.onPressed,
    required this.isLoading,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isLoading;

  @override
  State<_LoadingButton> createState() => _LoadingButtonState();
}

class _LoadingButtonState extends State<_LoadingButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.isLoading
          ? null
          : (_) => setState(() => _isPressed = true),
      onTapUp: widget.isLoading
          ? null
          : (_) {
              setState(() => _isPressed = false);
              widget.onPressed();
            },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        height: 54,
        transform: Matrix4.identity()..scale(_isPressed ? 0.96 : 1.0),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: widget.isLoading
                ? [
                    const Color(0xFFF8C24A).withValues(alpha: 0.7),
                    const Color(0xFFF5B92E).withValues(alpha: 0.7),
                  ]
                : [const Color(0xFFF8C24A), const Color(0xFFF5B92E)],
          ),
          boxShadow: [
            BoxShadow(
              color: KashfColors.gold.withValues(alpha: 0.35),
              blurRadius: widget.isLoading ? 8 : 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: widget.isLoading
            ? const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(Colors.black54),
                ),
              )
            : Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
      ),
    );
  }
}
