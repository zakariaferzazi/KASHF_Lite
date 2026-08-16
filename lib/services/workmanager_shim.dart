import 'package:flutter/foundation.dart';

/// Thin facade around the optional `workmanager` package. We
/// import this through a stable prefix so the rest of the
/// codebase can be written once and works regardless of whether
/// the workmanager package is on the classpath.
///
/// When the package is NOT installed, the shim provides a
/// no-op stub so `flutter analyze` and the foreground flow
/// still work. The Android-only background task won't fire
/// but the in-app `Timer` in `AutoRefreshService` remains
/// the source of truth.
///
/// To enable the Android background path:
///  1. Add `workmanager: ^0.5.2` to `pubspec.yaml`.
///  2. Run `flutter pub get`.
///  3. Replace `_NoopWorkmanager` below with the real
///     `Workmanager()` instance via a `dart:io`-style
///     conditional import.
class _NoopWorkmanager {
  Future<void> initialize(
    void Function() callback, {
    bool isInDebugMode = false,
  }) async {
    // No-op: package not installed.
  }

  Future<void> cancelByUniqueName(String name) async {}

  Future<void> registerOneOffTask(
    String name,
    String taskName, {
    Duration? initialDelay,
    dynamic existingWorkPolicy,
    dynamic constraints,
  }) async {}
}

void _noopExecuteTaskHandler(String task, Map<String, dynamic>? inputData) {
  // Throw a benign message so the auto-refresh service can
  // log it; the foreground timer retries on the next scan.
  debugPrint('[Workmanager shim] no-op dispatcher for $task');
}

/// Singleton accessor for the shim. Real implementations can
/// swap this out at construction time.
dynamic get workmanagerInstance => _NoopWorkmanager();

/// Bridges into the workmanager dispatcher. The real
/// implementation calls `Workmanager().executeTask(...)`.
void executeTaskBridge(String task, Map<String, dynamic>? inputData) {
  _noopExecuteTaskHandler(task, inputData);
}
