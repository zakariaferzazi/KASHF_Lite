import 'dart:async';

import '../../models/investigation_result.dart';
import '../ai/openrouter_client.dart';
import '../ai/openrouter_config.dart';
import 'script_draft.dart';

/// Thrown by [ScriptGeneratorService] when the model can't produce
/// a usable script. The original OpenRouter error is wrapped inside
/// so the UI can show a useful message and the operator can debug
/// from the audit log.
class ScriptGenerationException implements Exception {
  ScriptGenerationException(this.message, {this.cause, this.errorType});

  final String message;
  final OpenRouterErrorType? errorType;
  final Object? cause;

  @override
  String toString() => 'ScriptGenerationException: $message';
}

/// Generates Reel / Podcast scripts from an [InvestigationResult]
/// using a fixed Gemini 2.5 Flash Lite model via the OpenRouter
/// gateway.
///
/// Why a hard-coded model?
///   The "Content Studio" feature is admin-only and is meant to be
///   reproducible regardless of the user's Settings → AI model pick.
///   Pinning the slug inside this service keeps every generated
///   script on the same model so the admin can iterate on prompt
///   tuning without surprises. The Settings model picker still
///   drives the regular investigation flow.
class ScriptGeneratorService {
  ScriptGeneratorService({
    OpenRouterClient? client,
  }) : _client = client ?? OpenRouterClient.instance;

  /// Process-wide singleton. The Content Studio is admin-only and
  /// stateless — every generation is a one-shot call so we share a
  /// single instance and reuse its [OpenRouterClient].
  static final ScriptGeneratorService instance = ScriptGeneratorService();

  /// The model slug used for every generated script. Per the
  /// OpenRouter docs, `google/gemini-2.5-flash-lite` is the
  /// supported identifier for Gemini 2.5 Flash Lite on the
  /// OpenRouter gateway.
  static const String kModelId = 'google/gemini-2.5-flash-lite';

  final OpenRouterClient _client;

  /// Generates a 30-second reel script from [result].
  Future<ScriptDraft> generateReelScript({
    required InvestigationResult result,
  }) {
    return _generate(
      kind: ScriptKind.reel,
      result: result,
      systemPrompt: _reelSystemPrompt,
      userPrompt: _userPromptFor(result),
    );
  }

  /// Generates a ~15-minute podcast script outline from [result].
  Future<ScriptDraft> generatePodcastScript({
    required InvestigationResult result,
  }) {
    return _generate(
      kind: ScriptKind.podcast,
      result: result,
      systemPrompt: _podcastSystemPrompt,
      userPrompt: _userPromptFor(result),
    );
  }

  // -----------------------------------------------------------------
  // Internals
  // -----------------------------------------------------------------

