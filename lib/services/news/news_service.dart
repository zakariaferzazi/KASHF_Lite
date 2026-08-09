import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../ai/disk_cache.dart';
import 'news_models.dart';

export 'news_models.dart' show NewsArticle, NewsFeed, NewsTopic;

/// Fetches trending articles from Google News RSS for a given
/// (country, language) pair, then resolves each article's main
/// image by scraping the publisher's HTML page.
///
/// ## Pipeline
///
/// 1. Fetch the Google News RSS feed and pull up to [fetchHeadroom]
///    raw `<item>` entries.
/// 2. For each item, resolve the Google News redirect URL
///    (`https://news.google.com/rss/articles/...`) to the original
///    publisher URL via HTTP redirects.
/// 3. Fetch the publisher HTML with a realistic browser User-Agent.
/// 4. Extract the main image, checking in priority order:
///       a) `<meta property="og:image">`
///       b) `<meta property="og:image:url">`
///       c) `<meta name="twitter:image">`
///       d) `<meta name="twitter:image:src">`
///       e) JSON-LD structured data (`image` / `image.url` /
///          `image.contentUrl`)
/// 5. Resolve relative image URLs against the publisher's base URL.
/// 6. Validate the image URL via a HEAD request (HTTP 2xx and
///    image MIME type).
/// 7. Repeat until we have exactly [targetCount] articles with
///    valid images, or we run out of items.
///
/// ## Caching
///
/// * Per-locale feed cache ([_cacheTtl]): avoids re-fetching the
///   RSS itself.
/// * Per-URL HTML cache ([_htmlCacheTtl]): avoids re-scraping the
///   same publisher page on repeat carousel opens.
class NewsService {
  NewsService({
    http.Client? client,
    Duration cacheTtl = const Duration(minutes: 10),
    Duration htmlCacheTtl = const Duration(minutes: 30),
    DiskCache? diskCache,
  })  : _client = client ?? http.Client(),
        _cacheTtl = cacheTtl,
        _htmlCacheTtl = htmlCacheTtl,
        _disk = diskCache ?? _sharedDiskCache;

  static final NewsService instance = NewsService();

  final http.Client _client;
  final Duration _cacheTtl;
  final Duration _htmlCacheTtl;
  DiskCache? _disk;
  static DiskCache? _sharedDiskCache;

  /// Wires the shared disk-cache used to persist feeds across app
  /// restarts. Called once from `main.dart` after
  /// [SharedPreferences] is ready.
  static void initDiskCache(DiskCache cache) {
    _sharedDiskCache = cache;
    instance._disk = cache;
  }

  /// Number of articles we actually render in the carousel.
  static const int targetCount = 7;

  /// Pull this many raw RSS items before filtering by image
  /// availability. Most publisher pages expose a usable image,
  /// but some fail / 403 / return empty OG metadata, so we keep
  /// headroom.
  static const int fetchHeadroom = 20;

  /// Hard upper bound on per-publisher HTTP time so a single
  /// slow site can't stall the carousel.
  static const Duration _fetchTimeout = Duration(seconds: 8);

  /// Tighter timeout used for the per-image URL validation HEAD
  /// requests inside `_looksLikeImage`. These probes are run in
  /// parallel and we only need a yes/no answer, so anything
  /// slower than [imageValidationTimeout] is treated as "not an
  /// image" and we move on. Keeps a single slow CDN from blowing
  /// the entire refresh budget.
  static const Duration imageValidationTimeout = Duration(seconds: 3);

  /// Per-publisher HTML cache. Key = article URL (resolved).
  final Map<String, _HtmlCacheEntry> _htmlCache = <String, _HtmlCacheEntry>{};

  /// Per-locale RSS cache. Key = "$language|$country".
  final Map<String, NewsCacheEntry> _cache = <String, NewsCacheEntry>{};

  /// Shared RNG used to shuffle the resolved article pool so the
  /// carousel order varies between refreshes.
  final math.Random _rng = math.Random();

  /// Realistic browser User-Agent. Many publisher sites block
  /// generic `dart:io` UA strings.
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

  /// Headers sent on every HTTP request. We include a couple of
  /// common browser-y headers so publisher WAFs don't flag us.
  static Map<String, String> get _headers => <String, String>{
        'User-Agent': _userAgent,
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      };

