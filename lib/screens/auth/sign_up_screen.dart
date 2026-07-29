import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../main.dart';
import 'sign_in_email_screen.dart';
import '../../theme.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _agreedToTerms = false;

  Future<void> _handleCreateAccount() async {
    final l = AppLocalizations.of(context);
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.t('auth_signup_snackbar_terms')),
          backgroundColor: KashfColors.gold,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.t('auth_signup_snackbar_created')),
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
          hint: l.t('auth_signup_fullname_hint'),
          icon: Icons.person_outline,
          keyboardType: TextInputType.name,
        ),
        SizedBox(height: AuthSpacing.gapBetweenItems),
        CustomTextField(
          hint: l.t('auth_signup_email_hint'),
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        SizedBox(height: AuthSpacing.gapBetweenItems),
        CustomTextField(
          hint: l.t('auth_signup_phone_hint'),
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        SizedBox(height: AuthSpacing.gapBetweenItems),
        CustomTextField(
          hint: l.t('auth_signup_password_hint'),
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
        CustomTextField(
          hint: l.t('auth_signup_confirm_hint'),
          icon: Icons.lock_outline,
          obscureText: !_showConfirmPassword,
          suffixIcon: IconButton(
            icon: Icon(
              _showConfirmPassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: KashfPalette.active.textSecondary,
            ),
            onPressed: () {
              setState(() => _showConfirmPassword = !_showConfirmPassword);
            },
          ),
        ),
        SizedBox(height: AuthSpacing.gapBetweenItems),
        Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: _agreedToTerms,
                onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
                activeColor: KashfColors.gold,
                checkColor: Colors.black,
                side: BorderSide(
                  color: KashfPalette.active.fieldBorder,
                  width: 2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    l.t('auth_signup_agree'),
                    style: TextStyle(
                      color: KashfPalette.active.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: Text(
                      ' ${l.t('auth_signup_terms')}',
                      style: const TextStyle(
                        color: KashfColors.gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    ' ${l.t('auth_signup_and')}',
                    style: TextStyle(
                      color: KashfPalette.active.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: Text(
                      ' ${l.t('auth_signup_privacy')}',
                      style: const TextStyle(
                        color: KashfColors.gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: AuthSpacing.gapBetweenItems),
        KashfPrimaryButton(
          label: l.t('auth_signup_submit'),
          onPressed: _handleCreateAccount,
          enabled: _agreedToTerms,
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
      title: l.t('auth_signup_title'),
      subtitle: l.t('auth_signup_subtitle'),
      body: body,
      footerPrompt: l.t('auth_footer_already'),
      footerAction: l.t('auth_signup_footer_action'),
      logoWidth: 120,
      compact: true,
      onFooterActionTap: () {
        Navigator.pushReplacement(
          context,
          kashfRoute(const SignInEmailScreen()),
        );
      },
    );
  }
}
