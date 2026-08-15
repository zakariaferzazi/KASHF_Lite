/// One "قضية اليوم" (today's case) entry, loaded from
/// `assets/Data/today_case.json`.
///
/// The JSON schema in that file uses a single unique key —
/// `logourl` (e.g. `"saudi-aramco"`) — instead of a separate
/// `id` field, and the `logo` value is wrapped in markdown
/// link syntax that needs to be stripped before the URL is
/// usable. `coverImage` carries an asset key (e.g.
/// `"cover-saudi-aramco"`) — the matching file may or may
/// not exist in `assets/images/`, so consumers should fall
/// back to a bundled image when it's missing.
class TodayCase {
  const TodayCase({
    required this.logourl,
    required this.name,
    required this.nameAr,
    required this.description,
    required this.descriptionAr,
    required this.logo,
    required this.coverImage,
    required this.status,
    required this.category,
    required this.kpi,
    required this.quickIndicators,
    required this.socialPlatforms,
    required this.timeline,
  });

  /// Unique key (matches the JSON `"logourl"` field).
  final String logourl;

  /// English brand name.
  final String name;

  /// Arabic brand name.
  final String nameAr;

  /// English short description.
  final String description;

  /// Arabic short description.
  final String descriptionAr;

  /// Raw `logo` string from the JSON. Often a markdown-wrapped
  /// URL — use [cleanLogoUrl] to get the bare https URL.
  final String logo;

  /// Asset key for the cover image (e.g. `"cover-saudi-aramco"`).
  /// May or may not correspond to a real file under
  /// `assets/images/`. Consumers should fall back gracefully.
  final String coverImage;

  /// Status string (e.g. `"active"`).
  final String status;

  /// Industry / vertical (e.g. `"food"`, `"retail"`, `"tech"`).
  final String category;

  /// Four top-line metrics shown on the KPI strip.
  final TodayCaseKpi kpi;

  /// Four stat cards in the "Quick Indicators" row.
  final TodayCaseQuickIndicators quickIndicators;

  /// List of social platforms this brand is active on
  /// (`"instagram"`, `"tiktok"`, `"x"`, ...).
  final List<String> socialPlatforms;

  /// Timeline history shown at the bottom of the detail screen.
  final List<TodayCaseTimelineEvent> timeline;

  /// Locale-aware display name. Arabic gets [nameAr] when
  /// the user is on an RTL locale, otherwise [name].
  String displayName({required bool isRtl}) =>
      isRtl ? nameAr : name;

  /// Locale-aware description.
  String displayDescription({required bool isRtl}) =>
      isRtl ? descriptionAr : description;

  /// Strips markdown-link syntax from the raw [logo] string.
  /// The bundled JSON stores `logo` as
  /// `"[url](url)"`; this returns just the first https URL
  /// inside it, or the original string when no URL is found.
  String get cleanLogoUrl {
    final raw = logo.trim();
    // Markdown link form: "[https://...](https://...)".
    final match = RegExp(r'https?://[^\s\)\]]+').firstMatch(raw);
    return match?.group(0) ?? raw;
  }

  /// The image URL to use for this case's hero tile. Prefers
  /// the real `logo` URL from the bundled JSON (Logo.dev CDN);
  /// falls back to the local asset key when the URL is
  /// missing.
  String get coverImageUrl => cleanLogoUrl;

  /// Bundled asset path that should host the cover image. We
  /// guess `.jpg` since that's the dominant extension in
  /// `assets/images/`; consumers should still wrap the load
  /// in an `errorBuilder` because not every entry has a real
  /// file on disk.
  String get coverAssetPath {
    final key = coverImage.trim();
    if (key.isEmpty) return '';
    if (key.startsWith('assets/')) return key;
    return 'assets/images/$key.jpg';
  }

