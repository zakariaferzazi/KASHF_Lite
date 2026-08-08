import 'package:flutter_test/flutter_test.dart';

import 'package:kashf_lite/services/ai/chart_axis.dart';

void main() {
  group('ChartAxis.deriveYMax', () {
    test('uses AI yMax when it is reasonably close to the data', () {
      // data peaks at 8K, AI says 9K (within 1.5x). Should be honoured.
      final y = ChartAxis.deriveYMax(aiMax: 9000, dataMax: 8000);
      // 9000 * 1.10 = 9900 -> niceCeil = 10000
      expect(y, 10000);
    });

    test('falls back to data max when AI over-estimates (3x bigger)', () {
      // data peaks at 8K, AI says 25K (3x bigger). Use data + headroom.
      final y = ChartAxis.deriveYMax(aiMax: 25000, dataMax: 8000);
      // 8000 * 1.15 = 9200 -> niceCeil = 10000
      expect(y, 10000);
    });

    test('falls back when AI yMax is 5x the data', () {
      // data peaks at 5K, AI says 25K. Collapse to data-driven.
      final y = ChartAxis.deriveYMax(aiMax: 25000, dataMax: 5000);
      // 5000 * 1.15 = 5750 -> niceCeil = 10000
      expect(y, 10000);
    });

    test('uses data when AI yMax is 0 (missing)', () {
      final y = ChartAxis.deriveYMax(aiMax: 0, dataMax: 4500);
      // 4500 * 1.15 = 5175 -> niceCeil = 10000
      expect(y, 10000);
    });

    test('handles very small data (sub-1000)', () {
      final y = ChartAxis.deriveYMax(aiMax: 0, dataMax: 120);
      // 120 * 1.15 = 138 -> niceCeil = 200
      expect(y, 200);
    });

    test('returns safe default when data max is zero or negative', () {
      expect(ChartAxis.deriveYMax(aiMax: 0, dataMax: 0), 25000);
      expect(ChartAxis.deriveYMax(aiMax: 100, dataMax: -1), 25000);
    });
  });

  group('ChartAxis.niceCeil', () {
    test('rounds to nearest 1, 2, 5, 10 multiple of the magnitude', () {
      expect(ChartAxis.niceCeil(0.7), 1);
      expect(ChartAxis.niceCeil(1.2), 2);
      expect(ChartAxis.niceCeil(3.0), 5);
      expect(ChartAxis.niceCeil(7.5), 10);
      expect(ChartAxis.niceCeil(50), 50);
    });

    test('handles big numbers', () {
      expect(ChartAxis.niceCeil(1200), 2000);
      expect(ChartAxis.niceCeil(25000), 50000);
      expect(ChartAxis.niceCeil(100000), 100000);
    });
  });

  group('ChartAxis.yAxisLabels', () {
    test('produces 6 evenly-spaced labels from 0 to yMax', () {
      final labels = ChartAxis.yAxisLabels(25000, count: 6);
      expect(labels, hasLength(6));
      expect(labels.first, '25K');
      expect(labels.last, '0');
    });

    test('formats with M suffix for >= 1M', () {
      final labels = ChartAxis.yAxisLabels(2000000, count: 4);
      expect(labels.first, '2M');
    });

    test('falls back to zeros when yMax is invalid', () {
      final labels = ChartAxis.yAxisLabels(0, count: 6);
      expect(labels.every((l) => l == '0'), isTrue);
    });
  });
}
