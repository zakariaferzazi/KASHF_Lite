import 'package:flutter/material.dart';

/// Catalog of OpenRouter models the user can pick from in
/// Settings → AI model. The chosen model id is stored in
/// [SettingsPreferences] and read by [OpenRouterConfig.model] when
/// the user (or the env override) hasn't pinned a specific model.
///
/// Adding a new option is intentionally a one-line change: add an
/// entry to [kAiModelOptions] and it shows up in the picker sheet
/// and is persisted by id.
class AiModelOption {
  const AiModelOption({
    required this.id,
    required this.label,
    required this.provider,
    required this.subtitleL10nKey,
    required this.icon,
  });

  /// OpenRouter model identifier (e.g. `google/gemini-2.5-flash-lite`).
  final String id;

  /// Short user-facing label (e.g. "Gemini").
  final String label;

  /// Provider/brand name (e.g. "Google").
  final String provider;

  /// L10n key for the descriptive subtitle under the model name.
  final String subtitleL10nKey;

  /// Leading icon for the picker row.
  final IconData icon;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is AiModelOption && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// The default model used if the user has never picked one.
const String kDefaultAiModelId = 'openai/gpt-5.6-luna';

/// Ordered list of models surfaced in the settings picker.
const List<AiModelOption> kAiModelOptions = <AiModelOption>[
  AiModelOption(
    id: 'openai/gpt-5.6-luna',
    label: 'GPT-5.6 Luna',
    provider: 'OpenAI',
    subtitleL10nKey: 'ai_model_gpt5nano_sub',
    icon: Icons.layers_outlined,
  ),
];

/// Returns the [AiModelOption] for [id], falling back to the
/// default option if the id is unknown / null.
AiModelOption resolveAiModelOption(String? id) {
  if (id == null || id.isEmpty) {
    return kAiModelOptions.firstWhere(
      (m) => m.id == kDefaultAiModelId,
      orElse: () => kAiModelOptions.first,
    );
  }
  for (final m in kAiModelOptions) {
    if (m.id == id) return m;
  }
  return kAiModelOptions.firstWhere(
    (m) => m.id == kDefaultAiModelId,
    orElse: () => kAiModelOptions.first,
  );
}
