import 'dart:math' as math;
import 'openrouter_client.dart';

/// Prompt templates for the dashboard's AI-driven sections.
///
/// Design notes:
///  * We do NOT mention the product brand in the system prompt —
///    the model has no prior knowledge of it, and brand-coloured
///    wording adds nothing to the response quality.
///  * We pass the user's [region] in plain language ("Kuwait",
///    "Saudi Arabia", etc.) so the model can pick locally
///    relevant brands, currencies, and examples.
///  * Sparkline points cover a short time window (last 24h,
///    one sample per hour). Shorter windows make the line look
///    like a real chart, not a near-straight line.
class AiPrompts {
  AiPrompts._();

  /// System prompt used for every Market Pulse request. We force
  /// the model to return JSON in the exact schema the UI expects.
  static String marketPulseSystemPrompt({
    required String language,
    required String region,
  }) {
    return '''
You are a market analyst focused on the brand-investigation
domain (perfume, beauty, fashion, electronics, social-media
campaigns). Produce a JSON snapshot for a user's homepage
dashboard. Return STRICT JSON only — no commentary, no markdown
fences, no trailing prose.

Region: $region. Prefer brands, currencies, and examples that
are locally relevant to $region (e.g. use the local currency in
strings, mention brands and trends common there).

Language: $language. ALL string values must be in $language.

Schema:
{
  "metrics": [
    {
      "id": "gainers" | "traded" | "losers" | "campaigns",
      "label": string,             // e.g. "Top Gainers", "Most active"
      "value": string,             // e.g. "+24%" or "#Lattafa"
      "sub": string,               // short subtitle, <= 18 chars
      "color": "green" | "blue" | "red" | "gold",
      "points": [number, ...]      // exactly 24 normalized 0..1 sparkline
                                   // values, one per hour for the last 24h
    },
    ... 4 entries in the order: gainers, traded, losers, campaigns
  ],
  "activity": {
    "title": string,
    "subtitle": string,
    "alert_title": string,
    "alert_value": string,         // e.g. "+12.4%"
    "comparison_text": string,     // e.g. "vs last week"
    "color": "green" | "blue" | "red" | "gold",
    "points": [number, ...]        // exactly 24 normalized 0..1 values
                                   // (last 24 hours, hourly samples)
  }
}

Rules:
  * Sparkline timeframe is the LAST 24 HOURS, one sample per
    hour — 24 points total. Make the line clearly undulating
    (clear ups and downs, not a flat line). The closer the
    time, the more recent — last point = now.
  * Use 0..1 floats. Values should NOT be monotonically
    increasing or decreasing — they should oscillate like a
    real intraday trend.
  * Keep "label" and "sub" short and concrete.
  * Pick the dominant color for each metric: gainers=green,
    traded=blue, losers=red, campaigns=gold.
  * Return ONLY JSON. No prose around the JSON.

Variety — IMPORTANT:
  * DO NOT return the same demo numbers every time. The user
    refreshes the dashboard and expects DIFFERENT values each
    fetch. Pick plausible but VARIED numbers for "value":
    gainers anywhere in +5% to +60%, losers anywhere in -5%
    to -40%, traded should be a #hashtag or KWD amount (not
    the same one each time), campaigns an integer between
    3 and 25.
  * Pick DIFFERENT brand / product names for "sub" each fetch
    (e.g. Lattafa, Oud Satin, Bvlgari, Adidas, iPhone, Dior,
    Starbucks, TikTok, Shein, Nivea, etc.).
  * The sparkline shapes must be DIFFERENT across the 4
    metrics — they are not the same chart.

Hashtags / brand names — IMPORTANT:
  * When language is Arabic, ALL hashtag and brand strings
    (the "value" field for `traded`, the "sub" field, and
    brand / item titles elsewhere) MUST be written in Arabic
    script. Do NOT mix English letters inside Arabic strings.
  * Examples for Arabic:
      "#لاتافا" "#ديور" "#بفلقاري" "#شيك" "#ستاربكس"
      "للطافة" "عطر جديد" "حملة جديدة"
  * Examples for English:
      "#Lattafa" "#Dior" "New launch" "Summer campaign"
  * If you produce a hashtag, always prefix it with "#" using
    the same script as the language (Arabic # followed by
    Arabic letters, English # followed by Latin letters).
  * Numbers and currency codes may stay in ASCII (e.g. "+24%",
    "KWD 482K") even inside Arabic strings.
''';
  }

