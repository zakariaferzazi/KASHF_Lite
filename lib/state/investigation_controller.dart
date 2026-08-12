import 'package:flutter/foundation.dart';

import '../l10n/app_strings.dart';
import '../models/evidence.dart';
import '../models/entity_type.dart';
import '../models/investigation.dart';
import '../models/investigation_action.dart';
import '../services/investigation_service.dart';

/// State for the new-investigation screen. Holds:
///  * the user's free-text query,
///  * the list of evidence they've attached,
///  * the selected quick-action mode (lens applied to the query),
///  * the live progress reported by [InvestigationService].
///
/// The screen consumes this through a [ChangeNotifier] so we don't
/// pull in a third-party state-management library for one screen.
class InvestigationController extends ChangeNotifier {
  InvestigationController({InvestigationService? service})
      : _service = service ?? InvestigationService.instance {
    _service.progress.addListener(_onServiceProgress);
  }

  final InvestigationService _service;

  // ---------- Form state ----------

  String _query = '';
  String get query => _query;
  set query(String v) {
    if (_query == v) return;
    _query = v;
    notifyListeners();
  }

  final List<Evidence> _evidence = [];
  List<Evidence> get evidence => List.unmodifiable(_evidence);

  EntityType _entityType = EntityType.brand;
  EntityType get entityType => _entityType;
  set entityType(EntityType v) {
    if (_entityType == v) return;
    _entityType = v;
    // If the user explicitly picks an entity type that matches
    // the action's implied entity type, keep the action. If it
    // doesn't match, drop the action — running a "compare" action
    // (a brand-action) on an Influencer entity type produces the
    // same vocabulary mismatch we're trying to eliminate.
    final current = _selectedAction;
    if (current != null && current.entityType != v) {
      _selectedAction = null;
    }
    notifyListeners();
  }

  /// Currently selected quick-action mode (the "lens" the user
  /// wants the AI to apply). `null` when none is picked.
  InvestigationAction? _selectedAction;
  InvestigationAction? get selectedAction => _selectedAction;

  /// Backwards-compat alias for the UI: the id of the selected
  /// action, or `null` if none.
  String? get selectedActionId => _selectedAction?.id;

  /// Selects an action mode. Pass `null` to clear.
  ///
  /// Picking an action also pins the entity type that the action
  /// implies (e.g. the "Influencer" action pins entity-type to
  /// `EntityType.influencer`). This keeps the entity-type tile
  /// and the action chip in sync so the prompt and the UI never
  /// disagree — the #1 cause of "brand report about an influencer"
  /// output we used to see.
  ///
  /// The user can still override the entity type explicitly after
  /// picking an action; that re-pins the action if the new
  /// entity type implies a different one.
  void selectAction(InvestigationAction? action) {
    if (_selectedAction == action) return;
    _selectedAction = action;
    if (action != null) {
      _entityType = action.entityType;
    }
    notifyListeners();
  }

  void clearSelectedAction() {
    if (_selectedAction == null) return;
    _selectedAction = null;
    notifyListeners();
  }

  // ---------- Running state ----------

  InvestigationProgress _progress = const InvestigationProgress(
    phase: InvestigationPhase.draft,
    percent: 0,
    message: '',
  );
  InvestigationProgress get progress => _progress;

  bool get isRunning =>
      _progress.phase != InvestigationPhase.draft &&
      _progress.phase != InvestigationPhase.completed &&
      _progress.phase != InvestigationPhase.failed;

  bool get isCompleted => _progress.phase == InvestigationPhase.completed;

  bool get hasFailed => _progress.phase == InvestigationPhase.failed;

  String? get errorMessage => _progress.error;

  bool _disposed = false;

  /// Quick-question preset selected from the smart-search card.
  /// Wires the search field but does not auto-start.
  void applyQuickQuestion(String text) {
    query = text;
  }

  /// Adds a piece of evidence to the list. De-duplicates by id.
  void addEvidence(Evidence e) {
    if (_evidence.any((x) => x.id == e.id)) return;
    _evidence.add(e);
    notifyListeners();
  }

  /// Removes the evidence with the id and replaces it with the
  /// updated copy (used to drive the status transitions).
  void updateEvidence(Evidence updated) {
    final i = _evidence.indexWhere((e) => e.id == updated.id);
    if (i == -1) return;
    _evidence[i] = updated;
    notifyListeners();
  }

  /// Removes the evidence with the given id.
  void removeEvidence(String id) {
    _evidence.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  /// Clears all attached evidence. Used when the user taps "clear".
  void clearEvidence() {
    if (_evidence.isEmpty) return;
    _evidence.clear();
    notifyListeners();
  }

  /// Validates the form. Returns `null` if everything is good,
  /// otherwise the user-facing error key.
  String? validate() {
    final q = _query.trim();
    if (q.isEmpty && _evidence.isEmpty && _selectedAction == null) {
      return 'inv_validation_empty';
    }
    return null;
  }

  /// Kicks off the investigation. Throws if already running.
  Future<void> start(AppLocalizations l) async {
    if (isRunning) return;
    await _service.start(
      query: _query.trim(),
      evidence: List<Evidence>.from(_evidence),
      action: _selectedAction,
      entityType: _entityType,
      l: l,
      onEvidenceUpdate: (updated) => updateEvidence(updated),
    );
  }

  void _onServiceProgress() {
    if (_disposed) return;
    _progress = _service.current;
    notifyListeners();
  }

  /// Called after the screen pushes to the results page. Resets
  /// the service so a subsequent investigation starts clean.
  void acknowledgeCompletion() {
    _service.reset();
    _progress = const InvestigationProgress(
      phase: InvestigationPhase.draft,
      percent: 0,
      message: '',
    );
    // Reset the form too so the user can immediately start another
    // investigation without leaving the screen.
    _query = '';
    _evidence.clear();
    _selectedAction = null;
    notifyListeners();
  }

  /// Called by the loading overlay once its failed-state fade-out
  /// has finished. Resets the service back to draft so the overlay
  /// is removed from the Stack without clearing the user's form
  /// (so they can retry with the same query).
  void dismissFailure() {
    if (_progress.phase != InvestigationPhase.failed) return;
    _service.reset();
    _progress = const InvestigationProgress(
      phase: InvestigationPhase.draft,
      percent: 0,
      message: '',
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _service.progress.removeListener(_onServiceProgress);
    super.dispose();
  }
}
