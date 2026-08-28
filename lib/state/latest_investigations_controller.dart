import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/saved_investigation.dart';
import '../services/investigation_archive_service.dart';

/// Loads and exposes the most recent completed investigations for
/// the current user so the home screen's "Recent Updates" section
/// always reflects what's persisted in Firestore.
///
/// Subscribes to [InvestigationArchiveService.watchLatestFromFirestore]
/// on the first build (so the user only ever sees their
/// cloud-synced archive — local-only rows that haven't been
/// uploaded yet are intentionally hidden) and disposes the
/// subscription when the host widget is torn down. The list is
/// exposed read-only; rerender happens on every successful
/// stream emission.
class LatestInvestigationsController extends ChangeNotifier {
  LatestInvestigationsController({
    InvestigationArchiveService? archive,
    int limit = InvestigationArchiveService.kLatestLimit,
  })  : _archive = archive ?? InvestigationArchiveService.instance,
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
    // Pull the list directly from Firestore so the home screen's
    // "Recent Updates" section reflects the user's cloud-synced
    // archive — not transient local rows that may not yet be
    // uploaded. Returns an empty stream when the Firestore writer
    // hasn't been enabled yet, in which case the section stays
    // empty until Firebase boots.
    final source = _archive.watchLatestFromFirestore(limit: _limit);
    _sub = source.listen(
      (list) {
        // Defensive dedup by id. Firestore guarantees one doc per
        // id inside a collection, but the upstream broadcast stream
        // can re-emit the same snapshot multiple times in quick
        // succession (e.g. when the Firestore listener re-attaches
        // on auth state change, or when the home tab is rebuilt and
        // a new LatestInvestigationsController subscribes while the
        // previous one is still tearing down). Without dedup the
        // picker and the Recent Updates list would render the same
        // row twice — which is exactly what the admin reported when
        // generating reel/podcast scripts. Newest-first order is
        // preserved by iterating the source list in order; we keep
        // the first occurrence we see for any given id.
        final byId = <String, SavedInvestigation>{};
        for (final item in list) {
          byId.putIfAbsent(item.id, () => item);
        }
        _items = List<SavedInvestigation>.unmodifiable(byId.values);
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