  /// Builds the user-side prompt for Market Pulse. We keep it
  /// generic so the AI can pick the most relevant data.
  static List<OpenRouterMessage> marketPulseMessages({
    required String language,
    required String region,
    int? nonce,
    String? userQuery,
  }) {
    final userText = userQuery ??
        'Generate a fresh market pulse snapshot for the homepage. '
            'Use the brand-investigation domain (perfume, beauty, '
            'fashion, electronics, social-media campaigns) and prefer '
            'brands and trends relevant to $region. The trend line '
            'must cover the last 24 hours with hourly samples. '
            'All strings must be in $language.'
            '${nonce != null ? ' Fetch #$nonce — produce NEW values, do not repeat prior fetches.' : ''}';
    return [
      OpenRouterMessage(
        role: 'system',
        content: marketPulseSystemPrompt(
          language: language,
          region: region,
        ),
      ),
      OpenRouterMessage(
        role: 'user',
        content: PromptSanitizer.sanitize(userText),
      ),
    ];
  }

  /// System prompt for the Quick Actions grid.
  static String quickActionsSystemPrompt({
    required String language,
    required String region,
  }) {
    return '''
You are a recommender for a brand-investigation dashboard.
Produce a JSON payload describing the quick actions shown on
the user homepage. Return STRICT JSON only — no commentary,
no markdown fences, no trailing prose.

Region: $region. Prefer brands and products that are locally
relevant to $region.

Language: $language. ALL string values must be in $language.

Schema:
{
  "actions": [
    {
      "id": string,                  // slug, unique
      "title": string,               // short, <= 22 chars
      "progress": number,            // 0..1
      "status_text": string,         // e.g. "Monitored", "Analyzing"
      "status_color": "green" | "orange" | "red" | "blue",
      "image_hint": string,          // short noun, e.g. "perfume", "phone"
      "show_dot": boolean,
      "dot_color": "green" | "orange" | "red" | "blue"
    },
    ... exactly 8 entries
  ],
  "recent_updates": [
    {
      "id": string,
      "title": string,
      "price_line": string,          // e.g. "KWD 482K" (local currency)
      "views_line": string,          // e.g. "128K views"
      "status_text": string,
      "time_text": string,           // e.g. "2h"
      "score_percent": number,       // 0..100
      "score_color": "green" | "blue" | "orange" | "red",
      "dot_color": "green" | "blue" | "orange" | "red",
      "image_hint": string
    },
    ... 4 entries
  ]
}

Rules:
  * Keep titles and lines very short — they render on small
    cards. Aim for <= 18 chars on titles, <= 12 chars on
    status_text and time_text.
  * status_color/dot_color MUST match for the same item.
  * Use the local currency for $region in price_line values.
  * Keep the entire response under 2000 tokens so the JSON
    is not truncated.
  * Return ONLY JSON.

Variety — IMPORTANT:
  * The user refreshes the dashboard and expects DIFFERENT
    content each fetch. Do NOT repeat the same brands,
    percentages, view counts, or time strings every time.
  * Spread the 8 actions across AT LEAST 6 distinct brands
    (perfume, beauty, fashion, electronics, social-media
    campaigns) and VARY the titles each fetch.
  * Vary progress values (e.g. 0.18 to 0.95), status_text
    ("Monitored", "Analyzing", "Collecting", "New updates",
    "Paused", "Escalated", etc.), time_text ("2h", "47m",
    "5h", "1d", "13h", etc.) and score_percent between
    fetches.
  * Vary price_line across the 4 recent updates (do NOT
    reuse the same KWD amount on every fetch).
''';
  }

