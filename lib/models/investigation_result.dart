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
  risks,
  // Influencer reports emit an extra section that bundles
  // "what to do next" — the 30-day plan, the things to avoid
  // for the next 30 days, and the suggestion backed by the
  // sources and evidence.
  actionPlan;

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
      case InvestigationResultKind.actionPlan:
        return 'ir_tab_action_plan';
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
      case InvestigationResultKind.actionPlan:
        return Icons.event_note_outlined;
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
    this.links = const <InvestigationResultLink>[],
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

  /// Optional list of clickable references rendered as buttons
  /// under the item body. Used for influencer social-account URLs
  /// (Instagram, TikTok, YouTube, X, Snapchat) and for any other
  /// clickable reference (brand site, product page, source URL).
  /// Each link is a [InvestigationResultLink] with a short label
  /// (e.g. "Instagram") and a full https URL.
  final List<InvestigationResultLink> links;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'body': body,
        'metric': metric,
        'metric_label': metricLabel,
        'badge': badge,
        'image_url': imageUrl,
        'links': links.map((l) => l.toJson()).toList(),
      };

  factory InvestigationResultItem.fromJson(Map<String, dynamic> json) {
    final linksRaw = json['links'];
    final links = <InvestigationResultLink>[];
    if (linksRaw is List) {
      for (final raw in linksRaw) {
        if (raw is Map<String, dynamic>) {
          final link = InvestigationResultLink.fromJson(raw);
          if (link != null) links.add(link);
        }
      }
    }
    return InvestigationResultItem(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      metric: json['metric'] as String?,
      metricLabel: json['metric_label'] as String?,
      badge: json['badge'] as String?,
      imageUrl: json['image_url'] as String?,
      links: links,
    );
  }
}

/// One tappable link rendered as a button under a result item.
/// See [InvestigationResultItem.links].
@immutable
class InvestigationResultLink {
  const InvestigationResultLink({required this.label, required this.url});

  /// Short button text (e.g. "Instagram", "TikTok", "Website").
  final String label;

  /// Full https URL the button opens.
  final String url;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'label': label,
        'url': url,
      };

  /// Reconstructs a link from JSON. Returns `null` when the
  /// link is malformed (empty label, empty / non-http URL) so the
  /// caller can drop it silently rather than show a button that
  /// does nothing when tapped.
  static InvestigationResultLink? fromJson(Map<String, dynamic> json) {
    final label = (json['label'] as String?)?.trim();
    final url = (json['url'] as String?)?.trim();
    if (label == null || label.isEmpty) return null;
    if (url == null || url.isEmpty) return null;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return null;
    }
    return InvestigationResultLink(label: label, url: url);
  }
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

  /// Serialises to JSON. Enums are stored by name so schema
  /// changes that add new enum values don't crash the parser.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': kind.name,
        'headline': headline,
        'summary': summary,
        'items': items.map((it) => it.toJson()).toList(),
        'confidence': confidence,
        'imageUrl': imageUrl,
      };

  factory InvestigationResultSection.fromJson(Map<String, dynamic> json) {
    final kindName = json['kind'] as String? ?? 'overview';
    final kind = InvestigationResultKind.values.firstWhere(
      (k) => k.name == kindName,
      orElse: () => InvestigationResultKind.overview,
    );
    final itemsRaw = json['items'];
    final items = <InvestigationResultItem>[];
    if (itemsRaw is List) {
      for (final raw in itemsRaw) {
        if (raw is Map<String, dynamic>) {
          items.add(InvestigationResultItem.fromJson(raw));
        }
      }
    }
    return InvestigationResultSection(
      kind: kind,
      headline: (json['headline'] as String?) ?? '',
      summary: (json['summary'] as String?) ?? '',
      items: items,
      confidence: (json['confidence'] is num)
          ? (json['confidence'] as num).toDouble()
          : null,
      imageUrl: json['imageUrl'] as String?,
    );
  }
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

  /// Serialises this result to a plain JSON-compatible map so it
  /// can be persisted alongside the [SavedInvestigation] card
  /// fields and re-hydrated later with [fromJson]. Used by the
  /// archive layer so a tap on a Latest Investigations card can
  /// re-open the full report without re-running the AI.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'investigationId': investigationId,
        'title': title,
        'subtitle': subtitle,
        'sections': sections.map((s) => s.toJson()).toList(),
        'sources': sources.map((s) => s.toJson()).toList(),
        'generatedAt': generatedAt.toUtc().toIso8601String(),
        'confidence': confidence,
        'thumbnailUrl': thumbnailUrl,
      };

  /// Hydrates a result from the JSON map stored in
  /// [SavedInvestigation.reportJson]. Defensive about field
  /// shape — missing / unexpected fields fall back to safe
  /// defaults so an older document written before a schema
  /// change still renders.
  ///
  /// If [investigationId] / [id] are not present in the JSON we
  /// derive them from [saved] so the reconstructed result links
  /// back to the archive entry that owns it.
  factory InvestigationResult.fromJson(
    Map<String, dynamic> json, {
    String? fallbackInvestigationId,
  }) {
    DateTime parseDate(Object? raw, DateTime fallback) {
      if (raw is String) return DateTime.tryParse(raw) ?? fallback;
      if (raw is int) {
        return DateTime.fromMillisecondsSinceEpoch(raw);
      }
      return fallback;
    }

    final fallback = DateTime.now().toUtc();
    final sections = <InvestigationResultSection>[];
    final sectionsRaw = json['sections'];
    if (sectionsRaw is List) {
      for (final raw in sectionsRaw) {
        if (raw is Map<String, dynamic>) {
          sections.add(InvestigationResultSection.fromJson(raw));
        }
      }
    }

    final sources = <InvestigationSource>[];
    final sourcesRaw = json['sources'];
    if (sourcesRaw is List) {
      for (final raw in sourcesRaw) {
        if (raw is Map<String, dynamic>) {
          sources.add(InvestigationSource.fromJson(raw));
        }
      }
    }

    return InvestigationResult(
      id: (json['id'] as String?) ?? fallbackInvestigationId ?? '',
      investigationId:
          (json['investigationId'] as String?) ?? fallbackInvestigationId ?? '',
      title: (json['title'] as String?) ?? '',
      subtitle: (json['subtitle'] as String?) ?? '',
      sections: sections,
      sources: sources,
      generatedAt: parseDate(json['generatedAt'], fallback),
      confidence: (json['confidence'] is num)
          ? (json['confidence'] as num).toDouble()
          : null,
      thumbnailUrl: json['thumbnailUrl'] as String?,
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

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'kind': kind.name,
        'url': url,
        'imageUrl': imageUrl,
      };

  factory InvestigationSource.fromJson(Map<String, dynamic> json) {
    final kindName = json['kind'] as String? ?? 'other';
    final kind = InvestigationSourceKind.values.firstWhere(
      (k) => k.name == kindName,
      orElse: () => InvestigationSourceKind.other,
    );
    return InvestigationSource(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      subtitle: (json['subtitle'] as String?) ?? '',
      kind: kind,
      url: json['url'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );
  }
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
