import 'dart:async';

import 'package:authentication_repository/authentication_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:dan/authentication/authentication.dart';
import 'package:dan/home/home.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:status_repository/status_repository.dart' as status_repository;

import '../../helpers/helpers.dart';

class _MockAuthenticationBloc
    extends MockBloc<AuthenticationEvent, AuthenticationState>
    implements AuthenticationBloc {}

class _MockStatusRepository extends Mock
    implements status_repository.StatusRepository {}

void main() {
  group(HomePage, () {
    late AuthenticationBloc authenticationBloc;
    late status_repository.StatusRepository statusRepository;
    late StreamController<AuthenticationState> authenticationStates;

    setUp(() {
      authenticationBloc = _MockAuthenticationBloc();
      statusRepository = _MockStatusRepository();
      authenticationStates = StreamController<AuthenticationState>.broadcast();
      whenListen(
        authenticationBloc,
        authenticationStates.stream,
        initialState: _authenticatedState(_accountA),
      );
      when(
        () => statusRepository.statusChanges,
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => statusRepository.getHomeTimeline(),
      ).thenAnswer(
        (_) async => status_repository.StatusPage(
          statuses: const [],
          hasMore: false,
        ),
      );
    });

    tearDown(() async {
      await authenticationStates.close();
    });

    testWidgets('recreates its list bloc when the active account changes', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, _) => RepositoryProvider.value(
              value: statusRepository,
              child: BlocProvider.value(
                value: authenticationBloc,
                child: const HomePage(),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpRouterApp(router);
      await tester.pump();
      verify(() => statusRepository.getHomeTimeline()).called(1);

      authenticationStates.add(_authenticatedState(_accountB));
      await tester.pump();
      await tester.pump();

      verify(() => statusRepository.getHomeTimeline()).called(1);
    });
  });
}

AuthenticationAuthenticated _authenticatedState(AuthenticatedAccount account) {
  return AuthenticationAuthenticated(
    AuthenticationSnapshot.authenticated(
      accounts: [account],
      activeAccount: account,
    ),
  );
}

const _accountA = AuthenticatedAccount(
  id: 'account-a',
  name: 'Account A',
  screenName: 'account_a',
);

const _accountB = AuthenticatedAccount(
  id: 'account-b',
  name: 'Account B',
  screenName: 'account_b',
);
