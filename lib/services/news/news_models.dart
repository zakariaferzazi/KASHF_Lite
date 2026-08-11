import 'package:flutter/foundation.dart';

/// High-level topical categories the Home / Explore carousel can
/// show. Each one maps to a Google News RSS search query — one
/// for English and one for Arabic — so the feed stays relevant
/// regardless of the user's selected language.
enum NewsTopic {
  fashion(
    label: 'Fashion',
    labelAr: 'الموضة',
    queryEn: '(fashion OR couture OR runway OR "fashion week" OR '
        '"street style" OR collection OR lookbook OR designer OR '
        '"fashion brand" OR "fashion show" OR model OR "ready to wear" OR '
        'luxury OR apparel) '
        '-weather -election -football -soccer -match -concert',
    queryAr: '(الموضة OR الأزياء OR كوتور OR أسبوع_الموضة OR '
        'تصميم_أزياء OR مجموعة_أزياء OR مصمم_أزياء OR دار_أزياء OR '
        'عارضة OR فاشن OR ملابس OR أزياء_فاخرة) '
        '-طقس -انتخابات -كرة_قدم -مباراة -حفل',
  ),
  beauty(
    label: 'Beauty',
    labelAr: 'الجمال',
    queryEn: '(beauty OR makeup OR cosmetics OR skincare OR '
        '"beauty brand" OR lipstick OR foundation OR serum OR mascara OR '
        'fragrance OR "beauty launch" OR "beauty routine") '
        '-weather -election -football -soccer -match -concert',
    queryAr: '(الجمال OR مكياج OR مستحضرات_التجميل OR عناية_بالبشرة OR '
        'أحمر_شفاه OR كريم_أساس OR سيروم OR ماسكارا OR إطلاق_جمالي OR '
        'روتين_جمال OR علامة_جمالية) '
        '-طقس -انتخابات -كرة_قدم -مباراة -حفل',
  ),
  influencers(
    label: 'Influencers',
    labelAr: 'المؤثرين',
    queryEn: '(influencer OR creator OR YouTuber OR TikToker OR '
        'streamer OR "content creator" OR "brand deal" OR '
        'sponsorship OR endorsement OR collaboration OR ambassador) '
        '-weather -storm -election -football -match -concert',
    queryAr: '(مؤثر OR صانع_محتوى OR يوتيوبر OR تيك_توك OR '
        'ستريمر OR مؤثرون OR ترويج OR رعاية OR تعاون_تجاري OR '
        'سفير_علامة) '
        '-طقس -عاصفة -انتخابات -كرة_قدم -مباراة -حفل',
  ),
  fragrances(
    label: 'Fragrances',
    labelAr: 'العطور',
    queryEn: '(fragrance OR perfume OR parfum OR "eau de parfum" OR '
        '"eau de toilette" OR cologne OR oud OR "perfume launch" OR '
        '"new scent" OR "perfume brand" OR "niche perfume" OR attar) '
        '-weather -election -football -soccer -match -concert',
    queryAr: '(عطر OR عطور OR Parfum OR ماء_العطر OR كولونيا OR '
        'عود OR إطلاق_عطر OR عطر_جديد OR دار_عطور OR عطر_فاخر OR '
        'أتر OR عطور_فخمة) '
        '-طقس -انتخابات -كرة_قدم -مباراة -حفل',
  );

  const NewsTopic({
    required this.label,
    required this.labelAr,
    required this.queryEn,
    required this.queryAr,
  });

  /// English label shown in the chip row.
  final String label;

  /// Arabic label for RTL layouts.
  final String labelAr;

  /// Free-text query sent to Google News RSS search for English
  /// locales. We use `-` (exclude) terms to drop weather /
  /// election / sports / entertainment noise.
  final String queryEn;

  /// Free-text query sent to Google News RSS search for Arabic
  /// locales. Kept tight so it stays focused on the local beat.
  final String queryAr;

  /// Returns the right query string for [languageCode]. Defaults
  /// to the English variant for unknown languages so we always
  /// emit a valid query.
  String queryFor(String languageCode) {
    if (languageCode.toLowerCase().startsWith('ar')) return queryAr;
    return queryEn;
  }
}

/// A single trending news article pulled from Google News RSS.
///
/// We do NOT invent images; the [imageUrl] comes from the feed's
/// own `<media:content>` / `<media:thumbnail>` / `<enclosure>`
/// metadata. If an article has no usable image the carousel
/// simply skips it instead of falling back to a fake asset.
@immutable
class NewsArticle {
  const NewsArticle({
    required this.title,
    required this.url,
    required this.imageUrl,
    required this.source,
    required this.publishedAt,
  });

  final String title;
  /// The publisher article URL we want to open.
  final String url;
  /// Direct image URL (https://...).
  final String imageUrl;
  /// Publisher name (e.g. "BBC News", "Reuters").
  final String source;
  /// Publish time as ISO-8601 string when available; '' otherwise.
  final String publishedAt;

  /// JSON serialisation used by the disk cache. We keep the shape
  /// flat so it round-trips cleanly through `SharedPreferences`.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'url': url,
        'imageUrl': imageUrl,
        'source': source,
        'publishedAt': publishedAt,
      };

  static NewsArticle fromJson(Map<String, dynamic> json) => NewsArticle(
        title: (json['title'] as String?) ?? '',
        url: (json['url'] as String?) ?? '',
        imageUrl: (json['imageUrl'] as String?) ?? '',
        source: (json['source'] as String?) ?? '',
        publishedAt: (json['publishedAt'] as String?) ?? '',
      );
}

/// Top-level payload returned by the news service.
@immutable
class NewsFeed {
  const NewsFeed({required this.articles, this.topic});

  final List<NewsArticle> articles;

  /// The topic the feed was fetched for (if any).
  final NewsTopic? topic;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'topic': topic?.name,
        'articles': articles.map((a) => a.toJson()).toList(),
      };

  static NewsFeed fromJson(Map<String, dynamic> json) {
    final articlesRaw = json['articles'];
    final articles = articlesRaw is List
        ? articlesRaw
            .whereType<Map<String, dynamic>>()
            .map(NewsArticle.fromJson)
            .toList()
        : <NewsArticle>[];
    final topicName = json['topic'] as String?;
    final topic = NewsTopic.values.firstWhere(
      (t) => t.name == topicName,
      orElse: () => NewsTopic.fashion,
    );
    return NewsFeed(articles: articles, topic: topic);
  }
}