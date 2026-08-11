import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/news/news_data_controller.dart';
import '../services/news/news_models.dart';
import '../theme.dart';
import 'article_reader_sheet.dart';
import 'loading_overlay.dart';

/// News-topics filter chips used by both the Explore screen and
/// the Home screen. Selecting a chip notifies the parent via
/// [onChanged] so each screen can swap its own data source.
///
/// `null` represents the "Top stories" / general news chip which
/// always renders first.
class CategoryChipsRow extends StatelessWidget {
  const CategoryChipsRow({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.l,
  });

  /// The currently active topic. Always one of the 4 curated
  /// verticals (Fashion / Beauty / Influencers / Fragrances).
  final NewsTopic selected;
  final ValueChanged<NewsTopic> onChanged;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    // The 4 curated topic chips (Fashion / Beauty / Influencers /
    // Fragrances) in a fixed order. Limiting to these four keeps
    // both the home and explore carousels focused on the topics
    // the user actually cares about — there's no generic "Top"
    // chip anymore.
    final ordered = <NewsTopic>[
      NewsTopic.fashion,
      NewsTopic.beauty,
      NewsTopic.influencers,
      NewsTopic.fragrances,
    ];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        reverse: l.isRtl,
        padding: EdgeInsets.zero,
        itemCount: ordered.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final t = ordered[i];
          final picked = t == selected;
          return CategoryChip(
            icon: iconForTopic(t),
            label: labelForTopic(t, l),
            selected: picked,
            onTap: () => onChanged(t),
          );
        },
      ),
    );
  }

  static IconData iconForTopic(NewsTopic t) {
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

  static String labelForTopic(NewsTopic t, AppLocalizations l) {
    return l.isRtl ? t.labelAr : t.label;
  }
}

class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? KashfColors.gold : const Color(0xFF2A2D38),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? KashfColors.gold : Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? KashfColors.gold : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Trending carousel
// ============================================================================

/// Horizontally-scrolling carousel that renders the trending
/// articles for a given [NewsState]. Stateless on purpose so it
/// can be driven by either Explore or Home's controller.
class TrendingCarousel extends StatefulWidget {
  const TrendingCarousel({
    super.key,
    required this.newsState,
    required this.onPageChanged,
  });
  final NewsState newsState;
  final ValueChanged<int> onPageChanged;

  @override
  State<TrendingCarousel> createState() => _TrendingCarouselState();
}

class _TrendingCarouselState extends State<TrendingCarousel> {
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController()..addListener(_recomputeActive);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_recomputeActive)
      ..dispose();
    super.dispose();
  }

  void _recomputeActive() {
    if (!_scroll.hasClients) return;
    const outerH = 20.0;
    const inner = 12.0;
    const visibleCount = 3;
    final width = MediaQuery.of(context).size.width;
    final cardW =
        (width - (outerH * 2) - (inner * (visibleCount - 1))) / visibleCount;
    final stride = cardW + inner;
    final x = _scroll.position.pixels;
    final center = x + width / 2;
    final raw = ((center - outerH - cardW / 2) / stride).round();
    final count = _itemCount;
    if (count == 0) return;
    final idx = raw.clamp(0, count - 1);
    widget.onPageChanged(idx);
  }

  /// Number of items the carousel should render.
  int get _itemCount => widget.newsState.articles.length;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final width = MediaQuery.of(context).size.width;
    const outerH = 20.0;
    const inner = 12.0;
    const visibleCount = 3;
    final cardWidth =
        (width - (outerH * 2) - (inner * (visibleCount - 1))) / visibleCount;

    final newsArticles = widget.newsState.articles;

    if (newsArticles.isEmpty) {
      return TrendingEmptyState.forState(
        status: widget.newsState.status,
        l: l,
      );
    }

    return _buildList(
      itemCount: newsArticles.length,
      cardWidth: cardWidth,
      outerH: outerH,
      inner: inner,
      builder: (i) {
        final a = newsArticles[i];
        return _TrendingCard(
          title: a.title,
          subtitle: a.source.isNotEmpty ? a.source : a.publishedAt,
          imageUrl: a.imageUrl,
          width: cardWidth,
          onTap: () => ArticleReaderSheet.show(context, a),
        );
      },
    );
  }

  Widget _buildList({
    required int itemCount,
    required double cardWidth,
    required double outerH,
    required double inner,
    required Widget Function(int i) builder,
  }) {
    return SizedBox(
      height: 210,
      child: ListView.separated(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsetsDirectional.fromSTEB(outerH, 0, outerH, 0),
        itemCount: itemCount,
        separatorBuilder: (_, _) => SizedBox(width: inner),
        itemBuilder: (_, i) => builder(i),
      ),
    );
  }
}

class _TrendingCard extends StatefulWidget {
  const _TrendingCard({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.width,
    this.onTap,
  });
  final String imageUrl;
  final String title;
  final String subtitle;
  final double width;
  final VoidCallback? onTap;

  @override
  State<_TrendingCard> createState() => _TrendingCardState();
}

class _TrendingCardState extends State<_TrendingCard> {
  /// Number of times the user has tapped the retry button. Used
  /// as a `key` suffix on `Image.network` so each retry fully
  /// re-runs the codec pipeline.
  int _retryNonce = 0;

  /// When `true` the image is replaced by a graceful error card
  /// with a Retry button. Set by either `errorBuilder` (HTTP /
  /// DNS / TLS errors) or by [FlutterError.onError] when the
  /// codec throws `Invalid image data` after the future has
  /// already started.
  bool _failed = false;

