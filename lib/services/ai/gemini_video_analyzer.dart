import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../l10n/app_strings.dart';
import '../../models/evidence.dart';
import 'openrouter_client.dart';

/// OpenRouter model id used by [GeminiVideoAnalyzer] to
/// understand uploaded video clips. Xiaomi MiMo v2.5 natively
/// supports video input on OpenRouter, so we send the video
/// here as a `video_url` content part and inject the
/// structured analysis back into the main investigation run.
const String kVideoAnalyzerModel = 'xiaomi/mimo-v2.5';

/// Structured analysis returned by Gemini for a video evidence
/// item. The main investigation model (`gpt-5.6-luna`) consumes
/// these fields as plain text so we can keep the rest of the
/// pipeline on the user's chosen model.
@immutable
class GeminiVideoAnalysis {
  const GeminiVideoAnalysis({
    required this.evidenceId,
    required this.transcript,
    required this.summary,
    required this.keyMoments,
    required this.visualCues,
    required this.entities,
    required this.sentiment,
    required this.language,
  });

  final String evidenceId;

  /// Best-effort speech-to-text transcript of the video's
  /// spoken content (Arabic or English, depending on the
  /// clip). Empty when the video has no speech.
  final String transcript;

  /// 3–6 sentence plain-English summary of the clip.
  final String summary;

  /// Time-stamped key moments as `mm:ss — description`.
  final List<String> keyMoments;

  /// Visual cues (logos, on-screen text, scenes, transitions).
  final List<String> visualCues;

  /// Entities the model noticed (brands, products, people,
  /// locations).
  final List<String> entities;

  /// Overall sentiment: `positive`, `neutral`, `negative`,
  /// `mixed`.
  final String sentiment;

  /// Detected language (BCP-47 code, e.g. `en`, `ar`).
  final String language;

  /// Renders the analysis as a single text block so the
  /// main investigation model can consume it as context.
  String toContextBlock() {
    final buf = StringBuffer();
    buf.writeln('Video analysis (Xiaomi MiMo v2.5):');
    buf.writeln('• Summary: $summary');
    if (transcript.isNotEmpty) {
      buf.writeln('• Transcript: $transcript');
    }
    if (keyMoments.isNotEmpty) {
      buf.writeln('• Key moments:');
      for (final m in keyMoments) {
        buf.writeln('   - $m');
      }
    }
    if (visualCues.isNotEmpty) {
      buf.writeln('• Visual cues: ${visualCues.join('; ')}');
    }
    if (entities.isNotEmpty) {
      buf.writeln('• Entities: ${entities.join(', ')}');
    }
    buf.writeln('• Sentiment: $sentiment');
    buf.writeln('• Language: $language');
    return buf.toString();
  }

  factory GeminiVideoAnalysis.fromJson(
    Map<String, dynamic> json, {
    required String evidenceId,
  }) {
    final keyMomentsRaw = (json['key_moments'] as List?) ?? const [];
    final visualCuesRaw = (json['visual_cues'] as List?) ?? const [];
    final entitiesRaw = (json['entities'] as List?) ?? const [];
    return GeminiVideoAnalysis(
      evidenceId: evidenceId,
      transcript: (json['transcript'] as String?) ?? '',
      summary: (json['summary'] as String?) ?? '',
      keyMoments: keyMomentsRaw.map((e) => e.toString()).toList(),
      visualCues: visualCuesRaw.map((e) => e.toString()).toList(),
      entities: entitiesRaw.map((e) => e.toString()).toList(),
      sentiment: (json['sentiment'] as String?) ?? 'neutral',
      language: (json['language'] as String?) ?? 'en',
    );
  }

  /// Conservative fallback returned when Gemini fails. Keeps the
  /// main investigation run alive — the user still gets a report,
  /// it just doesn't carry the rich video context.
  factory GeminiVideoAnalysis.fallback({
    required String evidenceId,
    required String reason,
  }) {
    return GeminiVideoAnalysis(
      evidenceId: evidenceId,
      transcript: '',
      summary: 'Video analysis unavailable: $reason',
      keyMoments: const [],
      visualCues: const [],
      entities: const [],
      sentiment: 'unknown',
      language: 'en',
    );
  }
}

/// Calls a video-capable model on OpenRouter to extract a
/// structured understanding of a video evidence item. The model
/// is requested with multimodal content (the video itself + a
/// strict JSON schema) so we get back parseable fields.
///
/// We use `xiaomi/mimo-v2.5` — the MiMo family natively supports
/// video understanding via OpenRouter's `video_url` content parts.
/// The main investigation model (`openai/gpt-5.6-luna`) doesn't
/// accept video, so this pre-pass is the bridge.
///
/// Failures are non-fatal: the analyzer returns a
/// [VideoAnalysis.fallback] and logs the cause. The main
/// investigation continues so the user always gets a report.
class GeminiVideoAnalyzer {
  GeminiVideoAnalyzer({
    OpenRouterClient? client,
  }) : _client = client ?? OpenRouterClient.instance;

  final OpenRouterClient _client;

