import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../main.dart';
import '../../services/auth_service.dart';
import 'sign_up_screen.dart';
import '../../theme.dart';

class ContinueWithPhoneScreen extends StatefulWidget {
  const ContinueWithPhoneScreen({super.key});

  @override
  State<ContinueWithPhoneScreen> createState() =>
      _ContinueWithPhoneScreenState();
}

class _ContinueWithPhoneScreenState extends State<ContinueWithPhoneScreen> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final AuthService _auth = AuthService();

  bool _isSending = false;
  bool _isVerifying = false;
  String? _verificationId;
  final String _countryCode = '+966';

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  String _fullPhoneNumber() {
    final raw = _phoneCtrl.text.replaceAll(RegExp(r'\s+'), '');
    if (raw.startsWith('0')) return '$_countryCode${raw.substring(1)}';
    if (raw.startsWith('+')) return raw;
    return '$_countryCode$raw';
  }

  Future<void> _handleSendCode() async {
    if (_isSending) return;
    final l = AppLocalizations.of(context);
    final phoneNumber = _fullPhoneNumber();
    if (phoneNumber.length < 8) {
      _showError(l.t('auth_phone_hint_invalid'));
      return;
    }
    setState(() => _isSending = true);
    try {
      await _auth.startPhoneLogin(
        phoneNumber: phoneNumber,
        language: l.language,
        onCodeSent: (verificationId) {
          if (!mounted) return;
          setState(() => _verificationId = verificationId);
          _showInfo(l.tp('auth_phone_code_sent', {'phone': phoneNumber}));
        },
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _handleVerifyCode() async {
    if (_isVerifying) return;
    final l = AppLocalizations.of(context);
    final verificationId = _verificationId;
    final code = _codeCtrl.text.trim();
    if (verificationId == null) {
      _showError(l.t('auth_phone_need_send_first'));
      return;
    }
    if (code.length < 4) {
      _showError(l.t('auth_phone_need_code'));
      return;
    }
    setState(() => _isVerifying = true);
    try {
      await _auth.confirmPhoneCode(
        verificationId: verificationId,
        smsCode: code,
        language: l.language,
      );
      // Auth gate swaps to HomeShell automatically.
    } on AuthException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _isVerifying = false);
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

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: KashfColors.gold,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final inOtpStage = _verificationId != null;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!inOtpStage) ..._phoneStage(context, l) else ..._otpStage(context, l),
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

  List<Widget> _phoneStage(BuildContext context, AppLocalizations l) {
    return [
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
                  const Text('����', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    _countryCode,
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
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                style: TextStyle(
                  color: KashfPalette.active.textPrimary,
                  fontSize: 15,
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleSendCode(),
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
        label: _isSending ? l.t('auth_phone_sending') : l.t('auth_phone_submit'),
        onPressed: _isSending ? null : _handleSendCode,
        enabled: !_isSending,
      ),
    ];
  }

  List<Widget> _otpStage(BuildContext context, AppLocalizations l) {
    return [
      Text(
        l.tp('auth_phone_otp_prompt', {'phone': _fullPhoneNumber()}),
        style: TextStyle(
          color: KashfPalette.active.textSecondary,
          fontSize: 13,
        ),
      ),
      const SizedBox(height: AuthSpacing.gapBetweenItems),
      CustomTextField(
        controller: _codeCtrl,
        hint: '------',
        icon: Icons.sms_outlined,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _handleVerifyCode(),
      ),
      const SizedBox(height: AuthSpacing.gapBetweenItems),
      KashfPrimaryButton(
        label: _isVerifying ? l.t('auth_phone_verifying') : l.t('auth_phone_verify'),
        onPressed: _isVerifying ? null : _handleVerifyCode,
        enabled: !_isVerifying,
      ),
      const SizedBox(height: AuthSpacing.gapBetweenItems),
      Align(
        alignment: AlignmentDirectional.centerEnd,
        child: GestureDetector(
          onTap: _isSending ? null : _handleSendCode,
          child: Text(
            l.t('auth_phone_resend'),
            style: TextStyle(
              color: KashfColors.gold,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ];
  }
}
