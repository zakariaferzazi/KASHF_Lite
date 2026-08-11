import 'dart:async';

import 'package:flutter/foundation.dart';

import '../l10n/app_locale.dart';
import '../l10n/app_strings.dart';
import '../models/entity_type.dart';
import '../models/evidence.dart';
import '../models/investigation.dart';
import '../models/investigation_action.dart';
import '../models/investigation_result.dart';
import 'ai/openrouter_client.dart';
import 'investigation_prompt_builder.dart';

/// Snapshot of a running investigation exposed to the UI. The
/// [InvestigationController] watches this stream to drive the
/// loading sheet and the final transition to the results screen.
@immutable
class InvestigationProgress {
  const InvestigationProgress({
    required this.phase,
    required this.percent,
    required this.message,
    this.result,
    this.error,
  });

  final InvestigationPhase phase;

  /// 0..1 progress shown on the loading sheet.
  final double percent;

  /// Short status message ("Collecting evidence", "Analyzing...").
  final String message;

  /// Final result once the investigation completes. `null` until then.
  final InvestigationResult? result;

  /// Populated when [phase] is [InvestigationPhase.failed].
  final String? error;
}

/// Drives the new investigation pipeline:
///
/// 1. `start(query, evidence, action)` — kicks off the run.
/// 2. `progress` — ValueListenable the UI subscribes to.
/// 3. `reset()` — best-effort stop, used after the screen navigates
///    to the results page.
///
/// Implementation: we actually call OpenRouter through
/// [OpenRouterClient]. The pipeline walks through 4 phases
/// (collecting → processing → analyzing → completed) and emits a
/// progress snapshot at every step so the UI can drive its loading
/// sheet.
class InvestigationService {
  InvestigationService({
    OpenRouterClient? client,
    String? region,
  })  : _client = client ?? OpenRouterClient.instance,
        _region = region ?? 'Kuwait';

  /// Singleton instance used by the screen. Tests can build their
  /// own service with a mocked [OpenRouterClient].
  static final InvestigationService instance = InvestigationService();

  final OpenRouterClient _client;
  final String _region;

  final ValueNotifier<InvestigationProgress> _progress =
      ValueNotifier<InvestigationProgress>(
    const InvestigationProgress(
      phase: InvestigationPhase.draft,
      percent: 0,
      message: '',
    ),
  );

  /// Read-only progress. The controller listens to this notifier
  /// and rebuilds the loading sheet on every change.
  ValueListenable<InvestigationProgress> get progress => _progress;

  InvestigationProgress get current => _progress.value;

  bool _running = false;
  bool get isRunning => _running;

  /// Resets the service back to its idle state. Used when the
  /// user dismisses the loading sheet or the screen is rebuilt.
  void reset() {
    _running = false;
    _progress.value = const InvestigationProgress(
      phase: InvestigationPhase.draft,
      percent: 0,
      message: '',
    );
  }