  /// Parses one JSON object into a [TodayCase].
  factory TodayCase.fromJson(Map<String, dynamic> json) {
    return TodayCase(
      logourl: (json['logourl'] ?? json['id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      nameAr: (json['nameAr'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      descriptionAr: (json['descriptionAr'] ?? '') as String,
      logo: (json['logo'] ?? '') as String,
      coverImage: (json['coverImage'] ?? '') as String,
      status: (json['status'] ?? 'active') as String,
      category: (json['category'] ?? '') as String,
      kpi: TodayCaseKpi.fromJson(
        (json['kpi'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      quickIndicators: TodayCaseQuickIndicators.fromJson(
        (json['quickIndicators'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      socialPlatforms:
          (json['socialPlatforms'] as List?)?.cast<String>() ?? const [],
      timeline: ((json['timeline'] as List?) ?? const [])
          .cast<Map>()
          .map((m) => TodayCaseTimelineEvent.fromJson(
                m.cast<String, dynamic>(),
              ))
          .toList(growable: false),
    );
  }
}

/// Four top-line numbers on the detail-screen KPI strip:
/// Reach / Mentions / Confidence / Active.
class TodayCaseKpi {
  const TodayCaseKpi({
    required this.reach,
    required this.mentions,
    required this.index,
    required this.activeDays,
  });

  final String reach;
  final String mentions;
  final String index;
  final String activeDays;

  factory TodayCaseKpi.fromJson(Map<String, dynamic> json) {
    return TodayCaseKpi(
      reach: json['reach']?.toString() ?? '0',
      mentions: json['mentions']?.toString() ?? '0',
      index: json['index']?.toString() ?? '0',
      activeDays: json['activeDays']?.toString() ?? '0',
    );
  }
}

/// One of the four stat cards in the "Quick Indicators" row
/// (Volume / Engagement / Positive / Revenue). Each card
/// carries an Arabic label so the row works in RTL without
/// the UI needing to know about label translation.
class TodayCaseQuickIndicator {
  const TodayCaseQuickIndicator({
    required this.value,
    required this.label,
    required this.labelAr,
    required this.sub,
  });

  final String value;
  final String label;
  final String labelAr;
  final String sub;

  String displayLabel({required bool isRtl}) =>
      isRtl ? labelAr : label;

  factory TodayCaseQuickIndicator.fromJson(Map<String, dynamic> json) {
    return TodayCaseQuickIndicator(
      value: json['value']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      labelAr: json['labelAr']?.toString() ?? '',
      sub: json['sub']?.toString() ?? '',
    );
  }
}

/// Bundle of all four quick-indicator cards so the UI can
/// pass them around as a single object.
class TodayCaseQuickIndicators {
  const TodayCaseQuickIndicators({
    required this.volume,
    required this.engagement,
    required this.positive,
    required this.revenue,
  });

  final TodayCaseQuickIndicator volume;
  final TodayCaseQuickIndicator engagement;
  final TodayCaseQuickIndicator positive;
  final TodayCaseQuickIndicator revenue;

  factory TodayCaseQuickIndicators.fromJson(Map<String, dynamic> json) {
    return TodayCaseQuickIndicators(
      volume: TodayCaseQuickIndicator.fromJson(
        (json['volume'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      engagement: TodayCaseQuickIndicator.fromJson(
        (json['engagement'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      positive: TodayCaseQuickIndicator.fromJson(
        (json['positive'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      revenue: TodayCaseQuickIndicator.fromJson(
        (json['revenue'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
    );
  }
}

/// One row in the timeline shown at the bottom of the detail
/// screen. Has Arabic + English versions of both the title and
/// the description so the locale picker controls everything.
class TodayCaseTimelineEvent {
  const TodayCaseTimelineEvent({
    required this.date,
    required this.title,
    required this.titleAr,
    required this.description,
    required this.descriptionAr,
  });

  /// ISO date string `"YYYY-MM-DD"` — rendered as-is.
  final String date;
  final String title;
  final String titleAr;
  final String description;
  final String descriptionAr;

  String displayTitle({required bool isRtl}) =>
      isRtl ? titleAr : title;

  String displayDescription({required bool isRtl}) =>
      isRtl ? descriptionAr : description;

  factory TodayCaseTimelineEvent.fromJson(Map<String, dynamic> json) {
    return TodayCaseTimelineEvent(
      date: json['date']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      titleAr: json['titleAr']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      descriptionAr: json['descriptionAr']?.toString() ?? '',
    );
  }
}