import 'dart:async';

import 'openrouter_config.dart';

/// A simple, in-memory sliding-window rate limiter for OpenRouter
/// calls. We cap the number of requests per [OpenRouterConfig.rateLimitWindowMs]
/// so we never blow through OpenRouter's per-minute limits, even if
/// multiple UI components trigger refreshes at the same time.
class OpenRouterRateLimiter {
  OpenRouterRateLimiter._();

  static final OpenRouterRateLimiter instance = OpenRouterRateLimiter._();

  /// Timestamps of recent requests (newest last).
  final List<DateTime> _window = <DateTime>[];

  /// In-flight request *count* — we use a semaphore-style counter so
  /// we can short-circuit when too many requests are running at once.
  int _inFlight = 0;

  final List<Completer<void>> _waiters = <Completer<void>>[];

  /// Acquire a slot. Throws [OpenRouterRateLimitException] if the
  /// window is already saturated and the caller asked for a strict
  /// reservation. Otherwise waits up to the supplied [waitTimeout]
  /// for a slot to free up.
  Future<void> acquire({
    Duration waitTimeout = const Duration(seconds: 10),
  }) async {
    _evictExpired();

    // Concurrent cap.
    while (_inFlight >= OpenRouterConfig.maxConcurrentRequests) {
      final c = Completer<void>();
      _waiters.add(c);
      final timeout = Future<void>.delayed(waitTimeout, () => c);
      try {
        await Future.any<void>(<Future<void>>[c.future, timeout]);
      } finally {
        _waiters.remove(c);
      }
      _evictExpired();
    }

    // Window cap.
    if (_window.length >= OpenRouterConfig.maxRequestsPerWindow) {
      // We've used the whole window. Wait until the oldest entry
      // expires before issuing another request.
      final wait = _window.first.add(
        Duration(milliseconds: OpenRouterConfig.rateLimitWindowMs),
      );
      final remaining = wait.difference(DateTime.now());
      if (remaining.isNegative == false && remaining < waitTimeout) {
        await Future<void>.delayed(remaining);
      }
      _evictExpired();
      if (_window.length >= OpenRouterConfig.maxRequestsPerWindow) {
        throw const OpenRouterRateLimitException(
          'OpenRouter rate limit reached. Please retry shortly.',
        );
      }
    }

    _inFlight++;
    _window.add(DateTime.now());
  }

  /// Release a slot. Wakes the next queued waiter.
  void release() {
    if (_inFlight > 0) _inFlight--;
    if (_waiters.isNotEmpty) {
      final next = _waiters.removeAt(0);
      if (!next.isCompleted) next.complete();
    }
  }

  void _evictExpired() {
    final cutoff = DateTime.now().subtract(
      Duration(milliseconds: OpenRouterConfig.rateLimitWindowMs),
    );
    _window.removeWhere((d) => d.isBefore(cutoff));
  }

  /// Number of in-flight requests. Useful for tests and debug UI.
  int get inFlight => _inFlight;

  /// Number of requests in the current window.
  int get currentWindowCount => _window.length;
}

/// Thrown when the rate limiter refuses to grant a slot.
class OpenRouterRateLimitException implements Exception {
  const OpenRouterRateLimitException(this.message);
  final String message;

  @override
  String toString() => 'OpenRouterRateLimitException: $message';
}
