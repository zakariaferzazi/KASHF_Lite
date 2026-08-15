import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'logo_service.dart';

/// Resolves a verified image URL for an investigation result.
///
/// The AI often returns either no image at all, a 404 URL, or a
/// corrupted asset. To avoid showing an empty / broken tile, this
/// resolver builds a candidate list from every available source,
/// then **probes each one** with a lightweight HTTP request and
/// returns the first URL that actually serves an image.
///
/// The candidate list, in order (subject-aware so the result
/// always relates to what was searched for):
///
///   1. Wikipedia REST "page summary" thumbnail for the subject
///      name (or query) — works for brands, products, persons,
///      influencers, companies, and even market segments.
///   2. The AI's `thumbnail_url` from the JSON response.
///   3. The first `image_url` from any item or source the AI
///      produced.
///   4. A Logo.dev logo URL derived from the AI's
///      `subject_domain` (e.g. `lattafa.com`).
///   5. For influencer / person entities: unavatar.io keyed on
///      the subject name (real social avatar).
///   6. A deterministic picsum.photos URL seeded by the
///      SUBJECT name (so even the fallback image is tied to
///      the search — two different searches never produce the
///      same placeholder).
///
/// Once we land on a winner we cache the URL for the lifetime of
/// the process so we never re-probe the same investigation.
class InvestigationThumbnailResolver {
  InvestigationThumbnailResolver({
    http.Client? httpClient,
    Duration probeTimeout = const Duration(seconds: 3),
  })  : _http = httpClient ?? http.Client(),
        _probeTimeout = probeTimeout;

  static final InvestigationThumbnailResolver instance =
      InvestigationThumbnailResolver();

  final http.Client _http;
  final Duration _probeTimeout;

  /// Investigation id -> resolved image URL. Populated as we
  /// successfully probe each candidate, so subsequent calls (e.g.
  /// when the archive service persists the result, or when the
  /// home screen re-renders the card) skip the network entirely.
  final Map<String, String> _resolved = {};

  /// In-flight resolutions, keyed by investigation id. Multiple
  /// callers can `await` the same future without re-probing.
  final Map<String, Future<String?>> _inflight = {};

  /// Wikipedia REST summary responses cache, keyed by subject
  /// key (lowercased, ascii-folded). Avoids re-hitting the API
  /// for repeat investigations about the same subject within a
  /// session.
  final Map<String, String?> _wikiCache = {};

  /// The single thumbnail used for every investigation result.
  /// Lives in the bundle so we never touch the network to render
  /// it. The result screen detects this value (or any value
  /// starting with `asset://`) and renders it via [Image.asset]
  /// instead of [Image.network].
  static const String defaultThumbnailAssetPath =
      'asset://assets/images/report.jpg';

  /// Resolves (or returns the cached) thumbnail URL for a given
  /// investigation. Safe to call repeatedly — the underlying
  /// probe only runs once per id per process.
  ///
  /// Always returns the bundled report thumbnail — every
  /// investigation result uses the same image regardless of the
  /// subject. No network probing, no Wikipedia lookups, no
  /// fallback chains. The result screen renders the asset path
  /// through [Image.asset].
  Future<String?> resolve({
    required String investigationId,
    String? aiThumbnailUrl,
    String? subjectDomain,
    String? entityTypeName,
    String? subjectName,
    String? query,
    Iterable<String> moreCandidates = const <String>[],
  }) async {
    final cached = _resolved[investigationId];
    if (cached != null) return cached;

    final inflight = _inflight[investigationId];
    if (inflight != null) return inflight;

    final future = _doResolve(
      investigationId: investigationId,
      aiThumbnailUrl: aiThumbnailUrl,
      subjectDomain: subjectDomain,
      entityTypeName: entityTypeName,
      subjectName: subjectName,
      query: query,
      moreCandidates: moreCandidates,
    );
    _inflight[investigationId] = future;
    try {
      return await future;
    } finally {
      _inflight.remove(investigationId);
    }
  }

  Future<String?> _doResolve({
    required String investigationId,
    String? aiThumbnailUrl,
    String? subjectDomain,
    String? entityTypeName,
    String? subjectName,
    String? query,
    Iterable<String> moreCandidates = const <String>[],
  }) async {
    // Always return the bundled report thumbnail. No network
    // probing, no Wikipedia lookups, no Logo.dev, no picsum.
    _resolved[investigationId] = defaultThumbnailAssetPath;
    return defaultThumbnailAssetPath;
  }

