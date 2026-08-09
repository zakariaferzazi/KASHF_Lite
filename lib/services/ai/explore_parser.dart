import 'explore_models.dart';

/// Parses the JSON returned by [AiPrompts.exploreDetailMessages]
/// into an [ExploreDetailData] payload. Defensive: missing / bad
/// fields are replaced with safe defaults so the UI always renders.
class ExploreParser {
  ExploreParser._();

  static ExploreDetailData parse(Map<String, dynamic> json) {
    return ExploreDetailData(
      trending: _parseTrending(json['trending']),
      discover: _parseDiscover(json['discover']),
      recent: _parseRecent(json['recent']),
    );
  }

  // ---------- Trending carousel ----------

  static List<ExploreTrendingItem> _parseTrending(dynamic raw) {
    if (raw is! List || raw.isEmpty) return _fallbackTrending();
    final out = <ExploreTrendingItem>[];
    for (var i = 0; i < raw.length && out.length < 4; i++) {
      final item = raw[i];
      if (item is! Map<String, dynamic>) continue;
      out.add(ExploreTrendingItem(
        titleEn: _str(item['title_en'], fallback: 'Trending'),
        titleAr: _str(item['title_ar'], fallback: 'الرائج'),
        subtitleEn: _str(item['subtitle_en'], fallback: ''),
        subtitleAr: _str(item['subtitle_ar'], fallback: ''),
        imageHint: _str(item['image_hint'], fallback: ''),
        category: _str(item['category'], fallback: null),
      ));
    }
    while (out.length < 4) {
      out.add(_fallbackTrendingItem(out.length));
    }
    return out;
  }

  static List<ExploreTrendingItem> _fallbackTrending() {
    return List.generate(4, (i) => _fallbackTrendingItem(i));
  }

  static ExploreTrendingItem _fallbackTrendingItem(int i) {
    const items = [
      ExploreTrendingItem(
        titleEn: 'Commodity analysis',
        titleAr: 'تحليل السلع',
        subtitleEn: 'Gold and oil',
        subtitleAr: 'الذهب والنفط',
        imageHint: 'winner',
        category: 'markets',
      ),
      ExploreTrendingItem(
        titleEn: 'Market news',
        titleAr: 'أخبار السوق',
        subtitleEn: 'Top economic headlines',
        subtitleAr: 'أبرز العناوين الاقتصادية',
        imageHint: 'sauvage',
        category: 'markets',
      ),
      ExploreTrendingItem(
        titleEn: 'Investor portfolio',
        titleAr: 'محفظة المستثمر',
        subtitleEn: 'Risk and reward management',
        subtitleAr: 'إدارة المخاطر والعوائد',
        imageHint: 'mic',
        category: 'products',
      ),
      ExploreTrendingItem(
        titleEn: 'Highest influencer',
        titleAr: 'أعلى المؤثرين',
        subtitleEn: 'Top of the year',
        subtitleAr: 'لعام كامل',
        imageHint: 'borge',
        category: 'influencers',
      ),
    ];
    return items[i % items.length];
  }

  // ---------- Discover tiles ----------

  static List<ExploreDiscoverItem> _parseDiscover(dynamic raw) {
    if (raw is! List || raw.length < 4) return _fallbackDiscover();
    final out = <ExploreDiscoverItem>[];
    final types = ['companies', 'products', 'influencers', 'reports'];
    for (var i = 0; i < raw.length && out.length < 4; i++) {
      final item = raw[i];
      if (item is! Map<String, dynamic>) continue;
      out.add(ExploreDiscoverItem(
        type: _str(item['type'], fallback: types[out.length % types.length]),
        titleEn: _str(item['title_en'], fallback: _discoverTitlesEn[out.length % 4]),
        titleAr: _str(item['title_ar'], fallback: _discoverTitlesAr[out.length % 4]),
        subtitleEn: _str(item['subtitle_en'], fallback: _discoverSubsEn[out.length % 4]),
        subtitleAr: _str(item['subtitle_ar'], fallback: _discoverSubsAr[out.length % 4]),
      ));
    }
    while (out.length < 4) {
      out.add(_fallbackDiscoverItem(out.length));
    }
    return out;
  }

  static List<ExploreDiscoverItem> _fallbackDiscover() {
    return List.generate(4, (i) => _fallbackDiscoverItem(i));
  }

  static ExploreDiscoverItem _fallbackDiscoverItem(int i) {
    return ExploreDiscoverItem(
      type: _discoverTypes[i],
      titleEn: _discoverTitlesEn[i],
      titleAr: _discoverTitlesAr[i],
      subtitleEn: _discoverSubsEn[i],
      subtitleAr: _discoverSubsAr[i],
    );
  }

  static const _discoverTypes = ['companies', 'products', 'influencers', 'reports'];

  static const _discoverTitlesEn = [
    'Discover Companies',
    'Discover Products',
    'Discover Influencers',
    'Discover Reports',
  ];

