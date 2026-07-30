import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../theme.dart';

/// KASHF Lite dashboard. The entry point after sign-in. Layout mirrors
/// the marketing reference: greeting + user avatar, search bar with
/// shortcuts, featured investigation card, weekly market pulse, 6
/// quick actions in a 2-column grid, and recent updates carousel.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Use the natural direction for the active language so Arabic flows
    // right-to-left and English flows left-to-right natively.
    return Directionality(
      textDirection: l.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: KashfPalette.active.background,
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 16, 20, 8),
                sliver: SliverToBoxAdapter(child: _TopBar(l: l)),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 8, 20, 16),
                sliver: SliverToBoxAdapter(
                  child: _SearchBar(hint: l.t('home_search_hint')),
                ),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 16),
                sliver: SliverToBoxAdapter(child: _FeaturedInvestigation(l: l)),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: _SectionHeader(title: l.t('home_market_pulse')),
                ),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 8, 20, 16),
                sliver: SliverToBoxAdapter(child: _MarketPulseList(l: l)),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: _SectionHeader(title: l.t('home_quick_actions')),
                ),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 8, 20, 16),
                sliver: SliverToBoxAdapter(child: _QuickActionsGrid(l: l)),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: _SectionHeader(title: l.t('home_recent_activity')),
                ),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 8, 20, 32),
                sliver: SliverToBoxAdapter(child: _RecentUpdatesList(l: l)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================ Top Bar ============================
class _TopBar extends StatelessWidget {
  const _TopBar({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    // In LTR (English) the logo is on the left and avatar on the right.
    // In RTL (Arabic) the order is mirrored automatically by Directionality.
    final logo = KashfLogo(width: 56);
    final avatar = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: KashfColors.gold.withValues(alpha: 0.18),
        border: Border.all(color: KashfColors.gold, width: 1.4),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: Image.asset(
        'assets/images/logoprofile.jpeg',
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            Icon(Icons.person, color: KashfColors.gold, size: 22),
      ),
    );
    final greeting = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${l.t('home_greeting')}، ${l.t('home_user_name')}',
          style: TextStyle(
            color: KashfPalette.active.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 4),
        Text(
          l.t('home_subtitle'),
          style: TextStyle(
            color: KashfPalette.active.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
    // Logo always on the opposite side:
    // - English (LTR): avatar on left, logo on right.
    // - Arabic (RTL): logo on left, avatar on right.
    return Row(
      children: l.isRtl
          ? [
              logo,
              SizedBox(width: 10),
              Expanded(child: greeting),
              SizedBox(width: 8),
              avatar,
            ]
          : [
              avatar,
              SizedBox(width: 10),
              Expanded(child: greeting),
              SizedBox(width: 8),
              logo,
            ],
    );
  }
}

// ============================ Search Bar ============================
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.hint});
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Row(
        children: [
          SizedBox(width: 4),
          Expanded(
            child: Text(
              hint,
              style: TextStyle(
                color: KashfPalette.active.textSecondary,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: KashfColors.gold,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(Icons.search, color: Colors.black, size: 20),
          ),
        ],
      ),
    );
  }
}

