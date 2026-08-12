import 'dart:async';

import 'package:flutter/foundation.dart';

import 'news_content_repository.dart';
import 'news_service.dart';

/// Drives the Market Pulse "important events" list. Cycles
/// through a small set of [NewsTopic]s and pulls the top
/// article from each so the list always shows 3 distinct,
/// currently-trending stories.
///
/// ## Performance contract
///
/// The 3 topic fetches run in parallel (each caps image-resolve at
/// 1 article via `maxArticles: 1`) so a refresh finishes in roughly
/// the latency of a single topic fetch — not 3× sequential.
///
/// All fetches go through [NewsContentRepository], which gates
/// writes behind a 24-hour window. The result: at most one
/// background Google News scrape per day, regardless of how many
/// times the user opens the market screen or navigates between
/// tabs. Hydration from disk + Firestore keeps the screen instant
/// on every launch.
class MarketEventsController extends ChangeNotifier {
  MarketEventsController({
    NewsService? service,
    NewsContentRepository? repository,
  })  : _service = service ?? NewsService.instance,
        _repository = repository ?? NewsContentRepository.instance;

  final NewsService _service;
  final NewsContentRepository _repository;

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

  /// Hydrate from cache first; schedule a single background
  /// refresh only if the cached payload is older than 24 hours.
  /// Cheap to call multiple times — concurrent calls are deduped
  /// via [_loading].
  Future<void> bootstrap({
    required String language,
    required String country,
  }) async {
    _language = language;
    _country = country;

    // 1. Hydrate from cache (disk + Firestore) so the user sees
    //    the last successfully fetched articles immediately. No
    //    network calls go to Google News from this branch.
    final prefill = <NewsArticle>[];
    bool needsBackgroundRefresh = false;
    for (final t in _topics) {
      final cached = await _repository.readFeed(
        language: language,
        country: country,
        topic: t,
      );
      if (cached == null || cached.articles.isEmpty) {
        needsBackgroundRefresh = true;
        continue;
      }
      prefill.add(cached.articles.first);
      final stale = await _repository.needsRefresh(
        language: language,
        country: country,
        topic: t,
      );
      if (stale) needsBackgroundRefresh = true;
    }
    if (prefill.isNotEmpty) {
      _articles = prefill.take(3).toList(growable: false);
      _loading = false;
      notifyListeners();
    }

    // 2. If every cached slot was empty OR at least one is older
    //    than 24 hours, run a single background refresh. Otherwise
    //    do nothing — the cached payload is still inside the
    //    freshness window.
    if (!needsBackgroundRefresh && _articles != null && _articles!.length >= 3) {
      return;
    }
    // Defer to a microtask so the existing cached UI can paint
    // first.
    Future.microtask(refresh);
  }

  /// Force a fresh fetch of all 3 topic feeds.
  ///
  /// All 3 fetches run concurrently. Each `fetchTrending` call
  /// caps image-resolve at 1 article (`maxArticles: 1`) so the
  /// whole refresh is bounded by the slowest single topic —
  /// not 3× sequential. The underlying [NewsService] still
  /// respects the 24-hour gate, so calling this multiple times in
  /// a row will not trigger more than one Google News scrape per
  /// day.
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