import '../l10n/app_locale.dart';
import '../l10n/app_strings.dart';
import '../models/evidence.dart';
import '../models/entity_type.dart';
import '../models/investigation_action.dart';
import 'ai/openrouter_client.dart';

/// Builds the system + user messages we send to OpenRouter for a
/// new investigation run. Everything is composed from the user's
/// free-text query, the selected [InvestigationAction] mode, the
/// attached evidence, and the entity type they picked.
///
/// The result has a STRICT JSON schema — the model is forced to
/// return JSON that we then map onto [InvestigationResult] in the
/// service.
class InvestigationPromptBuilder {
  InvestigationPromptBuilder._();

  /// Detects the dominant script of the user's query. We use this
  /// as a strong hint in the prompt so the model writes its
  /// answer in the user's own language even when the UI language
  /// is different (e.g. someone types in English while the app
  /// is in Arabic, or vice-versa).
  ///
  /// Returns 'ar' if the query contains any Arabic codepoint,
  /// 'en' if it contains any Latin letters, otherwise `null`.
  static String? detectQueryLanguage(String query) {
    final stripped = query.trim();
    if (stripped.isEmpty) return null;
    final hasArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(stripped);
    if (hasArabic) return 'ar';
    final hasLatin = RegExp(r'[A-Za-z]').hasMatch(stripped);
    if (hasLatin) return 'en';
    return null;
  }

  /// System prompt: defines the model's role and the output schema.
  /// We keep the same JSON shape across languages so the client
  /// can always parse the result without per-language branching.
  static String systemPrompt({
    required String language,
    required String region,
    String? queryLanguage,
  }) {
    final langName = _languageName(language);
    final queryLangName = queryLanguage == null
        ? null
        : _languageName(queryLanguage);

    final queryLangClause = queryLangName == null
        ? ''
        : '''

LANGUAGE OVERRIDE — CRITICAL:
  The user's free-text query is written in $queryLangName. That is
  the language they expect the answer in, REGARDLESS of the app
  language. Every string you produce (title, subtitle, summary,
  section headlines, section summaries, item titles, item bodies,
  badge text, source titles, source subtitles) MUST be written in
  $queryLangName. Brand names and source URLs stay in their
  original Latin form.
''';

    return '''
You are a senior brand-investigation analyst covering the perfume,
beauty, fashion, electronics, F&B, and social-media sectors in the
Gulf (GCC). You produce deep, evidence-based, decision-ready
investigations for product, marketing and reputation teams.

Region: $region. Prefer brands, currencies, and examples that
are locally relevant to $region.

OUTPUT LANGUAGE — READ CAREFULLY:
  You MUST write ALL string values in $langName.
  The user's query is the single strongest signal for the
  output language — see the override below if it is set.$queryLangClause

Output schema — return STRICT JSON only, no markdown fences, no
prose before/after the JSON:

{
  "title": string,                 // short headline in the output language
  "subtitle": string,              // one-sentence tagline in the output language
  "overall_confidence": number,    // 0..1, your overall confidence
  "summary": string,               // 2-3 sentence executive summary in the output language
  "evidence_count": number,        // total evidence items processed
  "sections": [
    {
      "kind": "overview" | "evidence" | "insights" | "sources" | "recommendations",
      "headline": string,          // short section title in the output language
      "summary": string,           // 1-2 sentence description in the output language
      "confidence": number | null, // 0..1 or null
      "items": [
        {
          "id": string,            // stable id, lowercase ASCII
          "title": string,         // short, <= 60 chars, in the output language
          "body": string,          // 1-3 sentence explanation in the output language
          "metric": string | null, // e.g. "92%" or "24" (ASCII digits)
          "metric_label": string | null,
          "badge": string | null   // short tag in the output language
        }
      ]
    },
    ... exactly 5 sections in this order:
        overview, evidence, insights, sources, recommendations.
    ... 6-12 items per section.
  ],
  "sources": [
    {
      "id": string,
      "title": string,            // short label in the output language
      "subtitle": string,         // one-line description in the output language
      "kind": "web" | "news" | "social" | "document" | "other",
      "url": string | null
    },
    ... 3-6 entries
  ]
}

Strict rules — read carefully:
  * Return ONLY JSON. No markdown fences, no preamble, no postscript.
  * ALL string values must be in the OUTPUT LANGUAGE defined above.
    This includes section headlines, item titles, item bodies,
    source titles, source subtitles, and badges.
  * EXCEPTIONS that stay in their original form:
      - Brand / product / person proper nouns (Lattafa, Dior,
        Apple, Cristiano Ronaldo).
      - URLs.
      - Technical terms widely known by their Latin spelling.
  * Use ASCII digits (0-9) and ASCII "%" everywhere, even inside
    Arabic strings.
  * If evidence was attached, the "evidence" section MUST list
    every item by name and call out what was extracted from it
    (text, image, video, link). If no evidence was attached, the
    "evidence" section should be empty.
  * "insights" must contain 3-6 concrete findings, each with a
    quantitative metric where possible (e.g. "+24%", "18/100").
  * "recommendations" must contain 2-4 concrete next actions,
    each tied to a finding from "insights".
  * "sources" must contain 3-6 distinct entries. URLs are
    optional but encouraged; do NOT invent fake URLs.
  * `overall_confidence` reflects how solid the investigation
    is. With attached evidence aim for 0.80-0.95. With only a
    query aim for 0.60-0.80.
  * Do NOT include any field not listed above.
''';
  }