  static const _discoverTitlesAr = [
    'اكتشف الشركات',
    'اكتشف المنتجات',
    'اكتشف المؤثرين',
    'اكتشف التقارير',
  ];

  static const _discoverSubsEn = [
    'Browse brands & firms',
    'Track product launches',
    'Find top creators',
    'Read market reports',
  ];

  static const _discoverSubsAr = [
    'تصفح العلامات التجارية',
    'تتبع إصدارات المنتجات',
    'ابحث عن أبرز المؤثرين',
    'اقرأ تقارير السوق',
  ];

  // ---------- Recent investigations ----------

  static List<ExploreRecentItem> _parseRecent(dynamic raw) {
    if (raw is! List || raw.isEmpty) return _fallbackRecent();
    final out = <ExploreRecentItem>[];
    for (var i = 0; i < raw.length && out.length < 4; i++) {
      final item = raw[i];
      if (item is! Map<String, dynamic>) continue;
      final styleStr = _str(item['status_style'], fallback: 'completed');
      out.add(ExploreRecentItem(
        titleEn: _str(item['title_en'], fallback: 'Investigation'),
        titleAr: _str(item['title_ar'], fallback: 'تحقيق'),
        subtitleEn: _str(item['subtitle_en'], fallback: ''),
        subtitleAr: _str(item['subtitle_ar'], fallback: ''),
        time: _str(item['time'], fallback: '2h'),
        statusLabelEn: _str(item['status_label_en'], fallback: 'Completed'),
        statusLabelAr: _str(item['status_label_ar'], fallback: 'مكتمل'),
        statusStyle: _parseStatusStyle(styleStr),
        imageHint: _str(item['image_hint'], fallback: ''),
        brandDomain: _cleanDomain(item['domain']),
      ));
    }
    while (out.length < 2) {
      out.add(_fallbackRecentItem(out.length));
    }
    return out;
  }

  static List<ExploreRecentItem> _fallbackRecent() {
    return List.generate(2, (i) => _fallbackRecentItem(i));
  }

  static ExploreRecentItem _fallbackRecentItem(int i) {
    const items = [
      ExploreRecentItem(
        titleEn: 'Lattafa Asad Analysis',
        titleAr: 'تحليل عطر عطر أسد',
        subtitleEn: 'Perfume market share',
        subtitleAr: 'حصة سوق العطور',
        time: '2h',
        statusLabelEn: 'Completed',
        statusLabelAr: 'مكتمل',
        statusStyle: ExploreStatusStyle.completed,
        imageHint: 'parfum',
        brandDomain: null,
      ),
      ExploreRecentItem(
        titleEn: 'Dior Sauvage Trend',
        titleAr: 'اتجاه ديور سافاج',
        subtitleEn: 'Social media buzz',
        subtitleAr: 'التفاعل على وسائل التواصل',
        time: '5h',
        statusLabelEn: 'Quick Answer',
        statusLabelAr: 'إجابة سريعة',
        statusStyle: ExploreStatusStyle.quickAnswer,
        imageHint: 'sauvage',
        brandDomain: null,
      ),
    ];
    return items[i % items.length];
  }

  static ExploreStatusStyle _parseStatusStyle(String s) {
    switch (s.toLowerCase()) {
      case 'completed':
        return ExploreStatusStyle.completed;
      case 'quickanswer':
      case 'quick_answer':
        return ExploreStatusStyle.quickAnswer;
      case 'analyzing':
        return ExploreStatusStyle.analyzing;
      case 'paused':
        return ExploreStatusStyle.paused;
      default:
        return ExploreStatusStyle.completed;
    }
  }

  // ---------- Helpers ----------

  static String _str(dynamic v, {String? fallback}) {
    if (v is String && v.trim().isNotEmpty) {
      return normalizeDigits(v.trim());
    }
    return fallback ?? '';
  }

  static String? _cleanDomain(dynamic raw) {
    if (raw is! String) return null;
    var s = raw.trim().toLowerCase();
    if (s.isEmpty) return null;
    if (s.startsWith('https://')) s = s.substring(8);
    if (s.startsWith('http://')) s = s.substring(7);
    if (s.startsWith('www.')) s = s.substring(4);
    final slash = s.indexOf('/');
    if (slash != -1) s = s.substring(0, slash);
    final q = s.indexOf('?');
    if (q != -1) s = s.substring(0, q);
    final colon = s.indexOf(':');
    if (colon != -1) s = s.substring(0, colon);

    final hostRe = RegExp(r'^[a-z0-9-]+(\.[a-z0-9-]+)+$');
    if (!hostRe.hasMatch(s)) return null;
    return s;
  }

  /// Normalises any non-ASCII digits back to ASCII 0-9.
  static String normalizeDigits(String v) {
    const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
    const farsi = '۰۱۲۳۴۵۶۷۸۹';
    var out = v;
    for (var i = 0; i < 10; i++) {
      out = out.replaceAll(arabicIndic[i], '$i');
      out = out.replaceAll(farsi[i], '$i');
    }
    return out;
  }
}
