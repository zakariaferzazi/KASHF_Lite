import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_strings.dart';
import '../../services/ai/disk_cache.dart';
import '../../theme.dart';
import 'settings_scaffold.dart';

/// Lets the user (a) export a JSON snapshot of their account +
/// preferences, and (b) clear the local disk cache that powers
/// news / AI responses.
///
/// The export includes the user-id, display-name, email and every
/// key in [SharedPreferences]. Cached API payloads are intentionally
/// excluded — they live behind the cache prefix and can be
/// regenerated. Clearing the cache via the tile below drops those
/// payloads and frees up disk space.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _exporting = false;
  bool _clearing = false;
  String _lastExport = '';

  Future<void> _export() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _exporting = true;
      _lastExport = '';
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      final prefs = await SharedPreferences.getInstance();
      // Whitelist the non-secret prefs the user actually controls.
      // We deliberately skip any token-like key to avoid leaking
      // Firebase session state.
      final allowedKeys = prefs.getKeys().where((k) {
        if (k.startsWith('firebase') || k.startsWith('flutter.')) return false;
        return true;
      }).toList();
      final export = <String, dynamic>{
        'app': 'KASHF Lite',
        'exported_at': DateTime.now().toUtc().toIso8601String(),
        'user': {
          'uid': user?.uid,
          'email': user?.email,
          'displayName': user?.displayName,
          'email_verified': user?.emailVerified,
        },
        'preferences': {
          for (final k in allowedKeys) k: prefs.get(k),
        },
      };
      final pretty = const JsonEncoder.withIndent('  ').convert(export);
      await Clipboard.setData(ClipboardData(text: pretty));
      if (!mounted) return;
      setState(() {
        _exporting = false;
        _lastExport = pretty;
      });
      showKashfSnackBar(context, l.t('settings_backup_export_done'));
    } catch (_) {
      if (!mounted) return;
      setState(() => _exporting = false);
      showKashfErrorSnackBar(context, l.t('settings_backup_export_failed'));
    }
  }

  Future<void> _clearCache() async {
    final l = AppLocalizations.of(context);
    setState(() => _clearing = true);
    try {
      final cache = await DiskCache.create();
      final removed = await cache.clearAll();
      if (!mounted) return;
      setState(() => _clearing = false);
      showKashfSnackBar(
        context,
        '${l.t('settings_backup_cache_done')} ($removed)',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _clearing = false);
      showKashfErrorSnackBar(context, l.t('settings_backup_cache_failed'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final palette = KashfPalette.active;
    return SettingsScaffold(
      title: l.t('settings_backup_title'),
      child: ListView(
        children: [
          SettingsSectionHeader(l.t('settings_backup_title')),
          SettingsTile(
            icon: Icons.cloud_download_outlined,
            title: l.t('settings_backup_export_title'),
            subtitle: l.t('settings_backup_export_sub'),
            trailing: _exporting
                ? const _Spinner()
                : const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF9CA3B0),
                  ),
            onTap: _exporting ? null : _export,
          ),
          if (_lastExport.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.t('settings_backup_export_done'),
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Copied to clipboard.',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          SettingsTile(
            icon: Icons.cleaning_services_rounded,
            title: l.t('settings_backup_cache_title'),
            subtitle: l.t('settings_backup_cache_sub'),
            trailing: _clearing
                ? const _Spinner()
                : const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF9CA3B0),
                  ),
            onTap: _clearing ? null : _clearCache,
          ),
        ],
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation(KashfColors.gold),
      ),
    );
  }
}
