import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/saved_investigation.dart';
import 'firestore_investigation_writer.dart';
import 'investigation_writer.dart';
import 'local_investigation_writer.dart';

/// Composite [InvestigationWriter] that mirrors every write to both
/// the offline [LocalInvestigationWriter] (SharedPreferences) and the
/// remote [FirestoreInvestigationWriter] (Cloud Firestore).
///
/// `save(...)` writes to the local mirror FIRST (so the home screen
/// can render the new card immediately, even when the network is
/// down) and then fans out to Firestore in the background. A
/// failure on the remote side is logged and swallowed — the local
/// mirror always wins as the source of truth for the current
/// session.
///
/// `watchLatest(...)` prefers the Firestore subscription (so the home
/// list reflects remote changes from other devices), and merges in
/// the local stream so the UI keeps showing the latest local write
/// until the remote snapshot lands. This mirrors the way a normal
/// "cache + network" read pattern works in offline-first apps.
class CompositeInvestigationWriter implements InvestigationWriter {
  CompositeInvestigationWriter({
    required LocalInvestigationWriter local,
    required FirestoreInvestigationWriter remote,
  })  : _local = local,
        _remote = remote;

  final LocalInvestigationWriter _local;
  final FirestoreInvestigationWriter _remote;

  /// Most recent snapshot we've seen from either source. Yielded
  /// whenever either stream re-emits so the consumer always sees
  /// fresh data without gaps between sources.
  List<SavedInvestigation> _latest = const <SavedInvestigation>[];

  /// Tracks the most recent value from each source so we can
  /// emit the union (deduped, newest-first) on every relay tick.
  /// Without this, the controller would race and stale snapshots
  /// could overwrite fresher ones.
  List<SavedInvestigation> _localLatest = const <SavedInvestigation>[];
  List<SavedInvestigation> _remoteLatest = const <SavedInvestigation>[];

  /// Builds the merged, deduped, newest-first list used by
  /// `relay`. `id` is the natural key — duplicate ids prefer the
  /// remote copy (which carries the latest server timestamp).
  ///
  /// Each input list is also deduped internally. Without that
  /// step, if either source emitted the same snapshot twice in
  /// quick succession (Firestore re-attaching on auth tick, local
  /// cache re-flush) the merged list would carry the duplicate
  /// forward and the home screen would render the same row
  /// twice — which is what the admin reported when generating
  /// reel/podcast scripts.
  List<SavedInvestigation> _merge(
    List<SavedInvestigation> local,
    List<SavedInvestigation> remote,
  ) {
    final remoteById = <String, SavedInvestigation>{
      for (final r in remote) r.id: r,
    };
    final localById = <String, SavedInvestigation>{
      for (final l in local) l.id: l,
    };
    final byId = <String, SavedInvestigation>{};
    for (final r in remoteById.values) {
      byId[r.id] = r;
    }
    for (final l in localById.values) {
      byId.putIfAbsent(l.id, () => l);
    }
    final merged = byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List<SavedInvestigation>.unmodifiable(merged);
  }