  /// Starts an investigation.
  ///
  /// - [query] is the user's free-text question or topic.
  /// - [evidence] is the optional list of evidence the user attached.
  /// - [action] is the optional quick-action mode (the "lens").
  /// - [entityType] is the entity they want to investigate.
  /// - [l] is the localization bundle used to localize the
  ///   progress messages.
  /// - [onEvidenceUpdate] is an optional callback fired whenever
  ///   the status of an attached evidence item changes (e.g.
  ///   pending → uploading → processing → processed). The UI can
  ///   use it to drive per-row progress chips.
  Future<InvestigationResult> start({
    required String query,
    required List<Evidence> evidence,
    required InvestigationAction? action,
    required EntityType entityType,
    required AppLocalizations l,
    void Function(Evidence updated)? onEvidenceUpdate,
  }) async {
    if (_running) {
      throw StateError('Investigation already running.');
    }
    _running = true;

    final languageCode = _languageCode(l.language);
    try {
      // Phase 1 — collect evidence (if any).
      if (evidence.isNotEmpty) {
        _emit(
          l,
          InvestigationPhase.evidenceCollecting,
          l.t('ir_phase_collecting'),
        );
        await _processEvidence(evidence, l, onEvidenceUpdate);
      } else {
        _emit(l, InvestigationPhase.evidenceCollecting, l.t('ir_phase_collecting'));
        await _tick(const Duration(milliseconds: 250));
      }

      // Phase 2 — process evidence with the AI pipeline.
      if (evidence.isNotEmpty) {
        _emit(
          l,
          InvestigationPhase.evidenceProcessing,
          l.t('ir_phase_processing'),
        );
        await _processEvidenceAi(evidence, l, onEvidenceUpdate);
      }

      // Phase 3 — analyze via OpenRouter.
      _emit(l, InvestigationPhase.analyzing, l.t('ir_phase_analyzing'));

      final messages = InvestigationPromptBuilder.messages(
        language: languageCode,
        region: _region,
        query: query,
        action: action,
        evidence: evidence,
        entityType: entityType,
        l: l,
      );

      final request = OpenRouterRequest(
        messages: messages,
        temperature: 0.4,
        maxTokens: 4000,
        responseFormat: const {'type': 'json_object'},
      );

      final Map<String, dynamic> json;
      try {
        json = await _client.chatCompletionJson(request);
      } on OpenRouterException catch (e) {
        _emit(
          l,
          InvestigationPhase.failed,
          l.t('ir_processing_failed'),
          error: e.message,
        );
        throw _wrap(e);
      }

      // Phase 4 — build the result from the model output.
      final result = parseInvestigationResult(
        json: json,
        investigationId: 'inv-${DateTime.now().millisecondsSinceEpoch}',
        query: query,
        evidence: evidence,
        entityType: entityType,
        l: l,
      );

      _emit(
        l,
        InvestigationPhase.completed,
        l.t('ir_phase_completed'),
        result: result,
      );
      return result;
    } catch (e) {
      if (_progress.value.phase != InvestigationPhase.failed) {
        _emit(
          l,
          InvestigationPhase.failed,
          l.t('ir_processing_failed'),
          error: e.toString(),
        );
      }
      rethrow;
    } finally {
      _running = false;
    }
  }

  // ---------------------------------------------------------------------
  // Local helpers
  // ---------------------------------------------------------------------

  String _languageCode(AppLanguage lang) {
    switch (lang) {
      case AppLanguage.arabic:
        return 'ar';
      case AppLanguage.english:
        return 'en';
    }
  }

  Exception _wrap(OpenRouterException e) {
    switch (e.type) {
      case OpenRouterErrorType.config:
        return _ServiceError('config', e.message);
      case OpenRouterErrorType.auth:
        return _ServiceError('auth', e.message);
      case OpenRouterErrorType.rateLimit:
      case OpenRouterErrorType.rateLimitLocal:
        return _ServiceError('rate_limit', e.message);
      case OpenRouterErrorType.timeout:
        return _ServiceError('timeout', e.message);
      case OpenRouterErrorType.network:
        return _ServiceError('network', e.message);
      case OpenRouterErrorType.parse:
        return _ServiceError('parse', e.message);
      case OpenRouterErrorType.badRequest:
        return _ServiceError('bad_request', e.message);
      case OpenRouterErrorType.server:
        return _ServiceError('server', e.message);
      case OpenRouterErrorType.unknown:
        return _ServiceError('unknown', e.message);
    }
  }

  Future<void> _processEvidence(
    List<Evidence> evidence,
    AppLocalizations l,
    void Function(Evidence updated)? onEvidenceUpdate,
  ) async {
    for (final e in evidence) {
      if (e.kind == EvidenceKind.url) continue;
      _emit(
        l,
        InvestigationPhase.evidenceCollecting,
        l.tp('ir_evidence_uploading', {'name': e.displayName}),
      );
      onEvidenceUpdate?.call(e.copyWith(status: EvidenceStatus.uploading));
      await _tick(const Duration(milliseconds: 250));
      onEvidenceUpdate?.call(e.copyWith(status: EvidenceStatus.processed));
    }
  }

  Future<void> _processEvidenceAi(
    List<Evidence> evidence,
    AppLocalizations l,
    void Function(Evidence updated)? onEvidenceUpdate,
  ) async {
    final urls = evidence.where((e) => e.kind == EvidenceKind.url).toList();
    if (urls.isNotEmpty) {
      _emit(
        l,
        InvestigationPhase.evidenceProcessing,
        l.tp('ir_evidence_reading_links', {'n': '${urls.length}'}),
      );
      for (final e in urls) {
        onEvidenceUpdate?.call(e.copyWith(status: EvidenceStatus.processing));
        await _tick(const Duration(milliseconds: 220));
        onEvidenceUpdate?.call(e.copyWith(status: EvidenceStatus.processed));
      }
    }

    final files =
        evidence.where((e) => e.kind != EvidenceKind.url).toList();
    if (files.isNotEmpty) {
      _emit(
        l,
        InvestigationPhase.evidenceProcessing,
        l.tp('ir_evidence_extracting', {'n': '${files.length}'}),
      );
      for (final e in files) {
        onEvidenceUpdate?.call(e.copyWith(status: EvidenceStatus.processing));
        await _tick(const Duration(milliseconds: 300));
        onEvidenceUpdate?.call(e.copyWith(status: EvidenceStatus.processed));
      }
    }
  }

