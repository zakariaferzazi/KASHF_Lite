import 'package:flutter/material.dart';

import 'sign_in_email_screen.dart';
import '../theme.dart';

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
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the Terms of Service'),
          backgroundColor: KashfColors.gold,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account created'),
        backgroundColor: KashfColors.gold,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CustomTextField(
          hint: 'Full name',
          icon: Icons.person_outline,
          keyboardType: TextInputType.name,
        ),
        const SizedBox(height: AuthSpacing.gapBetweenItems),
        const CustomTextField(
          hint: 'Email address',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: AuthSpacing.gapBetweenItems),
        const CustomTextField(
          hint: 'Phone number (optional)',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: AuthSpacing.gapBetweenItems),
        CustomTextField(
          hint: 'Create password',
          icon: Icons.lock_outline,
          obscureText: !_showPassword,
          suffixIcon: IconButton(
            icon: Icon(
              _showPassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: KashfColors.textSecondary,
            ),
            onPressed: () {
              setState(() => _showPassword = !_showPassword);
            },
          ),
        ),
        const SizedBox(height: AuthSpacing.gapBetweenItems),
        CustomTextField(
          hint: 'Confirm password',
          icon: Icons.lock_outline,
          obscureText: !_showConfirmPassword,
          suffixIcon: IconButton(
            icon: Icon(
              _showConfirmPassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: KashfColors.textSecondary,
            ),
            onPressed: () {
              setState(() => _showConfirmPassword = !_showConfirmPassword);
            },
          ),
        ),
        const SizedBox(height: AuthSpacing.gapBetweenItems),
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
                side: const BorderSide(
                  color: KashfColors.fieldBorder,
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
                  const Text(
                    'I agree to the ',
                    style: TextStyle(
                      color: KashfColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: const Text(
                      'Terms of Service',
                      style: TextStyle(
                        color: KashfColors.gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Text(
                    ' and ',
                    style: TextStyle(
                      color: KashfColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: const Text(
                      'Privacy Policy',
                      style: TextStyle(
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
        const SizedBox(height: AuthSpacing.gapBetweenItems),
        KashfPrimaryButton(
          label: 'Create Account',
          onPressed: _handleCreateAccount,
          enabled: _agreedToTerms,
        ),
        const SizedBox(height: AuthSpacing.gapDividerApple),
        const OrDivider(),
        const SizedBox(height: AuthSpacing.gapDividerApple),
        AppleButton(onTap: () {}, label: 'Continue with Apple'),
      ],
    );

    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'Start your research journey',
      body: body,
      footerPrompt: 'Already have an account? ',
      footerAction: 'Sign in',
      onFooterActionTap: () {
        Navigator.pushReplacement(context, kashfRoute(const SignInEmailScreen()));
      },
    );
  }
}