  /// Identity check used to suppress identical re-emissions from
  /// `relay`. Compares by id AND content fingerprint (title,
  /// confidence, createdAt) so a same-id update with new content
  /// still triggers a re-emit — otherwise the UI would render
  /// stale data after a remote-overwrites-local save. Items are
  /// already immutable so we just compare the relevant fields.
  bool _isSameSnapshot(List<SavedInvestigation> a, List<SavedInvestigation> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final x = a[i];
      final y = b[i];
      if (x.id != y.id) return false;
      if (x.title != y.title) return false;
      if (x.confidencePercent != y.confidencePercent) return false;
      if (x.confidenceBand != y.confidenceBand) return false;
      if (x.createdAt != y.createdAt) return false;
    }
    return true;
  }

  @override
  Future<void> save(SavedInvestigation item) async {
    // 1. Local first — keeps the home screen snappy and survives a
    //    failed remote write.
    try {
      await _local.save(item);
    } catch (e, st) {
      debugPrint('[CompositeInvestigationWriter] local save failed: $e\n$st');
    }
    // 2. Remote in the background — failures are logged but never
    //    propagated. The next reload will pick up the local copy
    //    even if Firestore rejects this one.
    unawaited(_remote.save(item).catchError((Object e, StackTrace st) {
      debugPrint('[CompositeInvestigationWriter] remote save failed: $e\n$st');
    }));
  }

  @override
  Stream<List<SavedInvestigation>> watchLatest(
    String userId, {
    int limit = 8,
  }) async* {
    // Open both subscriptions in parallel and re-yield whenever
    // either side has a fresh snapshot. Either stream may go silent
    // (Firestore offline, local cache cold), so we always emit the
    // last value we have rather than blocking on a single source.
    final ctrl = StreamController<List<SavedInvestigation>>();
    // Last emitted snapshot — used to short-circuit a no-op relay
    // tick so the controller doesn't re-render for an identical
    // list (the local + remote streams can both fire for the same
    // merged snapshot on a single save).
    List<SavedInvestigation> lastSnapshot = const <SavedInvestigation>[];
    void relay(List<SavedInvestigation> _) {
      // Always relay the most recent merged snapshot. The merged
      // list deduplicates by id (preferring the remote copy) and
      // is sorted newest-first so the home screen sees a stable,
      // up-to-date view across both sources.
      final merged = _merge(_localLatest, _remoteLatest);
      _latest = merged;
      // Skip identical re-emissions so a hot reload or a quick
      // re-subscribe doesn't show the same row twice. We compare
      // content (not just ids) so a same-id update with new
      // content still re-emits.
      if (_isSameSnapshot(lastSnapshot, merged)) return;
      lastSnapshot = merged;
      ctrl.add(merged.take(limit).toList());
    }

    final remoteSub = _remote.watchLatest(userId, limit: limit).listen(
      (snap) {
        _remoteLatest = snap;
        relay(snap);
      },
      onError: (Object e, StackTrace st) {
        debugPrint(
          '[CompositeInvestigationWriter] remote watch failed: $e\n$st',
        );
      },
    );
    final localSub = _local.watchLatest(userId, limit: limit).listen(
      (snap) {
        _localLatest = snap;
        relay(snap);
      },
      onError: (Object e, StackTrace st) {
        debugPrint(
          '[CompositeInvestigationWriter] local watch failed: $e\n$st',
        );
      },
    );

    ctrl.onCancel = () async {
      await remoteSub.cancel();
      await localSub.cancel();
    };

    yield* ctrl.stream;
  }

  @override
  Future<int> commitPendingForUser(String userId) async {
    // Flush any "anonymous" rows from the local mirror into Firestore.
    final flushed = await _local.commitPendingForUser(userId);
    return flushed;
  }

  @override
  Future<int> clearAllForUser(String userId) async {
    // Wipe both halves so the local cache AND the cloud archive
    // stay in sync after the destructive "delete all" flow.
    final localRemoved = await _local.clearAllForUser(userId);
    final remoteRemoved = await _remote.clearAllForUser(userId);
    return localRemoved + remoteRemoved;
  }

  /// Removes a single investigation by [id] from BOTH halves:
  ///   1. Remote first — the cloud is the source of truth for
  ///      the admin's investigations table, so a failed remote
  ///      delete should propagate up so the UI can show a snackbar.
  ///      We propagate the exception rather than swallowing so the
  ///      admin actually sees what went wrong.
  ///   2. Local mirror afterwards so the offline cache stays in
  ///      sync with the cloud. Local failures are logged but
  ///      swallowed — the next reload will reconcile.
  ///
  /// Returns `true` when the row was found in either store.
  @override
  Future<bool> deleteOneForUser(String userId, String id) async {
    bool removed = false;
    // 1. Cloud first (source of truth). Errors bubble up so the
    //    admin UI can render a real diagnostic.
    try {
      removed = await _remote.deleteOneForUser(userId, id);
    } catch (e, st) {
      debugPrint(
        '[CompositeInvestigationWriter] remote deleteOne failed '
        'for userId=$userId id=$id: $e\n$st',
      );
      rethrow;
    }
    // 2. Local mirror. Best-effort — failures here don't undo the
    //    remote delete, they just delay the local reconciliation.
    try {
      final localRemoved = await _local.deleteOneForUser(userId, id);
      removed = removed || localRemoved;
    } catch (e, st) {
      debugPrint(
        '[CompositeInvestigationWriter] local deleteOne failed '
        'for userId=$userId id=$id: $e\n$st',
      );
    }
    return removed;
  }
}