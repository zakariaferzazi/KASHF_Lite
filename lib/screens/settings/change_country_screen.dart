import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../services/settings_scope.dart';
import '../../theme.dart';
import '../../widgets/country_picker.dart';
import 'settings_scaffold.dart';

/// Lets the user change the country their KASHF Lite account is
/// associated with. The chosen dial code is persisted via
/// [SettingsPreferences.setUserCountry], which also promotes it to
/// the default search region used by AI-driven investigations and
/// the home/market/monitoring feeds.
class ChangeCountryScreen extends StatefulWidget {
  const ChangeCountryScreen({super.key});

  @override
  State<ChangeCountryScreen> createState() => _ChangeCountryScreenState();
}

class _ChangeCountryScreenState extends State<ChangeCountryScreen> {
  /// Tracks a pending save so the picker is disabled while the
  /// preference is being written to disk.
  bool _saving = false;

  Future<void> _pickAndSave() async {
    if (_saving) return;
    final prefs = SettingsScope.of(context);
    final l = AppLocalizations.of(context);
    final picked = await showCountryPicker(
      context,
      currentDialCode: prefs.userCountry,
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      await prefs.setUserCountry(picked.dial);
      if (!mounted) return;
      showKashfSnackBar(context, l.t('settings_change_country_done'));
    } catch (_) {
      if (!mounted) return;
      showKashfErrorSnackBar(
        context,
        l.t('settings_change_country_done'),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final prefs = SettingsScope.of(context);
    final palette = KashfPalette.active;
    final isRtl = l.isRtl;
    final currentDial = prefs.userCountry;
    final currentInfo = currentDial == null
        ? null
        : countryByDial(currentDial);
    final currentName = currentInfo == null
        ? (currentDial ?? '—')
        : (isRtl ? currentInfo.arabicName : currentInfo.name);
    return SettingsScaffold(
      title: l.t('settings_change_country_title'),
      child: AnimatedBuilder(
        animation: prefs,
        builder: (context, _) => ListView(
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
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: palette.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: palette.cardBorder),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.public_rounded,
                      color: KashfColors.gold,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentName,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currentDial ?? '—',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _pickAndSave,
                icon: _saving
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                            KashfColors.gold,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: Colors.black,
                      ),
                label: Text(
                  l.t('settings_change_country_title'),
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: KashfColors.gold,
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
      ),
    );
  }
}