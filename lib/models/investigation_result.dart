import 'package:flutter/material.dart';

/// High-level output "section" we render on the results screen. The
/// values drive the chip filter at the top of the screen.
enum InvestigationResultKind {
  overview,
  evidence,
  insights,
  sources,
  recommendations;

  String get l10nKey {
    switch (this) {
      case InvestigationResultKind.overview:
        return 'ir_tab_overview';
      case InvestigationResultKind.evidence:
        return 'ir_tab_evidence';
      case InvestigationResultKind.insights:
        return 'ir_tab_insights';
      case InvestigationResultKind.sources:
        return 'ir_tab_sources';
      case InvestigationResultKind.recommendations:
        return 'ir_tab_recommendations';
    }
  }

  IconData get icon {
    switch (this) {
      case InvestigationResultKind.overview:
        return Icons.summarize_outlined;
      case InvestigationResultKind.evidence:
        return Icons.folder_open_outlined;
      case InvestigationResultKind.insights:
        return Icons.lightbulb_outline;
      case InvestigationResultKind.sources:
        return Icons.link_outlined;
      case InvestigationResultKind.recommendations:
        return Icons.recommend_outlined;
    }
  }
}

/// One atomic piece of content inside a results section. The shape
/// is intentionally small so we can render it with the same card
/// everywhere (overview, insights, recommendations, sources).
@immutable
class InvestigationResultItem {
  const InvestigationResultItem({
    required this.id,
    required this.title,
    required this.body,
    this.metric,
    this.metricLabel,
    this.badge,
  });

  final String id;
  final String title;
  final String body;

  /// Optional highlighted number (e.g. "92%", "24 sources").
  final String? metric;

  /// Caption under [metric].
  final String? metricLabel;

  /// Optional small tag (e.g. "Verified", "Low confidence").
  final String? badge;
}

/// One tab/section in the results screen.
@immutable
class InvestigationResultSection {
  const InvestigationResultSection({
    required this.kind,
    required this.headline,
    required this.summary,
    required this.items,
    this.confidence,
  });

  final InvestigationResultKind kind;

  /// Big title rendered above the section summary.
  final String headline;

  /// Short subtitle rendered under the headline.
  final String summary;

  /// Ordered list of items rendered as cards.
  final List<InvestigationResultItem> items;

  /// 0..1 confidence score. `null` means the AI did not provide one.
  final double? confidence;
}

/// Top-level result payload returned by [InvestigationService] when
/// an investigation finishes. The results screen renders this 1:1.
@immutable
class InvestigationResult {
  const InvestigationResult({
    required this.id,
    required this.investigationId,
    required this.title,
    required this.subtitle,
    required this.sections,
    required this.generatedAt,
    required this.sources,
    this.confidence,
  });

  final String id;
  final String investigationId;

  /// Result title (e.g. "Investigation · Lattafa").
  final String title;

  /// Result subtitle (e.g. "Profile overview and key findings").
  final String subtitle;

  /// Sections to render as tabs. Order = visual order.
  final List<InvestigationResultSection> sections;

  /// When the AI finished generating.
  final DateTime generatedAt;

  /// Flat list of external source references used across sections.
  final List<InvestigationSource> sources;

  /// Overall confidence (0..1). Drives the big percentage at the top.
  final double? confidence;
}

/// A source the AI cited (URL, article, social post, etc.).
@immutable
class InvestigationSource {
  const InvestigationSource({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.kind,
    this.url,
  });

  final String id;
  final String title;
  final String subtitle;

  /// Loose source category. The UI maps this to an icon.
  final InvestigationSourceKind kind;

  final String? url;
}

enum InvestigationSourceKind {
  web,
  news,
  social,
  document,
  other;

  IconData get icon {
    switch (this) {
      case InvestigationSourceKind.web:
        return Icons.public;
      case InvestigationSourceKind.news:
        return Icons.article_outlined;
      case InvestigationSourceKind.social:
        return Icons.tag;
      case InvestigationSourceKind.document:
        return Icons.description_outlined;
      case InvestigationSourceKind.other:
        return Icons.link;
    }
  }
}
