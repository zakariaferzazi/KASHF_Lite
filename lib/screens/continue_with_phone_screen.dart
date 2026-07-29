import 'package:flutter/material.dart';

import 'sign_up_screen.dart';
import '../theme.dart';

class ContinueWithPhoneScreen extends StatefulWidget {
  const ContinueWithPhoneScreen({super.key});

  @override
  State<ContinueWithPhoneScreen> createState() =>
      _ContinueWithPhoneScreenState();
}

class _ContinueWithPhoneScreenState extends State<ContinueWithPhoneScreen> {
  Future<void> _handleSend() async {
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Verification code sent'),
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
        Container(
          decoration: BoxDecoration(
            color: KashfColors.fieldFill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: KashfColors.fieldBorder),
          ),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                child: Row(
                  children: [
                    Text('🇸🇦', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 8),
                    Text(
                      '+966',
                      style: TextStyle(
                        color: KashfColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down,
                      color: KashfColors.textSecondary,
                      size: 20,
                    ),
                  ],
                ),
              ),
              Container(height: 28, width: 1, color: KashfColors.fieldBorder),
              const Expanded(
                child: TextField(
                  keyboardType: TextInputType.phone,
                  style: TextStyle(
                    color: KashfColors.textPrimary,
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Phone number',
                    hintStyle: TextStyle(color: KashfColors.textSecondary),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
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
        KashfPrimaryButton(label: 'Send Code', onPressed: _handleSend),
        const SizedBox(height: AuthSpacing.gapDividerApple),
        const OrDivider(),
        const SizedBox(height: AuthSpacing.gapDividerApple),
        AppleButton(onTap: () {}, label: 'Continue with Apple'),
      ],
    );

    return AuthScaffold(
      title: 'Continue with Phone',
      subtitle: "We'll send a verification code to your number",
      body: body,
      footerPrompt: "Don't have an account? ",
      footerAction: 'Sign up',
      onFooterActionTap: () {
        Navigator.pushReplacement(context, kashfRoute(const SignUpScreen()));
      },
    );
  }
}
