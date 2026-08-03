import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../models/analysis_history.dart';
import '../../state/history_store.dart';
import '../../theme.dart';

/// Reports tab — shows the history of analyses the user ran on the Explore
/// screen, so they can revisit past investigations without re-running them.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  void initState() {
    super.initState();
    // Re-render when the shared history list changes (e.g. user saves a new
    // analysis from the Explore screen while the Reports tab is mounted).
    HistoryStore.instance.entries.addListener(_onHistoryChanged);
  }

  @override
  void dispose() {
    HistoryStore.instance.entries.removeListener(_onHistoryChanged);
    super.dispose();
  }

  void _onHistoryChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final entries = HistoryStore.instance.entries.value;
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
                padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 12),
                sliver: SliverToBoxAdapter(child: _HistoryHint(l: l)),
              ),
              if (entries.isEmpty)
                SliverPadding(
                  padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 24),
                  sliver: SliverToBoxAdapter(child: _EmptyHistory(l: l)),
                )
              else
                SliverPadding(
                  padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 32),
                  sliver: SliverList.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => SizedBox(height: 10),
                    itemBuilder: (context, i) =>
                        _HistoryCard(entry: entries[i]),
                  ),
                ),
            ],
          ),
        ),
      ),
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
        'assets/images/logoprofile.jpg',
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

class _HistoryHint extends StatelessWidget {
  const _HistoryHint({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final isEmpty = HistoryStore.instance.entries.value.isEmpty;
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: KashfColors.gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KashfColors.gold.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(Icons.history, color: KashfColors.gold, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              isEmpty
                  ? (l.isRtl
                      ? 'لم تحفظ أي تحليل بعد. شغّل تحليلًا في صفحة الاستكشاف ثم اضغط «حفظ في المساحة».'
                      : 'No saved analyses yet. Run an analysis on the Explore screen, then tap "Save to workspace".')
                  : (l.isRtl
                      ? 'هذه نتائج كشوفاتك السابقة. اضغط على أي عنصر لإعادة فتح نتائجه.'
                      : 'Your past analyses. Tap any entry to revisit its results.'),
              style: TextStyle(
                color: KashfPalette.active.textPrimary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.l});
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
            Icons.history_toggle_off,
            color: KashfPalette.active.textSecondary,
            size: 36,
          ),
          SizedBox(height: 8),
          Text(
            l.isRtl ? 'لا توجد كشوفات محفوظة' : 'No saved analyses',
            style: TextStyle(
              color: KashfPalette.active.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            l.isRtl
                ? 'احفظ نتائج أي تحليل من صفحة الاستكشاف لتظهر هنا.'
                : 'Save any analysis from the Explore screen to see it here.',
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

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry});
  final AnalysisHistoryEntry entry;

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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: KashfColors.gold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.auto_awesome,
                    color: KashfColors.gold, size: 18),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.entity.isEmpty
                          ? (l.isRtl ? 'بدون اسم' : 'Untitled')
                          : entry.entity,
                      style: TextStyle(
                        color: KashfPalette.active.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2),
                    Text(
                      entry.summary,
                      style: TextStyle(
                        color: KashfPalette.active.textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_left,
                color: KashfPalette.active.textSecondary,
                size: 22,
              ),
            ],
          ),
          if (entry.categoryLabels.isNotEmpty) ...[
            SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final label in entry.categoryLabels)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: KashfColors.gold.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: KashfColors.gold,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.schedule,
                color: KashfPalette.active.textSecondary,
                size: 14,
              ),
              SizedBox(width: 4),
              Text(
                entry.displayDate(l),
                style: TextStyle(
                  color: KashfPalette.active.textSecondary,
                  fontSize: 11,
                ),
              ),
              SizedBox(width: 12),
              Icon(
                Icons.layers_outlined,
                color: KashfPalette.active.textSecondary,
                size: 14,
              ),
              SizedBox(width: 4),
              Text(
                l.isRtl
                    ? '${entry.outputsCount} نتائج كشف'
                    : '${entry.outputsCount} insights',
                style: TextStyle(
                  color: KashfPalette.active.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}