import 'dart:math' as math;

/// Helpers for computing a sensible Y-axis upper bound for the
/// trend chart, plus formatting compact axis labels.
///
/// Why this lives outside `market_screen.dart`:
///   * The logic is reusable (e.g. when we add line charts to
///     other screens).
///   * It is small and easy to unit-test without dragging in the
///     widget tree.
class ChartAxis {
  ChartAxis._();

  /// Computes a sensible y-axis upper bound given the AI's
  /// reported [aiMax] and the actual [dataMax] of the values.
  ///
  /// Strategy:
  ///   * If [aiMax] is non-zero and within 1.5x of [dataMax], use
  ///     it (with 10% headroom). This keeps the y-axis numbers
  ///     consistent with what the AI reported.
  ///   * Otherwise the AI over-estimated the yMax, which would
  ///     collapse the line near the bottom of the chart. In that
  ///     case we derive the yMax from the data's actual max with
  ///     15% headroom.
  ///   * Round the result up to a "nice" number (1, 2, 5, 10, 20,
  ///     50, 100, …) so the y-axis labels are clean integers.
  static double deriveYMax({
    required double aiMax,
    required double dataMax,
  }) {
    if (dataMax <= 0) return 25000;
    final aiIsReasonable = aiMax > 0 && aiMax <= dataMax * 1.5;
    final raw = aiIsReasonable ? aiMax * 1.10 : dataMax * 1.15;
    return niceCeil(raw);
  }

  /// Returns the smallest "nice" number >= [v] (1, 2, 5, 10, 20,
  /// 50, 100, …). Keeps y-axis labels round and readable.
  static double niceCeil(double v) {
    if (v <= 0) return 1;
    final magnitude =
        math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    final normalized = v / magnitude;
    double nice;
    if (normalized <= 1) {
      nice = 1;
    } else if (normalized <= 2) {
      nice = 2;
    } else if (normalized <= 5) {
      nice = 5;
    } else {
      nice = 10;
    }
    return nice * magnitude;
  }

  /// Produces [count] evenly-spaced labels from 0 to [yMax], using
  /// the K/M suffix for >= 1000 to keep the labels compact.
  static List<String> yAxisLabels(double yMax, {int count = 6}) {
    if (yMax <= 0) return List<String>.filled(count, '0');
    String fmt(double v) {
      if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(0)}M';
      if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
      return v.toStringAsFixed(0);
    }

    return List<String>.generate(count, (i) {
      final v = yMax - (i * yMax / (count - 1));
      return fmt(v);
    });
  }
}
