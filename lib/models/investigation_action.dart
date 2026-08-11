import 'package:flutter/material.dart';

/// Quick-action modes the user can pick on the investigation screen.
/// Each mode tells the AI which "lens" to apply to the user's query
/// (compare, monitor, identity match, campaign analysis, etc.).
///
/// The id is what we persist in [InvestigationController.selectedActionId];
/// the [promptInstruction] is the framing we inject into the
/// investigation prompt so the model knows what the user expects.
enum InvestigationAction {
  compare(
    id: 'compare',
    icon: Icons.compare_arrows,
  ),
  monitor(
    id: 'monitor',
    icon: Icons.remove_red_eye_outlined,
  ),
  match(
    id: 'match',
    icon: Icons.verified_user_outlined,
  ),
  campaign(
    id: 'campaign',
    icon: Icons.trending_up,
  ),
  influencer(
    id: 'influencer',
    icon: Icons.person_outline,
  );

  const InvestigationAction({required this.id, required this.icon});

  /// Stable slug used in storage and as the controller's
  /// `selectedActionId`. Never localized.
  final String id;

  /// Tile icon shown on the quick-actions card.
  final IconData icon;

  /// Human label shown on the tile (l10n key).
  String get l10nLabelKey => 'inv_action_$id';
  String get l10nSubKey => 'inv_action_${id}_sub';

  /// Short instruction injected into the AI prompt. This is the
  /// "lens" that tells the model what kind of output the user
  /// wants. These are written in English so the model gets a
  /// consistent directive regardless of UI language.
  String get promptInstruction {
    switch (this) {
      case InvestigationAction.compare:
        return 'Run a SIDE-BY-SIDE COMPARISON of the two entities '
            'mentioned in the user query. For each dimension '
            '(market position, audience, recent moves, strengths, '
            'weaknesses) call out who leads and by how much. '
            'Use a comparison table if helpful.';
      case InvestigationAction.monitor:
        return 'Build a MONITORING BRIEF for the entity in the user '
            'query. List the signals we should track weekly '
            '(mentions, sentiment, share of voice, top channels), '
            'the thresholds that would flag a real change, and a '
            'recommended tracking cadence.';
      case InvestigationAction.match:
        return 'Treat any attached files as the SUBJECT and find '
            'identity / brand / product matches. If the query '
            'names a target entity, compare against it. Otherwise '
            'surface the closest public matches. Highlight '
            'visual or textual similarity, plus any disambiguating '
            'differences.';
      case InvestigationAction.campaign:
        return 'Analyse the marketing CAMPAIGN described in the '
            'user query (or the most recent one if not specified). '
            'Cover objective, audience, channels, creative angles, '
            'expected vs actual KPIs, and what to do next. If no '
            'campaign is named, propose a campaign plan for the '
            'entity.';
      case InvestigationAction.influencer:
        return 'Analyse the INFLUENCER referenced in the user query. '
            'Cover audience fit, authenticity signals (followers / '
            'engagement ratio), recent content themes, brand '
            'collaborations, and a recommendation on whether to '
            'work with them. If no influencer is named, surface '
            'the top candidates for the given vertical and region.';
    }
  }

  /// Resolves an [InvestigationAction] from its id. Returns `null`
  /// when the id does not match any known action.
  static InvestigationAction? fromId(String? id) {
    if (id == null) return null;
    for (final a in InvestigationAction.values) {
      if (a.id == id) return a;
    }
    return null;
  }
}