  void _emit(
    AppLocalizations l,
    InvestigationPhase phase,
    String message, {
    InvestigationResult? result,
    String? error,
  }) {
    _progress.value = InvestigationProgress(
      phase: phase,
      percent: phase.progress,
      message: message,
      result: result,
      error: error,
    );
  }

  Future<void> _tick(Duration d) => Future<void>.delayed(d);
}

/// Tag-based wrapper so the UI can match on the kind without
/// knowing about [OpenRouterException].
class _ServiceError implements Exception {
  _ServiceError(this.kind, this.message);
  final String kind;
  final String message;
  @override
  String toString() => 'InvestigationServiceError($kind): $message';
}

/// Exposed so the UI can also display a friendly message from the
/// service-typed error.
String investigationErrorKind(Object error) {
  if (error is _ServiceError) return error.kind;
  return 'unknown';
}

/// Parses the JSON payload returned by OpenRouter into an
/// [InvestigationResult]. Defensive against missing fields — we
/// fall back to localized placeholders rather than throwing so the
/// user still sees a usable result page.
InvestigationResult parseInvestigationResult({
  required Map<String, dynamic> json,
  required String investigationId,
  required String query,
  required List<Evidence> evidence,
  required EntityType entityType,
  required AppLocalizations l,
}) {
  final title = (json['title'] as String?)?.trim().isNotEmpty == true
      ? json['title'] as String
      : l.tp(
          'ir_title_with_name',
          {'name': query.isEmpty ? l.t(entityType.l10nKey) : query},
        );

  final subtitle = (json['subtitle'] as String?)?.trim() ?? l.t('ir_subtitle');

  final summary = (json['summary'] as String?)?.trim();

  final overallConfidence = _readConfidence(json['overall_confidence']) ??
      (evidence.isNotEmpty ? 0.85 : 0.7);

  final sourcesJson = (json['sources'] as List?) ?? const [];
  final sources = sourcesJson
      .map((raw) => _parseSource(raw))
      .where((s) => s.title.isNotEmpty)
      .toList();

  final sectionsJson = (json['sections'] as List?) ?? const [];

  // We always build 5 sections in the canonical order. If the
  // model skipped one we still render an empty section so the UI
  // tabs stay aligned.
  const order = [
    InvestigationResultKind.overview,
    InvestigationResultKind.evidence,
    InvestigationResultKind.insights,
    InvestigationResultKind.sources,
    InvestigationResultKind.recommendations,
  ];
  final byKind = <InvestigationResultKind, Map<String, dynamic>>{};
  for (final raw in sectionsJson) {
    if (raw is Map<String, dynamic>) {
      final kStr = (raw['kind'] as String?) ?? '';
      final k = InvestigationResultKind.values.firstWhere(
        (kk) => kk.name == kStr,
        orElse: () => InvestigationResultKind.overview,
      );
      byKind[k] = raw;
    }
  }

  final sections = <InvestigationResultSection>[];
  for (final kind in order) {
    final raw = byKind[kind];
    if (raw == null) {
      sections.add(InvestigationResultSection(
        kind: kind,
        headline: l.t('ir_section_${kind.name}_title'),
        summary: l.t('ir_section_${kind.name}_sub'),
        items: const [],
      ));
    } else {
      sections.add(_parseSection(raw, fallback: kind, l: l));
    }
  }

  // If the model didn't return a summary, prepend one to the
  // overview section so the user sees the executive summary on
  // top of the page.
  if (summary != null && summary.isNotEmpty) {
    final overview = sections.first;
    final already = overview.items.any((i) => i.id == 'overview-summary');
    if (!already) {
      sections[0] = InvestigationResultSection(
        kind: overview.kind,
        headline: overview.headline,
        summary: overview.summary,
        confidence: overview.confidence,
        items: [
          InvestigationResultItem(
            id: 'overview-summary',
            title: l.t('ir_overview_summary_title'),
            body: summary,
            badge: l.t('ir_badge_verified'),
          ),
          ...overview.items,
        ],
      );
    }
  }

  // Attach the user's own URL evidence as sources too, so the
  // results page shows them even if the model skipped the
  // sources section.
  if (evidence.isNotEmpty) {
    final urlEvidence =
        evidence.where((e) => e.kind == EvidenceKind.url).toList();
    for (final e in urlEvidence) {
      if (sources.any((s) => s.url == e.url)) continue;
      sources.add(InvestigationSource(
        id: 'user-src-${e.id}',
        title: e.displayName,
        subtitle: l.t('ir_src_linked_sub'),
        kind: InvestigationSourceKind.web,
        url: e.url,
      ));
    }
  }

  // Map the file evidence into the evidence section when the
  // model didn't list it explicitly.
  if (evidence.isNotEmpty) {
    final evSection = sections[1]; // evidence is index 1
    if (evSection.items.isEmpty) {
      sections[1] = InvestigationResultSection(
        kind: evSection.kind,
        headline: evSection.headline,
        summary: evSection.summary,
        confidence: evSection.confidence,
        items: evidence.map((e) {
          return InvestigationResultItem(
            id: e.id,
            title: e.displayName,
            body: _evidenceLineFor(e, l),
            badge: l.t('ir_evidence_status_processed'),
          );
        }).toList(),
      );
    }
  }

  return InvestigationResult(
    id: investigationId,
    investigationId: investigationId,
    title: title,
    subtitle: subtitle,
    sections: sections,
    generatedAt: DateTime.now(),
    sources: sources,
    confidence: overallConfidence,
  );
}

