import 'package:flutter/material.dart';
import 'package:kashf_lite/screens/sign_up_screen.dart';

import 'theme.dart';

class SignInEmailScreen extends StatefulWidget {
  const SignInEmailScreen({super.key});

  @override
  State<SignInEmailScreen> createState() => _SignInEmailScreenState();
}

class _SignInEmailScreenState extends State<SignInEmailScreen> {
  bool _showPassword = false;

  Future<void> _handleSignIn() async {
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Signed in'),
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
          hint: 'Email address',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: AuthSpacing.gapBetweenItems),
        CustomTextField(
          hint: 'Password',
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
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () {},
            child: const Text(
              'Forgot password?',
              style: TextStyle(
                color: KashfColors.gold,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: AuthSpacing.gapBetweenItems),
        KashfPrimaryButton(label: 'Sign In', onPressed: _handleSignIn),
        const SizedBox(height: AuthSpacing.gapDividerApple),
        const OrDivider(),
        const SizedBox(height: AuthSpacing.gapDividerApple),
        AppleButton(onTap: () {}, label: 'Continue with Apple'),
      ],
    );

    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in with your email',
      body: body,
      footerPrompt: "Don't have an account? ",
      footerAction: 'Sign up',
      onFooterActionTap: () {
        Navigator.pushReplacement(context, kashfRoute(const SignUpScreen()));
      },
    );
  }
}
