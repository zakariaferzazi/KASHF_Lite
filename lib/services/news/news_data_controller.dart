import 'package:flutter/foundation.dart';

import 'news_content_repository.dart';
import 'news_models.dart';
import 'news_service.dart';

/// Status of the news feed controller.
enum NewsStatus { idle, loading, ready, error, empty }

@immutable
class NewsState {
  const NewsState({
    required this.status,
    this.articles = const <NewsArticle>[],
    this.lastUpdated,
    this.lastError,
    this.topic,
  });

  final NewsStatus status;
  final List<NewsArticle> articles;
  final DateTime? lastUpdated;
  final Object? lastError;

  /// Currently selected topic. Articles belong to this topic.
  /// Can be a built-in [NewsTopic] or a user [CustomNewsTopic].
  final dynamic topic;

  NewsState copyWith({
    NewsStatus? status,
    List<NewsArticle>? articles,
    DateTime? lastUpdated,
    Object? lastError,
    dynamic topic,
    bool clearError = false,
  }) {
    return NewsState(
      status: status ?? this.status,
      articles: articles ?? this.articles,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      lastError: clearError ? null : (lastError ?? this.lastError),
      topic: topic ?? this.topic,
    );
  }

  static const NewsState initial = NewsState(status: NewsStatus.idle);
}

/// Cache-first state controller for the trending news carousel.
///
/// ## Why this changed
///
/// The previous version called `refreshNow` from every screen's
/// `initState`, which (combined with the heavy Google News
/// pipeline inside [NewsService.fetchTrending]) kept [NewsService]
/// running in the background on every navigation, draining CPU and
/// bandwidth and producing visible app lag.
///
/// The new contract is:
///
/// 1. [bootstrap] is the **only** call that should run on screen
///    mount. It hydrates from disk → Firestore synchronously so the
///    user sees previously-cached articles in a single frame, with
///    zero network calls.
/// 2. [refreshNow] still exists for the manual "refresh" button,
///    but internally it asks [NewsContentRepository] whether the
///    cached payload is older than 24 hours before doing any work.
///    The result: at most one background refresh per day, even
///    across many user sessions.
/// 3. The 24-hour gate is the **shared** policy used by Home,
///    Explore, Market, and the topic bottom sheets — they no
///    longer race each other to re-scrape Google News.
class NewsDataController extends ChangeNotifier {
  NewsDataController({
    NewsService? service,
    NewsContentRepository? repository,
  })  : _service = service ?? NewsService.instance,
        _repository = repository ?? NewsContentRepository.instance;

  final NewsService _service;
  final NewsContentRepository _repository;

  NewsState _state = NewsState.initial;
  NewsState get state => _state;

  bool get isLoading => _state.status == NewsStatus.loading;

  dynamic get topic => _state.topic;

  String? _language;
  String _country = 'US';
  bool _disposed = false;

  /// Hydrate from the local cache (disk + Firestore) without
  /// hitting the Google News pipeline. Safe to call from
  /// `ExploreScreen.initState` / `HomeScreen.initState`.
  ///
  /// If the cached payload is older than 24 hours a single
  /// background refresh is scheduled so the next user session sees
  /// fresh content, but the current frame still renders the
  /// existing articles immediately.
  Future<void> bootstrap({
    required String language,
    required String country,
    dynamic topic,
  }) async {
    _language = language;
    _country = country;
    _state = _state.copyWith(topic: topic, clearError: true);
    notifyListeners();

    // 1. Pull whatever we already have on disk / Firestore so the
    //    user sees cached articles in this frame. Hydration is
    //    cheap (~1 ms for SharedPreferences, ~200 ms for Firestore)
    //    and never triggers the heavy Google News scrape.
    if (topic is NewsTopic) {
      final cached = await _repository.readFeed(
        language: language,
        country: country,
        topic: topic,
      );
      if (_disposed) return;
      if (cached != null && cached.articles.isNotEmpty) {
        _updateState(_state.copyWith(
          status: NewsStatus.ready,
          articles: cached.articles,
          lastUpdated: cached.fetchedAt ?? DateTime.now(),
          clearError: true,
        ));
        // 2. Schedule a single background refresh only if the
        //    cached payload is older than the 24-hour window.
        //    Otherwise do nothing — the existing articles are
        //    still inside the freshness window.
        final needs = await _repository.needsRefresh(
          language: language,
          country: country,
          topic: topic,
        );
        if (!needs) return;
        // Defer to a microtask so we don't block the current
        // frame's UI on the in-flight fetch.
        Future.microtask(() {
          if (_disposed) return;
          refreshNow(
            language: language,
            country: country,
            topic: topic,
            forceRefresh: true,
          );
        });
        return;
      }
    } else {
      // Fallback for non-built-in topics: hydrate the legacy
      // service cache (still cheap, no network).
      await _service.hydrateFromDisk(language: language, country: country);
      final cached = _service.cacheFor(
        language: language,
        country: country,
        topic: topic,
      );
      if (cached != null && cached.feed.articles.isNotEmpty) {
        _updateState(_state.copyWith(
          status: NewsStatus.ready,
          articles: cached.feed.articles,
          lastUpdated: DateTime.now(),
          clearError: true,
        ));
        return;
      }
    }

    // 3. Nothing cached at all (first-ever launch on this
    //    device). Fall back to a one-shot network fetch so the
    //    user sees content. The repository will persist the
    //    result so subsequent launches stay cache-only.
    if (!_disposed) {
      // ignore: unawaited_futures
      refreshNow(
        language: language,
        country: country,
        topic: topic,
        forceRefresh: true,
      );
    }
  }

