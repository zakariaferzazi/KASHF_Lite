import 'package:flutter/foundation.dart';

/// High-level topical categories the Explore carousel can show.
/// Each one maps to a Google News RSS search query that filters
/// for articles relevant to brand-investigation use-cases.
enum NewsTopic {
  companies(
    label: 'Companies',
    labelAr: 'الشركات',
    // Tight, brand-focused queries. We use `-` (exclude) terms to
    // drop regional war / weather / sports / entertainment noise.
    query: '(brand OR company OR corporate OR startup OR firm) '
        '(acquisition OR earnings OR merger OR IPO OR layoff OR '
        'expansion OR partnership OR valuation OR antitrust OR '
        'regulator OR investigation OR quarterly OR revenue OR '
        'subsidiary OR factory OR supply chain) '
        '-weather -storm -temperature -hurricane -election '
        '-football -soccer -match -concert -festival -celebrity',
  ),
  brands(
    label: 'Brands',
    labelAr: 'العلامات التجارية',
    query: '(brand OR brands OR label OR trademark) '
        '(campaign OR sponsorship OR ambassador OR endorsement OR '
        'rebrand OR recall OR boycott OR controversy OR logo OR '
        'collaboration OR launch OR partnership) '
        '-weather -storm -election -football -soccer -celebrity',
  ),
  products(
    label: 'Products',
    labelAr: 'المنتجات',
    query: '(product OR products OR gadget OR device) '
        '(launch OR release OR unveiling OR debut OR rollout OR '
        'recall OR discontinue OR announcement OR specs OR review OR '
        'preorder OR shipping) '
        '-weather -storm -election -football -celebrity',
  ),
  influencers(
    label: 'Influencers',
    labelAr: 'المؤثرون',
    query: '(influencer OR creator OR YouTuber OR TikToker OR '
        'streamer OR "content creator" OR "brand deal") '
        '(sponsorship OR partnership OR campaign OR endorsement OR '
        'controversy OR apology OR drama OR brand OR brand deal) '
        '-weather -storm -election -football -match -concert',
  ),
  trends(
    label: 'Trends',
    labelAr: 'المواضيع الرائجة',
    query: '(trend OR viral OR trending OR buzz OR meme OR hashtag) '
        '("social media" OR TikTok OR Instagram OR YouTube OR '
        'Twitter OR X OR Reddit OR "going viral") '
        '-weather -election -football -soccer -match',
  ),
  businessProblems(
    label: 'Business problems',
    labelAr: 'أزمات الشركات',
    query: '(company OR business OR corporate OR brand OR firm) '
        '(lawsuit OR scandal OR fraud OR boycott OR investigation OR '
        'fine OR ban OR shortage OR "data breach" OR recall OR '
        'controversy OR protest OR strike OR whistleblower OR '
        'bankruptcy OR "class action") '
        '-weather -storm -election -football -soccer -celebrity',
  );

  const NewsTopic({
    required this.label,
    required this.labelAr,
    required this.query,
  });

  /// English label shown in the chip row.
  final String label;

  /// Arabic label for RTL layouts.
  final String labelAr;

  /// Free-text query sent to Google News RSS search. We keep it
  /// tight on purpose — overly broad queries return celebrity /
  /// entertainment articles that aren't useful for brand
  /// investigation.
  final String query;
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
      orElse: () => NewsTopic.companies,
    );
    return NewsFeed(articles: articles, topic: topic);
  }
}