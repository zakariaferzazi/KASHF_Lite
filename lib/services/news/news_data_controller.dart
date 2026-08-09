import 'package:flutter/foundation.dart';

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
  final NewsTopic? topic;

  NewsState copyWith({
    NewsStatus? status,
    List<NewsArticle>? articles,
    DateTime? lastUpdated,
    Object? lastError,
    NewsTopic? topic,
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

/// Manual-only state controller for the trending news carousel.
///
/// Like [HomeDataController] / [MarketDataController] this does
/// NOT auto-refresh on mount. The screen calls [bootstrap] from
/// its `initState` to hydrate from cache, and [refreshNow] when
/// the user taps the refresh button.
///
/// When the [topic] changes via [setTopic], the controller
/// automatically fetches a new feed (or hydrates from the
/// per-topic cache if available).
class NewsDataController extends ChangeNotifier {
  NewsDataController({
    NewsService? service,
  }) : _service = service ?? NewsService.instance;

  final NewsService _service;

  NewsState _state = NewsState.initial;
  NewsState get state => _state;

  bool get isLoading => _state.status == NewsStatus.loading;

  NewsTopic? get topic => _state.topic;

  String? _language;
  String _country = 'US';
  bool _disposed = false;

  /// Hydrate from the in-memory cache without hitting the network.
  /// Called from `ExploreScreen.initState`.
  Future<void> bootstrap({
    required String language,
    required String country,
    NewsTopic? topic,
  }) async {
    _language = language;
    _country = country;
    // Hydrate the underlying service from disk so cross-restart
    // data is replayed before we look at the in-memory cache.
    await _service.hydrateFromDisk(
      language: language,
      country: country,
    );
    final cached = _service.cacheFor(
      language: language,
      country: country,
      topic: topic,
    );
    _updateState(_state.copyWith(topic: topic));
    if (cached != null) {
      _updateState(_state.copyWith(
        status: cached.feed.articles.isEmpty
            ? NewsStatus.empty
            : NewsStatus.ready,
        articles: cached.feed.articles,
        lastUpdated: DateTime.now(),
        clearError: true,
      ));
    }
  }

  /// Switches the active topic. Hydrates from cache
  /// synchronously, then fires a fresh fetch in the background
  /// (unless the cache was already fresh within [_fetchThreshold]).
  Future<void> setTopic(NewsTopic? topic) async {
    if (topic == _state.topic) return;
    final lang = _language ?? 'en';
    final ctry = _country;
    final cached = _service.cacheFor(
      language: lang,
      country: ctry,
      topic: topic,
    );
    _updateState(_state.copyWith(
      topic: topic,
      articles: cached?.feed.articles ?? const <NewsArticle>[],
      status: cached != null
          ? (cached.feed.articles.isEmpty
              ? NewsStatus.empty
              : NewsStatus.ready)
          : NewsStatus.idle,
      clearError: true,
    ));
    await refreshNow(topic: topic);
  }

  /// Force a fresh fetch.
  Future<void> refreshNow({
    String? language,
    String? country,
    NewsTopic? topic,
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
        forceRefresh: true,
      );
      if (_disposed) return;
      // Ignore stale responses (topic may have changed again).
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
          lastUpdated: DateTime.now(),
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