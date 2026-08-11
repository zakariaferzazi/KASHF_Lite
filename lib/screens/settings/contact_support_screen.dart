import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_strings.dart';
import '../../theme.dart';
import 'settings_scaffold.dart';

/// A working contact form that opens the device's default mail
/// client with a pre-filled message addressed to
/// `Nawaff89@gmail.com`.
///
/// Flutter does not provide a built-in way to send arbitrary email
/// programmatically — every app store (Apple, Google) blocks apps
/// that try to send email silently without user consent. So we
/// use `url_launcher` to launch a `mailto:` URL which always
/// surfaces a "Send" button the user must tap. This is the same
/// approach used by virtually every production app.
class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  /// The destination address. Surfaced as a constant so tests can
  /// patch it without touching call sites.
  static const String supportEmail = 'Nawaff89@gmail.com';

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _email.text = user.email ?? '';
      _name.text = user.displayName ?? '';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  String? _validate(AppLocalizations l) {
    if (_name.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _message.text.trim().isEmpty) {
      return l.t('settings_support_validation_required');
    }
    final email = _email.text.trim();
    final emailOk = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!emailOk) {
      return l.t('settings_support_validation_email');
    }
    return null;
  }

  Future<void> _send() async {
    final l = AppLocalizations.of(context);
    final err = _validate(l);
    if (err != null) {
      showKashfErrorSnackBar(context, err);
      return;
    }
    setState(() => _sending = true);
    final subject = _subject.text.trim().isEmpty
        ? 'KASHF Lite support'
        : _subject.text.trim();
    final body = '''
From: ${_name.text.trim()} <${_email.text.trim()}>

${_message.text.trim()}
''';
    final uri = Uri(
      scheme: 'mailto',
      path: ContactSupportScreen.supportEmail,
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );
    try {
      final ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;
      if (ok) {
        showKashfSnackBar(context, l.t('settings_support_send_done'));
      } else {
        // No mail app installed. Fall back to a clipboard copy so the
        // user can paste the message somewhere else, and tell them.
        await Clipboard.setData(
          ClipboardData(
            text: 'To: ${ContactSupportScreen.supportEmail}\n'
                'Subject: $subject\n\n$body',
          ),
        );
        if (!mounted) return;
        showKashfSnackBar(context, l.t('settings_support_send_no_email_app'));
      }
    } catch (_) {
      if (!mounted) return;
      showKashfErrorSnackBar(context, l.t('settings_support_send_failed'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _openDirectMail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: ContactSupportScreen.supportEmail,
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final palette = KashfPalette.active;
    return SettingsScaffold(
      title: l.t('settings_support_title'),
      child: ListView(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.cardBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: palette.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: palette.cardBorder),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.mail_outline_rounded,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.t('settings_support_subtitle'),
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 12.5,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ContactSupportScreen.supportEmail,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _Field(
            label: l.t('settings_support_name'),
            controller: _name,
            palette: palette,
          ),
          const SizedBox(height: 10),
          _Field(
            label: l.t('settings_support_email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            palette: palette,
          ),
          const SizedBox(height: 10),
          _Field(
            label: l.t('settings_support_subject'),
            controller: _subject,
            palette: palette,
          ),
          const SizedBox(height: 10),
          _Field(
            label: l.t('settings_support_message'),
            controller: _message,
            palette: palette,
            maxLines: 6,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.black),
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _sending
                    ? l.t('settings_support_sending')
                    : l.t('settings_support_send'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: KashfColors.gold,
                foregroundColor: Colors.black,
                disabledBackgroundColor:
                    KashfColors.gold.withValues(alpha: 0.4),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _openDirectMail,
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: Text(l.t('settings_support_email_direct')),
            style: TextButton.styleFrom(
              foregroundColor: palette.textSecondary,
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.palette,
    this.keyboardType,
    this.maxLines = 1,
  });
  final String label;
  final TextEditingController controller;
  final KashfPalette palette;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: palette.fieldFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.fieldBorder),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: TextStyle(color: palette.textPrimary, fontSize: 14.5),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
