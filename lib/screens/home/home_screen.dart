import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../l10n/theme_scope.dart';
import '../../models/saved_investigation.dart';
import '../../models/today_case.dart';
import '../../services/ai/ai_models.dart';
import '../../services/ai/ai_text_utils.dart';
import '../../services/ai/featured_brand_controller.dart';
import '../../services/ai/home_data_controller.dart';
import '../../services/home_tab_notifier.dart';
import '../../services/investigation_archive_service.dart';
import '../../services/news/news_data_controller.dart';
import '../../services/news/news_models.dart';
import '../../services/today_case_service.dart';
import '../../state/latest_investigations_controller.dart';
import '../../theme.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/news_carousel.dart';
import '../files/latest_investigations_screen.dart';
import '../investigation/investigation_results_screen.dart';
import '../market/market_screen.dart';
import '../shell/home_shell.dart';
import 'today_case_screen.dart';

/// KASHF Lite dashboard. The entry point after sign-in. Layout mirrors
/// the marketing reference: greeting + user avatar, featured investigation
/// card, weekly market pulse, 6 quick actions in a 2-column grid, and
/// recent updates carousel.
///
/// As of the OpenRouter integration, the Market Pulse and Quick Actions
/// sections are populated from the [AiHomeService] (driven by
/// [HomeDataController]). When the API is unreachable the controller
/// falls back to per-language demo data so the UI never goes blank.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeDataController _controller;
  late final NewsDataController _newsController;
  late final FeaturedBrandController _featuredBrand;
  late final LatestInvestigationsController _latestInvestigations;
  dynamic _selectedTopic = NewsTopic.fashion;
  int _trendingPage = 0;

  /// Random case picked from `assets/Data/today_case.json` on
  /// bootstrap / refresh. The same instance is forwarded to
  /// [TodayCaseScreen] when the user taps the featured card so
  /// the detail page mirrors the home card.
  TodayCase? _todayCase;

  /// ISO 3166-1 alpha-2 country code used for the home news feed.
  static const String _countryCode = 'KW';

  @override
  void initState() {
    super.initState();
    _controller = HomeDataController();
    _controller.addListener(_onStateChanged);
    _newsController = NewsDataController();
    _newsController.addListener(_onNewsChanged);
    _featuredBrand = FeaturedBrandController();
    _featuredBrand.addListener(_onStateChanged);
    _latestInvestigations = LatestInvestigationsController();
    _latestInvestigations.addListener(_onStateChanged);
    // Bootstrap the initial fetch on the next frame so we can read
    // the AppLocalizations (locale) from the context without a
    // race against the widget tree.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      _controller.bootstrap(
        language: l.language.code,
        region: 'Kuwait',
      );
      // Restore the previously featured brand from disk so the
      // user sees the same brand after a restart.
      await _featuredBrand.bootstrap();
      // Pick the initial random case from the bundled JSON so the
      // featured card shows real data on first paint.
      await _loadTodayCase();
      // Default to Fashion so the home carousel surfaces what's
      // trending in the highest-priority vertical on first load.
      //
      // `bootstrap` is cache-first: it renders whatever is on
      // disk/Firestore immediately and only schedules a network
      // refresh if the cached payload is older than 24 hours.
      // We deliberately do NOT call `refreshNow` here â€” that
      // would defeat the 24-hour gate and re-trigger the
      // expensive Google News pipeline every time the user
      // opens the home tab.
      await _newsController.bootstrap(
        language: l.language.code,
        country: _countryCode,
        topic: _selectedTopic,
      );
    });
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  void _onNewsChanged() {
    if (mounted) setState(() {});
  }

  /// Tap handler for a Latest Investigations card on the home
  /// screen. Looks up the full report from the archive (Firestore
  /// or the local mirror) and pushes the detail screen.
  ///
  /// The fetch is local-only (the document is already in memory
  /// or in SharedPreferences cache) so we don't show an overlay â€”
  /// a single SnackBar surfaces the rare case where the
  /// embedded report is missing.
  Future<void> _openSavedReport(
    SavedInvestigation item,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final result = await InvestigationArchiveService.instance
          .loadResult(item.id);
      if (!mounted) return;
      if (result == null) {
        // The saved record exists but the embedded report is
        // missing or unreadable â€” most likely the document was
        // written before the new schema shipped. Tell the user
        // rather than silently opening an empty detail screen.
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'This saved report cannot be opened â€” only its '
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
      debugPrint('[HomeScreen] openSavedReport failed: $e\n$st');
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open this report.')),
      );
    }
  }

  /// Single entry-point for the user-facing "refresh everything"
  /// action (app-bar icon + pull-to-refresh). Refreshes the AI
  /// payloads AND rotates the featured brand so the brand name
  /// + logo on the featured card change in lock-step with the
  /// rest of the page.
  Future<void> _onRefreshAll({required String language}) async {
    await Future.wait(<Future<void>>[
      _controller.refreshNow(language: language),
      _featuredBrand.refresh(),
      _latestInvestigations.refresh(),
    ]);
    // Re-roll today's case so the user sees a different company
    // each refresh (skipping the current pick to avoid repeats).
    await _loadTodayCase(excludeLogourl: _todayCase?.logourl);
  }

  /// Picks a random [TodayCase] from the bundled JSON pool and
  /// stores it in [_todayCase]. Called on bootstrap and on every
  /// full refresh so the featured card always shows fresh data.
  ///
  /// Failures are swallowed: a missing/broken JSON asset should
  /// never break the home screen.
  Future<void> _loadTodayCase({String? excludeLogourl}) async {
    try {
      debugPrint('[HomeScreen] _loadTodayCase: loading…');
      final picked = await TodayCaseService.instance
          .pickRandom(excludeLogourl: excludeLogourl);
      debugPrint('[HomeScreen] _loadTodayCase: picked=${picked?.logourl} '
          'name=${picked?.name}');
      if (!mounted || picked == null) {
        debugPrint('[HomeScreen] _loadTodayCase: skipped ('
            'mounted=$mounted, picked=$picked)');
        return;
      }
      setState(() => _todayCase = picked);
    } catch (e, st) {
      // Surface errors via debugPrint so they show up in BOTH
      // debug AND release builds (assert is stripped in release).
      debugPrint('[HomeScreen] _loadTodayCase failed: $e\n$st');
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onStateChanged);
    _controller.dispose();
    _newsController.removeListener(_onNewsChanged);
    _newsController.dispose();
    _featuredBrand.removeListener(_onStateChanged);
    _featuredBrand.dispose();
    _latestInvestigations.removeListener(_onStateChanged);
    _latestInvestigations.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Subscribe to the active theme so every rebuild picks up the
    // freshly-selected palette. Without this dependency the
    // IndexedStack in [HomeShell] keeps reusing our const widget
    // and the screen never refreshes when the user changes theme.
    ThemeScope.of(context);
    // The centered brand spinner overlays the whole page on every
    // refresh — both the very first cold load AND any tap on the
    // app-bar refresh / pull-to-refresh afterwards. The backdrop
    // fades in, blocking taps so the user can't trigger a second
    // refresh while one is in flight.
    final showFullOverlay = _controller.isLoading;
    // Use the natural direction for the active language so Arabic flows
    // right-to-left and English flows left-to-right natively.
    return Directionality(
      textDirection: l.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: KashfPalette.active.background,
        body: LoadingOverlay(
          visible: showFullOverlay,
          blocking: true,
          message: l.t('home_ai_loading'),
          child: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: () => _onRefreshAll(language: l.language.code),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                SliverPadding(
                  padding: EdgeInsetsDirectional.fromSTEB(16, 4, 16, 4),
                  sliver: SliverToBoxAdapter(
                    child: _TopBar(
                      isRefreshing: _controller.isLoading,
                      onRefresh: () => _onRefreshAll(
                        language: l.language.code,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 4),
                  sliver: SliverToBoxAdapter(child: _Greeting(l: l)),
                ),
                SliverPadding(
                  padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: _FeaturedInvestigation(
                      l: l,
                      brandController: _featuredBrand,
                      todayCase: _todayCase,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 4),
                  sliver: SliverToBoxAdapter(
                    child: _SectionHeader(
                      title: l.t('home_market_pulse'),
                      trailing: l.t('home_view_all'),
                      onTrailingTap: () => Navigator.of(
                        context,
                      ).push(kashfRoute(const MarketScreen())),
                      trailingLoading: _controller.isLoading,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsetsDirectional.fromSTEB(16, 4, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: _MarketPulseList(
                      l: l,
                      data: _controller.state.marketPulse,
                      isLoading: _controller.isLoading,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsetsDirectional.fromSTEB(16, 4, 16, 10),
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
                  padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: TrendingSectionHeader(
                      title: l.isRtl
                          ? _selectedTopic.labelAr
                          : _selectedTopic.label,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: TrendingCarousel(
                      newsState: _newsController.state,
                      onPageChanged: (i) =>
                          setState(() => _trendingPage = i),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsetsDirectional.fromSTEB(16, 4, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: DotsIndicator(
                      count: _newsController.state.articles.length,
                      index: _trendingPage,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 4),
                  sliver: SliverToBoxAdapter(
                    child: _SectionHeader(
                      title: l.t('home_recent_activity'),
                      trailing: l.t('home_view_all'),
                      onTrailingTap: () => Navigator.of(
                        context,
                      ).push(kashfRoute(const LatestInvestigationsScreen())),
                      trailingLoading: _controller.isLoading,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsetsDirectional.fromSTEB(16, 4, 16, 16),
                  sliver: SliverToBoxAdapter(
                    child: _RecentUpdatesList(
                      l: l,
                      investigations: _latestInvestigations.items,
                      onOpenReport: _openSavedReport,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}

// ============================ Top Bar ============================
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.isRefreshing,
    required this.onRefresh,
  });

  /// True while a manual refresh is in flight. Drives the spinner
  /// inside the refresh button.
  final bool isRefreshing;

  /// User-tap callback. The parent (HomeScreen) wires this to
  /// `HomeDataController.refreshNow` so the app bar is the
  /// single point of entry for "go fetch AI data".
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    // Subscribe to theme changes so this const widget re-runs
    // build() when the user flips the palette.
    ThemeScope.of(context);
    // The logo image already contains the brand name, so we just render it
    // as-is. Width is sized to match the action controls (bell + avatar).
    final logoMark = Image.asset(
      'assets/images/logo_appbar.png',
      height: 30,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
      errorBuilder: (_, _, _) => KashfLogo(width: 90),
    );

    final bell = _NotificationBell();
    final refreshButton = _RefreshIconButton(
      isLoading: isRefreshing,
      onTap: isRefreshing ? null : onRefresh,
    );
    final avatar = GestureDetector(
      // Switching tabs (not pushing a route) keeps the home
      // shell's bottom navbar visible behind the Settings tab.
      onTap: () =>
          HomeTabScope.of(context).requestTab(HomeTabs.settings),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: KashfColors.gold.withValues(alpha: 0.18),
          border: Border.all(color: KashfColors.gold, width: 1.2),
        ),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        child: Image.asset(
          'assets/images/logoprofile.jpg',
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              Icon(Icons.person, color: KashfColors.gold, size: 18),
        ),
      ),
    );

    // Children are listed in natural LTR visual order. Directionality
    // mirrors them for RTL automatically:
    //   LTR: [avatar] [refresh] [bell] ... [logo]
    //   RTL: [logo]  ... [bell] [refresh] [avatar]
    return Row(
      children: [
        avatar,
        SizedBox(width: 8),
        refreshButton,
        SizedBox(width: 6),
        bell,
        Spacer(),
        logoMark,
      ],
    );
  }
}

/// Round gold-bordered icon button that mirrors the look of the
/// notification bell. Shows a spinner while [isLoading] is true
/// and ignores taps so the user can't double-fire.
class _RefreshIconButton extends StatelessWidget {
  const _RefreshIconButton({
    required this.isLoading,
    required this.onTap,
  });

  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Subscribe to theme changes so this const widget re-runs
    // build() when the user flips the palette.
    ThemeScope.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: KashfPalette.active.surface,
          border: Border.all(color: KashfColors.gold.withValues(alpha: 0.55)),
        ),
        alignment: Alignment.center,
        child: isLoading
            ? const InlineSpinner(size: 14)
            : const Icon(
                Icons.refresh_rounded,
                color: KashfColors.gold,
                size: 16,
              ),
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Subscribe to theme changes so this const widget re-runs
    // build() when the user flips the palette.
    ThemeScope.of(context);
    return SizedBox(
      width: 30,
      height: 30,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: KashfPalette.active.surface,
              border: Border.all(color: KashfPalette.active.cardBorder),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.notifications_none_outlined,
              color: KashfPalette.active.textPrimary,
              size: 16,
            ),
          ),
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: KashfColors.gold,
                shape: BoxShape.circle,
                border: Border.all(
                  color: KashfPalette.active.background,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '1',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================ Greeting ============================
// Compact greeting line shown between the top bar and the featured card:
// "Good morning, Noor" + a softer "Welcome to KASHF Lite" subtitle.
class _Greeting extends StatelessWidget {
  const _Greeting({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    // Subscribe to theme changes so this const widget re-runs
    // build() when the user flips the palette.
    ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(0, 6, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: l.t('home_greeting')),
                TextSpan(text: ', '),
                TextSpan(
                  text: l.t('home_user_name'),
                  style: TextStyle(color: KashfColors.gold),
                ),
              ],
            ),
            style: TextStyle(
              color: KashfPalette.active.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            l.t('home_greeting_sub'),
            style: TextStyle(
              color: KashfPalette.active.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ============================ Featured Investigation ============================
class _FeaturedInvestigation extends StatelessWidget {
  const _FeaturedInvestigation({
    required this.l,
    required this.brandController,
    this.todayCase,
  });
  final AppLocalizations l;
  final FeaturedBrandController brandController;

  /// Random case loaded from `assets/Data/today_case.json`.
  /// When non-null, the card title + subtitle use this case's
  /// brand name and the detail screen is opened with the same
  /// instance. When null, the card falls back to the brand
  /// controller's headline strings.
  final TodayCase? todayCase;

  /// Brand-aware headline. Picks the Arabic label for RTL users
  /// (`brandController.brandLabel` is the Arabic form when one
  /// is known, the raw English key otherwise) and falls back to
  /// the raw English key for LTR users.
  String _title(AppLocalizations l) {
    final c = todayCase;
    if (c != null) {
      // Use the bundled case as the source of truth when it's
      // available so the headline matches the detail screen.
      return l.t('home_featured_title_with_brand_en')
          .replaceAll('{brand}', c.displayName(isRtl: l.isRtl));
    }
    final brand = brandController.brandKey ?? '';
    if (brand.isEmpty) return l.t('home_featured_title');
    if (l.isRtl) {
      final arabic = brandController.brandLabel;
      if (arabic.isNotEmpty && arabic != brand) {
        return l.t('home_featured_title_with_brand_ar')
            .replaceAll('{brand}', arabic);
      }
      return l.t('home_featured_title_with_brand_en')
          .replaceAll('{brand}', brand);
    }
    return l.t('home_featured_title_with_brand_en')
        .replaceAll('{brand}', brand);
  }

  /// Subtitle: includes the brand name so the user immediately
  /// sees WHICH brand the card is about. Brand name comes from
  /// the same source as [_title] so they stay in sync.
  String _subtitle(AppLocalizations l) {
    final c = todayCase;
    if (c != null) {
      return l
          .t('home_featured_subtitle_with_brand')
          .replaceAll('{brand}', c.displayName(isRtl: l.isRtl));
    }
    final brand = brandController.brandKey ?? '';
    if (brand.isEmpty) return l.t('home_featured_subtitle');
    return l.t('home_featured_subtitle_with_brand')
        .replaceAll('{brand}', brand);
  }

  /// Trims a mentions string like `"286K"` or `"1.2M"` so it
  /// fits inside the small featured stat slot without forcing
  /// the whole row to scale down.
  ///
  /// The JSON sometimes carries long strings like `"1.2M"`
  /// (fine) but can also carry `"1,200,000"`-style numbers.
  /// We abbreviate the latter into compact K/M form so the
  /// stat slot stays narrow.
  String _compactMentions(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return s;
    // Already short and friendly-looking — leave it alone.
    if (s.length <= 5) return s;
    // Strip thousands separators and try to parse as a number.
    final stripped = s.replaceAll(',', '');
    final n = num.tryParse(stripped);
    if (n == null) return s;
    if (n >= 1000000) {
      final m = n / 1000000.0;
      return '${_trimDecimal(m)}M';
    }
    if (n >= 1000) {
      final k = n / 1000.0;
      return '${_trimDecimal(k)}K';
    }
    return n.toString();
  }

  /// Trims trailing `.0` from a double so "2.0M" becomes "2M".
  String _trimDecimal(double v) {
    final s = v.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe to theme changes so this const widget re-runs
    // build() when the user flips the palette.
    ThemeScope.of(context);
    final palette = KashfPalette.active;
    // Purple is the primary accent for this card. Kept as a
    // constant so the brand-card identity stays consistent
    // across palettes (only the *background* surfaces flip).
    const purple = Color(0xFF8B5CF6);
    // When the bundled JSON hasn't been loaded yet, render a
    // skeleton card instead of the demo strings so the user
    // never sees stale placeholder data.
    final c = todayCase;
    final showSkeleton = c == null;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        kashfRoute(
          TodayCaseScreen(todayCase: todayCase),
        ),
      ),
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: star icon + "قضية اليوم" label
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 8),
            child: Row(
              children: [
                Text(
                  l.t('home_featured_today'),
                  style: TextStyle(
                    color: purple,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.star_outline, color: purple, size: 20),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  palette.surface,
                  palette.surfaceLight,
                ],
              ),
              border: Border.all(
                color: purple.withValues(alpha: 0.40),
                width: 1,
              ),
            ),
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1) Text column (RIGHT side in RTL = START).
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title â€” white, bold. Brand-aware so the
                          // headline rotates when the user refreshes.
                          if (showSkeleton)
                            const _FeaturedSkeleton(height: 16, width: 0.85)
                          else
                            Text(
                              _title(l),
                              textAlign: TextAlign.start,
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 6),
                          // Subtitle â€” lighter gray, plain text (no icon).
                          if (showSkeleton)
                            const _FeaturedSkeleton(height: 12, width: 0.65)
                          else
                            Text(
                              _subtitle(l),
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 11,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          Spacer(),
                          // Bottom row: stats (start side) + CTA pill (end side).
                          if (showSkeleton)
                            const Padding(
                              padding: EdgeInsetsDirectional.only(top: 6),
                              child: _FeaturedSkeleton(height: 14, width: 0.5),
                            )
                          else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Stats inline with thin vertical dividers.
                                // Wrapped in Flexible so the stats block
                                // yields room to the CTA pill on narrow
                                // screens; each stat is also Flexible so
                                // long unit strings shrink instead of
                                // pushing the row off the right edge.
                                Flexible(
                                  child: Row(
                                    children: [
                                      Flexible(
                                        flex: 2,
                                        child: _FeaturedStat(
                                          value: c.kpi.activeDays,
                                          unit: l
                                              .t('home_featured_metric1_ar'),
                                          color: purple,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        width: 1,
                                        height: 22,
                                        color: purple.withValues(alpha: 0.30),
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        flex: 2,
                                        child: _FeaturedStat(
                                          value: c.kpi.index,
                                          unit: l
                                              .t('home_featured_metric2_ar'),
                                          color: purple,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        width: 1,
                                        height: 22,
                                        color: purple.withValues(alpha: 0.30),
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        flex: 3,
                                        child: _FeaturedStat(
                                          value: _compactMentions(
                                              c.kpi.mentions),
                                          unit: l
                                              .t('home_featured_metric3_ar'),
                                          color: purple,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              SizedBox(width: 8),
                              // Outlined purple pill CTA on the END side.
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.surfaceLight
                                      .withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: purple, width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      l.t('home_featured_open'),
                                      style: TextStyle(
                                        color: purple,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    SizedBox(width: 3),
                                    Icon(
                                      Icons.chevron_right,
                                      color: purple,
                                      size: 14,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 12),
                    // 2) Image tile (ends up on the RIGHT side in RTL). Expands
                    // to the full height of the card so it doesn't look like a
                    // small thumbnail.
                    Expanded(
                      flex: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: palette.surfaceLight,
                          border: Border.all(
                            color: purple.withValues(alpha: 0.45),
                            width: 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (showSkeleton)
                              // Pulsing gray block while the JSON is
                              // loading — never show the lattafa
                              // fallback image during the load.
                              const _FeaturedSkeleton(
                                  height: 96, width: 1.0)
                            else
                              _FeaturedBrandLogo(
                                // Prefer the JSON-bundled logo URL when
                                // a case is loaded so the featured card
                                // matches the detail screen.
                                logoUrl: todayCase?.cleanLogoUrl ??
                                    brandController.logoUrl,
                                fallbackBrandKey:
                                    todayCase?.logourl ??
                                        brandController.brandKey,
                              ),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: AlignmentDirectional.topEnd,
                                  end: AlignmentDirectional.bottomStart,
                                  colors: [
                                    Colors.transparent,
                                    purple.withValues(alpha: 0.18),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders the brand logo for the currently featured brand via
/// `LogoService.urlFor(...)`. Falls back to the bundled Lattafa
/// asset if the Logo.dev URL hasn't loaded yet or fails, so the
/// card never looks empty.
class _FeaturedBrandLogo extends StatelessWidget {
  const _FeaturedBrandLogo({
    required this.logoUrl,
    required this.fallbackBrandKey,
  });

  final String? logoUrl;
  final String? fallbackBrandKey;

  @override
  Widget build(BuildContext context) {
    // Subscribe to theme changes so this const widget re-runs
    // build() when the user flips the palette.
    ThemeScope.of(context);
    final palette = KashfPalette.active;
    const purple = Color(0xFF8B5CF6);
    if (logoUrl == null) {
      // No brand picked yet (extremely rare â€” bootstrap fills it
      // synchronously on launch). Render the bundled fallback so
      // the slot is never blank.
      return _fallback(purple, palette);
    }
    return Image.network(
      logoUrl!,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      // White background lets light logos (e.g. Starbucks on a
      // white CDN) read against the card surface in either theme.
      color: palette.textPrimary,
      colorBlendMode: BlendMode.modulate,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          alignment: Alignment.center,
          child: const InlineSpinner(size: 18),
        );
      },
      errorBuilder: (_, error, _) {
        assert(() {
          // ignore: avoid_print
          print('[FeaturedBrand] logo load failed for '
              '$logoUrl: $error');
          return true;
        }());
        return _fallback(purple, palette);
      },
    );
  }

  Widget _fallback(Color purple, KashfPalette palette) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/lattafa.jpeg',
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            color: palette.surface,
            alignment: Alignment.center,
            child: Icon(Icons.local_florist, color: purple, size: 36),
          ),
        ),
      ],
    );
  }
}

/// Skeleton placeholder shown on the home featured card while
/// the bundled `assets/Data/today_case.json` is still being
/// loaded. Renders a pulsing rounded rectangle instead of the
/// localized demo strings so the user never sees stale data.
class _FeaturedSkeleton extends StatefulWidget {
  const _FeaturedSkeleton({
    required this.height,
    required this.width,
  });

  final double height;

  /// Width as a fraction of the parent (0..1). Use 1.0 for
  /// a full-width bar.
  final double width;

  @override
  State<_FeaturedSkeleton> createState() => _FeaturedSkeletonState();
}

class _FeaturedSkeletonState extends State<_FeaturedSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        final t = _ctrl.value;
        return FractionallySizedBox(
          widthFactor: widget.width,
          alignment: AlignmentDirectional.centerStart,
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: Color.lerp(
                const Color(0x33FFFFFF),
                const Color(0x66FFFFFF),
                t,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FeaturedStat extends StatelessWidget {
  const _FeaturedStat({
    required this.value,
    required this.unit,
    required this.color,
  });
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Subscribe to theme changes so this const widget re-runs
    // build() when the user flips the palette.
    ThemeScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Big number — purple accent. Wrapped in FittedBox so
        // long values like "8.7M" or "286K" shrink to fit the
        // available width instead of overflowing the row and
        // breaking the alignment with the dividers.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            value,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 1),
        // Unit label — purple accent. FittedBox guarantees it shrinks
        // instead of overflowing when the string is long.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            unit,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              color: color,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================ Section Header ============================
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.trailing,
    this.onTrailingTap,
    this.trailingLoading = false,
  });
  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;
  final bool trailingLoading;

  @override
  Widget build(BuildContext context) {
    // Subscribe to theme changes so this const widget re-runs
    // build() when the user flips the palette.
    ThemeScope.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: KashfPalette.active.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (trailingLoading)
          const InlineSpinner(size: 12)
        else if (trailing != null)
          GestureDetector(
            onTap: onTrailingTap,
            child: Text(
              trailing!,
              style: TextStyle(
                color: KashfColors.gold,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

// ============================ Market Pulse ============================
class _MarketPulseList extends StatelessWidget {
  const _MarketPulseList({
    required this.l,
    this.data,
    this.isLoading = false,
  });

  final AppLocalizations l;
  final MarketPulseData? data;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    // Resolve the activity block: prefer AI data, fall back to the
    // localized demo strings already shipped with the app.
    final hasAi = data != null;
    final activity = data?.activity;
    return _MarketPulsePanel(
      l: l,
      localeCode: l.language.code,
      aiMetrics: data?.metrics,
      aiActivity: activity,
      isLoading: isLoading && !hasAi,
    );
  }
}

class _MarketPulsePanel extends StatelessWidget {
  const _MarketPulsePanel({
    required this.l,
    required this.localeCode,
    this.aiMetrics,
    this.aiActivity,
    this.isLoading = false,
  });

  final AppLocalizations l;
  final String localeCode;
  final List<MarketPulseMetric>? aiMetrics;
  final MarketPulseActivity? aiActivity;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    // Subscribe to theme changes so this const widget re-runs
    // build() when the user flips the palette.
    ThemeScope.of(context);
    final palette = KashfPalette.active;
    // Color tokens used across the panel. The semantic colours
    // (green/blue/red/gold) are status indicators and intentionally
    // do NOT flip with the theme; only the *surfaces* adapt.
    const green = Color(0xFF22C55E);
    const blue = Color(0xFF38BDF8);
    const red = Color(0xFFEF4444);
    const gold = Color(0xFFF4C542);

    final List<_PulseCardData> cards;
    if (aiMetrics != null && aiMetrics!.isNotEmpty) {
      cards = aiMetrics!.take(4).map((m) {
        return _PulseCardData(
          label: m.label,
          value: m.value,
          sub: m.sub,
          color: pulseColorToColor(m.color),
          bg: pulseBgForColor(m.color),
          points: m.points,
        );
      }).toList();
      while (cards.length < 4) {
        cards.add(_PulseCardData(
          label: 'â€”',
          value: 'â€”',
          sub: '',
          color: blue,
          bg: palette.surfaceLight,
          points: _kSparkWave1,
        ));
      }
    } else {
      cards = <_PulseCardData>[
        _PulseCardData(
          label: l.t('home_pulse_top_gainers'),
          value: l.t('home_pulse_gainers_val'),
          sub: l.t('home_pulse_gainers_sub'),
          color: green,
          bg: green.withValues(alpha: 0.10),
          points: _kSparkUp,
        ),
        _PulseCardData(
          label: l.t('home_pulse_top_traded'),
          value: l.t('home_pulse_traded_val'),
          sub: l.t('home_pulse_traded_sub'),
          color: blue,
          bg: blue.withValues(alpha: 0.10),
          points: _kSparkWave1,
        ),
        _PulseCardData(
          label: l.t('home_pulse_top_losers'),
          value: l.t('home_pulse_losers_val'),
          sub: l.t('home_pulse_losers_sub'),
          color: red,
          bg: red.withValues(alpha: 0.10),
          points: _kSparkDown,
        ),
        _PulseCardData(
          label: l.t('home_pulse_top_campaigns'),
          value: l.t('home_pulse_campaigns_val'),
          sub: l.t('home_pulse_campaigns_sub'),
          color: gold,
          bg: gold.withValues(alpha: 0.10),
          points: _kSparkWave2,
        ),
      ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Row of 4 colored cards (equal width, side-by-side).
        Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) SizedBox(width: 8),
              Expanded(
                child: _PulseMetricCard(
                  data: cards[i],
                  localeCode: localeCode,
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: 8),
        // Bottom activity row: clock icon + label/sub on the start,
        // big percentage + small chart on the end (RTL-aware ordering).
        Container(
          padding: EdgeInsetsDirectional.fromSTEB(10, 8, 10, 8),
          decoration: BoxDecoration(
            color: KashfPalette.active.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: KashfPalette.active.cardBorder),
          ),
          child: Row(
            children: [
              // Start side: clock icon + text block.
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: green.withValues(alpha: 0.18),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.access_time, color: green, size: 16),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      aiActivity?.title.isNotEmpty == true
                          ? aiActivity!.title
                          : l.t('home_pulse_market_active'),
                      style: TextStyle(
                        color: KashfPalette.active.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 1),
                    Text(
                      aiActivity?.subtitle.isNotEmpty == true
                          ? aiActivity!.subtitle
                          : l.t('home_pulse_market_active_h'),
                      style: TextStyle(
                        color: KashfPalette.active.textSecondary,
                        fontSize: 9,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              // End side: text block + small chart image.
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    aiActivity?.alertTitle.isNotEmpty == true
                        ? aiActivity!.alertTitle
                        : l.t('home_pulse_market_alert'),
                    style: TextStyle(
                      color: KashfPalette.active.textPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 1),
                  Text(
                    aiActivity?.alertValue.isNotEmpty == true
                        ? aiActivity!.alertValue
                        : l.t('home_pulse_market_vs'),
                    style: TextStyle(
                      color: green,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              SizedBox(width: 6),
              Container(
                width: 36,
                height: 22,
                decoration: BoxDecoration(
                  color: green.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(5),
                ),
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                child: CustomPaint(
                  size: Size(36, 22),
                  painter: _SparklinePainter(
                    color: green,
                    points: aiActivity?.points ?? _kSparkUp,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PulseCardData {
  const _PulseCardData({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    required this.bg,
    required this.points,
  });
  final String label;
  final String value;
  final String sub;
  final Color color;
  final Color bg;
  final List<double> points;
}

class _PulseMetricCard extends StatelessWidget {
  const _PulseMetricCard({
    required this.data,
    required this.localeCode,
  });
  final _PulseCardData data;
  final String localeCode;

  @override
  Widget build(BuildContext context) {
    // Subscribe to theme changes so this const widget re-runs
    // build() when the user flips the palette.
    ThemeScope.of(context);
    final valueText = localiseBrandOrTag(data.value, locale: localeCode);
    final subText = localiseBrandOrTag(data.sub, locale: localeCode);
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(8, 8, 8, 6),
      decoration: BoxDecoration(
        color: data.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: data.color.withValues(alpha: 0.22), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top: small label (الأكثر صعوداً, etc.).
          Text(
            data.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: data.color,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 4),
          // Middle: big value (+24%, #Lattafa, -8%, 12). We
          // normalise hashtags and brand names so they always
          // match the active locale (e.g. "#لاتافا" in Arabic).
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              valueText,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: data.color,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
              maxLines: 1,
            ),
          ),
          SizedBox(height: 3),
          // Subtitle (عطر, 328K منشور, etc.).
          Text(
            subText,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: KashfPalette.active.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 4),
          // Bottom: wavy sparkline chart.
          SizedBox(
            height: 22,
            width: double.infinity,
            child: CustomPaint(
              size: Size.infinite,
              painter: _SparklinePainter(
                color: data.color,
                points: data.points,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tiny sparkline painter that draws a small, irregular zig-zag line
/// through the given normalized values (0..1). Used at the bottom of
/// each pulse card and inside the small chart thumbnail.
class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({required this.color, required this.points});

  final Color color;
  final List<double> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    // Use most of the vertical band so the line clearly undulates.
    // The painter is fed normalized 0..1 values from the AI; we map
    // the full range (0..1) to the box height, leaving a small
    // margin top + bottom so the line never clips.
    final topMargin = size.height * 0.10;
    final bottomMargin = size.height * 0.10;
    final usableHeight = size.height - topMargin - bottomMargin;
    double yFor(double v) =>
        topMargin + (1.0 - v.clamp(0.0, 1.0)) * usableHeight;

    final path = Path();
    final n = points.length;
    final dx = size.width / (n - 1);

    // Connect points directly. With hourly samples the segments
    // are short, giving the line a clearly "alive" look.
    path.moveTo(0, yFor(points[0]));
    for (var i = 1; i < n; i++) {
      path.lineTo(i * dx, yFor(points[i]));
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.color != color || old.points != points;
}

/// Pre-baked wave shapes for the demo data. All values are
/// normalized to 0..1 (vertical range used by the painter). Each
/// card uses 24 hourly samples with a different blend of sine
/// waves so the line clearly oscillates instead of looking flat.
const List<double> _kSparkUp = <double>[
  0.30, 0.42, 0.55, 0.68, 0.78, 0.86, 0.82, 0.74,
  0.65, 0.58, 0.50, 0.44, 0.40, 0.48, 0.58, 0.70,
  0.80, 0.88, 0.92, 0.86, 0.78, 0.66, 0.54, 0.46,
];

const List<double> _kSparkDown = <double>[
  0.78, 0.72, 0.64, 0.58, 0.50, 0.42, 0.36, 0.32,
  0.30, 0.36, 0.44, 0.50, 0.58, 0.62, 0.66, 0.58,
  0.48, 0.40, 0.34, 0.30, 0.28, 0.34, 0.42, 0.50,
];

const List<double> _kSparkWave1 = <double>[
  0.50, 0.62, 0.74, 0.82, 0.78, 0.66, 0.54, 0.42,
  0.34, 0.40, 0.52, 0.64, 0.74, 0.82, 0.88, 0.80,
  0.68, 0.56, 0.44, 0.36, 0.42, 0.54, 0.66, 0.76,
];

const List<double> _kSparkWave2 = <double>[
  0.70, 0.60, 0.48, 0.38, 0.32, 0.40, 0.52, 0.64,
  0.74, 0.80, 0.74, 0.64, 0.52, 0.42, 0.36, 0.42,
  0.54, 0.66, 0.78, 0.86, 0.82, 0.72, 0.60, 0.50,
];

// ============================ Recent Updates ============================
//
// Horizontal card list mirrored from the archive layer. Each row
// corresponds to one [SavedInvestigation] so a user's recent
// investigations surface immediately on the home screen without
// scrolling to the dedicated "Latest Investigations" section.
//
// The visual treatment is unchanged from the previous hardcoded
// layout â€” only the data source moved from inline demo entries to
// the controller-driven Firestore stream.
class _RecentUpdatesList extends StatelessWidget {
  const _RecentUpdatesList({
    required this.l,
    required this.investigations,
    required this.onOpenReport,
  });
  final AppLocalizations l;
  final List<SavedInvestigation> investigations;

  /// Tap handler invoked when the user taps one of the cards.
  /// Provided by the home screen so this widget stays stateless
  /// and doesn't know about navigation / loading details.
  final void Function(SavedInvestigation item) onOpenReport;

  @override
  Widget build(BuildContext context) {
    // Subscribe to theme changes so this const widget re-runs
    // build() when the user flips the palette.
    ThemeScope.of(context);
    // Caps the list at 4 rows. The upstream
    // [LatestInvestigationsController] is now Firestore-only so
    // no dedupe is needed — Firestore guarantees one doc per id.
    final recent = investigations.take(4).toList();
    if (recent.isEmpty) {
      // Render a single muted placeholder so the section header
      // doesn't collapse into thin air. The placeholder is
      // non-interactive (no onOpenReport) so taps on it are a
      // no-op rather than opening a missing report.
      return _UpdateCard(
        item: _UpdateItem.placeholder(l: l),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: recent.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final saved = recent[i];
        return _UpdateCard(
          item: _UpdateItem.fromInvestigation(saved: saved, l: l),
          onTap: () => onOpenReport(saved),
        );
      },
    );
  }
}

class _UpdateItem {
  const _UpdateItem({
    required this.title,
    required this.price,
    required this.views,
    required this.status,
    required this.time,
    required this.score,
    required this.scoreColor,
    required this.dotColor,
    required this.thumbnailUrl,
    required this.entityIcon,
    required this.entityColor,
  });

  /// Builds a row model from a saved investigation. Field
  /// mappings (kept intentionally simple so the visual stays
  /// recognisable from the demo):
  ///   * title   â†’ SavedInvestigation.title
  ///   * price   â†’ SavedInvestigation.subtitle (short blurb)
  ///   * views   â†’ evidence count if > 0, else tag list
  ///   * status  â†’ confidence-band label (high/medium/low)
  ///   * time    â†’ "x ago" relative timestamp
  ///   * score   â†’ SavedInvestigation.confidencePercent
  ///   * colors  â†’ derived from confidence band
  ///   * thumb   â†’ SavedInvestigation.thumbnailUrl (network)
  ///               with an entity-type icon fallback when
  ///               no thumbnail is available
  factory _UpdateItem.fromInvestigation({
    required SavedInvestigation saved,
    required AppLocalizations l,
  }) {
    final color = _bandColorFor(saved.confidenceBand);
    final score = '${saved.confidencePercent}%';
    final status = _bandLabelFor(saved.confidenceBand, l);
    final time = _sinceLabelFor(saved.createdAt, l);
    final price = saved.subtitle.isNotEmpty ? saved.subtitle : '';
    final views = saved.evidenceCount > 0
        ? l.tp('home_latest_evidence', {
            'n': saved.evidenceCount.toString(),
          })
        : (saved.tags.isNotEmpty ? saved.tags.first : '');
    return _UpdateItem(
      title: saved.title,
      price: price,
      views: views,
      status: status,
      time: time,
      score: score,
      scoreColor: color,
      dotColor: color,
      thumbnailUrl: saved.thumbnailUrl,
      entityIcon: saved.entityType.filledIcon,
      entityColor: color,
    );
  }

  /// Empty-state row shown when the user has no saved
  /// investigations yet. Mirrors the regular row layout so the
  /// section header doesn't sit awkwardly on its own.
  factory _UpdateItem.placeholder({required AppLocalizations l}) {
    // Use a neutral text-color for the placeholder markers so it
    // works in both dark and light themes.
    final neutral = KashfPalette.active.textSecondary;
    return _UpdateItem(
      title: l.t('home_update_placeholder_title'),
      price: l.t('home_update_placeholder_subtitle'),
      views: '',
      status: l.t('home_latest_band_medium'),
      time: '',
      score: 'â€“',
      scoreColor: neutral,
      dotColor: neutral,
      thumbnailUrl: null,
      entityIcon: Icons.search_outlined,
      entityColor: neutral,
    );
  }

  final String title;
  final String price;
  final String views;
  final String status;
  final String time;
  final String score;
  final Color scoreColor;
  final Color dotColor;
  final String? thumbnailUrl;
  final IconData entityIcon;
  final Color entityColor;

  // ------------------------------------------------------------------
  // Inline helpers â€” duplicated from the Latest Investigations
  // card so this section is self-contained. Kept tiny on
  // purpose so we don't introduce a third copy of the same
  // colour / label tables elsewhere in the app.
  // ------------------------------------------------------------------
  static Color _bandColorFor(String band) {
    switch (band) {
      case 'high':
        return const Color(0xFF22C55E);
      case 'low':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFFF4C542);
    }
  }

  static String _bandLabelFor(String band, AppLocalizations l) {
    switch (band) {
      case 'high':
        return l.t('home_latest_band_high');
      case 'low':
        return l.t('home_latest_band_low');
      default:
        return l.t('home_latest_band_medium');
    }
  }

  static String _sinceLabelFor(DateTime then, AppLocalizations l) {
    final diff = DateTime.now().difference(then);
    if (diff.inMinutes < 1) {
      return l.t('home_latest_since_just_now');
    }
    if (diff.inMinutes < 60) {
      return l.t('home_latest_since_minutes')
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

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({required this.item, this.onTap});
  final _UpdateItem item;

  /// When non-null, the entire card becomes a tappable area
  /// that opens the saved investigation report. The home
  /// screen wires this to [_HomeScreenState._openSavedReport]
  /// so the card stays a pure presentational widget.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Subscribe to theme changes so this const widget re-runs
    // build() when the user flips the palette.
    ThemeScope.of(context);
    final appPalette = KashfPalette.active;
    final card = Container(
      decoration: BoxDecoration(
        color: appPalette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: appPalette.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 10, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Far left: 3-dot menu
            Icon(
              Icons.more_vert,
              color: appPalette.textSecondary,
              size: 18,
            ),
            const SizedBox(width: 10),
            // Right column: percentage (top), time (bottom)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.score,
                  style: TextStyle(
                    color: item.scoreColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.time,
                  style: TextStyle(
                    color: appPalette.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            // Middle of the row: status text + colored dot
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.status,
                  style: TextStyle(
                    color: item.scoreColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: item.dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            // Title column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      color: appPalette.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Wrapped in Flexible so the subtitle row (price +
                  // views) shrinks rather than overflowing when the
                  // AI returns a long subtitle string.
                  Flexible(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.price,
                            style: TextStyle(
                              color: appPalette.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            item.views,
                            style: TextStyle(
                              color: appPalette.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Far right (in LTR) / Far left (in RTL): thumbnail.
            // Every saved investigation uses the bundled report
            // asset so the row visually anchors on a consistent
            // image regardless of which subject the run covered.
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/report.jpg',
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  color: appPalette.surfaceLight,
                  child: Icon(
                    item.entityIcon,
                    color: item.entityColor,
                    size: 26,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    // Wrap the visual card in a Material + InkWell when an
    // onTap handler is supplied so the user gets ripple feedback
    // and the whole row is a single tap target. Without an
    // onTap (placeholder row) the card stays non-interactive.
    if (onTap == null) return card;
    return Material(
      color: appPalette.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: card,
      ),
    );
  }
}

