import '../../models/saved_investigation.dart';

/// Pluggable persistence backend for the Latest Investigations
/// archive. The local (SharedPreferences) implementation is used
/// by default; a Firestore-backed implementation swaps in without
/// any caller-side changes when the cloud_firestore package is
/// added to the project.
///
/// Keeping the interface tiny on purpose — the home screen only
/// needs `save(...)` and a stream of "latest".
abstract class InvestigationWriter {
  /// Persists [item]. Idempotent: re-saving the same id is safe.
  Future<void> save(SavedInvestigation item);

  /// Streams the newest [limit] items for [userId], newest first.
  /// Emits at least once with whatever is currently cached.
  Stream<List<SavedInvestigation>> watchLatest(String userId, {int limit});

  /// Flushes any locally-cached "anonymous" rows into [userId].
  /// Returns the number of documents actually written remotely.
  Future<int> commitPendingForUser(String userId);
}
