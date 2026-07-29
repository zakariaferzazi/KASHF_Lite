import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'theme.dart';
import 'screens/welcome_screen.dart';

void main() {
  runApp(const KashfApp());
}

class KashfApp extends StatelessWidget {
  const KashfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kashf Lite',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF5B92E),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: KashfColors.background,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: const WelcomeScreen(),
    );
  }
}
