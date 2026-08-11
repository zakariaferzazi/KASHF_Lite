import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../services/settings_preferences.dart';
import '../../services/settings_scope.dart';
import '../../theme.dart';
import 'settings_scaffold.dart';

/// Per-channel notification toggles. State is persisted through
/// [SettingsPreferences] so changes survive an app restart.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _saving = false;

  Future<void> _save({
    required bool Function() read,
    required Future<void> Function(bool) write,
    required bool next,
  }) async {
    setState(() => _saving = true);
    await write(next);
    if (!mounted) return;
    setState(() => _saving = false);
    final l = AppLocalizations.of(context);
    showKashfSnackBar(context, l.t('settings_notifications_saved'));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final palette = KashfPalette.active;
    final prefs = SettingsScope.of(context);
    return SettingsScaffold(
      title: l.t('settings_notifications_title'),
      child: AnimatedBuilder(
        animation: prefs,
        builder: (context, _) => ListView(
          children: [
            SettingsSectionHeader(l.t('settings_notifications_title')),
            _NotifTile(
              title: l.t('settings_notifications_push'),
              subtitle: l.t('settings_notifications_push_sub'),
              value: prefs.notificationsPush,
              onChanged: _saving
                  ? null
                  : (v) => _save(
                        read: () => prefs.notificationsPush,
                        write: prefs.setNotificationsPush,
                        next: v,
                      ),
              palette: palette,
              icon: Icons.notifications_active_outlined,
            ),
            const SizedBox(height: 10),
            _NotifTile(
              title: l.t('settings_notifications_email'),
              subtitle: l.t('settings_notifications_email_sub'),
              value: prefs.notificationsEmail,
              onChanged: _saving
                  ? null
                  : (v) => _save(
                        read: () => prefs.notificationsEmail,
                        write: prefs.setNotificationsEmail,
                        next: v,
                      ),
              palette: palette,
              icon: Icons.email_outlined,
            ),
            const SizedBox(height: 10),
            _NotifTile(
              title: l.t('settings_notifications_investigation'),
              subtitle: l.t('settings_notifications_investigation_sub'),
              value: prefs.notificationsInvestigation,
              onChanged: _saving
                  ? null
                  : (v) => _save(
                        read: () => prefs.notificationsInvestigation,
                        write: prefs.setNotificationsInvestigation,
                        next: v,
                      ),
              palette: palette,
              icon: Icons.search_rounded,
            ),
            const SizedBox(height: 10),
            _NotifTile(
              title: l.t('settings_notifications_monitor'),
              subtitle: l.t('settings_notifications_monitor_sub'),
              value: prefs.notificationsMonitor,
              onChanged: _saving
                  ? null
                  : (v) => _save(
                        read: () => prefs.notificationsMonitor,
                        write: prefs.setNotificationsMonitor,
                        next: v,
                      ),
              palette: palette,
              icon: Icons.visibility_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  const _NotifTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.palette,
    required this.icon,
  });
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final KashfPalette palette;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: palette.surfaceLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.cardBorder),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: palette.textPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: KashfColors.gold,
          ),
        ],
      ),
    );
  }
}
