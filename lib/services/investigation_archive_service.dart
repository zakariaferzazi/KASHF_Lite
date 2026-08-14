import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

import '../models/entity_type.dart';
import '../models/investigation.dart';
import '../models/investigation_result.dart';
import '../models/saved_investigation.dart';
import 'ai/openrouter_config.dart';
import 'archive/composite_investigation_writer.dart';
import 'archive/firestore_investigation_writer.dart';
import 'archive/investigation_writer.dart';
import 'archive/local_investigation_writer.dart';
import 'auth_service.dart';

/// Persists completed investigations and exposes the "latest"
/// feed to the Home screen's "Latest Investigations" section.
///
/// Storage architecture:
///   * The default writer is a CompositeInvestigationWriter that
///     fans every save out to BOTH a local SharedPreferences mirror
///     AND a Firestore writer keyed on the signed-in user's uid.
///   * If Firestore isn't available (no cloud_firestore package,
///     no signed-in user, etc.) the service transparently falls back
///     to the local-only writer so the home section never goes blank.
///
/// Failure modes are non-fatal: every write also goes through the
/// local writer first so the home section always has data to show,
/// even on a brand-new install with no network.
///
/// Storage layout (Firestore, when active):
///   users / {uid} / investigations / {docId}
/// This matches the security rules in `firestore.rules`:
///   match /users/{uid} {
///     allow read, write: if request.auth != null
///                         && request.auth.uid == uid;
///   }
class InvestigationArchiveService {
  InvestigationArchiveService._() : _auth = AuthService() {
    _localWriter = LocalInvestigationWriter();
    _writer = _localWriter;
    _listenAuthChanges();
  }

  InvestigationArchiveService.forTesting({
    InvestigationWriter? writer,
    AuthService? authService,
  }) : _auth = authService ?? AuthService() {
    _localWriter = LocalInvestigationWriter();
    if (writer != null) {
      _writer = writer;
    } else {
      _writer = _localWriter;
    }
    _listenAuthChanges();
  }

  /// Shared singleton used by the home / settings screens. Tests
  /// can still build their own instance via [forTesting].
  static final InvestigationArchiveService instance =
      InvestigationArchiveService._();

  /// Cap on how many documents we read at once for the latest list.
  /// Keeping it small keeps the home page snappy.
  static const int kLatestLimit = 8;

  /// Larger cap used by [loadResult] so a tap-through can find
  /// older investigations that scrolled off the home feed. We
  /// scan locally — Firestore returns the rows we already have
  /// cached in `_latestByUser` without a fresh round-trip when
  /// the id is recent.
  static const int _kLatestLoadLimit = 60;

  /// Returns the authenticated user's uid, or `'anonymous'`
  /// when no one is signed in. The home section falls back to the
  /// local cache for anonymous users.
  String get _currentUserId => _auth.currentUser?.uid ?? 'anonymous';

  late InvestigationWriter _writer;
  late final LocalInvestigationWriter _localWriter;
  FirestoreInvestigationWriter? _firestoreWriter;
  StreamSubscription<fb.User?>? _authSub;
  final AuthService _auth;

