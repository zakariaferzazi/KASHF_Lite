import 'package:flutter/foundation.dart';

/// One labelled chunk of a generated script. Both reel and podcast
/// scripts share the same shape — a labelled block followed by the
/// spoken / displayed text — so the viewer screen can render either
/// format with the same widget tree.
@immutable
class ScriptSection {
  const ScriptSection({required this.label, required this.body});

  /// Short heading shown above the chunk (e.g. "HOOK", "ACT 1",
  /// "CTA"). Rendered in the brand gold colour and uppercase.
  final String label;

  /// Spoken / displayed text for this chunk. Multiline allowed.
  final String body;

  Map<String, dynamic> toJson() => {
        'label': label,
        'body': body,
      };

  factory ScriptSection.fromJson(Map<String, dynamic> json) {
    return ScriptSection(
      label: (json['label'] as String?)?.trim() ?? '',
      body: (json['body'] as String?)?.trim() ?? '',
    );
  }
}

/// Type of the generated script. Drives the icon / colour on the
/// studio cards and the title shown in the viewer screen.
enum ScriptKind {
  reel,
  podcast;

  String get displayName {
    switch (this) {
      case ScriptKind.reel:
        return 'Reel';
      case ScriptKind.podcast:
        return 'Podcast';
    }
  }
}

/// A fully-generated script ready to be shown to the admin.
///
/// The model holds both the structured sections (for re-rendering
/// after edits) and a flat text view (for copy / share / export).
/// Edits performed in the UI mutate [sections] and re-derive the
/// text — we never edit the text directly because that would
/// silently desync the structured and flat representations.
@immutable
class ScriptDraft {
  const ScriptDraft({
    required this.kind,
    required this.title,
    required this.hook,
    required this.sections,
    required this.callToAction,
    required this.durationSeconds,
    required this.sourceInvestigationId,
    required this.sourceInvestigationTitle,
    required this.generatedAt,
    this.platform = 'Instagram Reels',
  });

  /// Which kind of script this is (reel / podcast).
  final ScriptKind kind;

  /// Headline title of the script (the model picks a punchy one
  /// in the same language as the source investigation).
  final String title;

  /// Single-sentence hook. For reels this is the opening line; for
  /// podcasts it's the cold open.
  final String hook;

  /// Ordered body of the script.
  final List<ScriptSection> sections;

  /// Closing line(s) — the call to action viewers / listeners
  /// should follow (follow, save, leave a comment, etc.).
  final String callToAction;

  /// Approximate runtime, in seconds. Used by the UI to label the
  /// script as "30-second reel" or "15-min podcast".
  final int durationSeconds;

  /// Investigation id this script was generated from.
  final String sourceInvestigationId;

  /// Title of the source investigation (denormalised so the
  /// viewer screen has something to show without re-loading the
  /// archive).
  final String sourceInvestigationTitle;

  /// When the script was generated.
  final DateTime generatedAt;

  /// Free-form platform label (reels only) — influencer reels
  /// commonly include the target platform in the script header.
  final String platform;

  /// Flat, plain-text version of the script. Suitable for copy /
  /// paste, share, and the .txt export. Sections are joined with
  /// blank lines and the hook / CTA get a clear visual separator.
  String toPlainText() {
    final buf = StringBuffer()
      ..writeln(title.toUpperCase())
      ..writeln('—' * title.length)
      ..writeln();
    if (hook.isNotEmpty) {
      buf
        ..writeln('HOOK:')
        ..writeln(hook)
        ..writeln();
    }
    for (final s in sections) {
      if (s.label.isEmpty) {
        buf.writeln(s.body);
      } else {
        buf
          ..writeln('${s.label.toUpperCase()}:')
          ..writeln(s.body);
      }
      buf.writeln();
    }
    if (callToAction.isNotEmpty) {
      buf
        ..writeln('CTA:')
        ..writeln(callToAction)
        ..writeln();
    }
    buf.writeln(
      'Source investigation: $sourceInvestigationTitle '
      '($sourceInvestigationId)',
    );
    return buf.toString().trimRight();
  }
}