  Future<ScriptDraft> _generate({
    required ScriptKind kind,
    required InvestigationResult result,
    required String systemPrompt,
    required String userPrompt,
  }) async {
    // Fast-fail with a clean message when the OpenRouter API key
    // isn't configured (missing .env, or it failed to load at
    // startup). Without this check, the request would still be
    // built and sent — only to fail in `_headers()` with a raw
    // `NotInitializedError` from `flutter_dotenv`. We translate
    // every low-level dotenv / config exception into a single,
    // user-friendly message here so the script viewer can show it
    // verbatim in the error UI.
    if (!OpenRouterConfig.isConfigured) {
      throw ScriptGenerationException(
        'OpenRouter API key is not configured. Add '
        'OPENROUTER_API_KEY to your .env file (copy .env.example '
        'to .env to start), then rebuild the app.',
        errorType: OpenRouterErrorType.config,
      );
    }
    try {
      // Build the request. We pin the model and disable web search
      // because the source investigation already contains all the
      // grounding context we need — running a web plugin on top of
      // a long prompt both wastes budget and risks the plugin
      // re-introducing information the report explicitly excluded.
      final req = OpenRouterRequest(
        messages: [
          OpenRouterMessage(role: 'system', content: systemPrompt),
          OpenRouterMessage(role: 'user', content: userPrompt),
        ],
        // CRITICAL: this hard-pin bypasses `OpenRouterConfig.model()`
        // (which would otherwise pick up the user's saved choice and
        // route to e.g. `openai/gpt-5.6-luna`). The Content Studio
        // is admin-only and ships with one explicit model id —
        // `google/gemini-2.5-flash-lite`. Anything other than that
        // id here is a bug.
        model: kModelId,
        // 0.7 strikes a good balance for creative script writing:
        // high enough to keep the prose lively, low enough that the
        // model doesn't invent facts the report didn't establish.
        temperature: 0.7,
        maxTokens: kind == ScriptKind.reel ? 1200 : 4000,
        enableWebSearch: false,
        responseFormat: const {'type': 'json_object'},
        purpose: kind == ScriptKind.reel
            ? 'script.reel'
            : 'script.podcast',
      );

      final decoded = await _client.chatCompletionJson(req);

      final sections = <ScriptSection>[];
      final rawSections = decoded['sections'];
      if (rawSections is List) {
        for (final raw in rawSections) {
          if (raw is Map<String, dynamic>) {
            final section = ScriptSection.fromJson(raw);
            if (section.label.isEmpty && section.body.isEmpty) continue;
            sections.add(section);
          }
        }
      }

      final draft = ScriptDraft(
        kind: kind,
        title: (decoded['title'] as String?)?.trim() ?? result.title,
        hook: (decoded['hook'] as String?)?.trim() ?? '',
        sections: sections,
        callToAction:
            (decoded['call_to_action'] as String?)?.trim() ?? '',
        durationSeconds: kind == ScriptKind.reel ? 30 : 900,
        sourceInvestigationId: result.investigationId,
        sourceInvestigationTitle: result.title,
        generatedAt: DateTime.now(),
        platform: kind == ScriptKind.reel
            ? ((decoded['platform'] as String?)?.trim() ?? 'Instagram Reels')
            : '',
      );

      if (draft.sections.isEmpty &&
          draft.hook.isEmpty &&
          draft.callToAction.isEmpty) {
        throw ScriptGenerationException(
          'The model returned an empty script. Please try again.',
        );
      }
      return draft;
    } on OpenRouterException catch (e) {
      throw ScriptGenerationException(
        e.message,
        cause: e,
        errorType: e.type,
      );
    } on ScriptGenerationException {
      rethrow;
    } catch (e) {
      // Translate every other error (including any leaked
      // `flutter_dotenv` `NotInitializedError`) into a clean
      // message so the UI never shows a raw `(NotInitializedError)`.
      throw ScriptGenerationException(
        'Could not generate script (${e.runtimeType}). '
        'Check your network connection and that the OpenRouter '
        'API key is configured.',
        cause: e,
      );
    }
  }

  /// Compresses the investigation into a compact text block the
  /// model can ingest. Sections are listed in their original order;
  /// items are rendered as bullet-style lines so the model can
  /// quote them naturally without losing the structure.
  String _userPromptFor(InvestigationResult result) {
    final buf = StringBuffer()
      ..writeln('Title: ${result.title}')
      ..writeln('Subtitle: ${result.subtitle}')
      ..writeln('Generated at: ${result.generatedAt.toUtc().toIso8601String()}')
      ..writeln('Overall confidence: ${(result.confidence ?? 0).toStringAsFixed(2)}')
      ..writeln()
      ..writeln('Sections:');

    for (final section in result.sections) {
      buf
        ..writeln()
        ..writeln('## ${section.headline}')
        ..writeln(section.summary);
      for (final item in section.items) {
        buf
          ..write('- ')
          ..writeln('${item.title}: ${item.body}');
        if (item.metric != null && item.metric!.isNotEmpty) {
          buf.write('  (');
          buf.write(item.metric);
          if (item.metricLabel != null && item.metricLabel!.isNotEmpty) {
            buf.write(' — ${item.metricLabel}');
          }
          buf.writeln(')');
        }
      }
    }

    if (result.sources.isNotEmpty) {
      buf
        ..writeln()
        ..writeln('Sources (do NOT invent URLs that are not in this list):');
      for (final s in result.sources.take(20)) {
        final url = (s.url ?? '').trim();
        if (url.isEmpty) continue;
        buf.writeln('- ${s.title} — $url');
      }
    }
    return buf.toString();
  }

