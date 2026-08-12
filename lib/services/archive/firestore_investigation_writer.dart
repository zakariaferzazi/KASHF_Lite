import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../models/saved_investigation.dart';
import 'investigation_writer.dart';

/// Firestore-backed implementation of [InvestigationWriter].
///
/// Stores completed investigations under
/// `users/{uid}/investigations/{docId}` so each signed-in user keeps
/// their own private archive.
///
/// IMPORTANT — Firestore rules must explicitly allow reads +
/// writes on the `investigations` sub-collection. A rule that only
/// covers `match /users/{uid}` permits operations on the parent
/// document itself but NOT on its sub-collections, so the SDK
/// surfaces `[cloud_firestore/unknown] Unable to establish
/// connection on channel` (the Flutter shell translates the
/// permission-denied RPC failure into this generic message). Use
/// a wildcard match like the one below to grant each user
/// ownership of their own slice — and ONLY their own slice:
///
///   rules_version = '2';
///   service cloud.firestore {
///     match /databases/{database}/documents {
///       // Parent user document (lets the SDK create the user doc
///       // when first writing into a non-existent path).
///       match /users/{uid} {
///         allow read, write: if request.auth != null
///                             && request.auth.uid == uid;
///       }
///       // Every sub-collection under the user document,
///       // including `users/{uid}/investigations/{docId}`.
///       match /users/{uid}/{document=**} {
///         allow read, write: if request.auth != null
///                             && request.auth.uid == uid;
///       }
///     }
///   }
///
/// `watchLatest(userId, ...)` is implemented on top of
/// `CollectionReference.snapshots()` so the home screen's
/// Latest Investigations list updates immediately when a new run
/// finishes — no extra refresh trigger required.
///
/// All Firestore errors are surfaced via the writer's
/// `onError` channel (see [attach]) so callers can decide whether
/// to fall back to the local mirror.
class FirestoreInvestigationWriter implements InvestigationWriter {
  /// Copy-pasteable Firestore rules block required for this writer
  /// to function. The first `match /users/{uid}` lets the SDK
  /// auto-create the parent user document; the second `match`
  /// with the `{document=**}` wildcard is what permits reads +
  /// writes on the `investigations` sub-collection AND on every
  /// future sub-collection you might add under the user. Printed
  /// verbatim whenever a `permission-denied` error is observed so
  /// a developer can paste it into Firebase Console → Firestore →
  /// Rules without re-typing.
  static const String _kRequiredRulesSnippet = '''
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid} {
      allow read, write: if request.auth != null
                          && request.auth.uid == uid;
    }
    match /users/{uid}/{document=**} {
      allow read, write: if request.auth != null
                          && request.auth.uid == uid;
    }
  }
}''';
  FirestoreInvestigationWriter({
    FirebaseFirestore? firestore,
  }) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Maximum documents we accept per-user. Firestore doesn't need
  /// a hard cap but we mirror the local writer's value so the two
  /// stores stay roughly in sync.
  static const int _kCap = 60;

  /// Single broadcast controller that any number of watchers can
  /// listen on. We re-emit on every snapshot so subscribers see a
  /// fresh list (newest first, capped) without each one having to
  /// subscribe to Firestore independently.
  final StreamController<List<SavedInvestigation>> _watchCtrl =
      StreamController<List<SavedInvestigation>>.broadcast();

  /// Maps a per-user `StreamSubscription` so we can tear them down
  /// when [dispose] is called.
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
      _watchSubs = {};

  /// Cache of the latest snapshot per user, used to satisfy a
  /// watcher that subscribes after the first emission.
  final Map<String, List<SavedInvestigation>> _latestByUser = {};

  /// Hook for callers (e.g. the home screen) to observe Firestore
  /// errors that aren't tied to a single watcher. `null` until
  /// [attach] is called.
  void Function(Object error, StackTrace stack)? _onError;

