import 'package:authentication_repository/authentication_repository.dart';
import 'package:test/test.dart';

void main() {
  group(AuthenticatedAccount, () {
    test('supports value equality', () {
      const account = AuthenticatedAccount(
        id: 'account-id',
        name: 'Dash',
        screenName: 'dash',
        avatarUrl: 'https://example.com/avatar.png',
        description: 'Dash biography',
        location: 'Shanghai',
        url: 'https://fanfou.com/dash',
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

      expect(
        account,
        equals(
          const AuthenticatedAccount(
            id: 'account-id',
            name: 'Dash',
            screenName: 'dash',
            avatarUrl: 'https://example.com/avatar.png',
            description: 'Dash biography',
            location: 'Shanghai',
            url: 'https://fanfou.com/dash',
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
          ),
        ),
      );
    });

    test('does not expose account metadata in its string representation', () {
      const account = AuthenticatedAccount(
        id: 'sensitive-account-id',
        name: 'Sensitive Name',
        screenName: 'sensitive_screen_name',
      );

      expect(account.toString(), isNot(contains(account.id)));
      expect(account.toString(), isNot(contains(account.name)));
      expect(account.toString(), isNot(contains(account.screenName)));
    });
  });
}