  /// Wires the Firestore writer and swaps it in for the default
  /// writer. Safe to call once after Firebase is initialised. The
  /// Firestore writer will only ever write/read under the currently
  /// signed-in user's uid; anonymous users keep using the local
  /// mirror.
  void enableFirestore(FirestoreInvestigationWriter firestore) {
    _firestoreWriter = firestore;
    _writer = CompositeInvestigationWriter(
      local: _localWriter,
      remote: firestore,
    );
    // The constructor's `_listenAuthChanges()` already has an
    // authStateChanges subscription, but it ran before `_firestoreWriter`
    // was set so its listener did `if (fw == null) return;` and
    // never called `attach`. Cancel that dummy subscription and
    // install a real one now that the writer is available.
    _authSub?.cancel();
    _authSub = fb.FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        firestore.attach(user.uid);
      }
    });
  }

  /// Tears down Firestore listeners and the auth subscription.
  Future<void> dispose() async {
    await _authSub?.cancel();
    await _firestoreWriter?.dispose();
  }

  /// Re-subscribes the Firestore writer whenever the auth state
  /// flips, so each user only ever sees their own slice.
  void _listenAuthChanges() {
    _authSub = fb.FirebaseAuth.instance.authStateChanges().listen((user) {
      final fw = _firestoreWriter;
      if (fw == null) return;
      if (user != null) {
        fw.attach(user.uid);
      }
    });
  }

  InvestigationWriter get writer => _writer;

  // =============================== Save ================================

  /// Persists a completed investigation.
  ///
  /// Failures are swallowed and logged — the call site already
  /// `unawaited(...)`s this method so the navigation is never
  /// blocked on the network write.
  Future<SavedInvestigation> save({
    required InvestigationResult result,
    required EntityType entityType,
    List<String> tags = const [],
    int? evidenceCount,
  }) async {
    final uid = _currentUserId;
    final modelId = _safeModelId();

    final sections = result.sections;
    final headline =
        sections.isNotEmpty ? sections.first.headline : result.title;

    // Use the result's confidence as the headline number. When
    // the AI didn't provide one we fall back to a neutral 60% so
    // the card still renders with a usable percentage.
    final confidence = (result.confidence ?? 0.6).clamp(0.0, 1.0);
    final pct = (confidence * 100).round();

    // Thumbnail: prefer the top-level one resolved by the parser,
    // otherwise the first evidence image, otherwise `null`.
    String? thumbnailUrl = result.thumbnailUrl;
    if (thumbnailUrl == null || thumbnailUrl.isEmpty) {
      for (final s in sections) {
        for (final it in s.items) {
          if (it.imageUrl != null && it.imageUrl!.isNotEmpty) {
            thumbnailUrl = it.imageUrl;
            break;
          }
        }
        if (thumbnailUrl != null) break;
      }
    }

    final saved = SavedInvestigation(
      id: result.investigationId,
      userId: uid,
      title: result.title,
      subtitle: result.subtitle.isNotEmpty
          ? result.subtitle
          : (headline.isNotEmpty ? headline : 'Investigation'),
      entityType: entityType,
      status: InvestigationStatus.completed,
      confidencePercent: pct,
      confidenceBand: confidenceBandFor(pct),
      tags: tags.take(3).toList(),
      createdAt: result.generatedAt,
      modelId: modelId,
      evidenceCount: evidenceCount ?? 0,
      thumbnailUrl: (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
          ? thumbnailUrl
          : null,
      // Embed the full report so a tap on the Latest Investigations
      // card can re-open the original report without re-running the
      // AI. Serialised once here; both the local mirror and the
      // Firestore writer persist it as-is. Reconstruction logic
      // lives on [InvestigationResult.fromJson].
      reportJson: result.toJson(),
    );

    try {
      await _writer.save(saved);
    } catch (e, st) {
      debugPrint(
        '[InvestigationArchiveService] save failed: $e\n$st',
      );
    }
    return saved;
  }

  // ============================ Read latest ============================

  /// Streams the most recent [limit] completed investigations for
  /// the current user. Emits once immediately, then re-emits on
  /// every writer-side change (local save, remote snapshot, etc.).
  Stream<List<SavedInvestigation>> watchLatest({
    int limit = kLatestLimit,
  }) =>
      _writer.watchLatest(_currentUserId, limit: limit);

  /// Streams the user's investigations directly from Firestore,
  /// bypassing the local mirror. Returns an empty stream when
  /// the Firestore writer hasn't been enabled (e.g. Firebase
  /// isn't initialised yet, or the user is anonymous with no
  /// cloud access). The home screen's "Recent Updates" section
  /// uses this so the user always sees their cloud-synced
  /// archive and not transient local rows that haven't been
  /// uploaded yet.
  Stream<List<SavedInvestigation>> watchLatestFromFirestore({
    int limit = kLatestLimit,
  }) {
    final remote = _firestoreWriter;
    if (remote == null) {
      return const Stream<List<SavedInvestigation>>.empty();
    }
    return remote.watchLatest(_currentUserId, limit: limit);
  }

  /// One-shot read. Used on cold start when subscribing isn't
  /// appropriate yet.
  Future<List<SavedInvestigation>> fetchLatest({
    int limit = kLatestLimit,
  }) async {
    try {
      return await _writer
          .watchLatest(_currentUserId, limit: limit)
          .first;
    } catch (e, st) {
      debugPrint(
        '[InvestigationArchiveService] fetchLatest failed: $e\n$st',
      );
      return const <SavedInvestigation>[];
    }
  }

  /// Flushes any locally-cached "anonymous" rows into the
  /// authenticated user. Safe to call once after sign-in.
  Future<int> commitPending() =>
      _writer.commitPendingForUser(_currentUserId);

  /// Hydrates the full [InvestigationResult] for a previously-
  /// saved investigation by [id]. Returns `null` when no
  /// matching record exists, when the record belongs to a
  /// different user, or when the embedded report payload is
  /// missing or malformed.
  ///
  /// The home screen calls this when a Latest Investigations
  /// card is tapped so the detail screen can re-open the
  /// original report without re-running the AI.
  Future<InvestigationResult?> loadResult(String id) async {
    try {
      final matches = await _writer
          .watchLatest(_currentUserId, limit: _kLatestLoadLimit)
          .first;
      for (final row in matches) {
        if (row.id != id) continue;
        final json = row.reportJson;
        if (json == null) return null;
        return InvestigationResult.fromJson(
          json,
          fallbackInvestigationId: row.id,
        );
      }
      return null;
    } catch (e, st) {
      debugPrint('[InvestigationArchiveService] loadResult failed: $e\n$st');
      return null;
    }
  }

  // ============================== Helpers =============================

  /// Resolves the model id without importing Flutter widgets in
  /// tests that exercise the archive service. Falls back to null
  /// if anything throws.
  String? _safeModelId() {
    try {
      return OpenRouterConfig.model;
    } catch (_) {
      return null;
    }
  }
}
