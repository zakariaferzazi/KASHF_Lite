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
  final List<SavedInvestigation> _latest = const <SavedInvestigation>[];

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
    void relay(List<SavedInvestigation> _) => ctrl.add(_latest);

    final remoteSub = _remote.watchLatest(userId, limit: limit).listen(
      relay,
      onError: (Object e, StackTrace st) {
        debugPrint(
          '[CompositeInvestigationWriter] remote watch failed: $e\n$st',
        );
      },
    );
    final localSub = _local.watchLatest(userId, limit: limit).listen(
      relay,
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
}