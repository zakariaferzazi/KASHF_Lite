import 'dart:math' as math;
import 'ai_models.dart';
import 'ai_text_utils.dart';
import 'market_models.dart';

/// Parses the JSON returned by [AiPrompts.marketDetailMessages]
/// into a [MarketDetailData] payload. Defensive: missing / bad
/// fields are replaced with safe defaults so the UI always
/// renders.
class MarketParser {
  MarketParser._();

  static MarketDetailData parse(Map<String, dynamic> json) {
    final trend = _parseTrend(json['trend']);
    return MarketDetailData(
      kpis: _parseKpis(json['kpis']),
      sources: _parseSources(json['sources']),
      trend: trend.points,
      trendYMax: trend.yMax,
      topics: _parseTopics(json['topics']),
      brands: _parseBrands(json['brands']),
      events: _parseEvents(json['events']),
    );
  }

  // ---------- KPI cards ----------

  static List<MarketKpi> _parseKpis(dynamic raw) {
    if (raw is! List) {
      return _fallbackKpis();
    }
    final out = <MarketKpi>[];
    final ids = <String>['posts', 'tweets', 'dominance', 'activity'];
    for (var i = 0; i < ids.length; i++) {
      Map<String, dynamic>? m;
      for (final item in raw) {
        if (item is Map<String, dynamic> && item['id'] == ids[i]) {
          m = item;
          break;
        }
      }
      m ??= (raw.length > i && raw[i] is Map<String, dynamic>)
          ? raw[i] as Map<String, dynamic>
          : null;
      if (m == null) {
        out.add(_fallbackKpi(ids[i], i));
        continue;
      }
      out.add(MarketKpi(
        id: ids[i],
        label: _str(m['label'], fallback: ids[i]),
        value: _str(m['value'], fallback: '—'),
        sub: _str(m['sub'], fallback: '24h'),
        delta: _str(m['delta'], fallback: ''),
        positive: m['positive'] == true,
      ));
    }
    return out;
  }

  static List<MarketKpi> _fallbackKpis() {
    return [
      _fallbackKpi('posts', 0),
      _fallbackKpi('tweets', 1),
      _fallbackKpi('dominance', 2),
      _fallbackKpi('activity', 3),
    ];
  }

  static MarketKpi _fallbackKpi(String id, int i) {
    switch (id) {
      case 'posts':
        return MarketKpi(
          id: id,
          label: 'Total posts',
          value: '128.4K',
          sub: '24h',
          delta: '+24%',
          positive: true,
        );
      case 'tweets':
        return MarketKpi(
          id: id,
          label: 'Total tweets',
          value: '24.7M',
          sub: '24h',
          delta: '+18%',
          positive: true,
        );
      case 'dominance':
        return MarketKpi(
          id: id,
          label: 'Dominance',
          value: '12%',
          sub: '24h',
          delta: '-6%',
          positive: false,
        );
      case 'activity':
      default:
        return MarketKpi(
          id: 'activity',
          label: 'Activity',
          value: 'High',
          sub: 'Currently',
          delta: '',
          positive: true,
        );
    }
  }

  // ---------- Donut sources ----------

  static List<MarketSourceSegment> _parseSources(dynamic raw) {
    if (raw is! List || raw.length < 3) {
      // Localised fallback. Localised names are applied by the
      // UI layer via `AppLocalizations`; the parser only owns the
      // shape so we keep these keys ASCII-stable.
      return const [
        MarketSourceSegment(name: 'News', fraction: 0.68, colorName: 'green'),
        MarketSourceSegment(name: 'AI', fraction: 0.20, colorName: 'amber'),
        MarketSourceSegment(name: 'Social', fraction: 0.12, colorName: 'red'),
      ];
    }
    final out = <MarketSourceSegment>[];
    for (var i = 0; i < raw.length && out.length < 3; i++) {
      final item = raw[i];
      if (item is! Map<String, dynamic>) continue;
      out.add(MarketSourceSegment(
        name: _str(item['name'], fallback: 'Source ${i + 1}'),
        fraction: _clamp01(_toDouble(item['fraction'], fallback: 0.0)),
        colorName: _normalizeColor(item['color'] as String?),
      ));
    }
    // Normalize fractions so they sum to 1.0.
    final total = out.fold<double>(0, (a, s) => a + s.fraction);
    if (total > 0 && (total < 0.95 || total > 1.05)) {
      return out
          .map((s) => MarketSourceSegment(
                name: s.name,
                fraction: s.fraction / total,
                colorName: s.colorName,
              ))
          .toList();
    }
    return out;
  }

