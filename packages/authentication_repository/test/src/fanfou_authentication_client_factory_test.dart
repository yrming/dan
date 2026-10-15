import 'package:authentication_repository/authentication_repository.dart';
import 'package:test/test.dart';

void main() {
  group(FanfouAuthenticationClientFactory, () {
    group('constructor', () {
      test('rejects empty consumer credentials', () {
        expect(
          () => FanfouAuthenticationClientFactory(
            consumerKey: '',
            consumerSecret: 'secret',
          ),
          throwsArgumentError,
        );
        expect(
          () => FanfouAuthenticationClientFactory(
            consumerKey: 'key',
            consumerSecret: '',
          ),
          throwsArgumentError,
        );
      });
    });

    group('call', () {
      test('creates a fresh client for every invocation', () {
        final subject = FanfouAuthenticationClientFactory(
          consumerKey: 'key',
          consumerSecret: 'secret',
        );

        final firstClient = subject();
        final secondClient = subject();

        expect(firstClient, isNot(same(secondClient)));
        expect(firstClient.oauth.baseUrl, 'https://api.fanfou.com');
        expect(firstClient.oauth.oauthBaseUrl, 'https://fanfou.com');
        expect(firstClient.oauth.oauthToken, isNull);
        expect(firstClient.oauth.oauthTokenSecret, isNull);
        firstClient.close();
        secondClient.close();
      });

      test('configures only the supplied account session', () {
        final subject = FanfouAuthenticationClientFactory(
          consumerKey: 'key',
          consumerSecret: 'secret',
        );
        const session = AuthenticationSession(
          accountId: 'account-id',
          token: 'token',
          tokenSecret: 'token-secret',
        );

        final authenticatedClient = subject(session: session);
        final unauthenticatedClient = subject();

        expect(authenticatedClient.oauth.oauthToken, session.token);
        expect(
          authenticatedClient.oauth.oauthTokenSecret,
          session.tokenSecret,
        );
        expect(unauthenticatedClient.oauth.oauthToken, isNull);
        expect(unauthenticatedClient.oauth.oauthTokenSecret, isNull);
        authenticatedClient.close();
        unauthenticatedClient.close();
      });
    });
  });
}
