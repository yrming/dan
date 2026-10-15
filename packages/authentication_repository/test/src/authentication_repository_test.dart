import 'package:authentication_repository/authentication_repository.dart';
import 'package:fanfou/fanfou.dart' as fanfou;
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockFanfouClient extends Mock implements fanfou.FanfouClient {}

class _MockOAuthClient extends Mock implements fanfou.OAuthClient {}

class _MockAccountApi extends Mock implements fanfou.AccountApi {}

class _MockSessionStorage extends Mock
    implements AuthenticationSessionStorage {}

void main() {
  group(AuthenticationRepository, () {
    late AuthenticationClientFactory clientFactory;
    late List<AuthenticationSession?> createdClientSessions;
    late fanfou.FanfouClient fanfouClient;
    late fanfou.OAuthClient oauthClient;
    late fanfou.AccountApi accountApi;
    late AuthenticationSessionStorage sessionStorage;
    late AuthenticationRepository subject;

    setUpAll(() {
      registerFallbackValue(_accountA);
      registerFallbackValue(_sessionA);
    });

    setUp(() {
      fanfouClient = _MockFanfouClient();
      oauthClient = _MockOAuthClient();
      accountApi = _MockAccountApi();
      sessionStorage = _MockSessionStorage();
      when(() => fanfouClient.oauth).thenReturn(oauthClient);
      when(() => fanfouClient.account).thenReturn(accountApi);
      createdClientSessions = [];
      clientFactory = ({session}) {
        createdClientSessions.add(session);
        return fanfouClient;
      };
      subject = AuthenticationRepository(
        clientFactory: clientFactory,
        sessionStorage: sessionStorage,
      );
    });

    tearDown(() async {
      await subject.close();
    });

    Future<void> restoreAccountA({
      List<AuthenticatedAccount> accounts = const [_accountA],
    }) async {
      when(
        () => sessionStorage.readAccounts(),
      ).thenAnswer((_) async => accounts);
      when(() => sessionStorage.readActiveAccountId()).thenAnswer(
        (_) async => _accountA.id,
      );
      when(() => sessionStorage.readSession(_accountA.id)).thenAnswer(
        (_) async => _sessionA,
      );
      when(() => accountApi.verifyCredentials(format: 'html')).thenAnswer(
        (_) async => _fanfouUserA,
      );
      when(
        () => sessionStorage.setActiveAccountId(_accountA.id),
      ).thenAnswer((_) async {});

      await subject.restoreAccounts();
    }

    Future<Uri> beginOAuth() async {
      when(
        () => oauthClient.getRequestToken(
          callbackUrl: _oauthCallbackUri.toString(),
        ),
      ).thenAnswer(
        (_) async => {
          'oauth_token': _requestToken,
          'oauth_token_secret': _requestTokenSecret,
        },
      );
      when(
        () => oauthClient.getAuthorizationUrl(
          _requestToken,
          callbackUrl: _oauthCallbackUri.toString(),
        ),
      ).thenReturn(_authorizationUri.toString());

      return subject.beginOAuthAuthorization(callbackUri: _oauthCallbackUri);
    }

    test('starts with an unknown empty authentication snapshot', () {
      expect(
        subject.currentAuthentication,
        AuthenticationSnapshot.unknown(),
      );
    });

    group('createClientForActiveAccount', () {
      test('creates a client for the current active account session', () async {
        await restoreAccountA();
        clearInteractions(sessionStorage);
        clearInteractions(fanfouClient);
        clearInteractions(accountApi);
        createdClientSessions.clear();

        final result = await subject.createClientForActiveAccount();

        expect(result, same(fanfouClient));
        expect(createdClientSessions, const [_sessionA]);
        verify(() => sessionStorage.readSession(_accountA.id)).called(1);
        verifyNever(() => accountApi.verifyCredentials(format: 'html'));
        verifyNever(() => fanfouClient.close());
      });

      test(
        'throws $AuthenticationUnknownFailure when no account is active',
        () {
          expect(
            subject.createClientForActiveAccount(),
            throwsA(isA<AuthenticationUnknownFailure>()),
          );
          verifyNever(() => sessionStorage.readSession(any()));
        },
      );

      test(
        'throws $AccountUnavailableFailure when the session is missing',
        () async {
          await restoreAccountA();
          clearInteractions(sessionStorage);
          createdClientSessions.clear();
          when(
            () => sessionStorage.readSession(_accountA.id),
          ).thenAnswer((_) async => null);

          await expectLater(
            subject.createClientForActiveAccount(),
            throwsA(
              isA<AccountUnavailableFailure>().having(
                (failure) => failure.accountId,
                'accountId',
                _accountA.id,
              ),
            ),
          );
          expect(createdClientSessions, isEmpty);
        },
      );

      test(
        'throws $AuthenticationStorageFailure for storage failures',
        () async {
          await restoreAccountA();
          clearInteractions(sessionStorage);
          createdClientSessions.clear();
          when(
            () => sessionStorage.readSession(_accountA.id),
          ).thenThrow(Exception('storage failed'));

          await expectLater(
            subject.createClientForActiveAccount(),
            throwsA(isA<AuthenticationStorageFailure>()),
          );
          expect(createdClientSessions, isEmpty);
        },
      );
    });

    group('updateAccount', () {
      test(
        'persists refreshed metadata and updates the active snapshot',
        () async {
          await restoreAccountA();
          clearInteractions(sessionStorage);
          const updatedAccount = AuthenticatedAccount(
            id: 'account-a',
            name: 'Updated Account A',
            screenName: 'account_a',
            description: 'Updated biography',
            location: 'Beijing',
            followersCount: 20,
            friendsCount: 9,
            favoritesCount: 6,
            statusesCount: 50,
            gender: '男',
            photoCount: 10,
            createdAt: 'Wed Nov 02 07:49:55 +0000 2011',
            birthday: '1990-01-02',
          );
          when(
            () => sessionStorage.upsertAccount(
              account: updatedAccount,
              session: _sessionA,
            ),
          ).thenAnswer((_) async {});
          when(
            () => sessionStorage.readSession(updatedAccount.id),
          ).thenAnswer((_) async => _sessionA);

          final result = await subject.updateAccount(updatedAccount);

          expect(result, updatedAccount);
          expect(subject.currentAuthentication.activeAccount, updatedAccount);
          expect(subject.currentAuthentication.accounts, const [
            updatedAccount,
          ]);
          verify(() => sessionStorage.readSession(updatedAccount.id)).called(1);
          verify(
            () => sessionStorage.upsertAccount(
              account: updatedAccount,
              session: _sessionA,
            ),
          ).called(1);
        },
      );

      test('throws account not found for an unknown identifier', () async {
        await restoreAccountA();
        clearInteractions(sessionStorage);

        await expectLater(
          subject.updateAccount(_accountB),
          throwsA(
            isA<AccountNotFoundFailure>().having(
              (failure) => failure.accountId,
              'accountId',
              _accountB.id,
            ),
          ),
        );

        verifyNever(() => sessionStorage.readSession(any()));
        verifyNever(
          () => sessionStorage.upsertAccount(
            account: any(named: 'account'),
            session: any(named: 'session'),
          ),
        );
      });

      test('maps storage write failures', () async {
        await restoreAccountA();
        clearInteractions(sessionStorage);
        when(
          () => sessionStorage.readSession(_accountA.id),
        ).thenAnswer((_) async => _sessionA);
        when(
          () => sessionStorage.upsertAccount(
            account: _accountA,
            session: _sessionA,
          ),
        ).thenThrow(StateError('write failed'));

        await expectLater(
          subject.updateAccount(_accountA),
          throwsA(isA<AuthenticationStorageFailure>()),
        );

        expect(subject.currentAuthentication.activeAccount, _accountA);
      });
    });

    group('restoreAccounts', () {
      test('emits unauthenticated when no stored accounts exist', () async {
        when(() => sessionStorage.readAccounts()).thenAnswer((_) async => []);
        when(() => sessionStorage.readActiveAccountId()).thenAnswer(
          (_) async => null,
        );
        when(
          () => sessionStorage.setActiveAccountId(null),
        ).thenAnswer((_) async {});

        final result = await subject.restoreAccounts();

        expect(result, AuthenticationSnapshot.unauthenticated());
        verify(() => sessionStorage.setActiveAccountId(null)).called(1);
        verifyNever(() => sessionStorage.readSession(any()));
      });

      test(
        'restores the previously active account from multiple accounts',
        () async {
          when(() => sessionStorage.readAccounts()).thenAnswer(
            (_) async => [_accountA, _accountB],
          );
          when(() => sessionStorage.readActiveAccountId()).thenAnswer(
            (_) async => _accountB.id,
          );
          when(() => sessionStorage.readSession(_accountB.id)).thenAnswer(
            (_) async => _sessionB,
          );
          when(() => accountApi.verifyCredentials(format: 'html')).thenAnswer(
            (_) async => _fanfouUserB,
          );
          when(
            () => sessionStorage.setActiveAccountId(_accountB.id),
          ).thenAnswer((_) async {});

          final result = await subject.restoreAccounts();

          expect(
            result,
            AuthenticationSnapshot.authenticated(
              accounts: const [_accountA, _accountB],
              activeAccount: _accountB,
            ),
          );
          verify(() => sessionStorage.readSession(_accountB.id)).called(1);
          verifyNever(() => sessionStorage.readSession(_accountA.id));
          expect(createdClientSessions, const [_sessionB]);
          verify(() => fanfouClient.close()).called(1);
        },
      );

      test(
        'removes a rejected active account and falls back to the next one',
        () async {
          when(() => sessionStorage.readAccounts()).thenAnswer(
            (_) async => [_accountA, _accountB],
          );
          when(() => sessionStorage.readActiveAccountId()).thenAnswer(
            (_) async => _accountA.id,
          );
          when(() => sessionStorage.readSession(_accountA.id)).thenAnswer(
            (_) async => _sessionA,
          );
          when(() => accountApi.verifyCredentials(format: 'html')).thenThrow(
            fanfou.FanfouApiException(401, 'sensitive response body'),
          );
          when(() => sessionStorage.deleteAccount(_accountA.id)).thenAnswer(
            (_) async {},
          );
          when(() => sessionStorage.readSession(_accountB.id)).thenAnswer(
            (_) async => _sessionB,
          );
          when(() => accountApi.verifyCredentials(format: 'html')).thenAnswer(
            (_) async => _fanfouUserB,
          );
          when(
            () => sessionStorage.setActiveAccountId(_accountB.id),
          ).thenAnswer((_) async {});

          final result = await subject.restoreAccounts();

          expect(result.accounts, const [_accountB]);
          expect(result.activeAccount, _accountB);
          expect(createdClientSessions, const [_sessionA, _sessionB]);
          verify(() => sessionStorage.deleteAccount(_accountA.id)).called(1);
        },
      );

      test(
        'preserves every account when active account verification is retryable',
        () async {
          when(() => sessionStorage.readAccounts()).thenAnswer(
            (_) async => [_accountA, _accountB],
          );
          when(() => sessionStorage.readActiveAccountId()).thenAnswer(
            (_) async => _accountA.id,
          );
          when(() => sessionStorage.readSession(_accountA.id)).thenAnswer(
            (_) async => _sessionA,
          );
          when(() => accountApi.verifyCredentials(format: 'html')).thenThrow(
            fanfou.FanfouApiException(503, 'sensitive response body'),
          );

          await expectLater(
            subject.restoreAccounts(),
            throwsA(
              isA<AuthenticationApiFailure>().having(
                (failure) => failure.statusCode,
                'statusCode',
                503,
              ),
            ),
          );
          expect(
            subject.currentAuthentication,
            AuthenticationSnapshot.unknown(
              accounts: const [_accountA, _accountB],
            ),
          );
          expect(createdClientSessions, const [_sessionA]);
          verifyNever(() => sessionStorage.deleteAccount(any()));
        },
      );

      test(
        'throws storage failure when account metadata cannot be read',
        () async {
          when(
            () => sessionStorage.readAccounts(),
          ).thenThrow(Exception('read failed'));

          await expectLater(
            subject.restoreAccounts(),
            throwsA(isA<AuthenticationStorageFailure>()),
          );
          expect(
            subject.currentAuthentication,
            AuthenticationSnapshot.unknown(),
          );
        },
      );
    });

    group('addAccount', () {
      test('adds a verified account and makes it active', () async {
        when(
          () => oauthClient.getAccessTokenWithXAuth(any(), any()),
        ).thenAnswer(
          (_) async => {
            'oauth_token': _sessionB.token,
            'oauth_token_secret': _sessionB.tokenSecret,
          },
        );
        when(() => accountApi.verifyCredentials(format: 'html')).thenAnswer(
          (_) async => _fanfouUserB,
        );
        when(
          () => sessionStorage.upsertAccount(
            account: any(named: 'account'),
            session: any(named: 'session'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => sessionStorage.setActiveAccountId(_accountB.id),
        ).thenAnswer((_) async {});
        final expectedSnapshot = AuthenticationSnapshot.authenticated(
          accounts: const [_accountB],
          activeAccount: _accountB,
        );
        final snapshots = expectLater(
          subject.authentication,
          emits(expectedSnapshot),
        );

        final result = await subject.addAccount(
          username: '  account-b  ',
          password: 'secret',
        );

        expect(result, _accountB);
        expect(subject.currentAuthentication, expectedSnapshot);
        expect(createdClientSessions, const [null]);
        verify(
          () => oauthClient.getAccessTokenWithXAuth('account-b', 'secret'),
        ).called(1);
        final capturedSession =
            verify(
                  () => sessionStorage.upsertAccount(
                    account: _accountB,
                    session: captureAny(named: 'session'),
                  ),
                ).captured.single
                as AuthenticationSession;
        expect(capturedSession.accountId, _accountB.id);
        expect(capturedSession.token, _sessionB.token);
        expect(capturedSession.tokenSecret, _sessionB.tokenSecret);
        verify(() => fanfouClient.close()).called(1);
        await snapshots;
      });

      test(
        'updates an existing account without creating a duplicate',
        () async {
          await restoreAccountA();
          const updatedAccount = AuthenticatedAccount(
            id: 'account-a',
            name: 'Updated A',
            screenName: 'account_a',
            avatarUrl: 'https://example.com/a-updated.png',
            url: 'https://fanfou.com/account_a',
          );
          final updatedFanfouUser = fanfou.User(
            id: updatedAccount.id,
            name: updatedAccount.name,
            screenName: updatedAccount.screenName,
            profileImageUrlLarge: updatedAccount.avatarUrl,
            url: updatedAccount.url,
          );
          when(
            () => oauthClient.getAccessTokenWithXAuth(any(), any()),
          ).thenAnswer(
            (_) async => {
              'oauth_token': 'updated-token',
              'oauth_token_secret': 'updated-secret',
            },
          );
          when(() => accountApi.verifyCredentials(format: 'html')).thenAnswer(
            (_) async => updatedFanfouUser,
          );
          when(
            () => sessionStorage.upsertAccount(
              account: any(named: 'account'),
              session: any(named: 'session'),
            ),
          ).thenAnswer((_) async {});
          when(
            () => sessionStorage.setActiveAccountId(updatedAccount.id),
          ).thenAnswer((_) async {});

          await subject.addAccount(username: 'account-a', password: 'secret');

          expect(subject.currentAuthentication.accounts, const [
            updatedAccount,
          ]);
          expect(subject.currentAuthentication.activeAccount, updatedAccount);
        },
      );

      test(
        'does not remove an existing account when another login fails',
        () async {
          await restoreAccountA();
          when(
            () => oauthClient.getAccessTokenWithXAuth(any(), any()),
          ).thenThrow(fanfou.FanfouApiException(401, 'invalid password'));

          await expectLater(
            subject.addAccount(username: 'account-b', password: 'wrong'),
            throwsA(isA<InvalidCredentialsFailure>()),
          );
          expect(subject.currentAuthentication.activeAccount, _accountA);
          expect(subject.currentAuthentication.accounts, const [_accountA]);
          verifyNever(() => sessionStorage.deleteAccount(any()));
          verifyNever(() => sessionStorage.clear());
        },
      );
    });

    group('OAuth authorization', () {
      test(
        'begins authorization without exposing the request-token secret',
        () async {
          final result = await beginOAuth();

          expect(result, _authorizationUri);
          expect(result.toString(), isNot(contains(_requestTokenSecret)));
          expect(createdClientSessions, const [null]);
          verify(
            () => oauthClient.getRequestToken(
              callbackUrl: _oauthCallbackUri.toString(),
            ),
          ).called(1);
        },
      );

      test(
        'completes OAuth, persists the account, and makes it active',
        () async {
          await beginOAuth();
          when(
            () => oauthClient.getAccessToken(
              _requestToken,
              verifier: _oauthVerifier,
            ),
          ).thenAnswer(
            (_) async => {
              'oauth_token': _sessionB.token,
              'oauth_token_secret': _sessionB.tokenSecret,
            },
          );
          when(() => accountApi.verifyCredentials(format: 'html')).thenAnswer(
            (_) async => _fanfouUserB,
          );
          when(
            () => sessionStorage.upsertAccount(
              account: any(named: 'account'),
              session: any(named: 'session'),
            ),
          ).thenAnswer((_) async {});
          when(
            () => sessionStorage.setActiveAccountId(_accountB.id),
          ).thenAnswer((_) async {});

          final result = await subject.completeOAuthAuthorization(
            _successfulOAuthCallbackUri,
          );

          expect(result, _accountB);
          expect(subject.currentAuthentication.activeAccount, _accountB);
          verify(
            () => oauthClient.getAccessToken(
              _requestToken,
              verifier: _oauthVerifier,
            ),
          ).called(1);
          final session =
              verify(
                    () => sessionStorage.upsertAccount(
                      account: _accountB,
                      session: captureAny(named: 'session'),
                    ),
                  ).captured.single
                  as AuthenticationSession;
          expect(session.accountId, _sessionB.accountId);
          expect(session.token, _sessionB.token);
          expect(session.tokenSecret, _sessionB.tokenSecret);
          verify(() => fanfouClient.close()).called(1);
        },
      );

      test(
        'completes OAuth when the callback does not include a verifier',
        () async {
          await beginOAuth();
          when(
            () => oauthClient.getAccessToken(_requestToken),
          ).thenAnswer(
            (_) async => {
              'oauth_token': _sessionB.token,
              'oauth_token_secret': _sessionB.tokenSecret,
            },
          );
          when(() => accountApi.verifyCredentials(format: 'html')).thenAnswer(
            (_) async => _fanfouUserB,
          );
          when(
            () => sessionStorage.upsertAccount(
              account: any(named: 'account'),
              session: any(named: 'session'),
            ),
          ).thenAnswer((_) async {});
          when(
            () => sessionStorage.setActiveAccountId(_accountB.id),
          ).thenAnswer((_) async {});

          final result = await subject.completeOAuthAuthorization(
            Uri.parse(
              'dev.yrm.dan://oauth/callback?oauth_token=$_requestToken',
            ),
          );

          expect(result, _accountB);
          expect(subject.currentAuthentication.activeAccount, _accountB);
          verify(
            () => oauthClient.getAccessToken(_requestToken),
          ).called(1);
          verify(
            () => sessionStorage.upsertAccount(
              account: _accountB,
              session: any(named: 'session'),
            ),
          ).called(1);
          verify(
            () => sessionStorage.setActiveAccountId(_accountB.id),
          ).called(1);
          verify(() => fanfouClient.close()).called(1);
        },
      );

      test('rejects a callback that is missing its token', () async {
        await beginOAuth();

        await expectLater(
          subject.completeOAuthAuthorization(
            Uri.parse(
              'dev.yrm.dan://oauth/callback?oauth_verifier=$_oauthVerifier',
            ),
          ),
          throwsA(isA<InvalidOAuthCallbackFailure>()),
        );
        verifyNever(
          () => oauthClient.getAccessToken(
            any(),
            verifier: any(named: 'verifier'),
          ),
        );
      });

      test('rejects a callback for a different request token', () async {
        await beginOAuth();

        await expectLater(
          subject.completeOAuthAuthorization(
            Uri.parse(
              'dev.yrm.dan://oauth/callback?oauth_token=other-token'
              '&oauth_verifier=$_oauthVerifier',
            ),
          ),
          throwsA(isA<OAuthAuthorizationStateMismatchFailure>()),
        );
      });

      test('reports authorization denied without exchanging a token', () async {
        await beginOAuth();

        await expectLater(
          subject.completeOAuthAuthorization(
            Uri.parse(
              'dev.yrm.dan://oauth/callback?denied=$_requestToken',
            ),
          ),
          throwsA(isA<OAuthAuthorizationDeniedFailure>()),
        );
        verifyNever(
          () => oauthClient.getAccessToken(
            any(),
            verifier: any(named: 'verifier'),
          ),
        );
      });

      test('rejects a callback with an unexpected target', () async {
        await beginOAuth();

        await expectLater(
          subject.completeOAuthAuthorization(
            Uri.parse(
              'dev.yrm.dan://attacker/callback?oauth_token=$_requestToken'
              '&oauth_verifier=$_oauthVerifier',
            ),
          ),
          throwsA(isA<InvalidOAuthCallbackFailure>()),
        );
      });

      test(
        'maps a request-token API response to a sanitized API failure',
        () async {
          when(
            () => oauthClient.getRequestToken(
              callbackUrl: _oauthCallbackUri.toString(),
            ),
          ).thenThrow(
            fanfou.FanfouApiException(503, 'sensitive response body'),
          );

          await expectLater(
            subject.beginOAuthAuthorization(callbackUri: _oauthCallbackUri),
            throwsA(
              isA<AuthenticationApiFailure>().having(
                (failure) => failure.statusCode,
                'statusCode',
                503,
              ),
            ),
          );
        },
      );

      test(
        'maps an access-token API response to a sanitized API failure',
        () async {
          await beginOAuth();
          when(
            () => oauthClient.getAccessToken(
              _requestToken,
              verifier: _oauthVerifier,
            ),
          ).thenThrow(
            fanfou.FanfouApiException(503, 'sensitive response body'),
          );

          await expectLater(
            subject.completeOAuthAuthorization(_successfulOAuthCallbackUri),
            throwsA(
              isA<AuthenticationApiFailure>().having(
                (failure) => failure.statusCode,
                'statusCode',
                503,
              ),
            ),
          );
        },
      );

      test(
        'requires a pending authorization before accepting a callback',
        () async {
          await expectLater(
            subject.completeOAuthAuthorization(_successfulOAuthCallbackUri),
            throwsA(isA<OAuthAuthorizationNotStartedFailure>()),
          );
        },
      );
    });

    group('switchAccount', () {
      test('verifies and activates the selected account', () async {
        await restoreAccountA(accounts: const [_accountA, _accountB]);
        when(() => sessionStorage.readSession(_accountB.id)).thenAnswer(
          (_) async => _sessionB,
        );
        when(() => accountApi.verifyCredentials(format: 'html')).thenAnswer(
          (_) async => _fanfouUserB,
        );
        when(
          () => sessionStorage.setActiveAccountId(_accountB.id),
        ).thenAnswer((_) async {});

        final result = await subject.switchAccount(_accountB.id);

        expect(result, _accountB);
        expect(subject.currentAuthentication.activeAccount, _accountB);
        expect(
          subject.currentAuthentication.accounts,
          const [_accountA, _accountB],
        );
        expect(createdClientSessions, const [_sessionA, _sessionB]);
      });

      test(
        'removes only the selected account when its session is rejected',
        () async {
          await restoreAccountA(accounts: const [_accountA, _accountB]);
          when(() => sessionStorage.readSession(_accountB.id)).thenAnswer(
            (_) async => _sessionB,
          );
          when(() => accountApi.verifyCredentials(format: 'html')).thenThrow(
            fanfou.FanfouApiException(401, 'expired'),
          );
          when(() => sessionStorage.deleteAccount(_accountB.id)).thenAnswer(
            (_) async {},
          );

          await expectLater(
            subject.switchAccount(_accountB.id),
            throwsA(isA<AccountUnavailableFailure>()),
          );
          expect(subject.currentAuthentication.activeAccount, _accountA);
          expect(subject.currentAuthentication.accounts, const [_accountA]);
          verifyNever(() => sessionStorage.deleteAccount(_accountA.id));
        },
      );

      test(
        'throws account not found without reading session storage',
        () async {
          await expectLater(
            subject.switchAccount('missing'),
            throwsA(isA<AccountNotFoundFailure>()),
          );
          verifyNever(() => sessionStorage.readSession(any()));
        },
      );
    });

    group('removeAccount', () {
      test(
        'removes an inactive account without changing the active account',
        () async {
          await restoreAccountA(accounts: const [_accountA, _accountB]);
          when(() => sessionStorage.deleteAccount(_accountB.id)).thenAnswer(
            (_) async {},
          );

          await subject.removeAccount(_accountB.id);

          expect(subject.currentAuthentication.activeAccount, _accountA);
          expect(subject.currentAuthentication.accounts, const [_accountA]);
        },
      );

      test(
        'activates the next account after removing the active account',
        () async {
          await restoreAccountA(accounts: const [_accountA, _accountB]);
          when(() => sessionStorage.deleteAccount(_accountA.id)).thenAnswer(
            (_) async {},
          );
          when(() => sessionStorage.readSession(_accountB.id)).thenAnswer(
            (_) async => _sessionB,
          );
          when(() => accountApi.verifyCredentials(format: 'html')).thenAnswer(
            (_) async => _fanfouUserB,
          );
          when(
            () => sessionStorage.setActiveAccountId(_accountB.id),
          ).thenAnswer((_) async {});

          await subject.removeAccount(_accountA.id);

          expect(subject.currentAuthentication.activeAccount, _accountB);
          expect(subject.currentAuthentication.accounts, const [_accountB]);
        },
      );

      test('emits unauthenticated after removing the only account', () async {
        await restoreAccountA();
        when(() => sessionStorage.deleteAccount(_accountA.id)).thenAnswer(
          (_) async {},
        );

        await subject.removeAccount(_accountA.id);

        expect(
          subject.currentAuthentication,
          AuthenticationSnapshot.unauthenticated(),
        );
      });
    });

    group('removeAllAccounts', () {
      test(
        'clears storage and emits an empty unauthenticated snapshot',
        () async {
          await restoreAccountA(accounts: const [_accountA, _accountB]);
          when(() => sessionStorage.clear()).thenAnswer((_) async {});

          await subject.removeAllAccounts();

          expect(
            subject.currentAuthentication,
            AuthenticationSnapshot.unauthenticated(),
          );
          verify(() => sessionStorage.clear()).called(1);
        },
      );
    });
  });
}

const _accountA = AuthenticatedAccount(
  id: 'account-a',
  name: 'Account A',
  screenName: 'account_a',
  avatarUrl: 'https://example.com/a.png',
  description: 'Account A biography',
  location: 'Shanghai',
  protected: true,
  following: false,
  followersCount: 12,
  friendsCount: 8,
  favoritesCount: 5,
  statusesCount: 42,
  gender: '男',
  photoCount: 7,
  createdAt: 'Wed Nov 02 07:49:55 +0000 2011',
  birthday: '1990-01-02',
);

const _accountB = AuthenticatedAccount(
  id: 'account-b',
  name: 'Account B',
  screenName: 'account_b',
  avatarUrl: 'https://example.com/b.png',
  description: 'Account B biography',
  location: 'Beijing',
  protected: false,
  following: true,
  followersCount: 21,
  friendsCount: 13,
  favoritesCount: 9,
  statusesCount: 84,
  gender: '女',
  photoCount: 14,
  createdAt: 'Thu Nov 03 07:49:55 +0000 2011',
  birthday: '1991-02-03',
);

const _sessionA = AuthenticationSession(
  accountId: 'account-a',
  token: 'token-a',
  tokenSecret: 'secret-a',
);

const _sessionB = AuthenticationSession(
  accountId: 'account-b',
  token: 'token-b',
  tokenSecret: 'secret-b',
);

final _fanfouUserA = fanfou.User(
  id: _accountA.id,
  name: _accountA.name,
  screenName: _accountA.screenName,
  profileImageUrlLarge: _accountA.avatarUrl,
  description: _accountA.description,
  location: _accountA.location,
  protected: _accountA.protected,
  following: _accountA.following,
  followersCount: _accountA.followersCount,
  friendsCount: _accountA.friendsCount,
  favouritesCount: _accountA.favoritesCount,
  statusesCount: _accountA.statusesCount,
  gender: _accountA.gender,
  photoCount: _accountA.photoCount,
  createdAt: _accountA.createdAt,
  birthday: _accountA.birthday,
);

final _fanfouUserB = fanfou.User(
  id: _accountB.id,
  name: _accountB.name,
  screenName: _accountB.screenName,
  profileImageUrlLarge: _accountB.avatarUrl,
  description: _accountB.description,
  location: _accountB.location,
  protected: _accountB.protected,
  following: _accountB.following,
  followersCount: _accountB.followersCount,
  friendsCount: _accountB.friendsCount,
  favouritesCount: _accountB.favoritesCount,
  statusesCount: _accountB.statusesCount,
  gender: _accountB.gender,
  photoCount: _accountB.photoCount,
  createdAt: _accountB.createdAt,
  birthday: _accountB.birthday,
);

const _requestToken = 'request-token';
const _requestTokenSecret = 'request-token-secret';
const _oauthVerifier = 'oauth-verifier';
final Uri _oauthCallbackUri = Uri.parse('dev.yrm.dan://oauth/callback');
final Uri _authorizationUri = Uri.parse(
  'https://fanfou.com/oauth/authorize?oauth_token=$_requestToken',
);
final Uri _successfulOAuthCallbackUri = Uri.parse(
  'dev.yrm.dan://oauth/callback?oauth_token=$_requestToken'
  '&oauth_verifier=$_oauthVerifier',
);