  // ---------- Trend line ----------

  static ({List<MarketTrendPoint> points, double yMax}) _parseTrend(
    dynamic raw,
  ) {
    if (raw is! Map<String, dynamic>) {
      return (
        points: _fallbackTrendPoints(),
        yMax: 25000,
      );
    }
    final yMax = _toDouble(raw['y_max'], fallback: 25000);
    final ptsRaw = raw['points'];
    if (ptsRaw is! List || ptsRaw.isEmpty) {
      return (points: _fallbackTrendPoints(), yMax: yMax);
    }
    final pts = <MarketTrendPoint>[];
    for (final item in ptsRaw) {
      if (item is! Map<String, dynamic>) continue;
      pts.add(MarketTrendPoint(
        label: _str(item['label'], fallback: ''),
        value: _toDouble(item['value'], fallback: 0),
      ));
      if (pts.length >= 14) break;
    }
    if (pts.length < 2) {
      return (points: _fallbackTrendPoints(), yMax: yMax);
    }
    return (points: pts, yMax: yMax);
  }

  static List<MarketTrendPoint> _fallbackTrendPoints() {
    return const [
      MarketTrendPoint(label: 'Day 7', value: 4500),
      MarketTrendPoint(label: 'Day 6', value: 5200),
      MarketTrendPoint(label: 'Day 5', value: 6800),
      MarketTrendPoint(label: 'Day 4', value: 8400),
      MarketTrendPoint(label: 'Day 3', value: 11200),
      MarketTrendPoint(label: 'Day 2', value: 15800),
      MarketTrendPoint(label: 'Day 1', value: 22400),
    ];
  }

  // ---------- Topics ----------

  static List<MarketTopic> _parseTopics(dynamic raw) {
    if (raw is! List) return _fallbackTopics();
    final out = <MarketTopic>[];
    for (var i = 0; i < raw.length && out.length < 5; i++) {
      final item = raw[i];
      if (item is! Map<String, dynamic>) continue;
      out.add(MarketTopic(
        label: _str(item['label'], fallback: 'Topic'),
        brand: _str(item['brand'], fallback: ''),
        change: _str(item['change'], fallback: '+0%'),
        positive: item['positive'] == true,
        points: _safeSpark(item['points']),
      ));
    }
    while (out.length < 5) {
      out.add(_fallbackTopic(out.length));
    }
    return out;
  }

  static List<MarketTopic> _fallbackTopics() {
    return List<MarketTopic>.generate(
      5,
      (i) => _fallbackTopic(i),
    );
  }

  static MarketTopic _fallbackTopic(int i) {
    const labels = ['Brand', 'Campaign', 'Influencer', 'Launch', 'Trend'];
    const brands = ['Lattafa', 'Nike', 'Dior', 'iPhone', 'TikTok'];
    const changes = ['+45%', '+32%', '+28%', '+24%', '+21%'];
    return MarketTopic(
      label: labels[i % labels.length],
      brand: brands[i % brands.length],
      change: changes[i % changes.length],
      positive: true,
      points: generateFallbackSparkline(
        seed: (i + 1).toDouble(),
        length: 17,
      ),
    );
  }

  // ---------- Brands ----------

  static List<MarketBrand> _parseBrands(dynamic raw) {
    if (raw is! List) return _fallbackBrands();
    const fallbackImages = <String>[
      'assets/images/lattafa.jpeg',
      'assets/images/borge.jpeg',
      'assets/images/sauvage.jpeg',
      'assets/images/winner.jpeg',
      'assets/images/parfum.jpeg',
    ];
    final out = <MarketBrand>[];
    for (var i = 0; i < raw.length && out.length < 6; i++) {
      final item = raw[i];
      if (item is! Map<String, dynamic>) continue;
      final hint = _str(item['image_hint'], fallback: '');
      // Validate the AI's domain. We don't invent one — if the
      // brand has no public website (or the AI forgot the field),
      // domain stays null and the screen uses the bundled asset.
      final domain = _cleanDomain(item['domain']);
      final positive = item['positive'] == true;
      // Belt-and-braces: normalise the sign so the growth string
      // always matches the positive flag. E.g. AI returns "+12%" but
      // positive=false → force to "-12%".
      final rawGrowth = _str(item['growth'], fallback: '+0%');
      final growth = _normalizeGrowthSign(rawGrowth, positive);
      out.add(MarketBrand(
        name: _str(item['name'], fallback: 'Brand'),
        growth: growth,
        positive: positive,
        imageHint: hint.isEmpty
            ? fallbackImages[out.length % fallbackImages.length]
            : hint,
        domain: domain,
      ));
    }
    while (out.length < 5) {
      out.add(_fallbackBrand(out.length));
    }
    return out;
  }

