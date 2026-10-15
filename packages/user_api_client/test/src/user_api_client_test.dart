import 'package:fanfou/fanfou.dart' as fanfou;
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:user_api_client/user_api_client.dart';

class _MockFanfouClient extends Mock implements fanfou.FanfouClient {}

class _MockUsersApi extends Mock implements fanfou.UsersApi {}

class _MockAccountApi extends Mock implements fanfou.AccountApi {}

class _MockFriendshipsApi extends Mock implements fanfou.FriendshipsApi {}

class _MockBlocksApi extends Mock implements fanfou.BlocksApi {}

void main() {
  group(UserApiClient, () {
    late fanfou.FanfouClient fanfouClient;
    late fanfou.UsersApi usersApi;
    late fanfou.AccountApi accountApi;
    late UserApiClient subject;
    late fanfou.FriendshipsApi friendships;
    late fanfou.BlocksApi blocks;

    setUp(() {
      fanfouClient = _MockFanfouClient();
      usersApi = _MockUsersApi();
      friendships = _MockFriendshipsApi();
      blocks = _MockBlocksApi();
      when(() => fanfouClient.friendships).thenReturn(friendships);
      when(() => fanfouClient.blocks).thenReturn(blocks);
      accountApi = _MockAccountApi();
      when(() => fanfouClient.users).thenReturn(usersApi);
      when(() => fanfouClient.account).thenReturn(accountApi);
      when(() => fanfouClient.close()).thenReturn(null);
      subject = UserApiClient(clientFactory: () async => fanfouClient);
    });

    group('isFollowing', () {
      test('returns the relationship reported by the API', () async {
        when(
          () => friendships.exists(userA: 'peer', userB: 'account'),
        ).thenAnswer((_) async => true);

        expect(
          await subject.isFollowing(
            userId: 'peer',
            targetUserId: 'account',
          ),
          isTrue,
        );
        verify(
          () => friendships.exists(userA: 'peer', userB: 'account'),
        ).called(1);
        verify(() => fanfouClient.close()).called(1);
      });
    });

    group('setFollowing', () {
      for (final following in [true, false]) {
        test(
          'only calls the mutation endpoint for following=$following',
          () async {
            final user = fanfou.User(
              id: 'peer',
              name: 'Peer',
              screenName: 'peer',
              following: following,
            );
            if (following) {
              when(
                () => friendships.create('peer'),
              ).thenAnswer((_) async => user);
            } else {
              when(
                () => friendships.destroy('peer'),
              ).thenAnswer((_) async => user);
            }
            expect(
              await subject.setFollowing('peer', following: following),
              following,
            );
            if (following) {
              verify(() => friendships.create('peer')).called(1);
            } else {
              verify(() => friendships.destroy('peer')).called(1);
            }
            verifyNoMoreInteractions(friendships);
            verify(() => fanfouClient.close()).called(1);
          },
        );
      }
      test('sanitizes errors and closes the client', () async {
        when(
          () => friendships.create('peer'),
        ).thenThrow(fanfou.FanfouApiException(403, 'private'));
        await expectLater(
          subject.setFollowing('peer', following: true),
          throwsA(isA<UserApiClientApiFailure>()),
        );
        verify(() => fanfouClient.close()).called(1);
      });
      for (final body in [
        '{"error":" 已向 小婴 发出关注请求，请等待确认。 ","request":"/friendships/create.json"}',
        '{}',
        '{"error":"   "}',
        '{"error":42}',
        '[]',
        '<html>unavailable</html>',
      ]) {
        for (final following in [true, false]) {
          test(
            'extracts only error text from $body for following=$following',
            () async {
              when(() => friendships.create('peer')).thenThrow(
                fanfou.FanfouApiException(403, body),
              );
              when(() => friendships.destroy('peer')).thenThrow(
                fanfou.FanfouApiException(403, body),
              );
              await expectLater(
                subject.setFollowing('peer', following: following),
                throwsA(
                  isA<UserApiClientApiFailure>()
                      .having((error) => error.statusCode, 'statusCode', 403)
                      .having(
                        (error) => error.message,
                        'message',
                        body.contains('已向') ? '已向 小婴 发出关注请求，请等待确认。' : null,
                      ),
                ),
              );
              verify(() => fanfouClient.close()).called(1);
            },
          );
        }
      }
      test('reports an unconfirmed follow request', () async {
        when(() => friendships.create('peer')).thenAnswer((_) async => _user);
        expect(await subject.setFollowing('peer', following: true), isFalse);
      });
      test('sanitizes factory failures', () async {
        subject = UserApiClient(
          clientFactory: () async => throw StateError('session'),
        );
        await expectLater(
          subject.setFollowing('peer', following: true),
          throwsA(isA<UserApiClientUnknownFailure>()),
        );
      });
    });

    group('isBlocked', () {
      test('returns true when the blocks endpoint returns a user', () async {
        when(
          () => blocks.exists('peer', mode: 'lite'),
        ).thenAnswer((_) async => _user);

        expect(await subject.isBlocked('peer'), isTrue);
        verify(() => blocks.exists('peer', mode: 'lite')).called(1);
        verify(() => fanfouClient.close()).called(1);
      });

      test('returns false when the blocks endpoint returns 404', () async {
        when(
          () => blocks.exists('peer', mode: 'lite'),
        ).thenThrow(fanfou.FanfouApiException(404, '{"error":"Not found"}'));

        expect(await subject.isBlocked('peer'), isFalse);
        verify(() => fanfouClient.close()).called(1);
      });
    });

    group('setBlocked', () {
      for (final blocked in [true, false]) {
        test('calls the block mutation endpoint', () async {
          if (blocked) {
            when(
              () => blocks.create('peer', mode: 'lite'),
            ).thenAnswer((_) async => _user);
          } else {
            when(
              () => blocks.destroy('peer', mode: 'lite'),
            ).thenAnswer((_) async => _user);
          }

          expect(await subject.setBlocked('peer', blocked: blocked), blocked);
          if (blocked) {
            verify(() => blocks.create('peer', mode: 'lite')).called(1);
          } else {
            verify(() => blocks.destroy('peer', mode: 'lite')).called(1);
          }
          verify(() => fanfouClient.close()).called(1);
        });
      }
    });

    group('getNotificationCounts', () {
      test(
        'returns a typed $NotificationCountsResponse when the request succeeds',
        () async {
          when(
            () => accountApi.notification(),
          ).thenAnswer(
            (_) async => fanfou.NotificationCounts(
              mentions: 2,
              directMessages: 3,
              friendRequests: 4,
            ),
          );

          final result = await subject.getNotificationCounts();

          expect(result.mentions, 2);
          expect(result.directMessages, 3);
          expect(result.friendRequests, 4);
          verify(() => accountApi.notification()).called(1);
          verify(() => fanfouClient.close()).called(1);
        },
      );

      test('throws $UserApiClientApiFailure for API failures', () async {
        when(
          () => accountApi.notification(),
        ).thenThrow(fanfou.FanfouApiException(401, 'sensitive body'));

        await expectLater(
          subject.getNotificationCounts(),
          throwsA(
            isA<UserApiClientApiFailure>().having(
              (failure) => failure.statusCode,
              'statusCode',
              401,
            ),
          ),
        );
        verify(() => fanfouClient.close()).called(1);
      });
    });

    group('getFriends', () {
      test('requests the specified user and page with the page size', () async {
        when(
          () => usersApi.friends(
            id: 'owner',
            count: 60,
            page: 2,
            format: 'html',
          ),
        ).thenAnswer((_) async => [_user]);
        final users = await subject.getFriends('owner', page: 2);
        expect(users.single.id, _user.id);
        expect(users.single.avatarUrl, _user.profileImageUrlLarge);
        verify(
          () => usersApi.friends(
            id: 'owner',
            count: 60,
            page: 2,
            format: 'html',
          ),
        ).called(1);
        verify(() => fanfouClient.close()).called(1);
      });
      test('returns an empty terminal page', () async {
        when(
          () => usersApi.friends(
            id: 'owner',
            count: 60,
            page: 3,
            format: 'html',
          ),
        ).thenAnswer((_) async => []);
        expect(await subject.getFriends('owner', page: 3), isEmpty);
        verify(() => fanfouClient.close()).called(1);
      });
      test('sanitizes API errors and closes the client', () async {
        when(
          () => usersApi.friends(
            id: 'owner',
            count: 60,
            page: 2,
            format: 'html',
          ),
        ).thenThrow(fanfou.FanfouApiException(503, 'private response'));
        await expectLater(
          subject.getFriends('owner', page: 2),
          throwsA(
            isA<UserApiClientApiFailure>().having(
              (e) => e.statusCode,
              'statusCode',
              503,
            ),
          ),
        );
        verify(() => fanfouClient.close()).called(1);
      });
    });

    group('getFollowers', () {
      test('requests the specified user and page with the page size', () async {
        when(
          () => usersApi.followers(
            id: 'owner',
            count: 60,
            page: 2,
            format: 'html',
          ),
        ).thenAnswer((_) async => [_user]);
        final users = await subject.getFollowers('owner', page: 2);
        expect(users.single.id, _user.id);
        expect(users.single.avatarUrl, _user.profileImageUrlLarge);
        verify(
          () => usersApi.followers(
            id: 'owner',
            count: 60,
            page: 2,
            format: 'html',
          ),
        ).called(1);
        verify(() => fanfouClient.close()).called(1);
      });
      test('returns an empty terminal page', () async {
        when(
          () => usersApi.followers(
            id: 'owner',
            count: 60,
            page: 3,
            format: 'html',
          ),
        ).thenAnswer((_) async => []);
        expect(await subject.getFollowers('owner', page: 3), isEmpty);
        verify(() => fanfouClient.close()).called(1);
      });
      test('sanitizes API errors and closes the client', () async {
        when(
          () => usersApi.followers(
            id: 'owner',
            count: 60,
            page: 2,
            format: 'html',
          ),
        ).thenThrow(fanfou.FanfouApiException(503, 'private response'));
        await expectLater(
          subject.getFollowers('owner', page: 2),
          throwsA(
            isA<UserApiClientApiFailure>().having(
              (e) => e.statusCode,
              'statusCode',
              503,
            ),
          ),
        );
        verify(() => fanfouClient.close()).called(1);
      });
    });

    group('getBlockedUsers', () {
      test('requests the specified page with the relation page size', () async {
        when(
          () => blocks.blocking(count: 60, page: 2),
        ).thenAnswer((_) async => [_user]);
        final users = await subject.getBlockedUsers(page: 2);
        expect(users.single.id, _user.id);
        verify(() => blocks.blocking(count: 60, page: 2)).called(1);
        verify(() => fanfouClient.close()).called(1);
      });

      test('removes a blocked user through the blocks API', () async {
        when(
          () => blocks.destroy('blocked', mode: 'lite'),
        ).thenAnswer((_) async => _user);
        final user = await subject.removeBlockedUser('blocked');
        expect(user.id, _user.id);
        verify(() => blocks.destroy('blocked', mode: 'lite')).called(1);
        verify(() => fanfouClient.close()).called(1);
      });
    });

    group('getUser', () {
      test('returns a typed $UserResponse when the request succeeds', () async {
        when(
          () => usersApi.show(id: 'user-a', format: 'html'),
        ).thenAnswer((_) async => _user);

        final result = await subject.getUser('user-a');

        expect(result.id, _user.id);
        expect(result.name, _user.name);
        expect(result.screenName, _user.screenName);
        expect(result.avatarUrl, _user.profileImageUrlLarge);
        expect(result.description, _user.description);
        expect(result.url, _user.url);
        expect(result.protected, _user.protected);
        expect(result.following, _user.following);
        expect(result.followersCount, _user.followersCount);
        expect(result.gender, _user.gender);
        expect(result.photoCount, _user.photoCount);
        expect(result.createdAt, _user.createdAt);
        expect(result.birthday, _user.birthday);
        verify(() => fanfouClient.close()).called(1);
      });

      test('throws $UserApiClientApiFailure for API failures', () async {
        when(
          () => usersApi.show(id: 'user-a', format: 'html'),
        ).thenThrow(fanfou.FanfouApiException(404, 'sensitive body'));

        await expectLater(
          subject.getUser('user-a'),
          throwsA(
            isA<UserApiClientApiFailure>().having(
              (failure) => failure.statusCode,
              'statusCode',
              404,
            ),
          ),
        );
        verify(() => fanfouClient.close()).called(1);
      });

      test('throws $UserApiClientUnknownFailure for factory failures', () {
        subject = UserApiClient(
          clientFactory: () async => throw StateError('missing session'),
        );

        expect(
          subject.getUser('user-a'),
          throwsA(isA<UserApiClientUnknownFailure>()),
        );
        verifyNever(() => fanfouClient.close());
      });

      test('rejects an empty user identifier', () {
        expect(subject.getUser('  '), throwsArgumentError);
        verifyNever(() => fanfouClient.users);
      });
    });
  });
}

final _user = fanfou.User(
  id: 'user-a',
  name: '饭友 A',
  screenName: 'fanfou_a',
  profileImageUrl: 'https://example.com/avatar-small.png',
  profileImageUrlLarge: 'https://example.com/avatar-large.png',
  description: '写点什么。',
  location: '上海',
  url: 'https://example.com',
  protected: true,
  following: false,
  followersCount: 12,
  friendsCount: 8,
  favouritesCount: 5,
  statusesCount: 42,
  gender: '男',
  photoCount: 7,
  createdAt: 'Wed Nov 02 07:49:55 +0000 2011',
  birthday: '1990-01-02',
);
