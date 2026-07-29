import 'entity_type.dart';

enum InvestigationStatus { active, paused, completed }

/// A single investigation the user is tracking. Mock data only in the MVP.
class Investigation {
  const Investigation({
    required this.id,
    required this.title,
    required this.entityType,
    required this.status,
    required this.lastUpdated,
    required this.progress,
    required this.summary,
  });

  final String id;
  final String title;
  final EntityType entityType;
  final InvestigationStatus status;
  final DateTime lastUpdated;
  final double progress; // 0.0 - 1.0
  final String summary;
}
