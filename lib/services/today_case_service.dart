import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/today_case.dart';

/// Loads the bundled `assets/Data/today_case.json` payload into a
/// pool of [TodayCase] objects and picks a random entry to
/// feature on the home screen + the "today's case" detail screen.
///
/// Behavior:
///   * [loadAll] reads the JSON once via [rootBundle.loadString]
///     and caches the parsed list for the lifetime of the
///     process — repeated calls don't re-read the asset.
///   * [pickRandom] returns a uniformly-random entry from the
///     pool. The optional [excludeId] lets the caller avoid
///     showing the same case twice in a row when the user
///     refreshes.
///   * [pickById] returns the entry with the given [id], or
///     `null` if the pool doesn't contain it.
class TodayCaseService {
  TodayCaseService._();
  static final TodayCaseService instance = TodayCaseService._();

  /// Bundled asset path. Kept private so callers don't depend
  /// on the file location.
  static const String _assetPath = 'assets/Data/today_case.json';

  /// Shared RNG so two consecutive calls don't yield the same
  /// value.
  final math.Random _rng = math.Random();

  /// In-memory cache. Populated on the first [loadAll] call
  /// and reused thereafter.
  List<TodayCase>? _cache;

  /// Future used to deduplicate concurrent [loadAll] calls.
  Future<List<TodayCase>>? _loading;

  /// Reads the bundled JSON file and returns the parsed list.
  /// The result is cached so subsequent calls are O(1).
  ///
  /// Throws [FormatException] if the file is missing or its
  /// top-level shape isn't an array.
  Future<List<TodayCase>> loadAll() {
    final cached = _cache;
    if (cached != null) return Future.value(cached);
    final pending = _loading;
    if (pending != null) return pending;

    final future = _readAsset();
    _loading = future;
    future.whenComplete(() => _loading = null);
    return future;
  }

  Future<List<TodayCase>> _readAsset() async {
    debugPrint('[TodayCaseService] reading $_assetPath …');
    final raw = await rootBundle.loadString(_assetPath);
    debugPrint('[TodayCaseService] raw length=${raw.length} chars');
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw FormatException(
        'today_case.json is expected to be a JSON array, '
        'got: ${decoded.runtimeType}',
      );
    }
    debugPrint('[TodayCaseService] decoded list with '
        '${decoded.length} entries');
    final list = decoded
        .cast<Map>()
        .map((m) => TodayCase.fromJson(m.cast<String, dynamic>()))
        .toList(growable: false);
    _cache = list;
    debugPrint('[TodayCaseService] cached ${list.length} TodayCase items');
    return list;
  }

  /// Picks a uniformly-random entry from the loaded pool.
  /// When [excludeLogourl] is given, that key is skipped so
  /// the user doesn't see the same case twice in a row.
  Future<TodayCase?> pickRandom({String? excludeLogourl}) async {
    final pool = await loadAll();
    if (pool.isEmpty) return null;
    if (pool.length == 1) return pool.first;

    final filtered = excludeLogourl == null
        ? pool
        : pool
            .where((c) => c.logourl != excludeLogourl)
            .toList(growable: false);
    final source = filtered.isEmpty ? pool : filtered;
    return source[_rng.nextInt(source.length)];
  }

  /// Looks up a case by its `logourl` key. Returns `null`
  /// if the pool hasn't been loaded yet or no entry matches.
  Future<TodayCase?> pickByLogourl(String logourl) async {
    final pool = await loadAll();
    for (final c in pool) {
      if (c.logourl == logourl) return c;
    }
    return null;
  }
}