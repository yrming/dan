import 'package:authentication_repository/authentication_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:dan/authentication/authentication.dart';
import 'package:dan/login/login.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthenticationRepository extends Mock
    implements AuthenticationRepository {}

class _MockOAuthAuthorizationService extends Mock
    implements OAuthAuthorizationService {}

void main() {
  group(LoginBloc, () {
    late AuthenticationRepository authenticationRepository;
    late OAuthAuthorizationService oauthAuthorizationService;

    setUpAll(() {
      registerFallbackValue(_callbackUri);
    });

    setUp(() {
      authenticationRepository = _MockAuthenticationRepository();
      oauthAuthorizationService = _MockOAuthAuthorizationService();
      when(() => oauthAuthorizationService.callbackUri).thenReturn(
        _callbackUri,
      );
    });

    LoginBloc buildSubject() => LoginBloc(
      authenticationRepository: authenticationRepository,
      oauthAuthorizationService: oauthAuthorizationService,
    );

    test('starts with an initial state', () {
      final bloc = buildSubject();
      addTearDown(bloc.close);

      expect(bloc.state, const LoginState());
    });

    group(LoginOAuthRequested, () {
      blocTest<LoginBloc, LoginState>(
        'opens authorization, completes the callback, and succeeds',
        setUp: () => _stubOAuthSuccess(
          authenticationRepository,
          oauthAuthorizationService,
        ),
        build: buildSubject,
        act: (bloc) => bloc.add(const LoginOAuthRequested()),
        expect: () => const <LoginState>[
          LoginState(status: LoginSubmissionStatus.oauthInProgress),
          LoginState(status: LoginSubmissionStatus.success),
        ],
        verify: (_) {
          verify(
            () => authenticationRepository.beginOAuthAuthorization(
              callbackUri: _callbackUri,
            ),
          ).called(1);
          verify(
            () => oauthAuthorizationService.authorize(_authorizationUri),
          ).called(1);
          verify(
            () => authenticationRepository.completeOAuthAuthorization(
              _successfulCallbackUri,
            ),
          ).called(1);
          verify(
            () => authenticationRepository.cancelOAuthAuthorization(),
          ).called(1);
        },
      );

      blocTest<LoginBloc, LoginState>(
        'ignores duplicate requests while OAuth is already in progress',
        build: buildSubject,
        seed: () => const LoginState(
          status: LoginSubmissionStatus.oauthInProgress,
        ),
        act: (bloc) => bloc.add(const LoginOAuthRequested()),
        expect: () => const <LoginState>[],
        verify: (_) {
          verifyNever(
            () => authenticationRepository.beginOAuthAuthorization(
              callbackUri: any(named: 'callbackUri'),
            ),
          );
          verifyNever(
            () => authenticationRepository.cancelOAuthAuthorization(),
          );
        },
      );

      blocTest<LoginBloc, LoginState>(
        'returns to initial state when browser authorization is cancelled',
        setUp: () {
          _stubOAuthStart(authenticationRepository);
          when(
            () => oauthAuthorizationService.authorize(_authorizationUri),
          ).thenThrow(const OAuthAuthorizationCancelled());
        },
        build: buildSubject,
        act: (bloc) => bloc.add(const LoginOAuthRequested()),
        expect: () => const <LoginState>[
          LoginState(status: LoginSubmissionStatus.oauthInProgress),
          LoginState(),
        ],
        verify: (_) {
          verifyNever(
            () => authenticationRepository.completeOAuthAuthorization(any()),
          );
          verify(
            () => authenticationRepository.cancelOAuthAuthorization(),
          ).called(1);
        },
      );

      blocTest<LoginBloc, LoginState>(
        'emits oauthFailure when authorization launch fails',
        setUp: () {
          _stubOAuthStart(authenticationRepository);
          when(
            () => oauthAuthorizationService.authorize(_authorizationUri),
          ).thenThrow(const OAuthAuthorizationLaunchFailure());
        },
        build: buildSubject,
        act: (bloc) => bloc.add(const LoginOAuthRequested()),
        expect: () => const <LoginState>[
          LoginState(status: LoginSubmissionStatus.oauthInProgress),
          LoginState(status: LoginSubmissionStatus.oauthFailure),
        ],
      );

      for (final testCase in <(Object, LoginSubmissionStatus)>[
        (
          const OAuthAuthorizationDeniedFailure(),
          LoginSubmissionStatus.oauthDenied,
        ),
        (
          const OAuthAuthorizationStateMismatchFailure(),
          LoginSubmissionStatus.oauthFailure,
        ),
        (
          const AuthenticationApiFailure(statusCode: 503),
          LoginSubmissionStatus.apiFailure,
        ),
        (
          const AuthenticationStorageFailure(),
          LoginSubmissionStatus.storageFailure,
        ),
        (
          const InvalidCredentialsFailure(),
          LoginSubmissionStatus.failure,
        ),
      ]) {
        blocTest<LoginBloc, LoginState>(
          'emits ${testCase.$2} when OAuth throws ${testCase.$1.runtimeType}',
          setUp: () {
            _stubOAuthStart(authenticationRepository);
            when(
              () => oauthAuthorizationService.authorize(_authorizationUri),
            ).thenAnswer((_) async => _successfulCallbackUri);
            when(
              () => authenticationRepository.completeOAuthAuthorization(
                _successfulCallbackUri,
              ),
            ).thenThrow(testCase.$1);
          },
          build: buildSubject,
          act: (bloc) => bloc.add(const LoginOAuthRequested()),
          expect: () => <LoginState>[
            const LoginState(status: LoginSubmissionStatus.oauthInProgress),
            LoginState(status: testCase.$2),
          ],
        );
      }
    });
  });
}

void _stubOAuthStart(
  AuthenticationRepository authenticationRepository,
) {
  when(
    () => authenticationRepository.beginOAuthAuthorization(
      callbackUri: _callbackUri,
    ),
  ).thenAnswer((_) async => _authorizationUri);
}

void _stubOAuthSuccess(
  AuthenticationRepository authenticationRepository,
  OAuthAuthorizationService oauthAuthorizationService,
) {
  _stubOAuthStart(authenticationRepository);
  when(
    () => oauthAuthorizationService.authorize(_authorizationUri),
  ).thenAnswer((_) async => _successfulCallbackUri);
  when(
    () => authenticationRepository.completeOAuthAuthorization(
      _successfulCallbackUri,
    ),
  ).thenAnswer((_) async => _account);
}

const _account = AuthenticatedAccount(
  id: 'account-id',
  name: 'Alice',
  screenName: 'alice',
);

final Uri _callbackUri = Uri.parse('dev.yrm.dan://oauth/callback');
final Uri _authorizationUri = Uri.parse(
  'https://fanfou.com/oauth/authorize?oauth_token=request-token',
);
final Uri _successfulCallbackUri = Uri.parse(
  'dev.yrm.dan://oauth/callback?oauth_token=request-token&oauth_verifier=pin',
);