  static List<OpenRouterMessage> quickActionsMessages({
    required String language,
    required String region,
    int? nonce,
    String? userQuery,
  }) {
    final userText = userQuery ??
        'Generate a fresh set of quick actions for a '
            'brand-investigation dashboard. Use diverse industries '
            '(perfume, beauty, fashion, electronics, social-media '
            'campaigns) and prefer brands relevant to $region. '
            'Use the local currency for $region in price strings. '
            'All strings must be in $language.'
            '${nonce != null ? ' Fetch #$nonce — produce NEW actions and updates, do not repeat prior fetches.' : ''}';
    return [
      OpenRouterMessage(
        role: 'system',
        content: quickActionsSystemPrompt(
          language: language,
          region: region,
        ),
      ),
      OpenRouterMessage(
        role: 'user',
        content: PromptSanitizer.sanitize(userText),
      ),
    ];
  }

  /// System prompt for the full Market Pulse detail screen. This
  /// is the data the user sees when they tap "View all" on the
  /// Market Pulse panel.
  static String marketDetailSystemPrompt({
    required String language,
    required String region,
  }) {
    return '''
You are a market analyst for a brand-investigation dashboard.
Produce a JSON snapshot for the "Market Pulse" detail screen.
Return STRICT JSON only — no commentary, no markdown fences, no
trailing prose.

Region: $region. Prefer brands, currencies, and examples
locally relevant to $region.

Language: $language. ALL string values must be in $language.

Number formatting (CRITICAL — read carefully):
  * ALL digits inside ANY string (kpi.value, kpi.delta, kpi.sub,
    topic.change, brand.growth, event.time, trend.point labels,
    etc.) MUST be WESTERN / ASCII digits 0-9, NEVER Arabic-Indic
    digits ٠-٩. Even when the surrounding text is in Arabic.
  * The percent sign must always be the ASCII `%`, NEVER the
    Arabic `٪`. Write e.g. "+24%", not "+٢٤٪".
  * This applies to BOTH labels/numbers written in Arabic text
    AND any English strings — digits are always ASCII.
  * The app converts any Arabic-Indic digits back to ASCII as a
    safety net, but you should produce ASCII digits directly.

Schema:
{
  "kpis": [
    {
      "id": "posts" | "tweets" | "dominance" | "activity",
      "label": string,
      "value": string,             // e.g. "128.4K", "12%", "High"
      "sub": string,               // e.g. "24h"
      "delta": string,             // e.g. "+24%", "-6%", or ""
      "positive": boolean          // true for green arrow, false for red
    },
    ... 4 entries in the order: posts, tweets, dominance, activity
  ],
  "sources": [
    {
      "name": string,             // short label (≤ 16 chars) in the
                                  // user's language. Use ONLY the
                                  // three stable values:
                                  //   Arabic  → "أخبار",
                                  //              "ذكاء اصطناعي",
                                  //              "التواصل الاجتماعي"
                                  //   English → "News",
                                  //              "AI",
                                  //              "Social"
                                  // Do NOT use any other names (no
                                  // "دردشات", no "اجتماعي", no
                                  // transliterations). The card
                                  // renders this verbatim.
      "fraction": number,         // 0..1, sum across segments ~= 1.0
      "color": "green" | "amber" | "red"
    },
    ... 3 entries. Fractions must sum to ~1.0.
  ],
  "trend": {
    "y_max": number,              // suggested top y-axis value, e.g. 25000
    "points": [
      { "label": string, "value": number },
      ... 7 to 14 entries, oldest first, newest last
    ]
  },
  "topics": [
    {
      "label": string,            // short, <= 18 chars
      "brand": string,
      "change": string,           // e.g. "+12%"
      "positive": boolean,
      "points": [number, ...]     // 12..20 normalized 0..1 sparkline values
    },
    ... 5 entries
  ],
  "brands": [
    {
      "name": string,
      "growth": string,           // e.g. "+45%"
      "positive": boolean,
      "image_hint": string,       // short noun (perfume / phone / coffee / shoe / etc.)
      "domain": string            // the brand's official website domain.
                                 // No "https://", no "www.", no path.
                                 // Used by the app to build the logo
                                 // URL — DO NOT return a logo URL
                                 // yourself, the app constructs it
                                 // from this domain. If the brand
                                 // has no public English website, omit
                                 // the field entirely.
    },
    ... 5 entries
  ],
  "events": [
    {
      "title": string,            // <= 70 chars
      "subtitle": string,         // <= 90 chars
      "time": string,             // e.g. "2h"
      "status": string,           // e.g. "Viral", "Important", "Banned"
      "status_color": "green" | "amber" | "red"
    },
    ... 3 entries
  ]
}

Rules:
  * All numeric values (value, fraction, change, points) must be
    plausible — pick REALISTIC magnitudes. Posts in the tens of
    thousands (e.g. "82.4K"), tweets in millions (e.g. "12.7M"),
    dominance as a percent (e.g. "14%"), and so on.
  * Fractions in `sources` MUST sum to 1.0 (each 0..1).
  * Sparkline points for `topics` MUST form a clearly visible,
    oscillating line (12..20 values). MANDATORY shape rules:
      - Start lower than the end (a clear upward OR downward
        trend across the 12..20 points).
      - Across the trend, include at least 3 visible bumps
        (local maxima and minima), not just endpoints.
      - Cover the FULL 0..1 range: min < 0.30 AND max > 0.70.
      - No flat segments: every consecutive pair must differ
        by at least 0.04.
  * Use the local currency / units of $region where natural.
  * Keep titles / labels short — they render on small cards.
  * `trend.y_max` MUST be a TIGHT upper bound — within ~1.2x of
    the maximum `value` in `trend.points`. The y-axis renders 6
    labels from 0 to y_max, so if y_max is too large the line
    will collapse near the bottom of the chart. Pick a round
    number (e.g. 10000, 25000, 50000) just above the data peak.
  * For `brands[].name`: ALWAYS write the brand name in
    ENGLISH / Latin script, even when the user's language is
    Arabic. Brand names render verbatim on the brand cards.
  * For `brands[].domain`: return the brand's OFFICIAL website
    domain in ASCII / Latin form (e.g. `starbucks.com`,
    `apple.com`). No `https://`, no `www.`, no path.
    Only include a `domain` for brands that ACTUALLY have a
    public English-website domain. For regional / local brands
    that have no public site, OMIT the `domain` field entirely.
    The `domain` MUST be ASCII even when the user's language
    is Arabic.
  * NEVER invent image URLs (Wikimedia, Unsplash, or anything
    else) — the app builds the logo URL from the `domain` field.
  * Return ONLY JSON.
''';
  }

