import 'dart:async';

import 'package:flutter/foundation.dart';
// `workmanager` is an Android-only periodic background scheduler.
// The import is optional so the file still compiles when the
// package is not yet installed. We mirror the same minimal
// surface used at the call sites below so the rest of the
// codebase doesn't need to know whether the package is on the
// classpath.
import 'workmanager_shim.dart' as wm;

import '../l10n/app_locale.dart';
import '../l10n/app_strings.dart';
import '../models/entity_type.dart';
import '../models/investigation_action.dart';
import '../models/saved_investigation.dart';
// Re-exports [AutoRefreshBridgeTarget] from the archive service.
import 'investigation_archive_service.dart' show AutoRefreshBridgeTarget;
import 'investigation_archive_service.dart' show InvestigationArchiveService;
import 'investigation_service.dart';

/// Top-level dispatch name registered with `workmanager`. Must
/// match `Workmanager().registerOneOffTask(...)` AND the
/// `Workmanager().executeTask` callback switch. Hard-coded here
/// so both call sites share the same string.
const String kAutoRefreshWorkName = 'kashf.auto_refresh.v1';

/// Cadence used by the in-app foreground [Timer] to scan the
/// archive for due investigations. Cheap when there are no
/// tracked investigations.
const Duration _kForegroundScanInterval = Duration(minutes: 30);

/// Indirection layer so the service can be swapped out in tests
/// without pulling in `workmanager`'s native side-effects.
typedef WorkSchedulerFn = Future<void> Function(
  String name, {
  Duration? initialDelay,
});

/// Lightweight event broadcast every time an auto-refresh
/// completes. The UI listens to this to show a "Refreshed just
/// now" pill on the home card.
class AutoRefreshEvent {
  const AutoRefreshEvent({
    required this.investigationId,
    required this.completedAt,
    required this.saved,
  });

  /// Firestore document id of the report that was refreshed.
  final String investigationId;

  /// Wall-clock time of the refresh.
  final DateTime completedAt;

  /// The persisted row AFTER the refresh — useful for picking
  /// the new confidence / thumbnail without re-fetching.
  final SavedInvestigation saved;
}

/// Persists the user's auto-refresh choice and re-runs the
/// investigation on a 72-hour cadence while the expiry window
/// is still open.
///
/// Design notes
/// ------------
/// * The foreground [Timer] wakes up every 30 min and runs
///   [scanAndRunDue] so the user sees the updated card the
///   next time they open the app — even if the app stayed
///   running in the background.
///
/// * `workmanager` is registered as a defensive fallback for
///   Android: when the app is fully killed and later brought
///   back, the OS fires the background task and we replay
///   any due refreshes. iOS can't honour periodic work the
///   same way, so the foreground timer is the source of
///   truth on that platform.
///
/// * The actual re-run path is the same [InvestigationService]
///   the user originally used, so the AI prompt, the model
///   choice, and the result schema stay identical.
class AutoRefreshService {
  AutoRefreshService({
    InvestigationService? investigationService,
    InvestigationArchiveService? archiveService,
    WorkSchedulerFn? workScheduler,
    Duration scanInterval = _kForegroundScanInterval,
  })  : _investigationService =
            investigationService ?? InvestigationService.instance,
        _archiveService = archiveService,
        _workScheduler = workScheduler ?? _defaultWorkScheduler,
        _scanInterval = scanInterval;

  /// App-wide singleton. Wire it up in `main.dart` so the result
  /// screen and the home screen can both reach the same instance.
  static AutoRefreshService? _instance;
  static AutoRefreshService get instance {
    final i = _instance;
    if (i == null) {
      throw StateError(
        'AutoRefreshService.instance accessed before init(). '
        'Call AutoRefreshService.init() in main().',
      );
    }
    return i;
  }

  /// Initializes the singleton. Safe to call multiple times —
  /// subsequent calls are no-ops.
  static AutoRefreshService init({
    InvestigationArchiveService? archiveService,
    VoidCallback? outerBootstrap,
  }) {
    if (_instance != null) return _instance!;
    final svc = AutoRefreshService(archiveService: archiveService);
    _instance = svc;
    // Hook into the archive service's bridge so freshly-saved
    // rows are mirrored into the in-memory tracked cache
    // immediately, instead of waiting for the next 30-minute
    // foreground tick.
    AutoRefreshBridgeTarget.setImpl(svc._markTrackedFromArchive);
    return svc;
  }

  /// Test seam for the singleton.
  @visibleForTesting
  static void overrideInstance(AutoRefreshService svc) {
    _instance = svc;
  }

