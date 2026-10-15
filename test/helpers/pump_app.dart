import 'package:dan/app/theme/theme.dart';
import 'package:dan/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

extension PumpApp on WidgetTester {
  /// Completes a route or dialog transition while shimmers keep running.
  Future<void> pumpTransition() async {
    await pump();
    await pump(Durations.extralong4);
  }

  Future<void> pumpApp(
    Widget widget, {
    ThemeData? theme,
    ThemeData? darkTheme,
    ThemeMode themeMode = ThemeMode.system,
    Locale? locale,
  }) {
    return pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light(),
        darkTheme: darkTheme ?? AppTheme.dark(),
        themeMode: themeMode,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: widget,
      ),
    );
  }

  Future<void> pumpRouterApp(
    GoRouter router, {
    ThemeData? theme,
    ThemeData? darkTheme,
    ThemeMode themeMode = ThemeMode.system,
    Locale? locale,
  }) {
    return pumpWidget(
      MaterialApp.router(
        theme: theme ?? AppTheme.light(),
        darkTheme: darkTheme ?? AppTheme.dark(),
        themeMode: themeMode,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  }
}
