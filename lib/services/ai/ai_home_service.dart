import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'ai_models.dart';
import 'ai_parser.dart';
import 'ai_prompts.dart';
import 'market_models.dart';
import 'market_parser.dart';
import 'openrouter_client.dart';
import 'openrouter_config.dart';

/// High-level service that turns the OpenRouter API into
/// dashboard-ready data for the Home screen.
///
/// The service exposes two async fetches:
///   * `fetchMarketPulse(...)` — populates the Market Pulse panel.
///   * `fetchQuickActions(...)` — populates the Quick Actions grid
///     and the Recent Updates list.
///
/// Each call is independent and caches the last successful response
/// in memory so re-renders / re-builds don't trigger fresh API
/// calls. Callers can also subscribe to [stream] for live updates.
class AiHomeService {
  AiHomeService({
    OpenRouterClient? client,
    Duration cacheTtl = const Duration(minutes: 5),
  })  : _client = client ?? OpenRouterClient.instance,
        _cacheTtl = cacheTtl;

  static final AiHomeService instance = AiHomeService();

  final OpenRouterClient _client;
  final Duration _cacheTtl;

  MarketPulseData? _marketPulseCache;
  DateTime? _marketPulseCachedAt;
  QuickActionsData? _quickActionsCache;
  DateTime? _quickActionsCachedAt;
  MarketDetailData? _marketDetailCache;
  DateTime? _marketDetailCachedAt;

  final StreamController<HomeAiData> _controller =
      StreamController<HomeAiData>.broadcast();

  /// Live stream of the latest fully-populated AI data. Useful for
  /// the UI to subscribe once and rebuild on every successful
  /// refresh.
  Stream<HomeAiData> get stream => _controller.stream;

  MarketPulseData? get cachedMarketPulse => _marketPulseCache;
  MarketDetailData? get cachedMarketDetail => _marketDetailCache;
  QuickActionsData? get cachedQuickActions => _quickActionsCache;

