import 'package:authentication_repository/authentication_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:dan/app/navigation/app_shell_tab.dart';
import 'package:dan/app/navigation/app_shell_tab_scope.dart';
import 'package:dan/authentication/authentication.dart';
import 'package:dan/mentions/mentions.dart';
import 'package:dan/notifications/notifications.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:status_repository/status_repository.dart' as status_repository;

import '../helpers/helpers.dart';

class _MockAuthenticationBloc
    extends MockBloc<AuthenticationEvent, AuthenticationState>
    implements AuthenticationBloc {}

class _MockStatusRepository extends Mock
    implements status_repository.StatusRepository {}

class _MockNotificationCountsCubit extends MockCubit<NotificationCountsState>
    implements NotificationCountsCubit {}

void main() {
  late AuthenticationBloc authenticationBloc;
  late status_repository.StatusRepository statusRepository;
  late NotificationCountsCubit notificationCountsCubit;

  setUp(() {
    authenticationBloc = _MockAuthenticationBloc();
    statusRepository = _MockStatusRepository();
    notificationCountsCubit = _MockNotificationCountsCubit();
    when(() => authenticationBloc.state).thenReturn(_authenticatedState);
    when(
      () => statusRepository.statusChanges,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => statusRepository.getMentions(),
    ).thenAnswer((_) async => _emptyMentionsPage);
    when(
      () => notificationCountsCubit.refresh(),
    ).thenAnswer((_) async {});
    when(
      () => notificationCountsCubit.state,
    ).thenReturn(const NotificationCountsInitial());
  });

  Future<void> pumpMentionsPage(
    WidgetTester tester, {
    required AppShellTab selectedTab,
  }) {
    return tester.pumpApp(
      AppShellTabScope(
        selectedTab: selectedTab,
        child: MultiBlocProvider(
          providers: [
            BlocProvider<AuthenticationBloc>.value(value: authenticationBloc),
            BlocProvider<NotificationCountsCubit>.value(
              value: notificationCountsCubit,
            ),
          ],
          child: MultiRepositoryProvider(
            providers: [
              RepositoryProvider<status_repository.StatusRepository>.value(
                value: statusRepository,
              ),
            ],
            child: const MentionsPage(),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'refreshes notification counters after the first timeline load',
    (tester) async {
      await pumpMentionsPage(tester, selectedTab: AppShellTab.mentions);
      await tester.pump();
      await tester.pump();

      verifyInOrder([
        () => statusRepository.getMentions(),
        () => notificationCountsCubit.refresh(),
      ]);
    },
  );

  testWidgets('reloads the timeline when the tab is activated again', (
    tester,
  ) async {
    await pumpMentionsPage(tester, selectedTab: AppShellTab.mentions);
    await tester.pump();
    await tester.pump();

    await pumpMentionsPage(tester, selectedTab: AppShellTab.browse);
    await tester.pump();
    await pumpMentionsPage(tester, selectedTab: AppShellTab.mentions);
    await tester.pump();
    await tester.pump();

    verify(() => statusRepository.getMentions()).called(2);
  });

  testWidgets(
    'keeps the timeline when rebuilds keep the tab active',
    (tester) async {
      await pumpMentionsPage(tester, selectedTab: AppShellTab.mentions);
      await tester.pump();
      await tester.pump();
      await pumpMentionsPage(tester, selectedTab: AppShellTab.mentions);
      await tester.pump();
      await tester.pump();

      verify(() => statusRepository.getMentions()).called(1);
    },
  );

  testWidgets(
    'refreshes notification counters in timeline order on every reload',
    (tester) async {
      await pumpMentionsPage(tester, selectedTab: AppShellTab.mentions);
      await tester.pump();
      await tester.pump();
      await pumpMentionsPage(tester, selectedTab: AppShellTab.browse);
      await tester.pump();
      await pumpMentionsPage(tester, selectedTab: AppShellTab.mentions);
      await tester.pump();
      await tester.pump();

      verifyInOrder([
        () => statusRepository.getMentions(),
        () => notificationCountsCubit.refresh(),
        () => statusRepository.getMentions(),
        () => notificationCountsCubit.refresh(),
      ]);
    },
  );

  testWidgets('does not refresh notification counters on timeline failure', (
    tester,
  ) async {
    when(() => statusRepository.getMentions()).thenThrow(Exception('offline'));
    await pumpMentionsPage(tester, selectedTab: AppShellTab.mentions);
    await tester.pump();
    await tester.pump();

    verifyNever(() => notificationCountsCubit.refresh());
  });
}

final _authenticatedState = AuthenticationAuthenticated(
  AuthenticationSnapshot.authenticated(
    accounts: const [_account],
    activeAccount: _account,
  ),
);

const _account = AuthenticatedAccount(
  id: 'account-id',
  name: 'Account',
  screenName: 'account',
);

final _emptyMentionsPage = status_repository.StatusPage(
  statuses: const [],
  hasMore: false,
);
