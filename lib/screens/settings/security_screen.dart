import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import 'settings_scaffold.dart';

/// Hub for security-related actions: change password, sign out
/// all other devices (handled by Firebase's refresh-token rotation
/// after a password change), and delete the account permanently.
///
/// The "Active sessions" screen lists this device and any other
/// devices recorded in `User.metadata`. Firebase's client SDK does
/// not expose per-device revocation; rotating the password (or
/// deleting the account) is the supported way to invalidate
/// sessions, which we explain inline.
class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final palette = KashfPalette.active;
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
          const SizedBox(height: 10),
          SettingsTile(
            icon: Icons.devices_other_rounded,
            title: l.t('settings_security_sessions_title'),
            subtitle: l.t('settings_security_sessions_sub'),
            trailing: const _Chevron(),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ActiveSessionsScreen(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SettingsTile(
            icon: Icons.security_rounded,
            title: l.t('settings_security_2fa_title'),
            subtitle: l.t('settings_security_2fa_sub'),
            trailing: Switch(
              value: false,
              onChanged: (v) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      v
                          ? 'Two-step verification is not yet available.'
                          : 'Two-step verification is not yet available.',
                      style: TextStyle(color: palette.textPrimary),
                    ),
                    backgroundColor: palette.surface,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              activeThumbColor: KashfColors.gold,
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

/// Lists signed-in devices. Firebase's client SDK doesn't expose a
/// per-device list, so we render this device with whatever metadata
/// the SDK exposes, plus a hint that rotating the password (or
/// deleting the account) is the supported way to sign out other
/// devices.
class ActiveSessionsScreen extends StatelessWidget {
  const ActiveSessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final palette = KashfPalette.active;
    final user = AuthService().currentUser;
    final metadata = user?.metadata;
    return SettingsScaffold(
      title: l.t('settings_security_sessions_title_screen'),
      child: ListView(
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
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: palette.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: palette.cardBorder),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.smartphone_rounded,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.t('settings_security_sessions_this'),
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        metadata?.lastSignInTime != null
                            ? 'Last sign-in ${metadata!.lastSignInTime!.toLocal()}'
                                .replaceAll('.000', '')
                            : '—',
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
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.cardBorder),
            ),
            child: Text(
              l.t('settings_security_sessions_empty'),
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ChangePasswordScreen(),
                ),
              );
            },
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: Text(l.t('settings_security_sessions_sign_out_all')),
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.textPrimary,
              side: BorderSide(color: palette.cardBorder),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