  static List<OpenRouterMessage> marketDetailMessages({
    required String language,
    required String region,
    int? nonce,
    String? userQuery,
  }) {
    // Dynamically inject a curated pool of REAL, locally-relevant
    // brands for this region. The AI must pick from this list — it
    // must NOT make up brand names or reuse the generic examples
    // from prior prompts. We pick a random subset of 6 brands
    // per fetch so the AI always sees fresh examples and cannot
    // memorise a fixed list.
    final isArabic = language == 'ar';
    final seed = nonce ?? DateTime.now().millisecondsSinceEpoch;
    final brandPool = _pickRandomBrands(6, seed, isArabic);
    final userText = userQuery ??
        'Generate a fresh market pulse snapshot for $region. '
            'All strings must be in $language. '
            'IMPORTANT: Pick brands ONLY from this list: $brandPool. '
            'Do NOT invent brand names or use generic placeholders. '
            '${nonce != null ? ' Fetch #$nonce — produce NEW values.' : ''}';
    return [
      OpenRouterMessage(
        role: 'system',
        content: marketDetailSystemPrompt(
          language: language,
          region: region,
        ),
      ),
      OpenRouterMessage(
        role: 'user',
        content: PromptSanitizer.sanitize(userText),
      ),
    ];
  }

  /// System prompt for the Explore screen detail.
  static String exploreDetailSystemPrompt({
    required String language,
    required String region,
  }) {
    return '''
You are a discovery and exploration guide for a brand-investigation
dashboard. Produce a JSON payload for the Explore screen. Return
STRICT JSON only — no commentary, no markdown fences, no trailing prose.

Region: $region. Prefer brands, products, and trends locally
relevant to $region.

Language: The user may be in English or Arabic. ALL string values
must be in the same language as the user's request.

Schema:
{
  "trending": [
    {
      "title_en": string,        // English title (required)
      "title_ar": string,        // Arabic title (required)
      "subtitle_en": string,     // English subtitle
      "subtitle_ar": string,     // Arabic subtitle
      "image_hint": string,      // short noun for asset picker
      "category": string         // "markets" | "products" | "beauty" | "brands" | "influencers"
    },
    ... 4 entries covering different trending topics
  ],
  "discover": [
    {
      "type": "companies" | "products" | "influencers" | "reports",
      "title_en": string,
      "title_ar": string,
      "subtitle_en": string,
      "subtitle_ar": string
    },
    ... 4 entries
  ],
  "recent": [
    {
      "title_en": string,
      "title_ar": string,
      "subtitle_en": string,
      "subtitle_ar": string,
      "time": string,           // e.g. "2h", "5h", "1d"
      "status_label_en": string, // e.g. "Completed", "Quick Answer", "Analyzing"
      "status_label_ar": string,
      "status_style": "completed" | "quickanswer" | "analyzing" | "paused",
      "image_hint": string,
      "domain": string          // optional brand domain for logo
    },
    ... 2-4 entries
  ]
}

Rules:
  * trending[].category must be one of: markets, products, beauty, brands, influencers
  * trending titles should be engaging and relevant to current events
  * discover tiles should cover: companies, products, influencers, reports
  * recent investigations should have realistic titles about brand analysis, product launches, or market research
  * status_style controls the badge color: completed=green, quickanswer=blue, analyzing=amber, paused=red
  * Use real brand names relevant to $region where appropriate
  * Return ONLY JSON.

Variety — IMPORTANT:
  * Each fetch should produce DIFFERENT content. Do not repeat the
    same titles, brands, or topics.
  * Pick from diverse industries: perfume, beauty, fashion, electronics,
    food & beverage, telecom, social-media campaigns.
  * Vary the time strings across recent items (e.g. "2h", "5h", "13h", "1d").
''';
  }

