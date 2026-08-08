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
  /// [size] controls the rendered square size (px). Defaults to 128
  /// which is what the brand card uses.
  static String? urlFor(String? domain, {int size = 128}) {
    if (domain == null || domain.isEmpty) return null;
    final params = <String, String>{
      'size': '$size',
      'token': publishableKey,
    };
    final uri = Uri.parse('$baseUrl/$domain').replace(
      queryParameters: params,
    );
    return uri.toString();
  }
}