  /// Subscribes the writer to a user's collection. Idempotent.
  ///
  /// [onError] is invoked for every Firestore error so the caller
  /// can decide whether to fall back to the local cache.
  void attach(String userId, {void Function(Object, StackTrace)? onError}) {
    _onError = onError;
    final sub = _userCol(userId)
        .orderBy('createdAt', descending: true)
        .limit(_kCap)
        .snapshots()
        .listen(
      (snap) {
        final items = snap.docs
            .map((d) => SavedInvestigation.fromFirestore({
                  'id': d.id,
                  ...d.data(),
                }))
            .toList();
        _latestByUser[userId] = items;
        _watchCtrl.add(items);
      },
      onError: (Object e, StackTrace st) {
        debugPrint('[FirestoreInvestigationWriter] watch error: $e\n$st');
        _onError?.call(e, st);
        // Re-emit whatever we last saw so watchers keep a list.
        final last = _latestByUser[userId] ?? const <SavedInvestigation>[];
        _watchCtrl.add(last);
      },
    );
    _watchSubs[userId] = sub;
  }

  CollectionReference<Map<String, dynamic>> _userCol(String userId) {
    return _db.collection('users').doc(userId).collection('investigations');
  }

  // ---------------------------------------------------------------------
  // InvestigationWriter API
  // ---------------------------------------------------------------------

  @override
  Future<void> save(SavedInvestigation item) async {
    try {
      // Ensure the parent `users/{uid}` document exists before we
      // try to write a sub-collection document. Without this, some
      // Firestore rule configurations reject the sub-collection
      // write with a generic "permission-denied" (which the Flutter
      // SDK surfaces as `[cloud_firestore/unknown] Unable to
      // establish connection on channel`). Errors here are
      // swallowed on purpose — the second attempt below is the one
      // that actually needs to succeed.
      await _ensureParentDoc(item.userId);
      await _userCol(item.userId).doc(item.documentId).set(item.toFirestore());
    } on Exception catch (e, st) {
      // Wrap with a hint so the developer can recognise the most
      // common cause (Firestore rules don't allow the write). The
      // composite writer will still swallow the error — this just
      // surfaces the root cause in the log output AND prints a
      // copy-pasteable rule the developer can paste into the
      // Firebase console to fix it.
      final msg = e.toString();
      if (msg.contains('Unable to establish connection on channel') ||
          msg.contains('permission-denied')) {
        debugPrint(
          '[FirestoreInvestigationWriter] save rejected for '
          'userId=${item.userId} docId=${item.documentId}.\n'
          'Most likely your Firestore rules do not allow writes on '
          'users/{uid}/investigations/{docId}. Paste this into '
          'Firebase Console → Firestore → Rules:\n'
          '$_kRequiredRulesSnippet\n'
          'Original error: $e\n$st',
        );
      }
      rethrow;
    }
  }

  /// Best-effort parent-doc upsert. Uses a low-cost [set] with an
  /// `updatedAt` timestamp so we don't have to read the doc first.
  /// Errors are intentionally swallowed: if rules block the parent
  /// write too, the subsequent sub-collection write will surface
  /// the real error.
  Future<void> _ensureParentDoc(String userId) async {
    try {
      await _db.collection('users').doc(userId).set(
        <String, dynamic>{
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Silent — see comment above.
    }
  }

  @override
  Stream<List<SavedInvestigation>> watchLatest(
    String userId, {
    int limit = 8,
  }) async* {
    // Make sure we're subscribed to this user so the broadcast
    // controller is fed fresh data.
    if (!_watchSubs.containsKey(userId)) {
      attach(userId);
    }
    // Seed the new subscriber with whatever we already know.
    final seed = _latestByUser[userId] ?? const <SavedInvestigation>[];
    yield seed.take(limit).toList();
    yield* _watchCtrl.stream.map(
      (all) => all.take(limit).toList(),
    );
  }

  @override
  Future<int> commitPendingForUser(String userId) async {
    // Firestore is the source of truth — nothing to flush.
    return 0;
  }

  /// Cancels the underlying Firestore listener and closes the
  /// broadcast controller. Safe to call multiple times.
  Future<void> dispose() async {
    for (final sub in _watchSubs.values) {
      await sub.cancel();
    }
    _watchSubs.clear();
    _latestByUser.clear();
    if (!_watchCtrl.isClosed) {
      await _watchCtrl.close();
    }
  }
}