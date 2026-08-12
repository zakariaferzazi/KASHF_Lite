import 'package:flutter/material.dart';

/// High-level output "section" we render on the results screen. The
/// values drive the chip filter at the top of the screen.
///
/// Each kind is one of the 7 the AI model emits for an
/// investigation. The renderer can collapse empty sections so a
/// sparse-but-accurate report still feels complete.
enum InvestigationResultKind {
  overview,
  evidence,
  keyFindings,
  activityTrends,
  competitors,
  opportunities,
  risks;

  String get l10nKey {
    switch (this) {
      case InvestigationResultKind.overview:
        return 'ir_tab_overview';
      case InvestigationResultKind.evidence:
        return 'ir_tab_evidence';
      case InvestigationResultKind.keyFindings:
        return 'ir_tab_key_findings';
      case InvestigationResultKind.activityTrends:
        return 'ir_tab_activity_trends';
      case InvestigationResultKind.competitors:
        return 'ir_tab_competitors';
      case InvestigationResultKind.opportunities:
        return 'ir_tab_opportunities';
      case InvestigationResultKind.risks:
        return 'ir_tab_risks';
    }
  }

  IconData get icon {
    switch (this) {
      case InvestigationResultKind.overview:
        return Icons.summarize_outlined;
      case InvestigationResultKind.evidence:
        return Icons.folder_open_outlined;
      case InvestigationResultKind.keyFindings:
        return Icons.lightbulb_outline;
      case InvestigationResultKind.activityTrends:
        return Icons.trending_up;
      case InvestigationResultKind.competitors:
        return Icons.compare_arrows;
      case InvestigationResultKind.opportunities:
        return Icons.auto_awesome;
      case InvestigationResultKind.risks:
        return Icons.warning_amber_outlined;
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
    this.imageUrl,
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

  /// Optional image URL rendered as a thumbnail next to the item.
  /// When the AI response (or the attached evidence) provides a
  /// visual identifier for the investigated subject, the result
  /// hero card surfaces it here so the user has an at-a-glance
  /// picture of what they're looking at.
  final String? imageUrl;
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
    this.imageUrl,
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

  /// Optional section-level thumbnail. When the AI provides a
  /// hero image for the report it is hoisted into the result
  /// screen's hero card so the user sees it the moment they land.
  final String? imageUrl;
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
    this.thumbnailUrl,
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

  /// Top-level hero thumbnail for the investigation. Copied from
  /// the most relevant section/item when the result is parsed and
  /// re-used by [InvestigationArchiveService] when saving the
  /// report so the Latest Investigations list can render the same
  /// picture on every card.
  final String? thumbnailUrl;

  /// Returns a copy of this result with [thumbnailUrl] (and
  /// optionally other fields) replaced. Used by the thumbnail
  /// resolver service to swap in a verified image URL after the
  /// AI response is parsed but before the result is handed to the
  /// UI.
  InvestigationResult copyWith({
    String? thumbnailUrl,
    double? confidence,
  }) {
    return InvestigationResult(
      id: id,
      investigationId: investigationId,
      title: title,
      subtitle: subtitle,
      sections: sections,
      generatedAt: generatedAt,
      sources: sources,
      confidence: confidence ?? this.confidence,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    );
  }
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
    this.imageUrl,
  });

  final String id;
  final String title;
  final String subtitle;

  /// Loose source category. The UI maps this to an icon.
  final InvestigationSourceKind kind;

  final String? url;

  /// Optional thumbnail for the source (e.g. an article cover image).
  /// When present, the latest-investigations archive uses the first
  /// available image-bearing source as the card thumbnail so the
  /// user can recognise the investigated subject at a glance.
  final String? imageUrl;
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
