import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../models/entity_type.dart';
import '../../models/investigation.dart';
import '../../models/saved_investigation.dart';
import '../../state/latest_investigations_controller.dart';
import '../../theme.dart';
import '../settings/settings_scaffold.dart';

/// "Select a report" picker used by the admin-only Content Studio
/// flows (Reel script + Podcast script).
///
/// Lists the admin's saved investigations, newest first, sourced
/// directly from Firestore via [LatestInvestigationsController].
/// Tapping a row returns the chosen [SavedInvestigation] via
/// `Navigator.pop(...)` so the caller (system overview screen) can
/// load the full report and push the script viewer.
///
/// Authorization is the responsibility of the caller — this screen
/// is purely a picker and does NOT re-check admin status. We
/// double-check at the call site so the route can never be reached
/// from a non-admin context even via deep links.
class AdminReportPickerScreen extends StatefulWidget {
  const AdminReportPickerScreen({
    super.key,
    required this.title,
    this.subtitleKey,
  });

  /// Title shown in the app bar — already-localised by the caller.
  final String title;

  /// Optional l10n key for the empty-state subtitle. When the
  /// caller wants a custom message ("Choose a report to turn into
  /// a reel"), pass its l10n key here.
  final String? subtitleKey;

  @override
  State<AdminReportPickerScreen> createState() =>
      _AdminReportPickerScreenState();
}

class _AdminReportPickerScreenState extends State<AdminReportPickerScreen> {
  late final LatestInvestigationsController _controller;
  // Local mirror of the controller's data, sorted and filtered.
  // The picker is small enough that re-sorting on every build is
  // cheaper than maintaining a parallel filtered stream.
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller = LatestInvestigationsController(limit: 60);
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  /// Filtered + sorted view of the controller's items.
  List<SavedInvestigation> _filteredItems() {
    final query = _query.trim().toLowerCase();
    final list = _controller.items
        .where((it) => it.status == InvestigationStatus.completed)
        .where((it) => it.reportJson != null)
        .where((it) {
      if (query.isEmpty) return true;
      return it.title.toLowerCase().contains(query) ||
          it.subtitle.toLowerCase().contains(query) ||
          it.tags.any((t) => t.toLowerCase().contains(query));
    }).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final items = _filteredItems();

    return SettingsScaffold(
      title: widget.title,
      padding: EdgeInsets.zero,
      actions: [
        IconButton(
          tooltip: l.t('li_more_refresh'),
          icon: const Icon(Icons.refresh),
          onPressed: () async {
            await _controller.refresh();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l.t('li_more_refreshed'))),
            );
          },
        ),
      ],
      child: Column(
        children: [
          _buildHeader(l),
          Expanded(child: _buildBody(l, items)),
        ],
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.subtitleKey != null) ...[
            Text(
              l.t(widget.subtitleKey!),
              style: TextStyle(
                color: KashfPalette.active.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Container(
            decoration: BoxDecoration(
              color: KashfPalette.active.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: KashfPalette.active.cardBorder),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: TextStyle(
                color: KashfPalette.active.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: l.t('li_search_hint'),
                hintStyle: TextStyle(
                  color: KashfPalette.active.textSecondary,
                  fontSize: 13,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: KashfPalette.active.textSecondary,
                  size: 18,
                ),
                filled: true,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations l, List<SavedInvestigation> items) {
    if (_controller.isLoading && items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: KashfColors.gold),
      );
    }
    if (_controller.error != null && items.isEmpty) {
      return _EmptyState(
        icon: Icons.error_outline,
        title: l.t('adm_picker_error_title'),
        subtitle: l.t('adm_picker_error_sub'),
        actionLabel: l.t('li_more_refresh'),
        onAction: () => _controller.refresh(),
      );
    }
    if (items.isEmpty) {
      return _EmptyState(
        icon: Icons.search_off,
        title: l.t('adm_picker_empty_title'),
        subtitle: l.t('adm_picker_empty_sub'),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _ReportRow(
        item: items[i],
        onTap: () => Navigator.of(context).pop(items[i]),
      ),
    );
  }
}

/// Single row in the report picker — title + subtitle, an entity
/// chip, a confidence pill, and a trailing chevron.
class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.item, required this.onTap});

  final SavedInvestigation item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = KashfPalette.active;
    final bandColor = switch (item.confidenceBand) {
      'high' => const Color(0xFF22C55E),
      'medium' => const Color(0xFFF59E0B),
      _ => const Color(0xFFEF4444),
    };

    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.cardBorder),
          ),
          child: Row(
            children: [
              // Thumbnail (or icon fallback).
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 48,
                  height: 48,
                  color: palette.surfaceLight,
                  alignment: Alignment.center,
                  child: item.thumbnailUrl != null &&
                          item.thumbnailUrl!.isNotEmpty
                      ? Image.network(
                          item.thumbnailUrl!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Icon(
                            _iconFor(item.entityType),
                            color: KashfColors.gold,
                            size: 22,
                          ),
                        )
                      : Icon(
                          _iconFor(item.entityType),
                          color: KashfColors.gold,
                          size: 22,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Title / subtitle / entity chip.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title.isEmpty ? '—' : item.title,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 11.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _Pill(
                          text: _entityLabel(item.entityType),
                          color: KashfColors.gold,
                        ),
                        const SizedBox(width: 6),
                        _Pill(
                          text: '${item.confidencePercent}%',
                          color: bandColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: palette.textSecondary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(EntityType type) {
    switch (type) {
      case EntityType.company:
        return Icons.business_rounded;
      case EntityType.brand:
        return Icons.bookmark_rounded;
      case EntityType.product:
        return Icons.shopping_bag_outlined;
      case EntityType.influencer:
        return Icons.person_rounded;
      case EntityType.market:
        return Icons.bar_chart_rounded;
    }
  }

  String _entityLabel(EntityType type) {
    switch (type) {
      case EntityType.company:
        return 'Company';
      case EntityType.brand:
        return 'Brand';
      case EntityType.product:
        return 'Product';
      case EntityType.influencer:
        return 'Influencer';
      case EntityType.market:
        return 'Market';
    }
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = KashfPalette.active;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: palette.textSecondary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: KashfColors.gold,
                  side: const BorderSide(color: KashfColors.gold),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

