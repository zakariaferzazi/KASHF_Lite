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
    return Scaffold(
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
              sliver: SliverToBoxAdapter(
                child: _FeaturedInvestigation(l: l),
              ),
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
                child: _SectionHeader(
                  title: l.t('home_recent_activity'),
                  trailing: l.t('home_view_details'),
                  onTrailing: () {},
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsetsDirectional.fromSTEB(20, 8, 20, 32),
              sliver: SliverToBoxAdapter(child: _RecentUpdatesList(l: l)),
            ),
          ],
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
    final isRtl = l.isRtl;
    // In LTR the logo is on the left and avatar on the right.
    // In RTL that order is mirrored automatically by Directionality.
    final logo = KashfLogo(width: 56);
    final avatar = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: KashfPalette.active.surface,
        border: Border.all(color: KashfColors.gold, width: 1.4),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.person, color: KashfColors.gold, size: 22),
    );
    final bell = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: KashfPalette.active.surface,
            border: Border.all(color: KashfPalette.active.cardBorder),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.notifications_none,
              color: KashfPalette.active.textPrimary, size: 20),
        ),
        Positioned(
          top: -2,
          right: -2,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: KashfColors.gold,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '2',
              style: TextStyle(
                color: Colors.black,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
    final greeting = Column(
      crossAxisAlignment:
          isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
    return Row(
      children: [
        logo,
        SizedBox(width: 10),
        Expanded(child: greeting),
        bell,
        SizedBox(width: 8),
        avatar,
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
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.attach_money,
                color: KashfPalette.active.textSecondary, size: 20),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.qr_code_scanner,
                color: KashfPalette.active.textSecondary, size: 20),
          ),
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
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(14, 12, 14, 8),
            child: Row(
              children: [
                Icon(Icons.auto_awesome,
                    color: KashfColors.gold, size: 14),
                SizedBox(width: 6),
                Text(
                  l.t('home_featured_today'),
                  style: TextStyle(
                    color: KashfColors.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(14, 0, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image placeholder card.
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF7B5A2B), Color(0xFF2D2418)],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.local_florist,
                      color: KashfColors.gold, size: 36),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.t('home_featured_title'),
                        style: TextStyle(
                          color: KashfPalette.active.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.schedule,
                              color: KashfPalette.active.textSecondary, size: 12),
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
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _ChipAction(
                            icon: Icons.bookmark_add_outlined,
                            label: l.t('home_featured_watchlist'),
                          ),
                          _ChipAction(
                            icon: Icons.open_in_new,
                            label: l.t('home_featured_open'),
                            primary: true,
                          ),
                          _ChipAction(
                            icon: Icons.chat_bubble_outline,
                            label: l.t('home_featured_chat'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(14, 0, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      l.t('home_featured_progress_label'),
                      style: TextStyle(
                        color: KashfPalette.active.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Spacer(),
                    Text(
                      '${l.t('home_featured_progress_label')}\n72 %',
                      style: TextStyle(
                        color: KashfColors.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: 0.72,
                    minHeight: 6,
                    backgroundColor: KashfPalette.active.cardBorder,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(KashfColors.gold),
                  ),
                ),
              ],
            ),
          ),
        ],
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: primary ? KashfColors.gold : KashfPalette.active.textSecondary,
              size: 12),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: primary ? KashfColors.gold : KashfPalette.active.textPrimary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
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
        avatar: Icons.person,
        avatarColor: KashfColors.gold,
        title: l.t('home_market_gainers'),
        value: '+32 %',
        color: Color(0xFF22C55E),
      ),
      _PulseTile(
        avatar: Icons.local_fire_department,
        avatarColor: KashfColors.gold,
        title: 'Lattafa',
        value: '+15 %',
        color: Color(0xFF22C55E),
      ),
      _PulseTile(
        avatar: Icons.brush_outlined,
        avatarColor: KashfColors.gold,
        title: 'Dior Sauvage',
        value: '+18 %',
        color: Color(0xFF22C55E),
      ),
      _PulseTile(
        avatar: Icons.local_fire_department,
        avatarColor: Color(0xFFEF4444),
        title: l.t('home_market_losers'),
        value: '-24 %',
        color: Color(0xFFEF4444),
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
    required this.avatar,
    required this.avatarColor,
    required this.title,
    required this.value,
    required this.color,
  });
  final IconData avatar;
  final Color avatarColor;
  final String title;
  final String value;
  final Color color;
}

class _PulseCard extends StatelessWidget {
  const _PulseCard({required this.tile});
  final _PulseTile tile;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tile.avatarColor.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(tile.avatar, color: tile.avatarColor, size: 18),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  tile.title,
                  style: TextStyle(
                    color: KashfPalette.active.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  tile.value,
                  style: TextStyle(
                    color: tile.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
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
        color: Color(0xFF6F8BFF),
        title: l.t('home_action_search'),
        subtitle: l.t('home_action_search_sub'),
      ),
      _QuickAction(
        icon: Icons.people_outline,
        color: Color(0xFFEC4899),
        title: l.t('home_action_users'),
        subtitle: l.t('home_action_users_sub'),
      ),
      _QuickAction(
        icon: Icons.bar_chart,
        color: Color(0xFF6F8BFF),
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
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (_, i) => _QuickActionCard(action: actions[i]),
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
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: KashfPalette.active.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: KashfPalette.active.cardBorder),
          ),
          child: Column(
            crossAxisAlignment:
                Directionality.of(context) == TextDirection.rtl
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(action.icon, color: action.color, size: 18),
              ),
              Spacer(),
              Text(
                action.title,
                style: TextStyle(
                  color: KashfPalette.active.textPrimary,
                  fontSize: 12,
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
                  fontSize: 10,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
        icon: Icons.local_florist,
        coverColors: const [Color(0xFF7B5A2B), Color(0xFF2D2418)],
      ),
      _UpdateItem(
        title: l.t('home_update_campaign'),
        subtitle: l.t('home_update_campaign_h'),
        score: l.t('home_update_campaign_score'),
        scoreColor: KashfColors.gold,
        icon: Icons.person_outline,
        coverColors: const [Color(0xFF3A2E25), Color(0xFF1A1A1A)],
      ),
      _UpdateItem(
        title: l.t('home_update_market'),
        subtitle: l.t('home_update_market_h'),
        score: l.t('home_update_market_score'),
        scoreColor: Color(0xFFEF4444),
        icon: Icons.brush_outlined,
        coverColors: const [Color(0xFF2A1810), Color(0xFF0F0F0F)],
      ),
      _UpdateItem(
        title: l.t('home_update_yasmine'),
        subtitle: l.t('home_update_yasmine_h'),
        score: l.t('home_update_yasmine_score'),
        scoreColor: KashfColors.gold,
        icon: Icons.location_city_outlined,
        coverColors: const [Color(0xFF2A2F36), Color(0xFF0E1014)],
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
    required this.icon,
    required this.coverColors,
  });
  final String title;
  final String subtitle;
  final String score;
  final Color scoreColor;
  final IconData icon;
  final List<Color> coverColors;
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
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: item.coverColors,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(item.icon,
                  color: KashfColors.gold.withValues(alpha: 0.85), size: 32),
            ),
          ),
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
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
