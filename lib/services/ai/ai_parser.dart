import 'ai_models.dart';

/// Parses the JSON payloads returned by the OpenRouter client into
/// the strongly-typed models used by the UI. Each parser is
/// defensive: if the model returns malformed data we fall back to
/// safe defaults so the home screen always renders.
class AiParser {
  AiParser._();

  /// Parse the Market Pulse response. Returns a populated
  /// [MarketPulseData] or throws a [FormatException] if the input
  /// is unusable.
  static MarketPulseData parseMarketPulse(Map<String, dynamic> json) {
    final metricsRaw = json['metrics'];
    if (metricsRaw is! List) {
      throw const FormatException('MarketPulse: "metrics" must be a list');
    }

    final metrics = <MarketPulseMetric>[];
    for (var i = 0; i < metricsRaw.length && metrics.length < 4; i++) {
      final m = metricsRaw[i];
      if (m is! Map<String, dynamic>) continue;
      metrics.add(MarketPulseMetric(
        id: (m['id'] as String?) ?? 'm_$i',
        label: _safeString(m['label'], fallback: 'Metric'),
        value: _safeString(m['value'], fallback: '—'),
        sub: _safeString(m['sub']),
        color: pulseColorFromString(m['color'] as String?),
        bg: pulseColorFromString(m['color'] as String?),
        points: _safePoints(m['points']),
      ));
    }

    // If the model returned fewer than 4 metrics, pad with
    // placeholders so the grid always renders 4 columns.
    while (metrics.length < 4) {
      metrics.add(MarketPulseMetric(
        id: 'placeholder_${metrics.length}',
        label: '—',
        value: '—',
        sub: '',
        color: PulseColor.blue,
        bg: PulseColor.blue,
        points: generateFallbackSparkline(seed: metrics.length.toDouble()),
      ));
    }

    final activityRaw = json['activity'];
    MarketPulseActivity activity;
    if (activityRaw is Map<String, dynamic>) {
      activity = MarketPulseActivity(
        title: _safeString(activityRaw['title'], fallback: 'Market active'),
        subtitle: _safeString(activityRaw['subtitle']),
        alertTitle: _safeString(activityRaw['alert_title']),
        alertValue: _safeString(activityRaw['alert_value']),
        comparisonText: _safeString(activityRaw['comparison_text']),
        color: pulseColorFromString(activityRaw['color'] as String?),
        points: _safePoints(activityRaw['points']),
      );
    } else {
      activity = MarketPulseActivity(
        title: 'Market active',
        subtitle: 'Live data',
        alertTitle: 'Trend',
        alertValue: '—',
        comparisonText: '',
        color: PulseColor.green,
        points: generateFallbackSparkline(),
      );
    }

    return MarketPulseData(metrics: metrics, activity: activity);
  }

