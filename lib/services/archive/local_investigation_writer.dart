import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/saved_investigation.dart';
import 'investigation_writer.dart';

/// Offline-only [InvestigationWriter] backed by SharedPreferences.
///
/// Persists every row under a single key (`investigation_archive_v1`)
/// as a JSON list. Designed to be the default writer — works on
/// any device without Firebase setup, so the Latest Investigations
/// section is functional from day one.
///
/// When the Firestore writer becomes available (the user installs
/// the cloud_firestore package + runs pub get), this writer stays
/// in the loop as a **local mirror** (write-through cache) so the
/// home screen never blocks on the network.
class LocalInvestigationWriter implements InvestigationWriter {
  LocalInvestigationWriter();

  static const String _kStorageKey = 'investigation_archive_v1';

  /// Hard cap on cached rows. Anything older is pruned on save.
  static const int _kCap = 60;

  /// In-memory cache backed by `_persistDebouncer`. Every save
  /// triggers a single async flush of the new cache so writes
  /// to SharedPreferences coalesce.
  final Map<String, Map<String, SavedInvestigation>> _byUser = {};
  final StreamController<List<SavedInvestigation>> _ctrl =
      StreamController<List<SavedInvestigation>>.broadcast();

  Future<void> _hydrate() async {
    if (_byUser.isNotEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kStorageKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      for (final entry in decoded.entries) {
        final userId = entry.key.toString();
        final list = entry.value;
        if (list is! List) continue;
        final perUser = <String, SavedInvestigation>{};
        for (final row in list) {
          if (row is! Map) continue;
          try {
            final saved = SavedInvestigation.fromJson(
              row.cast<String, dynamic>(),
            );
            perUser[saved.id] = saved;
          } catch (_) {
            // skip junk rows
          }
        }
        _byUser[userId] = perUser;
      }
    } catch (e, st) {
      debugPrint(
        '[LocalInvestigationWriter] hydrate failed: $e\n$st',
      );
    }
  }

  Future<void> _flush() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serialized = <String, List<Map<String, dynamic>>>{};
      _byUser.forEach((userId, perUser) {
        serialized[userId] = perUser.values
            .map((e) => e.toJson())
            .toList();
      });
      await prefs.setString(_kStorageKey, jsonEncode(serialized));
    } catch (e, st) {
      debugPrint('[LocalInvestigationWriter] flush failed: $e\n$st');
    }
  }

  List<SavedInvestigation> _sortedForUser(String userId, int limit) {
    final perUser = _byUser[userId] ?? const {};
    final list = perUser.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (list.length > limit) return list.sublist(0, limit);
    return list;
  }

  @override
  Future<void> save(SavedInvestigation item) async {
    await _hydrate();
    final perUser = _byUser.putIfAbsent(
      item.userId,
      () => <String, SavedInvestigation>{},
    );
    perUser[item.id] = item;
    // Trim per-user cap (FIFO).
    if (perUser.length > _kCap) {
      final sorted = perUser.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      while (perUser.length > _kCap) {
        perUser.remove(sorted.removeAt(0).id);
      }
    }
    await _flush();
    // Fan-out a fresh snapshot for any active watchers.
    _ctrl.add(_sortedForUser(item.userId, _kCap));
  }

  @override
  Stream<List<SavedInvestigation>> watchLatest(
    String userId, {
    int limit = 8,
  }) async* {
    await _hydrate();
    yield _sortedForUser(userId, limit);
    yield* _ctrl.stream.map((_) => _sortedForUser(userId, limit));
  }

  @override
  Future<int> commitPendingForUser(String userId) async {
    // No-op: the local writer doesn't have a remote to flush into.
    // Kept on the interface so the Firestore writer can take over.
    return 0;
  }

  /// Drops every cached row for [userId] and emits an empty
  /// snapshot so live watchers update without a full refresh.
  /// Returns the number of rows that were removed.
  @override
  Future<int> clearAllForUser(String userId) async {
    await _hydrate();
    final removed = _byUser[userId]?.length ?? 0;
    _byUser.remove(userId);
    await _flush();
    _ctrl.add(_sortedForUser(userId, _kCap));
    return removed;
  }

  /// Removes a single row by [id] from the per-user cache and
  /// emits a fresh snapshot. Returns `true` when the row existed
  /// in the cache and was removed, `false` otherwise. We always
  /// re-emit (even on a miss) so watcher UI that was waiting on
  /// this id gets a deterministic "no change" signal rather than
  /// having to maintain its own poll.
  @override
  Future<bool> deleteOneForUser(String userId, String id) async {
    await _hydrate();
    final perUser = _byUser[userId];
    final removed = perUser?.remove(id) != null;
    if (removed) {
      await _flush();
    }
    _ctrl.add(_sortedForUser(userId, _kCap));
    return removed;
  }
}