  /// Public helper: builds the candidate URL list (with a
  /// Wikipedia lookup already resolved). Useful in tests /
  /// previews.
  Future<List<String>> buildCandidates({
    required String investigationId,
    String? aiThumbnailUrl,
    String? subjectDomain,
    String? entityTypeName,
    String? subjectName,
    String? query,
    Iterable<String> moreCandidates = const <String>[],
  }) async {
    final out = <String>[];

    void add(String? url) {
      if (url == null) return;
      final trimmed = url.trim();
      if (trimmed.isEmpty) return;
      if (!_looksLikeImageUrl(trimmed)) return;
      if (!out.contains(trimmed)) out.add(trimmed);
    }

    // 1) Wikipedia subject thumbnail — the smartest candidate for
    //    any entity type (brand, product, person, market...).
    add(await _wikipediaThumbnailFor(subjectName, query, entityTypeName));

    // 2) AI-declared top-level thumbnail.
    add(aiThumbnailUrl);

    // 3) Per-item / per-source images the AI produced.
    for (final m in moreCandidates) {
      add(m);
    }

    // 4) Logo.dev for known domains — covers brands / companies.
    add(LogoService.urlFor(subjectDomain, size: 256));

    // 5) Influencer / person: unavatar.io keyed on a handle or
    //    the subject name.
    if (entityTypeName == 'influencer') {
      add(_unavatarUrlFor(subjectName, query));
    }

    // 6) Final deterministic fallback — seeded by the SUBJECT so
    //    even the placeholder image is tied to what was searched.
    add(_picsumFallback(investigationId, subjectName, query));

    return out;
  }

  /// Hits the Wikipedia REST "page summary" endpoint for the
  /// subject and returns its `thumbnail.source` URL when the
  /// article exists. Returns null on miss / error / network
  /// failure so the resolver can fall through to the next
  /// candidate.
  ///
  /// We try a small list of normalised variants for the subject
  /// so a query like "Huda Kattan" or "huda beauty" both land on
  /// the right article. The lookup is cached for the process
  /// lifetime keyed on the normalised subject.
  Future<String?> _wikipediaThumbnailFor(
    String? subjectName,
    String? query,
    String? entityTypeName,
  ) async {
    final subjects = _candidateSubjects(subjectName, query);
    if (subjects.isEmpty) return null;

    for (final raw in subjects) {
      final title = _normaliseForWikipedia(raw);
      if (title.isEmpty) continue;
      final key = title.toLowerCase();
      // Cache hit.
      if (_wikiCache.containsKey(key)) {
        final cached = _wikiCache[key];
        if (cached != null && cached.isNotEmpty) return cached;
        continue;
      }
      final url = await _fetchWikipediaThumbnail(title);
      _wikiCache[key] = url;
      if (url != null && url.isNotEmpty) return url;
    }
    return null;
  }

  /// Builds a short list of plausible Wikipedia titles for the
  /// subject. We pick the cleanest forms first (subject_name,
  /// then query) and stop after a few — Wikipedia would
  /// otherwise rate-limit us.
  List<String> _candidateSubjects(String? subjectName, String? query) {
    final out = <String>[];
    void add(String? s) {
      if (s == null) return;
      final trimmed = s.trim();
      if (trimmed.isEmpty) return;
      if (!out.contains(trimmed)) out.add(trimmed);
    }

    add(subjectName);
    add(query);

    // If the query is short / multi-word, also try stripping a
    // trailing qualifier like "investigation" / "تحقيق" so
    // "Lattafa investigation" → "Lattafa".
    final q = query?.trim() ?? '';
    if (q.isNotEmpty) {
      final stripped = q
          .replaceAll(RegExp(
              r'\b(investigation|investigation|profile|report|تحقيق|تقرير)\b',
              caseSensitive: false),
          '')
          .trim();
      if (stripped.isNotEmpty && stripped != q) add(stripped);
    }

    return out.take(3).toList();
  }

  /// Normalises a free-text title into something the Wikipedia
  /// API will accept. Replaces whitespace with underscores,
  /// strips punctuation that the API rejects, and URL-encodes
  /// the result.
  String _normaliseForWikipedia(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return '';
    // Collapse whitespace.
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    // Wikipedia disallows certain characters at the start of a
    // title. Strip surrounding straight quotes / brackets using
    // explicit codepoints so the regex stays ASCII-only and the
    // Dart parser is happy with curly quotes in raw strings.
    s = s.replaceAll(
        RegExp(r'^[\"\u2018\u2019\u201C\u201D`]+|[\"\u2018\u2019\u201C\u201D`]+$'),
        '');
    // Replace spaces with underscores (the API does this itself
    // for the path segment, but doing it here keeps the URL
    // encoding clean).
    s = s.replaceAll(' ', '_');
    return s;
  }