// ============================ Featured Investigation ============================
class _FeaturedInvestigation extends StatelessWidget {
  const _FeaturedInvestigation({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1F1810), Color(0xFF2D2418)],
        ),
        border: Border.all(
          color: KashfColors.gold.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top header row: badge + close button.
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(14, 12, 14, 8),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: KashfColors.gold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: KashfColors.gold,
                        size: 12,
                      ),
                      SizedBox(width: 4),
                      Text(
                        l.t('home_featured_today'),
                        style: TextStyle(
                          color: KashfColors.gold,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Color(0xFF22C55E).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.trending_up,
                        color: Color(0xFF22C55E),
                        size: 12,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '+18 %',
                        style: TextStyle(
                          color: Color(0xFF22C55E),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Hero content: image on right, title and metadata on left.
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(14, 4, 14, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.t('home_featured_title'),
                        style: TextStyle(
                          color: KashfPalette.active.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.public, color: KashfColors.gold, size: 11),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              l.t('home_featured_subtitle'),
                              style: TextStyle(
                                color: KashfPalette.active.textSecondary,
                                fontSize: 11,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10),
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Color(0xFF1A0F08),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'assets/images/parfum.jpeg',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.local_florist,
                      color: KashfColors.gold,
                      size: 32,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // KPI tiles row.
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(14, 0, 14, 12),
            child: Row(
              children: [
                _KpiTile(
                  label: '+18%',
                  value: '28.4K',
                  sub: 'Mentions',
                  color: KashfColors.gold,
                ),
                SizedBox(width: 8),
                _KpiTile(
                  label: '+24%',
                  value: '4.1K',
                  sub: 'Authors',
                  color: const Color(0xFF60A5FA),
                ),
                SizedBox(width: 8),
                _KpiTile(
                  label: '+32%',
                  value: '72 %',
                  sub: 'Reach',
                  color: const Color(0xFF22C55E),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });
  final String label;
  final String value;
  final String sub;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            SizedBox(height: 2),
            Text(
              sub,
              style: TextStyle(
                color: KashfPalette.active.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipAction extends StatelessWidget {
  const _ChipAction({
    required this.icon,
    required this.label,
    this.primary = false,
  });
  final IconData icon;
  final String label;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: primary
            ? KashfColors.gold.withValues(alpha: 0.18)
            : KashfPalette.active.fieldFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: primary ? KashfColors.gold : KashfPalette.active.fieldBorder,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: primary
                ? KashfColors.gold
                : KashfPalette.active.textSecondary,
            size: 12,
          ),
          SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: primary
                    ? KashfColors.gold
                    : KashfPalette.active.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================ Section Header ============================
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing, this.onTrailing});
  final String title;
  final String? trailing;
  final VoidCallback? onTrailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: KashfPalette.active.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (trailing != null)
          GestureDetector(
            onTap: onTrailing,
            child: Text(
              trailing!,
              style: TextStyle(
                color: KashfColors.gold,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

// ============================ Market Pulse ============================
class _MarketPulseList extends StatelessWidget {
  const _MarketPulseList({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final tiles = <_PulseTile>[
      _PulseTile(
        imagePath: 'assets/images/winner.jpeg',
        title: l.t('home_market_gainers'),
        subtitle: l.t('home_pulse_sub_gainers'),
        value: '+32 %',
        color: Color(0xFF22C55E),
      ),
      _PulseTile(
        imagePath: 'assets/images/lattafa.jpeg',
        title: 'Lattafa',
        subtitle: l.t('home_pulse_sub_lattafa'),
        value: '+15 %',
        color: Color(0xFF22C55E),
      ),
      _PulseTile(
        imagePath: 'assets/images/sauvage.jpeg',
        title: 'Dior Sauvage',
        subtitle: l.t('home_pulse_sub_sauvage'),
        value: '+18 %',
        color: Color(0xFF22C55E),
      ),
      _PulseTile(
        imagePath: 'assets/images/parfum.jpeg',
        title: 'العطور الصيفية',
        subtitle: l.t('home_pulse_sub_perfumes'),
        value: '+24 %',
        color: Color(0xFF22C55E),
      ),
    ];
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tiles.length,
        separatorBuilder: (_, _) => SizedBox(width: 10),
        itemBuilder: (_, i) => _PulseCard(tile: tiles[i]),
      ),
    );
  }
}

class _PulseTile {
  const _PulseTile({
    required this.imagePath,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.color,
  });
  final String imagePath;
  final String title;
  final String subtitle;
  final String value;
  final Color color;
}

class _PulseCard extends StatelessWidget {
  const _PulseCard({required this.tile});
  final _PulseTile tile;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 220),
      child: Container(
        padding: EdgeInsetsDirectional.fromSTEB(12, 0, 12, 0),
        decoration: BoxDecoration(
          color: KashfPalette.active.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: KashfPalette.active.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: tile.color.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                tile.imagePath,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: tile.color.withValues(alpha: 0.2),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.image_outlined,
                    color: tile.color,
                    size: 16,
                  ),
                ),
              ),
            ),
            SizedBox(width: 10),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    tile.subtitle,
                    style: TextStyle(
                      color: KashfPalette.active.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  Text(
                    tile.title,
                    style: TextStyle(
                      color: KashfPalette.active.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    tile.value,
                    style: TextStyle(
                      color: tile.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================ Quick Actions ============================
class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final actions = <_QuickAction>[
      _QuickAction(
        icon: Icons.search,
        color: Color(0xFFF59E0B),
        title: l.t('home_action_search'),
        subtitle: l.t('home_action_search_sub'),
      ),
      _QuickAction(
        icon: Icons.people_outline,
        color: Color(0xFFC084FC),
        title: l.t('home_action_users'),
        subtitle: l.t('home_action_users_sub'),
      ),
      _QuickAction(
        icon: Icons.business_outlined,
        color: Color(0xFF60A5FA),
        title: l.t('home_action_identities'),
        subtitle: l.t('home_action_identities_sub'),
      ),
      _QuickAction(
        icon: Icons.inventory_2_outlined,
        color: Color(0xFF22C55E),
        title: l.t('home_action_products'),
        subtitle: l.t('home_action_products_sub'),
      ),
      _QuickAction(
        icon: Icons.trending_up,
        color: Color(0xFFFB923C),
        title: l.t('home_action_market'),
        subtitle: l.t('home_action_market_sub'),
      ),
      _QuickAction(
        icon: Icons.mic_none,
        color: Color(0xFFEC4899),
        title: l.t('home_action_content'),
        subtitle: l.t('home_action_content_sub'),
      ),
    ];
    final rows = <Widget>[];
    for (var i = 0; i < actions.length; i += 2) {
      final children = <Widget>[
        Expanded(child: _QuickActionCard(action: actions[i])),
        if (i + 1 < actions.length) ...[
          SizedBox(width: 10),
          Expanded(child: _QuickActionCard(action: actions[i + 1])),
        ],
      ];
      rows.add(Row(children: children));
      if (i + 2 < actions.length) rows.add(SizedBox(height: 10));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.action});
  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {},
        child: Container(
          padding: EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: KashfPalette.active.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: KashfPalette.active.cardBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(action.icon, color: action.color, size: 22),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      style: TextStyle(
                        color: KashfPalette.active.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2),
                    Text(
                      action.subtitle,
                      style: TextStyle(
                        color: KashfPalette.active.textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: KashfPalette.active.textSecondary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================ Recent Updates ============================
class _RecentUpdatesList extends StatelessWidget {
  const _RecentUpdatesList({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final items = <_UpdateItem>[
      _UpdateItem(
        title: l.t('home_update_perfume'),
        subtitle: l.t('home_update_perfume_h'),
        score: l.t('home_update_perfume_score'),
        scoreColor: Color(0xFF22C55E),
        imagePath: 'assets/images/parfum.jpeg',
      ),
      _UpdateItem(
        title: l.t('home_update_campaign'),
        subtitle: l.t('home_update_campaign_h'),
        score: l.t('home_update_campaign_score'),
        scoreColor: KashfColors.gold,
        imagePath: 'assets/images/borge.jpeg',
      ),
      _UpdateItem(
        title: l.t('home_update_market'),
        subtitle: l.t('home_update_market_h'),
        score: l.t('home_update_market_score'),
        scoreColor: Color(0xFFEF4444),
        imagePath: 'assets/images/sauvage.jpeg',
      ),
      _UpdateItem(
        title: l.t('home_update_yasmine'),
        subtitle: l.t('home_update_yasmine_h'),
        score: l.t('home_update_yasmine_score'),
        scoreColor: KashfColors.gold,
        imagePath: 'assets/images/winner.jpeg',
      ),
    ];
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => SizedBox(width: 10),
        itemBuilder: (_, i) => _UpdateCard(item: items[i]),
      ),
    );
  }
}

class _UpdateItem {
  const _UpdateItem({
    required this.title,
    required this.subtitle,
    required this.score,
    required this.scoreColor,
    required this.imagePath,
  });
  final String title;
  final String subtitle;
  final String score;
  final Color scoreColor;
  final String imagePath;
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({required this.item});
  final _UpdateItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              child: Container(
                width: double.infinity,
                color: const Color(0xFF2D2418),
                child: Image.asset(
                  item.imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    alignment: Alignment.center,
                    color: const Color(0xFF2D2418),
                    child: const Icon(
                      Icons.image_outlined,
                      color: KashfColors.gold,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: KashfPalette.active.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  item.subtitle,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: KashfPalette.active.textSecondary,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: item.scoreColor.withValues(alpha: 0.6),
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        item.score,
                        style: TextStyle(
                          color: item.scoreColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
