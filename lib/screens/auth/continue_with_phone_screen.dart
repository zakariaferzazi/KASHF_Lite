import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' show PhoneAuthCredential;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_strings.dart';
import '../../services/auth_service.dart';
import '../../widgets/country_picker.dart';
import 'auth_social_block.dart';
import 'sign_up_screen.dart';
import '../../theme.dart';

/// Phone sign-in flow.
///
/// Two stages:
///   1. The user enters their phone number (E.164) and taps "Send code".
///      We call [AuthService.startPhoneLogin] which dispatches the SMS
///      and surfaces the `verificationId` via `onCodeSent`.
///   2. The user enters the 6-digit OTP. We call
///      [AuthService.confirmPhoneCode]. The auth gate routes the user
///      to the home shell on success.
///
/// Sub-features:
///   * Country picker — shared with the signup screen via
///     [showCountryPicker] from `country_picker.dart`.
///   * 60-second resend cooldown to prevent SMS spam.
///   * Auto-OTP focus when entering the OTP stage.
///   * On Android, if Firebase auto-retrieves the SMS via the system
///     SMS Retriever, we sign in directly with the returned credential
///     — the user never has to type a code.
class ContinueWithPhoneScreen extends StatefulWidget {
  const ContinueWithPhoneScreen({super.key});

  @override
  State<ContinueWithPhoneScreen> createState() =>
      _ContinueWithPhoneScreenState();
}

class _ContinueWithPhoneScreenState extends State<ContinueWithPhoneScreen> {
  // -------- State -----------------------------------------------------
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _phoneFocus = FocusNode();
  final _codeFocus = FocusNode();
  final _auth = AuthService();

  String _dialCode = '+966';
  bool _isSending = false;
  bool _isVerifying = false;

  /// `verificationId` returned by Firebase once the SMS is dispatched.
  /// `null` while we're still on the phone-entry stage.
  String? _verificationId;

  /// Resend token from the previous `codeSent` — required by Firebase
  /// to re-send to the same number without rate-limiting.
  int? _resendToken;

  /// Snapshot of the phone number at the moment we sent the code. We
  /// use this in the OTP prompt so the message doesn't shift when the
  /// user edits the phone field.
  String? _sentPhone;

  /// Cooldown for the "Resend code" button. Counted down every second.
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  static const int _resendCooldownSeconds = 60;
  static const int _otpLength = 6;