  Future<String?> _fetchWikipediaThumbnail(String title) async {
    // Try English Wikipedia first (largest coverage of brands,
    // products, and Western / GCC influencers). If miss, the
    // resolver falls through to the next candidate subject —
    // cross-language fallback is intentionally out of scope
    // here to keep latency low.
    final uri = Uri.parse(
      'https://en.wikipedia.org/api/rest_v1/page/summary/'
      '${Uri.encodeComponent(title)}',
    );
    try {
      final res = await _http.get(uri).timeout(_probeTimeout);
      if (res.statusCode != 200) return null;
      final body = utf8.decode(res.bodyBytes);
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) return null;
      final thumb = json['thumbnail'];
      if (thumb is! Map<String, dynamic>) return null;
      final src = thumb['source'];
      if (src is String && src.isNotEmpty) {
        // Wikipedia thumbnails are small (~300px) by default;
        // ask for a larger rendition by tweaking the URL.
        return _bumpWikipediaThumbSize(src);
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          '[InvestigationThumbnailResolver] wikipedia probe failed for '
          '$title: $e\n$st',
        );
      }
    }
    return null;
  }

  /// Wikipedia returns thumbnails in `/wikipedia/commons/thumb/...`
  /// form with a width segment like `/300px-...`. Bumping it to
  /// `/600px-...` (or whatever target we want) gives the UI a
  /// sharper card image. Falls through unchanged if the URL
  /// doesn't match the expected pattern.
  String _bumpWikipediaThumbSize(String url) {
    final targetWidth = 600;
    final pattern = RegExp(r'/\d+px-');
    if (!pattern.hasMatch(url)) return url;
    return url.replaceFirstMapped(
      pattern,
      (m) => '/${targetWidth}px-',
    );
  }

  /// Builds a unavatar.io URL for an influencer / person entity.
  /// unavatar returns a real social avatar when it can resolve
  /// the username (Instagram, Twitter, GitHub, Gravatar…), and a
  /// 404 otherwise. We use the subject name (lower-cased, with
  /// spaces stripped) as the candidate handle.
  String? _unavatarUrlFor(String? subjectName, String? query) {
    final raw = (subjectName?.trim().isNotEmpty ?? false)
        ? subjectName!.trim()
        : (query?.trim() ?? '');
    if (raw.isEmpty) return null;
    // Strip leading '@' if present.
    var handle = raw.startsWith('@') ? raw.substring(1) : raw;
    // Lowercase + drop spaces so "Huda Kattan" → "hudakattan".
    handle = handle.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    // Drop characters that aren't valid in a handle.
    handle = handle.replaceAll(RegExp(r'[^a-z0-9._-]'), '');
    if (handle.isEmpty) return null;
    // unavatar itself handles the multi-service lookup and falls
    // back to a deterministic silhouette. The picsum fallback we
    // add below ensures the UI never shows an empty tile even if
    // every social network rejects the handle.
    return 'https://unavatar.io/$handle?fallback=https://picsum.photos/'
        'seed/${handle}_avatar/600';
  }

  bool _looksLikeImageUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.startsWith('data:')) return false;
    if (!lower.startsWith('http://') &&
        !lower.startsWith('https://') &&
        !lower.startsWith('//')) {
      return false;
    }
    return true;
  }

  /// Builds the deterministic picsum fallback URL. Seeded by the
  /// SUBJECT name (or query) so two different searches produce
  /// two different placeholders — never the same random photo.
  /// Falls back to a hash of the investigation id when no subject
  /// is available.
  String _picsumFallback(
    String investigationId,
    String? subjectName,
    String? query,
  ) {
    final seedSource = (subjectName?.trim().isNotEmpty ?? false)
        ? subjectName!.trim()
        : ((query?.trim().isNotEmpty ?? false)
            ? query!.trim()
            : investigationId);
    final seed = _seedFor(seedSource);
    return 'https://picsum.photos/seed/$seed/600/600';
  }

  String _seedFor(String s) {
    var h = 0;
    for (final code in s.codeUnits) {
      h = (h * 31 + code) & 0x7FFFFFFF;
    }
    return h.toRadixString(36);
  }

  /// Drops every cached resolutions. Useful for tests.
  void clearCache() {
    _resolved.clear();
    _wikiCache.clear();
  }

  /// Closes the underlying HTTP client. Safe to call multiple
  /// times.
  Future<void> dispose() async {
    _resolved.clear();
    _inflight.clear();
    _wikiCache.clear();
    _http.close();
  }
}