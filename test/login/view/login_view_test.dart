import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:dan/login/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';

class _MockLoginBloc extends MockBloc<LoginEvent, LoginState>
    implements LoginBloc {}

void main() {
  group(LoginView, () {
    late LoginBloc loginBloc;

    setUp(() {
      loginBloc = _MockLoginBloc();
    });

    Future<void> pumpLoginView(
      WidgetTester tester, {
      LoginState state = const LoginState(),
      ThemeData? theme,
      ThemeData? darkTheme,
      ThemeMode themeMode = ThemeMode.system,
      Locale? locale,
      Stream<LoginState>? states,
      LoginExternalLinkLauncher? externalLinkLauncher,
    }) async {
      if (states == null) {
        when(() => loginBloc.state).thenReturn(state);
      } else {
        whenListen(loginBloc, states, initialState: state);
      }
      await tester.pumpApp(
        BlocProvider.value(
          value: loginBloc,
          child: LoginView(externalLinkLauncher: externalLinkLauncher),
        ),
        theme: theme,
        darkTheme: darkTheme,
        themeMode: themeMode,
        locale: locale,
      );
    }

    testWidgets('renders the branded OAuth-first login experience', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpLoginView(tester, theme: AppTheme.light());
      final context = tester.element(find.byType(LoginView));

      expect(find.byType(DanLogo), findsOneWidget);
      expect(
        find.bySemanticsLabel(context.l10n.loginBrandLogoLabel),
        findsOneWidget,
      );
      expect(find.text(context.l10n.loginTagline), findsOneWidget);
      expect(find.text(context.l10n.loginOAuthButtonLabel), findsOneWidget);
      expect(find.text(context.l10n.loginConsentNotice), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      semantics.dispose();
    });

    testWidgets('uses theme colors for the logo in light and dark modes', (
      tester,
    ) async {
      for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
        await pumpLoginView(
          tester,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeMode,
        );
        final context = tester.element(find.byType(LoginView));
        final logo = tester.widget<DanLogo>(find.byType(DanLogo));
        final expectedTheme = themeMode == ThemeMode.light
            ? AppTheme.light()
            : AppTheme.dark();

        expect(Theme.of(context).brightness, expectedTheme.brightness);
        expect(logo.color, expectedTheme.colorScheme.onSurface);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('renders Chinese login content for a Chinese locale', (
      tester,
    ) async {
      await pumpLoginView(
        tester,
        theme: AppTheme.light(),
        locale: const Locale('zh'),
      );
      final context = tester.element(find.byType(LoginView));

      expect(find.text(context.l10n.loginTagline), findsOneWidget);
      expect(find.text(context.l10n.loginOAuthButtonLabel), findsOneWidget);
      expect(find.text(context.l10n.loginConsentNotice), findsOneWidget);
    });

    group('legal links', () {
      for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
        testWidgets('opens both legal documents in $themeMode', (tester) async {
          final launchedUris = <Uri>[];
          await pumpLoginView(
            tester,
            themeMode: themeMode,
            externalLinkLauncher: (uri) async {
              launchedUris.add(uri);
              return true;
            },
          );
          final context = tester.element(find.byType(LoginView));

          await tester.tapOnText(
            find.textRange.ofSubstring(context.l10n.settingsUserAgreementLabel),
          );
          await tester.pump();
          await tester.tapOnText(
            find.textRange.ofSubstring(context.l10n.settingsPrivacyPolicyLabel),
          );
          await tester.pump();

          expect(launchedUris, [
            Uri.parse('https://dan.yrm.dev/user-agreement'),
            Uri.parse('https://dan.yrm.dev/privacy-policy'),
          ]);
          verifyNever(() => loginBloc.add(const LoginOAuthRequested()));
        });

        testWidgets('styles legal links with solid underlines only', (
          tester,
        ) async {
          await pumpLoginView(tester, themeMode: themeMode);
          final context = tester.element(find.byType(LoginView));
          final consent = tester.widget<Text>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Text &&
                  widget.textSpan?.toPlainText() ==
                      context.l10n.loginConsentNotice,
            ),
          );
          final spans = (consent.textSpan! as TextSpan).children!
              .whereType<TextSpan>()
              .where((span) => span.recognizer != null)
              .toList();

          expect(spans, hasLength(2));
          for (final span in spans) {
            expect(span.style?.color, context.appTypography.loginConsent.color);
            expect(span.style?.decoration, TextDecoration.underline);
            expect(
              span.style?.decorationColor,
              context.appTypography.loginConsent.color,
            );
            expect(
              span.style?.decorationStyle,
              TextDecorationStyle.solid,
            );
          }
        });
      }
    });

    testWidgets('dispatches OAuth login when the primary button is tapped', (
      tester,
    ) async {
      await pumpLoginView(tester);

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      verify(() => loginBloc.add(const LoginOAuthRequested())).called(1);
    });

    testWidgets(
      'shows OAuth progress and disables the button while submitting',
      (tester) async {
        await pumpLoginView(
          tester,
          state: const LoginState(
            status: LoginSubmissionStatus.oauthInProgress,
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
      },
    );

    for (final status in <LoginSubmissionStatus>[
      LoginSubmissionStatus.apiFailure,
      LoginSubmissionStatus.storageFailure,
      LoginSubmissionStatus.oauthDenied,
      LoginSubmissionStatus.oauthFailure,
      LoginSubmissionStatus.failure,
    ]) {
      testWidgets(
        'renders the localized $status failure',
        (tester) async {
          await pumpLoginView(
            tester,
            state: LoginState(status: status),
          );
          final context = tester.element(find.byType(LoginView));

          expect(
            find.text(_failureText(context, status)),
            findsOneWidget,
          );
        },
      );
    }
  });
}

String _failureText(BuildContext context, LoginSubmissionStatus status) {
  return switch (status) {
    LoginSubmissionStatus.apiFailure => context.l10n.loginApiFailure,
    LoginSubmissionStatus.storageFailure => context.l10n.loginStorageFailure,
    LoginSubmissionStatus.oauthDenied => context.l10n.loginOAuthDenied,
    LoginSubmissionStatus.oauthFailure => context.l10n.loginOAuthFailure,
    LoginSubmissionStatus.failure => context.l10n.loginGenericFailure,
    _ => throw StateError('Unexpected status'),
  };
}