  /// Fetches Market Pulse data. If a fresh-enough cache exists the
  /// call returns immediately. Otherwise it hits OpenRouter and
  /// parses the response. Failed parses still resolve to a
  /// [MarketPulseData] with placeholder data so the UI never sees
  /// `null` mid-render.
  Future<MarketPulseData> fetchMarketPulse({
    required String language,
    String region = 'Kuwait',
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _marketPulseCache != null &&
        _marketPulseCachedAt != null &&
        DateTime.now().difference(_marketPulseCachedAt!) < _cacheTtl) {
      return _marketPulseCache!;
    }

    try {
      final nonce = _newNonce();
      final messages = AiPrompts.marketPulseMessages(
        language: language,
        region: region,
        nonce: nonce,
      );
      final json = await _client.chatCompletionJson(
        OpenRouterRequest(
          messages: messages,
          temperature: 0.7,
          maxTokens: 1800,
          responseFormat: const {'type': 'json_object'},
          extra: {'seed': nonce},
        ),
      );
      final data = AiParser.parseMarketPulse(json);
      _marketPulseCache = data;
      _marketPulseCachedAt = DateTime.now();
      _emit();
      return data;
    } catch (e, st) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[AiHomeService] fetchMarketPulse failed: $e\n$st');
      }
      final fallback = _buildFallbackMarketPulse(nonce: _newNonce());
      _marketPulseCache = fallback;
      _marketPulseCachedAt = DateTime.now(); // back-off until next refresh
      _emit();
      return fallback;
    }
  }

  /// Fetches Quick Actions + Recent Updates. Same caching story as
  /// [fetchMarketPulse].
  Future<QuickActionsData> fetchQuickActions({
    required String language,
    String region = 'Kuwait',
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _quickActionsCache != null &&
        _quickActionsCachedAt != null &&
        DateTime.now().difference(_quickActionsCachedAt!) < _cacheTtl) {
      return _quickActionsCache!;
    }

    try {
      final nonce = _newNonce();
      final messages = AiPrompts.quickActionsMessages(
        language: language,
        region: region,
        nonce: nonce,
      );
      final json = await _client.chatCompletionJson(
        OpenRouterRequest(
          messages: messages,
          temperature: 0.8,
          maxTokens: 2500,
          responseFormat: const {'type': 'json_object'},
          extra: {'seed': nonce},
        ),
      );
      final data = AiParser.parseQuickActions(json);
      _quickActionsCache = data;
      _quickActionsCachedAt = DateTime.now();
      _emit();
      return data;
    } catch (e, st) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[AiHomeService] fetchQuickActions failed: $e\n$st');
      }
      final fallback = _buildFallbackQuickActions(nonce: _newNonce());
      _quickActionsCache = fallback;
      _quickActionsCachedAt = DateTime.now();
      _emit();
      return fallback;
    }
  }

  /// Random 31-bit non-negative integer used to vary each fetch.
  /// Passed both into the user prompt (so the model sees it) and
  /// as the OpenRouter `seed` field (so the API does too).
  int _newNonce() => math.Random().nextInt(0x7FFFFFFF);

  /// Fetches the full Market Pulse detail payload (KPIs, donut
  /// sources, trend line, topics, brands, events). The data is
  /// cached in memory for [_cacheTtl] and falls back to demo
  /// values on any failure so the UI always renders.
  Future<MarketDetailData> fetchMarketDetail({
    required String language,
    String region = 'Kuwait',
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _marketDetailCache != null &&
        _marketDetailCachedAt != null &&
        DateTime.now().difference(_marketDetailCachedAt!) < _cacheTtl) {
      return _marketDetailCache!;
    }

    try {
      final nonce = _newNonce();
      final messages = AiPrompts.marketDetailMessages(
        language: language,
        region: region,
        nonce: nonce,
      );
      final json = await _client.chatCompletionJson(
        OpenRouterRequest(
          messages: messages,
          temperature: 0.7,
          maxTokens: 3000,
          responseFormat: const {'type': 'json_object'},
          extra: {'seed': nonce},
        ),
      );
      // Diagnostic: log what the AI returned for each brand so we
      // can see why domains are / aren't coming through.
      // ignore: avoid_print
      print('[AiHomeService] fetchMarketDetail raw brand domains:');
      final brandsRaw = json['brands'];
      if (brandsRaw is List) {
        for (var i = 0; i < brandsRaw.length; i++) {
          final b = brandsRaw[i];
          if (b is Map) {
            // ignore: avoid_print
            print('  [$i] name=${b['name']} domain=${b['domain']}');
          }
        }
      }
      final data = MarketParser.parse(json);
      _marketDetailCache = data;
      _marketDetailCachedAt = DateTime.now();
      return data;
    } catch (e, st) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[AiHomeService] fetchMarketDetail failed: $e\n$st');
      }
      final fallback = _buildFallbackMarketDetail(nonce: _newNonce());
      _marketDetailCache = fallback;
      _marketDetailCachedAt = DateTime.now();
      return fallback;
    }
  }

  /// Refresh both sections in parallel. Returns only when both
  /// have resolved (or fallen back). The UI uses this for the
  /// "pull to refresh" / refresh button.
  Future<void> refreshAll({
    required String language,
    String region = 'Kuwait',
  }) async {
    await Future.wait<void>(<Future<void>>[
      fetchMarketPulse(
        language: language,
        region: region,
        forceRefresh: true,
      ),
      fetchQuickActions(
        language: language,
        region: region,
        forceRefresh: true,
      ),
    ]);
  }

  /// Clears both caches. Useful for tests or when the user signs
  /// out.
  void clearCache() {
    _marketPulseCache = null;
    _marketPulseCachedAt = null;
    _quickActionsCache = null;
    _quickActionsCachedAt = null;
    _marketDetailCache = null;
    _marketDetailCachedAt = null;
  }

  Future<void> dispose() async {
    await _controller.close();
  }

  void _emit() {
    _controller.add(HomeAiData(
      marketPulse: _marketPulseCache,
      quickActions: _quickActionsCache,
    ));
  }

  // ---------- Fallback builders ----------

  MarketPulseData _buildFallbackMarketPulse({int? nonce}) {
    final rng = math.Random(nonce ?? math.Random().nextInt(0x7FFFFFFF));
    final gainerPct = 8 + rng.nextInt(48); // 8% .. 55%
    final loserPct = -(5 + rng.nextInt(30)); // -5% .. -34%
    final campaigns = 4 + rng.nextInt(20); // 4 .. 23
    const tradedBrands = <String>[
      '#Lattafa',
      '#Dior',
      '#Bvlgari',
      '#Shein',
      '#Nivea',
      '#Adidas',
      '#Apple',
      '#Samsung',
    ];
    const tradedSubs = <String>[
      'Perfume',
      'Beauty',
      'Fashion',
      'Tech',
      'F&B',
      'Electronics',
    ];
    return MarketPulseData(
      metrics: <MarketPulseMetric>[
        MarketPulseMetric(
          id: 'gainers',
          label: 'Top Gainers',
          value: '+$gainerPct%',
          sub: tradedBrands[rng.nextInt(tradedBrands.length)],
          color: PulseColor.green,
          bg: PulseColor.green,
          points: generateFallbackSparkline(seed: rng.nextDouble()),
        ),
        MarketPulseMetric(
          id: 'traded',
          label: 'Top Traded',
          value: tradedBrands[rng.nextInt(tradedBrands.length)],
          sub: tradedSubs[rng.nextInt(tradedSubs.length)],
          color: PulseColor.blue,
          bg: PulseColor.blue,
          points: generateFallbackSparkline(seed: rng.nextDouble()),
        ),
        MarketPulseMetric(
          id: 'losers',
          label: 'Top Losers',
          value: '$loserPct%',
          sub: tradedBrands[rng.nextInt(tradedBrands.length)],
          color: PulseColor.red,
          bg: PulseColor.red,
          points: generateFallbackSparkline(seed: rng.nextDouble()),
        ),
        MarketPulseMetric(
          id: 'campaigns',
          label: 'Top Campaigns',
          value: '$campaigns',
          sub: 'Live',
          color: PulseColor.gold,
          bg: PulseColor.gold,
          points: generateFallbackSparkline(seed: rng.nextDouble()),
        ),
      ],
      activity: MarketPulseActivity(
        title: 'Market active',
        subtitle: 'Live snapshot',
        alertTitle: 'Trend',
        alertValue: '—',
        comparisonText: '',
        color: PulseColor.green,
        points: generateFallbackSparkline(seed: rng.nextDouble()),
      ),
    );
  }

  QuickActionsData _buildFallbackQuickActions({int? nonce}) {
    const fallbackImages = <String>[
      'assets/images/parfum.jpeg',
      'assets/images/borge.jpeg',
      'assets/images/winner.jpeg',
      'assets/images/sauvage.jpeg',
      'assets/images/lattafa.jpeg',
    ];
    const titlesPool = <String>[
      'Lattafa',
      'Dior Sauvage',
      'Oud Satin',
      'Bvlgari',
      'iPhone 15',
      'Adidas Ultraboost',
      'Starbucks',
      'TikTok Trend',
      'Shein Drop',
      'Nivea',
      'Samsung S24',
      'Yasmine Brand',
    ];
    const statusPool = <String>[
      'Monitored',
      'Analyzing',
      'Collecting',
      'New updates',
      'Paused',
      'Escalated',
    ];
    const updateTitles = <String>[
      'Lattafa Asad',
      'Bvlgari Leather',
      'iPhone Launch',
      'Starbucks Menu',
      'Adidas Drop',
      'Shein Capsule',
    ];
    const timePool = <String>['2h', '5h', '13h', '1d', '47m', '3h'];
    final rng = math.Random(nonce ?? math.Random().nextInt(0x7FFFFFFF));
    final shuffledTitles = <String>[...titlesPool]..shuffle(rng);
    final shuffledStatuses = <String>[...statusPool]..shuffle(rng);
    final shuffledTime = <String>[...timePool]..shuffle(rng);
    final colors = PulseColor.values;
    final shuffledColors = <PulseColor>[...colors]..shuffle(rng);

    final actions = <QuickAction>[];
    for (var i = 0; i < 8; i++) {
      final c = shuffledColors[i % shuffledColors.length];
      actions.add(QuickAction(
        id: 'fallback_$i',
        title: shuffledTitles[i % shuffledTitles.length],
        progress: 0.15 + rng.nextDouble() * 0.80,
        statusText: shuffledStatuses[i % shuffledStatuses.length],
        statusColor: c,
        progressColor: c,
        imagePath: fallbackImages[i % fallbackImages.length],
        showDot: i.isEven,
        dotColor: c,
      ));
    }
    final updates = <RecentUpdateItem>[];
    for (var i = 0; i < 4; i++) {
      final c = shuffledColors[(i + 2) % shuffledColors.length];
      final kwd = 50 + rng.nextInt(900);
      updates.add(RecentUpdateItem(
        id: 'fallback_update_$i',
        title: updateTitles[(i + rng.nextInt(updateTitles.length)) %
            updateTitles.length],
        priceLine: 'KWD $kwd K',
        viewsLine: '${50 + rng.nextInt(950)}K views',
        statusText: shuffledStatuses[i % shuffledStatuses.length],
        timeText: shuffledTime[i % shuffledTime.length],
        scorePercent: 35 + rng.nextInt(60),
        scoreColor: c,
        dotColor: c,
        imagePath: fallbackImages[i % fallbackImages.length],
      ));
    }
    return QuickActionsData(actions: actions, recentUpdates: updates);
  }

  // ---------- Market detail fallback ----------

  MarketDetailData _buildFallbackMarketDetail({int? nonce}) {
    final rng = math.Random(nonce ?? math.Random().nextInt(0x7FFFFFFF));
    final postsK = 60.0 + rng.nextDouble() * 220.0;
    final tweetsM = 4.0 + rng.nextDouble() * 35.0;
    final dominance = 5 + rng.nextInt(28);
    final domDelta = -(1 + rng.nextInt(15));
    return MarketDetailData(
      kpis: <MarketKpi>[
        MarketKpi(
          id: 'posts',
          label: 'Total posts',
          value: '${postsK.toStringAsFixed(1)}K',
          sub: '24h',
          delta: '+${8 + rng.nextInt(50)}%',
          positive: true,
        ),
        MarketKpi(
          id: 'tweets',
          label: 'Total tweets',
          value: '${tweetsM.toStringAsFixed(1)}M',
          sub: '24h',
          delta: '+${5 + rng.nextInt(25)}%',
          positive: true,
        ),
        MarketKpi(
          id: 'dominance',
          label: 'Dominance',
          value: '$dominance%',
          sub: '24h',
          delta: '$domDelta%',
          positive: false,
        ),
        MarketKpi(
          id: 'activity',
          label: 'Activity',
          value: const ['Low', 'Medium', 'High', 'Very high'][rng.nextInt(4)],
          sub: 'Currently',
          delta: '',
          positive: true,
        ),
      ],
      sources: <MarketSourceSegment>[
        MarketSourceSegment(
          name: 'News',
          fraction: 0.55 + rng.nextDouble() * 0.25,
          colorName: 'green',
        ),
        MarketSourceSegment(
          name: 'Chats',
          fraction: 0.10 + rng.nextDouble() * 0.20,
          colorName: 'amber',
        ),
        MarketSourceSegment(
          name: 'Social',
          fraction: 0.05 + rng.nextDouble() * 0.15,
          colorName: 'red',
        ),
      ],
      trend: <MarketTrendPoint>[
        for (var i = 0; i < 7; i++)
          MarketTrendPoint(
            label: 'D${i + 1}',
            value: 3000 + (i * 1500) + rng.nextInt(1500).toDouble(),
          ),
      ],
      trendYMax: 25000,
      topics: <MarketTopic>[
        for (var i = 0; i < 5; i++)
          MarketTopic(
            label: const ['Brand', 'Campaign', 'Influencer', 'Launch', 'Trend']
                [i],
            brand: const ['Lattafa', 'Nike', 'Dior', 'iPhone', 'TikTok'][i],
            change: '+${5 + rng.nextInt(50)}%',
            positive: rng.nextBool(),
            points: generateFallbackSparkline(seed: rng.nextDouble()),
          ),
      ],
      brands: <MarketBrand>[
        for (var i = 0; i < 5; i++)
          MarketBrand(
            name: const ['Lattafa', 'Nike', 'Dior', 'Starbucks', 'Adidas'][i],
            growth: '+${10 + rng.nextInt(45)}%',
            positive: true,
            imageHint: const ['perfume', 'shoe', 'perfume', 'coffee', 'shoe']
                [i],
          ),
      ],
      events: <MarketEvent>[
        MarketEvent(
          title: 'Lattafa launch trending',
          subtitle: 'Mentions spiked 4x in the last hour.',
          time: '35m',
          status: 'Viral',
          statusColorName: 'amber',
        ),
        MarketEvent(
          title: 'iPhone chatter surge',
          subtitle: 'Negative sentiment dominates the launch thread.',
          time: '2h',
          status: 'Important',
          statusColorName: 'green',
        ),
        MarketEvent(
          title: 'Adidas collab pulled',
          subtitle: 'Quality concerns triggered a recall.',
          time: '4h',
          status: 'Banned',
          statusColorName: 'red',
        ),
      ],
    );
  }
}

/// Snapshot of the AI data currently held by the service.
@immutable
class HomeAiData {
  const HomeAiData({this.marketPulse, this.quickActions});
  final MarketPulseData? marketPulse;
  final QuickActionsData? quickActions;
}

/// Convenience helpers for callers that don't want to import the
/// config module directly.
class AiCapability {
  AiCapability._();

  static bool get isAvailable => OpenRouterConfig.isConfigured;
}
