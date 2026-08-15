import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import 'settings_scaffold.dart';

/// Lets the user edit their display name (and shows their email +
/// verification status). Calls [AuthService.updateDisplayName] on
/// save. The save button is disabled until the field is dirty.
class PersonalProfileScreen extends StatefulWidget {
  const PersonalProfileScreen({super.key});

  @override
  State<PersonalProfileScreen> createState() =>
      _PersonalProfileScreenState();
}

class _PersonalProfileScreenState extends State<PersonalProfileScreen> {
  late final TextEditingController _nameController;
  String _initialName = '';
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final user = AuthService().currentUser;
    _initialName = user?.displayName ?? '';
    _nameController = TextEditingController(text: _initialName);
    _nameController.addListener(_onChanged);
  }

  void _onChanged() {
    final newDirty = _nameController.text.trim() != _initialName.trim();
    if (newDirty != _dirty) {
      setState(() => _dirty = newDirty);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      final l = AppLocalizations.of(context);
      showKashfErrorSnackBar(context, l.t('settings_profile_name_required'));
      return;
    }
    setState(() => _saving = true);
    final l = AppLocalizations.of(context);
    try {
      await AuthService().updateDisplayName(
        displayName: newName,
        language: l.language,
      );
      if (!mounted) return;
      setState(() {
        _initialName = newName;
        _dirty = false;
        _saving = false;
      });
      showKashfSnackBar(context, l.t('settings_profile_saved'));
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showKashfErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showKashfErrorSnackBar(context, l.t('settings_profile_save_failed'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final palette = KashfPalette.active;
    final user = AuthService().currentUser;
    return SettingsScaffold(
      title: l.t('settings_profile_title'),
      child: ListView(
        children: [
          // Avatar + email header card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.cardBorder),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: palette.surfaceLight,
                  child: Text(
                    _initialName.isNotEmpty
                        ? _initialName.characters.first.toUpperCase()
                        : (user?.email?.characters.first.toUpperCase() ?? '?'),
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.email ?? '—',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            user?.emailVerified == true
                                ? Icons.verified_rounded
                                : Icons.error_outline_rounded,
                            size: 14,
                            color: user?.emailVerified == true
                                ? const Color(0xFF22C55E)
                                : const Color(0xFFEF4444),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            user?.emailVerified == true
                                ? l.t('settings_profile_email_verified')
                                : l.t('settings_profile_email_unverified'),
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SettingsSectionHeader(l.t('settings_profile_title')),
          Text(
            l.t('settings_profile_name_label'),
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: palette.fieldFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.fieldBorder),
            ),
            child: TextField(
              controller: _nameController,
              style: TextStyle(color: palette.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: l.t('settings_profile_name_label'),
                hintStyle: TextStyle(color: palette.textSecondary),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _dirty && !_saving ? _save : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: KashfColors.gold,
                foregroundColor: Colors.black,
                disabledBackgroundColor:
                    KashfColors.gold.withValues(alpha: 0.4),
                disabledForegroundColor: Colors.black54,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation(Colors.black),
                      ),
                    )
                  : Text(
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

// `AuthException` lives in `auth_service.dart`. The
// `currentUser` getter is the source of truth used here so we don't
// need to import `firebase_auth` at the call site.
