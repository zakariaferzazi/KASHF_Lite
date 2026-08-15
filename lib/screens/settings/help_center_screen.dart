import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../theme.dart';
import 'contact_support_screen.dart';
import 'settings_scaffold.dart';

/// FAQ list with a primary CTA that hands the user off to the
/// contact-support flow.
class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final palette = KashfPalette.active;
    final entries = <_Faq>[
      _Faq(l.t('settings_help_q1'), l.t('settings_help_a1')),
      _Faq(l.t('settings_help_q2'), l.t('settings_help_a2')),
      _Faq(l.t('settings_help_q3'), l.t('settings_help_a3')),
      _Faq(l.t('settings_help_q4'), l.t('settings_help_a4')),
      _Faq(l.t('settings_help_q5'), l.t('settings_help_a5')),
    ];
    return SettingsScaffold(
      title: l.t('settings_help_title'),
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
              l.t('settings_help_subtitle'),
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...entries.expand((e) sync* {
            yield _FaqTile(entry: e, palette: palette);
            yield const SizedBox(height: 10);
          }),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ContactSupportScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.support_agent_rounded, size: 18),
              label: Text(l.t('settings_help_contact_action')),
              style: ElevatedButton.styleFrom(
                backgroundColor: KashfColors.gold,
                foregroundColor: Colors.black,
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

class _Faq {
  const _Faq(this.question, this.answer);
  final String question;
  final String answer;
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.entry, required this.palette});
  final _Faq entry;
  final KashfPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Theme(
        // Removes the default ExpansionTile divider so the surface
        // looks like a single rounded card.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          iconColor: palette.textSecondary,
          collapsedIconColor: palette.textSecondary,
          title: Text(
            entry.question,
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                entry.answer,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
