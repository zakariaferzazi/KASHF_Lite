import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'openrouter_audit.dart';
import 'openrouter_config.dart';
import 'openrouter_rate_limiter.dart';

/// A single chat message compatible with the OpenAI / OpenRouter
/// chat-completions API.
@immutable
class OpenRouterMessage {
  const OpenRouterMessage({required this.role, required this.content});

  /// One of: `system`, `user`, `assistant`.
  final String role;
  final String content;

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
      };
}

/// A request to the OpenRouter chat-completions endpoint. The fields
/// here are the minimum needed for the home dashboard use cases; if
/// you need more (stop sequences, function calls, vision, etc.) you
/// can extend this struct and the [OpenRouterClient] will pass them
/// through.
@immutable
class OpenRouterRequest {
  const OpenRouterRequest({
    required this.messages,
    this.model,
    this.temperature = 0.4,
    this.maxTokens = 800,
    this.responseFormat,
    this.extra = const <String, dynamic>{},
  });

  final List<OpenRouterMessage> messages;
  final String? model;
  final double temperature;
  final int maxTokens;

  /// Optional override for the response format. Use
  /// `{'type': 'json_object'}` to force JSON mode.
  final Map<String, dynamic>? responseFormat;

  /// Anything else we want to merge into the request body
  /// (e.g. tool calls, stop sequences).
  final Map<String, dynamic> extra;
}

/// Successful response payload.
@immutable
class OpenRouterResponse {
  const OpenRouterResponse({
    required this.content,
    required this.model,
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
    required this.raw,
    this.finishReason,
  });

  /// The first message's content (the assistant's reply).
  final String content;

  /// The model that actually served the request (resolved by
  /// OpenRouter based on availability / load).
  final String model;

  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;

  /// Why the model stopped. `"length"` indicates the response
  /// was truncated by the max_tokens cap. Useful for diagnosing
  /// parse failures.
  final String? finishReason;

  /// The raw decoded JSON body for callers that need access to
  /// additional fields (e.g. tool calls).
  final Map<String, dynamic> raw;
}

/// Thrown when the OpenRouter API call fails after all retries.
class OpenRouterException implements Exception {
  const OpenRouterException({
    required this.message,
    this.statusCode,
    this.type = OpenRouterErrorType.unknown,
  });

  final String message;
  final int? statusCode;
  final OpenRouterErrorType type;

  @override
  String toString() => 'OpenRouterException($type, $statusCode): $message';
}

enum OpenRouterErrorType {
  network,
  timeout,
  auth,
  rateLimit,
  badRequest,
  server,
  parse,
  rateLimitLocal,
  config,
  unknown,
}

/// Default sleep function used between retries. Indirected so tests
/// can swap in a no-op.
typedef OpenRouterSleep = Future<void> Function(Duration);

/// Default implementation of [OpenRouterSleep].
Future<void> _defaultSleep(Duration d) => Future<void>.delayed(d);

/// Singleton HTTP client for OpenRouter.
///
/// Responsibilities:
///  * Authenticate using the API key from [OpenRouterConfig].
///  * Enforce request validation (non-empty messages, valid
///    temperature, etc.).
///  * Apply retries with exponential backoff + jitter.
///  * Throttle concurrent requests via [OpenRouterRateLimiter].
///  * Sanitize user content before sending.
///  * Persist an audit log via [OpenRouterAuditLog].
class OpenRouterClient {
  OpenRouterClient({
    http.Client? httpClient,
    OpenRouterAuditLog? auditLog,
    OpenRouterRateLimiter? rateLimiter,
    OpenRouterSleep? sleep,
    math.Random? random,
  })  : _http = httpClient ?? http.Client(),
        _auditLog = auditLog ?? OpenRouterAuditLog.instance,
        _rateLimiter = rateLimiter ?? OpenRouterRateLimiter.instance,
        _sleep = sleep ?? _defaultSleep,
        _random = random ?? math.Random();

  static final OpenRouterClient instance = OpenRouterClient();

  final http.Client _http;
  final OpenRouterAuditLog _auditLog;
  final OpenRouterRateLimiter _rateLimiter;
  final OpenRouterSleep _sleep;
  final math.Random _random;

