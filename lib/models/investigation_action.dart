import 'package:flutter/material.dart';

import 'entity_type.dart';

/// Quick-action modes the user can pick on the investigation screen.
/// Each mode tells the AI which "lens" to apply to the user's query
/// (compare, monitor, identity match, campaign analysis, etc.).
///
/// The id is what we persist in [InvestigationController.selectedActionId];
/// the [promptInstruction] is the framing we inject into the
/// investigation prompt so the model knows what the user expects.
///
/// Each action also pins a [entityType] — this is the implicit
/// "what kind of thing am I investigating" the action assumes.
/// The controller uses this to keep the entity-type tile and the
/// quick-action in sync so the prompt can never mix vocabularies
/// (e.g. a brand report about an influencer).
enum InvestigationAction {
  compare(
    id: 'compare',
    icon: Icons.compare_arrows,
    entityType: EntityType.brand,
  ),
  monitor(
    id: 'monitor',
    icon: Icons.remove_red_eye_outlined,
    entityType: EntityType.brand,
  ),
  match(
    id: 'match',
    icon: Icons.verified_user_outlined,
    entityType: EntityType.brand,
  ),
  campaign(
    id: 'campaign',
    icon: Icons.trending_up,
    entityType: EntityType.brand,
  ),
  influencer(
    id: 'influencer',
    icon: Icons.person_outline,
    entityType: EntityType.influencer,
  );

  const InvestigationAction({
    required this.id,
    required this.icon,
    required this.entityType,
  });

  /// Stable slug used in storage and as the controller's
  /// `selectedActionId`. Never localized.
  final String id;

  /// Tile icon shown on the quick-actions card.
  final IconData icon;

  /// The entity type this action implicitly investigates. When
  /// the user picks an action without explicitly choosing an
  /// entity type, the controller uses this as the default so the
  /// prompt and the UI never disagree.
  final EntityType entityType;

  /// Human label shown on the tile (l10n key).
  String get l10nLabelKey => 'inv_action_$id';
  String get l10nSubKey => 'inv_action_${id}_sub';

  /// Short instruction injected into the AI prompt. This is the
  /// "lens" that tells the model what kind of output the user
  /// wants. These are written in English so the model gets a
  /// consistent directive regardless of UI language.
  ///
  /// The instruction is rendered against the SELECTED entity
  /// type so the lens vocabulary and the report vocabulary stay
  /// aligned. For an "influencer" + "compare" run, the language
  /// talks about peer creators, not peer brands.
  String promptInstructionFor(EntityType type) {
    switch (this) {
      case InvestigationAction.compare:
        return 'Run a SIDE-BY-SIDE COMPARISON of the two entities '
            'mentioned in the user query. For each dimension '
            'appropriate to the SELECTED entity type '
            '(${_comparisonDimensions(type)}) call out who leads '
            'and by how much. Use a comparison table if helpful. '
            'Use ${_vocabularyPhrase(type)} vocabulary.';
      case InvestigationAction.monitor:
        return 'Build a MONITORING BRIEF for the entity in the user '
            'query. List the signals we should track regularly '
            '(${_monitoringSignals(type)}), the thresholds that '
            'would flag a real change, and a recommended tracking '
            'cadence. Use ${_vocabularyPhrase(type)} vocabulary.';
      case InvestigationAction.match:
        return 'Treat any attached files as the SUBJECT and find '
            'identity / ${_vocabularyPhrase(type)} matches. If the '
            'query names a target entity, compare against it. '
            'Otherwise surface the closest public matches. '
            'Highlight visual or textual similarity, plus any '
            'disambiguating differences.';
      case InvestigationAction.campaign:
        return 'Analyse the CAMPAIGN described in the user query '
            '(${_campaignHint(type)}). Cover objective, audience, '
            'channels, creative angles, expected vs actual KPIs, '
            'and what to do next. If no campaign is named, propose '
            'a campaign plan for the entity. Use '
            '${_vocabularyPhrase(type)} vocabulary.';
      case InvestigationAction.influencer:
        return 'Analyse the INFLUENCER referenced in the user query. '
            'Cover audience fit, authenticity signals (followers / '
            'engagement ratio), recent content themes, brand '
            'collaborations, and a recommendation on whether to '
            'work with them. If no influencer is named, surface '
            'the top candidates for the given vertical and region. '
            'Use influencer vocabulary.';
    }
  }

  /// Backwards-compatible accessor. Prefer
  /// [promptInstructionFor] when the entity type is known.
  String get promptInstruction =>
      promptInstructionFor(EntityType.brand);

  /// Human-readable phrase describing the entity type's vocabulary
  /// for use in the instruction prompt.
  static String _vocabularyPhrase(EntityType type) {
    switch (type) {
      case EntityType.influencer:
        return 'influencer (handles, followers, engagement, audience, '
            'collaborations, partnership fit)';
      case EntityType.product:
        return 'product (specs, price tier, pros/cons, alternatives, '
            'where to buy)';
      case EntityType.brand:
        return 'brand (positioning, awareness, sentiment, campaigns)';
      case EntityType.company:
        return 'corporate (ownership, financials, governance, '
            'leadership, M&A)';
      case EntityType.market:
        return 'market (size, CAGR, drivers, players, regulation)';
    }
  }

  /// Comparison dimensions appropriate to the entity type.
  static String _comparisonDimensions(EntityType type) {
    switch (type) {
      case EntityType.influencer:
        return 'audience size, engagement rate, content pillars, '
            'authenticity signals, brand collaborations, pricing tier';
      case EntityType.product:
        return 'specs, price tier, review aggregate, value-for-money, '
            'availability, pros/cons';
      case EntityType.brand:
        return 'positioning, awareness, sentiment, top product lines, '
            'campaign performance, competitive share';
      case EntityType.company:
        return 'ownership, revenue, growth, margin, leadership, '
            'governance, recent strategic moves';
      case EntityType.market:
        return 'size, CAGR, growth drivers, dominant players, '
            'channel shifts, regulation';
    }
  }

  /// Monitoring signals appropriate to the entity type.
  static String _monitoringSignals(EntityType type) {
    switch (type) {
      case EntityType.influencer:
        return 'follower growth, engagement rate, content-cadence, '
            'new collaborations, audience sentiment';
      case EntityType.product:
        return 'review aggregate, restocks, price changes, recall '
            'notices, counterfeit reports';
      case EntityType.brand:
        return 'share of voice, sentiment, search trend, campaign '
            'launches, competitor moves';
      case EntityType.company:
        return 'earnings, M&A, leadership changes, regulatory '
            'filings, audit news';
      case EntityType.market:
        return 'sector size, CAGR, regulatory changes, dominant '
            'player moves, channel shifts';
    }
  }

  /// What kind of "campaign" the lens refers to for this entity type.
  static String _campaignHint(EntityType type) {
    switch (type) {
      case EntityType.influencer:
        return 'a brand collaboration / sponsored-content campaign '
            'the creator recently ran, or a campaign the creator is '
            'a face of';
      case EntityType.product:
        return 'the most recent launch / promo campaign for the '
            'product';
      case EntityType.brand:
        return 'the most recent marketing campaign for the brand';
      case EntityType.company:
        return 'the most recent corporate campaign '
            '(investor / talent / employer-brand)';
      case EntityType.market:
        return 'the dominant campaign pattern in the sector';
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
