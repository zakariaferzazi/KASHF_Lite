import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/saved_investigation.dart';
import '../services/investigation_archive_service.dart';

/// Loads and exposes the most recent completed investigations for
/// the current user so the home screen's "Latest Investigations"
/// section always reflects the latest Firestore state.
///
/// Subscribes to [InvestigationArchiveService.watchLatest] on the
/// first build and disposes the subscription when the host widget
/// is torn down. The list is exposed read-only; rerender happens
/// on every successful stream emission.
class LatestInvestigationsController extends ChangeNotifier {
  LatestInvestigationsController({
    InvestigationArchiveService? archive,
    int limit = InvestigationArchiveService.kLatestLimit,
  })  : _archive = archive ?? InvestigationArchiveService(),
        _limit = limit {
    _subscribe();
  }

  final InvestigationArchiveService _archive;
  final int _limit;
  StreamSubscription<List<SavedInvestigation>>? _sub;

  List<SavedInvestigation> _items = const <SavedInvestigation>[];
  bool _isLoading = true;
  Object? _error;

  /// Read-only snapshot of the most recent investigations (newest
  /// first). The list is always non-null but may be empty while
  /// the stream is still loading.
  List<SavedInvestigation> get items => _items;
  bool get isLoading => _isLoading;
  Object? get error => _error;

  void _subscribe() {
    _isLoading = true;
    _error = null;
    notifyListeners();
    _sub = _archive.watchLatest(limit: _limit).listen(
      (list) {
        _items = List<SavedInvestigation>.unmodifiable(list);
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (Object e, StackTrace st) {
        _isLoading = false;
        _error = e;
        notifyListeners();
      },
    );
  }

  /// Forces a re-subscription. Useful when the user signs in
  /// (auth state changes) or pulls to refresh.
  Future<void> refresh() async {
    await _sub?.cancel();
    _subscribe();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
