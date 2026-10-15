import 'package:authentication_repository/authentication_repository.dart';
import 'package:test/test.dart';

void main() {
  group(AuthenticationSnapshot, () {
    const account = AuthenticatedAccount(
      id: 'account-id',
      name: 'Dash',
      screenName: 'dash',
    );

    test('copies the account list into an immutable collection', () {
      final accounts = <AuthenticatedAccount>[account];
      final snapshot = AuthenticationSnapshot.authenticated(
        accounts: accounts,
        activeAccount: account,
      );
      accounts.clear();

      expect(snapshot.accounts, const [account]);
      expect(snapshot.accounts.clear, throwsUnsupportedError);
    });

    test('supports value equality', () {
      expect(
        AuthenticationSnapshot.authenticated(
          accounts: const [account],
          activeAccount: account,
        ),
        equals(
          AuthenticationSnapshot.authenticated(
            accounts: const [account],
            activeAccount: account,
          ),
        ),
      );
    });

    test('does not expose account metadata in its string representation', () {
      final snapshot = AuthenticationSnapshot.authenticated(
        accounts: const [account],
        activeAccount: account,
      );

      expect(snapshot.toString(), isNot(contains(account.id)));
      expect(snapshot.toString(), isNot(contains(account.screenName)));
    });
  });
}
