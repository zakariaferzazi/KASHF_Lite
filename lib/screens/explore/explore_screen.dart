import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../l10n/theme_scope.dart';
import '../../models/saved_investigation.dart';
import '../../services/investigation_archive_service.dart';
import '../../services/news/news_data_controller.dart';
import '../../services/news/news_models.dart';
import '../../state/latest_investigations_controller.dart';
import '../../theme.dart';
import '../../widgets/article_reader_sheet.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/news_carousel.dart';
import '../investigation/investigation_results_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  dynamic _selectedTopic = NewsTopic.fragrances;
  int _trendingPage = 0;
  late final NewsDataController _newsController;
  late final LatestInvestigationsController _investigationsController;

  /// ISO 3166-1 alpha-2 country code used for the news feed.
  /// Maps the display name "Kuwait" → "KW". Add more entries as
  /// we support more regions.
  static const String _countryCode = 'KW';

  @override
  void initState() {
    super.initState();
    _newsController = NewsDataController();
    _newsController.addListener(_onNewsChanged);
    _investigationsController = LatestInvestigationsController();
    _investigationsController.addListener(_onInvestigationsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      // Default to Fragrances on first load so the carousel
      // immediately shows articles about the highest-priority
      // vertical for the user's region. (Always set — there's no
      // "Top" / general-news chip anymore.)
      //
      // `bootstrap` is cache-first: it renders whatever is on
      // disk/Firestore immediately and only schedules a network
      // refresh if the cached payload is older than 24 hours.
      // We deliberately do NOT call `refreshNow` here — that
      // would defeat the 24-hour gate and re-trigger the
      // expensive Google News pipeline every time the user
      // opens the Explore tab.
      await _newsController.bootstrap(
        language: l.language.code,
        country: _countryCode,
        topic: _selectedTopic,
      );
    });
  }

  void _onNewsChanged() {
    if (mounted) setState(() {});
  }

  void _onInvestigationsChanged() {
    if (mounted) setState(() {});
  }

  /// Maps the Firestore-backed [LatestInvestigationsController]
  /// snapshot into the visual row model used by
  /// [_RecentInvestigationsList]. Caps the list at 4 entries
  /// so the section stays compact. When the controller is still
  /// loading and we have no data, we fall back to a small skeleton
  /// surface — the `EmptyState` variant of the row.
  List<_RecentInvestigationItem> _buildRecentItems(AppLocalizations l) {
    final items = _investigationsController.items;
    if (items.isEmpty &&
        _investigationsController.isLoading) {
      return const <_RecentInvestigationItem>[];
    }
    return items
        .take(4)
        .map((saved) => _RecentInvestigationItem.fromInvestigation(
              saved: saved,
              l: l,
            ))
        .toList();
  }

  /// Loads the full report for the tapped investigation and pushes
  /// the detail screen. Same pattern as the home / latest
  /// investigations screens.
  Future<void> _openSavedReport(SavedInvestigation item) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final result = await InvestigationArchiveService.instance
          .loadResult(item.id);
      if (!mounted) return;
      if (result == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'This saved report cannot be opened — only its '
              'summary is available. Re-run the investigation '
              'to refresh.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => InvestigationResultsScreen(result: result),
        ),
      );
    } catch (e, st) {
      debugPrint('[ExploreScreen] openSavedReport failed: $e\n$st');
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open this report.')),
      );
    }
  }

  @override
  void dispose() {
    _newsController.removeListener(_onNewsChanged);
    _newsController.dispose();
    _investigationsController.removeListener(_onInvestigationsChanged);
    _investigationsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Subscribe to theme changes so the IndexedStack container in
    // [HomeShell] actually rebuilds us when the user picks a
    // different palette.
    ThemeScope.of(context);
    return Directionality(
      textDirection: l.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: KashfPalette.active.background,
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 12, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: _TopBar(
                    l: l,
                    isRefreshing: _newsController.isLoading,
                    onRefresh: () {
                      _newsController.refreshNow(
                        language: l.language.code,
                        country: _countryCode,
                        topic: _selectedTopic,
                      );
                    },
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 6, 20, 14),
                sliver: SliverToBoxAdapter(
                  child: CategoryChipsRow(
                    selected: _selectedTopic,
                    onChanged: (t) {
                      setState(() => _selectedTopic = t);
                      _newsController.setTopic(t);
                    },
                    l: l,
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 16, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: TrendingSectionHeader(
                    title: l.isRtl
                        ? _selectedTopic.labelAr
                        : _selectedTopic.label,
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: TrendingCarousel(
                    newsState: _newsController.state,
                    onPageChanged: (i) => setState(() => _trendingPage = i),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 4, 20, 16),
                sliver: SliverToBoxAdapter(
                  child: DotsIndicator(
                    count: _newsController.state.articles.length,
                    index: _trendingPage,
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 16, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: _DiscoverSectionHeader(
                    title: l.t('explore_discover_title'),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: _DiscoverGridStatic(
                    l: l,
                    onTapTopic: (t) {
                      _TopicArticlesSheet.show(
                        context,
                        topic: t,
                        languageCode: l.language.code,
                        countryCode: _countryCode,
                      );
                    },
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 16, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: _RecentSectionHeader(
                    title: l.t('explore_recent_title'),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(12, 0, 12, 32),
                sliver: SliverToBoxAdapter(
                  child: _RecentInvestigationsList(
                    items: _buildRecentItems(l),
                    onTapItem: _openSavedReport,
                  ),
                ),
              ),
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
  const _TopBar({
    required this.l,
    required this.isRefreshing,
    required this.onRefresh,
  });
  final AppLocalizations l;
  final bool isRefreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              l.t('nav_explore'),
              style: TextStyle(
                color: KashfPalette.active.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
              textDirection: TextDirection.ltr,
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: _RefreshIcon(
              isLoading: isRefreshing,
              onTap: isRefreshing ? null : onRefresh,
            ),
          ),
        ],
      ),
    );
  }
}

class _RefreshIcon extends StatelessWidget {
  const _RefreshIcon({
    required this.isLoading,
    required this.onTap,
  });
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
          border: Border.all(color: KashfColors.gold.withValues(alpha: 0.55)),
        ),
        alignment: Alignment.center,
        child: isLoading
            ? const InlineSpinner(size: 18)
            : Icon(
                Icons.refresh_rounded,
                color: KashfColors.gold,
                size: 20,
              ),
      ),
    );
  }
}

