import 'dart:async';

import 'package:flutter/foundation.dart';

import 'news_service.dart';

/// Drives the Market Pulse "important events" list. Cycles
/// through a small set of [NewsTopic]s and pulls the top
/// article from each so the list always shows 3 distinct,
/// currently-trending stories.
///
/// Performance: the 3 topic fetches run in parallel (each caps
/// image-resolve at 1 article via `maxArticles: 1`) so a refresh
/// finishes in roughly the latency of a single topic fetch —
/// not 3× sequential.
///
/// State persistence is implicit — every fetch goes through
/// [NewsService.instance], which already caches its result on
/// disk via `DiskCache`. So the same articles are restored on
/// the next app launch even before any network call completes.
class MarketEventsController extends ChangeNotifier {
  MarketEventsController({NewsService? service})
      : _service = service ?? NewsService.instance;

  final NewsService _service;

  /// `null` when nothing has been fetched yet; `true` during a
  /// fetch; `false` after the first response (success or fail)
  /// arrives.
  bool? _loading;
  bool get isLoading => _loading ?? false;

  String _language = 'ar';
  String _country = 'KW';

  /// The 3 articles currently displayed. `null` until the first
  /// fetch resolves.
  List<NewsArticle>? _articles;
  List<NewsArticle> get articles => _articles ?? const [];

  /// Fetched at least once this session.
  bool get hasFetched => _articles != null;

  /// Topics we cycle through, top article each → 3 rows. Picked
  /// from the 4 curated verticals used across Home / Explore so
  /// the Market Pulse stays aligned with what the user can
  /// already drill into elsewhere.
  static const List<NewsTopic> _topics = <NewsTopic>[
    NewsTopic.fashion,
    NewsTopic.beauty,
    NewsTopic.fragrances,
  ];

  /// Picks a status badge for an article by sniffing the title
  /// for keywords like `launch` (Viral) or `ban` (Banned). The
  /// string keys are locale-independent — the UI layer maps them
  /// to a localised label via [AppLocalizations].
  static String classifyColorName(String title) {
    final t = title.toLowerCase();
    // Banned / recall / lawsuit / ban / fine / crackdown.
    const banned = <String>[
      'ban', 'banned', 'ban-', 'recall', 'recalled', 'lawsuit',
      'sued', 'fine', 'fined', 'penalty', 'crackdown', 'prohibit',
      'illegal', 'fraud', 'scandal', 'ban-', 'sanction',
    ];
    // Viral / launch / hot / trending / popular.
    const viral = <String>[
      'viral', 'launch', 'launches', 'launched', 'unveil', 'unveils',
      'unveiled', 'debut', 'rolls out', 'breaks', 'soars', 'surges',
      'trending', 'hot', 'hits', 'overtake', 'overtakes',
    ];
    for (final k in banned) {
      if (t.contains(k)) return 'red';
    }
    for (final k in viral) {
      if (t.contains(k)) return 'amber';
    }
    return 'green';
  }

  /// Kick off the first fetch. Cheap to call multiple times —
  /// concurrent calls are deduped.
  Future<void> bootstrap({
    required String language,
    required String country,
  }) async {
    _language = language;
    _country = country;

    // Hydrate from disk first so the user sees the last
    // successfully fetched articles immediately on launch. We
    // don't need to gate this on `_articles` being null — it's
    // already cheap (a few `SharedPreferences` reads).
    await _service.hydrateFromDisk(language: language, country: country);

    final prefill = <NewsArticle>[];
    for (final t in _topics) {
      final cached = _service.cacheFor(
        language: language,
        country: country,
        topic: t,
      );
      if (cached == null || cached.feed.articles.isEmpty) continue;
      prefill.add(cached.feed.articles.first);
    }
    if (prefill.isNotEmpty) {
      _articles = prefill.take(3).toList(growable: false);
      _loading = false;
      notifyListeners();
    }

    // If the cache already has all 3 slots filled, skip the
    // network entirely.
    if (_articles != null && _articles!.length >= 3) return;
    await refresh();
  }

  /// Force a fresh fetch of all 3 topic feeds.
  ///
  /// All 3 fetches run concurrently. Each `fetchTrending` call
  /// caps image-resolve at 1 article (`maxArticles: 1`) so the
  /// whole refresh is bounded by the slowest single topic —
  /// not 3× sequential.
  Future<void> refresh() async {
    if (_loading == true) return;
    _loading = true;
    notifyListeners();
    final results = await Future.wait(
      _topics.map((t) async {
        try {
          final feed = await _service.fetchTrending(
            language: _language,
            country: _country,
            topic: t,
            maxArticles: 1,
          );
          if (feed.articles.isNotEmpty) {
            return feed.articles.first;
          }
        } catch (e) {
          if (kDebugMode) {
            // ignore: avoid_print
            print('[MarketEvents] topic ${t.name} fetch failed: $e');
          }
        }
        return null;
      }),
    );
    final fresh = results.whereType<NewsArticle>().toList(growable: false);
    if (fresh.isNotEmpty) {
      _articles = fresh.take(3).toList(growable: false);
    }
    _articles ??= const [];
    _loading = false;
    notifyListeners();
  }
}