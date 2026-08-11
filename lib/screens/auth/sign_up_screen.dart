import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../main.dart';
import '../../services/auth_service.dart';
import '../../services/settings_scope.dart';
import '../../theme.dart';
import '../../widgets/country_picker.dart';
import 'auth_social_block.dart';
import 'sign_in_email_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final AuthService _auth = AuthService();

  /// Selected country — required to create the account.
  CountryInfo? _country;

  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _agreedToTerms = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCountry() async {
    final selected = await showCountryPicker(
      context,
      currentDialCode: _country?.dial,
    );
    if (selected != null && mounted) {
      setState(() => _country = selected);
    }
  }

  Future<void> _handleCreateAccount() async {
    final l = AppLocalizations.of(context);
    final prefs = SettingsScope.of(context);
    if (_isLoading) return;

    // Country is required — the app uses it across the board (search
    // defaults, AI prompts, market data, monitoring alerts, …). Don't
    // even attempt Firebase until we know where the user lives.
    if (_country == null) {
      _showError(l.t('auth_signup_country_required'));
      return;
    }
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

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    if (!emailRegex.hasMatch(email)) {
      _showError(l.t('auth_email_invalid'));
      return;
    }
    if (password.length < 6) {
      _showError(l.t('auth_password_too_short'));
      return;
    }
    if (password != confirm) {
      _showError(l.t('auth_password_mismatch'));
      return;
    }

    // Dismiss the keyboard so the spinner isn't fighting the IME.
    FocusManager.instance.primaryFocus?.unfocus();

    // Flip the loading flag BEFORE the Firebase call so the button
    // is disabled for the entire network round-trip. Without this,
    // a second tap (or the keyboard's "Done" auto-submit) could fire
    // while the first call is still in-flight, which would race with
    // Firebase and look like the account was created before the click.
    setState(() => _isLoading = true);
    try {
      await _auth.signUpWithEmail(
        email: email,
        password: password,
        displayName: _nameCtrl.text,
        language: l.language,
      );
      // Persist the country so every AI feature (search, home,
      // market, monitoring) picks it up automatically — no need for
      // the user to revisit Settings → Search preferences.
      await prefs.setUserCountry(_country!.dial);
      // Show the success popup on the root overlay while we navigate.
      // We don't await it so the redirect is never blocked by the
      // popup's animation lifecycle.
      if (!mounted) return;
      // ignore: discarded_futures
      SuccessPopup.show(
        context,
        title: l.t('auth_signup_snackbar_created'),
        message: l.t('auth_signup_welcome'),
      );
      // Safety net: explicitly push HomeShell so the redirect is
      // guaranteed even if the auth gate's stream listener is slow.
      if (!mounted) return;
      navigateToHome(context);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(e.toString());
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final palette = KashfPalette.active;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomTextField(
          controller: _nameCtrl,
          hint: l.t('auth_signup_fullname_hint'),
          icon: Icons.person_outline,
          keyboardType: TextInputType.name,
          textInputAction: TextInputAction.next,
        ),
        SizedBox(height: AuthSpacing.gapBetweenItems),
        CustomTextField(
          controller: _emailCtrl,
          hint: l.t('auth_signup_email_hint'),
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        SizedBox(height: AuthSpacing.gapBetweenItems),
        // Country picker — required to create the account. We render
        // it with the same look as the phone-code picker so the user
        // gets a consistent UX across the auth flow.
        _CountryField(
          country: _country,
          onTap: _pickCountry,
          hint: l.t('auth_signup_country_hint'),
          palette: palette,
        ),
        SizedBox(height: AuthSpacing.gapBetweenItems),
        CustomTextField(
          controller: _phoneCtrl,
          hint: l.t('auth_signup_phone_hint'),
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
        ),
        SizedBox(height: AuthSpacing.gapBetweenItems),
        CustomTextField(
          controller: _passwordCtrl,
          hint: l.t('auth_signup_password_hint'),
          icon: Icons.lock_outline,
          obscureText: !_showPassword,
          textInputAction: TextInputAction.next,
          suffixIcon: IconButton(
            icon: Icon(
              _showPassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: palette.textSecondary,
            ),
            onPressed: () {
              setState(() => _showPassword = !_showPassword);
            },
          ),
        ),
        SizedBox(height: AuthSpacing.gapBetweenItems),
        CustomTextField(
          controller: _confirmCtrl,
          hint: l.t('auth_signup_confirm_hint'),
          icon: Icons.lock_outline,
          obscureText: !_showConfirmPassword,
          textInputAction: TextInputAction.done,
          suffixIcon: IconButton(
            icon: Icon(
              _showConfirmPassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: palette.textSecondary,
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
                  color: Colors.white,
                  width: 2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                // Combine all four phrases into a single Text.rich so
                // Flutter's bidi algorithm handles the Arabic reading
                // order correctly. Wrapping each phrase in a separate
                // Text widget forced LTR child ordering and made the
                // Arabic look reversed. The Tappable terms/privacy
                // links are kept as inline WidgetSpans so they remain
                // visually distinct and tappable.
                TextSpan(
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 13,
                  ),
                  children: [
                    TextSpan(text: l.t('auth_signup_agree')),
                    const TextSpan(text: ' '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: _LinkSpan(
                        text: l.t('auth_signup_terms'),
                        onTap: () {},
                      ),
                    ),
                    TextSpan(
                      text: ' ${l.t('auth_signup_and')} ',
                    ),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: _LinkSpan(
                        text: l.t('auth_signup_privacy'),
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: AuthSpacing.gapBetweenItems),
        KashfPrimaryButton(
          label: _isLoading
              ? l.t('auth_signup_loading')
              : l.t('auth_signup_submit'),
          onPressed: _handleCreateAccount,
          enabled: _agreedToTerms,
          loading: _isLoading,
        ),
        SizedBox(height: AuthSpacing.gapDividerApple),
        const AuthSocialBlock(),
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

/// Country picker field — same visual treatment as [CustomTextField]
/// but renders the flag-less dial-code + country name when a
/// [CountryInfo] is selected, and a placeholder hint otherwise.
class _CountryField extends StatelessWidget {
  const _CountryField({
    required this.country,
    required this.onTap,
    required this.hint,
    required this.palette,
  });

  final CountryInfo? country;
  final VoidCallback onTap;
  final String hint;
  final KashfPalette palette;

  @override
  Widget build(BuildContext context) {
    final selected = country != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: palette.fieldFill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? palette.fieldBorder : KashfColors.gold
                  .withValues(alpha: 0.6),
              width: selected ? 1 : 1.2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.public_rounded,
                color: palette.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  selected
                      ? '${country!.dial}  ${country!.name}'
                      : hint,
                  style: TextStyle(
                    color: selected
                        ? palette.textPrimary
                        : palette.textSecondary,
                    fontSize: 15,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: palette.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline tappable link used inside [Text.rich] for the sign-up
/// terms/privacy agreement. Rendered as a [WidgetSpan] so Flutter's
/// bidi algorithm still handles the surrounding Arabic text
/// correctly when this widget is mixed with regular [TextSpan]s.
class _LinkSpan extends StatelessWidget {
  const _LinkSpan({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: const TextStyle(
          color: KashfColors.gold,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}