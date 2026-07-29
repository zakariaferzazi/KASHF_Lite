import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../main.dart';
import 'sign_in_email_screen.dart';
import 'continue_with_phone_screen.dart';
import 'sign_up_screen.dart';
import '../../theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OptionTile(
          icon: Icons.mail_outline,
          label: l.t('auth_welcome_body_email'),
          onTap: () {
            Navigator.push(context, kashfRoute(const SignInEmailScreen()));
          },
        ),
        const SizedBox(height: AuthSpacing.gapBetweenItems),
        OptionTile(
          icon: Icons.phone_outlined,
          label: l.t('auth_welcome_body_phone'),
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
        AppleButton(
          onTap: () => navigateToHome(context),
          label: l.t('auth_welcome_body_apple'),
        ),
      ],
    );

    return AuthScaffold(
      title: l.t('auth_welcome_title'),
      subtitle: l.t('auth_welcome_subtitle'),
      body: body,
      footerPrompt: l.t('auth_signup_agree_fallback'),
      footerAction: l.t('auth_welcome_footer_action'),
      showBackButton: false,
      compact: true,
      logoWidth: 120,
      onFooterActionTap: () {
        Navigator.push(context, kashfRoute(const SignUpScreen()));
      },
    );
  }
}
