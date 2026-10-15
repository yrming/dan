import 'package:authentication_repository/authentication_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/authentication/authentication.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:dan/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:remixicon/remixicon.dart';

import '../../helpers/helpers.dart';

class _MockAuthenticationBloc
    extends MockBloc<AuthenticationEvent, AuthenticationState>
    implements AuthenticationBloc {}

void main() {
  group('showAccountSwitcherSheet', () {
    late AuthenticationBloc authenticationBloc;

    setUp(() {
      authenticationBloc = _MockAuthenticationBloc();
      when(() => authenticationBloc.state).thenReturn(
        AuthenticationAuthenticated(
          AuthenticationSnapshot.authenticated(
            accounts: const [_firstAccount, _secondAccount],
            activeAccount: _firstAccount,
          ),
        ),
      );
    });

    testWidgets('shows accounts, marks the active account, and switches', (
      tester,
    ) async {
      await tester.pumpApp(
        BlocProvider.value(
          value: authenticationBloc,
          child: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => showAccountSwitcherSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(BottomSheet));

      expect(find.text(_firstAccount.name), findsOneWidget);
      expect(find.text(_secondAccount.name), findsOneWidget);
      expect(find.textContaining(_firstAccount.id), findsOneWidget);
      expect(find.text(context.l10n.addAccountLabel), findsOneWidget);
      expect(find.byIcon(RemixIcons.check_line), findsOneWidget);
      final accountRow = find.ancestor(
        of: find.text(_firstAccount.name),
        matching: find.byType(InkWell),
      );
      final addAccountRow = find.ancestor(
        of: find.text(context.l10n.addAccountLabel),
        matching: find.byType(InkWell),
      );
      expect(
        tester.getRect(accountRow).height,
        tester.getRect(addAccountRow).height,
      );
      expect(
        tester
            .getRect(
              find.descendant(
                of: accountRow,
                matching: find.byType(UserAvatar),
              ),
            )
            .center
            .dy,
        closeTo(tester.getRect(accountRow).center.dy, 0.01),
      );
      expect(
        tester
            .getRect(
              find.descendant(
                of: addAccountRow,
                matching: find.byIcon(RemixIcons.add_line),
              ),
            )
            .center
            .dy,
        closeTo(tester.getRect(addAccountRow).center.dy, 0.01),
      );

      await tester.tap(find.text(_secondAccount.name));
      await tester.pumpAndSettle();

      verify(
        () => authenticationBloc.add(
          const AuthenticationAccountSwitchRequested(_secondAccountId),
        ),
      ).called(1);
    });
  });
}

const _secondAccountId = 'account-2';

const _firstAccount = AuthenticatedAccount(
  id: 'account-1',
  name: 'First account',
  screenName: 'first',
);

const _secondAccount = AuthenticatedAccount(
  id: _secondAccountId,
  name: 'Second account',
  screenName: 'second',
);
