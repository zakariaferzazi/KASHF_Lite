import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../news/news_content_repository.dart';
import '../settings_preferences.dart';
import 'ai_models.dart';
import 'ai_parser.dart';
import 'ai_prompts.dart';
import 'disk_cache.dart';
import 'explore_models.dart';
import 'explore_parser.dart';
export 'explore_models.dart' show ExploreStatusStyle;
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
    DiskCache? diskCache,
  })  : _client = client ?? OpenRouterClient.instance,
        _cacheTtl = cacheTtl,
        _disk = diskCache ?? _sharedDiskCache;

  static final AiHomeService instance = AiHomeService();

  final OpenRouterClient _client;
  final Duration _cacheTtl;
  DiskCache? _disk;

  /// Shared disk cache instance created lazily at app startup.
  /// Stored on a static so tests / multiple service instances
  /// share the same backing store.
  static DiskCache? _sharedDiskCache;

  MarketPulseData? _marketPulseCache;
  DateTime? _marketPulseCachedAt;
  String? _marketPulseModelId;
  QuickActionsData? _quickActionsCache;
  DateTime? _quickActionsCachedAt;
  String? _quickActionsModelId;
  MarketDetailData? _marketDetailCache;
  DateTime? _marketDetailCachedAt;
  String? _marketDetailModelId;
  ExploreDetailData? _exploreDetailCache;
  DateTime? _exploreDetailCachedAt;
  String? _exploreDetailModelId;

  /// Subscribed to SettingsPreferences.modelChangedStream. When the
  /// user picks a different model in Settings we immediately wipe
  /// every in-memory cache + matching disk entry so the next fetch
  /// goes to the new model. Without this listener, the 5-minute
  /// in-memory TTL would keep showing responses produced by the
  /// previous model.
  StreamSubscription<String>? _modelSub;

  final StreamController<HomeAiData> _controller =
      StreamController<HomeAiData>.broadcast();

  /// Live stream of the latest fully-populated AI data. Useful for
  /// the UI to subscribe once and rebuild on every successful
  /// refresh.
  Stream<HomeAiData> get stream => _controller.stream;

  MarketPulseData? get cachedMarketPulse => _marketPulseCache;
  MarketDetailData? get cachedMarketDetail => _marketDetailCache;
  QuickActionsData? get cachedQuickActions => _quickActionsCache;
  ExploreDetailData? get cachedExploreDetail => _exploreDetailCache;

  /// Wires the shared disk-cache used to persist AI payloads across
  /// app restarts. Called once from `main.dart` after
  /// [SharedPreferences] is ready.
  static void initDiskCache(DiskCache cache) {
    _sharedDiskCache = cache;
    // The static [instance] was built before the disk cache
    // existed; replace it so it sees the new dependency.
    // ignore: invalid_use_of_visible_for_testing_member
    instance._disk = cache;
    // Also hook the model-change subscription on the same static
    // instance so cache invalidation works regardless of which
    // instance the controllers happen to use.
    instance._subscribeToModelChanges();
  }

  /// Resolves the currently selected OpenRouter model id from the
  /// shared [SettingsPreferences] singleton. Returns an empty string
  /// when the prefs aren't initialised yet (e.g. early in a test)
  /// so cache-key derivation never throws.
  String _currentModelId() {
    final prefs = SettingsPreferences.instance;
    if (prefs == null) return '';
    return prefs.aiModelId;
  }

  void _subscribeToModelChanges() {
    _modelSub?.cancel();
    final prefs = SettingsPreferences.instance;
    if (prefs == null) return;
    _modelSub = prefs.modelChangedStream.listen((_) {
      // Clear everything cached under the OLD model so the next
      // fetch hits the new model.
      clearCache();
      _invalidateDiskCache();
      _emit();
    });
  }

  Future<void> _invalidateDiskCache() async {
    final disk = _disk;
    if (disk == null) return;
    // Drop every cached AI payload — the keys are model-scoped
    // (see [_diskKey]) but clearing all is simpler and avoids
    // leaking entries from the previous model when the disk cache
    // is shared across the home / explore / market screens.
    await disk.clearAll();
  }

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
    final modelId = _currentModelId();
    if (!forceRefresh &&
        _marketPulseCache != null &&
        _marketPulseCachedAt != null &&
        _marketPulseModelId == modelId &&
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
          model: OpenRouterConfig.model,
          temperature: 0.7,
          maxTokens: 1800,
          // No responseFormat: web search is permanently on (see
          // OpenRouterRequest default), and `response_format:
          // json_object` would silently disable the tool call.
          extra: {'seed': nonce},
        ),
      );
      final data = AiParser.parseMarketPulse(json);
      _marketPulseCache = data;
      _marketPulseCachedAt = DateTime.now();
      _marketPulseModelId = modelId;
      _persist('market_pulse', language, region, modelId, json);
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
      _marketPulseModelId = modelId;
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
    final modelId = _currentModelId();
    if (!forceRefresh &&
        _quickActionsCache != null &&
        _quickActionsCachedAt != null &&
        _quickActionsModelId == modelId &&
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
          model: OpenRouterConfig.model,
          temperature: 0.8,
          maxTokens: 2500,
          // No responseFormat: web search is permanently on (see
          // OpenRouterRequest default), and `response_format:
          // json_object` would silently disable the tool call.
          extra: {'seed': nonce},
        ),
      );
      final data = AiParser.parseQuickActions(json);
      _quickActionsCache = data;
      _quickActionsCachedAt = DateTime.now();
      _quickActionsModelId = modelId;
      _persist('quick_actions', language, region, modelId, json);
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
      _quickActionsModelId = modelId;
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
    final modelId = _currentModelId();
    if (!forceRefresh &&
        _marketDetailCache != null &&
        _marketDetailCachedAt != null &&
        _marketDetailModelId == modelId &&
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
          model: OpenRouterConfig.model,
          temperature: 0.7,
          maxTokens: 3000,
          // No responseFormat: web search is permanently on (see
          // OpenRouterRequest default), and `response_format:
          // json_object` would silently disable the tool call.
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
      _marketDetailModelId = modelId;
      _persist('market_detail', language, region, modelId, json);
      return data;
    } catch (e, st) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[AiHomeService] fetchMarketDetail failed: $e\n$st');
      }
      final fallback = _buildFallbackMarketDetail(nonce: _newNonce());
      _marketDetailCache = fallback;
      _marketDetailCachedAt = DateTime.now();
      _marketDetailModelId = modelId;
      return fallback;
    }
  }

  /// Fetches the Explore screen payload (trending, discover, recent).
  /// Cached in memory for [_cacheTtl] and falls back to demo values.
  Future<ExploreDetailData> fetchExploreDetail({
    required String language,
    String region = 'Kuwait',
    bool forceRefresh = false,
  }) async {
    final modelId = _currentModelId();
    if (!forceRefresh &&
        _exploreDetailCache != null &&
        _exploreDetailCachedAt != null &&
        _exploreDetailModelId == modelId &&
        DateTime.now().difference(_exploreDetailCachedAt!) < _cacheTtl) {
      return _exploreDetailCache!;
    }

    try {
      final nonce = _newNonce();
      final messages = AiPrompts.exploreDetailMessages(
        language: language,
        region: region,
        nonce: nonce,
      );
      final json = await _client.chatCompletionJson(
        OpenRouterRequest(
          messages: messages,
          model: OpenRouterConfig.model,
          temperature: 0.7,
          maxTokens: 2500,
          // No responseFormat: web search is permanently on (see
          // OpenRouterRequest default), and `response_format:
          // json_object` would silently disable the tool call.
          extra: {'seed': nonce},
        ),
      );
      final data = ExploreParser.parse(json);
      _exploreDetailCache = data;
      _exploreDetailCachedAt = DateTime.now();
      _exploreDetailModelId = modelId;
      _persist('explore_detail', language, region, modelId, json);
      return data;
    } catch (e, st) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[AiHomeService] fetchExploreDetail failed: $e\n$st');
      }
      final fallback = _buildFallbackExploreDetail(nonce: _newNonce());
      _exploreDetailCache = fallback;
      _exploreDetailCachedAt = DateTime.now();
      _exploreDetailModelId = modelId;
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
  /// out. Always clears the per-fetch model id too so the next
  /// fetch can't accidentally return a stale payload from a
  /// different model.
  void clearCache() {
    _marketPulseCache = null;
    _marketPulseCachedAt = null;
    _marketPulseModelId = null;
    _quickActionsCache = null;
    _quickActionsCachedAt = null;
    _quickActionsModelId = null;
    _marketDetailCache = null;
    _marketDetailCachedAt = null;
    _marketDetailModelId = null;
    _exploreDetailCache = null;
    _exploreDetailCachedAt = null;
    _exploreDetailModelId = null;
  }

  Future<void> dispose() async {
    await _modelSub?.cancel();
    await _controller.close();
  }

  void _emit() {
    _controller.add(HomeAiData(
      marketPulse: _marketPulseCache,
      quickActions: _quickActionsCache,
    ));
  }

  // ---------- Disk persistence ----------

  /// Persist a successful AI response to disk so the same payload
  /// can be replayed on the next app launch. The key is scoped to
  /// the model that produced it so the user can't see data from a
  /// previous model after switching in Settings.
  ///
  /// Also mirrors the payload into [NewsContentRepository], which
  /// stores it in Firestore under the shared 24-hour refresh
  /// window. The repository is the single source of truth that
  /// prevents the AI pipeline from being invoked more than once
  /// per 24 hours per (locale, region, screen) tuple.
  void _persist(
    String kind,
    String language,
    String region,
    String modelId,
    Map<String, dynamic> json,
  ) {
    final disk = _disk;
    if (disk == null) return;
    final key = _diskKey(kind, language, region, modelId);
    // Fire-and-forget; we never await this on the request path.
    // ignore: unawaited_futures
    disk.writeJson(key, json);
    final aiKind = _aiKindFor(kind);
    if (aiKind != null) {
      // ignore: unawaited_futures
      NewsContentRepository.instance.writeAiContent(
        kind: aiKind,
        language: language,
        region: region,
        payload: json,
      );
    }
  }

  /// Maps the legacy AI cache "kind" string to the
  /// [AiContentKind] enum used by [NewsContentRepository]. Returns
  /// `null` for kinds we do not mirror into Firestore (the older
  /// "quick_actions" payload, for example, is local-only because
  /// it is regenerated with demo data on the fly).
  AiContentKind? _aiKindFor(String kind) {
    switch (kind) {
      case 'market_pulse':
        return AiContentKind.homeMarketPulse;
      case 'market_detail':
        return AiContentKind.marketDetail;
      case 'explore_detail':
        return AiContentKind.exploreDetail;
      default:
        return null;
    }
  }

  /// Builds the on-disk cache key for an AI payload. Includes the
  /// model id so payloads from different models never collide.
  String _diskKey(
    String kind,
    String language,
    String region,
    String modelId,
  ) {
    return '$kind|$language|${region.toLowerCase()}|$modelId';
  }

  /// Hydrate all four AI caches from disk on app startup. Called
  /// once during `HomeDataController.bootstrap` (and similarly by
  /// the Market / Explore controllers) so the user sees their
  /// recently-fetched data immediately after a restart, without
  /// burning API tokens. Each cache entry is keyed on the model
  /// that produced it so a model switch in Settings wipes the
  /// visible cache automatically.
  ///
  /// Falls back to Firestore (via [NewsContentRepository]) when the
  /// local disk slot is empty — this is what lets the Market Pulse
  /// panel and Market screen survive an app reinstall / cache
  /// wipe / model-id mismatch. The Firestore payload is written
  /// back to disk on the way through so subsequent launches are
  /// instant again.
  Future<void> hydrateFromDisk({
    required String language,
    String region = 'Kuwait',
  }) async {
    final disk = _disk;
    if (disk == null) return;

    final modelId = _currentModelId();

    Future<void> tryHydrate(
      String kind,
      Future<void> Function(Map<String, dynamic>) apply,
    ) async {
      final key = _diskKey(kind, language, region, modelId);
      var raw = await disk.readJson(key);
      if (raw == null) {
        // Disk miss → ask the Firestore-backed repository. It
        // mirrors its own disk slot under a different prefix, so
        // a fresh install (empty local prefs) still finds the
        // last-known-good AI payload.
        final aiKind = _aiKindFor(kind);
        if (aiKind != null) {
          raw = await NewsContentRepository.instance.readAiContent(
            kind: aiKind,
            language: language,
            region: region,
          );
        }
      }
      if (raw == null) return;
      try {
        await apply(raw);
      } catch (e) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('[AiHomeService] hydrate $kind failed: $e');
        }
      }
    }

    await tryHydrate('market_pulse', (json) async {
      _marketPulseCache = AiParser.parseMarketPulse(json);
      _marketPulseCachedAt = DateTime.now();
      _marketPulseModelId = modelId;
    });
    await tryHydrate('quick_actions', (json) async {
      _quickActionsCache = AiParser.parseQuickActions(json);
      _quickActionsCachedAt = DateTime.now();
      _quickActionsModelId = modelId;
    });
    await tryHydrate('market_detail', (json) async {
      _marketDetailCache = MarketParser.parse(json);
      _marketDetailCachedAt = DateTime.now();
      _marketDetailModelId = modelId;
    });
    await tryHydrate('explore_detail', (json) async {
      _exploreDetailCache = ExploreParser.parse(json);
      _exploreDetailCachedAt = DateTime.now();
      _exploreDetailModelId = modelId;
    });

    _emit();
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

  ExploreDetailData _buildFallbackExploreDetail({int? nonce}) {
    return ExploreDetailData(
      trending: <ExploreTrendingItem>[
        ExploreTrendingItem(
          titleEn: 'Commodity analysis',
          titleAr: 'تحليل السلع',
          subtitleEn: 'Gold and oil',
          subtitleAr: 'الذهب والنفط',
          imageHint: 'winner',
          category: 'markets',
        ),
        ExploreTrendingItem(
          titleEn: 'Market news',
          titleAr: 'أخبار السوق',
          subtitleEn: 'Top economic headlines',
          subtitleAr: 'أبرز العناوين الاقتصادية',
          imageHint: 'sauvage',
          category: 'markets',
        ),
        ExploreTrendingItem(
          titleEn: 'Investor portfolio',
          titleAr: 'محفظة المستثمر',
          subtitleEn: 'Risk and reward management',
          subtitleAr: 'إدارة المخاطر والعوائد',
          imageHint: 'mic',
          category: 'products',
        ),
        ExploreTrendingItem(
          titleEn: 'Highest influencer',
          titleAr: 'أعلى المؤثرين',
          subtitleEn: 'Top of the year',
          subtitleAr: 'لعام كامل',
          imageHint: 'borge',
          category: 'influencers',
        ),
      ],
      discover: <ExploreDiscoverItem>[
        ExploreDiscoverItem(
          type: 'companies',
          titleEn: 'Discover Companies',
          titleAr: 'اكتشف الشركات',
          subtitleEn: 'Browse brands & firms',
          subtitleAr: 'تصفح العلامات التجارية',
        ),
        ExploreDiscoverItem(
          type: 'products',
          titleEn: 'Discover Products',
          titleAr: 'اكتشف المنتجات',
          subtitleEn: 'Track product launches',
          subtitleAr: 'تتبع إصدارات المنتجات',
        ),
        ExploreDiscoverItem(
          type: 'influencers',
          titleEn: 'Discover Influencers',
          titleAr: 'اكتشف المؤثرين',
          subtitleEn: 'Find top creators',
          subtitleAr: 'ابحث عن أبرز المؤثرين',
        ),
        ExploreDiscoverItem(
          type: 'reports',
          titleEn: 'Discover Reports',
          titleAr: 'اكتشف التقارير',
          subtitleEn: 'Read market reports',
          subtitleAr: 'اقرأ تقارير السوق',
        ),
      ],
      recent: <ExploreRecentItem>[
        ExploreRecentItem(
          titleEn: 'Lattafa Asad Analysis',
          titleAr: 'تحليل عطر عطر أسد',
          subtitleEn: 'Perfume market share',
          subtitleAr: 'حصة سوق العطور',
          time: '2h',
          statusLabelEn: 'Completed',
          statusLabelAr: 'مكتمل',
          statusStyle: ExploreStatusStyle.completed,
          imageHint: 'parfum',
          brandDomain: null,
        ),
        ExploreRecentItem(
          titleEn: 'Dior Sauvage Trend',
          titleAr: 'اتجاه ديور سافاج',
          subtitleEn: 'Social media buzz',
          subtitleAr: 'التفاعل على وسائل التواصل',
          time: '5h',
          statusLabelEn: 'Quick Answer',
          statusLabelAr: 'إجابة سريعة',
          statusStyle: ExploreStatusStyle.quickAnswer,
          imageHint: 'sauvage',
          brandDomain: null,
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
