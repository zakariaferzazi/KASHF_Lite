import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'ai_prompts.dart';
import 'disk_cache.dart';
import 'logo_service.dart';

/// Picks a brand to feature on the home screen's "Featured
/// investigation" card. Cycles through every entry in
/// [AiPrompts.brandUrls] in a deterministic-but-random-looking
/// order, so:
///   * The first launch shows brand #0 (lattafa, the default).
///   * Each manual refresh moves to the next brand.
///   * The chosen brand is persisted via [DiskCache] so the user
///     sees the same brand after a restart until they tap refresh.
///
/// The widget that consumes this controller renders the brand's
/// logo via [LogoService.urlFor] so we never ship bundled assets
/// — the URL is fetched fresh from the Logo.dev CDN.
class FeaturedBrandController extends ChangeNotifier {
  FeaturedBrandController({DiskCache? diskCache})
      : _disk = diskCache ?? _sharedDiskCache;

  static const String _diskKey = 'home_featured_brand';

  /// Shared disk cache. Wired in `main.dart` after the process
  /// boots so the singleton can read/write the chosen brand.
  static DiskCache? _sharedDiskCache;

  /// Static hook used by `main.dart` to wire the same cache the
  /// other controllers use.
  static void initDiskCache(DiskCache cache) {
    _sharedDiskCache = cache;
  }

  final DiskCache? _disk;

  /// Currently-featured brand key (lowercase, e.g. `lattafa`),
  /// or `null` until the first `bootstrap()` / `refresh()` runs.
  String? _brandKey;

  /// Public accessor — the brand key as stored.
  String? get brandKey => _brandKey;

  /// Public accessor — the domain for the featured brand, used
  /// to render the logo.
  String? get brandDomain {
    final k = _brandKey;
    if (k == null) return null;
    return AiPrompts.brandUrls[k];
  }

  /// Public accessor — the Logo.dev URL for the featured brand,
  /// ready to feed to `Image.network`. `null` when no brand has
  /// been picked yet.
  String? get logoUrl => LogoService.urlFor(brandDomain, size: 256);

  /// Public accessor — localised brand name for the featured
  /// brand. Falls back to the raw key when no Arabic translation
  /// is known.
  String get brandLabel {
    final k = _brandKey;
    if (k == null) return '';
    return AiPrompts.brandNamesAr[k] ?? k;
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Bootstrap from disk cache on first frame. Restores the
  /// last persisted brand so the user sees it after a restart.
  ///
  /// When there's no persisted choice (fresh install) we pick a
  /// random brand instead of always landing on Lattafa — the
  /// user shouldn't see the same image every cold start.
  Future<void> bootstrap() async {
    final disk = _disk;
    if (disk == null) {
      _brandKey = _randomBrandKey();
      notifyListeners();
      return;
    }
    final raw = await disk.readJson(_diskKey, ttl: const Duration(days: 30));
    if (raw == null) {
      _brandKey = _randomBrandKey();
      notifyListeners();
      return;
    }
    final key = raw['brandKey'] as String?;
    if (key != null && AiPrompts.brandUrls.containsKey(key)) {
      _brandKey = key;
      notifyListeners();
    } else {
      // Persisted entry is invalid (old schema?) — pick a random
      // brand so the UI never breaks.
      _brandKey = _randomBrandKey();
      notifyListeners();
    }
  }

  /// Pick a new brand. Cycles through every entry in
  /// [AiPrompts.brandUrls] starting from a randomised offset so
  /// the order varies between sessions, but always advances on
  /// each call.
  Future<void> refresh() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    final keys = AiPrompts.brandUrls.keys.toList(growable: false);
    if (keys.isEmpty) {
      _isLoading = false;
      notifyListeners();
      return;
    }
    final current = _brandKey;
    // Default to a random offset so the first refresh on a cold
    // install doesn't always land on Lattafa. After we already
    // have a current brand we just advance to the next one so
    // repeated taps feel deterministic.
    var nextIndex = _rng.nextInt(keys.length);
    if (current != null) {
      final currentIndex = keys.indexOf(current);
      if (currentIndex >= 0) {
        nextIndex = (currentIndex + 1) % keys.length;
      }
    }
    _brandKey = keys[nextIndex];

    // Persist the new choice so the next app launch shows it.
    final disk = _disk;
    if (disk != null) {
      await disk.writeJson(_diskKey, <String, dynamic>{
        'brandKey': _brandKey,
      });
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Shared RNG so subsequent calls don't pick the same value.
  final math.Random _rng = math.Random();

  /// Picks a brand key uniformly at random from
  /// [AiPrompts.brandUrls]. Returns the first entry if the map
  /// is somehow empty (shouldn't happen — the map is a `const`
  /// with ~46 entries).
  String _randomBrandKey() {
    final keys = AiPrompts.brandUrls.keys.toList(growable: false);
    if (keys.isEmpty) return '';
    return keys[_rng.nextInt(keys.length)];
  }
}