  /// Builds the two-message payload (system + user) we send to
  /// OpenRouter. Includes the user's query, the selected action
  /// mode, and a digest of the attached evidence.
  ///
  /// The output language is chosen by:
  ///   1. The language of the user's query (auto-detected), if any.
  ///   2. Otherwise the app's UI language.
  static List<OpenRouterMessage> messages({
    required String language,
    required String region,
    required String query,
    required InvestigationAction? action,
    required List<Evidence> evidence,
    required EntityType entityType,
    required AppLocalizations l,
  }) {
    // Pick the strongest signal first: the user's own query.
    // If the query is empty or all-numbers, fall back to the UI
    // language.
    final queryLang = detectQueryLanguage(query);
    final outputLanguage = queryLang ?? language;

    final instruction = action?.promptInstruction ??
        'Investigate the topic below and produce a decision-ready '
            'brief with overview, insights, sources and next-step '
            'recommendations.';
    final modeName = action == null ? 'general' : action.id;
    final queryText = query.trim().isEmpty
        ? '(no query provided — base the investigation on the entity type below)'
        : query.trim();
    final evidenceDigest = _evidenceDigest(evidence, l);
    final entityLabel = l.t(entityType.l10nKey);

    final outputLanguageLabel = _languageName(outputLanguage);
    final appLanguageLabel = _languageName(language);

    final userText = '''
App UI language: $appLanguageLabel
Output language for this investigation: $outputLanguageLabel
Mode: $modeName
Entity type: $entityLabel
User query:
"""
$queryText
"""

Action instruction (the lens the user wants applied):
"""
$instruction
"""

Evidence attached by the user:
$evidenceDigest

Write the entire JSON response in $outputLanguageLabel. Return
the full JSON investigation in the schema defined in the system
prompt. Make the analysis concrete, quantitative, and actionable.
''';

    return [
      OpenRouterMessage(
        role: 'system',
        content: systemPrompt(
          language: outputLanguage,
          region: region,
          queryLanguage: queryLang,
        ),
      ),
      OpenRouterMessage(
        role: 'user',
        content: PromptSanitizer.sanitize(userText),
      ),
    ];
  }

  /// Builds a human-readable digest of the attached evidence so
  /// the model knows exactly what files/links it's working with.
  /// For URL evidence we include the URL; for files we include
  /// the name + size.
  static String _evidenceDigest(List<Evidence> evidence, AppLocalizations l) {
    if (evidence.isEmpty) {
      return '(none)';
    }
    final buffer = StringBuffer();
    for (var i = 0; i < evidence.length; i++) {
      final e = evidence[i];
      final size =
          e.sizeBytes == null ? '' : ' (${_humanSize(e.sizeBytes!)})';
      final ref = e.kind == EvidenceKind.url
          ? 'URL: ${e.url ?? e.displayName}'
          : 'file: ${e.displayName}$size';
      buffer.writeln('  ${i + 1}. [${e.kind.name.toUpperCase()}] $ref');
    }
    return buffer.toString().trimRight();
  }

  static String _humanSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  static String _languageName(String code) {
    switch (code) {
      case 'ar':
        return 'Arabic';
      case 'en':
        return 'English';
      default:
        return code;
    }
  }
}

/// Mapping from the user-facing language code to OpenRouter's
/// language hint. Pulled out so callers don't have to know about
/// the [AppLanguage] enum.
String aiLanguageCode(AppLanguage language) {
  switch (language) {
    case AppLanguage.arabic:
      return 'ar';
    case AppLanguage.english:
      return 'en';
  }
}