  /// Public entry point. Sends a chat completion request, applies
  /// retries, and returns the parsed response. Throws
  /// [OpenRouterException] on failure.
  Future<OpenRouterResponse> chatCompletion(OpenRouterRequest req) async {
    _validateRequest(req);

    final body = _buildBody(req);
    final endpoint = '${OpenRouterConfig.baseUrl}/chat/completions';
    final startedAt = DateTime.now();

    // No API key → record and bail out fast. We treat this as a
    // hard failure so the UI can show a "configure API key" banner.
    if (!OpenRouterConfig.isConfigured) {
      _auditLog.record(OpenRouterAuditEntry(
        timestamp: startedAt,
        endpoint: endpoint,
        model: req.model ?? OpenRouterConfig.model,
        statusCode: 0,
        durationMs: 0,
        success: false,
        errorType: 'config',
        errorMessage: 'OPENROUTER_API_KEY missing',
      ));
      throw const OpenRouterException(
        message: 'OpenRouter API key is not configured.',
        type: OpenRouterErrorType.config,
      );
    }

    Object? lastError;
    int? lastStatus;
    for (var attempt = 0; attempt < OpenRouterConfig.maxRetries; attempt++) {
      try {
        await _rateLimiter.acquire();
        try {
          final response = await _postJson(
            endpoint: endpoint,
            body: body,
            headers: _headers(),
          );
          final status = response.statusCode;
          lastStatus = status;

          if (status >= 200 && status < 300) {
            final parsed = _parseResponse(response.body);
            _auditLog.record(OpenRouterAuditEntry(
              timestamp: DateTime.now(),
              endpoint: endpoint,
              model: parsed.model,
              statusCode: status,
              durationMs:
                  DateTime.now().difference(startedAt).inMilliseconds,
              success: true,
              promptTokens: parsed.promptTokens,
              completionTokens: parsed.completionTokens,
              totalTokens: parsed.totalTokens,
            ));
            return parsed;
          }

          // 4xx / 5xx handling.
          final errType = _classifyStatus(status);
          // Do not retry auth failures or bad-requests — they will
          // never succeed on retry.
          if (errType == OpenRouterErrorType.auth ||
              errType == OpenRouterErrorType.badRequest) {
            _auditLog.record(OpenRouterAuditEntry(
              timestamp: DateTime.now(),
              endpoint: endpoint,
              model: req.model ?? OpenRouterConfig.model,
              statusCode: status,
              durationMs:
                  DateTime.now().difference(startedAt).inMilliseconds,
              success: false,
              errorType: errType.name,
              errorMessage: _extractErrorMessage(response.body),
            ));
            throw OpenRouterException(
              message: _extractErrorMessage(response.body),
              statusCode: status,
              type: errType,
            );
          }

          lastError = OpenRouterException(
            message: _extractErrorMessage(response.body),
            statusCode: status,
            type: errType,
          );
        } finally {
          _rateLimiter.release();
        }
      } catch (e) {
        // Classify whatever bubbled up so we can decide whether to
        // retry, rethrow, or back off.
        final classified = _classifyException(e);
        lastError = classified;
        if (classified.type == OpenRouterErrorType.auth ||
            classified.type == OpenRouterErrorType.badRequest ||
            classified.type == OpenRouterErrorType.config) {
          rethrow;
        }
      }

      // Don't sleep after the last attempt.
      if (attempt < OpenRouterConfig.maxRetries - 1) {
        await _sleep(_backoffDelay(attempt));
      }
    }

    final durationMs = DateTime.now().difference(startedAt).inMilliseconds;
    final err = lastError is OpenRouterException
        ? lastError
        : OpenRouterException(
            message: lastError?.toString() ?? 'Unknown error',
            statusCode: lastStatus,
            type: OpenRouterErrorType.unknown,
          );
    _auditLog.record(OpenRouterAuditEntry(
      timestamp: DateTime.now(),
      endpoint: endpoint,
      model: req.model ?? OpenRouterConfig.model,
      statusCode: lastStatus ?? 0,
      durationMs: durationMs,
      success: false,
      errorType: err.type.name,
      errorMessage: err.message,
    ));
    throw err;
  }