  /// Parse the Quick Actions + Recent Updates response.
  static QuickActionsData parseQuickActions(Map<String, dynamic> json) {
    final actionsRaw = json['actions'];
    final actions = <QuickAction>[];
    if (actionsRaw is List) {
      for (var i = 0; i < actionsRaw.length; i++) {
        final a = actionsRaw[i];
        if (a is! Map<String, dynamic>) continue;
        final id = (a['id'] as String?) ?? 'action_$i';
        final progress = _safeDouble(a['progress'], fallback: 0.5);
        final color = pulseColorFromString(a['status_color'] as String?);
        final dotColor = pulseColorFromString(a['dot_color'] as String?);
        final imageHint = (a['image_hint'] as String?) ?? '';
        actions.add(QuickAction(
          id: id,
          title: _safeString(a['title'], fallback: 'Action'),
          progress: progress.clamp(0.0, 1.0),
          statusText: _safeString(a['status_text']),
          statusColor: color,
          progressColor: color,
          imagePath: _imageForHint(imageHint),
          showDot: a['show_dot'] == true,
          dotColor: dotColor,
        ));
        if (actions.length >= 8) break;
      }
    }

    // Pad up to 8 cards so the carousel scrollbar is consistent.
    final fallbackImages = <String>[
      'assets/images/parfum.jpeg',
      'assets/images/borge.jpeg',
      'assets/images/winner.jpeg',
      'assets/images/sauvage.jpeg',
      'assets/images/lattafa.jpeg',
    ];
    while (actions.length < 8) {
      final i = actions.length;
      final colors = PulseColor.values;
      final c = colors[i % colors.length];
      actions.add(QuickAction(
        id: 'placeholder_$i',
        title: '—',
        progress: 0.5,
        statusText: '—',
        statusColor: c,
        progressColor: c,
        imagePath: fallbackImages[i % fallbackImages.length],
        showDot: i.isEven,
        dotColor: c,
      ));
    }

    final updatesRaw = json['recent_updates'];
    final updates = <RecentUpdateItem>[];
    if (updatesRaw is List) {
      for (var i = 0; i < updatesRaw.length && updates.length < 4; i++) {
        final u = updatesRaw[i];
        if (u is! Map<String, dynamic>) continue;
        final color = pulseColorFromString(u['score_color'] as String?);
        final dot = pulseColorFromString(u['dot_color'] as String?);
        final score = _safeDouble(u['score_percent'], fallback: 50).toInt();
        updates.add(RecentUpdateItem(
          id: (u['id'] as String?) ?? 'update_$i',
          title: _safeString(u['title'], fallback: 'Update'),
          priceLine: _safeString(u['price_line']),
          viewsLine: _safeString(u['views_line']),
          statusText: _safeString(u['status_text']),
          timeText: _safeString(u['time_text']),
          scorePercent: score.clamp(0, 100),
          scoreColor: color,
          dotColor: dot,
          imagePath: _imageForHint((u['image_hint'] as String?) ?? ''),
        ));
      }
    }

    while (updates.length < 4) {
      final i = updates.length;
      final c = PulseColor.values[i % PulseColor.values.length];
      updates.add(RecentUpdateItem(
        id: 'placeholder_$i',
        title: '—',
        priceLine: '',
        viewsLine: '',
        statusText: '—',
        timeText: '',
        scorePercent: 50,
        scoreColor: c,
        dotColor: c,
        imagePath: fallbackImages[i % fallbackImages.length],
      ));
    }

    return QuickActionsData(actions: actions, recentUpdates: updates);
  }

  // ---------- Helpers ----------

  static String _safeString(dynamic v, {String fallback = ''}) {
    if (v is String && v.trim().isNotEmpty) return v.trim();
    return fallback;
  }

  static double _safeDouble(dynamic v, {double fallback = 0}) {
    if (v is num) return v.toDouble();
    if (v is String) {
      return double.tryParse(v) ?? fallback;
    }
    return fallback;
  }

  static List<double> _safePoints(dynamic v) {
    if (v is! List) return generateFallbackSparkline();
    final result = <double>[];
    for (final item in v) {
      if (item is num) {
        result.add(item.toDouble().clamp(0.0, 1.0));
      } else if (item is String) {
        final p = double.tryParse(item);
        if (p != null) result.add(p.clamp(0.0, 1.0));
      }
    }
    if (result.length < 2) return generateFallbackSparkline();
    // Cap at a reasonable upper bound to avoid runaway JSON.
    if (result.length > 64) return result.sublist(result.length - 64);
    return result;
  }

  /// Maps an image hint to a built-in asset. We use a small
  /// whitelist so we never try to load an image that does not
  /// exist in the bundle.
  static const Map<String, String> _hintToAsset = <String, String>{
    'perfume': 'assets/images/parfum.jpeg',
    'parfum': 'assets/images/parfum.jpeg',
    'brand': 'assets/images/borge.jpeg',
    'winner': 'assets/images/winner.jpeg',
    'sauvage': 'assets/images/sauvage.jpeg',
    'lattafa': 'assets/images/lattafa.jpeg',
    'phone': 'assets/images/sauvage.jpeg',
    'shoe': 'assets/images/borge.jpeg',
    'adidas': 'assets/images/borge.jpeg',
    'tiktok': 'assets/images/winner.jpeg',
    'starbucks': 'assets/images/sauvage.jpeg',
    'iphone': 'assets/images/sauvage.jpeg',
  };

  static String _imageForHint(String hint) {
    final key = hint.toLowerCase().trim();
    for (final entry in _hintToAsset.entries) {
      if (key.contains(entry.key)) return entry.value;
    }
    return 'assets/images/parfum.jpeg';
  }
}