  /// Cache lookup helper exposed to the controller layer. Returns
  /// null on miss / expiry. Pass [topic] to look up a per-topic
  /// cache slot.
  NewsCacheEntry? cacheFor({
    required String language,
    required String country,
    NewsTopic? topic,
  }) {
    final key = topic == null
        ? '$language|${country.toUpperCase()}|top'
        : '$language|${country.toUpperCase()}|topic:${topic.name}';
    final entry = _cache[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.at) > _cacheTtl) return null;
    return entry;
  }

  /// Hydrate every cache slot from disk. Called once at app
  /// startup so the trending carousel shows previously fetched
  /// articles immediately after a restart, without hitting the
  /// network. Entries older than [diskTtl] are ignored so we
  /// eventually re-fetch even when the user never taps refresh.
  Future<void> hydrateFromDisk({
    required String language,
    required String country,
    Duration diskTtl = const Duration(days: 3),
  }) async {
    final disk = _disk;
    if (disk == null) return;
    final ctry = country.toUpperCase();
    // Top stories + 6 topic slots.
    final keys = <String>[
      '$language|$ctry|top',
      for (final t in NewsTopic.values)
        '$language|$ctry|topic:${t.name}',
    ];
    for (final key in keys) {
      final raw = await disk.readJson(key, ttl: diskTtl);
      if (raw == null) continue;
      try {
        final feed = NewsFeed.fromJson(raw);
        _cache[key] = NewsCacheEntry(at: DateTime.now(), feed: feed);
      } catch (e) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('[NewsService] hydrate $key failed: $e');
        }
      }
    }
  }

  void clearCache() {
    _cache.clear();
    _htmlCache.clear();
  }

  /// Locale fallback chain: user-locale feed → same-country
  /// English → global English. Google News can return a sparse
  /// feed for an exotic locale pair, so we always have a backup.
  List<({String country, String ceid})> _feedCandidates({
    required String language,
    required String country,
  }) {
    final candidates = <({String country, String ceid})>[];
    final uc = country.toUpperCase();
    candidates.add((country: uc, ceid: '$uc:$language'));
    candidates.add((country: uc, ceid: '$uc:en'));
    candidates.add((country: 'US', ceid: 'US:en'));
    return candidates;
  }

  /// Fetches up to [targetCount] trending articles for [language]
  /// and [country]. Results are cached for [_cacheTtl].
  ///
  /// When [topic] is non-null we hit Google News' **search**
  /// endpoint with a curated query instead of the generic
  /// top-stories feed. This is what powers the category-filtered
  /// carousel (Companies / Brands / Products / Influencers /
  /// Trends / Business problems).
  Future<NewsFeed> fetchTrending({
    required String language,
    required String country,
    NewsTopic? topic,
    bool forceRefresh = false,
    /// When set, stops image-resolve early once we have at least
    /// [maxArticles] valid entries. The carousel defaults to the
    /// standard [targetCount] (7); event-style callers pass 1 to
    /// keep refresh latency low.
    int? maxArticles,
  }) async {
    final cacheKey = topic == null
        ? '$language|${country.toUpperCase()}|top'
        : '$language|${country.toUpperCase()}|topic:${topic.name}';
    final now = DateTime.now();
    final cached = _cache[cacheKey];
    if (!forceRefresh && cached != null && now.difference(cached.at) < _cacheTtl) {
      // ignore: avoid_print
      print('[NewsService] Cache hit for $cacheKey (${cached.feed.articles.length} articles)');
      return cached.feed;
    }

    final candidates = _feedCandidates(language: language, country: country);
    NewsFeed? best;
    for (final c in candidates) {
      try {
        final url = topic == null
            ? Uri.parse(
                'https://news.google.com/rss?hl=$language&gl=${c.country}&ceid=${c.ceid}',
              )
            : _searchUrl(
                query: topic.query,
                language: language,
                ceid: c.ceid,
                country: c.country,
              );
        final res = await _client.get(url, headers: _headers).timeout(_fetchTimeout);
        if (res.statusCode != 200) continue;
        final rssItems = _parseRss(res.body, limit: fetchHeadroom);
        if (rssItems.isEmpty) continue;
        // ignore: avoid_print
        print(
            '[NewsService] Fetched ${rssItems.length} RSS items from ${c.ceid} (topic=${topic?.name ?? "top"}):');
        for (final r in rssItems) {
          // ignore: avoid_print
          print('[NewsService]   RSS[${rssItems.indexOf(r)}] "${r.title}" (source=${r.source})');
        }
        final resolved = await _resolveArticles(rssItems, maxArticles: maxArticles);
        final feed = NewsFeed(articles: resolved, topic: topic);
        final successAt = maxArticles ?? targetCount;
        if (feed.articles.length >= successAt) {
          // ignore: avoid_print
          print('[NewsService] Resolved ${feed.articles.length}/$targetCount articles for topic=${topic?.name ?? "top"}');
          _cache[cacheKey] = NewsCacheEntry(at: now, feed: feed);
          _persistFeed(cacheKey, feed);
          return feed;
        }
        // Keep the best partial result so we can still return
        // something useful even if every fallback chain only
        // yields a handful of valid articles.
        best ??= feed;
      } catch (e, st) {
        if (kDebugMode) {
          developer.log('fetchTrending failed for ${c.ceid}: $e',
              name: 'NewsService');
          developer.log('$st', name: 'NewsService');
        }
      }
    }

    final empty = best ?? NewsFeed(articles: const <NewsArticle>[], topic: topic);
    _cache[cacheKey] = NewsCacheEntry(at: now, feed: empty);
    if (best != null) {
      // Only persist non-empty results so we never overwrite a
      // good on-disk feed with a transient empty fallback.
      _persistFeed(cacheKey, empty);
    }
    return empty;
  }

  /// Fire-and-forget disk write for a freshly fetched feed.
  /// Failures are silent; the in-memory cache is already up to
  /// date.
  void _persistFeed(String key, NewsFeed feed) {
    final disk = _disk;
    if (disk == null) return;
    // ignore: unawaited_futures
    disk.writeJson(key, feed.toJson());
  }

  /// Builds the Google News search-RSS URL for a given free-text
  /// query. We URL-encode the query so spaces / parentheses /
  /// quoted phrases survive intact.
  Uri _searchUrl({
    required String query,
    required String language,
    required String country,
    required String ceid,
  }) {
    final url = Uri.parse(
      'https://news.google.com/rss/search?q=${Uri.encodeQueryComponent(query)}'
      '&hl=$language&gl=$country&ceid=$ceid',
    );
    // ignore: avoid_print
    print('[NewsService] Search URL: $url');
    return url;
  }

  /// Resolves each raw RSS item into a [NewsArticle] with a
  /// valid image URL. We try to resolve the entire pool (up to
  /// [fetchHeadroom]) so the final carousel can be picked as a
  /// random [targetCount] of all valid articles — that way the
  /// user sees a fresh mix on every refresh instead of the same
  /// first-N items every time.
  ///
  /// Performance: image resolution is the slowest step (one HTTP
  /// HEAD per candidate). We resolve up to [resolveConcurrency]
  /// items in parallel so the round-trips overlap. We also stop
  /// early once we've produced [maxArticles] valid results — the
  /// market-events controller only needs one article per topic,
  /// so there is no reason to churn through 20 candidates.
  Future<List<NewsArticle>> _resolveArticles(
    List<_RawRssItem> items, {
    int? maxArticles,
    int resolveConcurrency = 6,
  }) async {
    final cap = maxArticles ?? targetCount;
    final resolved = <NewsArticle>[];
    // Track raw-title → resolved-article so we can stop early.
    final pending = <_RawRssItem>[];
    for (final raw in items) {
      if (resolved.length >= cap) break;
      pending.add(raw);
    }

    // Process in batches of [resolveConcurrency] so we don't
    // slam every publisher at once, but still overlap the slow
    // round-trips.
    for (var i = 0; i < pending.length; i += resolveConcurrency) {
      if (resolved.length >= cap) break;
      final batch = pending.skip(i).take(resolveConcurrency).toList();
      final results = await Future.wait(
        batch.map((raw) async {
          try {
            return await _resolveOne(raw);
          } catch (e) {
            // ignore: avoid_print
            print('[NewsService] Resolve failed for "${raw.title}": $e');
            return null;
          }
        }),
      );
      for (final a in results) {
        if (a == null) continue;
        resolved.add(a);
        if (resolved.length >= cap) break;
      }
    }

    if (resolved.length <= targetCount) return resolved;
    final shuffled = <NewsArticle>[...resolved]..shuffle(_rng);
    return shuffled.take(targetCount).toList(growable: false);
  }

  /// Resolves one RSS item to a [NewsArticle]. Returns null if
  /// no usable image can be obtained.
  ///
  /// The Google News RSS `<source url="...">` attribute gives
  /// only the publisher's DOMAIN (e.g. `https://www.cbsnews.com`),
  /// NOT the full article path. To get the full article URL we
  /// MUST follow the redirect on the Google News `<link>` (e.g.
  /// `https://news.google.com/rss/articles/CBMi...`), which
  /// resolves to the canonical article URL (e.g.
  /// `https://www.cbsnews.com/news/joe-biden-cancer...`).
  ///
  /// We then fetch HTML from that full article URL and extract
  /// the article's main image (JSON-LD first, then og:image,
  /// twitter:image, with logo filtering).
  Future<NewsArticle?> _resolveOne(_RawRssItem raw) async {
    // ignore: avoid_print
    print('[NewsService] RESOLVE "${raw.title}" (source=${raw.source})');

    // 1. Resolve the FULL article URL by following the Google
    //    News redirect. `<source url>` only contains the publisher
    //    domain, which is not enough to fetch the real article.
    final articleUrl = await _resolveGoogleRedirect(raw.link);
    if (articleUrl.isEmpty || !articleUrl.startsWith('http')) {
      // ignore: avoid_print
      print('[NewsService]   [1] no article URL; skipping');
      return null;
    }
    // ignore: avoid_print
    print('[NewsService]   [1] article=$articleUrl');

    // 2. Fetch HTML from the real article URL.
    final html = await _fetchHtml(articleUrl);
    if (html == null || html.isEmpty) {
      // ignore: avoid_print
      print('[NewsService]   [2] no HTML from article; skipping');
      return null;
    }
    // ignore: avoid_print
    print('[NewsService]   [2] HTML length=${html.length}');

    // 3. Extract main image using the article URL as base for
    //    resolving relative URLs.
    final candidates = _extractImageCandidates(html, baseUrl: articleUrl);
    // ignore: avoid_print
    print('[NewsService]   [3] candidates=$candidates');
    if (candidates.isEmpty) {
      // ignore: avoid_print
      print('[NewsService]   [3] no image candidates; skipping');
      return null;
    }

    // Step A: cheap URL-string logo filter (no network) for all
    // candidates first — drops everything that can't possibly
    // be an article image.
    final filtered = <String>[];
    for (final c in candidates) {
      if (!_isLikelyArticleImage(c)) {
        // ignore: avoid_print
        print('[NewsService]   [4] logo-filter skip: $c');
        continue;
      }
      // Flutter's web engine can't decode AVIF; the resolver
      // hands the URL to `Image.network` later, which throws an
      // "Invalid image data" exception. Drop AVIF candidates
      // proactively so the carousel never tries to render one.
      if (_isUnsupportedAvif(c)) {
        // ignore: avoid_print
        print('[NewsService]   [4] AVIF unsupported: $c');
        continue;
      }
      filtered.add(c);
    }

    if (filtered.isEmpty) {
      // ignore: avoid_print
      print('[NewsService]   [4] no candidates survived logo-filter; skipping');
      return null;
    }

    // Cap the validation work so a long og:image list can't
    // blow the refresh budget. The first valid image is what we
    // render, so we only need to find one.
    const maxValidate = 4;
    final toValidate = filtered.take(maxValidate).toList(growable: false);
    String? chosenImage;
    for (final c in toValidate) {
      // ignore: avoid_print
      print('[NewsService]   [4] validating: $c');
      if (await _looksLikeImage(c)) {
        chosenImage = c;
        // ignore: avoid_print
        print('[NewsService]   [4] VALID image: $c');
        break;
      } else {
        // ignore: avoid_print
        print('[NewsService]   [4] HTTP invalid: $c');
      }
    }
    if (chosenImage == null) {
      // ignore: avoid_print
      print('[NewsService]   [4] no valid image; skipping');
      return null;
    }

    return NewsArticle(
      title: raw.title,
      url: articleUrl,
      imageUrl: chosenImage,
      source: raw.source,
      publishedAt: raw.publishedAt,
    );
  }

  /// Returns `true` when [url] points to an AVIF asset. AVIF is
  /// broadly supported on Android/iOS, but Flutter's web engine
  /// and some older Skia builds refuse to decode it, surfacing
  /// "Invalid image data" exceptions at runtime. We filter it
  /// out here so the carousel only ever sees decodable assets.
  static bool _isUnsupportedAvif(String url) {
    final lower = url.toLowerCase();
    // Drop the query string before checking the path extension
    // so URLs like `foo.avif?v=1` still match.
    final qIdx = lower.indexOf('?');
    final path = qIdx == -1 ? lower : lower.substring(0, qIdx);
    return path.endsWith('.avif');
  }

  // ---------- URL resolution ----------

  /// Resolves a Google News article URL to the real publisher
  /// article URL.
