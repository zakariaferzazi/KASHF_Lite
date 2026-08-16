import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../settings_preferences.dart';
import 'ai_model_options.dart';

/// Whether [model] should be overridden to a video-capable
/// model when the user has uploaded video evidence. `gpt-5.6-luna`
/// doesn't support video input; `xiaomi/mimo-v2.5` does.
const String kVideoCapableModelId = 'xiaomi/mimo-v2.5';

/// Whether [model] should be overridden to a video-capable
/// model when the user has uploaded video evidence.
bool isVideoCapableModel(String? modelId) =>
    modelId == kVideoCapableModelId;

/// Centralised configuration for the OpenRouter AI integration.
///
/// All sensitive values (API key, base URL, model) are sourced from a
/// `.env` file at runtime via `flutter_dotenv`. Falling back to safe
/// defaults means the rest of the app can still bootstrap in dev /
/// test environments where the env file is missing.
class OpenRouterConfig {
  OpenRouterConfig._();

  /// The OpenRouter chat completions endpoint. The OpenRouter API is
  /// OpenAI-compatible so we use the same path as
  /// `https://openrouter.ai/api/v1/chat/completions`.
  static const String _defaultBaseUrl = 'https://openrouter.ai/api/v1';

  /// Default model used when the user / app does not override it.
  /// We pick a fast, cheap model that is well suited for structured
  /// JSON output: `inclusionai/ling-2.6-flash`.
  static const String _defaultModel = 'inclusionai/ling-2.6-flash';

  /// Hard timeout for a single HTTP request. Models like
  /// `qwen/qwen3.7-flash` can take 30–60s on the free tier when
  /// the model is cold or rate-limited. Set generously so slower
  /// models don't get killed mid-generation. Web-search-enabled
  /// requests chain tool calls and can take 2-3x longer, so we
  /// default to a high cap that works for both paths.
  static const Duration requestTimeout = Duration(seconds: 150);

  /// How many times we retry a transient failure (network glitch,
  /// 5xx, 429 timeout). 5 attempts gives slower models like
  /// qwen/qwen3.7-flash enough room to recover from a cold start
  /// on the free tier without making the user wait forever.
  static const int maxRetries = 5;

  /// Base delay between retries. We use exponential backoff +
  /// jitter (see [OpenRouterClient]) so the actual delay grows.
  static const Duration baseRetryDelay = Duration(milliseconds: 600);

  /// Max in-flight requests we issue concurrently. OpenRouter's
  /// free tier is rate-limited per minute and per day; throttling
  /// client-side keeps us well within those limits.
  static const int maxConcurrentRequests = 4;

  /// How long the rate-limiter window is, in milliseconds. We
  /// allow at most [maxRequestsPerWindow] requests per window.
  static const int rateLimitWindowMs = 60 * 1000;
  static const int maxRequestsPerWindow = 20;

  /// Optional Referer header — OpenRouter tracks usage by referer
  /// for ranking. Defaults to the app's marketing URL.
  static const String defaultReferer = 'https://kashf-lite.app';

  /// Optional title shown in the OpenRouter dashboard. Defaults to
  /// the app's display name.
  static const String defaultAppTitle = 'KASHF Lite';

  /// Read the API key from the .env file. Throws an
  /// [OpenRouterConfigException] when missing so callers can
  /// surface a clear error instead of silently using an empty key.
  static String get apiKey {
    final key = dotenv.maybeGet('OPENROUTER_API_KEY');
    if (key == null || key.trim().isEmpty) {
      throw const OpenRouterConfigException(
        'OPENROUTER_API_KEY is missing. Add it to your .env file.',
      );
    }
    return key.trim();
  }

  /// Whether the API key is configured. Use this in UI to disable
  /// the AI features without crashing.
  static bool get isConfigured {
    final key = dotenv.maybeGet('OPENROUTER_API_KEY');
    return key != null && key.trim().isNotEmpty;
  }

  /// Base URL for the OpenRouter API. Override-able through the
  /// `OPENROUTER_BASE_URL` env var for testing against the
  /// OpenRouter-compatible mock servers.
  static String get baseUrl {
    final override = dotenv.maybeGet('OPENROUTER_BASE_URL');
    if (override != null && override.trim().isNotEmpty) {
      return override.trim();
    }
    return _defaultBaseUrl;
  }

  /// Model identifier used by the chat completion.
  ///
  /// Precedence:
  ///   1. If [forceVideoCapable] is true, always return
  ///      [kVideoCapableModelId] — the user uploaded video
  ///      evidence and gpt-5.6-luna doesn't support video.
  ///   2. The user's saved pick in [SettingsPreferences]
  ///      (Settings → AI model). This is the source of truth for
  ///      every user — switching model in Settings MUST be honoured
  ///      on the very next request.
  ///   3. The bundled default ([kDefaultAiModelId]) when the user
  ///      hasn't picked one yet.
  ///
  /// The `OPENROUTER_MODEL` env var used to be a hard override
  /// here. It was removed: a stray `.env` file silently pinned
  /// every install to the default model regardless of the user's
  /// Settings choice, which made the Settings picker look broken.
  static String model({bool forceVideoCapable = false}) {
    // Video evidence requires a video-capable model. Auto-switch
    // transparently so the user never has to manually change
    // their model pick in Settings just because they uploaded
    // a video.
    if (forceVideoCapable) return kVideoCapableModelId;
    final prefs = SettingsPreferences.instance;
    final userPick = prefs?.aiModelId.trim();
    if (userPick != null && userPick.isNotEmpty) {
      return userPick;
    }
    return _defaultModel;
  }

  /// Referer header. Override-able through `OPENROUTER_REFERER`.
  static String get referer {
    final override = dotenv.maybeGet('OPENROUTER_REFERER');
    if (override != null && override.trim().isNotEmpty) {
      return override.trim();
    }
    return defaultReferer;
  }

  /// App title header. Override-able through `OPENROUTER_APP_TITLE`.
  static String get appTitle {
    final override = dotenv.maybeGet('OPENROUTER_APP_TITLE');
    if (override != null && override.trim().isNotEmpty) {
      return override.trim();
    }
    return defaultAppTitle;
  }
}

/// Thrown when the OpenRouter configuration is missing or invalid.
class OpenRouterConfigException implements Exception {
  const OpenRouterConfigException(this.message);
  final String message;

  @override
  String toString() => 'OpenRouterConfigException: $message';
}
