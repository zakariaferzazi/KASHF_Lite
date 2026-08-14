import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import 'settings_scaffold.dart';

/// Hub for security-related actions: change password and delete
/// the account permanently.
class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SettingsScaffold(
      title: l.t('settings_security_title'),
      child: ListView(
        children: [
          SettingsSectionHeader(l.t('settings_security_title')),
          SettingsTile(
            icon: Icons.lock_outline_rounded,
            title: l.t('settings_security_password_title'),
            subtitle: l.t('settings_security_password_sub'),
            trailing: const _Chevron(),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
            ),
          ),
          const SizedBox(height: 24),
          SettingsSectionHeader(l.t('settings_security_danger_title')),
          SettingsTile(
            icon: Icons.delete_forever_rounded,
            title: l.t('settings_security_danger_title'),
            subtitle: l.t('settings_security_danger_sub'),
            trailing: const _Chevron(color: Color(0xFFEF4444)),
            onTap: () => _confirmDelete(context),
            danger: true,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final palette = KashfPalette.active;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: palette.cardBorder),
        ),
        title: Text(
          l.t('settings_security_delete_title'),
          style: TextStyle(color: palette.textPrimary),
        ),
        content: Text(
          l.t('settings_security_delete_body'),
          style: TextStyle(color: palette.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              l.t('legal_close'),
              style: TextStyle(color: palette.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
            ),
            child: Text(
              l.t('settings_security_delete_confirm'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    final password = await _askPassword(context);
    if (password == null) return;
    if (!context.mounted) return;
    try {
      await AuthService().deleteAccount(
        reauthPassword: password,
        language: l.language,
      );
      if (!context.mounted) return;
      showKashfSnackBar(context, l.t('settings_profile_saved'));
      // Auth gate will auto-route the user back to the welcome screen.
    } on AuthException catch (e) {
      if (!context.mounted) return;
      showKashfErrorSnackBar(context, e.message);
    } catch (_) {
      if (!context.mounted) return;
      showKashfErrorSnackBar(context, l.t('settings_security_delete_failed'));
    }
  }

  Future<String?> _askPassword(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final palette = KashfPalette.active;
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: palette.cardBorder),
        ),
        title: Text(
          l.t('settings_security_reauth_required'),
          style: TextStyle(color: palette.textPrimary),
        ),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          style: TextStyle(color: palette.textPrimary),
          decoration: InputDecoration(
            hintText: l.t('settings_security_current_pw'),
            hintStyle: TextStyle(color: palette.textSecondary),
            filled: true,
            fillColor: palette.fieldFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: palette.fieldBorder),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text(
              l.t('legal_close'),
              style: TextStyle(color: palette.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text(
              l.t('settings_security_delete_confirm'),
              style: const TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    return result;
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron({this.color});
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final palette = KashfPalette.active;
    return Icon(
      Icons.chevron_right_rounded,
      color: color ?? palette.textSecondary,
    );
  }
}

/// Lets the user rotate their password. The current password is
/// re-entered to satisfy Firebase's recent-login requirement.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    if (_current.text.isEmpty) {
      showKashfErrorSnackBar(context, l.t('settings_security_reauth_required'));
      return;
    }
    if (_next.text.length < 6) {
      showKashfErrorSnackBar(context, l.t('settings_security_pw_too_short'));
      return;
    }
    if (_next.text != _confirm.text) {
      showKashfErrorSnackBar(context, l.t('settings_security_pw_mismatch'));
      return;
    }
    setState(() => _saving = true);
    try {
      await AuthService().changePassword(
        currentPassword: _current.text,
        newPassword: _next.text,
        reauthPassword: _current.text,
        language: l.language,
      );
      if (!mounted) return;
      showKashfSnackBar(context, l.t('settings_security_pw_updated'));
      Navigator.of(context).pop();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showKashfErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showKashfErrorSnackBar(context, l.t('settings_security_pw_failed'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final palette = KashfPalette.active;
    return SettingsScaffold(
      title: l.t('settings_security_change_pw_title'),
      child: ListView(
        children: [
          _Field(
            label: l.t('settings_security_current_pw'),
            controller: _current,
            palette: palette,
          ),
          const SizedBox(height: 12),
          _Field(
            label: l.t('settings_security_new_pw'),
            controller: _next,
            palette: palette,
          ),
          const SizedBox(height: 12),
          _Field(
            label: l.t('settings_security_confirm_pw'),
            controller: _confirm,
            palette: palette,
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
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
                      l.t('settings_security_submit'),
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

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.palette,
  });
  final String label;
  final TextEditingController controller;
  final KashfPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
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
            controller: controller,
            obscureText: true,
            style: TextStyle(color: palette.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// (Active sessions list removed: Firebase's client SDK doesn't
/// support per-device management, so we keep the screen out of
/// the Settings hub entirely.)
