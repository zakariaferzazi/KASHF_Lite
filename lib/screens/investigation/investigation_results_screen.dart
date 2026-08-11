import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../models/investigation_result.dart';
import '../../theme.dart';
import '../../utils/text_direction_utils.dart';

/// "نتائج التحقيق" / "Investigation Results" — the destination
/// screen the [InvestigationScreen] pushes to once the service
/// finishes a run.
///
/// Layout (top → bottom):
///   1. Top bar (back · title · share/more)
///   2. Confidence hero card (overall confidence + summary)
///   3. Tab row (one chip per [InvestigationResultKind])
///   4. Section content: headline + summary + item cards
///   5. Action row (export / monitor / report / save)
class InvestigationResultsScreen extends StatefulWidget {
  const InvestigationResultsScreen({super.key, required this.result});
  final InvestigationResult result;

  @override
  State<InvestigationResultsScreen> createState() =>
      _InvestigationResultsScreenState();
}

class _InvestigationResultsScreenState
    extends State<InvestigationResultsScreen> {
  late int _activeSection;

  @override
  void initState() {
    super.initState();
    _activeSection = 0;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final section = widget.result.sections[_activeSection];

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: KashfPalette.active.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _TopBar(l: l, result: widget.result),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _HeroCard(result: widget.result, l: l),
                    const SizedBox(height: 14),
                    _TabsRow(
                      sections: widget.result.sections,
                      active: _activeSection,
                      onSelect: (i) => setState(() => _activeSection = i),
                      l: l,
                    ),
                    const SizedBox(height: 14),
                    _SectionHeader(section: section, l: l),
                    const SizedBox(height: 10),
                    for (final item in section.items) ...[
                      _ItemCard(item: item, l: l),
                      const SizedBox(height: 8),
                    ],
                    if (section.items.isEmpty)
                      _EmptyState(l: l),
                  ],
                ),
              ),
              _ActionBar(result: widget.result, l: l),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Top bar
