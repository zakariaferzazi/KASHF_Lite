import 'entity_type.dart';

/// Lifecycle status of an investigation. Used across the app
/// (Home, Files, Latest Investigations, Reports).
enum InvestigationStatus { active, paused, completed }

/// Lifecycle phase used by the new investigation flow to track the
/// AI/evidence processing pipeline. The two enums coexist because
/// [InvestigationStatus] is what the rest of the app already shows
/// (Home active list, etc.), while [InvestigationPhase] drives the
/// processing UI inside the investigation screen itself.
enum InvestigationPhase {
  draft,
  evidenceCollecting,
  evidenceProcessing,
  analyzing,
  completed,
  failed;

  /// Returns the matching user-facing label l10n key.
  String get l10nKey {
    switch (this) {
      case InvestigationPhase.draft:
        return 'ir_phase_draft';
      case InvestigationPhase.evidenceCollecting:
        return 'ir_phase_collecting';
      case InvestigationPhase.evidenceProcessing:
        return 'ir_phase_processing';
      case InvestigationPhase.analyzing:
        return 'ir_phase_analyzing';
      case InvestigationPhase.completed:
        return 'ir_phase_completed';
      case InvestigationPhase.failed:
        return 'ir_phase_failed';
    }
  }

  /// Percentage of the bar shown on the loading sheet (0..1).
  double get progress {
    switch (this) {
      case InvestigationPhase.draft:
        return 0.0;
      case InvestigationPhase.evidenceCollecting:
        return 0.15;
      case InvestigationPhase.evidenceProcessing:
        return 0.4;
      case InvestigationPhase.analyzing:
        return 0.7;
      case InvestigationPhase.completed:
        return 1.0;
      case InvestigationPhase.failed:
        return 0.0;
    }
  }
}

/// A single investigation the user is tracking. Mock data only in
/// the MVP but the shape now supports the new flow (phase + query).
class Investigation {
  const Investigation({
    required this.id,
    required this.title,
    required this.entityType,
    required this.status,
    required this.lastUpdated,
    required this.progress,
    required this.summary,
    this.query,
    this.evidenceIds = const [],
    this.phase = InvestigationPhase.draft,
  });

  final String id;
  final String title;
  final EntityType entityType;
  final InvestigationStatus status;
  final DateTime lastUpdated;
  final double progress; // 0.0 - 1.0
  final String summary;

  /// Original query the user typed. Used by the AI pipeline.
  final String? query;

  /// IDs of evidence attached to this investigation.
  final List<String> evidenceIds;

  /// Current processing phase. Independent from [status] which is
  /// the user-facing status (active/paused/completed).
  final InvestigationPhase phase;

  Investigation copyWith({
    InvestigationStatus? status,
    DateTime? lastUpdated,
    double? progress,
    String? summary,
    String? query,
    List<String>? evidenceIds,
    InvestigationPhase? phase,
  }) {
    return Investigation(
      id: id,
      title: title,
      entityType: entityType,
      status: status ?? this.status,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      progress: progress ?? this.progress,
      summary: summary ?? this.summary,
      query: query ?? this.query,
      evidenceIds: evidenceIds ?? this.evidenceIds,
      phase: phase ?? this.phase,
    );
  }
}