///
/// Google News does NOT expose the publisher URL through a
/// plain 302 redirect. Instead, the tracking page embeds an
/// encrypted payload inside `<c-wiz data-p="...">`, which must
/// be POSTed to Google News's `batchexecute` RPC endpoint to
/// be decrypted.
///
/// Reference implementation (Python):
///   https://stackoverflow.com/a/79388987
///
/// Pipeline:
///   1. GET the Google News tracking page.
///   2. Extract the `data-p` attribute of `<c-wiz>`.
///   3. Parse the JSON array inside (Google prefixes it with
///      `%.@.` which we replace with the JS-equivalent
///      `["garturlreq",`).
///   4. POST `f.req=[[["Fbv4je", "<payload>", "null", "generic"]]]`
///      to `https://news.google.com/_/DotsSplashUi/data/batchexecute`.
///   5. Strip the leading `)]}'` XSSI guard, parse the JSON,
///      drill into `[0][2]`, parse that JSON, take `[1]` —
//      that's the real article URL.
  Future<String> _resolveGoogleRedirect(String googleUrl) async {
    if (googleUrl.isEmpty) return '';
    try {
      // Step 1: GET the tracking page.
      final res = await _client
          .get(Uri.parse(googleUrl), headers: _headers)
          .timeout(_fetchTimeout);
      if (res.statusCode != 200) {
        // ignore: avoid_print
        print('[NewsService]    tracking page status=${res.statusCode}');
        return '';
      }
      final html = res.body;

      // Step 2: pull the <c-wiz data-p="..."> payload.
      final dataP = _extractCWiZDataP(html);
      if (dataP == null || dataP.isEmpty) {
        // ignore: avoid_print
        print('[NewsService]    no <c-wiz data-p> on tracking page');
        return '';
      }

      // Step 3: fix the `%.@.` prefix and parse the inner array.
      // Google wraps it in `)]}'\n<actual JSON>`, similar to the
      // batchexecute response, so we normalise it before decoding.
      var raw = dataP;
      if (raw.startsWith(")]}'")) {
        raw = raw.substring(4).trim();
      }
      // `%.@.` is Google-internal shorthand for the JS opener
      // `["garturlreq",` so the data becomes a valid JSON array.
      final normalised = raw.replaceAll('%.@.', '["garturlreq",');
      final List<dynamic> outer;
      try {
        outer = jsonDecode(normalised) as List<dynamic>;
      } catch (e) {
        // ignore: avoid_print
        print('[NewsService]    failed to decode data-p: $e');
        return '';
      }
      // The published Python solution strips `obj[:-6] + obj[-2:]`
      // before serialising. We replicate that here.
      final stripped = [...outer.sublist(0, outer.length - 6), ...outer.sublist(outer.length - 2)];
      final encoded = jsonEncode(stripped);

      // Step 4: POST to the batchexecute RPC.
      final reqBody =
          'f.req=${Uri.encodeQueryComponent('[[["Fbv4je", ${jsonEncode(encoded)}, "null", "generic"]]]')}';
      final postRes = await _client
          .post(
            Uri.parse('https://news.google.com/_/DotsSplashUi/data/batchexecute'),
            headers: <String, String>{
              'content-type': 'application/x-www-form-urlencoded;charset=UTF-8',
              'user-agent': _userAgent,
            },
            body: reqBody,
          )
          .timeout(_fetchTimeout);
      if (postRes.statusCode != 200) {
        // ignore: avoid_print
        print('[NewsService]    batchexecute status=${postRes.statusCode}');
        return '';
      }

      // Step 5: decode the response.
      var respText = postRes.body;
      if (respText.startsWith(")]}'")) {
        respText = respText.substring(4).trim();
      }
      final List<dynamic> outerResp;
      try {
        outerResp = jsonDecode(respText) as List<dynamic>;
      } catch (e) {
        // ignore: avoid_print
        print('[NewsService]    failed to decode batchexecute response: $e');
        return '';
      }
      if (outerResp.isEmpty || outerResp[0] is! List) return '';
      final inner = outerResp[0] as List<dynamic>;
      if (inner.length < 3 || inner[2] is! String) return '';
      final List<dynamic> payloadArr;
      try {
        payloadArr = jsonDecode(inner[2] as String) as List<dynamic>;
      } catch (_) {
        return '';
      }
      if (payloadArr.length < 2 || payloadArr[1] is! String) return '';
      final articleUrl = payloadArr[1] as String;
      if (articleUrl.isEmpty || articleUrl.contains('news.google.com')) {
        return '';
      }
      return articleUrl;
    } catch (e) {
      // ignore: avoid_print
      print('[NewsService]    redirect fetch failed: $e');
      return '';
    }
  }

  /// Extracts the `data-p` attribute of the first `<c-wiz>`
  /// element. We use a regex instead of an HTML parser to keep
  /// the service dependency-free. The attribute is HTML-encoded
  /// (e.g. `&quot;` instead of `"`), so we decode the standard
  /// XML/HTML entities before returning.
  String? _extractCWiZDataP(String html) {
    final re = RegExp(
      '<c-wiz\\b[^>]*\\bdata-p\\s*=\\s*"([^"]+)"',
      caseSensitive: false,
    );
    final m = re.firstMatch(html);
    final raw = m?.group(1) ??
        // Reverse attribute order.
        RegExp(
          '<c-wiz\\b[^>]*\\bdata-p\\s*=\\s*\'([^\']+)\'',
          caseSensitive: false,
        ).firstMatch(html)?.group(1);
    if (raw == null) return null;
    return _decodeHtmlEntities(raw);
  }

  /// Decodes the small set of HTML entities Google uses inside
  /// `data-p`. We avoid pulling in a full HTML parser because
  /// the entity set is tiny and well-defined.
  String _decodeHtmlEntities(String s) {
    return s
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ');
  }

  // ---------- HTML fetch + cache ----------

  Future<String?> _fetchHtml(String url) async {
    final now = DateTime.now();
    final entry = _htmlCache[url];
    if (entry != null && now.difference(entry.at) < _htmlCacheTtl) {
      return entry.html;
    }
    try {
      final res = await _client
          .get(Uri.parse(url), headers: _headers)
          .timeout(_fetchTimeout);
      if (res.statusCode != 200) return null;
      _htmlCache[url] = _HtmlCacheEntry(at: now, html: res.body);
      return res.body;
    } catch (_) {
      return null;
    }
  }

  // ---------- Image extraction ----------

  /// Returns image URLs in priority order. The first that
  /// survives [_looksLikeImage] and passes [_isLikelyArticleImage]
  /// wins.
  List<String> _extractImageCandidates(String html, {required String baseUrl}) {
    final candidates = <String>[];

    // PRIORITY 1: JSON-LD structured data. Schema.org's
    // Article/image field reliably contains the actual article
    // image — NOT the site logo — because it's manually set by
    // the CMS for each article.
    final jsonLdImages = _extractJsonLdImages(html);
    for (final url in jsonLdImages) {
      candidates.add(_absolutize(url, baseUrl));
    }

    // PRIORITY 2: <meta property="og:image" content="...">
    // BUT many publishers put their site logo here instead of the
    // article image. We add the url to the list but mark it as
    // "likely-logo" so it is checked AFTER JSON-LD images.
    final og1 = _extractMetaContent(html, property: 'og:image');
    if (og1.isNotEmpty) candidates.add(_absolutize(og1, baseUrl));

    // PRIORITY 3: <meta property="og:image:url" content="...">
    final og2 = _extractMetaContent(html, property: 'og:image:url');
    if (og2.isNotEmpty) candidates.add(_absolutize(og2, baseUrl));

    // PRIORITY 4: <meta name="twitter:image" content="...">
    final tw1 = _extractMetaContent(html, name: 'twitter:image');
    if (tw1.isNotEmpty) candidates.add(_absolutize(tw1, baseUrl));

    // PRIORITY 5: <meta name="twitter:image:src" content="...">
    final tw2 = _extractMetaContent(html, name: 'twitter:image:src');
    if (tw2.isNotEmpty) candidates.add(_absolutize(tw2, baseUrl));

    // De-dupe while preserving order.
    final seen = <String>{};
    final out = <String>[];
    for (final c in candidates) {
      if (c.isEmpty) continue;
      if (seen.add(c)) out.add(c);
    }
    return out;
  }

  /// Extracts `<meta property="X" content="Y">` or
  /// `<meta name="X" content="Y">`. Handles attribute order
  /// independence (property/name before content). Most real-world
  /// publishers emit attributes in double quotes; we deliberately
  /// do not match the single-quote form here because it would
  /// require regex syntax that conflicts with Dart's raw-string
  /// quoting (and it's vanishingly rare in practice).
  String _extractMetaContent(String html, {String? property, String? name}) {
    final needle = property ?? name;
    if (needle == null) return '';
    final escaped = RegExp.escape(needle);
    final pattern = property != null
        ? '<meta\\s[^>]*property\\s*=\\s*"$escaped"[^>]*content\\s*=\\s*"([^"]+)"'
        : '<meta\\s[^>]*name\\s*=\\s*"$escaped"[^>]*content\\s*=\\s*"([^"]+)"';
    final m = RegExp(pattern, caseSensitive: false).firstMatch(html);
    if (m == null) {
      // Reverse attribute order: content before property/name.
      final reverse = property != null
          ? '<meta\\s[^>]*content\\s*=\\s*"([^"]+)"[^>]*property\\s*=\\s*"$escaped"'
          : '<meta\\s[^>]*content\\s*=\\s*"([^"]+)"[^>]*name\\s*=\\s*"$escaped"';
      final m2 = RegExp(reverse, caseSensitive: false).firstMatch(html);
      if (m2 != null) return (m2.group(1) ?? '').trim();
      return '';
    }
    return (m.group(1) ?? '').trim();
  }

  /// Walks every JSON-LD `<script type="application/ld+json">`
  /// blob in the page and extracts any `image` value (string,
  /// list, or object with `url` / `contentUrl`). Some publishers
  /// expose the main article image only here.
  List<String> _extractJsonLdImages(String html) {
    final out = <String>[];
    // Match the opening `<script type="application/ld+json">`
    // tag (double-quoted attributes only — single quotes are not
    // valid HTML for `type` in practice).
    final scriptRe = RegExp(
      '<script[^>]*type\\s*=\\s*"application/ld\\+json"[^>]*>',
      caseSensitive: false,
    );
    final bodyRe = RegExp('</script>', caseSensitive: false);
    for (final m in scriptRe.allMatches(html)) {
      final start = m.end;
      final endMatch = bodyRe.firstMatch(html.substring(start));
      final end = endMatch != null ? start + endMatch.start : html.length;
      final blob = html.substring(start, end).trim();
      try {
        final decoded = jsonDecode(blob);
        _walkJsonLdForImages(decoded, out);
      } catch (_) {
        // Malformed JSON-LD — skip.
      }
    }
    return out;
  }

  /// Recursively walks [node] collecting anything that looks
  /// like an image URL. Handles the JSON-LD shapes described in
  /// schema.org/ImageObject:
  ///   * "image": "https://..."
  ///   * "image": ["https://...", "https://..."]
  ///   * "image": { "url": "https://...", "contentUrl": "..." }
  void _walkJsonLdForImages(Object? node, List<String> out) {
    if (node is String) {
      // Only treat it as an image if it looks like one. We
      // verify later in [_looksLikeImage].
      if (_looksLikeImageUrl(node)) out.add(node);
      return;
    }
    if (node is List) {
      for (final v in node) {
        _walkJsonLdForImages(v, out);
      }
      return;
    }
    if (node is Map) {
      // Prefer explicit "image" key (or its variants).
      for (final key in const ['image', 'thumbnail', 'thumbnailUrl']) {
        if (node.containsKey(key)) {
          _walkJsonLdForImages(node[key], out);
        }
      }
      // ImageObject-style nested objects.
      for (final key in const ['url', 'contentUrl']) {
        if (node.containsKey(key) && node[key] is String) {
          final v = node[key] as String;
          if (_looksLikeImageUrl(v)) out.add(v);
        }
      }
      // Don't recurse into the whole map — too noisy. JSON-LD
      // image entries are at the top-level shape we already
      // covered above.
      return;
    }
  }

  // ---------- Image validation ----------

  /// Cheap pre-check based on the URL string alone. Filters out
  /// obvious tracking pixels / favicons / logos before we burn a
  /// network round-trip on a HEAD request.
  bool _looksLikeImageUrl(String url) {
    if (url.isEmpty) return false;
    final lower = url.toLowerCase();
    // Reject data URIs and non-http schemes.
    if (lower.startsWith('data:')) return false;
    if (!lower.startsWith('http://') &&
        !lower.startsWith('https://') &&
        !lower.startsWith('//')) {
      return false;
    }
    return true;
  }

  /// Checks whether [url] looks like an article image (not a
  /// tiny logo, favicon, or tracking pixel) based purely on the
  /// URL string. Called BEFORE the HTTP validation round-trip so
  /// we can skip a network call for obvious non-article images.
  ///
  /// Rules:
  /// - Reject SVG (logos, icons, site-wide graphics).
  /// - Reject ICO (favicon).
  /// - Reject URLs with logo/favicon/icon/avatar/pixel in the path.
  /// - Reject URLs that look like Open Graph default images
  ///   (usually `og_` prefix).
  /// - Accept everything else (jpg/png/webp) — the HTTP validation
  ///   round-trip will catch any remaining bad URLs.
  bool _isLikelyArticleImage(String url) {
    if (url.isEmpty) return false;
    final lower = url.toLowerCase();

    // File-type rejections.
    if (lower.endsWith('.svg')) return false;
    if (lower.endsWith('.ico')) return false;
    if (lower.contains('data:image')) return false;

    // Path-based logo / icon rejections.
    if (lower.contains('/favicon')) return false;
    if (lower.contains('/favi')) return false;
    if (lower.contains('/icon')) return false;
    if (lower.contains('/logo')) return false;
    if (lower.contains('/avatar')) return false;
    if (lower.contains('/user-avatar')) return false;
    if (lower.contains('/1x1')) return false;
    if (lower.contains('pixel')) return false;
    if (lower.contains('/blank.')) return false;
    if (lower.contains('/default.')) return false;
    if (lower.contains('/spacer.')) return false;

    // Common OG default / site-wide banner paths.
    if (lower.contains('/og_default')) return false;
    if (lower.contains('/og-image')) return false;
    if (lower.contains('/ogimage')) return false;
    if (lower.contains('/share-image')) return false;
    if (lower.contains('/social-image')) return false;
    if (lower.contains('/twitter-card')) return false;
    if (lower.contains('/header-image')) return false;
    if (lower.contains('/site-logo')) return false;
    if (lower.contains('/banner-logo')) return false;

    // Tiny dimensions baked into the URL (common for logos / pixel).
    if (lower.contains('width=1') || lower.contains('w=1')) return false;
    if (lower.contains('height=1') || lower.contains('h=1')) return false;
    if (lower.contains('_logo')) return false;
    if (lower.contains('-logo')) return false;
    if (lower.contains('logo_')) return false;
    if (lower.contains('logo-')) return false;

    return true;
  }

  /// Network-level validation. We do a HEAD request with a tight
  /// timeout. We treat the URL as valid when either:
  ///   * the HEAD returns 2xx with `content-type: image/...`, or
  ///   * the URL itself ends with a known image extension (in
  ///     which case some servers refuse HEAD, so we trust the
  ///     extension).
  Future<bool> _looksLikeImage(String url) async {
    if (!_looksLikeImageUrl(url)) return false;
    final lower = url.toLowerCase();
    final ext = _imageExtension(lower);
    if (ext != null) return true; // skip HEAD; trust the extension
    try {
      final req = http.Request('HEAD', Uri.parse(url));
      req.headers.addAll(_headers);
      final res = await _client.send(req).timeout(imageValidationTimeout);
      if (res.statusCode < 200 || res.statusCode >= 300) return false;
      final ct = (res.headers['content-type'] ?? '').toLowerCase();
      return ct.startsWith('image/');
    } catch (_) {
      // Some sites block HEAD. Fall back to a small GET and
      // check the Content-Type + first bytes.
      try {
        final res = await _client
            .get(Uri.parse(url), headers: _headers)
            .timeout(imageValidationTimeout);
        if (res.statusCode < 200 || res.statusCode >= 300) return false;
        final ct = res.headers['content-type'] ?? '';
        if (ct.toLowerCase().startsWith('image/')) return true;
        // Magic-byte sniff: PNG, JPEG, GIF, WEBP.
        final body = res.bodyBytes;
        if (body.length < 8) return false;
        if (body[0] == 0x89 && body[1] == 0x50) return true; // PNG
        if (body[0] == 0xFF && body[1] == 0xD8) return true; // JPEG
        if (body[0] == 0x47 && body[1] == 0x49) return true; // GIF
        if (_startsWithAscii(body, 'RIFF') && _startsWithAscii(body.sublist(8, 12), 'WEBP')) {
          return true;
        }
        return false;
      } catch (_) {
        return false;
      }
    }
  }

  static bool _startsWithAscii(List<int> bytes, String ascii) {
    if (bytes.length < ascii.length) return false;
    for (var i = 0; i < ascii.length; i++) {
      if (bytes[i] != ascii.codeUnitAt(i)) return false;
    }
    return true;
  }

  String? _imageExtension(String lower) {
    for (final ext in const ['.jpg', '.jpeg', '.png', '.webp', '.gif']) {
      if (lower.endsWith(ext)) return ext;
    }
    return null;
  }

  // ---------- URL helpers ----------

  /// Resolves [url] against [baseUrl] so the result is always an
  /// absolute http(s) URL. Empty / data / non-http schemes are
  /// stripped.
  String _absolutize(String url, String baseUrl) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('//')) {
      final base = Uri.parse(baseUrl);
      return '${base.scheme}:$trimmed';
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('data:')) return ''; // not useful here
    try {
      final abs = Uri.parse(baseUrl).resolve(trimmed);
      return abs.toString();
    } catch (_) {
      return '';
    }
  }

  // ---------- RSS parsing ----------

  /// Splits an RSS body into raw items. We do dependency-free
  /// regex here to avoid pulling in another package just for this
  /// small feed.
  List<_RawRssItem> _parseRss(String body, {required int limit}) {
    try {
      final out = <_RawRssItem>[];
      final itemRe =
          RegExp(r'<item\b[^>]*>([\s\S]*?)</item>', caseSensitive: false);
      for (final m in itemRe.allMatches(body)) {
        if (out.length >= limit) break;
        final inner = m.group(1) ?? '';
        final item = _parseItem(inner);
        if (item != null) out.add(item);
      }
      return out;
    } catch (e) {
      if (kDebugMode) {
        developer.log('RSS parse failed: $e', name: 'NewsService');
      }
      return const <_RawRssItem>[];
    }
  }

  _RawRssItem? _parseItem(String inner) {
    final title = _decodeEntities(_extractTag(inner, 'title'));
    if (title.isEmpty) return null;
    final link = _extractTag(inner, 'link');
    final source = _extractTag(inner, 'source');
    final sourceUrl = _extractAttr(inner, 'source', 'url');
    final publishedAt = _extractTag(inner, 'pubDate');
    return _RawRssItem(
      title: title,
      link: link,
      sourceUrl: sourceUrl,
      source: source,
      publishedAt: publishedAt,
    );
  }

  String _extractTag(String body, String tag) {
    final re = RegExp(
      '<$tag\\b[^>]*>([\\s\\S]*?)</$tag>',
      caseSensitive: false,
    );
    final m = re.firstMatch(body);
    if (m == null) return '';
    return (m.group(1) ?? '').trim();
  }

  String _extractAttr(String body, String tag, String attr) {
    final re = RegExp(
      '<$tag\\b[^>]*\\b$attr\\s*=\\s*"([^"]*)"',
      caseSensitive: false,
    );
    final m = re.firstMatch(body);
    if (m != null) return (m.group(1) ?? '').trim();
    final re2 = RegExp(
      "<$tag\\b[^>]*\\b$attr\\s*=\\s*'([^']*)'",
      caseSensitive: false,
    );
    final m2 = re2.firstMatch(body);
    if (m2 != null) return (m2.group(1) ?? '').trim();
    return '';
  }

  String _decodeEntities(String s) {
    var v = s;
    final cdata = RegExp(r'^<!\[CDATA\[([\s\S]*?)\]\]>$');
    final cm = cdata.firstMatch(v.trim());
    if (cm != null) v = cm.group(1) ?? '';
    v = v
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');
    return v.trim();
  }

  /// Public helper exposed for the UI so it can pull exactly
  /// [targetCount] articles with valid images from the feed.
  static List<NewsArticle> takeForCarousel(NewsFeed feed) {
    return feed.articles.take(targetCount).toList(growable: false);
  }

  void dispose() {
    _client.close();
    _cache.clear();
    _htmlCache.clear();
  }
}

/// One parsed RSS item. We keep the raw link / sourceUrl so the
/// resolver pipeline can pick the cheapest URL first.
class _RawRssItem {
  const _RawRssItem({
    required this.title,
    required this.link,
    required this.sourceUrl,
    required this.source,
    required this.publishedAt,
  });
  final String title;
  final String link;
  final String sourceUrl;
  final String source;
  final String publishedAt;
}

class NewsCacheEntry {
  NewsCacheEntry({required this.at, required this.feed});
  final DateTime at;
  final NewsFeed feed;
}

class _HtmlCacheEntry {
  _HtmlCacheEntry({required this.at, required this.html});
  final DateTime at;
  final String html;
}