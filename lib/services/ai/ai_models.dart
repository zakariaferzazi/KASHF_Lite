import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A single metric card for the Market Pulse section. Mirrors the
/// shape used by the `_PulseCardData` widget in `home_screen.dart`,
/// but is owned by the AI service so we can build it from the
/// OpenRouter response.
@immutable
class MarketPulseMetric {
  const MarketPulseMetric({
    required this.id,
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    required this.bg,
    required this.points,
  });

  final String id;
  final String label;
  final String value;
  final String sub;

  /// A semantic color name. The UI maps this to a concrete
  /// [Color] via [_colorFor].
  final PulseColor color;
  final PulseColor bg;

  /// Sparkline values in the 0..1 range, normalized.
  final List<double> points;
}

enum PulseColor { green, blue, red, gold, purple, orange }

/// A single activity strip for the bottom of the Market Pulse
/// panel ("market active" / "alert" / sparkline).
@immutable
class MarketPulseActivity {
  const MarketPulseActivity({
    required this.title,
    required this.subtitle,
    required this.alertTitle,
    required this.alertValue,
    required this.comparisonText,
    required this.color,
    required this.points,
  });

  final String title;
  final String subtitle;
  final String alertTitle;
  final String alertValue;
  final String comparisonText;
  final PulseColor color;
  final List<double> points;
}

/// Complete payload returned by the AI service for the Market
/// Pulse section.
@immutable
class MarketPulseData {
  const MarketPulseData({
    required this.metrics,
    required this.activity,
  });

  final List<MarketPulseMetric> metrics; // 4 entries
  final MarketPulseActivity activity;
}

/// One action card in the Quick Actions Grid.
@immutable
class QuickAction {
  const QuickAction({
    required this.id,
    required this.title,
    required this.progress,
    required this.statusText,
    required this.statusColor,
    required this.progressColor,
    required this.imagePath,
    required this.showDot,
    required this.dotColor,
  });

  final String id;
  final String title;

  /// 0..1, displayed as a percentage.
  final double progress;
  final String statusText;
  final PulseColor statusColor;
  final PulseColor progressColor;

  /// Optional image path under assets/images/. May be empty.
  final String imagePath;

  final bool showDot;
  final PulseColor dotColor;
}

/// A single line in the Recent Updates list.
@immutable
class RecentUpdateItem {
  const RecentUpdateItem({
    required this.id,
    required this.title,
    required this.priceLine,
    required this.viewsLine,
    required this.statusText,
    required this.timeText,
    required this.scorePercent,
    required this.scoreColor,
    required this.dotColor,
    required this.imagePath,
  });

  final String id;
  final String title;
  final String priceLine;
  final String viewsLine;
  final String statusText;
  final String timeText;
  final int scorePercent;
  final PulseColor scoreColor;
  final PulseColor dotColor;
  final String imagePath;
}

/// Full payload for the Quick Actions + Recent Updates sections.
@immutable
class QuickActionsData {
  const QuickActionsData({
    required this.actions,
    required this.recentUpdates,
  });

  final List<QuickAction> actions;
  final List<RecentUpdateItem> recentUpdates;
}

/// Maps a [PulseColor] to a concrete color, pulled from the
/// brand palette. Keeping the mapping in the AI layer means the
/// service can return semantic colors and the UI just renders
/// them — no separate theme pass needed.
Color pulseColorToColor(PulseColor c) {
  switch (c) {
    case PulseColor.green:
      return const Color(0xFF22C55E);
    case PulseColor.blue:
      return const Color(0xFF3B82F6);
    case PulseColor.red:
      return const Color(0xFFEF4444);
    case PulseColor.gold:
      return const Color(0xFFF4C542);
    case PulseColor.purple:
      return const Color(0xFF8B5CF6);
    case PulseColor.orange:
      return const Color(0xFFFB923C);
  }
}

/// Background used for pulse cards. Slightly darker than the
/// foreground color so the card reads as a colored tile.
Color pulseBgForColor(PulseColor c) {
  switch (c) {
    case PulseColor.green:
      return const Color(0xFF12241A);
    case PulseColor.blue:
      return const Color(0xFF13202A);
    case PulseColor.red:
      return const Color(0xFF241318);
    case PulseColor.gold:
      return const Color(0xFF241F12);
    case PulseColor.purple:
      return const Color(0xFF1F1530);
    case PulseColor.orange:
      return const Color(0xFF2A1F12);
  }
}

/// Best-effort mapping from a string identifier to a [PulseColor].
PulseColor pulseColorFromString(String? s) {
  switch (s?.toLowerCase()) {
    case 'green':
      return PulseColor.green;
    case 'blue':
      return PulseColor.blue;
    case 'red':
      return PulseColor.red;
    case 'gold':
    case 'yellow':
      return PulseColor.gold;
    case 'purple':
      return PulseColor.purple;
    case 'orange':
      return PulseColor.orange;
    default:
      return PulseColor.green;
  }
}

/// Deterministic pseudo-random sparkline generator. We use it as
/// a fallback when the AI does not return sparkline points so the
/// UI always has something to render. The output oscillates with
/// high amplitude so the line does NOT look like a near-straight
/// trend — adjacent points are noticeably different.
List<double> generateFallbackSparkline({
  int length = 24,
  double seed = 0.5,
  double min = 0.20,
  double max = 0.90,
}) {
  final rng = math.Random((seed * 1000).toInt());
  // Anchor on a base trend and add a heavy random walk so each
  // step is a real jump (not the previous blended with the
  // random — that produces a near-straight line).
  final base = (min + max) / 2;
  final amp = (max - min) / 2;
  return List<double>.generate(length, (i) {
    // Slow trend: gentle drift over the window.
    final trend = math.sin((i / length) * math.pi * 2) * (amp * 0.45);
    // Fast oscillation: large, independent random step.
    final noise = (rng.nextDouble() - 0.5) * amp * 0.85;
    final v = (base + trend + noise).clamp(min, max);
    return v;
  });
}
