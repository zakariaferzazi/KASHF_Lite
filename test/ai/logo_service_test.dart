import 'package:flutter_test/flutter_test.dart';

import 'package:kashf_lite/services/ai/logo_service.dart';

void main() {
  group('LogoService.urlFor', () {
    test('builds a Logo.dev URL with size and token params', () {
      final url = LogoService.urlFor('starbucks.com');
      expect(url, isNotNull);
      expect(url, contains('https://img.logo.dev/starbucks.com'));
      expect(url, contains('size=128'));
      expect(url, contains('token=pk_alLbQ-_HQ6yA195-bcNVGQ'));
    });

    test('respects a custom size', () {
      final url = LogoService.urlFor('nike.com', size: 64);
      expect(url, contains('size=64'));
    });

    test('returns null when domain is null or empty', () {
      expect(LogoService.urlFor(null), isNull);
      expect(LogoService.urlFor(''), isNull);
    });
  });
}