  /// Switches the active topic. Hydrates from cache
  /// synchronously, then fires a single background fetch — but
  /// ONLY when the cached payload is older than the 24-hour
  /// window. This prevents the controller from hammering
  /// Google News every time the user switches a chip.
  Future<void> setTopic(dynamic topic) async {
    if (topic == _state.topic) return;
    final lang = _language ?? 'en';
    final ctry = _country;
    _state = _state.copyWith(topic: topic, clearError: true);
    notifyListeners();

    if (topic is NewsTopic) {
      final cached = await _repository.readFeed(
        language: lang,
        country: ctry,
        topic: topic,
      );
      if (_disposed) return;
      if (cached != null && cached.articles.isNotEmpty) {
        _updateState(_state.copyWith(
          status: NewsStatus.ready,
          articles: cached.articles,
          lastUpdated: cached.fetchedAt ?? DateTime.now(),
          clearError: true,
        ));
        final needs = await _repository.needsRefresh(
          language: lang,
          country: ctry,
          topic: topic,
        );
        if (!needs) return;
      }
    } else {
      final cached = _service.cacheFor(
        language: lang,
        country: ctry,
        topic: topic,
      );
      if (cached != null && cached.feed.articles.isNotEmpty) {
        _updateState(_state.copyWith(
          status: NewsStatus.ready,
          articles: cached.feed.articles,
          lastUpdated: DateTime.now(),
          clearError: true,
        ));
      }
    }
    // ignore: unawaited_futures
    refreshNow(
      language: lang,
      country: ctry,
      topic: topic,
      forceRefresh: true,
    );
  }

  /// Force a fresh fetch. Used by the manual refresh button. The
  /// underlying [NewsService] still re-checks the 24-hour gate, so
  /// calling this multiple times in a row won't re-scrape Google
  /// News more than once per day.
  Future<void> refreshNow({
    String? language,
    String? country,
    dynamic topic,
    bool forceRefresh = false,
  }) async {
    if (_state.status == NewsStatus.loading) return;
    final lang = language ?? _language ?? 'en';
    final ctry = (country ?? _country).toUpperCase();
    final tp = topic ?? _state.topic;
    _language = lang;
    _country = ctry;

    _updateState(_state.copyWith(
      topic: tp,
      status: NewsStatus.loading,
      clearError: true,
    ));

    try {
      final feed = await _service.fetchTrending(
        language: lang,
        country: ctry,
        topic: tp,
        forceRefresh: forceRefresh,
      );
      if (_disposed) return;
      if (tp != _state.topic) return;
      if (feed.articles.isEmpty) {
        _updateState(_state.copyWith(
          status: NewsStatus.empty,
          lastUpdated: DateTime.now(),
        ));
      } else {
        _updateState(_state.copyWith(
          status: NewsStatus.ready,
          articles: feed.articles,
          lastUpdated: feed.fetchedAt ?? DateTime.now(),
          clearError: true,
        ));
      }
    } catch (e) {
      _updateState(_state.copyWith(
        status: NewsStatus.error,
        lastError: e,
      ));
    }
  }

  void _updateState(NewsState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}