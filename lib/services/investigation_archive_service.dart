import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/entity_type.dart';
import '../models/investigation.dart';
import '../models/investigation_result.dart';
import '../models/saved_investigation.dart';
import 'ai/openrouter_config.dart';
import 'archive/investigation_writer.dart';
import 'archive/local_investigation_writer.dart';
import 'auth_service.dart';

/// Persists completed investigations and exposes the "latest"
/// feed to the Home screen's "Latest Investigations" section.
///
/// Storage architecture:
///   * Pluggable [InvestigationWriter] backend (defaults to the
///     offline SharedPreferences implementation so the section
///     works without any cloud setup).
///   * When the cloud_firestore package is added to pubspec.yaml
///     the `FirestoreInvestigationWriter` can be swapped in by
///     calling [useFirestoreWriter] before [bootstrap] — the
///     orchestration here is identical.
///
/// Failure modes are non-fatal: every write also goes through the
/// local writer first so the home section always has data to
/// show, even on a brand-new install with no network.
///
/// Storage layout (when Firestore is plugged in):
///   users / {uid} / investigations / {docId}
class InvestigationArchiveService {
  InvestigationArchiveService({
    InvestigationWriter? writer,
    AuthService? authService,
  }) : _auth = authService ?? AuthService() {
    _writer = writer ?? LocalInvestigationWriter();
  }

  /// Cap on how many documents we read at once for the latest list.
  /// Keeping it small keeps the home page snappy.
  static const int kLatestLimit = 8;

  /// Returns the authenticated user's uid, or `'anonymous'`
  /// when no one is signed in. The home section falls back to the
  /// local cache for anonymous users.
  String get _currentUserId => _auth.currentUser?.uid ?? 'anonymous';

  late InvestigationWriter _writer;
  final AuthService _auth;

  /// Swaps in a Firestore-backed [InvestigationWriter]. Called
  /// from `main.dart` after Firebase is initialised, gated on
  /// `cloud_firestore` being present in pubspec.
  @visibleForTesting
  void useFirestoreWriter(InvestigationWriter writer) {
    _writer = writer;
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
