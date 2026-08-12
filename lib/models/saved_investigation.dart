import 'package:flutter/foundation.dart';

import 'entity_type.dart';
import 'investigation.dart';

/// Slim, persistable summary of a completed investigation. We
/// deliberately keep this as a flat document (no nested sections)
/// so it can be stored cleanly in a single Firestore document
/// AND rendered as a card on the Home screen without any joins.
///
/// Fields mirror what the [LatestInvestigationsCard] needs to
/// render — title, badge label, confidence %, status, tags,
/// timestamp — so the home screen reads straight from this model
/// without going back to the full [InvestigationResult].
@immutable
class SavedInvestigation {
  const SavedInvestigation({
    required this.id,
    required this.userId,
    required this.title,
    required this.subtitle,
    required this.entityType,
    required this.status,
    required this.confidencePercent,
    required this.confidenceBand,
    required this.tags,
    required this.createdAt,
    this.modelId,
    this.evidenceCount = 0,
    this.thumbnailUrl,
  });

  /// Firestore document id. Locally-generated UUID for offline
  /// documents that haven't been flushed yet.
  final String id;

  /// Owning user's uid. Anonymous/local investigations fall back
  /// to `'anonymous'` (still in their own private sub-collection
  /// once they sign in).
  final String userId;

  /// Headline shown on the latest-investigations card.
  final String title;

  /// Short subtitle (e.g. "Profile overview and key findings").
  final String subtitle;

  /// What was investigated.
  final EntityType entityType;

  /// Lifecycle. Always [InvestigationStatus.completed] for
  /// saved investigations — failed ones are deliberately not
  /// archived.
  final InvestigationStatus status;

  /// 0..100 confidence %, snapped from the AI's 0..1 score.
  final int confidencePercent;

  /// Discrete band ('high' / 'medium' / 'low') derived from the
  /// percentage — drives the colour + label on the card without
  /// having to recompute thresholding in the UI.
  final String confidenceBand;

  /// 0..3 short tag strings shown on the card.
  final List<String> tags;

  /// Wall-clock time the investigation completed.
  final DateTime createdAt;

  /// OpenRouter model id that produced the result (best-effort).
  final String? modelId;

  /// Number of evidence items attached at the time of the run.
  final int evidenceCount;

  /// URL of an image used as the card thumbnail. Sourced from the
  /// AI result's first image-bearing source so the latest-investigations
  /// list and the result hero card show a visual identifier of the
  /// investigated subject. `null` means "no thumbnail available" —
  /// the UI falls back to a neutral icon tile.
  final String? thumbnailUrl;

  String get documentId => id;

  Map<String, dynamic> toFirestore() => <String, dynamic>{
        'userId': userId,
        'title': title,
        'subtitle': subtitle,
        'entityType': entityType.name,
        'status': status.name,
        'confidencePercent': confidencePercent,
        'confidenceBand': confidenceBand,
        'tags': tags,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'modelId': modelId,
        'evidenceCount': evidenceCount,
        'thumbnailUrl': thumbnailUrl,
      };

  /// Hydrate from a Firestore document. Falls back to safe
  /// defaults when fields are missing so old documents don't
  /// crash the UI.
  factory SavedInvestigation.fromFirestore(Map<String, dynamic> doc) {
    DateTime parseDate(Object? raw) {
      if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
      if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
      return DateTime.now();
    }

    final entityStr = (doc['entityType'] as String?) ?? 'brand';
    final entity = EntityType.values.firstWhere(
      (e) => e.name == entityStr,
      orElse: () => EntityType.brand,
    );
    final statusStr = (doc['status'] as String?) ?? 'completed';
    final status = InvestigationStatus.values.firstWhere(
      (s) => s.name == statusStr,
      orElse: () => InvestigationStatus.completed,
    );
    return SavedInvestigation(
      id: (doc['id'] as String?) ??
          doc['docId']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      userId: (doc['userId'] as String?) ?? 'anonymous',
      title: (doc['title'] as String?) ?? '',
      subtitle: (doc['subtitle'] as String?) ?? '',
      entityType: entity,
      status: status,
      confidencePercent:
          ((doc['confidencePercent'] as num?) ?? 0).toInt().clamp(0, 100),
      confidenceBand: (doc['confidenceBand'] as String?) ?? 'medium',
      tags: (doc['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      createdAt: parseDate(doc['createdAt']),
      modelId: doc['modelId'] as String?,
      evidenceCount: ((doc['evidenceCount'] as num?) ?? 0).toInt(),
      thumbnailUrl: doc['thumbnailUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => toFirestore();

  factory SavedInvestigation.fromJson(Map<String, dynamic> json) =>
      SavedInvestigation.fromFirestore(json);

  SavedInvestigation copyWith({
    String? title,
    String? subtitle,
    int? confidencePercent,
    String? confidenceBand,
    List<String>? tags,
    String? modelId,
    int? evidenceCount,
    EntityType? entityType,
    InvestigationStatus? status,
    String? thumbnailUrl,
  }) {
    return SavedInvestigation(
      id: id,
      userId: userId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      entityType: entityType ?? this.entityType,
      status: status ?? this.status,
      confidencePercent: confidencePercent ?? this.confidencePercent,
      confidenceBand: confidenceBand ?? this.confidenceBand,
      tags: tags ?? this.tags,
      createdAt: createdAt,
      modelId: modelId ?? this.modelId,
      evidenceCount: evidenceCount ?? this.evidenceCount,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    );
  }
}

/// Tiny utility that bins a 0..100 percentage into one of three
/// bands. Centralised here so the home card and the future
/// "Latest investigations" screen stay in sync.
String confidenceBandFor(int percent) {
  if (percent >= 80) return 'high';
  if (percent >= 60) return 'medium';
  return 'low';
}