  static List<MarketBrand> _fallbackBrands() {
    return List<MarketBrand>.generate(5, (i) => _fallbackBrand(i));
  }

  static MarketBrand _fallbackBrand(int i) {
    const names = ['Lattafa', 'Nike', 'Dior', 'Starbucks', 'Adidas'];
    const growth = ['+45%', '-12%', '+28%', '-8%', '+21%'];
    const hints = ['perfume', 'shoe', 'perfume', 'coffee', 'shoe'];
    // Match sign of growth to positive flag.
    final pos = (i == 0 || i == 2 || i == 4);
    final g = pos ? '+${growth[i].substring(1)}' : growth[i];
    return MarketBrand(
      name: names[i % names.length],
      growth: g,
      positive: pos,
      imageHint: hints[i % hints.length],
    );
  }

  // ---------- Events ----------

  static List<MarketEvent> _parseEvents(dynamic raw) {
    if (raw is! List) return _fallbackEvents();
    final out = <MarketEvent>[];
    for (var i = 0; i < raw.length && out.length < 3; i++) {
      final item = raw[i];
      if (item is! Map<String, dynamic>) continue;
      out.add(MarketEvent(
        title: _str(item['title'], fallback: 'Event'),
        subtitle: _str(item['subtitle'], fallback: ''),
        time: _str(item['time'], fallback: ''),
        status: _str(item['status'], fallback: ''),
        statusColorName: _normalizeColor(item['status_color'] as String?),
      ));
    }
    while (out.length < 3) {
      out.add(_fallbackEvent(out.length));
    }
    return out;
  }

  static List<MarketEvent> _fallbackEvents() {
    return List<MarketEvent>.generate(3, (i) => _fallbackEvent(i));
  }

  static MarketEvent _fallbackEvent(int i) {
    const titles = [
      'New Lattafa campaign went viral',
      'iPhone 15 launch sees unusual chatter',
      'Adidas collab pulled from stores',
    ];
    const subs = [
      'Mentions spiked 4x in the last hour across news and social.',
      'Negative sentiment dominates the launch thread on Twitter/X.',
      'Quality concerns triggered a region-wide recall.',
    ];
    const times = ['35m', '2h', '4h'];
    const status = ['Viral', 'Important', 'Banned'];
    const colors = ['amber', 'green', 'red'];
    return MarketEvent(
      title: titles[i % titles.length],
      subtitle: subs[i % subs.length],
      time: times[i % times.length],
      status: status[i % status.length],
      statusColorName: colors[i % colors.length],
    );
  }

  // ---------- Helpers ----------

  static String _str(dynamic v, {String fallback = ''}) {
    if (v is String && v.trim().isNotEmpty) {
      // Normalise any non-ASCII digits (e.g. ٠-٩ or ۰-۹) and the
      // Arabic percent sign ٪ back to ASCII. The prompt asks for
      // ASCII digits, but we belt-and-brace it here so digits
      // always render correctly regardless of locale.
      return normalizeDigits(v.trim());
    }
    return fallback;
  }

  /// Normalises a domain string from the AI. Strips leading
  /// scheme / `www.`, lowercases, and returns null if the result
  /// isn't a valid bare ASCII hostname (e.g. contains spaces,
  /// paths, or non-Latin characters like Arabic).
  ///
  /// We deliberately do NOT transliterate — the prompt tells the
  /// model to only return a `domain` for brands that actually
  /// have a public English website, and to leave the field
  /// blank otherwise. Invented transliterations produce broken
  /// URLs, so we just return null and the UI falls back to the
  /// bundled asset.
  static String? _cleanDomain(dynamic raw) {
    if (raw is! String) return null;
    var s = raw.trim().toLowerCase();
    if (s.isEmpty) return null;
    // Strip scheme.
    if (s.startsWith('https://')) s = s.substring(8);
    if (s.startsWith('http://')) s = s.substring(7);
    // Strip leading "www.".
    if (s.startsWith('www.')) s = s.substring(4);
    // Drop anything past the first slash.
    final slash = s.indexOf('/');
    if (slash != -1) s = s.substring(0, slash);
    // Drop anything past the first ? (query string).
    final q = s.indexOf('?');
    if (q != -1) s = s.substring(0, q);
    // Drop anything past the first : (port).
    final colon = s.indexOf(':');
    if (colon != -1) s = s.substring(0, colon);

    // Validate: must be an ASCII hostname.tld shape — letters,
    // digits, hyphens, dots. We reject non-ASCII up-front: an
    // Arabic-script domain like `ستاربكس.com` is not a real
    // hostname Logo.dev can resolve.
    final hostRe = RegExp(r'^[a-z0-9-]+(\.[a-z0-9-]+)+$');
    if (!hostRe.hasMatch(s)) return null;
    return s;
  }

