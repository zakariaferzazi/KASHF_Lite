/// Builds a Logo.dev URL from a brand's official domain.
///
/// Logo.dev serves company logos at `https://img.logo.dev/{domain}`
/// and the AI never has to invent image URLs — it only returns
/// the domain, and we build the URL ourselves.
class LogoService {
  LogoService._();

  /// Public Logo.dev publishable key. Used as a query string so
  /// the API can attribute the request. Without it, the CDN serves
  /// logos but at a lower rate limit.
  static const String publishableKey = 'pk_alLbQ-_HQ6yA195-bcNVGQ';

  /// Base URL for the Logo.dev logo API.
  static const String baseUrl = 'https://img.logo.dev';

  /// Builds a Logo.dev logo URL for [domain] (e.g. `starbucks.com`).
  /// Returns null when [domain] is null/empty.
  ///
  /// Accepts domains in any of the following forms and normalises
  /// them before joining onto the Logo.dev base URL:
  ///   * `starbucks.com`
  ///   * `www.starbucks.com`
  ///   * `https://starbucks.com`
  ///   * `https://www.starbucks.com`
  ///   * `https://www.starbucks.com/some/path`
  ///
  /// The previous implementation passed the raw string through
  /// unchanged which produced malformed URLs like
  /// `https://img.logo.dev/https://www.starbucks.com` — Logo.dev
  /// returns 404 for those. We strip scheme, `www.`, and any
  /// path/query here so callers don't have to.
  ///
  /// [size] controls the rendered square size (px). Defaults to 128
  /// which is what the brand card uses.
  static String? urlFor(String? domain, {int size = 128}) {
    if (domain == null || domain.isEmpty) return null;
    final cleaned = _normaliseDomain(domain);
    if (cleaned.isEmpty) return null;
    final params = <String, String>{
      'size': '$size',
      'token': publishableKey,
    };
    final uri = Uri.parse('$baseUrl/$cleaned').replace(
      queryParameters: params,
    );
    return uri.toString();
  }

  /// Strips scheme, `www.`, path, and query string so [domain]
  /// is just `host.tld`. Returns an empty string when nothing
  /// usable remains.
  static String _normaliseDomain(String domain) {
    var s = domain.trim();
    if (s.isEmpty) return '';
    // Drop scheme.
    for (final prefix in const ['https://', 'http://']) {
      if (s.toLowerCase().startsWith(prefix)) {
        s = s.substring(prefix.length);
        break;
      }
    }
    // Drop `www.` prefix (case-insensitive).
    if (s.toLowerCase().startsWith('www.')) {
      s = s.substring(4);
    }
    // Drop path / query / fragment — we only want the host.
    final slash = s.indexOf('/');
    if (slash >= 0) s = s.substring(0, slash);
    final q = s.indexOf('?');
    if (q >= 0) s = s.substring(0, q);
    final h = s.indexOf('#');
    if (h >= 0) s = s.substring(0, h);
    return s;
  }
}