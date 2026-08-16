import 'package:flutter/foundation.dart';

import 'entity_type.dart';
import 'investigation.dart';

/// Slim, persistable summary of a completed investigation. We
/// keep the card-rendering fields flat (title, subtitle,
/// confidence, tags, thumbnail, timestamp) so a single Firestore
/// document can hydrate the Latest Investigations card without
/// any joins, AND we embed the full report JSON in the same
/// document so a tap-through to the detail screen can re-open
/// the original report from Firestore / SharedPreferences
/// without re-running the investigation.
///
/// Document size: a typical 7-section influencer report
/// serialises to ~50–150 KB of JSON — well under Firestore's
/// 1 MiB-per-document limit. If a report ever grows past that
/// we'll move [reportJson] into a sibling sub-document; for
/// now one document per investigation keeps reads and writes
/// simple and atomic.
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
    this.reportJson,
    this.autoRefreshDays = 0,
    this.autoRefreshUntil,
    this.lastRefreshedAt,
    /// Original free-text query the user typed. Persisted so the
    /// background auto-refresh can replay the exact same
    /// investigation without user input.
    this.originalQuery,
    /// Original quick-action id (the "lens"). Same reason as
    /// [originalQuery] — required to reproduce the run.
    this.actionId,
    /// Language code (`en` / `ar`) at the time of the run. Used
    /// by the background re-run to localize the AI prompt so the
    /// report stays in the user's chosen language.
    this.languageCode,
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

  /// Full report payload (sections / sources / hero / items /
  /// links) serialised as a `Map<String, dynamic>`. Stored inside
  /// the same Firestore document as the card fields so the home
  /// screen can fetch the card metadata AND re-open the full
  /// report from a single read.
  ///
  /// `null` for older documents written before this field
  /// existed (see [InvestigationResult.fromJson] for the
  /// reconstruction fallback that synthesises a minimal report
  /// from the card fields).
  final Map<String, dynamic>? reportJson;

  /// Auto-refresh duration chosen by the user. `0` means refresh
  /// is OFF (no background re-run). `30` or `60` are the only
  /// supported values.
  final int autoRefreshDays;

  /// Hard expiry — when the auto-refresh window ends.
  /// The background scheduler refreshes the report every 72h
  /// **while** `now < autoRefreshUntil`. Once the expiry passes
  /// the work is permanently cancelled.
  final DateTime? autoRefreshUntil;

  /// Wall-clock time of the most recent refresh (initial run or
  /// auto-refresh). Used by the scheduler to decide whether the
  /// 72h interval has elapsed since the last refresh.
  final DateTime? lastRefreshedAt;

  /// Original free-text query the user typed. Persisted so the
  /// background auto-refresh can replay the exact same
  /// investigation without user input.
  final String? originalQuery;

  /// Original quick-action id (the "lens"). Same reason as
  /// [originalQuery] — required to reproduce the run.
  final String? actionId;

  /// Language code (`en` / `ar`) at the time of the run. Used
  /// by the background re-run to localize the AI prompt so the
  /// report stays in the user's chosen language.
  final String? languageCode;

  String get documentId => id;

  /// Whether the auto-refresh *window* is currently open. We use
  /// `autoRefreshUntil` (a hard expiry) rather than `autoRefreshDays`
  /// because the user picks a duration at a point in time and we
  /// persist the resulting wall-clock cutoff.
  bool get hasActiveAutoRefresh =>
      autoRefreshUntil != null && autoRefreshUntil!.isAfter(DateTime.now());

  /// Whether the scheduler should re-run this investigation now.
  /// Returns `true` when:
  ///  - the auto-refresh window is still open AND
  ///  - we don't have a recorded `lastRefreshedAt`, OR
  ///  - the last refresh is older than [kAutoRefreshInterval].
  bool get isRefreshDue {
    if (!hasActiveAutoRefresh) return false;
    final last = lastRefreshedAt;
    if (last == null) return true;
    return DateTime.now().difference(last) >= kAutoRefreshInterval;
  }

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
        if (reportJson != null) 'report': reportJson,
        'autoRefreshDays': autoRefreshDays,
        if (autoRefreshUntil != null)
          'autoRefreshUntil': autoRefreshUntil!.toUtc().toIso8601String(),
        if (lastRefreshedAt != null)
          'lastRefreshedAt': lastRefreshedAt!.toUtc().toIso8601String(),
        if (originalQuery != null) 'originalQuery': originalQuery,
        if (actionId != null) 'actionId': actionId,
        if (languageCode != null) 'languageCode': languageCode,
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
      reportJson: (doc['report'] is Map<String, dynamic>)
          ? doc['report'] as Map<String, dynamic>
          : null,
      autoRefreshDays: ((doc['autoRefreshDays'] as num?) ?? 0).toInt(),
      autoRefreshUntil: parseDate(doc['autoRefreshUntil']),
      lastRefreshedAt: parseDate(doc['lastRefreshedAt']),
      originalQuery: doc['originalQuery'] as String?,
      actionId: doc['actionId'] as String?,
      languageCode: doc['languageCode'] as String?,
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
    Map<String, dynamic>? reportJson,
    int? autoRefreshDays,
    DateTime? autoRefreshUntil,
    DateTime? lastRefreshedAt,
    bool clearAutoRefreshUntil = false,
    bool clearLastRefreshedAt = false,
    String? originalQuery,
    String? actionId,
    String? languageCode,
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
      reportJson: reportJson ?? this.reportJson,
      autoRefreshDays: autoRefreshDays ?? this.autoRefreshDays,
      autoRefreshUntil: clearAutoRefreshUntil
          ? null
          : (autoRefreshUntil ?? this.autoRefreshUntil),
      lastRefreshedAt: clearLastRefreshedAt
          ? null
          : (lastRefreshedAt ?? this.lastRefreshedAt),
      originalQuery: originalQuery ?? this.originalQuery,
      actionId: actionId ?? this.actionId,
      languageCode: languageCode ?? this.languageCode,
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

/// Interval (in hours) between scheduled auto-refreshes. Each
/// tracked investigation is re-run on this cadence while the
/// expiry window is still open.
const Duration kAutoRefreshInterval = Duration(hours: 72);

/// Fixed choices shown in the auto-refresh picker. `0` means
/// the auto-refresh is OFF (no background re-run).
const List<int> kAutoRefreshDayChoices = <int>[0, 30, 60];
