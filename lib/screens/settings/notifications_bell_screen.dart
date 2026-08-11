import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../services/settings_preferences.dart';
import '../../services/settings_scope.dart';
import '../../theme.dart';
import 'settings_scaffold.dart';

/// Lightweight "notifications inbox" opened from the bell icon on
/// the home shell. The MVP doesn't have a server-side inbox, so we
/// render a friendly empty state plus a "mark all read" action
/// that records a timestamp in [SettingsPreferences]. The bell
/// badge will hide until the next notification arrives.
class NotificationsBellScreen extends StatelessWidget {
  const NotificationsBellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final palette = KashfPalette.active;
    final prefs = SettingsScope.of(context);
    return SettingsScaffold(
      title: l.t('settings_bell_title'),
      actions: [
        AnimatedBuilder(
          animation: prefs,
          builder: (context, _) => TextButton(
            onPressed: () async {
              await prefs.markAllBellRead();
              if (!context.mounted) return;
              showKashfSnackBar(context, l.t('settings_bell_marked'));
            },
            child: Text(
              l.t('settings_bell_mark_all'),
              style: TextStyle(
                color: KashfColors.gold,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: palette.cardBorder),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.notifications_none_rounded,
                color: palette.textSecondary,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l.t('settings_bell_empty'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