  /// Convenience wrapper that asks the model for JSON and returns
  /// the parsed map. Throws [OpenRouterException] with type
  /// [OpenRouterErrorType.parse] if the response is not valid JSON.
  Future<Map<String, dynamic>> chatCompletionJson(
    OpenRouterRequest req, {
    bool enforceJsonObject = true,
  }) async {
    final request = enforceJsonObject
        ? OpenRouterRequest(
            messages: req.messages,
            model: req.model,
            temperature: req.temperature,
            maxTokens: req.maxTokens,
            responseFormat: const {'type': 'json_object'},
            extra: req.extra,
          )
        : req;

    final response = await chatCompletion(request);
    final raw = response.content.trim();

    // Be generous: the model sometimes wraps the JSON in ```json
    // fences. Strip them before parsing.
    final cleaned = _stripCodeFence(raw);
    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) return decoded;
      throw const FormatException('Expected JSON object at top level.');
    } on FormatException catch (e) {
      // If the model reported a `length` finish reason, the JSON
      // was almost certainly truncated by the max_tokens cap —
      // surface a clearer message so callers know to bump the
      // token budget.
      final wasTruncated = response.finishReason == 'length';
      final hint = wasTruncated
          ? ' (response hit max_tokens cap and was truncated; raise the token budget)'
          : '';
      throw OpenRouterException(
        message: 'Failed to parse JSON response: ${e.message}$hint',
        type: OpenRouterErrorType.parse,
      );
    }
  }

  void close() {
    _http.close();
  }

  // ---------- Internals ----------

  Map<String, String> _headers() {
    return {
      'Authorization': 'Bearer ${OpenRouterConfig.apiKey}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'HTTP-Referer': OpenRouterConfig.referer,
      'X-Title': OpenRouterConfig.appTitle,
    };
  }

  void _validateRequest(OpenRouterRequest req) {
    if (req.messages.isEmpty) {
      throw const OpenRouterException(
        message: 'Request must include at least one message.',
        type: OpenRouterErrorType.badRequest,
      );
    }
    if (req.temperature < 0 || req.temperature > 2) {
      throw const OpenRouterException(
        message: 'temperature must be between 0 and 2.',
        type: OpenRouterErrorType.badRequest,
      );
    }
    if (req.maxTokens <= 0 || req.maxTokens > 8000) {
      throw const OpenRouterException(
        message: 'maxTokens must be between 1 and 8000.',
        type: OpenRouterErrorType.badRequest,
      );
    }
    for (final m in req.messages) {
      if (m.role != 'system' && m.role != 'user' && m.role != 'assistant') {
        throw OpenRouterException(
          message: 'Invalid message role: ${m.role}',
          type: OpenRouterErrorType.badRequest,
        );
      }
    }
  }

  Map<String, dynamic> _buildBody(OpenRouterRequest req) {
    final body = <String, dynamic>{
      'model': req.model ?? OpenRouterConfig.model,
      'messages': req.messages.map((m) => m.toJson()).toList(),
      'temperature': req.temperature,
      'max_tokens': req.maxTokens,
      if (req.responseFormat != null) 'response_format': req.responseFormat,
      ...req.extra,
    };
    return body;
  }

  Future<http.Response> _postJson({
    required String endpoint,
    required Map<String, dynamic> body,
    required Map<String, String> headers,
  }) {
    final uri = Uri.parse(endpoint);
    return _http
        .post(
          uri,
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(OpenRouterConfig.requestTimeout);
  }

  OpenRouterResponse _parseResponse(String body) {
    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Top-level JSON is not an object.');
      }
      json = decoded;
    } on FormatException catch (e) {
      throw OpenRouterException(
        message: 'Failed to decode response: ${e.message}',
        type: OpenRouterErrorType.parse,
      );
    }

    final choices = json['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const OpenRouterException(
        message: 'Response contains no choices.',
        type: OpenRouterErrorType.parse,
      );
    }

    final first = choices.first;
    if (first is! Map<String, dynamic>) {
      throw const OpenRouterException(
        message: 'Invalid choice payload.',
        type: OpenRouterErrorType.parse,
      );
    }

    final message = first['message'];
    String content = '';
    if (message is Map<String, dynamic>) {
      final c = message['content'];
      if (c is String) content = c;
    }
    final model = (json['model'] as String?) ??
        OpenRouterConfig.model;
    final finishReason = first['finish_reason'] as String?;

    int? readTokens(String key) {
      final usage = json['usage'];
      if (usage is Map<String, dynamic>) {
        final v = usage[key];
        if (v is int) return v;
        if (v is num) return v.toInt();
      }
      return null;
    }

    return OpenRouterResponse(
      content: content,
      model: model,
      promptTokens: readTokens('prompt_tokens'),
      completionTokens: readTokens('completion_tokens'),
      totalTokens: readTokens('total_tokens'),
      finishReason: finishReason,
      raw: json,
    );
  }

  OpenRouterErrorType _classifyStatus(int status) {
    if (status == 401 || status == 403) return OpenRouterErrorType.auth;
    if (status == 408) return OpenRouterErrorType.timeout;
    if (status == 429) return OpenRouterErrorType.rateLimit;
    if (status >= 400 && status < 500) return OpenRouterErrorType.badRequest;
    if (status >= 500 && status < 600) return OpenRouterErrorType.server;
    return OpenRouterErrorType.unknown;
  }

  /// Maps a thrown exception to an [OpenRouterException] with a
  /// useful [OpenRouterErrorType]. We translate the most common
  /// framework exceptions (timeouts, network failures) into our
  /// own error vocabulary so the upper layers can react uniformly.
  OpenRouterException _classifyException(Object e) {
    if (e is OpenRouterException) return e;
    if (e is TimeoutException) {
      return const OpenRouterException(
        message: 'Request timed out',
        type: OpenRouterErrorType.timeout,
      );
    }
    // http.ClientException is not a subtype of TimeoutException;
    // the analyzer sometimes loses track of unrelated Exception
    // subtypes across packages, so we use pattern matching on the
    // runtimeType to be safe.
    if (e.runtimeType.toString() == 'ClientException') {
      final msg = e.toString();
      return OpenRouterException(
        message: 'Network error: $msg',
        type: OpenRouterErrorType.network,
      );
    }
    if (e is FormatException) {
      return OpenRouterException(
        message: 'Format error: ${e.message}',
        type: OpenRouterErrorType.parse,
      );
    }
    return OpenRouterException(
      message: e.toString(),
      type: OpenRouterErrorType.unknown,
    );
  }

  String _extractErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final err = decoded['error'];
        if (err is Map<String, dynamic>) {
          final msg = err['message'];
          if (msg is String && msg.isNotEmpty) return msg;
        }
      }
    } catch (_) {
      // Fall through — return raw body.
    }
    return body.isEmpty ? 'Unknown error' : body;
  }

  Duration _backoffDelay(int attempt) {
    // Exponential backoff with jitter. attempt=0 -> base, 1 -> 2x,
    // 2 -> 4x, and we add ±25% random jitter.
    final base = OpenRouterConfig.baseRetryDelay.inMilliseconds;
    final exp = base * (1 << attempt);
    final jitter = (_random.nextDouble() - 0.5) * 0.5 * exp;
    return Duration(milliseconds: (exp + jitter).clamp(50, 60000).toInt());
  }

  String _stripCodeFence(String input) {
    var s = input.trim();
    if (s.startsWith('```')) {
      // Strip the opening fence (and optional language tag).
      final newline = s.indexOf('\n');
      if (newline != -1) {
        s = s.substring(newline + 1);
      } else {
        s = s.substring(3);
      }
    }
    if (s.endsWith('```')) {
      s = s.substring(0, s.length - 3);
    }
    // Be defensive: if the model put preamble / postscript
    // around the JSON (e.g. reasoning text), keep only the
    // substring from the first `{` to the last `}`.
    final firstBrace = s.indexOf('{');
    final lastBrace = s.lastIndexOf('}');
    if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
      s = s.substring(firstBrace, lastBrace + 1);
    }
    return s.trim();
  }
}

