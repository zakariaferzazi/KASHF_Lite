import 'package:flutter/foundation.dart';

/// A single KPI card on the Market Pulse screen.
@immutable
class MarketKpi {
  const MarketKpi({
    required this.id,
    required this.label,
    required this.value,
    required this.sub,
    required this.delta,
    required this.positive,
  });

  /// One of: `posts`, `tweets`, `dominance`, `activity`. The
  /// `activity` card hides the delta arrow and shows a dash.
  final String id;
  final String label;
  final String value;
  final String sub;
  final String delta;
  final bool positive;
}

/// A single segment of the donut "sources" chart.
@immutable
class MarketSourceSegment {
  const MarketSourceSegment({
    required this.name,
    required this.fraction,
    required this.colorName,
  });

  final String name;
  final double fraction; // 0..1, sum across all segments ~= 1
  final String colorName; // "green" / "amber" / "red"
}

/// A single data point on the trend line. `value` is a real
/// (non-normalized) number so the y-axis labels can be derived.
@immutable
class MarketTrendPoint {
  const MarketTrendPoint({required this.label, required this.value});
  final String label; // "يوم 1", "اليوم 1", etc.
  final double value;
}

/// A single "most traded topic" card.
@immutable
class MarketTopic {
  const MarketTopic({
    required this.label,
    required this.brand,
    required this.change,
    required this.positive,
    required this.points,
  });

  final String label;
  final String brand;
  final String change; // e.g. "+12%"
  final bool positive;
  final List<double> points; // 0..1 normalized sparkline
}

/// A single "fastest growing brand" card.
@immutable
class MarketBrand {
  const MarketBrand({
    required this.name,
    required this.growth,
    required this.positive,
    required this.imageHint,
    this.domain,
  });

  final String name;
  final String growth; // e.g. "+45%"
  final bool positive;
  final String imageHint; // brand slug for asset picker
  /// The brand's official website domain (e.g. "starbucks.com").
  /// The UI builds the logo URL from this — the AI never has to
  /// invent image URLs.
  final String? domain;
}

/// A single "important current event" row.
@immutable
class MarketEvent {
  const MarketEvent({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.status,
    required this.statusColorName,
  });

  final String title;
  final String subtitle;
  final String time;
  final String status;
  final String statusColorName; // "green" / "amber" / "red"
}

/// Top-level payload returned by the AI service for the Market
/// Pulse screen.
@immutable
class MarketDetailData {
  const MarketDetailData({
    required this.kpis,
    required this.sources,
    required this.trend,
    required this.trendYMax,
    required this.topics,
    required this.brands,
    required this.events,
  });

  final List<MarketKpi> kpis; // 4 entries
  final List<MarketSourceSegment> sources; // 3 entries, fractions ~ 1.0
  final List<MarketTrendPoint> trend; // 7..14 entries
  final double trendYMax; // upper bound for the Y-axis label
  final List<MarketTopic> topics; // 5 entries
  final List<MarketBrand> brands; // 5..6 entries
  final List<MarketEvent> events; // 3 entries
}