  /// Previously-registered global error handler. We save the
  /// reference once in `initState` and restore it in `dispose`
  /// (or on a successful frame) so we never silently swallow
  /// unrelated errors.
  FlutterExceptionHandler? _prevOnError;

  @override
  void initState() {
    super.initState();
    _prevOnError = FlutterError.onError;
    // Codec errors raised AFTER `errorBuilder` has returned
    // would otherwise bubble all the way to the red error
    // screen. Trap only the ones that mention this card's URL
    // (or the well-known codec exception text) and convert
    // them into a graceful retry-able state.
    FlutterError.onError = (details) {
      final msg = details.exception.toString();
      final stack = details.stack?.toString() ?? '';
      final isThisCard =
          stack.contains(widget.imageUrl) || stack.contains('_TrendingCard');
      final isCodecError = msg.contains('Invalid image data') ||
          msg.contains('ImageCodecException');
      if (isCodecError && (isThisCard || stack.isEmpty)) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('[NewsCard] codec decode failed: '
              '${widget.imageUrl} :: ${details.exception}');
        }
        _markFailed();
        return;
      }
      _prevOnError?.call(details);
    };
  }

  @override
  void didUpdateWidget(covariant _TrendingCard old) {
    super.didUpdateWidget(old);
    if (old.imageUrl != widget.imageUrl) {
      _failed = false;
    }
  }

  @override
  void dispose() {
    if (FlutterError.onError != _prevOnError) {
      FlutterError.onError = _prevOnError;
    }
    super.dispose();
  }

  void _markFailed() {
    if (!mounted) return;
    setState(() => _failed = true);
  }

  void _retry() {
    if (!mounted) return;
    setState(() {
      _failed = false;
      _retryNonce++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: Material(
        color: const Color(0xFF171A20),
        borderRadius: BorderRadius.circular(15),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 125,
                child: _failed
                    ? _buildError()
                    : _buildImage(),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                top: 125,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(8, 5, 8, 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF9AA0A6),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: const Icon(
                          Icons.trending_up,
                          color: Color(0xFFD4A33A),
                          size: 20,
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
    );
  }

  Widget _buildImage() {
    // HTTP / DNS / TLS failures come through `errorBuilder`.
    // Codec decode failures (e.g. AVIF on the web engine, or a
    // server returning malformed bytes) are intercepted by the
    // per-card `FlutterError.onError` filter installed in
    // `initState`, which flips `_failed` and the card re-renders
    // as the graceful error fallback with a Retry button.
    return Image.network(
      // Re-keying on [_retryNonce] forces Flutter to throw away
      // the cached frame and start a brand new decode pipeline.
      widget.imageUrl,
      key: ValueKey('${widget.imageUrl}#$_retryNonce'),
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: const Color(0xFF0E0F14),
          alignment: Alignment.center,
          child: const SizedBox(
            width: 18,
            height: 18,
            child: InlineSpinner(size: 18),
          ),
        );
      },
      errorBuilder: (_, error, _) {
        // Surface this in debug builds so it's easy to spot which
        // URL broke; in release builds we just render the fallback.
        assert(() {
          // ignore: avoid_print
          print('[NewsCard] image load failed: $error');
          return true;
        }());
        // Schedule the state flip for after this frame so we
        // don't mutate state during build.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _markFailed();
        });
        return _buildError();
      },
    );
  }

  /// Graceful fallback rendered when the image couldn't be
  /// decoded. Renders inline (no toast, no full-screen pop-up)
  /// so the rest of the carousel stays usable.
  Widget _buildError() {
    final l = AppLocalizations.of(context);
    return Container(
      color: const Color(0xFF0E0F14),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.broken_image_outlined,
            size: 28,
            color: Color(0xFF8A8F9C),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              l.isRtl ? 'تعذر تحميل القصة' : 'Couldn’t load this story',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF9AA0A6),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: _retry,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFD4A33A),
              minimumSize: const Size(0, 24),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.refresh, size: 12),
            label: Text(
              l.isRtl ? 'إعادة المحاولة' : 'Retry',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty-state card shown when the carousel has nothing to render
/// (loading, error, or truly empty). Keeps the same 210-px height
/// as the carousel so the surrounding layout doesn't shift.
class TrendingEmptyState extends StatelessWidget {
  const TrendingEmptyState({super.key, required this.message});
  final String message;

  /// Returns a loading-style empty state instead of a plain
  /// spinner when the controller is currently fetching.
  static Widget forState({
    required NewsStatus status,
    required AppLocalizations l,
  }) {
    if (status == NewsStatus.loading) {
      return _TrendingLoading(l: l);
    }
    return TrendingEmptyState(
      message: status == NewsStatus.error
          ? l.t('explore_news_error')
          : l.t('explore_news_empty'),
    );
  }

  /// Branded spinner shown while the very first fetch is in
  /// flight. Kept the same 210-px footprint as the carousel so
  /// the surrounding layout doesn't shift.
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF9AA0A6),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _TrendingLoading extends StatelessWidget {
  const _TrendingLoading({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210,
      child: LoadingOverlay(
        visible: true,
        message: l.isRtl ? 'جاري التحديث…' : 'Refreshing feed…',
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Section header specific to Trending.
class TrendingSectionHeader extends StatelessWidget {
  const TrendingSectionHeader({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.trending_up, color: const Color(0xFFD4A33A), size: 20),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
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

// ============================================================================
// Page indicator (dots)
// ============================================================================

/// Horizontal dots indicator that mirrors the active page in the
/// trending carousel.
class DotsIndicator extends StatelessWidget {
  const DotsIndicator({super.key, required this.count, required this.index});
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: i == index ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == index ? KashfColors.gold : const Color(0xFF2A2D38),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
      ],
    );
  }
}