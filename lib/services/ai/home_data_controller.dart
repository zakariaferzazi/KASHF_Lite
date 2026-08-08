import 'dart:async';

import 'package:flutter/foundation.dart';

import 'ai_home_service.dart';
import 'ai_models.dart';

/// State of the home data controller. The Home screen reads this
/// to drive its loading / error / empty UI.
enum HomeDataStatus { loading, ready, error }

/// Immutable snapshot of the controller state. The UI listens for
/// new instances and rebuilds.
@immutable
class HomeDataState {
  const HomeDataState({
    required this.status,
    this.marketPulse,
    this.quickActions,
    this.lastError,
    this.lastUpdated,
  });

  final HomeDataStatus status;
  final MarketPulseData? marketPulse;
  final QuickActionsData? quickActions;
  final Object? lastError;
  final DateTime? lastUpdated;

  HomeDataState copyWith({
    HomeDataStatus? status,
    MarketPulseData? marketPulse,
    QuickActionsData? quickActions,
    Object? lastError,
    DateTime? lastUpdated,
    bool clearError = false,
  }) {
    return HomeDataState(
      status: status ?? this.status,
      marketPulse: marketPulse ?? this.marketPulse,
      quickActions: quickActions ?? this.quickActions,
      lastError: clearError ? null : (lastError ?? this.lastError),
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  static const HomeDataState initial = HomeDataState(
    status: HomeDataStatus.ready,
  );
}

/// State controller for the AI-driven Home screen data.
///
/// By design this controller is **manual-only**:
///   * No automatic refresh on startup.
///   * No periodic background refresh.
///   * The UI must call [refreshNow] (e.g. when the user taps the
///     refresh icon in the app bar or pull-to-refresh) to hit the
///     OpenRouter API.
///
/// This keeps the AI token usage tightly under user control — the
/// dashboard will not spend tokens every time the home tab is
/// mounted, the app is resumed, or the user navigates back.
///
/// Wraps [AiHomeService] with:
///   * In-memory cache hydration (no network call).
///   * Manual fetch with locale + region awareness.
///   * Loading / error / ready state for the UI.
///
/// Lifecycle: instantiate once in `initState`, dispose in
/// `dispose`. The class is a `ChangeNotifier` so any
/// `ListenableBuilder` / `AnimatedBuilder` can subscribe.
class HomeDataController extends ChangeNotifier {
  HomeDataController({
    AiHomeService? service,
  }) : _service = service ?? AiHomeService.instance;

  final AiHomeService _service;

  StreamSubscription<HomeAiData>? _streamSub;

  HomeDataState _state = HomeDataState.initial;
  HomeDataState get state => _state;

  String? _language;
  // Defaults to Kuwait — the primary market for the app. Callers
  // can override via [setRegion].
  String _region = 'Kuwait';
  bool _disposed = false;

  /// True while a manual refresh is in flight. The app bar
  /// refresh icon uses this to render a spinner.
  bool get isLoading => _state.status == HomeDataStatus.loading;

  /// Hydrate the controller from in-memory cache without hitting
  /// the network. Called once from `HomeScreen.initState`.
  /// If the cache is empty, the screen falls back to the
  /// localized demo data until the user requests a refresh.
  Future<void> bootstrap({
    required String language,
    String? region,
  }) async {
    _language = language;
    if (region != null) _region = region;

    final cachedPulse = _service.cachedMarketPulse;
    final cachedActions = _service.cachedQuickActions;
    if (cachedPulse != null || cachedActions != null) {
      _updateState(_state.copyWith(
        status: HomeDataStatus.ready,
        marketPulse: cachedPulse,
        quickActions: cachedActions,
        lastUpdated: DateTime.now(),
        clearError: true,
      ));
    }
  }

  /// Force a fresh fetch. Safe to call from anywhere — typically
  /// from the refresh icon in the app bar or pull-to-refresh.
  ///
  /// Only the Market Pulse section is AI-driven. The Quick
  /// Actions section renders hardcoded demo data and does not
  /// touch the API.
  Future<void> refreshNow({String? language, String? region}) async {
    if (_state.status == HomeDataStatus.loading) {
      // Already refreshing — don't double-fire.
      return;
    }
    final lang = language ?? _language ?? 'en';
    _language = lang;
    if (region != null) _region = region;

    _updateState(_state.copyWith(
      status: HomeDataStatus.loading,
      clearError: true,
    ));

    try {
      final data = await _service.fetchMarketPulse(
        language: lang,
        region: _region,
        forceRefresh: true,
      );
      _updateState(_state.copyWith(
        status: HomeDataStatus.ready,
        marketPulse: data,
        lastUpdated: DateTime.now(),
        clearError: true,
      ));
    } catch (e) {
      _updateState(_state.copyWith(
        status: HomeDataStatus.error,
        lastError: e,
      ));
    }
  }

  /// Update the user's region. Does NOT trigger a fetch on its
  /// own — the caller decides when to hit the API.
  void setRegion(String region) {
    if (region == _region) return;
    _region = region;
  }

  void _updateState(HomeDataState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _streamSub?.cancel();
    super.dispose();
  }
}
