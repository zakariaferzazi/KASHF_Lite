import 'package:flutter/material.dart';

import '../../l10n/app_locale.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/locale_scope.dart';
import '../../theme.dart';

/// A small, scrollable popup modal that displays a long legal
/// document — Privacy Policy or Terms of Service. The popup is
/// accessible (it exposes a close button, supports keyboard focus,
/// and lets the user scale the text up/down for readability).
///
/// The content is built from a list of [_LegalSection]s so the
/// dialog renders correctly in both English and Arabic.
class LegalDocumentDialog extends StatefulWidget {
  const LegalDocumentDialog({
    super.key,
    required this.title,
    required this.intro,
    required this.sections,
    required this.lastUpdatedLabel,
    required this.language,
    this.maxWidth = 560,
    this.maxHeight = 540,
  });

  /// Document title (already localised, e.g. "Privacy policy").
  final String title;

  /// One-paragraph intro rendered under the title.
  final String intro;

  /// Ordered list of section heading + body pairs.
  final List<LegalSection> sections;

  /// Localised "Last updated" line rendered at the very bottom.
  final String lastUpdatedLabel;

  /// Used to resolve any future localisations inside the dialog.
  final AppLanguage language;

  /// Caps the dialog width on tablets / web so it doesn't stretch
  /// all the way to the screen edges.
  final double maxWidth;

  /// Caps the dialog height so the close button stays reachable.
  final double maxHeight;

  /// Convenience wrapper that resolves [key] against [AppStrings]
  /// and shows the dialog. Returns the dialog's `Future` so callers
  /// can `await` dismissal if needed.
  static Future<void> showPrivacy(BuildContext context) async {
    final language = LocaleScope.of(context).language;
    final l = AppLocalizations(language);
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => LegalDocumentDialog(
        title: l.t('settings_privacy_action_privacy'),
        intro: l.t('legal_privacy_intro'),
        lastUpdatedLabel: l.t('legal_last_updated'),
        language: language,
        sections: [
          LegalSection(l.t('legal_privacy_section1_title'),
              l.t('legal_privacy_section1_body')),
          LegalSection(l.t('legal_privacy_section2_title'),
              l.t('legal_privacy_section2_body')),
          LegalSection(l.t('legal_privacy_section3_title'),
              l.t('legal_privacy_section3_body')),
          LegalSection(l.t('legal_privacy_section4_title'),
              l.t('legal_privacy_section4_body')),
          LegalSection(l.t('legal_privacy_section5_title'),
              l.t('legal_privacy_section5_body')),
          LegalSection(l.t('legal_privacy_section6_title'),
              l.t('legal_privacy_section6_body')),
        ],
      ),
    );
  }

  /// Convenience wrapper that resolves [key] against [AppStrings]
  /// and shows the Terms of Service dialog.
  static Future<void> showTerms(BuildContext context) async {
    final language = LocaleScope.of(context).language;
    final l = AppLocalizations(language);
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => LegalDocumentDialog(
        title: l.t('settings_privacy_action_terms'),
        intro: l.t('legal_terms_intro'),
        lastUpdatedLabel: l.t('legal_last_updated'),
        language: language,
        sections: [
          LegalSection(l.t('legal_terms_section1_title'),
              l.t('legal_terms_section1_body')),
          LegalSection(l.t('legal_terms_section2_title'),
              l.t('legal_terms_section2_body')),
          LegalSection(l.t('legal_terms_section3_title'),
              l.t('legal_terms_section3_body')),
          LegalSection(l.t('legal_terms_section4_title'),
              l.t('legal_terms_section4_body')),
          LegalSection(l.t('legal_terms_section5_title'),
              l.t('legal_terms_section5_body')),
          LegalSection(l.t('legal_terms_section6_title'),
              l.t('legal_terms_section6_body')),
          LegalSection(l.t('legal_terms_section7_title'),
              l.t('legal_terms_section7_body')),
        ],
      ),
    );
  }

  @override
  State<LegalDocumentDialog> createState() => _LegalDocumentDialogState();
}

class _LegalDocumentDialogState extends State<LegalDocumentDialog> {
  /// User-controlled text scale. Range is 0.85x .. 1.35x (Material's
  /// recommended accessibility range). Default 1.0 keeps the
  /// original typography.
  double _scale = 1.0;

  void _bump(double delta) {
    setState(() {
      _scale = (_scale + delta).clamp(0.85, 1.35);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations(widget.language);
    final palette = KashfPalette.active;
    final scale = _scale;
    return Dialog(
      backgroundColor: palette.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: palette.cardBorder),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: widget.maxWidth,
          maxHeight: widget.maxHeight,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // -------- Header --------
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 19 * scale,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  // Text-size controls. Two compact buttons (smaller /
                  // larger) so the user can scale without leaving the
                  // modal — required by the spec for readability.
                  _ScaleButton(
                    label: 'A-',
                    onPressed: () => _bump(-0.1),
                    palette: palette,
                  ),
                  const SizedBox(width: 4),
                  _ScaleButton(
                    label: 'A+',
                    onPressed: () => _bump(0.1),
                    palette: palette,
                  ),
                  const SizedBox(width: 8),
                  _CloseButton(
                    onPressed: () => Navigator.of(context).pop(),
                    palette: palette,
                    semanticsLabel: l.t('legal_close'),
                  ),
                ],
              ),
            ),
            Divider(color: palette.divider, height: 1),
            // -------- Body --------
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.intro,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 14 * scale,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (final section in widget.sections) ...[
                      Text(
                        section.title,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 15 * scale,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        section.body,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 13.5 * scale,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Divider(color: palette.divider, height: 24),
                    Text(
                      widget.lastUpdatedLabel,
                      style: TextStyle(
                        color: palette.textSecondary.withValues(alpha: 0.7),
                        fontSize: 11.5 * scale,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // -------- Footer --------
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: palette.brightness == Brightness.dark
                        ? Colors.white
                        : const Color(0xFF0F1116),
                    backgroundColor: palette.surfaceLight,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: palette.cardBorder),
                    ),
                  ),
                  child: Text(
                    l.t('legal_close'),
                    style: TextStyle(
                      fontSize: 14 * scale,
                      fontWeight: FontWeight.w600,
                    ),
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

/// A simple `(title, body)` pair used by [LegalDocumentDialog].
class LegalSection {
  const LegalSection(this.title, this.body);
  final String title;
  final String body;
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({
    required this.onPressed,
    required this.palette,
    required this.semanticsLabel,
  });
  final VoidCallback onPressed;
  final KashfPalette palette;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      button: true,
      child: InkResponse(
        onTap: onPressed,
        radius: 22,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: palette.surfaceLight,
            shape: BoxShape.circle,
            border: Border.all(color: palette.cardBorder),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.close_rounded,
            size: 18,
            color: palette.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ScaleButton extends StatelessWidget {
  const _ScaleButton({
    required this.label,
    required this.onPressed,
    required this.palette,
  });
  final String label;
  final VoidCallback onPressed;
  final KashfPalette palette;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onPressed,
      radius: 22,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: palette.surfaceLight,
          shape: BoxShape.circle,
          border: Border.all(color: palette.cardBorder),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: palette.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: label == 'A+' ? 14 : 12,
          ),
        ),
      ),
    );
  }
}
