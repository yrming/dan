import 'package:appearance_repository/appearance_repository.dart';
import 'package:authentication_repository/authentication_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:dan/appearance/appearance.dart';
import 'package:dan/authentication/authentication.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:dan/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
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
      testWidgets('opens the agreement and privacy policy URLs', (
        tester,
      ) async {
        final launchedUris = <Uri>[];
        await tester.pumpApp(
          BlocProvider.value(
            value: appearanceCubit,
            child: SettingsPage(
              externalLinkLauncher: (uri) async {
                launchedUris.add(uri);
                return true;
              },
            ),
          ),
        );

        await tester.tap(find.byKey(const Key('settings-user-agreement-row')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('settings-privacy-policy-row')));
        await tester.pump();

        expect(launchedUris, [
          Uri.parse('https://dan.yrm.dev/user-agreement'),
          Uri.parse('https://dan.yrm.dev/privacy-policy'),
        ]);
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