  // -------- Lifecycle -------------------------------------------------
  @override
  void initState() {
    super.initState();
    _codeCtrl.addListener(_onCodeChanged);
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _codeCtrl.removeListener(_onCodeChanged);
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _phoneFocus.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  void _onCodeChanged() {
    // Auto-submit when 6 digits are typed.
    final code = _codeCtrl.text.trim();
    if (code.length == _otpLength && _verificationId != null && !_isVerifying) {
      _handleVerifyCode();
    }
  }

  // -------- Phone number helpers --------------------------------------
  String _fullPhoneNumber() {
    final raw = _phoneCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    final cc = _dialCode.replaceAll('+', '');
    if (raw.isEmpty) return _dialCode;
    // User typed the full international number including the country
    // code prefix — trust them.
    if (_dialCode.length > 1 &&
        _phoneCtrl.text.trim().startsWith('+') &&
        raw.length >= cc.length + 6) {
      return '+${raw.substring(cc.length)}'.startsWith('+$_dialCode')
          ? '+$raw'
          : '$_dialCode$raw';
    }
    // Strip a local leading 0 so "+966 5XX" works the same as
    // "+966 055...".
    final trimmed = raw.startsWith('0') ? raw.substring(1) : raw;
    return '$_dialCode$trimmed';
  }

  /// Returns true if [phone] is a plausible E.164 number:
  /// `+` followed by 8–15 digits (the E.164 spec range).
  bool _isValidE164(String phone) {
    return RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(phone);
  }

  // -------- Country picker -------------------------------------------
  Future<void> _pickCountry() async {
    final selected = await showCountryPicker(context, currentDialCode: _dialCode);
    if (selected != null && mounted) {
      setState(() => _dialCode = selected.dial);
    }
  }

  // -------- Stage 1 — send code --------------------------------------
  Future<void> _handleSendCode({bool isResend = false}) async {
    if (_isSending) return;
    final l = AppLocalizations.of(context);
    final phoneNumber = _fullPhoneNumber();
    if (!_isValidE164(phoneNumber)) {
      _showError(l.t('auth_phone_hint_invalid'));
      return;
    }
    setState(() => _isSending = true);
    try {
      await _auth.startPhoneLogin(
        phoneNumber: phoneNumber,
        language: l.language,
        forceResendingToken: isResend ? _resendToken : null,
        onCodeSent: (verificationId) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _sentPhone = phoneNumber;
            _isSending = false;
          });
          _startResendCooldown();
          _showInfo(
            l.tp('auth_phone_code_sent', {'phone': phoneNumber}),
          );
          // Move focus to the OTP field on the next frame.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _codeFocus.requestFocus();
          });
        },
        onCodeResent: (token) {
          if (!mounted) return;
          setState(() => _resendToken = token ?? _resendToken);
        },
        onAutoVerifiedCredential: (PhoneAuthCredential credential) async {
          // Android SMS Retriever API succeeded. Sign the user in
          // directly — they never see the OTP stage.
          if (!mounted) return;
          try {
            await _auth.signInWithCredential(credential, language: l.language);
          } on AuthException catch (e) {
            if (!mounted) return;
            setState(() => _isSending = false);
            _showError(e.message);
          }
        },
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      _showError(e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      _showError(e.toString());
    }
  }

  // -------- Stage 2 — verify code -------------------------------------
  Future<void> _handleVerifyCode() async {
    if (_isVerifying) return;
    final l = AppLocalizations.of(context);
    final verificationId = _verificationId;
    final code = _codeCtrl.text.trim();
    if (verificationId == null) {
      _showError(l.t('auth_phone_need_send_first'));
      return;
    }
    if (code.length != _otpLength) {
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
      // Auth gate swaps to HomeShell automatically via
      // FirebaseAuth.authStateChanges().
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _isVerifying = false);
      _showError(e.message);
      // Wipe the OTP field so the user can re-type without confusion.
      _codeCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isVerifying = false);
      _showError(e.toString());
    }
  }

  void _handleChangeNumber() {
    setState(() {
      _verificationId = null;
      _sentPhone = null;
      _resendToken = null;
      _codeCtrl.clear();
      _cooldownTimer?.cancel();
      _resendCooldown = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _phoneFocus.requestFocus();
    });
  }

  // -------- Resend cooldown ------------------------------------------
  void _startResendCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _resendCooldown = _resendCooldownSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) {
          timer.cancel();
        }
      });
    });
  }

  bool get _canResend => _resendCooldown <= 0 && !_isSending;

  // -------- Snackbars -------------------------------------------------
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444)),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: KashfPalette.active.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFEF4444)),
        ),
      ),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Color(0xFF22C55E)),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: KashfPalette.active.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF22C55E)),
        ),
      ),
    );
  }

  // -------- Build -----------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final inOtpStage = _verificationId != null;

    return AuthScaffold(
      title: l.t('auth_phone_title'),
      subtitle: l.t('auth_phone_subtitle'),
      footerPrompt: l.t('auth_signup_agree_fallback'),
      footerAction: l.t('auth_phone_footer_action'),
      logoWidth: 120,
      compact: true,
      onFooterActionTap: () {
        Navigator.pushReplacement(context, kashfRoute(const SignUpScreen()));
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!inOtpStage)
            _PhoneStage(
              phoneCtrl: _phoneCtrl,
              phoneFocus: _phoneFocus,
              dialCode: _dialCode,
              onPickCountry: _pickCountry,
              onSend: _handleSendCode,
              isSending: _isSending,
              submitLabel: l.t('auth_phone_submit'),
              sendingLabel: l.t('auth_phone_sending'),
              hintLabel: l.t('auth_phone_hint'),
              countryLabel: l.t('auth_phone_change_country'),
            )
          else
            _OtpStage(
              codeCtrl: _codeCtrl,
              codeFocus: _codeFocus,
              phoneNumber: _sentPhone ?? '',
              prompt: l.tp(
                'auth_phone_otp_prompt',
                {'phone': _sentPhone ?? ''},
              ),
              isVerifying: _isVerifying,
              verifyLabel: l.t('auth_phone_verify'),
              verifyingLabel: l.t('auth_phone_verifying'),
              resendLabel: l.t('auth_phone_resend'),
              resendInLabel: l.tp(
                'auth_phone_resend_in',
                {'seconds': _resendCooldown.toString()},
              ),
              changeNumberLabel: l.t('auth_phone_change_number'),
              onVerify: _handleVerifyCode,
              onResend: () => _handleSendCode(isResend: true),
              onChangeNumber: _handleChangeNumber,
              canResend: _canResend,
            ),
          const SizedBox(height: AuthSpacing.gapDividerApple),
          // Apple block — gated to iOS/macOS.
          const AuthSocialBlock(),
        ],
      ),
    );
  }
}