  /// Analyzes every video evidence item in [evidence] and
  /// returns one analysis per item, keyed by evidence id.
  Future<Map<String, GeminiVideoAnalysis>> analyze({
    required List<Evidence> evidence,
    required AppLocalizations l,
  }) async {
    final videos =
        evidence.where((e) => e.kind == EvidenceKind.video).toList();
    final out = <String, GeminiVideoAnalysis>{};
    if (videos.isEmpty) return out;

    for (final v in videos) {
      try {
        final result = await _analyzeOne(v, l);
        out[v.id] = result;
      } catch (e, st) {
        debugPrint('[GeminiVideoAnalyzer] analysis failed for '
            '${v.id}: $e\n$st');
        out[v.id] = GeminiVideoAnalysis.fallback(
          evidenceId: v.id,
          reason: e.toString(),
        );
      }
    }
    return out;
  }

  Future<GeminiVideoAnalysis> _analyzeOne(
    Evidence v,
    AppLocalizations l,
  ) async {
    final videoUrl = await _resolveVideoUrl(v);
    final languageHint = l.isRtl ? 'Arabic (ar)' : 'English (en)';

    final systemText = '''
You are a video-understanding specialist. You will be given
one short video (or video clip) and asked to extract a
structured analysis.

Return ONLY a single JSON object — no prose, no markdown
fences. Use this schema exactly:

{
  "summary": string,            // 3–6 sentence plain summary
  "transcript": string,         // speech-to-text; empty if no speech
  "key_moments": string[],      // "mm:ss — description"
  "visual_cues": string[],      // logos, on-screen text, scenes
  "entities": string[],         // brands, products, people, locations
  "sentiment": string,          // positive | neutral | negative | mixed
  "language": string            // BCP-47 code
}

Detect the spoken language and write the transcript in that
language. The summary MUST be in $languageHint.
''';

    final userText = 'Analyse this video (id ${v.id}, '
        '"${v.displayName}") and return the JSON analysis.';

    final parts = <Map<String, dynamic>>[
      <String, dynamic>{'type': 'text', 'text': userText},
      <String, dynamic>{
        'type': 'video_url',
        'video_url': <String, dynamic>{'url': videoUrl},
      },
    ];

    final request = OpenRouterRequest(
      messages: [
        OpenRouterMessage(role: 'system', content: systemText),
        OpenRouterMessage(role: 'user', content: parts),
      ],
      // Force the video-capable MiMo v2.5 model. The user's
      // Settings pick is intentionally ignored here — video
      // understanding is a MiMo-only capability on OpenRouter.
      model: kVideoAnalyzerModel,
      temperature: 0.2,
      maxTokens: 2000,
      // JSON mode keeps the response parseable.
      responseFormat: const {'type': 'json_object'},
      // No web search — the video is the only source.
      enableWebSearch: false,
    );

    final response = await _client.chatCompletion(request);
    final decoded = _parseJsonObject(response.content);
    return GeminiVideoAnalysis.fromJson(
      decoded,
      evidenceId: v.id,
    );
  }

  /// Resolves the URL the multimodal request will reference.
  ///
  /// Priority:
  ///  1. [Evidence.url] — already-remote URL (e.g. an upload
  ///     endpoint that returns a CDN URL).
  ///  2. [Evidence.localPath] — convert the local file to a
  ///     `data:` URL so the model can ingest it without
  ///     uploading first. We cap the size at 25 MB to keep
  ///     the request body reasonable.
  Future<String> _resolveVideoUrl(Evidence v) async {
    final remote = v.url;
    if (remote != null && remote.isNotEmpty) return remote;

    final local = v.localPath;
    if (local == null || local.isEmpty) {
      throw StateError(
        'Video evidence ${v.id} has neither a remote URL nor a local path.',
      );
    }
    final file = File(local);
    if (!await file.exists()) {
      throw StateError('Local video file missing: $local');
    }
    final size = await file.length();
    const maxBytes = 25 * 1024 * 1024;
    if (size > maxBytes) {
      throw StateError(
        'Video is ${(size / 1024 / 1024).toStringAsFixed(1)} MB; '
        'maximum supported inline is 25 MB.',
      );
    }
    final bytes = await file.readAsBytes();
    final mime = _mimeFor(local);
    final base64Data = base64Encode(bytes);
    return 'data:$mime;base64,$base64Data';
  }

  String _mimeFor(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.m4v')) return 'video/mp4';
    if (lower.endsWith('.webm')) return 'video/webm';
    return 'video/mp4';
  }

  Map<String, dynamic> _parseJsonObject(String content) {
    // The OpenRouter client already attempts to extract a JSON
    // object. If the model slipped in prose around it, this
    // last-ditch scrubber finds the outermost `{...}` block.
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    final start = content.indexOf('{');
    final end = content.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      throw FormatException('Gemini returned non-JSON output: $content');
    }
    final slice = content.substring(start, end + 1);
    final decoded = jsonDecode(slice);
    if (decoded is Map<String, dynamic>) return decoded;
    throw FormatException('Gemini JSON root was not an object: $slice');
  }
}
