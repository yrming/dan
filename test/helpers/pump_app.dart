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

  /// Pumps enough frames for a showing app toast to finish its entrance,
  /// hold, and exit animations. Animation frames report the clock before
  /// each pump, so every phase needs a clock-advancing pump plus one more
  /// frame pump before the toast entry is removed.
  Future<void> pumpToastDismissal() async {
    await pump(const Duration(seconds: 4));
    await pump(const Duration(seconds: 4));
    await pump(const Duration(seconds: 4));
    await pump(const Duration(milliseconds: 300));
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
    Widget Function(Widget child)? wrapper,
    ThemeData? theme,
    ThemeData? darkTheme,
    ThemeMode themeMode = ThemeMode.system,
    Locale? locale,
  }) {
    final app = MaterialApp.router(
      theme: theme ?? AppTheme.light(),
      darkTheme: darkTheme ?? AppTheme.dark(),
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
    return pumpWidget(wrapper?.call(app) ?? app);
  }
}
