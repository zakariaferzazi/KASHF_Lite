import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_strings.dart';
import '../../theme.dart';
import 'contact_support_screen.dart';
import 'legal_document_dialog.dart';
import 'settings_scaffold.dart';

/// "About" screen showing the app version, the company that built
/// it, and deep-links to the website, contact email, privacy
/// policy and terms of service.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '—';
  String _build = '—';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _version = info.version;
        _build = info.buildNumber;
      });
    } catch (_) {
      // Package info unavailable (e.g. running in a unit test) — the
      // fallback `—` is fine.
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final palette = KashfPalette.active;
    return SettingsScaffold(
      title: l.t('settings_about_title'),
      child: ListView(
        children: [
          // Brand card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.cardBorder),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: palette.surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: palette.cardBorder),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'K',
                    style: TextStyle(
                      color: KashfColors.gold,
                      fontWeight: FontWeight.w800,
                      fontSize: 32,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l.t('app_title'),
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l.t('settings_about_company_value'),
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Row(
            label: l.t('settings_about_version_label'),
            value: _version,
            palette: palette,
          ),
          _Row(
            label: l.t('settings_about_build_label'),
            value: _build,
            palette: palette,
          ),
          _Row(
            label: l.t('settings_about_company_label'),
            value: l.t('settings_about_company_value'),
            palette: palette,
          ),
          const SizedBox(height: 16),
          SettingsTile(
            icon: Icons.language_rounded,
            title: l.t('settings_about_website'),
            subtitle: 'kashf-lite.app',
            trailing: const _Chevron(),
            onTap: () => _openUrl('https://kashf-lite.app'),
          ),
          const SizedBox(height: 10),
          SettingsTile(
            icon: Icons.mail_outline_rounded,
            title: l.t('settings_about_contact'),
            subtitle: ContactSupportScreen.supportEmail,
            trailing: const _Chevron(),
            onTap: () async {
              final uri = Uri(
                scheme: 'mailto',
                path: ContactSupportScreen.supportEmail,
              );
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
          ),
          const SizedBox(height: 10),
          SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: l.t('settings_about_privacy'),
            trailing: const _Chevron(),
            onTap: () =>
                LegalDocumentDialog.showPrivacy(context),
          ),
          const SizedBox(height: 10),
          SettingsTile(
            icon: Icons.gavel_rounded,
            title: l.t('settings_about_terms'),
            trailing: const _Chevron(),
            onTap: () => LegalDocumentDialog.showTerms(context),
          ),
          const SizedBox(height: 10),
          SettingsTile(
            icon: Icons.code_rounded,
            title: l.t('settings_about_open_source'),
            subtitle: l.t('settings_about_open_source_action'),
            trailing: const _Chevron(),
            onTap: () => showLicensePage(
              context: context,
              applicationName: l.t('app_title'),
              applicationVersion: _version,
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    required this.palette,
  });
  final String label;
  final String value;
  final KashfPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(
          bottom: BorderSide(color: palette.cardBorder, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron();
  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.chevron_right_rounded,
      color: KashfPalette.active.textSecondary,
    );
  }
}
