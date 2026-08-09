import 'package:flutter/material.dart';

import '../../theme.dart';

/// One labeled section inside an [InfoSheet].
class InfoSheetSection {
  const InfoSheetSection({
    required this.title,
    required this.body,
    this.icon,
    this.iconColor,
  });
  final String title;
  final String body;
  final IconData? icon;
  final Color? iconColor;
}

/// A reusable bottom-sheet popup used in Settings to surface static
/// reference info (Privacy policy, Security details, …) without pushing
/// a full screen.
class InfoSheet extends StatelessWidget {
  const InfoSheet({
    super.key,
    required this.title,
    required this.subtitle,
    this.updatedLabel,
    required this.sections,
  });

  final String title;
  final String subtitle;
  final String? updatedLabel;
  final List<InfoSheetSection> sections;

  /// Convenience to show the sheet.
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    String? updatedLabel,
    required List<InfoSheetSection> sections,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: KashfPalette.active.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => InfoSheet(
        title: title,
        subtitle: subtitle,
        updatedLabel: updatedLabel,
        sections: sections,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      // Make room for the keyboard if a future text-field variant is
      // added, but the current sections are read-only.
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) {
          return Column(
            children: [
              // Drag handle.
              Container(
                margin: const EdgeInsetsDirectional.only(top: 10, bottom: 6),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3A45),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title bar.
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 6, 20, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: KashfPalette.active.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: KashfPalette.active.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: KashfPalette.active.textSecondary,
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              if (updatedLabel != null)
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.update,
                        color: KashfPalette.active.textSecondary,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        updatedLabel!,
                        style: TextStyle(
                          color: KashfPalette.active.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              Divider(
                color: KashfPalette.active.divider,
                height: 1,
                indent: 20,
                endIndent: 20,
              ),
              // Sections.
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 32),
                  itemCount: sections.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsetsDirectional.only(bottom: 12),
                    child: _SectionCard(section: sections[i]),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section});
  final InfoSheetSection section;

  @override
  Widget build(BuildContext context) {
    // Cards should be visibly distinct from the sheet background. On
    // the dark / main palettes we use `surfaceLight` (slightly darker
    // than `surface`); on the light palette we use a grey so the card
    // stands out from the near-white sheet.
    final isLight = KashfPalette.active.brightness == Brightness.light;
    final cardBg = isLight
        ? const Color(0xFFE5E7EE)
        : KashfPalette.active.surfaceLight;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (section.icon != null) ...[
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: (section.iconColor ?? const Color(0xFFD4A33A))
                        .withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    section.icon,
                    size: 14,
                    color: section.iconColor ?? const Color(0xFFD4A33A),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  section.title,
                  style: TextStyle(
                    color: KashfPalette.active.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            section.body,
            style: TextStyle(
              color: KashfPalette.active.textSecondary,
              fontSize: 12,
              height: 1.55,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
