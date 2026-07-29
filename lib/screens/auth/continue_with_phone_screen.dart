import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../main.dart';
import 'sign_up_screen.dart';
import '../../theme.dart';

class ContinueWithPhoneScreen extends StatefulWidget {
  const ContinueWithPhoneScreen({super.key});

  @override
  State<ContinueWithPhoneScreen> createState() =>
      _ContinueWithPhoneScreenState();
}

class _ContinueWithPhoneScreenState extends State<ContinueWithPhoneScreen> {
  Future<void> _handleSend() async {
    final l = AppLocalizations.of(context);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.t('auth_phone_snackbar_sent')),
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
        Container(
          decoration: BoxDecoration(
            color: KashfPalette.active.fieldFill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: KashfPalette.active.fieldBorder),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                child: Row(
                  children: [
                    const Text('🇸🇦', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text(
                      l.t('auth_phone_dial_code'),
                      style: TextStyle(
                        color: KashfPalette.active.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down,
                      color: KashfPalette.active.textSecondary,
                      size: 20,
                    ),
                  ],
                ),
              ),
              Container(
                height: 28,
                width: 1,
                color: KashfPalette.active.fieldBorder,
              ),
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.phone,
                  style: TextStyle(
                    color: KashfPalette.active.textPrimary,
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    hintText: l.t('auth_phone_hint'),
                    hintStyle: TextStyle(
                      color: KashfPalette.active.textSecondary,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AuthSpacing.gapBetweenItems),
        KashfPrimaryButton(
          label: l.t('auth_phone_submit'),
          onPressed: _handleSend,
        ),
        const SizedBox(height: AuthSpacing.gapDividerApple),
        const OrDivider(),
        const SizedBox(height: AuthSpacing.gapDividerApple),
        AppleButton(
          onTap: () => navigateToHome(context),
          label: l.t('auth_welcome_body_apple'),
        ),
      ],
    );

    return AuthScaffold(
      title: l.t('auth_phone_title'),
      subtitle: l.t('auth_phone_subtitle'),
      body: body,
      footerPrompt: l.t('auth_signup_agree_fallback'),
      footerAction: l.t('auth_phone_footer_action'),
      logoWidth: 120,
      compact: true,
      onFooterActionTap: () {
        Navigator.pushReplacement(context, kashfRoute(const SignUpScreen()));
      },
    );
  }
}