// ============================================================================
// Discover-by-medium 2×2 grid
// ============================================================================

class _DiscoverSectionHeader extends StatelessWidget {
  const _DiscoverSectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    // Subscribe to theme changes so this const widget actually
    // re-runs build() when the user flips the palette.
    ThemeScope.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                color: KashfColors.gold,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: KashfPalette.active.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DiscoverGridStatic extends StatelessWidget {
  const _DiscoverGridStatic({
    required this.l,
    required this.onTapTopic,
  });
  final AppLocalizations l;
  final ValueChanged<NewsTopic> onTapTopic;

  /// Mirrors the topic chips in [_CategoryChipsRow] so the grid
  /// acts as a second entry point into the same feeds. Limited
  /// to the 4 curated topics (Fashion / Beauty / Influencers /
  /// Fragrances) shared with the Home screen.
  static const List<NewsTopic> _topics = <NewsTopic>[
    NewsTopic.fashion,
    NewsTopic.beauty,
    NewsTopic.influencers,
    NewsTopic.fragrances,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _DiscoverTile(
                topic: _topics[0],
                onTap: () => onTapTopic(_topics[0]),
                l: l,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _DiscoverTile(
                topic: _topics[1],
                onTap: () => onTapTopic(_topics[1]),
                l: l,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _DiscoverTile(
                topic: _topics[2],
                onTap: () => onTapTopic(_topics[2]),
                l: l,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _DiscoverTile(
                topic: _topics[3],
                onTap: () => onTapTopic(_topics[3]),
                l: l,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DiscoverTile extends StatelessWidget {
  const _DiscoverTile({
    required this.topic,
    required this.onTap,
    required this.l,
  });
  final NewsTopic topic;
  final VoidCallback onTap;
  final AppLocalizations l;

  IconData _iconFor(NewsTopic t) {
    switch (t) {
      case NewsTopic.fashion:
        return Icons.checkroom_outlined;
      case NewsTopic.beauty:
        return Icons.face_retouching_natural_outlined;
      case NewsTopic.influencers:
        return Icons.person_outline;
      case NewsTopic.fragrances:
        return Icons.local_florist_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe to theme changes so this const widget actually
    // re-runs build() when the user flips the palette.
    ThemeScope.of(context);
    final palette = KashfPalette.active;
    final title = l.isRtl ? topic.labelAr : topic.label;
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 88,
          padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 10, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.cardBorder, width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            textDirection: TextDirection.ltr,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: palette.surfaceLight,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(_iconFor(topic), color: KashfColors.gold, size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  textDirection: TextDirection.ltr,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.t('explore_news_tap_hint'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 10,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 2),
                child: Icon(
                  Icons.chevron_left,
                  color: palette.textSecondary,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Topic articles sheet (used by the Discover grid)
// ============================================================================

/// Bottom sheet shown when the user taps a Discover tile. Fetches
/// the same per-topic Google News RSS feed that powers the
/// trending carousel and renders the resolved articles in a
/// vertical list. Each row mirrors the carousel card style so
/// tapping it opens [ArticleReaderSheet] in a WebView.
class _TopicArticlesSheet extends StatefulWidget {
  const _TopicArticlesSheet({
    required this.topic,
    required this.languageCode,
    required this.countryCode,
  });

  final NewsTopic topic;
  final String languageCode;
  final String countryCode;

  static Future<void> show(
    BuildContext context, {
    required NewsTopic topic,
    required String languageCode,
    required String countryCode,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      useSafeArea: true,
      builder: (_) => _TopicArticlesSheet(
        topic: topic,
        languageCode: languageCode,
        countryCode: countryCode,
      ),
    );
  }

  @override
  State<_TopicArticlesSheet> createState() => _TopicArticlesSheetState();
}

class _TopicArticlesSheetState extends State<_TopicArticlesSheet> {
  late final NewsDataController _controller;
  NewsState? _state;

  @override
  void initState() {
    super.initState();
    _controller = NewsDataController();
    _controller.addListener(_onChanged);
    // `bootstrap` is cache-first: it renders whatever is on
    // disk/Firestore immediately and only schedules a network
    // refresh if the cached payload is older than 24 hours.
    // Calling `refreshNow` here used to re-trigger the Google
    // News pipeline on every topic-bottom-sheet open, which was
    // the biggest single source of background CPU usage.
    _controller.bootstrap(
      language: widget.languageCode,
      country: widget.countryCode,
      topic: widget.topic,
    );
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() => _state = _controller.state);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final title = l.isRtl ? widget.topic.labelAr : widget.topic.label;
    final state = _state ?? NewsState.initial;
    final screenH = MediaQuery.of(context).size.height;
    final sheetH = screenH * 0.86;

    return SizedBox(
      height: sheetH,
      child: Material(
        color: const Color(0xFF0E0F14),
        elevation: 12,
        shadowColor: Colors.black.withValues(alpha: 0.6),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Directionality(
          textDirection: l.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: Column(
            children: [
              _buildHandle(),
              _buildHeader(title),
              Expanded(child: _buildBody(l, state)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.center,
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2D38),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 12, 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF1A1D24), width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF9AA0A6),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded,
                color: Color(0xFFD4A33A), size: 22),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations l, NewsState state) {
    if (state.status == NewsStatus.loading && state.articles.isEmpty) {
      return Center(
        child: LoadingOverlay(
          visible: true,
          message: l.isRtl ? 'جاري التحديث…' : 'Refreshing feed…',
          child: const SizedBox(
            width: 220,
            height: 120,
          ),
        ),
      );
    }
    if (state.articles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            state.status == NewsStatus.error
                ? l.t('explore_news_error')
                : l.t('explore_news_empty'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF9AA0A6),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 24),
      itemCount: state.articles.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _TopicArticleRow(article: state.articles[i]),
    );
  }
}

class _TopicArticleRow extends StatelessWidget {
  const _TopicArticleRow({required this.article});
  final NewsArticle article;

  @override
  Widget build(BuildContext context) {
    // Subscribe to theme changes so this const widget re-runs
    // build() when the user flips the palette.
    ThemeScope.of(context);
    final palette = KashfPalette.active;
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => ArticleReaderSheet.show(context, article),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.cardBorder, width: 1),
          ),
          padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 10, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            textDirection: TextDirection.ltr,
            children: [
              _buildThumb(palette),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      article.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      article.source.isNotEmpty
                          ? article.source
                          : article.publishedAt,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_left,
                color: palette.textSecondary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumb(KashfPalette palette) {
    final placeholder = Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(color: palette.surfaceLight),
      alignment: Alignment.center,
      child: Icon(
        Icons.image_outlined,
        size: 22,
        color: palette.textSecondary,
      ),
    );
    if (article.imageUrl.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 64,
        height: 64,
        child: Image.network(
          article.imageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return Container(
              color: palette.surfaceLight,
              alignment: Alignment.center,
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  valueColor: AlwaysStoppedAnimation(KashfColors.gold),
                ),
              ),
            );
          },
          errorBuilder: (_, _, _) => placeholder,
        ),
      ),
    );
  }
}

// ============================================================================
// Recent investigations
// ============================================================================

class _RecentSectionHeader extends StatelessWidget {
  const _RecentSectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    // Subscribe to theme changes so this const widget re-runs
    // build() when the user flips the palette.
    ThemeScope.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.history_outlined,
                color: KashfColors.gold,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: KashfPalette.active.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _StatusStyle { completed, quickAnswer, analyzing, paused }

class _StatusPalette {
  const _StatusPalette({
    required this.bg,
    required this.fg,
    required this.icon,
  });
  final Color bg;
  final Color fg;
  final IconData icon;
}

class _RecentInvestigationItem {
  const _RecentInvestigationItem({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.statusLabel,
    required this.statusStyle,
    required this.saved,
  });

  /// Builds a row model from a Firestore-saved investigation.
  /// Field mappings:
  ///   * title   → SavedInvestigation.title
  ///   * subtitle → SavedInvestigation.subtitle (short blurb)
  ///   * time    → "x ago" relative timestamp
  ///   * status  → confidence-band-driven label + style
  factory _RecentInvestigationItem.fromInvestigation({
    required SavedInvestigation saved,
    required AppLocalizations l,
  }) {
    return _RecentInvestigationItem(
      title: saved.title,
      subtitle: saved.subtitle,
      time: _sinceLabel(saved.createdAt, l),
      statusLabel: _statusLabelFor(saved, l),
      statusStyle: _statusStyleFor(saved),
      saved: saved,
    );
  }

  final String title;
  final String subtitle;
  final String time;
  final String statusLabel;
  final _StatusStyle statusStyle;

  /// Backing Firestore record — supplied to the tap handler so
  /// the row can re-open the saved investigation report.
  final SavedInvestigation saved;

  static _StatusStyle _statusStyleFor(SavedInvestigation saved) {
    // Status column only differentiates "complete vs anything
    // else" because every saved record in the archive is in
    // fact completed — failed runs aren't persisted. Map high
    // confidence → "complete" styling, medium / low → the
    // analyzing / paused palettes so the visual still hints at
    // the confidence band.
    switch (saved.confidenceBand) {
      case 'high':
        return _StatusStyle.completed;
      case 'low':
        return _StatusStyle.paused;
      default:
        return _StatusStyle.analyzing;
    }
  }

  static String _statusLabelFor(SavedInvestigation saved, AppLocalizations l) {
    switch (saved.confidenceBand) {
      case 'high':
        return l.t('explore_recent_complete');
      case 'low':
        return l.t('home_latest_band_low');
      default:
        return l.t('home_latest_band_medium');
    }
  }

  static String _sinceLabel(DateTime then, AppLocalizations l) {
    final diff = DateTime.now().difference(then);
    if (diff.inMinutes < 1) return l.t('home_latest_since_just_now');
    if (diff.inMinutes < 60) {
      return l
          .t('home_latest_since_minutes')
          .replaceAll('%{n}', diff.inMinutes.toString());
    }
    if (diff.inHours < 24) {
      return l
          .t('home_latest_since_hours')
          .replaceAll('%{n}', diff.inHours.toString());
    }
    return l
        .t('home_latest_since_days')
        .replaceAll('%{n}', diff.inDays.toString());
  }
}

class _RecentInvestigationsList extends StatelessWidget {
  const _RecentInvestigationsList({
    required this.items,
    required this.onTapItem,
  });
  final List<_RecentInvestigationItem> items;

  /// Tap handler invoked when the user taps one of the rows.
  /// Provided by the screen so this widget stays stateless.
  final void Function(SavedInvestigation item) onTapItem;

  @override
  Widget build(BuildContext context) {
    // Subscribe to theme changes so this const widget re-runs
    // build() when the user flips the palette.
    ThemeScope.of(context);
    final palette = KashfPalette.active;
    if (items.isEmpty) {
      // Empty state mirrors the list's outer chrome so the
      // section header doesn't collapse into thin air. Friendly
      // copy nudges the user to run their first investigation.
      final l = AppLocalizations.of(context);
      return Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.cardBorder, width: 1),
        ),
        padding: const EdgeInsetsDirectional.fromSTEB(16, 18, 16, 18),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.search,
                color: KashfColors.gold,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l.t('explore_recent_empty'),
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.cardBorder, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _RecentInvestigationRow(
              item: items[i],
              onTap: () => onTapItem(items[i].saved),
            ),
            if (i != items.length - 1)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 12, end: 12),
                child: Divider(
                  color: palette.divider,
                  height: 1,
                  thickness: 1,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _RecentInvestigationRow extends StatelessWidget {
  const _RecentInvestigationRow({required this.item, required this.onTap});
  final _RecentInvestigationItem item;

  /// Tap handler. When non-null the whole row becomes a tappable
  /// area that opens the saved report (mirrors the home screen
  /// / latest investigations screens).
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Subscribe to theme changes so this const widget re-runs
    // build() when the user flips the palette.
    ThemeScope.of(context);
    final appPalette = KashfPalette.active;
    final palette = _paletteFor(item.statusStyle);

    final row = Directionality(
      textDirection: TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 64,
              child: Text(
                item.time,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: appPalette.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 10),
            _StatusPill(label: item.statusLabel, palette: palette),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: appPalette.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: appPalette.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _buildThumbnail(appPalette),
            const SizedBox(width: 10),
            Icon(
              Icons.more_vert,
              color: appPalette.textSecondary,
              size: 18,
            ),
          ],
        ),
      ),
    );

    return InkWell(
      onTap: onTap,
      child: row,
    );
  }

  /// Thumbnail — every saved investigation uses the bundled
  /// `report.jpg` asset so the row visually anchors on a
  /// consistent image regardless of which subject the run
  /// covered (matches the home + latest investigations screens).
  Widget _buildThumbnail(KashfPalette appPalette) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 48,
        height: 48,
        color: appPalette.surfaceLight,
        alignment: Alignment.center,
        child: Image.asset(
          'assets/images/report.jpg',
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Icon(
            Icons.branding_watermark_outlined,
            size: 22,
            color: appPalette.textSecondary,
          ),
        ),
      ),
    );
  }

  static _StatusPalette _paletteFor(_StatusStyle s) {
    switch (s) {
      case _StatusStyle.completed:
        return const _StatusPalette(
          bg: Color(0xFF103C26),
          fg: Color(0xFF3DDC84),
          icon: Icons.check,
        );
      case _StatusStyle.quickAnswer:
        return const _StatusPalette(
          bg: Color(0xFF112B45),
          fg: Color(0xFF4DA3FF),
          icon: Icons.bolt_outlined,
        );
      case _StatusStyle.analyzing:
        return const _StatusPalette(
          bg: Color(0xFF241F12),
          fg: Color(0xFFFBBF24),
          icon: Icons.analytics_outlined,
        );
      case _StatusStyle.paused:
        return const _StatusPalette(
          bg: Color(0xFF241318),
          fg: Color(0xFFEF4444),
          icon: Icons.pause,
        );
    }
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.palette});
  final String label;
  final _StatusPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(7, 4, 7, 4),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(palette.icon, size: 11, color: palette.fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: palette.fg,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// NewsTopic icon/label mapping for the chip row
// ============================================================================