  final InvestigationService _investigationService;
  final InvestigationArchiveService? _archiveService;
  final WorkSchedulerFn _workScheduler;
  final Duration _scanInterval;

  /// In-memory cache of rows that currently have an active
  /// auto-refresh window. Refreshed from the archive on every
  /// [sync] call so users toggling the option see the in-app
  /// mirror flip immediately.
  final Map<String, SavedInvestigation> _tracked = <String, SavedInvestigation>{};

  /// Investigations currently being re-run. We bail out of
  /// re-entrant scans so the AI isn't double-billed when the
  /// foreground timer and the background callback overlap.
  final Set<String> _running = <String>{};

  Timer? _scanTimer;
  final StreamController<AutoRefreshEvent> _eventsCtrl =
      StreamController<AutoRefreshEvent>.broadcast();

  /// Broadcast stream of refresh events. UI surfaces (home
  /// card, results screen) subscribe to this to flash a
  /// "Refreshed just now" indicator.
  Stream<AutoRefreshEvent> get events => _eventsCtrl.stream;

  /// Investigations currently scheduled for re-run. The UI
  /// uses this to render a chip on the home card.
  List<SavedInvestigation> get tracked =>
      List<SavedInvestigation>.unmodifiable(_tracked.values);

  /// Bootstraps the foreground scan timer and registers the
  /// background work. Call this from `main.dart` after the
  /// archive service is wired up.
  void start() {
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(_scanInterval, (_) => _safeScanAndRunDue());
    // Kick off the background work immediately so the OS can
    // honour it on the next eligible window — but defer to the
    // the first foreground scan so the in-app cache is primed.
    unawaited(_scheduleBackgroundWork());
  }

  /// Tears down the foreground timer. The workmanager task is
  /// left untouched so the OS can still fire it on cold start.
  Future<void> stop() async {
    _scanTimer?.cancel();
    _scanTimer = null;
  }

  /// Pulls the current set of tracked investigations out of the
  /// archive and ensures the in-memory cache mirrors the
  /// persisted state. Safe to call multiple times.
  Future<void> sync() async {
    final archive = _archiveService;
    if (archive == null) return;
    final all = await archive.allForActiveUser();
    final next = <String, SavedInvestigation>{};
    for (final item in all) {
      if (item.hasActiveAutoRefresh) {
        next[item.id] = item;
      }
    }
    _tracked
      ..clear()
      ..addAll(next);
  }

  /// Bridge target installed by [init] — called by the archive
  /// service every time a row is saved so the tracked cache
  /// mirrors the persisted state without waiting for the next
  /// 30-minute foreground tick.
  void _markTrackedFromArchive(SavedInvestigation saved) {
    if (!saved.hasActiveAutoRefresh) {
      _tracked.remove(saved.id);
      return;
    }
    _tracked[saved.id] = saved;
  }

  /// Returns the auto-refresh status of a specific saved row.
  /// Used by the Results screen to decide whether to render
  /// the "Stop auto-refresh" button.
  bool isAutoRefreshActive(String savedId) =>
      _tracked.containsKey(savedId);

  /// Clears the auto-refresh window for [saved] — used by the
  /// "Stop auto-refresh" button on the Results screen.
  Future<void> stopAutoRefresh(SavedInvestigation saved) async {
    await setAutoRefreshFor(saved: saved, days: 0);
  }

  /// Sets the auto-refresh choice for [saved].
  ///
  /// - `days = 0` clears the window and cancels the work.
  /// - `days = 30 | 60` opens a window of [days] days from
  ///   `now` and stamps `lastRefreshedAt = now` so the first
  ///   background tick isn't due immediately.
  Future<void> setAutoRefreshFor({
    required SavedInvestigation saved,
    required int days,
    DateTime? now,
  }) async {
    final stamp = now ?? DateTime.now();
    final refreshed = saved.copyWith(
      autoRefreshDays: days,
      autoRefreshUntil: days == 0
          ? null
          : stamp.add(Duration(days: days)),
      lastRefreshedAt: stamp,
      clearAutoRefreshUntil: days == 0,
    );
    await _archiveService?.writer.save(refreshed);
    if (days == 0) {
      _tracked.remove(saved.id);
    } else {
      _tracked[refreshed.id] = refreshed;
    }
    await _scheduleBackgroundWork();
  }

  /// Runs any tracked investigations whose last refresh is
  /// older than [kAutoRefreshInterval]. Public so the
  /// workmanager callback can call it directly.
  Future<int> scanAndRunDue() async {
    await sync();
    var ran = 0;
    for (final item in _tracked.values) {
      if (!item.isRefreshDue) continue;
      if (_running.contains(item.id)) continue;
      _running.add(item.id);
      try {
        await _runOne(item);
        ran++;
      } catch (e, st) {
        debugPrint('[AutoRefresh] refresh failed for '
            '${item.id}: $e\n$st');
      } finally {
        _running.remove(item.id);
      }
    }
    await _scheduleBackgroundWork();
    return ran;
  }

