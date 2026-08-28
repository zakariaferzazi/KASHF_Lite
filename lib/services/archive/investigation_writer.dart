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

  /// Removes every cached row for [userId]. Used by the
  /// destructive "delete all" actions exposed in the System
  /// Overview → Tools and Quick Actions sections. Implementations
  /// that have no local cache (e.g. the Firestore writer) should
  /// return 0 — Firestore deletes are routed through cloud-side
  /// rules and not driven from this interface.
  Future<int> clearAllForUser(String userId) async => 0;

  /// Removes a single row by id for [userId]. Used by the
  /// admin-only "delete one" affordance on the System Overview's
  /// investigations table. Returns `true` if the row was found
  /// and removed, `false` otherwise. Implementations MUST emit a
  /// fresh snapshot on their internal broadcast controller so
  /// every active watcher updates without a manual refresh.
  Future<bool> deleteOneForUser(String userId, String id) async => false;
}