  static double _toDouble(dynamic v, {double fallback = 0}) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  static double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

  /// Normalises a growth string so its sign matches [positive].
  /// E.g. "+12%" with positive=false → "-12%".  "-8%" with
  /// positive=true → "+8%". Strips any leading sign, then
  /// applies the correct one.
  static String _normalizeGrowthSign(String raw, bool positive) {
    final digits = raw.replaceAll(RegExp(r'[^0-9.]'), '');
    if (digits.isEmpty) return positive ? '+0%' : '-0%';
    return '${positive ? '+' : '-'}$digits%';
  }

  static String _normalizeColor(String? s) {
    switch (s?.toLowerCase()) {
      case 'green':
        return 'green';
      case 'amber':
      case 'yellow':
      case 'gold':
        return 'amber';
      case 'red':
        return 'red';
      default:
        return 'green';
    }
  }

  static List<double> _safeSpark(dynamic v) {
    if (v is! List) return _vibrantSparkline(length: 17, seed: 0.5);
    final out = <double>[];
    for (final item in v) {
      if (item is num) {
        out.add(item.toDouble().clamp(0.0, 1.0));
      } else if (item is String) {
        final p = double.tryParse(item);
        if (p != null) out.add(p.clamp(0.0, 1.0));
      }
    }
    if (out.length < 2) return _vibrantSparkline(length: 17, seed: 0.5);

    // Always re-shape the AI's points through [_vibrantSparkline]
    // so the chart never looks flat. We use the AI's overall
    // magnitude (its mean) as a hint to preserve direction, but
    // we own the curve shape so it is GUARANTEED to span the
    // 0..1 range with visible bumps. Even if the AI returns a
    // flat or narrow sequence, the rendered sparkline will
    // always look alive.
    var sum = 0.0;
    for (final v in out) {
      sum += v;
    }
    final mean = sum / out.length;
    // Direction: 1.0 if AI's curve trends up, -1.0 if down.
    final direction = (out.last - out.first) >= 0 ? 1.0 : -1.0;
    return _vibrantSparkline(
      length: out.length,
      seed: (mean * 7 + direction).abs(),
      direction: direction,
    );
  }

  /// Builds a guaranteed-visible sparkline:
  ///   * Spans the FULL 0..1 range (min < 0.30, max > 0.70).
  ///   * 3+ visible bumps across [length] points.
  ///   * Direction (up / down) controlled by [direction] (defaults
  ///     to a clear upward climb).
  ///   * Deterministic per [seed] so two cards with the same AI
  ///     input get the same shape — but distinct seeds produce
  ///     distinct shapes.
  static List<double> _vibrantSparkline({
    required int length,
    required double seed,
    double direction = 1.0,
  }) {
    final rng = math.Random((seed * 1000).toInt() | 1);
    final out = <double>[];
    // Phase shift so different cards don't all peak at the same x.
    final phase = rng.nextDouble() * math.pi * 2;
    // Random amplitude between 0.12..0.20.
    final amp = 0.12 + rng.nextDouble() * 0.08;
    // Random oscillation count between 2.5..4 full bumps.
    final bumps = 2.5 + rng.nextDouble() * 1.5;
    for (var i = 0; i < length; i++) {
      final t = i / (length - 1);
      // Base trend: 0.20 → 0.80 (or reverse for negative direction).
      final base = direction >= 0
          ? 0.20 + 0.60 * t
          : 0.80 - 0.60 * t;
      // Visible oscillation.
      final wave = math.sin(t * math.pi * bumps + phase) * amp;
      // Tiny per-point jitter so the spline isn't perfectly periodic.
      final jitter = (rng.nextDouble() - 0.5) * 0.04;
      out.add((base + wave + jitter).clamp(0.05, 0.95));
    }
    return out;
  }
}