  static List<OpenRouterMessage> exploreDetailMessages({
    required String language,
    required String region,
    int? nonce,
    String? userQuery,
  }) {
    final userText = userQuery ??
        'Generate a fresh explore screen snapshot for $region. '
            'All strings must be in $language. '
            '${nonce != null ? ' Fetch #$nonce — produce NEW content.' : ''}';
    return [
      OpenRouterMessage(
        role: 'system',
        content: exploreDetailSystemPrompt(
          language: language,
          region: region,
        ),
      ),
      OpenRouterMessage(
        role: 'user',
        content: PromptSanitizer.sanitize(userText),
      ),
    ];
  }

  /// Picks [count] random brands from the [allBrands] pool using
  /// [seed] so the selection is deterministic per fetch. Returns
  /// a comma-separated list for injection into the user prompt.
  static String _pickRandomBrands(int count, int seed, bool isArabic) {
    final shuffled = List<String>.from(allBrands)..shuffle(math.Random(seed));
    final picked = shuffled.take(count).toList();
    if (isArabic) {
      return picked.map((b) => _brandNamesAr[b] ?? b).join(', ');
    }
    return picked.join(', ');
  }

  /// A large, flat pool of ~100 real brands with strong market
  /// presence across the GCC (Kuwait, Saudi, UAE, Qatar, Bahrain,
  /// Oman). The AI is told to pick from this pool exclusively —
  /// this prevents it from inventing brand names.
  ///
  /// Brands span: perfume/arabs, fashion, food & beverage,
  /// electronics, telecom, automotive, and general retail.
  static const List<String> allBrands = [
    // Perfume / Arab fragrances
    'Lattafa', 'Arabian Oud', 'Ajmal', 'Al Halal Perfumes', 'Rasasi',
    'Al Rehab', 'Swiss Arabian', 'Ard Al Zaafaran', 'Al Mujeeb',
    'Al Ghourab', 'Ahmed Al Maghribi', 'Khalis', 'Moulana',
    'Fragrance World', 'Riffat Al Sultan', 'My Perfumes',
    // Fashion / apparel
    'H&M', 'Max Fashion', 'Boutique 5', 'Vincero', 'Namshi',
    'Centrepoint', 'Splash', 'London Gallery', 'Koton', 'LC Waikiki',
    'Decathlon', 'Zara', 'Massimo Dutti', 'Stradivarius', 'Pull&Bear',
    'BERSHKA', 'Mango', 'Next', 'River Island', 'New Look',
    // Food & beverage
    'AlMarai', 'Sadafco', 'Herfy', 'Kudu', 'Al Baik',
    'Shawarmanji', 'Lean Kitchen', 'Protein Bakery', 'Cafe Bateel',
    'Paul Bakery', 'Shake Shack', 'Five Guys', 'KFC', 'McDonalds',
    'Subway', 'Cinnabon', 'Costa Coffee', 'Caribou Coffee',
    'Starbucks', 'Tim Hortons', 'Joe & The Juice', 'Nando\'s',
    'The Cheesecake Factory', 'P.F. Chang\'s', 'Kcal',
    // Electronics / tech retail
    'Jarir Bookstore', 'Xcite', 'Ecity', 'Sharaf DG',
    'Euromax', 'Jackys', 'Lulus', 'Plug-Ins', 'Eagle Technologies',
    // Telecom
    'STC', 'Mobily', 'Zain', 'Ooredoo', 'Batelco',
    'Virgin Mobile', 'jawwy', 'Lebara', 'holafly',
    // Automotive
    'BMP', 'Al-Futtaim Auto', 'Al Maya Motors', 'Universal Motors',
    'Saqr Agency', 'Teefa', 'Mulliner', 'Al Mojil Group',
    // Retail / hypermarkets
    'Carrefour', 'Lulu Hypermarket', 'Spinneys', 'Union Coop',
    'Al Meera', 'Masmak', 'Tamimi Markets', 'Al Sadhan',
    'Danube', 'Khalifa Hypermarket', 'Sharjah Co-op',
    // Beauty / cosmetics
    'Sephora', 'MAC Cosmetics', 'Sephora KSA', 'Faces',
    'Bloom Beauty', 'Sanaa', 'The Body Shop', 'Inglot',
    // General lifestyle / luxury
    'Al Tayer', 'Al Futtaim', 'Chalhoub Group', 'Rivoli Group',
    'Paris Gallery', 'Smile Art', 'Khalti', 'Talabat',
  ];

