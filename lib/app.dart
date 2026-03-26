import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';
import 'core/constants.dart';
import 'routes.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class GenerasiEmasApp extends StatelessWidget {
  const GenerasiEmasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Generasi Emas',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,

      // [TAMBAHAN] Konfigurasi Localization
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('id', 'ID'), // Bahasa Indonesia
        Locale('en', 'US'),
      ],

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kPrimary), // kPrimary dari constants.dart
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      ),
      initialRoute: Routes.splash,
      onGenerateRoute: Routes.onGenerateRoute,
    );
  }
}