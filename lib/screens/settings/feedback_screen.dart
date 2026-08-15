import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_strings.dart';
import '../../theme.dart';
import 'contact_support_screen.dart';
import 'settings_scaffold.dart';

/// Lets the user send a quick piece of feedback. Pre-fills a
/// `mailto:` link routed to [ContactSupportScreen.supportEmail].
///
/// Flutter doesn't allow silent email sending, so we use the
/// device's mail client. The user always sees the message and has
/// to tap "Send" — which is the right UX for a feedback channel.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _message = TextEditingController();
  String _category = 'idea';
  bool _sending = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  String _categoryLabel(AppLocalizations l) {
    switch (_category) {
      case 'bug':
        return l.t('settings_feedback_cat_bug');
      case 'idea':
        return l.t('settings_feedback_cat_idea');
      default:
        return l.t('settings_feedback_cat_other');
    }
  }

  Future<void> _send() async {
    final l = AppLocalizations.of(context);
    if (_message.text.trim().isEmpty) {
      showKashfErrorSnackBar(context, l.t('settings_feedback_validation'));
      return;
    }
    setState(() => _sending = true);
    final subject =
        'KASHF Lite feedback — ${_categoryLabel(l)}';
    final body = '''
Category: ${_categoryLabel(l)}

${_message.text.trim()}
''';
    final uri = Uri(
      scheme: 'mailto',
      path: ContactSupportScreen.supportEmail,
      queryParameters: {'subject': subject, 'body': body},
    );
    try {
      final ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;
      if (ok) {
        showKashfSnackBar(context, l.t('settings_feedback_sent'));
      } else {
        showKashfErrorSnackBar(context, l.t('settings_feedback_failed'));
      }
    } catch (_) {
      if (!mounted) return;
      showKashfErrorSnackBar(context, l.t('settings_feedback_failed'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final palette = KashfPalette.active;
    return SettingsScaffold(
      title: l.t('settings_feedback_title'),
      child: ListView(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.cardBorder),
            ),
            child: Text(
              l.t('settings_feedback_subtitle'),
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            l.t('settings_feedback_category'),
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _Chip(
                label: l.t('settings_feedback_cat_bug'),
                selected: _category == 'bug',
                onTap: () => setState(() => _category = 'bug'),
                palette: palette,
              ),
              _Chip(
                label: l.t('settings_feedback_cat_idea'),
                selected: _category == 'idea',
                onTap: () => setState(() => _category = 'idea'),
                palette: palette,
              ),
              _Chip(
                label: l.t('settings_feedback_cat_other'),
                selected: _category == 'other',
                onTap: () => setState(() => _category = 'other'),
                palette: palette,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l.t('settings_feedback_message'),
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
              controller: _message,
              maxLines: 8,
              style: TextStyle(color: palette.textPrimary, fontSize: 14.5),
              decoration: InputDecoration(
                hintText: l.t('settings_feedback_message'),
                hintStyle: TextStyle(color: palette.textSecondary),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
            ),
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
                    ? l.t('settings_feedback_sending')
                    : l.t('settings_feedback_send'),
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
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.palette,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final KashfPalette palette;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? KashfColors.gold : palette.surfaceLight,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? KashfColors.gold : palette.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : palette.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
