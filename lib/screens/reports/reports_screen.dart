import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../models/mock_data.dart';
import '../../models/report.dart';
import '../../theme.dart';

/// Generates and manages AI reports and analyses.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportStatus? _filter; // null = all

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final all = MockData.reports(context);
    final visible = _filter == null
        ? all
        : all.where((r) => r.status == _filter).toList();

    // Use the natural direction for the active language.
    return Directionality(
      textDirection: l.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: KashfPalette.active.background,
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 16, 20, 8),
                sliver: SliverToBoxAdapter(child: _Header(l: l)),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 8, 20, 16),
                sliver: SliverToBoxAdapter(
                  child: _FilterBar(
                    current: _filter,
                    onChange: (s) => setState(() => _filter = s),
                  ),
                ),
              ),
              if (visible.isEmpty)
                SliverPadding(
                  padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 24),
                  sliver: SliverToBoxAdapter(child: _EmptyReports(l: l)),
                )
              else
                SliverPadding(
                  padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 32),
                  sliver: SliverList.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, i) => Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: _ReportCard(report: visible[i]),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGenerateSheet(BuildContext context) {
    final l = AppLocalizations.of(context);
    final actions = [
      ReportType.executiveSummary,
      ReportType.marketInsight,
      ReportType.competitive,
      ReportType.swot,
      ReportType.contentIdeas,
      ReportType.reelScript,
      ReportType.podcastScript,
      ReportType.monitoring,
      ReportType.recommendation,
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: KashfPalette.active.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.t('reports_action_generate'),
                  style: TextStyle(
                    color: KashfPalette.active.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 12),
                for (final a in actions)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.auto_awesome, color: KashfColors.gold),
                    title: Text(
                      l.t(a.l10nKey),
                      style: TextStyle(
                        color: KashfPalette.active.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l.t('settings_coming_soon')),
                          backgroundColor: KashfColors.gold,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final logo = KashfLogo(width: 56);
    final avatar = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: KashfColors.gold.withValues(alpha: 0.18),
        border: Border.all(color: KashfColors.gold, width: 1.4),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: Image.asset(
        'assets/images/logoprofile.jpeg',
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            Icon(Icons.person, color: KashfColors.gold, size: 22),
      ),
    );
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.t('reports_title'),
          style: TextStyle(
            color: KashfPalette.active.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 2),
        Text(
          l.t('reports_subtitle'),
          style: TextStyle(
            color: KashfPalette.active.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
    // Logo always on the opposite side, like the home top bar.
    return Padding(
      padding: EdgeInsetsDirectional.only(bottom: 8),
      child: Row(
        children: l.isRtl
            ? [
                logo,
                SizedBox(width: 10),
                Expanded(child: titleBlock),
                SizedBox(width: 8),
                avatar,
              ]
            : [
                avatar,
                SizedBox(width: 10),
                Expanded(child: titleBlock),
                SizedBox(width: 8),
                logo,
              ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.current, required this.onChange});
  final ReportStatus? current;
  final ValueChanged<ReportStatus?> onChange;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final items = <_FilterItem>[
      _FilterItem(null, l.t('reports_filter_all')),
      _FilterItem(ReportStatus.recent, l.t('reports_filter_recent')),
      _FilterItem(ReportStatus.archived, l.t('reports_filter_archived')),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in items) ...[
            _FilterPill(
              label: item.label,
              selected: current == item.value,
              onTap: () => onChange(item.value),
            ),
            SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FilterItem {
  const _FilterItem(this.value, this.label);
  final ReportStatus? value;
  final String label;
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? KashfColors.gold.withValues(alpha: 0.18)
              : KashfPalette.active.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? KashfColors.gold : KashfPalette.active.cardBorder,
            width: selected ? 1.2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? KashfColors.gold
                : KashfPalette.active.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});
  final Report report;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: KashfColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.description_outlined,
                  color: KashfColors.gold,
                  size: 18,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.title,
                      style: TextStyle(
                        color: KashfPalette.active.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2),
                    Text(
                      l.t(report.type.l10nKey),
                      style: TextStyle(
                        color: KashfPalette.active.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                color: KashfPalette.active.surface,
                icon: Icon(
                  Icons.more_horiz,
                  color: KashfPalette.active.textSecondary,
                ),
                onSelected: (v) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l.t('settings_coming_soon')),
                      backgroundColor: KashfColors.gold,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'export',
                    child: Text(l.t('reports_export_pdf')),
                  ),
                  PopupMenuItem(
                    value: 'share',
                    child: Text(l.t('reports_share')),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            report.preview,
            style: TextStyle(
              color: KashfPalette.active.textSecondary,
              fontSize: 12,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.source_outlined,
                color: KashfPalette.active.textSecondary,
                size: 14,
              ),
              SizedBox(width: 4),
              Text(
                '${report.sourceCount}',
                style: TextStyle(
                  color: KashfPalette.active.textSecondary,
                  fontSize: 11,
                ),
              ),
              SizedBox(width: 12),
              Icon(
                Icons.schedule,
                color: KashfPalette.active.textSecondary,
                size: 14,
              ),
              SizedBox(width: 4),
              Text(
                _formatDate(context, report.createdAt),
                style: TextStyle(
                  color: KashfPalette.active.textSecondary,
                  fontSize: 11,
                ),
              ),
              Spacer(),
              if (report.status == ReportStatus.archived)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFFFB923C).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l.t('reports_filter_archived'),
                    style: TextStyle(
                      color: Color(0xFFFB923C),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(BuildContext context, DateTime dt) {
    final diff = DateTime.now().difference(dt);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return isAr ? 'قبل $m د' : '${m}m ago';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return isAr ? 'قبل $h س' : '${h}h ago';
    }
    final d = diff.inDays;
    return isAr ? 'قبل $d ي' : '${d}d ago';
  }
}

class _EmptyReports extends StatelessWidget {
  const _EmptyReports({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Column(
        children: [
          Icon(
            Icons.assessment_outlined,
            color: KashfPalette.active.textSecondary,
            size: 36,
          ),
          SizedBox(height: 8),
          Text(
            l.t('reports_empty'),
            style: TextStyle(
              color: KashfPalette.active.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            l.t('reports_empty_hint'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: KashfPalette.active.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