  /// Arabic translations for brand names in [allBrands]. Used only
  /// as a contextual hint when the user's language is Arabic — the
  /// JSON output MUST always use English/Latin names.
  static const Map<String, String> _brandNamesAr = {
    'lattafa': 'لاتافا',
    'arabian oud': 'عود عربي',
    'ajmal': 'عجمان',
    'al halal perfumes': 'العطور الحلال',
    'al rehab': 'الرحاب',
    'swiss arabian': 'سويسري عربي',
    'ard al zaafaran': 'عرض الطائف',
    'rasasi': 'راساسي',
    'almarai': 'المراعي',
    'sadafco': 'صدىكو',
    'herfy': 'هرفي',
    'kudu': 'كودو',
    'al baik': 'البيك',
    'stc': 'الاتصالات السعودية',
    'mobily': 'موبيلي',
    'zain': 'زين',
    'ooredoo': 'أوريدو',
    'batelco': 'باتلتكو',
    'lulu hypermarket': 'لولو هايبرماركت',
    'carrefour': 'كارفور',
    'spinneys': 'سبينيس',
    'jarir bookstore': 'جارتي',
    'xcite': 'أكسيت',
    'namshi': 'نمشي',
    'centrepoint': 'سنتر بوينت',
    'h&m': 'اتش آند ام',
    'max fashion': 'ماكس فاشن',
    'cafe bateel': 'كافيه باتيل',
    'costa coffee': 'كوستا كوفي',
    'caribou coffee': 'كاريبو كوفي',
    'starbucks': 'ستاربكس',
    'kfc': 'كيه اف سي',
    'mcdonalds': 'ماكدونالدز',
    'subway': 'سبلوي',
    'shake shack': 'شيك شاك',
    'sephora': 'سيفورا',
    'mac cosmetics': 'ماك كوزمتكس',
    'the body shop': 'ذا بودي شوب',
    'zara': 'زارا',
    'mango': 'مانجو',
    'lacoste': 'لاكوست',
    'al tayer': 'الطاير',
    'al futuraim': 'الفطيم',
    'rivoli group': 'ريڤولي',
    'talabat': 'طلبات',
  };
}
