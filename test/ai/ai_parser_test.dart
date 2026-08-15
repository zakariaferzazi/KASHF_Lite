import 'package:flutter_test/flutter_test.dart';

import 'package:kashf_lite/services/ai/ai_models.dart';
import 'package:kashf_lite/services/ai/ai_parser.dart';

void main() {
  group('AiParser.parseMarketPulse', () {
    test('parses full payload', () {
      final json = {
        'metrics': [
          {
            'id': 'gainers',
            'label': 'Top Gainers',
            'value': '+24%',
            'sub': 'Perfume',
            'color': 'green',
            'points': [0.1, 0.3, 0.5, 0.7, 0.9],
          },
          {
            'id': 'traded',
            'label': 'Top Traded',
            'value': '#Lattafa',
            'sub': 'Beauty',
            'color': 'blue',
            'points': [0.2, 0.4, 0.6],
          },
          {
            'id': 'losers',
            'label': 'Top Losers',
            'value': '-8%',
            'sub': 'X',
            'color': 'red',
            'points': [0.9, 0.5, 0.2],
          },
          {
            'id': 'campaigns',
            'label': 'Top Campaigns',
            'value': '12',
            'sub': 'Live',
            'color': 'gold',
            'points': [0.4, 0.6, 0.8],
          },
        ],
        'activity': {
          'title': 'Market active',
          'subtitle': 'Live snapshot',
          'alert_title': 'Trend',
          'alert_value': '+12.4%',
          'comparison_text': 'vs last week',
          'color': 'green',
          'points': [0.1, 0.5, 0.9],
        },
      };
      final data = AiParser.parseMarketPulse(json);
      expect(data.metrics, hasLength(4));
      expect(data.metrics.first.value, '+24%');
      expect(data.metrics.first.color, PulseColor.green);
      expect(data.activity.title, 'Market active');
      expect(data.activity.alertValue, '+12.4%');
    });

    test('pads missing metrics with placeholders', () {
      final data = AiParser.parseMarketPulse({'metrics': []});
      expect(data.metrics, hasLength(4));
      expect(data.metrics.first.value, '—');
    });

    test('falls back to default activity when missing', () {
      final data = AiParser.parseMarketPulse({'metrics': []});
      expect(data.activity.title, 'Market active');
      expect(data.activity.points, isNotEmpty);
    });

    test('accepts 24-point hourly sparkline', () {
      final points = List<double>.generate(24, (i) => 0.3 + 0.4 * (i % 5) / 4);
      final data = AiParser.parseMarketPulse({
        'metrics': [
          {
            'id': 'gainers',
            'label': 'Top Gainers',
            'value': '+24%',
            'sub': 'Perfume',
            'color': 'green',
            'points': points,
          },
          {
            'id': 'traded',
            'label': 'Top Traded',
            'value': 'X',
            'sub': 'X',
            'color': 'blue',
            'points': points,
          },
          {
            'id': 'losers',
            'label': 'Top Losers',
            'value': '-8%',
            'sub': 'X',
            'color': 'red',
            'points': points,
          },
          {
            'id': 'campaigns',
            'label': 'Top Campaigns',
            'value': '12',
            'sub': 'X',
            'color': 'gold',
            'points': points,
          },
        ],
        'activity': {
          'title': 'Market active',
          'subtitle': 'X',
          'alert_title': 'X',
          'alert_value': 'X',
          'comparison_text': 'X',
          'color': 'green',
          'points': points,
        },
      });
      expect(data.metrics.first.points, hasLength(24));
      expect(data.activity.points, hasLength(24));
    });
  });

  group('AiParser.parseQuickActions', () {
    test('parses actions and updates', () {
      final json = {
        'actions': List.generate(8, (i) => {
              'id': 'a_$i',
              'title': 'Item $i',
              'progress': 0.5,
              'status_text': 'Monitored',
              'status_color': 'green',
              'image_hint': 'perfume',
              'show_dot': true,
              'dot_color': 'green',
            }),
        'recent_updates': List.generate(4, (i) => {
              'id': 'u_$i',
              'title': 'Update $i',
              'price_line': 'SAR 100',
              'views_line': '128K views',
              'status_text': 'Live',
              'time_text': '2h',
              'score_percent': 80,
              'score_color': 'green',
              'dot_color': 'green',
              'image_hint': 'perfume',
            }),
      };
      final data = AiParser.parseQuickActions(json);
      expect(data.actions, hasLength(8));
      expect(data.recentUpdates, hasLength(4));
      expect(data.actions.first.progress, 0.5);
      expect(data.recentUpdates.first.scorePercent, 80);
    });

    test('clamps invalid scores', () {
      final json = {
        'actions': [],
        'recent_updates': [
          {
            'id': 'u0',
            'title': 'X',
            'score_percent': 999,
            'score_color': 'green',
            'dot_color': 'green',
          }
        ],
      };
      final data = AiParser.parseQuickActions(json);
      expect(data.recentUpdates.first.scorePercent, 100);
    });

    test('pads to 8 actions and 4 updates', () {
      final data = AiParser.parseQuickActions({});
      expect(data.actions, hasLength(8));
      expect(data.recentUpdates, hasLength(4));
    });
  });

  group('generateFallbackSparkline', () {
    test('returns 24 points by default', () {
      final s = generateFallbackSparkline();
      expect(s, hasLength(24));
    });

    test('values oscillate (not a straight line)', () {
      final s = generateFallbackSparkline();
      // Count adjacent pairs that differ by more than 0.01.
      var meaningfulChanges = 0;
      for (var i = 1; i < s.length; i++) {
        if ((s[i] - s[i - 1]).abs() > 0.01) meaningfulChanges++;
      }
      // At least half the transitions should be visible jumps.
      expect(meaningfulChanges, greaterThan(s.length ~/ 2));
    });

    test('all values stay in [0,1]', () {
      final s = generateFallbackSparkline();
      for (final v in s) {
        expect(v, inInclusiveRange(0.0, 1.0));
      }
    });
  });
}
