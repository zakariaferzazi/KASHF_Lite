import 'dart:async';

import 'package:flutter/foundation.dart';

import 'ai_home_service.dart';
import 'market_models.dart';

/// State of the market data controller.
enum MarketDataStatus { loading, ready, error }

@immutable
class MarketDataState {
  const MarketDataState({
    required this.status,
    this.data,
    this.lastError,
    this.lastUpdated,
  });

  final MarketDataStatus status;
  final MarketDetailData? data;
  final Object? lastError;
  final DateTime? lastUpdated;

  MarketDataState copyWith({
    MarketDataStatus? status,
    MarketDetailData? data,
    Object? lastError,
    DateTime? lastUpdated,
    bool clearError = false,
  }) {
    return MarketDataState(
      status: status ?? this.status,
      data: data ?? this.data,
      lastError: clearError ? null : (lastError ?? this.lastError),
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  static const MarketDataState initial = MarketDataState(
    status: MarketDataStatus.ready,
  );
}

/// State controller for the AI-driven Market Pulse detail
/// screen. Like [HomeDataController] this is **manual-only**:
///   * No automatic fetch on mount.
///   * No periodic background refresh.
///   * Hydrates from in-memory cache; only hits the API when
///     the user explicitly triggers [refreshNow] (e.g. via
///     the refresh icon in the screen's top bar).
class MarketDataController extends ChangeNotifier {
  MarketDataController({
    AiHomeService? service,
  }) : _service = service ?? AiHomeService.instance;

  final AiHomeService _service;

  MarketDataState _state = MarketDataState.initial;
  MarketDataState get state => _state;

  String? _language;
  String _region = 'Kuwait';
  bool _disposed = false;

  bool get isLoading => _state.status == MarketDataStatus.loading;

  /// Hydrate from in-memory cache without hitting the network.
  /// Called once from `MarketScreen.initState`.
  void bootstrap({required String language, String? region}) {
    _language = language;
    if (region != null) _region = region;
    final cached = _service.cachedMarketDetail;
    if (cached != null) {
      _updateState(_state.copyWith(
        status: MarketDataStatus.ready,
        data: cached,
        lastUpdated: DateTime.now(),
        clearError: true,
      ));
    }
  }

  /// Force a fresh fetch. Safe to call from anywhere.
  Future<void> refreshNow({String? language, String? region}) async {
    if (_state.status == MarketDataStatus.loading) return;
    final lang = language ?? _language ?? 'en';
    _language = lang;
    if (region != null) _region = region;

    _updateState(_state.copyWith(
      status: MarketDataStatus.loading,
      clearError: true,
    ));

    try {
      final data = await _service.fetchMarketDetail(
        language: lang,
        region: _region,
        forceRefresh: true,
      );
      _updateState(_state.copyWith(
        status: MarketDataStatus.ready,
        data: data,
        lastUpdated: DateTime.now(),
        clearError: true,
      ));
    } catch (e) {
      _updateState(_state.copyWith(
        status: MarketDataStatus.error,
        lastError: e,
      ));
    }
  }

  void _updateState(MarketDataState next) {
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
