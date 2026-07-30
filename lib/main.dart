import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'l10n/app_locale.dart';
import 'l10n/app_strings.dart';
import 'l10n/locale_controller.dart';
import 'l10n/locale_scope.dart';
import 'l10n/theme_controller.dart';
import 'l10n/theme_scope.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/shell/home_shell.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final localeController = await LocaleController.load();
  runApp(KashfApp(localeController: localeController));
}

class KashfApp extends StatefulWidget {
  const KashfApp({super.key, required this.localeController});
  final LocaleController localeController;

  @override
  State<KashfApp> createState() => _KashfAppState();
}

class _KashfAppState extends State<KashfApp> {
  late final ThemeController _themeController;

  @override
  void initState() {
    super.initState();
    _themeController = ThemeController();
    // Apply the initial palette so the very first frame is correct.
    _applyPalette(_themeController.mode);
  }

  @override
  void dispose() {
    widget.localeController.dispose();
    _themeController.dispose();
    super.dispose();
  }

  void _applyPalette(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.dark:
        KashfPalette.setActive(KashfPalette.dark);
        break;
      case AppThemeMode.light:
        KashfPalette.setActive(KashfPalette.light);
        break;
      case AppThemeMode.main:
        KashfPalette.setActive(KashfPalette.main);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LocaleScope(
      controller: widget.localeController,
      child: ThemeScope(
        controller: _themeController,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            widget.localeController,
            _themeController,
          ]),
          builder: (context, _) {
            _applyPalette(_themeController.mode);
            final l = AppLocalizations(widget.localeController.language);
            // Wrap MaterialApp in Directionality so the entire app
            // flips to RTL when Arabic is selected. MaterialApp's
            // internal Directionality is then overridden by this one.
            return Directionality(
              textDirection: l.isRtl ? TextDirection.rtl : TextDirection.ltr,
              child: MaterialApp(
                title: l.t('app_title'),
                debugShowCheckedModeBanner: false,
                themeMode: _themeController.mode.materialMode,
                theme: _buildTheme(Brightness.light),
                darkTheme: _buildTheme(Brightness.dark),
                locale: widget.localeController.language.locale,
                // Stub delegate so MaterialApp accepts our locale. We avoid
                // pulling in flutter_localizations for the MVP.
                localizationsDelegates: const [
                  _StubLocalizationsDelegate(),
                  _StubCupertinoLocalizationsDelegate(),
                ],
                supportedLocales: const [Locale('en'), Locale('ar')],
                localeResolutionCallback: (deviceLocale, supported) {
                  if (deviceLocale == null) return const Locale('en');
                  for (final loc in supported) {
                    if (loc.languageCode == deviceLocale.languageCode) {
                      return loc;
                    }
                  }
                  return const Locale('en');
                },
                home: const _AuthGate(),
              ),
            );
          },
        ),
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFF5B92E),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// A no-op delegate that satisfies MaterialApp's localizationsDelegates
/// requirement without depending on the flutter_localizations package.
class _StubLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _StubLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) async =>
      DefaultMaterialLocalizations();

  @override
  bool shouldReload(_StubLocalizationsDelegate old) => false;
}

/// A no-op delegate for Cupertino localizations.
class _StubCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _StubCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<CupertinoLocalizations> load(Locale locale) async =>
      DefaultCupertinoLocalizations();

  @override
  bool shouldReload(_StubCupertinoLocalizationsDelegate old) => false;
}

/// Minimal MVP auth gate. The user lands on the welcome screen and
/// can use the "Sign in" / "Sign up" buttons to advance to the shell.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return const WelcomeScreen();
  }
}

/// Public helper so the auth screens can navigate to the home shell.
void navigateToHome(BuildContext context) {
  Navigator.pushReplacement(context, kashfRoute(const HomeShell()));
}

/// Helper for AppLanguage's locale from a code.
AppLanguage appLanguageFromCode(String code) => AppLanguage.fromCode(code);