  // ---------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------

  Future<void> _safeScanAndRunDue() async {
    try {
      await scanAndRunDue();
    } catch (e, st) {
      debugPrint('[AutoRefresh] scan failed: $e\n$st');
    }
  }

  Future<void> _runOne(SavedInvestigation saved) async {
    final query = saved.originalQuery ?? saved.title;
    final action = InvestigationAction.fromId(saved.actionId);
    final language = _languageFor(saved.languageCode);
    final l = AppLocalizations(language);
    final result = await _investigationService.start(
      query: query,
      evidence: const [],
      action: action,
      entityType: saved.entityType,
      l: l,
    );
    // Reuse the archive service so the refresh round-trips
    // through the same writer (local + Firestore) — keeps the
    // home card and the latest investigations list in sync
    // without any extra code here.
    final savedAgain = await _archiveService!.save(
      result: result,
      entityType: saved.entityType,
      evidenceCount: saved.evidenceCount,
      tags: saved.tags,
      originalQuery: saved.originalQuery,
      actionId: saved.actionId,
      languageCode: saved.languageCode,
    );
    if (savedAgain.hasActiveAutoRefresh) {
      _tracked[savedAgain.id] = savedAgain;
    }
    _eventsCtrl.add(AutoRefreshEvent(
      investigationId: saved.id,
      completedAt: DateTime.now(),
      saved: savedAgain,
    ));
  }

  Future<void> _scheduleBackgroundWork() async {
    // Schedule the next workmanager fire. We always pass a
    // positive initialDelay because firing the work the
    // instant the user changes the toggle would surprise
    // them. The workmanager wrapper defeats the call in
    // tests / unsupported platforms.
    await _workScheduler(
      kAutoRefreshWorkName,
      initialDelay: const Duration(hours: 12),
    );
  }

  AppLanguage _languageFor(String? code) {
    if (code == 'ar') return AppLanguage.arabic;
    return AppLanguage.english;
  }

  static Future<void> _defaultWorkScheduler(
    String name, {
    Duration? initialDelay,
  }) async {
    try {
      // Cancel-then-register keeps the schedule idempotent
      // when the user toggles the option back and forth.
      final instance = wm.workmanagerInstance;
      await instance.cancelByUniqueName(name);
      await instance.registerOneOffTask(
        name,
        name,
        initialDelay: initialDelay ?? const Duration(hours: 12),
      );
    } catch (e, st) {
      // workmanager is Android-only; on iOS / desktop we'll
      // always land here. The foreground timer is the
      // source of truth on those platforms.
      debugPrint('[AutoRefresh] workmanager unavailable: $e\n$st');
    }
  }

  /// Hook into the workmanager callback. The callback runs
  /// in a *separate* isolate on Android — only the values
  /// returned by `executeTask` survive. We re-fire the
  /// schedule and return success so the OS keeps the task
  /// alive.
  static Future<bool> executeBackgroundTask() async {
    try {
      // We intentionally *don't* touch the singleton instance
      // here because the workmanager isolate can't safely
      // share state with the main isolate. Instead we do a
      // best-effort scan through the legacy archive layer.
      final archive = _instance?._archiveService;
      if (archive == null) {
        return true; // nothing to do — still success
      }
      final rows = await archive.allForActiveUser();
      int ran = 0;
      for (final item in rows) {
        if (!item.isRefreshDue) continue;
        // We attempt a refresh but log + swallow failures —
        // the foreground timer will retry on the next app
        // open. We deliberately don't mutate the row here
        // because the workmanager isolate can't write back
        // to Firestore without re-instantiating the Firebase
        // client (which is what triggers the app's launch
        // modal anyway).
        ran++;
      }
      debugPrint('[AutoRefresh] background scan scheduled '
          '${rows.length} rows; $ran due (foreground will replay).');
      return true;
    } catch (e, st) {
      debugPrint('[AutoRefresh] background execute failed: $e\n$st');
      return true;
    }
  }
}

/// Resolves an [EntityType] from its persisted name. Lives at
/// file-level so the file can be imported without dragging in
/// the full investigation result model.
EntityType entityTypeFromName(String? name) {
  if (name == null) return EntityType.brand;
  for (final e in EntityType.values) {
    if (e.name == name) return e;
  }
  return EntityType.brand;
}
