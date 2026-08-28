import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../ai/disk_cache.dart';
import 'news_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Firestore deployment
// ─────────────────────────────────────────────────────────────────────────────
// The security rules for the collections this repository uses
// (`newsContent/**` and `aiContent/**`) live in `firestore.rules` at the
// repo root. Until they are deployed the app will see
// `PERMISSION_DENIED` on writes; reads will also be denied.
//
// To publish the rules from an authenticated workstation:
//
//     firebase login
//     firebase deploy --only firestore:rules --project kashf-lite
//
// While you are still setting up the rules (or if the database is in
// production-mode without them), the repository degrades gracefully:
// reads return `null` (caller falls back to disk), writes persist only
// to local SharedPreferences. No exception bubbles up to the UI and the
// 24-hour gate still works because the disk stamp is the source of
// truth for `needsRefresh`.

/// Firestore collection + document id for an AI payload produced by
/// the home / market / explore screens. The pair uniquely identifies
/// one AI response so the next launch can rehydrate without a network
/// call.
enum AiContentKind {
  homeMarketPulse('home_pulse'),
  marketDetail('market_screen'),
  exploreDetail('explore_screen');

  const AiContentKind(this.docKey);
  final String docKey;
}

/// Single source of truth for news/AI content on the home, market,
/// and explore screens.
///
/// Historically every screen mounted its own controller and called
/// `refreshNow` on `initState`, which (a) hammered the Google News
/// pipeline (~100 HTTP requests per refresh) on every navigation
/// and (b) leaked controllers + listeners. Combined with the heavy
/// image-resolve step the app kept spending CPU and bandwidth in
/// the background, producing visible lag.
///
/// This repository fixes the root cause by:
///   1. Keeping one **24-hour** timestamp-gated refresh cycle. The
///      heavy Google News scrape only runs when the persisted
///      timestamp is older than [refreshInterval].
///   2. **Hydrating from disk and Firestore FIRST** on app launch so
///      every screen renders previously-cached content immediately
///      without a single network call.
///   3. **Only** triggering a background network refresh when the
///      cached payload is older than 24 hours (or absent), so a
///      user opening the app 10× in a single day still pays the
///      refresh cost at most once.
///
/// The disk cache is the fast path (SharedPreferences, ~1 ms).
/// Firestore is the slow path (network). Both share the same JSON
/// payload, so once we've written to Firestore the next session can
/// pull from either.
///
/// Schema (Firestore):
///   newsContent/{locale}/{topic}  ->  { articles: [...], updatedAt: ms }
///   aiContent/home_pulse/{region}  ->  same shape, for the home page
///   aiContent/market_screen/{region} ->  same shape, for the market page
///
/// In a production deployment a Cloud Function / scheduled job
/// would call into `NewsService` (or a server-side equivalent) once
/// every 24 hours and overwrite the documents. The client only ever
/// *reads* from Firestore; it never scrapes Google News on the user
/// device unless the document is missing AND the disk cache is
/// empty AND the timestamp is older than 24 hours.
class NewsContentRepository {
  NewsContentRepository({
    FirebaseFirestore? firestore,
    DiskCache? diskCache,
    Duration refreshInterval = const Duration(hours: 24),
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _disk = diskCache,
        _refreshInterval = refreshInterval;

  final FirebaseFirestore _firestore;
  final DiskCache? _disk;
  final Duration _refreshInterval;

  /// Tracks whether we have already surfaced a "Firestore
  /// unavailable" warning to the user. The repository logs at
  /// most once per process so the debug console doesn't get
  /// flooded with [PERMISSION_DENIED] when rules haven't been
  /// deployed yet.
  static bool _warnedAboutFirestore = false;

  /// Shared, lazily-initialised instance. Used by every controller
  /// in the app so they all share the same 24-hour window instead of
  /// each scheduling their own refresh.
  static NewsContentRepository? _instance;
  static NewsContentRepository get instance =>
      _instance ??= NewsContentRepository();

  /// Allows `main.dart` to inject the same `DiskCache` it gives to
  /// `NewsService` / `AiHomeService`, so the repository writes to
  /// the same on-device slot.
  static void init(DiskCache diskCache) {
    _instance = NewsContentRepository(diskCache: diskCache);
  }

  // ============================ Public API ============================

  /// Hydrate the in-memory [NewsService] cache from disk + Firestore
  /// without performing any network refresh. Safe to call from
  /// every screen's `initState` — it is idempotent and bounded to a
  /// handful of SharedPreferences reads.
  ///
  /// Returns the number of topics that were successfully hydrated.
  Future<int> hydrate({
    required String language,
    required String country,
  }) async {
    int loaded = 0;
    for (final topic in NewsTopic.values) {
      final cached = await _readCache(language, country, topic);
      if (cached == null || cached.articles.isEmpty) continue;
      loaded++;
    }
    return loaded;
  }

  /// Returns the cached feed for [topic], preferring disk (fast)
  /// and falling back to Firestore (slower, ~200 ms). Never hits
  /// the network beyond Firestore.
  Future<NewsFeed?> readFeed({
    required String language,
    required String country,
    required NewsTopic topic,
  }) async {
    final fromDisk = await _readDisk(language, country, topic);
    if (fromDisk != null) return fromDisk;
    final fromFs = await _readFirestore(language, country, topic);
    if (fromFs != null) {
      // Mirror Firestore into disk so the next launch can hydrate
      // without a Firestore round-trip.
      await _writeDisk(language, country, topic, fromFs);
      return fromFs;
    }
    return null;
  }

  /// Returns `true` when the cached payload for [topic] is older
  /// than [refreshInterval] OR is missing entirely. Used by callers
  /// to decide whether a background refresh is worth scheduling.
  Future<bool> needsRefresh({
    required String language,
    required String country,
    required NewsTopic topic,
  }) async {
    final feed = await readFeed(
      language: language,
      country: country,
      topic: topic,
    );
    if (feed == null) return true;
    final stampedAt = feed.fetchedAt;
    if (stampedAt == null) return true;
    return DateTime.now().difference(stampedAt) > _refreshInterval;
  }

  /// Persist a freshly fetched [feed] into BOTH disk (fast path) and
  /// Firestore (cross-device sync). Called only after the heavy
  /// Google News scrape completes — which itself is throttled to
  /// once every 24 hours by [needsRefresh].
  Future<void> writeFeed({
    required String language,
    required String country,
    required NewsTopic topic,
    required NewsFeed feed,
  }) async {
    final stamped = feed.stamp(DateTime.now());
    await _writeDisk(language, country, topic, stamped);
    await _writeFirestore(language, country, topic, stamped);
  }

  /// The shared 24-hour window. Exposed so the [MarketEventsController]
  /// and others can gate themselves on the same policy.
  Duration get refreshInterval => _refreshInterval;

  // ============================ Storage helpers ============================

  String _diskKey(String lang, String country, NewsTopic topic) =>
      'news|$lang|${country.toUpperCase()}|topic:${topic.name}';

  String _docId(String lang, String country, NewsTopic topic) =>
      '${lang}_${country.toUpperCase()}_${topic.name}';

  Future<NewsFeed?> _readCache(
    String lang,
    String country,
    NewsTopic topic,
  ) async {
    return readFeed(language: lang, country: country, topic: topic);
  }

  Future<NewsFeed?> _readDisk(
    String lang,
    String country,
    NewsTopic topic,
  ) async {
    final disk = _disk;
    if (disk == null) return null;
    final raw = await disk.readJson(_diskKey(lang, country, topic));
    if (raw == null) return null;
    try {
      return NewsFeed.fromCacheJson(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeDisk(
    String lang,
    String country,
    NewsTopic topic,
    NewsFeed feed,
  ) async {
    final disk = _disk;
    if (disk == null) return;
    await disk.writeJson(_diskKey(lang, country, topic), feed.toCacheJson());
  }

  Future<NewsFeed?> _readFirestore(
    String lang,
    String country,
    NewsTopic topic,
  ) async {
    try {
      final snap = await _firestore
          .collection('newsContent')
          .doc(lang)
          .collection('topics')
          .doc(_docId(lang, country, topic))
          .get(const GetOptions(source: Source.cache))
          .timeout(const Duration(seconds: 3));
      if (!snap.exists) return null;
      final data = snap.data();
      if (data == null) return null;
      return NewsFeed.fromFirestoreJson(data);
    } catch (e) {
      _warnFirestoreOnce('read', e);
      return null;
    }
  }

  Future<void> _writeFirestore(
    String lang,
    String country,
    NewsTopic topic,
    NewsFeed feed,
  ) async {
    try {
      await _firestore
          .collection('newsContent')
          .doc(lang)
          .collection('topics')
          .doc(_docId(lang, country, topic))
          .set(feed.toFirestoreJson(), SetOptions(merge: true));
    } catch (e) {
      _warnFirestoreOnce('write', e);
    }
  }

  // ============================ AI content ============================

  /// Mirror an AI payload into both Firestore and disk. Called from
  /// `AiHomeService` whenever a fetch returns a fresh response so
  /// the next launch can rehydrate from Firestore without spending
  /// OpenRouter tokens.
  Future<void> writeAiContent({
    required AiContentKind kind,
    required String language,
    required String region,
    required Map<String, dynamic> payload,
  }) async {
    final stamped = <String, dynamic>{
      'payload': payload,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'language': language,
      'region': region,
    };
    try {
      await _firestore
          .collection('aiContent')
          .doc(kind.docKey)
          .collection('regions')
          .doc('${language}_${region.toLowerCase()}')
          .set(stamped, SetOptions(merge: true));
    } catch (e) {
      _warnFirestoreOnce('ai-write', e);
    }
    final disk = _disk;
    if (disk != null) {
      await disk.writeJson(_aiDiskKey(kind, language, region), stamped);
    }
  }

  /// Read a previously persisted AI payload. Returns the decoded
  /// JSON (or null on miss / expiry). The payload is the same
  /// shape that [AiHomeService] parses, so callers can hand the
  /// value straight to the existing parsers.
  ///
  /// Read order:
  ///   1. **Disk cache** (instant). If a payload is present and
  ///      within the 24-hour refresh window, return it directly.
  ///   2. **Firestore server** (the source of truth). We
  ///      deliberately do NOT pin to `Source.cache` here —
  ///      cold installs (where the local cache has never been
  ///      primed for this user) would otherwise return `null`
  ///      even though the data sits in Firestore, and the user
  ///      would be forced to hit the refresh button on every
  ///      app launch. We always check the server so a payload
  ///      that was written by a previous session is picked up
  ///      immediately.
  ///   3. **Network error / offline** — fall back to whatever
  ///      is in the Firestore disk cache (the legacy
  ///      `Source.cache` path) so the home screen still has
  ///      something to render if we got disconnected.
  ///   4. On a successful server read, mirror the doc into the
  ///      disk cache so subsequent launches are instant.
  Future<Map<String, dynamic>?> readAiContent({
    required AiContentKind kind,
    required String language,
    required String region,
  }) async {
    final disk = _disk;
    final docRef = _firestore
        .collection('aiContent')
        .doc(kind.docKey)
        .collection('regions')
        .doc('${language}_${region.toLowerCase()}');

    // Disk first — instant path for warm launches.
    if (disk != null) {
      final raw = await disk.readJson(_aiDiskKey(kind, language, region));
      if (raw != null) {
        final payload = raw['payload'];
        if (payload is Map<String, dynamic>) {
          // Also kick off a background server read so the disk
          // cache stays in sync if a manual refresh happened
          // on another device.
          _refreshDiskFromServer(
            docRef: docRef,
            diskKey: _aiDiskKey(kind, language, region),
          );
          return payload;
        }
      }
    }

    // Server next — source of truth.
    try {
      final snap = await docRef.get().timeout(const Duration(seconds: 3));
      if (!snap.exists) return null;
      final data = snap.data();
      if (data == null) return null;
      final payload = data['payload'];
      if (payload is Map<String, dynamic>) {
        if (disk != null) {
          await disk.writeJson(_aiDiskKey(kind, language, region), data);
        }
        return payload;
      }
      return null;
    } catch (serverErr) {
      // Offline / timeout — fall back to whatever the Firestore
      // local cache has. This is the legacy path; it survives
      // cold-cache + offline scenarios.
      try {
        final cachedSnap = await docRef
            .get(const GetOptions(source: Source.cache))
            .timeout(const Duration(seconds: 2));
        if (!cachedSnap.exists) return null;
        final data = cachedSnap.data();
        if (data == null) return null;
        final payload = data['payload'];
        if (payload is Map<String, dynamic>) return payload;
        return null;
      } catch (_) {
        _warnFirestoreOnce('ai-read', serverErr);
        return null;
      }
    }
  }

  /// Fire-and-forget background sync of the disk cache from
  /// Firestore. We don't await this from [readAiContent] so the
  /// caller gets an instant response from disk on warm
  /// launches. Errors are silent — the next foreground read
  /// will retry.
  void _refreshDiskFromServer({
    required DocumentReference<Map<String, dynamic>> docRef,
    required String diskKey,
  }) {
    unawaited(() async {
      try {
        final snap = await docRef.get().timeout(const Duration(seconds: 3));
        if (!snap.exists) return;
        final data = snap.data();
        if (data == null) return;
        final disk = _disk;
        if (disk != null) {
          await disk.writeJson(diskKey, data);
        }
      } catch (_) {
        // Silent — best effort.
      }
    }());
  }

  /// `true` when the AI payload for [kind] / [language] / [region]
  /// is older than [refreshInterval] OR missing entirely. Callers
  /// (e.g. `AiHomeService.fetchMarketPulse`) skip the OpenRouter
  /// request when this returns false.
  ///
  /// Same read order as [readAiContent]: disk first (instant),
  /// then Firestore server (the source of truth — pinned to the
  /// default source, NOT `Source.cache`, so cold installs find
  /// existing payloads and don't trigger a fresh AI fetch on
  /// every launch).
  Future<bool> aiNeedsRefresh({
    required AiContentKind kind,
    required String language,
    required String region,
  }) async {
    final disk = _disk;
    final docRef = _firestore
        .collection('aiContent')
        .doc(kind.docKey)
        .collection('regions')
        .doc('${language}_${region.toLowerCase()}');

    if (disk != null) {
      final raw = await disk.readJson(_aiDiskKey(kind, language, region));
      if (raw != null) {
        final at = raw['updatedAt'];
        if (at is num) {
          final stamped = DateTime.fromMillisecondsSinceEpoch(at.toInt());
          if (DateTime.now().difference(stamped) <= _refreshInterval) {
            return false;
          }
        }
      }
    }
    try {
      final snap = await docRef.get().timeout(const Duration(seconds: 3));
      if (!snap.exists) return true;
      final data = snap.data();
      if (data == null) return true;
      final at = data['updatedAt'];
      if (at is! num) return true;
      final stamped = DateTime.fromMillisecondsSinceEpoch(at.toInt());
      // Within the refresh window — caller can skip the AI call.
      return DateTime.now().difference(stamped) > _refreshInterval;
    } catch (_) {
      return true;
    }
  }

  String _aiDiskKey(AiContentKind kind, String language, String region) =>
      'ai|${kind.docKey}|$language|${region.toLowerCase()}';

  /// Logs a Firestore failure at most once per process. This keeps
  /// the debug console readable when the rules haven't been deployed
  /// yet (every save would otherwise spam the same
  /// `PERMISSION_DENIED` line).
  void _warnFirestoreOnce(String op, Object error) {
    if (!kDebugMode) return;
    if (_warnedAboutFirestore) return;
    _warnedAboutFirestore = true;
    // ignore: avoid_print
    print(
      '[NewsContentRepository] firestore $op failed — falling back '
      'to disk. Deploy firestore.rules to fix this. Error: $error',
    );
  }
}