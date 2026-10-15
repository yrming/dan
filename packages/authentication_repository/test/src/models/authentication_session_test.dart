import 'package:authentication_repository/authentication_repository.dart';
import 'package:test/test.dart';

void main() {
  group(AuthenticationSession, () {
    test('is valid when both OAuth credential values are present', () {
      const session = AuthenticationSession(
        accountId: 'account-id',
        token: 'access-token',
        tokenSecret: 'access-secret',
      );

      expect(session.isValid, isTrue);
    });

    test('is invalid when any required value is missing', () {
      const missingToken = AuthenticationSession(
        accountId: 'account-id',
        token: '',
        tokenSecret: 'access-secret',
      );
      const missingSecret = AuthenticationSession(
        accountId: 'account-id',
        token: 'access-token',
        tokenSecret: '',
      );
      const missingAccount = AuthenticationSession(
        accountId: '',
        token: 'access-token',
        tokenSecret: 'access-secret',
      );

      expect(missingToken.isValid, isFalse);
      expect(missingSecret.isValid, isFalse);
      expect(missingAccount.isValid, isFalse);
    });

    test('redacts credentials from its string representation', () {
      const session = AuthenticationSession(
        accountId: 'account-id',
        token: 'access-token',
        tokenSecret: 'access-secret',
      );

      expect(session.toString(), isNot(contains(session.token)));
      expect(session.toString(), isNot(contains(session.tokenSecret)));
      expect(session.toString(), contains('redacted'));
    });
  });
}