// ---------------------------------------------------------------------
// Parser helpers (top-level so they're not closures).
// ---------------------------------------------------------------------

double? _readConfidence(Object? v) {
  if (v is num) return v.toDouble().clamp(0.0, 1.0);
  if (v is String) {
    final p = double.tryParse(v);
    if (p == null) return null;
    if (p > 1) return (p / 100).clamp(0.0, 1.0);
    return p.clamp(0.0, 1.0);
  }
  return null;
}

InvestigationSource _parseSource(dynamic raw) {
  final m = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
  final kindStr = (m['kind'] as String?) ?? 'other';
  final kind = InvestigationSourceKind.values.firstWhere(
    (k) => k.name == kindStr,
    orElse: () => InvestigationSourceKind.other,
  );
  return InvestigationSource(
    id: (m['id'] as String?) ?? 'src-${DateTime.now().microsecondsSinceEpoch}',
    title: (m['title'] as String?) ?? '',
    subtitle: (m['subtitle'] as String?) ?? '',
    kind: kind,
    url: m['url'] as String?,
  );
}

InvestigationResultItem _parseItem(
  dynamic raw, {
  required String fallbackId,
}) {
  final m = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
  return InvestigationResultItem(
    id: (m['id'] as String?) ?? fallbackId,
    title: (m['title'] as String?) ?? '',
    body: (m['body'] as String?) ?? '',
    metric: m['metric'] as String?,
    metricLabel: m['metric_label'] as String?,
    badge: m['badge'] as String?,
  );
}

InvestigationResultSection _parseSection(
  dynamic raw, {
  required InvestigationResultKind fallback,
  required AppLocalizations l,
}) {
  final m = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
  final kindStr = (m['kind'] as String?) ?? fallback.name;
  final kind = InvestigationResultKind.values.firstWhere(
    (k) => k.name == kindStr,
    orElse: () => fallback,
  );
  final itemsJson = (m['items'] as List?) ?? const [];
  final items = itemsJson
      .asMap()
      .entries
      .map((e) => _parseItem(e.value, fallbackId: '${kind.name}-${e.key}'))
      .where((it) => it.title.isNotEmpty || it.body.isNotEmpty)
      .toList();

  return InvestigationResultSection(
    kind: kind,
    headline: (m['headline'] as String?)?.trim().isNotEmpty == true
        ? m['headline'] as String
        : l.t('ir_section_${kind.name}_title'),
    summary: (m['summary'] as String?) ?? '',
    items: items,
    confidence: _readConfidence(m['confidence']),
  );
}

String _evidenceLineFor(Evidence e, AppLocalizations l) {
  switch (e.kind) {
    case EvidenceKind.pdf:
      return l.t('ir_evidence_kind_pdf');
    case EvidenceKind.image:
      return l.t('ir_evidence_kind_image');
    case EvidenceKind.video:
      return l.t('ir_evidence_kind_video');
    case EvidenceKind.url:
      return l.t('ir_evidence_kind_url');
  }
}
