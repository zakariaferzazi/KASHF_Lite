/// The kind of AI output a report represents. Localization keys are mapped
/// in [reportL10nKey].
enum ReportType {
  investigation,
  executiveSummary,
  marketInsight,
  competitive,
  product,
  brand,
  company,
  influencer,
  swot,
  contentIdeas,
  reelScript,
  podcastScript,
  monitoring,
  recommendation,
}

extension ReportTypeX on ReportType {
  String get l10nKey {
    switch (this) {
      case ReportType.investigation:
        return 'reports_action_generate';
      case ReportType.executiveSummary:
        return 'reports_action_summary';
      case ReportType.marketInsight:
        return 'reports_action_market';
      case ReportType.competitive:
        return 'reports_action_competitive';
      case ReportType.swot:
        return 'reports_action_swot';
      case ReportType.contentIdeas:
        return 'reports_action_content';
      case ReportType.reelScript:
        return 'reports_action_reel';
      case ReportType.podcastScript:
        return 'reports_action_podcast';
      case ReportType.monitoring:
        return 'reports_action_monitoring';
      case ReportType.recommendation:
        return 'reports_action_recommendation';
      case ReportType.product:
      case ReportType.brand:
      case ReportType.company:
      case ReportType.influencer:
        return 'reports_action_generate';
    }
  }
}

enum ReportStatus { recent, archived }

class Report {
  const Report({
    required this.id,
    required this.title,
    required this.type,
    required this.status,
    required this.createdAt,
    required this.preview,
    required this.sourceCount,
  });

  final String id;
  final String title;
  final ReportType type;
  final ReportStatus status;
  final DateTime createdAt;
  final String preview;
  final int sourceCount;
}
