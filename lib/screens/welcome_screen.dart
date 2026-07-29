import 'package:flutter/material.dart';

import 'sign_in_email_screen.dart';
import 'continue_with_phone_screen.dart';
import 'sign_up_screen.dart';
import '../theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OptionTile(
          icon: Icons.mail_outline,
          label: 'Continue with Email',
          onTap: () {
            Navigator.push(context, kashfRoute(const SignInEmailScreen()));
          },
        ),
        const SizedBox(height: AuthSpacing.gapBetweenItems),
        OptionTile(
          icon: Icons.phone_outlined,
          label: 'Continue with Phone',
          onTap: () {
            Navigator.push(
              context,
              kashfRoute(const ContinueWithPhoneScreen()),
            );
          },
        ),
        const SizedBox(height: AuthSpacing.gapBetweenItems),
        const OrDivider(),
        const SizedBox(height: AuthSpacing.gapBetweenItems),
        AppleButton(onTap: () {}, label: 'Continue with Apple'),
      ],
    );

    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to continue your research',
      body: body,
      footerPrompt: "Don't have an account? ",
      footerAction: 'Sign up',
      showBackButton: false,
      compact: true,
      logoWidth: 120,
      onFooterActionTap: () {
        Navigator.push(context, kashfRoute(const SignUpScreen()));
      },
    );
  }
}
