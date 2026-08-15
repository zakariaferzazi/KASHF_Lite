import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;

/// Color tokens used by the Market Pulse cards (gainers / losers /
/// campaigns / etc.). The home / market UIs convert these into
/// concrete `Color` values via [pulseColorToColor].
enum PulseColor { green, blue, red, gold, amber }

/// Resolves a [PulseColor] from a string returned by the AI.
/// Unknown / null values fall back to [PulseColor.blue].
PulseColor pulseColorFromString(String? raw) {
  switch (raw?.toLowerCase().trim()) {
    case 'green':
      return PulseColor.green;
    case 'red':
      return PulseColor.red;
    case 'gold':
    case 'yellow':
    case 'amber':
      return PulseColor.amber;
    case 'blue':
    default:
      return PulseColor.blue;
  }
}

/// Concrete `Color` for the pill / badge / chart stroke used by
/// the Market Pulse UI. Pulled from the brand palette so the
/// cards stay readable in light, dark, and the special "main"
/// theme.
Color pulseColorToColor(PulseColor color) {
  switch (color) {
    case PulseColor.green:
      return const Color(0xFF22C55E);
    case PulseColor.blue:
      return const Color(0xFF38BDF8);
    case PulseColor.red:
      return const Color(0xFFEF4444);
    case PulseColor.gold:
    case PulseColor.amber:
      return const Color(0xFFF4C542);
  }
}

/// Subtle background tint used behind the pulse card value. Kept
/// low-opacity so the parent surface still shows through.
Color pulseBgForColor(PulseColor color) {
  switch (color) {
    case PulseColor.green:
      return const Color(0xFF12241A);
    case PulseColor.blue:
      return const Color(0xFF13202A);
    case PulseColor.red:
      return const Color(0xFF2B1414);
    case PulseColor.gold:
    case PulseColor.amber:
      return const Color(0xFF2A2410);
  }
}

// =====================================================================
//  Data models — Home screen, Market Pulse, Quick Actions
// =====================================================================

/// One metric card on the Market Pulse strip (gainers / losers /
/// top traded / campaigns). The chart on the card uses [points].
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
  final PulseColor color;
  final PulseColor bg;
  final List<double> points; // 0..1 series for the sparkline
}

/// Live activity tile on the Market Pulse panel.
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

/// Full payload for the Home screen Market Pulse section.
@immutable
class MarketPulseData {
  const MarketPulseData({required this.metrics, required this.activity});
  final List<MarketPulseMetric> metrics;
  final MarketPulseActivity activity;
}

/// One tile in the horizontal Quick Actions carousel on Home.
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
  final double progress; // 0..1
  final String statusText;
  final PulseColor statusColor;
  final PulseColor progressColor;
  final String imagePath;
  final bool showDot;
  final PulseColor dotColor;
}

/// One row in the "Recent updates" list under Quick Actions.
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
  final int scorePercent; // 0..100
  final PulseColor scoreColor;
  final PulseColor dotColor;
  final String imagePath;
}

/// Aggregate of the Quick Actions carousel + Recent updates list.
@immutable
class QuickActionsData {
  const QuickActionsData({required this.actions, required this.recentUpdates});
  final List<QuickAction> actions;
  final List<RecentUpdateItem> recentUpdates;
}

// =====================================================================
//  Helpers
// =====================================================================

/// Generates a deterministic 17-point sparkline in the 0..1 range.
/// Used as the visual fallback whenever the AI response is missing
/// a `points` array or returns something too short to plot.
///
/// The shape is always "alive" — visible bumps and a clear
/// direction — so two cards with different AI inputs never render
/// identically.
///
/// - [seed] controls the per-card jitter.
/// - [length] controls how many points (default 17 to match the
///   sparkline width used across the app).
/// - [direction] flips the slope: +1 climbs up, -1 falls down,
///   0 keeps the curve neutral.
List<double> generateFallbackSparkline({
  double seed = 0.5,
  int length = 17,
  double direction = 1.0,
}) {
  final rng = math.Random((seed * 1000).toInt() | 1);
  final out = <double>[];
  // Phase shift so different cards don't all peak at the same x.
  final phase = rng.nextDouble() * math.pi * 2;
  // Amplitude between 0.12..0.20 (visible but not chaotic).
  final amp = 0.12 + rng.nextDouble() * 0.08;
  // 2.5..4 oscillation bumps across the line.
  final bumps = 2.5 + rng.nextDouble() * 1.5;
  for (var i = 0; i < length; i++) {
    final t = (length == 1) ? 0.0 : i / (length - 1);
    final base = direction >= 0
        ? 0.20 + 0.60 * t
        : 0.80 - 0.60 * t;
    final wave = math.sin(t * math.pi * bumps + phase) * amp;
    final jitter = (rng.nextDouble() - 0.5) * 0.04;
    out.add((base + wave + jitter).clamp(0.05, 0.95));
  }
  return out;
}

/// Backwards-compatible alias used by older call-sites
/// (`_vibrantSparkline(...)`). Returns the same shape with default
/// direction (= +1).
List<double> vibrantSparkline({
  required int length,
  required double seed,
  double direction = 1.0,
}) =>
    generateFallbackSparkline(seed: seed, length: length, direction: direction);
