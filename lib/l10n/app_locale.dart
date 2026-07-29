import 'package:flutter/widgets.dart';

/// Supported UI languages for KASHF Lite.
enum AppLanguage {
  english('en', 'English', 'الإنجليزية'),
  arabic('ar', 'العربية', 'Arabic');

  const AppLanguage(this.code, this.nativeName, this.englishName);

  /// ISO 639-1 code used by [Locale].
  final String code;

  /// Name shown in the language list (matches the language itself).
  final String nativeName;

  /// Name shown in the language list (English).
  final String englishName;

  /// The Flutter [Locale] for this language.
  Locale get locale => Locale(code);

  static AppLanguage fromCode(String code) {
    return AppLanguage.values.firstWhere(
      (l) => l.code == code,
      orElse: () => AppLanguage.english,
    );
  }
}