// =====================================================================
// Phone stage — collect the phone number and dial code.
// =====================================================================
class _PhoneStage extends StatelessWidget {
  const _PhoneStage({
    required this.phoneCtrl,
    required this.phoneFocus,
    required this.dialCode,
    required this.onPickCountry,
    required this.onSend,
    required this.isSending,
    required this.submitLabel,
    required this.sendingLabel,
    required this.hintLabel,
    required this.countryLabel,
  });

  final TextEditingController phoneCtrl;
  final FocusNode phoneFocus;
  final String dialCode;
  final VoidCallback onPickCountry;
  final Future<void> Function() onSend;
  final bool isSending;
  final String submitLabel;
  final String sendingLabel;
  final String hintLabel;
  final String countryLabel;

  @override
  Widget build(BuildContext context) {
    final palette = KashfPalette.active;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: palette.fieldFill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.fieldBorder),
          ),
          child: Row(
            children: [
              // Country-code picker
              Semantics(
                label: countryLabel,
                button: true,
                child: InkWell(
                  onTap: onPickCountry,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 18,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          dialCode,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: palette.textSecondary,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                height: 28,
                width: 1,
                color: palette.fieldBorder,
              ),
              Expanded(
                child: TextField(
                  controller: phoneCtrl,
                  focusNode: phoneFocus,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(15),
                  ],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onSend(),
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: hintLabel,
                    hintStyle: TextStyle(
                      color: palette.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
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
          label: isSending ? sendingLabel : submitLabel,
          onPressed: isSending ? null : onSend,
          enabled: !isSending,
        ),
      ],
    );
  }
}

// =====================================================================
// OTP stage — enter the 6-digit code.
// =====================================================================
class _OtpStage extends StatefulWidget {
  const _OtpStage({
    required this.codeCtrl,
    required this.codeFocus,
    required this.phoneNumber,
    required this.prompt,
    required this.isVerifying,
    required this.verifyLabel,
    required this.verifyingLabel,
    required this.resendLabel,
    required this.resendInLabel,
    required this.changeNumberLabel,
    required this.onVerify,
    required this.onResend,
    required this.onChangeNumber,
    required this.canResend,
  });

  final TextEditingController codeCtrl;
  final FocusNode codeFocus;
  final String phoneNumber;
  final String prompt;
  final bool isVerifying;
  final String verifyLabel;
  final String verifyingLabel;
  final String resendLabel;
  final String resendInLabel;
  final String changeNumberLabel;
  final Future<void> Function() onVerify;
  final Future<void> Function() onResend;
  final VoidCallback onChangeNumber;
  final bool canResend;

  @override
  State<_OtpStage> createState() => _OtpStageState();
}

class _OtpStageState extends State<_OtpStage> {
  @override
  void initState() {
    super.initState();
    // Auto-focus the OTP field as soon as we enter this stage so the
    // user can paste/type without an extra tap.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.codeFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = KashfPalette.active;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.prompt,
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AuthSpacing.gapBetweenItems),
        Container(
          decoration: BoxDecoration(
            color: palette.fieldFill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.fieldBorder),
          ),
          child: TextField(
            controller: widget.codeCtrl,
            focusNode: widget.codeFocus,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => widget.onVerify(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 8,
            ),
            decoration: InputDecoration(
              hintText: '\u2014 \u2014 \u2014 \u2014 \u2014 \u2014',
              hintStyle: TextStyle(
                color: palette.textSecondary,
                fontSize: 22,
                letterSpacing: 8,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 18,
              ),
            ),
          ),
        ),
        const SizedBox(height: AuthSpacing.gapBetweenItems),
        KashfPrimaryButton(
          label: widget.isVerifying ? widget.verifyingLabel : widget.verifyLabel,
          onPressed: widget.isVerifying ? null : widget.onVerify,
          enabled: !widget.isVerifying,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: widget.onChangeNumber,
              child: Text(
                widget.changeNumberLabel,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            GestureDetector(
              onTap: widget.canResend ? widget.onResend : null,
              child: Text(
                widget.canResend
                    ? widget.resendLabel
                    : widget.resendInLabel,
                style: TextStyle(
                  color: widget.canResend
                      ? KashfColors.gold
                      : palette.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}