  // -----------------------------------------------------------------
  // System prompts
  // -----------------------------------------------------------------

  static const String _reelSystemPrompt = '''
You are a senior short-form video copywriter specialised in
turning research reports into 30-second Instagram / TikTok / X
Reels scripts.

You will receive an investigation report (title + sections +
findings + sources). Your job is to produce a single reel script
that:

  1. Is exactly 30 seconds when read aloud at ~150 words per
     minute (≈75 words total, give or take 10).
  2. Opens with a HOOK strong enough to stop a scroll in the first
     2 seconds (shocking stat, contrarian claim, or pattern
     interrupt).
  3. Delivers the most surprising / useful insight from the
     investigation in plain, conversational language.
  4. Has a tight CTA (follow / save / share).
  5. Uses the report's own data and quotes — NEVER invent stats,
     handles, URLs, or facts that aren't in the source.
  6. Speaks in the same language the report is written in.

Output ONLY a JSON object with this exact shape:

{
  "title": "Punchy 5-8 word reel title",
  "hook": "Opening 1-2 sentence scroll-stopper",
  "platform": "Instagram Reels",
  "sections": [
    {"label": "HOOK", "body": "..."},
    {"label": "ACT 1", "body": "..."},
    {"label": "ACT 2", "body": "..."},
    {"label": "ACT 3", "body": "..."}
  ],
  "call_to_action": "1-2 sentence CTA"
}

No prose before or after the JSON. No markdown fences.
''';

  static const String _podcastSystemPrompt = '''
You are a senior podcast producer specialised in turning research
reports into a structured ~15-minute solo episode outline.

You will receive an investigation report (title + sections +
findings + sources). Produce a full script outline that:

  1. Targets ~15 minutes of audio at ~150 words/minute
     (≈2,250 words total).
  2. Follows a classic three-act structure:
       COLD OPEN  — 30 seconds, punchy hook
       INTRO      — 60 seconds, frame the topic + tease value
       ACT 1      — context, key findings, the main story
       ACT 2      — deeper analysis, contradictions, expert angle
       ACT 3      — implications, what to do next, predictions
       OUTRO      — recap + CTA (subscribe, share, follow)
  3. For every ACT, list 3-5 talking points. Each talking point
     becomes a 20-40 second spoken segment.
  4. Quotes specific data from the report verbatim where it
     matters. NEVER invent stats or URLs.
  5. Speaks in the same language the report is written in.
  6. Includes a suggested guest-question prompt in ACT 2 for
     interviews.

Output ONLY a JSON object with this exact shape:

{
  "title": "Episode title (5-10 words)",
  "hook": "Cold open (2-3 sentences)",
  "sections": [
    {"label": "INTRO", "body": "Frame the topic and tease the value the listener will get."},
    {"label": "ACT 1", "body": "Act 1 talking points:\\n• Point 1\\n• Point 2\\n• Point 3"},
    {"label": "ACT 2", "body": "Act 2 talking points:\\n• Point 1\\n• Point 2"},
    {"label": "ACT 3", "body": "Act 3 talking points:\\n• Point 1\\n• Point 2"},
    {"label": "OUTRO", "body": "Recap and CTA."}
  ],
  "call_to_action": "Subscribe, share, follow — 1-2 sentences."
}

No prose before or after the JSON. No markdown fences.
''';
}
