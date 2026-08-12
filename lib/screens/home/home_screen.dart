import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../models/saved_investigation.dart';
import '../../services/ai/ai_models.dart';
import '../../services/ai/ai_text_utils.dart';
import '../../services/ai/featured_brand_controller.dart';
import '../../services/ai/home_data_controller.dart';
import '../../services/news/news_data_controller.dart';
import '../../services/news/news_models.dart';
import '../../state/latest_investigations_controller.dart';
import '../../theme.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/news_carousel.dart';
import '../files/latest_investigations_screen.dart';
import '../market/market_screen.dart';
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
      // Default to Fashion so the home carousel surfaces what's
      // trending in the highest-priority vertical on first load.
      //
      // `bootstrap` is cache-first: it renders whatever is on
      // disk/Firestore immediately and only schedules a network
      // refresh if the cached payload is older than 24 hours.
      // We deliberately do NOT call `refreshNow` here — that
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
          message: l.isRtl
              ? 'جاري تحميل بيانات الذكاء الاصطناعي…'
              : 'Loading AI data…',
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
                    child: _RecentUpdatesList(l: l),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 4),
                  sliver: SliverToBoxAdapter(
                    child: _SectionHeader(
                      title: l.t('home_latest_investigations'),
                      trailing: l.t('home_view_all'),
                      onTrailingTap: () => Navigator.of(
                        context,
                      ).push(kashfRoute(const LatestInvestigationsScreen())),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsetsDirectional.fromSTEB(16, 4, 16, 24),
                  sliver: SliverToBoxAdapter(
                    child: _LatestInvestigationsList(
                      l: l,
                      controller: _latestInvestigations,
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
    final avatar = Container(
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
  });
  final AppLocalizations l;
  final FeaturedBrandController brandController;

  /// Brand-aware headline. Picks the Arabic label for RTL users
  /// (`brandController.brandLabel` is the Arabic form when one
  /// is known, the raw English key otherwise) and falls back to
  /// the raw English key for LTR users.
  String _title(AppLocalizations l) {
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
    final brand = brandController.brandKey ?? '';
    if (brand.isEmpty) return l.t('home_featured_subtitle');
    return l.t('home_featured_subtitle_with_brand')
        .replaceAll('{brand}', brand);
  }

  @override
  Widget build(BuildContext context) {
    // Purple is the primary accent for this card.
    const purple = Color(0xFF8B5CF6);
    return GestureDetector(
      onTap: () =>
          Navigator.of(context).push(kashfRoute(const TodayCaseScreen())),
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
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1F1810), Color(0xFF2D2418)],
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
                          // Title — white, bold. Brand-aware so the
                          // headline rotates when the user refreshes.
                          Text(
                            _title(l),
                            textAlign: TextAlign.start,
                            style: TextStyle(
                              color: KashfPalette.active.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 6),
                          // Subtitle — lighter gray, plain text (no icon).
                          Text(
                            _subtitle(l),
                            style: TextStyle(
                              color: KashfPalette.active.textPrimary.withValues(
                                alpha: 0.7,
                              ),
                              fontSize: 11,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Spacer(),
                          // Bottom row: stats (start side) + CTA pill (end side).
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Stats inline with thin vertical dividers.
                              Expanded(
                                child: Row(
                                  children: [
                                    _FeaturedStat(
                                      value: '12',
                                      unit: l.t('home_featured_metric1_ar'),
                                      color: purple,
                                    ),
                                    SizedBox(width: 6),
                                    Container(
                                      width: 1,
                                      height: 22,
                                      color: purple.withValues(alpha: 0.30),
                                    ),
                                    SizedBox(width: 6),
                                    _FeaturedStat(
                                      value: '8',
                                      unit: l.t('home_featured_metric2_ar'),
                                      color: purple,
                                    ),
                                    SizedBox(width: 6),
                                    Container(
                                      width: 1,
                                      height: 22,
                                      color: purple.withValues(alpha: 0.30),
                                    ),
                                    SizedBox(width: 6),
                                    _FeaturedStat(
                                      value: '24',
                                      unit: l.t('home_featured_metric3_ar'),
                                      color: purple,
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
                                  color: Colors.black.withValues(alpha: 0.35),
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
                          color: const Color(0xFF1A0F08),
                          border: Border.all(
                            color: purple.withValues(alpha: 0.45),
                            width: 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _FeaturedBrandLogo(
                              logoUrl: brandController.logoUrl,
                              fallbackBrandKey: brandController.brandKey,
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
    const purple = Color(0xFF8B5CF6);
    if (logoUrl == null) {
      // No brand picked yet (extremely rare — bootstrap fills it
      // synchronously on launch). Render the bundled fallback so
      // the slot is never blank.
      return _fallback(purple);
    }
    return Image.network(
      logoUrl!,
      fit: BoxFit.contain,
      alignment: Alignment.center,
      // White background lets light logos (e.g. Starbucks on a
      // white CDN) read against the dark card surface.
      color: Colors.white,
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
        return _fallback(purple);
      },
    );
  }

  Widget _fallback(Color purple) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/lattafa.jpeg',
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            color: const Color(0xFF2A1A0F),
            alignment: Alignment.center,
            child: Icon(Icons.local_florist, color: purple, size: 36),
          ),
        ),
      ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Small number â€" purple accent.
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            height: 1.0,
          ),
        ),
        SizedBox(height: 1),
        // Unit label â€" purple accent. FittedBox guarantees it shrinks
        // instead of overflowing when the string is long.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            unit,
            style: TextStyle(
              color: color,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
            maxLines: 1,
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
    // Color tokens used across the panel.
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
          label: '—',
          value: '—',
          sub: '',
          color: blue,
          bg: const Color(0xFF13202A),
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
          bg: const Color(0xFF12241A),
          points: _kSparkUp,
        ),
        _PulseCardData(
          label: l.t('home_pulse_top_traded'),
          value: l.t('home_pulse_traded_val'),
          sub: l.t('home_pulse_traded_sub'),
          color: blue,
          bg: const Color(0xFF13202A),
          points: _kSparkWave1,
        ),
        _PulseCardData(
          label: l.t('home_pulse_top_losers'),
          value: l.t('home_pulse_losers_val'),
          sub: l.t('home_pulse_losers_sub'),
          color: red,
          bg: const Color(0xFF241318),
          points: _kSparkDown,
        ),
        _PulseCardData(
          label: l.t('home_pulse_top_campaigns'),
          value: l.t('home_pulse_campaigns_val'),
          sub: l.t('home_pulse_campaigns_sub'),
          color: gold,
          bg: const Color(0xFF241F12),
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
          // Top: small label (الأكثر صعودًا, etc.).
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
class _RecentUpdatesList extends StatelessWidget {
  const _RecentUpdatesList({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final items = <_UpdateItem>[
      _UpdateItem(
        title: l.t('home_update_perfume'),
        price: l.t('home_update_perfume_h'),
        views: l.t('home_update_perfume_views'),
        status: l.t('home_update_perfume_status'),
        time: l.t('home_update_perfume_time'),
        score: l.t('home_update_perfume_score'),
        scoreColor: const Color(0xFF22C55E),
        dotColor: const Color(0xFF22C55E),
        imagePath: 'assets/images/parfum.jpeg',
      ),
      _UpdateItem(
        title: l.t('home_update_campaign'),
        price: l.t('home_update_campaign_h'),
        views: l.t('home_update_campaign_views'),
        status: l.t('home_update_campaign_status'),
        time: l.t('home_update_campaign_time'),
        score: l.t('home_update_campaign_score'),
        scoreColor: const Color(0xFF3B82F6),
        dotColor: const Color(0xFF3B82F6),
        imagePath: 'assets/images/borge.jpeg',
      ),
      _UpdateItem(
        title: l.t('home_update_market'),
        price: l.t('home_update_market_h'),
        views: l.t('home_update_market_views'),
        status: l.t('home_update_market_status'),
        time: l.t('home_update_market_time'),
        score: l.t('home_update_market_score'),
        scoreColor: const Color(0xFFF59E0B),
        dotColor: const Color(0xFFF59E0B),
        imagePath: 'assets/images/sauvage.jpeg',
      ),
      _UpdateItem(
        title: l.t('home_update_yasmine'),
        price: l.t('home_update_yasmine_h'),
        views: l.t('home_update_yasmine_views'),
        status: l.t('home_update_yasmine_status'),
        time: l.t('home_update_yasmine_time'),
        score: l.t('home_update_yasmine_score'),
        scoreColor: const Color(0xFFEF4444),
        dotColor: const Color(0xFFEF4444),
        imagePath: 'assets/images/lattafa.jpeg',
      ),
    ];
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _UpdateCard(item: items[i]),
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
    required this.imagePath,
  });
  final String title;
  final String price;
  final String views;
  final String status;
  final String time;
  final String score;
  final Color scoreColor;
  final Color dotColor;
  final String imagePath;
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({required this.item});
  final _UpdateItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 10, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Far left: 3-dot menu
            const Icon(Icons.more_vert, color: Color(0xFF6B7280), size: 18),
            const SizedBox(width: 10),
            // Right column: percentage (top), time (bottom)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${item.score}%',
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
                    color: KashfPalette.active.textSecondary,
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
                      color: KashfPalette.active.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        item.price,
                        style: TextStyle(
                          color: KashfPalette.active.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        item.views,
                        style: TextStyle(
                          color: KashfPalette.active.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Far right (in LTR) / Far left (in RTL): thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 64,
                height: 64,
                color: const Color(0xFF2D2418),
                child: Image.asset(
                  item.imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    alignment: Alignment.center,
                    color: const Color(0xFF2D2418),
                    child: const Icon(
                      Icons.image_outlined,
                      color: KashfColors.gold,
                      size: 24,
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

// ============================================================================
// Latest Investigations
// ============================================================================
//
// The bottom-most section on the home screen. Backed by
// [LatestInvestigationsController] which streams the most-recent
// completed investigations from the archive service (Firestore
// + local cache). Renders a vertical card list — clean, easy to
// scan — and a friendly empty state.
//
// Data flow:
//   SavedInvestigation → _LatestInvestigationCard → home page
class _LatestInvestigationsList extends StatelessWidget {
  const _LatestInvestigationsList({
    required this.l,
    required this.controller,
  });
  final AppLocalizations l;
  final LatestInvestigationsController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.isLoading && controller.items.isEmpty) {
          return const _LatestInvestigationsSkeleton();
        }
        if (controller.items.isEmpty) {
          return _LatestInvestigationsEmpty(l: l);
        }
        return Column(
          children: [
            for (var i = 0; i < controller.items.length; i++) ...[
              if (i != 0) const SizedBox(height: 10),
              _LatestInvestigationCard(
                item: controller.items[i],
                l: l,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _LatestInvestigationsEmpty extends StatelessWidget {
  const _LatestInvestigationsEmpty({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: KashfColors.gold.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: KashfColors.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.search,
              color: KashfColors.gold,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.t('home_latest_empty_title'),
                  style: TextStyle(
                    color: KashfPalette.active.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l.t('home_latest_empty_sub'),
                  style: TextStyle(
                    color: KashfPalette.active.textSecondary,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LatestInvestigationsSkeleton extends StatefulWidget {
  const _LatestInvestigationsSkeleton();
  @override
  State<_LatestInvestigationsSkeleton> createState() =>
      _LatestInvestigationsSkeletonState();
}

class _LatestInvestigationsSkeletonState
    extends State<_LatestInvestigationsSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
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
      builder: (context, _) {
        final alpha = 0.25 + 0.25 * _ctrl.value;
        return Column(
          children: [
            for (var i = 0; i < 2; i++) ...[
              if (i != 0) const SizedBox(height: 10),
              Container(
                height: 92,
                decoration: BoxDecoration(
                  color: KashfPalette.active.surface
                      .withValues(alpha: alpha),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: KashfPalette.active.cardBorder),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _LatestInvestigationCard extends StatelessWidget {
  const _LatestInvestigationCard({
    required this.item,
    required this.l,
  });
  final SavedInvestigation item;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final band = item.confidenceBand;
    final bandColor = _bandColor(band);
    final pctText = '${item.confidencePercent}%';
    final tags = item.tags;
    final thumbnail = item.thumbnailUrl;

    return Container(
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Visual identifier of the investigated subject.
                // Renders the AI-provided thumbnail when available
                // and falls back to the entity-type icon tile so
                // the row never looks empty.
                _LatestCardThumbnail(
                  url: thumbnail,
                  fallbackIcon: item.entityType.filledIcon,
                  fallbackColor: bandColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: KashfPalette.active.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _LatestStatusChip(
                  label: l.t('home_latest_status_complete'),
                  color: const Color(0xFF22C55E),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              item.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: KashfPalette.active.textSecondary,
                fontSize: 11,
                height: 1.3,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: KashfPalette.active.fieldFill,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: FractionallySizedBox(
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor:
                          (item.confidencePercent / 100).clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: bandColor,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  pctText,
                  style: TextStyle(
                    color: bandColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _bandLabel(band),
              style: TextStyle(
                color: KashfPalette.active.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in tags) _LatestTagPill(label: t),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _sinceLabel(item.createdAt),
                  style: TextStyle(
                    color: KashfPalette.active.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.evidenceCount > 0)
                  Text(
                    l.tp('home_latest_evidence', {
                      'n': item.evidenceCount.toString(),
                    }),
                    style: TextStyle(
                      color: KashfPalette.active.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _bandColor(String band) {
    switch (band) {
      case 'high':
        return const Color(0xFF22C55E);
      case 'low':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFFF4C542);
    }
  }

  String _bandLabel(String band) {
    switch (band) {
      case 'high':
        return l.t('home_latest_band_high');
      case 'low':
        return l.t('home_latest_band_low');
      default:
        return l.t('home_latest_band_medium');
    }
  }

  String _sinceLabel(DateTime then) {
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

class _LatestStatusChip extends StatelessWidget {
  const _LatestStatusChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// 40x40 thumbnail tile used in the Latest Investigations card row.
/// Renders the AI-provided image when one was persisted to the
/// archive; otherwise renders the entity-type icon so the slot
/// never looks empty.
class _LatestCardThumbnail extends StatelessWidget {
  const _LatestCardThumbnail({
    required this.url,
    required this.fallbackIcon,
    required this.fallbackColor,
  });
  final String? url;
  final IconData fallbackIcon;
  final Color fallbackColor;

  static const double size = 40;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fallbackColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: fallbackColor.withValues(alpha: 0.45),
        ),
      ),
      child: Icon(fallbackIcon, color: fallbackColor, size: 18),
    );
    if (url == null || url!.isEmpty) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          url!,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              color: KashfPalette.active.fieldFill,
              alignment: Alignment.center,
              child: const InlineSpinner(size: 12),
            );
          },
          errorBuilder: (_, _, _) => fallback,
        ),
      ),
    );
  }
}

class _LatestTagPill extends StatelessWidget {
  const _LatestTagPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: KashfPalette.active.fieldFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: KashfPalette.active.textSecondary,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
