import 'package:flutter/material.dart';

import '../theme.dart';
import 'entity_type.dart';
import 'investigation.dart';
import 'report.dart';

/// Static demo data for the MVP. These would be replaced by real API
/// responses once the OpenRouter / data layer is wired up.
class MockData {
  /// Investigations shown on the Home dashboard.
  static List<Investigation> investigations(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final isAr = locale == 'ar';
    return [
      Investigation(
        id: 'inv-1',
        title: isAr ? 'ماسك — تحليل العلامة' : 'Mascara — Brand analysis',
        entityType: EntityType.brand,
        status: InvestigationStatus.active,
        lastUpdated: DateTime.now().subtract(const Duration(hours: 2)),
        progress: 0.72,
        summary: isAr
            ? 'تتبع المحتوى والمحادثات عبر المنصات.'
            : 'Tracking content and conversations across platforms.',
      ),
      Investigation(
        id: 'inv-2',
        title: isAr ? 'سوق الجمال في الخليج' : 'Gulf beauty market',
        entityType: EntityType.market,
        status: InvestigationStatus.active,
        lastUpdated: DateTime.now().subtract(const Duration(hours: 6)),
        progress: 0.45,
        summary: isAr
            ? 'فرص إطلاق منتجات جديدة.'
            : 'New product launch opportunities.',
      ),
      Investigation(
        id: 'inv-3',
        title: isAr ? 'مؤثرة — ريم عبدالله' : 'Influencer — Reem Abdallah',
        entityType: EntityType.influencer,
        status: InvestigationStatus.paused,
        lastUpdated: DateTime.now().subtract(const Duration(days: 1)),
        progress: 0.30,
        summary: isAr
            ? 'تحليل الجمهور والمحتوى.'
            : 'Audience and content analysis.',
      ),
      Investigation(
        id: 'inv-4',
        title: isAr ? 'شركة — نكتار القابضة' : 'Company — Nectar Holdings',
        entityType: EntityType.company,
        status: InvestigationStatus.completed,
        lastUpdated: DateTime.now().subtract(const Duration(days: 3)),
        progress: 1.0,
        summary: isAr
            ? 'تقرير نهائي تم تسليمه.'
            : 'Final report delivered.',
      ),
    ];
  }

  /// Reports shown in the Reports tab.
  static List<Report> reports(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final isAr = locale == 'ar';
    return [
      Report(
        id: 'r-1',
        title: isAr ? 'ملخص تنفيذي — ماسك' : 'Executive summary — Mascara',
        type: ReportType.executiveSummary,
        status: ReportStatus.recent,
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        preview: isAr
            ? 'ملخص لأداء العلامة خلال الربع الأخير.'
            : 'Quarterly brand performance summary.',
        sourceCount: 24,
      ),
      Report(
        id: 'r-2',
        title: isAr ? 'تحليل المنافسين — مجال العناية' : 'Competitive analysis — Care',
        type: ReportType.competitive,
        status: ReportStatus.recent,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        preview: isAr
            ? 'أبرز 5 منافسين في السوق.'
            : 'Top 5 competitors in the market.',
        sourceCount: 41,
      ),
      Report(
        id: 'r-3',
        title: isAr ? 'سوات — شركة نكتار' : 'SWOT — Nectar Holdings',
        type: ReportType.swot,
        status: ReportStatus.archived,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        preview: isAr
            ? 'تحليل نقاط القوة والضعف والفرص والتهديدات.'
            : 'Strengths, weaknesses, opportunities, threats.',
        sourceCount: 17,
      ),
      Report(
        id: 'r-4',
        title: isAr ? 'رؤية السوق — الخليج' : 'Market insight — Gulf',
        type: ReportType.marketInsight,
        status: ReportStatus.recent,
        createdAt: DateTime.now().subtract(const Duration(hours: 18)),
        preview: isAr
            ? 'اتجاهات الإنفاق والجمهور.'
            : 'Spending and audience trends.',
        sourceCount: 32,
      ),
      Report(
        id: 'r-5',
        title: isAr ? 'أفكار محتوى — حملة ربيع' : 'Content ideas — Spring campaign',
        type: ReportType.contentIdeas,
        status: ReportStatus.recent,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        preview: isAr
            ? '12 فكرة محتوى لمنصة ريلز وتيك توك.'
            : '12 content ideas for Reels and TikTok.',
        sourceCount: 12,
      ),
    ];
  }

  /// Recent searches shown on the Explore screen.
  static List<String> recentSearches(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return isAr
        ? const [
            'ماسك',
            'سوق الجمال',
            'شركة نكتار',
            'مؤثرة ريم',
            'علامة لومير',
          ]
        : const [
            'Mascara',
            'Gulf beauty market',
            'Nectar Holdings',
            'Influencer Reem',
            'Lumiere brand',
          ];
  }

  /// Suggested investigations on the Explore screen.
  static List<String> suggestedInvestigations(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return isAr
        ? const [
            'تحليل إطلاق منتج جديد',
            'تتبع حملة مؤثر',
            'دراسة فئة الجمال الفاخر',
            'تحليل تطبيق دفع',
            'مراقبة منافس جديد',
          ]
        : const [
            'New product launch analysis',
            'Influencer campaign tracking',
            'Luxury beauty category study',
            'Payment app analysis',
            'Competitor monitoring',
          ];
  }

  /// Market pulse tiles for the Home dashboard.
  static List<MarketPulseTile> marketPulse(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return [
      MarketPulseTile(
        label: isAr ? 'الرابحون' : 'Gainers',
        value: '+2.4%',
        trend: TrendDirection.up,
        color: const Color(0xFF22C55E),
      ),
      MarketPulseTile(
        label: isAr ? 'الخاسرون' : 'Losers',
        value: '-1.1%',
        trend: TrendDirection.down,
        color: const Color(0xFFEF4444),
      ),
      MarketPulseTile(
        label: isAr ? 'حجم التداول' : 'Volume',
        value: '1.2M',
        trend: TrendDirection.flat,
        color: KashfColors.gold,
      ),
    ];
  }

  /// Quick actions on the Home dashboard.
  static List<QuickAction> quickActions(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return [
      QuickAction(
        label: isAr ? 'تحقيق جديد' : 'New investigation',
        icon: Icons.add_circle_outline,
      ),
      QuickAction(
        label: isAr ? 'إنشاء تقرير' : 'Generate report',
        icon: Icons.assignment_outlined,
      ),
      QuickAction(
        label: isAr ? 'إضافة مراقبة' : 'Add monitor',
        icon: Icons.notifications_active_outlined,
      ),
      QuickAction(
        label: isAr ? 'رؤى الذكاء' : 'AI insights',
        icon: Icons.auto_awesome_outlined,
      ),
    ];
  }
}

enum TrendDirection { up, down, flat }

class MarketPulseTile {
  const MarketPulseTile({
    required this.label,
    required this.value,
    required this.trend,
    required this.color,
  });

  final String label;
  final String value;
  final TrendDirection trend;
  final Color color;
}

class QuickAction {
  const QuickAction({required this.label, required this.icon});

  final String label;
  final IconData icon;
}
