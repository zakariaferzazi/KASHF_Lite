import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../theme.dart';

/// Full-screen privacy policy viewer. Reached from the
/// "Privacy policy" tile in Settings.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final sections = <_PrivacySection>[
      _PrivacySection(
        title: l.t('privacy_intro_title'),
        body: l.t('privacy_intro_body'),
        highlight: true,
      ),
      _PrivacySection(
        title: l.t('privacy_collect_title'),
        body: l.t('privacy_collect_body'),
      ),
      _PrivacySection(
        title: l.t('privacy_use_title'),
        body: l.t('privacy_use_body'),
      ),
      _PrivacySection(
        title: l.t('privacy_share_title'),
        body: l.t('privacy_share_body'),
      ),
      _PrivacySection(
        title: l.t('privacy_storage_title'),
        body: l.t('privacy_storage_body'),
      ),
      _PrivacySection(
        title: l.t('privacy_rights_title'),
        body: l.t('privacy_rights_body'),
      ),
      _PrivacySection(
        title: l.t('privacy_security_title'),
        body: l.t('privacy_security_body'),
      ),
      _PrivacySection(
        title: l.t('privacy_changes_title'),
        body: l.t('privacy_changes_body'),
      ),
      _PrivacySection(
        title: l.t('privacy_contact_title'),
        body: l.t('privacy_contact_body'),
      ),
    ];

    return Scaffold(
      backgroundColor: KashfPalette.active.background,
      appBar: AppBar(
        backgroundColor: KashfPalette.active.background,
        foregroundColor: KashfPalette.active.textPrimary,
        elevation: 0,
        title: Text(l.t('privacy_title')),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 32),
          itemCount: sections.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              // "Last updated" header.
              return Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.update,
                      color: KashfPalette.active.textSecondary,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l.t('privacy_updated'),
                      style: TextStyle(
                        color: KashfPalette.active.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }
            final section = sections[index - 1];
            return Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 14),
              child: _buildSection(context, section),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, _PrivacySection section) {
    final highlight = section.highlight;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight
            ? const Color(0xFF1F1810) // subtle gold tint for the intro
            : KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight
              ? const Color(0xFFD4A33A).withValues(alpha: 0.45)
              : KashfPalette.active.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            section.title,
            style: TextStyle(
              color: highlight
                  ? const Color(0xFFD4A33A)
                  : KashfPalette.active.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            section.body,
            style: TextStyle(
              color: KashfPalette.active.textSecondary,
              fontSize: 13,
              height: 1.55,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacySection {
  const _PrivacySection({
    required this.title,
    required this.body,
    this.highlight = false,
  });
  final String title;
  final String body;
  final bool highlight;
}
