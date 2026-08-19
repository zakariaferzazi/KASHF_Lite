import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/app_strings.dart';
import '../../l10n/user_profile_scope.dart';
import '../../theme.dart';

/// Editable personal info screen. Reached from the
/// "Personal profile" tile in Settings.
///
/// Lets the user:
///   * Change their display name (free text)
///   * View the email used to sign in (read-only)
///   * Replace the avatar image (camera / gallery) or pick a color
///     that shows their first initial
class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _nameCtrl = TextEditingController();
  final _picker = ImagePicker();
  bool _initialized = false;

  /// Palette the user can pick from when they choose "Pick a color".
  static const _colorPalette = <int>[
    0xFFD4A33A, // brand gold
    0xFF22C55E, // green
    0xFF3B82F6, // blue
    0xFF8B5CF6, // purple
    0xFFEF4444, // red
    0xFFF59E0B, // amber
    0xFFEC4899, // pink
    0xFF14B8A6, // teal
    0xFF6B7280, // gray
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final p = UserProfileScope.of(context).profile;
    _nameCtrl.text = p.name;
    _initialized = true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFromCamera() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
      );
      if (file == null) return;
      if (!mounted) return;
      await UserProfileScope.of(context).setAvatarImage(file.path);
    } catch (e) {
      if (!mounted) return;
      _showError(_formatPickerError(e));
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
      );
      if (file == null) return;
      if (!mounted) return;
      await UserProfileScope.of(context).setAvatarImage(file.path);
    } catch (e) {
      if (!mounted) return;
      _showError(_formatPickerError(e));
    }
  }

  /// Translate common image_picker failures into friendlier messages
  /// (the raw PlatformException leaks the channel name and confuses
  /// users — e.g. when the native plugin hasn't been registered yet).
  String _formatPickerError(Object e) {
    final raw = e.toString();
    final l = AppLocalizations.of(context);
    if (raw.contains('channel-error') ||
        raw.contains('MissingPluginException') ||
        raw.contains('Unable to establish connection')) {
      // The native side of the plugin isn't available — usually because
      // the app needs a full rebuild after adding image_picker.
      return l.t('profile_avatar_picker_unavailable');
    }
    if (raw.contains('camera_access_denied') ||
        raw.contains('CameraAccessDenied') ||
        raw.contains('photo_access_denied')) {
      return l.t('profile_avatar_picker_permission');
    }
    return raw;
  }

  Future<void> _pickColor() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: KashfPalette.active.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        final l = AppLocalizations.of(sheetCtx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.t('profile_avatar_color_label'),
                  style: TextStyle(
                    color: KashfPalette.active.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final color in _colorPalette)
                      GestureDetector(
                        onTap: () => Navigator.pop(sheetCtx, color),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(color),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null) return;
    if (!mounted) return;
    await UserProfileScope.of(context).setAvatarColor(selected);
  }

  Future<void> _showAvatarSheet() async {
    final l = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: KashfPalette.active.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.photo_camera_outlined,
                  color: Color(0xFFD4A33A),
                ),
                title: Text(
                  l.t('profile_avatar_take_photo'),
                  style: TextStyle(color: KashfPalette.active.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _pickFromCamera();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: Color(0xFFD4A33A),
                ),
                title: Text(
                  l.t('profile_avatar_choose_gallery'),
                  style: TextStyle(color: KashfPalette.active.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _pickFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.palette_outlined,
                  color: Color(0xFFD4A33A),
                ),
                title: Text(
                  l.t('profile_avatar_pick_color'),
                  style: TextStyle(color: KashfPalette.active.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _pickColor();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.restart_alt,
                  color: KashfPalette.active.textSecondary,
                ),
                title: Text(
                  l.t('profile_avatar_reset'),
                  style: TextStyle(color: KashfPalette.active.textSecondary),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  UserProfileScope.of(context).resetAvatar();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    await UserProfileScope.of(context).setName(_nameCtrl.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.t('profile_saved')),
        backgroundColor: const Color(0xFF22C55E),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).pop();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ctrl = UserProfileScope.of(context);

    return Scaffold(
      backgroundColor: KashfPalette.active.background,
      appBar: AppBar(
        backgroundColor: KashfPalette.active.background,
        foregroundColor: KashfPalette.active.textPrimary,
        elevation: 0,
        centerTitle: true,
        title: Text(l.t('profile_edit_title')),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 32),
          children: [
            // Avatar block.
            Center(
              child: GestureDetector(
                onTap: _showAvatarSheet,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    UserAvatar(
                      profile: ctrl.profile,
                      size: 96,
                      borderColor: const Color(0xFFD4A33A),
                      borderWidth: 2,
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4A33A),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: KashfPalette.active.background,
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.camera_alt_outlined,
                        color: Colors.black,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                l.t('profile_avatar_subtitle'),
                style: TextStyle(
                  color: KashfPalette.active.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Name field.
            _buildFieldLabel(l.t('profile_name_label')),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _nameCtrl,
              hint: l.t('profile_name_hint'),
            ),
            const SizedBox(height: 16),
            // Email field (read-only).
            _buildFieldLabel(l.t('profile_email_label')),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: KashfPalette.active.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: KashfPalette.active.cardBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      ctrl.profile.email.isEmpty ? '—' : ctrl.profile.email,
                      style: TextStyle(
                        color: KashfPalette.active.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.lock_outline,
                    color: KashfPalette.active.textSecondary,
                    size: 16,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l.t('profile_email_readonly'),
              style: TextStyle(
                color: KashfPalette.active.textSecondary,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 24),
            // Save button.
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4A33A),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: Text(l.t('profile_save')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        color: KashfPalette.active.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(color: KashfPalette.active.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: KashfPalette.active.textSecondary,
          fontSize: 14,
        ),
        filled: true,
        fillColor: KashfPalette.active.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: KashfPalette.active.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: KashfPalette.active.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD4A33A), width: 1.4),
        ),
      ),
    );
  }
}