// ============================================================================
class _TopBar extends StatelessWidget {
  const _TopBar({required this.l, required this.result});
  final AppLocalizations l;
  final InvestigationResult result;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: Icon(
              Icons.chevron_left,
              color: KashfPalette.active.textPrimary,
              size: 24,
            ),
          ),
          Expanded(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                l.t('ir_screen_title'),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: KashfPalette.active.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l.t('ir_action_share')),
                  backgroundColor: KashfColors.gold,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: Icon(
              Icons.share_outlined,
              color: KashfPalette.active.textPrimary,
              size: 20,
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.more_vert,
              color: KashfPalette.active.textPrimary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Hero card with overall confidence
// ============================================================================
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.result, required this.l});
  final InvestigationResult result;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final confidence = (result.confidence ?? 0) * 100;
    final confidenceStr = '${confidence.round()}%';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: KashfColors.gold.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: KashfColors.gold.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Big % on the left.
          SizedBox(
            width: 84,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  confidenceStr,
                  style: TextStyle(
                    color: KashfColors.gold,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    l.t('ir_hero_confidence'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: KashfPalette.active.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _ConfidenceBar(value: confidence / 100),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                autoDirection(
                  result.title,
                  Text(
                    result.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: isRtlText(result.title)
                        ? TextAlign.right
                        : TextAlign.left,
                    style: TextStyle(
                      color: KashfPalette.active.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                autoDirection(
                  result.subtitle,
                  Text(
                    result.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: isRtlText(result.subtitle)
                        ? TextAlign.right
                        : TextAlign.left,
                    style: TextStyle(
                      color: KashfPalette.active.textSecondary,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _HeroMetaRow(
                  sourcesCount: result.sources.length,
                  itemsCount: result.sections.fold<int>(
                    0,
                    (sum, s) => sum + s.items.length,
                  ),
                  l: l,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceBar extends StatelessWidget {
  const _ConfidenceBar({required this.value});
  final double value;
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: 5,
        backgroundColor: KashfPalette.active.fieldFill,
        valueColor: const AlwaysStoppedAnimation(KashfColors.gold),
      ),
    );
  }
}

class _HeroMetaRow extends StatelessWidget {
  const _HeroMetaRow({
    required this.sourcesCount,
    required this.itemsCount,
    required this.l,
  });
  final int sourcesCount;
  final int itemsCount;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        _MetaChip(
          icon: Icons.link,
          label: l.tp('ir_meta_sources', {'n': '$sourcesCount'}),
        ),
        _MetaChip(
          icon: Icons.list_alt,
          label: l.tp('ir_meta_items', {'n': '$itemsCount'}),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 8, 4),
      decoration: BoxDecoration(
        color: KashfPalette.active.fieldFill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: KashfPalette.active.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: KashfPalette.active.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Tabs row (one chip per section).
// ============================================================================
class _TabsRow extends StatelessWidget {
  const _TabsRow({
    required this.sections,
    required this.active,
    required this.onSelect,
    required this.l,
  });

  final List<InvestigationResultSection> sections;
  final int active;
  final ValueChanged<int> onSelect;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: sections.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final s = sections[i];
          final selected = i == active;
          return InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? KashfColors.gold.withValues(alpha: 0.14)
                    : KashfPalette.active.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? KashfColors.gold
                      : KashfPalette.active.cardBorder,
                  width: selected ? 1.2 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    s.kind.icon,
                    size: 14,
                    color: selected
                        ? KashfColors.gold
                        : KashfPalette.active.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l.t(s.kind.l10nKey),
                    style: TextStyle(
                      color: selected
                          ? KashfColors.gold
                          : KashfPalette.active.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// Section header (headline + summary).
// ============================================================================
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.section, required this.l});
  final InvestigationResultSection section;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        autoDirection(
          section.headline,
          Text(
            section.headline,
            textAlign: isRtlText(section.headline)
                ? TextAlign.right
                : TextAlign.left,
            style: TextStyle(
              color: KashfPalette.active.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 4),
        autoDirection(
          section.summary,
          Text(
            section.summary,
            textAlign: isRtlText(section.summary)
                ? TextAlign.right
                : TextAlign.left,
            style: TextStyle(
              color: KashfPalette.active.textSecondary,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Item card — renders one [InvestigationResultItem].
// ============================================================================
class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.l});
  final InvestigationResultItem item;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: autoDirection(
                  item.title,
                  Text(
                    item.title,
                    textAlign: isRtlText(item.title)
                        ? TextAlign.right
                        : TextAlign.left,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: KashfPalette.active.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              if (item.badge != null) ...[
                const SizedBox(width: 8),
                _Badge(label: item.badge!),
              ],
            ],
          ),
          if (item.metric != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  item.metric!,
                  style: TextStyle(
                    color: KashfColors.gold,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                if (item.metricLabel != null) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: autoDirection(
                      item.metricLabel!,
                      Text(
                        item.metricLabel!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: isRtlText(item.metricLabel!)
                            ? TextAlign.right
                            : TextAlign.left,
                        style: TextStyle(
                          color: KashfPalette.active.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 6),
          autoDirection(
            item.body,
            Text(
              item.body,
              textAlign:
                  isRtlText(item.body) ? TextAlign.right : TextAlign.left,
              style: TextStyle(
                color: KashfPalette.active.textPrimary,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: KashfColors.gold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KashfColors.gold.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: KashfColors.gold,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.inbox_outlined,
            size: 32,
            color: KashfColors.gold,
          ),
          const SizedBox(height: 8),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              l.t('ir_section_empty'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: KashfPalette.active.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Bottom action bar — 4 actions.
// ============================================================================
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.result, required this.l});
  final InvestigationResult result;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        border: Border(top: BorderSide(color: KashfPalette.active.cardBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.picture_as_pdf_outlined,
                label: l.t('ir_action_export_pdf'),
                onTap: () => _toast(context, l, 'ir_action_export_pdf'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                icon: Icons.notifications_active_outlined,
                label: l.t('ir_action_monitor'),
                onTap: () => _toast(context, l, 'ir_action_monitor_toast'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                icon: Icons.assignment_outlined,
                label: l.t('ir_action_report'),
                onTap: () => _toast(context, l, 'ir_action_report'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                icon: Icons.bookmark_border,
                label: l.t('ir_action_save'),
                onTap: () => _toast(context, l, 'ir_action_save'),
                filled: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toast(BuildContext context, AppLocalizations l, String key) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.t(key)),
        backgroundColor: KashfColors.gold,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: filled
              ? KashfColors.gold
              : KashfPalette.active.fieldFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: filled ? KashfColors.gold : KashfPalette.active.cardBorder,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: filled ? Colors.black : KashfColors.gold,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: filled ? Colors.black : KashfPalette.active.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