/// Sanitizes user-provided content before it is sent as a prompt
/// payload. This is intentionally conservative: we strip control
/// characters, neutralise obvious prompt-injection patterns, and
/// cap the length. We do NOT HTML-escape because the payload is
/// JSON, not HTML.
class PromptSanitizer {
  PromptSanitizer._();

  static const int maxLength = 4000;

  /// Returns a sanitized version of [input] safe to embed into a
  /// prompt. Throws [FormatException] if the input is empty after
  /// sanitization.
  static String sanitize(String input) {
    if (input.isEmpty) {
      throw const FormatException('Empty prompt content.');
    }

    var s = input;

    // Strip C0 control chars except newline + tab.
    s = s.replaceAll(RegExp(r'[\u0000-\u0008\u000B-\u001F\u007F]'), '');

    // Neutralise common prompt-injection patterns: ignore
    // instructions that try to override the system prompt.
    const patterns = <String>[
      'ignore previous instructions',
      'ignore the above',
      'disregard prior',
      'system:',
      'assistant:',
      '<|im_start|>',
      '<|im_end|>',
    ];
    final lower = s.toLowerCase();
    for (final p in patterns) {
      if (lower.contains(p)) {
        s = s.replaceAll(RegExp(p, caseSensitive: false), '');
      }
    }

    // Cap length to avoid runaway payloads.
    if (s.length > maxLength) {
      s = s.substring(0, maxLength);
    }

    final trimmed = s.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Prompt content is empty after sanitization.');
    }
    return trimmed;
  }
}
