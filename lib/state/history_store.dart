import 'package:flutter/foundation.dart';

import '../models/analysis_history.dart';

/// In-memory store of analyses the user has run on the Explore screen.
/// Both the Explore screen and the Reports tab read from this store, so
/// the Reports tab can act as the "history" of past explorations.
class HistoryStore {
  HistoryStore._();
  static final HistoryStore instance = HistoryStore._();

  final ValueNotifier<List<AnalysisHistoryEntry>> entries =
      ValueNotifier<List<AnalysisHistoryEntry>>(<AnalysisHistoryEntry>[]);

  void add(AnalysisHistoryEntry entry) {
    final next = <AnalysisHistoryEntry>[entry, ...entries.value];
    entries.value = next;
  }

  void remove(String id) {
    entries.value = entries.value.where((e) => e.id != id).toList();
  }

  void clear() {
    entries.value = <AnalysisHistoryEntry>[];
  }
}