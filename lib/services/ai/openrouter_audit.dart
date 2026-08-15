import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

/// A single audit log entry for an OpenRouter API call. Persisted
/// in-memory only (the MVP does not yet write to disk so we don't
/// leak PII through log files). The shape is intentionally JSON
/// friendly so we can swap in a remote log sink later.
@immutable
class OpenRouterAuditEntry {
  const OpenRouterAuditEntry({
    required this.timestamp,
    required this.endpoint,
    required this.model,
    required this.statusCode,
    required this.durationMs,
    required this.success,
    this.errorType,
    this.errorMessage,
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
  });

  final DateTime timestamp;
  final String endpoint;
  final String model;
  final int statusCode;
  final int durationMs;
  final bool success;

  final String? errorType;
  final String? errorMessage;

  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;

  Map<String, dynamic> toJson() => {
        'ts': timestamp.toIso8601String(),
        'endpoint': endpoint,
        'model': model,
        'status': statusCode,
        'duration_ms': durationMs,
        'success': success,
        if (errorType != null) 'error_type': errorType,
        if (errorMessage != null) 'error': errorMessage,
        if (promptTokens != null) 'prompt_tokens': promptTokens,
        if (completionTokens != null) 'completion_tokens': completionTokens,
        if (totalTokens != null) 'total_tokens': totalTokens,
      };
}

/// In-memory audit log for OpenRouter API calls.
///
/// Why a singleton? The HTTP client is a singleton and we want the
/// audit log to live for the whole app session so the user can scroll
/// through "what just happened" under debug logs. We expose a
/// [stream] for any UI that wants to render them.
class OpenRouterAuditLog {
  OpenRouterAuditLog._();

  static final OpenRouterAuditLog instance = OpenRouterAuditLog._();

  final List<OpenRouterAuditEntry> _entries = <OpenRouterAuditEntry>[];
  final StreamController<OpenRouterAuditEntry> _controller =
      StreamController<OpenRouterAuditEntry>.broadcast();

  /// Last [maxEntries] entries, newest first.
  List<OpenRouterAuditEntry> get recent => List.unmodifiable(_entries);

  /// Live stream of new entries.
  Stream<OpenRouterAuditEntry> get stream => _controller.stream;

  static const int _maxEntries = 200;

  void record(OpenRouterAuditEntry entry) {
    _entries.insert(0, entry);
    if (_entries.length > _maxEntries) {
      _entries.removeRange(_maxEntries, _entries.length);
    }
    _controller.add(entry);
    if (kDebugMode) {
      // Pretty-print the entry so devs can read it in the console.
      // We never log the request body — it can contain user PII.
      // ignore: avoid_print
      print('[OpenRouter] ${jsonEncode(entry.toJson())}');
    }
  }

  void clear() {
    _entries.clear();
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
