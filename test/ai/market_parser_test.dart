import 'package:flutter_test/flutter_test.dart';

import 'package:kashf_lite/services/ai/market_parser.dart';

void main() {
  group('MarketParser', () {
    test('parses a full payload', () {
      final json = {
        'kpis': [
          {'id': 'posts', 'label': 'Posts', 'value': '82.4K', 'sub': '24h', 'delta': '+12%', 'positive': true},
          {'id': 'tweets', 'label': 'Tweets', 'value': '12.7M', 'sub': '24h', 'delta': '+8%', 'positive': true},
          {'id': 'dominance', 'label': 'Dominance', 'value': '14%', 'sub': '24h', 'delta': '-2%', 'positive': false},
          {'id': 'activity', 'label': 'Activity', 'value': 'High', 'sub': 'Now', 'delta': '', 'positive': true},
        ],
        'sources': [
          {'name': 'News', 'fraction': 0.55, 'color': 'green'},
          {'name': 'Chats', 'fraction': 0.30, 'color': 'amber'},
          {'name': 'Social', 'fraction': 0.15, 'color': 'red'},
        ],
        'trend': {
          'y_max': 25000,
          'points': [
            {'label': 'D1', 'value': 3000},
            {'label': 'D2', 'value': 5000},
            {'label': 'D3', 'value': 8200},
            {'label': 'D4', 'value': 12000},
            {'label': 'D5', 'value': 17500},
            {'label': 'D6', 'value': 22000},
            {'label': 'D7', 'value': 24800},
          ],
        },
        'topics': [
          {
            'label': 'Brand',
            'brand': 'Lattafa',
            'change': '+12%',
            'positive': true,
            'points': [0.2, 0.5, 0.7, 0.9],
          },
          {
            'label': 'Campaign',
            'brand': 'Nike',
            'change': '+8%',
            'positive': true,
            'points': [0.1, 0.4, 0.6, 0.8],
          },
          {
            'label': 'Influencer',
            'brand': 'Dior',
            'change': '-4%',
            'positive': false,
            'points': [0.3, 0.4, 0.5, 0.6],
          },
          {
            'label': 'Launch',
            'brand': 'iPhone',
            'change': '+22%',
            'positive': true,
            'points': [0.5, 0.6, 0.7, 0.9],
          },
          {
            'label': 'Trend',
            'brand': 'TikTok',
            'change': '+9%',
            'positive': true,
            'points': [0.2, 0.3, 0.5, 0.7],
          },
        ],
        'brands': [
          {'name': 'Lattafa', 'growth': '+45%', 'positive': true, 'image_hint': 'perfume', 'domain': 'lattafa.com'},
          {'name': 'Nike', 'growth': '+32%', 'positive': true, 'image_hint': 'shoe', 'domain': 'nike.com'},
          {'name': 'Dior', 'growth': '+28%', 'positive': true, 'image_hint': 'perfume', 'domain': 'dior.com'},
          {'name': 'Starbucks', 'growth': '+24%', 'positive': true, 'image_hint': 'coffee', 'domain': 'starbucks.com'},
          {'name': 'Adidas', 'growth': '+21%', 'positive': true, 'image_hint': 'shoe', 'domain': 'adidas.com'},
        ],
        'events': [
          {
            'title': 'Lattafa trending',
            'subtitle': '4x spike',
            'time': '35m',
            'status': 'Viral',
            'status_color': 'amber',
          },
          {
            'title': 'iPhone chatter',
            'subtitle': 'Negative sentiment',
            'time': '2h',
            'status': 'Important',
            'status_color': 'green',
          },
          {
            'title': 'Adidas pulled',
            'subtitle': 'Quality recall',
            'time': '4h',
            'status': 'Banned',
            'status_color': 'red',
          },
        ],
      };
      final data = MarketParser.parse(json);
      expect(data.kpis, hasLength(4));
      expect(data.kpis.first.value, '82.4K');
      expect(data.sources, hasLength(3));
      // Fractions are normalised to sum ~ 1.0.
      final total = data.sources.fold<double>(0, (a, s) => a + s.fraction);
      expect(total, closeTo(1.0, 0.05));
      expect(data.trend, hasLength(7));
      expect(data.trendYMax, 25000);
      expect(data.topics, hasLength(5));
      expect(data.brands, hasLength(5));
      expect(data.events, hasLength(3));
      expect(data.events.first.statusColorName, 'amber');
      expect(data.brands[1].domain, 'nike.com');
    });

    test('cleans up the brand domain (strips scheme/www/path/port)', () {
      final data = MarketParser.parse({
        'brands': [
          {'name': 'A', 'growth': '+1%', 'positive': true, 'image_hint': 'x', 'domain': 'https://www.starbucks.com/menu?foo=1#bar'},
          {'name': 'B', 'growth': '+2%', 'positive': true, 'image_hint': 'x', 'domain': 'HTTP://nike.com:8080/'},
          {'name': 'C', 'growth': '+3%', 'positive': true, 'image_hint': 'x'},
          {'name': 'D', 'growth': '+4%', 'positive': true, 'image_hint': 'x', 'domain': 'not a domain'},
          {'name': 'E', 'growth': '+5%', 'positive': true, 'image_hint': 'x', 'domain': ''},
        ],
      });
      expect(data.brands[0].domain, 'starbucks.com');
      expect(data.brands[1].domain, 'nike.com');
      expect(data.brands[2].domain, isNull);
      expect(data.brands[3].domain, isNull);
      expect(data.brands[4].domain, isNull);
    });

    test('Arabic-script domains are rejected (no transliteration)', () {
      // The prompt tells the AI to ALWAYS return ASCII domains.
      // We validate this strictly — Arabic-script domains are
      // rejected and the screen falls back to the bundled asset.
      final data = MarketParser.parse({
        'brands': [
          {'name': 'ستاربكس', 'growth': '+24%', 'positive': true, 'image_hint': 'coffee', 'domain': 'starbucks.com'},
          {'name': 'نايكي', 'growth': '+30%', 'positive': true, 'image_hint': 'shoe', 'domain': 'نايكي.com'},
          {'name': 'ديور', 'growth': '+45%', 'positive': true, 'image_hint': 'perfume'},
          {'name': 'لطافة', 'growth': '+20%', 'positive': true, 'image_hint': 'perfume'},
        ],
      });
      // Good: explicit ASCII domain survives.
      expect(data.brands[0].domain, 'starbucks.com');
      // Bad: Arabic domain is rejected, not transliterated.
      expect(data.brands[1].domain, isNull);
      // Missing: stays null so the bundled asset renders.
      expect(data.brands[2].domain, isNull);
      expect(data.brands[3].domain, isNull);
    });

    test('does NOT derive a domain by appending .com to the brand name', () {
      // Regression: an earlier version tried to fabricate a
      // domain from the brand name. That produced broken URLs
      // for every brand whose name wasn't already a hostname.
      final data = MarketParser.parse({
        'brands': [
          {'name': 'Lattafa', 'growth': '+20%', 'positive': true, 'image_hint': 'perfume'},
          {'name': 'Oud Satin', 'growth': '+15%', 'positive': true, 'image_hint': 'perfume'},
        ],
      });
      expect(data.brands[0].domain, isNull);
      expect(data.brands[1].domain, isNull);
    });

    test('pads missing kpi entries with defaults', () {
      final data = MarketParser.parse({'kpis': []});
      expect(data.kpis, hasLength(4));
      expect(data.kpis.first.id, 'posts');
      expect(data.kpis.last.id, 'activity');
    });

    test('falls back to demo donut when sources missing', () {
      final data = MarketParser.parse({});
      expect(data.sources, hasLength(3));
      expect(data.sources.first.name, 'News');
    });

    test('falls back to demo trend when trend missing', () {
      final data = MarketParser.parse({});
      expect(data.trend, isNotEmpty);
      expect(data.trendYMax, 25000);
    });

    test('falls back to demo topics / brands / events when missing', () {
      final data = MarketParser.parse({});
      expect(data.topics, hasLength(5));
      expect(data.brands, hasLength(5));
      expect(data.events, hasLength(3));
    });

    test('clamps out-of-range fractions into [0,1]', () {
      final data = MarketParser.parse({
        'sources': [
          {'name': 'A', 'fraction': 1.8, 'color': 'green'},
          {'name': 'B', 'fraction': -0.2, 'color': 'amber'},
          {'name': 'C', 'fraction': 0.3, 'color': 'red'},
        ],
      });
      for (final s in data.sources) {
        expect(s.fraction, inInclusiveRange(0.0, 1.0));
      }
    });
  });
}
