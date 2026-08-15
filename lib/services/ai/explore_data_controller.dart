import 'dart:async';

import 'package:flutter/foundation.dart';

import 'ai_home_service.dart';
import 'explore_models.dart';

/// State of the explore data controller.
enum ExploreDataStatus { loading, ready, error }

@immutable
class ExploreDataState {
  const ExploreDataState({
    required this.status,
    this.data,
    this.lastError,
    this.lastUpdated,
  });

  final ExploreDataStatus status;
  final ExploreDetailData? data;
  final Object? lastError;
  final DateTime? lastUpdated;

  ExploreDataState copyWith({
    ExploreDataStatus? status,
    ExploreDetailData? data,
    Object? lastError,
    DateTime? lastUpdated,
    bool clearError = false,
  }) {
    return ExploreDataState(
      status: status ?? this.status,
      data: data ?? this.data,
      lastError: clearError ? null : (lastError ?? this.lastError),
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  static const ExploreDataState initial = ExploreDataState(
    status: ExploreDataStatus.ready,
  );
}

/// State controller for the AI-driven Explore screen.
/// Manual-only: no automatic fetch on mount, no periodic refresh.
/// Hydrates from in-memory cache; only hits the API when the user
/// explicitly triggers [refreshNow].
class ExploreDataController extends ChangeNotifier {
  ExploreDataController({
    AiHomeService? service,
  }) : _service = service ?? AiHomeService.instance;

  final AiHomeService _service;

  ExploreDataState _state = ExploreDataState.initial;
  ExploreDataState get state => _state;

  String? _language;
  String _region = 'Kuwait';
  bool _disposed = false;

  bool get isLoading => _state.status == ExploreDataStatus.loading;

  /// Hydrate from in-memory cache without hitting the network.
  /// Called once from `ExploreScreen.initState`.
  void bootstrap({required String language, String? region}) {
    _language = language;
    if (region != null) _region = region;
    final cached = _service.cachedExploreDetail;
    if (cached != null) {
      _updateState(_state.copyWith(
        status: ExploreDataStatus.ready,
        data: cached,
        lastUpdated: DateTime.now(),
        clearError: true,
      ));
    }
  }

  /// Force a fresh fetch. Safe to call from anywhere.
  Future<void> refreshNow({String? language, String? region}) async {
    if (_state.status == ExploreDataStatus.loading) return;
    final lang = language ?? _language ?? 'en';
    _language = lang;
    if (region != null) _region = region;

    _updateState(_state.copyWith(
      status: ExploreDataStatus.loading,
      clearError: true,
    ));

    try {
      final data = await _service.fetchExploreDetail(
        language: lang,
        region: _region,
        forceRefresh: true,
      );
      _updateState(_state.copyWith(
        status: ExploreDataStatus.ready,
        data: data,
        lastUpdated: DateTime.now(),
        clearError: true,
      ));
    } catch (e) {
      _updateState(_state.copyWith(
        status: ExploreDataStatus.error,
        lastError: e,
      ));
    }
  }

  void _updateState(ExploreDataState next) {
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
