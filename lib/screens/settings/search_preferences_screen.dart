import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../services/settings_preferences.dart';
import '../../services/settings_scope.dart';
import '../../theme.dart';
import 'settings_scaffold.dart';

/// Default filters applied when the user opens the search / home
/// screens. Settings are persisted via [SettingsPreferences] so the
/// app honours them across launches.
class SearchPreferencesScreen extends StatefulWidget {
  const SearchPreferencesScreen({super.key});

  @override
  State<SearchPreferencesScreen> createState() =>
      _SearchPreferencesScreenState();
}

class _SearchPreferencesScreenState extends State<SearchPreferencesScreen> {
  late String _entity;
  late String _region;
  late bool _safe;

  @override
  void initState() {
    super.initState();
    final prefs = SettingsScope.of(context);
    _entity = prefs.defaultEntity;
    _region = prefs.defaultRegion;
    _safe = prefs.safeSearch;
  }

  Future<void> _save() async {
    final prefs = SettingsScope.of(context);
    final l = AppLocalizations.of(context);
    await prefs.setDefaultEntity(_entity);
    await prefs.setDefaultRegion(_region);
    await prefs.setSafeSearch(_safe);
    if (!mounted) return;
    showKashfSnackBar(context, l.t('settings_search_saved'));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final palette = KashfPalette.active;
    return SettingsScaffold(
      title: l.t('settings_search_title'),
      child: ListView(
        children: [
          SettingsSectionHeader(l.t('settings_search_title')),
          _DropdownTile(
            icon: Icons.category_outlined,
            title: l.t('settings_search_default_entity'),
            value: _entity,
            options: const [
              DropdownMenuItem(value: 'company', child: Text('Companies')),
              DropdownMenuItem(value: 'person', child: Text('People')),
              DropdownMenuItem(value: 'product', child: Text('Products')),
            ],
            onChanged: (v) => setState(() => _entity = v ?? _entity),
            palette: palette,
          ),
          const SizedBox(height: 10),
          _DropdownTile(
            icon: Icons.public_outlined,
            title: l.t('settings_search_default_region'),
            value: _region,
            options: [
              DropdownMenuItem(
                value: 'global',
                child: Text(l.t('settings_region_global')),
              ),
              DropdownMenuItem(
                value: 'gulf',
                child: Text(l.t('settings_region_gulf')),
              ),
              DropdownMenuItem(
                value: 'europe',
                child: Text(l.t('settings_region_europe')),
              ),
              DropdownMenuItem(
                value: 'na',
                child: Text(l.t('settings_region_na')),
              ),
            ],
            onChanged: (v) => setState(() => _region = v ?? _region),
            palette: palette,
          ),
          const SizedBox(height: 10),
          Container(
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
                  child: Icon(
                    Icons.shield_outlined,
                    size: 20,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.t('settings_search_safe'),
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l.t('settings_search_safe_sub'),
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
                  value: _safe,
                  onChanged: (v) => setState(() => _safe = v),
                  activeThumbColor: KashfColors.gold,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: KashfColors.gold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                l.t('settings_profile_save'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownTile extends StatelessWidget {
  const _DropdownTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.palette,
  });
  final IconData icon;
  final String title;
  final String value;
  final List<DropdownMenuItem<String>> options;
  final ValueChanged<String?> onChanged;
  final KashfPalette palette;

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
            child: Text(
              title,
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14.5,
              ),
            ),
          ),
          DropdownButton<String>(
            value: value,
            items: options,
            onChanged: onChanged,
            underline: const SizedBox.shrink(),
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: palette.textSecondary,
            ),
            dropdownColor: palette.surface,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
