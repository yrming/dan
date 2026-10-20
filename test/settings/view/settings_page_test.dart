import 'package:appearance_repository/appearance_repository.dart';
import 'package:authentication_repository/authentication_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:dan/app/navigation/routes.dart';
import 'package:dan/appearance/appearance.dart';
import 'package:dan/authentication/authentication.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:dan/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';

class _MockAppearanceCubit extends MockCubit<AppearanceState>
    implements AppearanceCubit {}

class _MockAuthenticationBloc
    extends MockBloc<AuthenticationEvent, AuthenticationState>
    implements AuthenticationBloc {}

void main() {
  group(SettingsPage, () {
    late AppearanceCubit appearanceCubit;
    late AuthenticationBloc authenticationBloc;

    setUp(() {
      appearanceCubit = _MockAppearanceCubit();
      authenticationBloc = _MockAuthenticationBloc();
      when(() => appearanceCubit.state).thenReturn(_appearanceState);
      when(() => authenticationBloc.state).thenReturn(
        AuthenticationAuthenticated(
          AuthenticationSnapshot.authenticated(
            accounts: const [_account],
            activeAccount: _account,
          ),
        ),
      );
    });

    testWidgets('opens application information from about', (tester) async {
      await tester.pumpApp(
        BlocProvider.value(
          value: appearanceCubit,
          child: const SettingsPage(),
        ),
      );

      await tester.tap(find.text('关于'));
      await tester.pumpAndSettle();

      expect(find.byType(AboutDialog), findsOneWidget);
      expect(find.text('旦'), findsOneWidget);
    });

    group('legal links', () {
      testWidgets('opens licenses on a separate page and returns to settings', (
        tester,
      ) async {
        final router = GoRouter(
          initialLocation: '/account-id/settings',
          routes: [
            GoRoute(
              path: '/:userId/settings',
              builder: (context, state) => const SettingsPage(),
              routes: [
                GoRoute(
                  name: AppRouteName.openSourceLicenses,
                  path: AppRoutePath.openSourceLicenses,
                  builder: (context, state) => const OpenSourceLicensesPage(),
                ),
              ],
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpRouterApp(
          router,
          wrapper: (child) => BlocProvider.value(
            value: appearanceCubit,
            child: child,
          ),
        );

        await tester.tap(
          find.byKey(const Key('settings-open-source-licenses-row')),
        );
        await tester.pumpTransition();
        expect(find.byType(OpenSourceLicensesPage), findsOneWidget);
        expect(find.byType(LicensePage), findsOneWidget);
        expect(find.byType(AboutDialog), findsNothing);
        expect(
          GoRouterState.of(
            tester.element(find.byType(OpenSourceLicensesPage)),
          ).uri.path,
          '/account-id/settings/open-source-licenses',
        );
        await tester.tap(find.byType(BackButton));
        await tester.pumpTransition();
        expect(find.byType(SettingsView), findsOneWidget);
        expect(find.byType(OpenSourceLicensesPage), findsNothing);
      });

      testWidgets('reads both documents in app and returns to settings', (
        tester,
      ) async {
        final router = GoRouter(
          initialLocation: '/account-id/settings',
          routes: [
            GoRoute(
              path: '/:userId/settings',
              builder: (context, state) => const SettingsPage(),
              routes: [
                GoRoute(
                  name: AppRouteName.userAgreement,
                  path: AppRoutePath.userAgreement,
                  builder: (context, state) => const LegalDocumentPage(),
                ),
                GoRoute(
                  name: AppRouteName.privacyPolicy,
                  path: AppRoutePath.privacyPolicy,
                  builder: (context, state) =>
                      const LegalDocumentPage(privacyPolicy: true),
                ),
              ],
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpRouterApp(
          router,
          wrapper: (child) => BlocProvider.value(
            value: appearanceCubit,
            child: child,
          ),
        );
        await tester.pumpTransition();

        for (final document in ['user-agreement', 'privacy-policy']) {
          await tester.tap(find.byKey(Key('settings-$document-row')));
          await tester.pumpTransition();
          await tester.pumpAndSettle();
          expect(find.byType(MarkdownBody), findsOneWidget);
          expect(
            find.text(
              document == 'user-agreement' ? '「旦」用户协议' : '「旦」隐私政策',
            ),
            findsOneWidget,
          );
          await tester.tap(find.byType(BackButton));
          await tester.pumpTransition();
          expect(find.byType(SettingsView), findsOneWidget);
        }
      });
    });

    testWidgets('confirms before requesting sign out', (tester) async {
      await tester.pumpApp(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: appearanceCubit),
            BlocProvider.value(value: authenticationBloc),
          ],
          child: const SettingsPage(),
        ),
      );
      final context = tester.element(find.byType(SettingsPage));

      await tester.ensureVisible(find.text(context.l10n.signOutLabel).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(context.l10n.signOutLabel).first);
      await tester.pump();

      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.text(context.l10n.signOutDialogTitle(_account.name)),
        findsAtLeastNWidgets(1),
      );
      expect(find.text(context.l10n.confirmationDialogContent), findsOneWidget);

      await tester.tap(find.text(context.l10n.signOutDialogCancelLabel));
      await tester.pump();
      verifyNever(
        () => authenticationBloc.add(
          const AuthenticationSignOutRequested(),
        ),
      );

      await tester.tap(find.text(context.l10n.signOutLabel).first);
      await tester.pump();
      await tester.tap(find.text(context.l10n.signOutDialogConfirmLabel).last);
      await tester.pump();

      verify(
        () => authenticationBloc.add(
          const AuthenticationSignOutRequested(),
        ),
      ).called(1);
    });
  });
}

const _appearanceState = AppearanceState(
  status: AppearanceStatus.success,
  settings: AppearanceSettings(),
);

const _account = AuthenticatedAccount(
  id: 'account-id',
  name: '当前账号',
  screenName: 'account',
);
