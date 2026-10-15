import 'package:authentication_repository/authentication_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:dan/authentication/authentication.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthenticationRepository extends Mock
    implements AuthenticationRepository {}

void main() {
  group(AuthenticationBloc, () {
    late AuthenticationRepository authenticationRepository;

    setUp(() {
      authenticationRepository = _MockAuthenticationRepository();
      when(
        () => authenticationRepository.authentication,
      ).thenAnswer((_) => const Stream.empty());
    });

    test('starts with $AuthenticationInitial', () {
      expect(
        AuthenticationBloc(
          authenticationRepository: authenticationRepository,
        ).state,
        const AuthenticationInitial(),
      );
    });

    blocTest<AuthenticationBloc, AuthenticationState>(
      'emits loading then unauthenticated when no account is restored',
      setUp: () {
        when(() => authenticationRepository.restoreAccounts()).thenAnswer(
          (_) async => AuthenticationSnapshot.unauthenticated(),
        );
      },
      build: () => AuthenticationBloc(
        authenticationRepository: authenticationRepository,
      ),
      act: (bloc) => bloc.add(
        const AuthenticationSubscriptionRequested(),
      ),
      expect: () => <AuthenticationState>[
        const AuthenticationLoadInProgress(),
        AuthenticationUnauthenticated(
          AuthenticationSnapshot.unauthenticated(),
        ),
      ],
      verify: (_) {
        verify(() => authenticationRepository.restoreAccounts()).called(1);
        verify(() => authenticationRepository.authentication).called(1);
      },
    );

    blocTest<AuthenticationBloc, AuthenticationState>(
      'emits loading then authenticated when an account is restored',
      setUp: () {
        when(() => authenticationRepository.restoreAccounts()).thenAnswer(
          (_) async => AuthenticationSnapshot.authenticated(
            accounts: const [_account],
            activeAccount: _account,
          ),
        );
      },
      build: () => AuthenticationBloc(
        authenticationRepository: authenticationRepository,
      ),
      act: (bloc) => bloc.add(
        const AuthenticationSubscriptionRequested(),
      ),
      expect: () => <AuthenticationState>[
        const AuthenticationLoadInProgress(),
        AuthenticationAuthenticated(
          AuthenticationSnapshot.authenticated(
            accounts: const [_account],
            activeAccount: _account,
          ),
        ),
      ],
    );

    blocTest<AuthenticationBloc, AuthenticationState>(
      'emits repository authentication updates after restoration',
      setUp: () {
        when(() => authenticationRepository.restoreAccounts()).thenAnswer(
          (_) async => AuthenticationSnapshot.unauthenticated(),
        );
        when(
          () => authenticationRepository.authentication,
        ).thenAnswer(
          (_) => Stream.value(
            AuthenticationSnapshot.authenticated(
              accounts: const [_account],
              activeAccount: _account,
            ),
          ),
        );
      },
      build: () => AuthenticationBloc(
        authenticationRepository: authenticationRepository,
      ),
      act: (bloc) => bloc.add(
        const AuthenticationSubscriptionRequested(),
      ),
      expect: () => <AuthenticationState>[
        const AuthenticationLoadInProgress(),
        AuthenticationUnauthenticated(
          AuthenticationSnapshot.unauthenticated(),
        ),
        AuthenticationAuthenticated(
          AuthenticationSnapshot.authenticated(
            accounts: const [_account],
            activeAccount: _account,
          ),
        ),
      ],
    );

    blocTest<AuthenticationBloc, AuthenticationState>(
      'emits loading then failure when restoration throws',
      setUp: () {
        when(
          () => authenticationRepository.restoreAccounts(),
        ).thenThrow(const AuthenticationStorageFailure());
      },
      build: () => AuthenticationBloc(
        authenticationRepository: authenticationRepository,
      ),
      act: (bloc) => bloc.add(
        const AuthenticationSubscriptionRequested(),
      ),
      expect: () => const <AuthenticationState>[
        AuthenticationLoadInProgress(),
        AuthenticationRestoreFailure(),
      ],
    );

    blocTest<AuthenticationBloc, AuthenticationState>(
      'removes the active account when sign out is requested',
      setUp: () {
        when(
          () => authenticationRepository.currentAuthentication,
        ).thenReturn(
          AuthenticationSnapshot.authenticated(
            accounts: const [_account],
            activeAccount: _account,
          ),
        );
        when(
          () => authenticationRepository.removeAccount(_account.id),
        ).thenAnswer((_) async {});
      },
      build: () => AuthenticationBloc(
        authenticationRepository: authenticationRepository,
      ),
      act: (bloc) => bloc.add(const AuthenticationSignOutRequested()),
      expect: () => const <AuthenticationState>[],
      verify: (_) {
        verify(
          () => authenticationRepository.removeAccount(_account.id),
        ).called(1);
        verifyNever(() => authenticationRepository.removeAllAccounts());
      },
    );

    blocTest<AuthenticationBloc, AuthenticationState>(
      'switches accounts when an account switch is requested',
      setUp: () {
        when(
          () => authenticationRepository.switchAccount(_account.id),
        ).thenAnswer((_) async => _account);
      },
      build: () => AuthenticationBloc(
        authenticationRepository: authenticationRepository,
      ),
      act: (bloc) => bloc.add(
        const AuthenticationAccountSwitchRequested(_accountId),
      ),
      expect: () => const <AuthenticationState>[],
      verify: (_) {
        verify(
          () => authenticationRepository.switchAccount(_account.id),
        ).called(1);
      },
    );

    blocTest<AuthenticationBloc, AuthenticationState>(
      'restores accounts again when retry is requested after a failure',
      setUp: () {
        var attempts = 0;
        when(() => authenticationRepository.restoreAccounts()).thenAnswer((
          _,
        ) async {
          attempts += 1;
          if (attempts == 1) {
            throw const AuthenticationStorageFailure();
          }
          return AuthenticationSnapshot.unauthenticated();
        });
      },
      build: () => AuthenticationBloc(
        authenticationRepository: authenticationRepository,
      ),
      act: (bloc) async {
        final failure = bloc.stream.firstWhere(
          (state) => state is AuthenticationRestoreFailure,
        );
        bloc.add(const AuthenticationSubscriptionRequested());
        await failure;
        bloc.add(const AuthenticationSubscriptionRequested());
      },
      expect: () => <AuthenticationState>[
        const AuthenticationLoadInProgress(),
        const AuthenticationRestoreFailure(),
        const AuthenticationLoadInProgress(),
        AuthenticationUnauthenticated(
          AuthenticationSnapshot.unauthenticated(),
        ),
      ],
      verify: (_) {
        verify(() => authenticationRepository.restoreAccounts()).called(2);
      },
    );
  });
}

const _account = AuthenticatedAccount(
  id: _accountId,
  name: 'Account',
  screenName: 'account',
);

const _accountId = 'account-id';
