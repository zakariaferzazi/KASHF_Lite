import '../l10n/app_strings.dart';

/// Saved analyses shown in the Reports tab. Each entry mirrors what the user
/// explored in the Explore screen and lets them re-open the cached output
/// without re-running the analysis.
class AnalysisHistoryEntry {
  AnalysisHistoryEntry({
    required this.id,
    required this.entity,
    required this.categoryLabels,
    required this.createdAt,
    required this.summary,
    required this.outputsCount,
  });
  final String id;
  final String entity;

  /// Already-localized chip labels for the categories the user picked on the
  /// Explore screen (e.g. ["Brand", "Market"] or ["علامة", "سوق"]).
  final List<String> categoryLabels;
  final DateTime createdAt;

  /// Short headline shown on the history row (e.g. "Investigation · Lattafa
  /// Asad" or "تقرير تحقيق · Lattafa Asad").
  final String summary;

  /// Total number of analysis sections generated (e.g. 6 if all outputs
  /// were selected).
  final int outputsCount;

  String displayDate(AppLocalizations l) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return l.isRtl ? 'الآن' : 'just now';
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return l.isRtl ? 'قبل $m د' : '${m}m ago';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return l.isRtl ? 'قبل $h س' : '${h}h ago';
    }
    final d = diff.inDays;
    return l.isRtl ? 'قبل $d ي' : '${d}d ago';
  }
}