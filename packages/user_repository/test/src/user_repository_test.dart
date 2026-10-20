import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:user_api_client/user_api_client.dart';
import 'package:user_repository/user_repository.dart';

class _MockUserApiClient extends Mock implements UserApiClient {}

void main() {
  group(UserRepository, () {
    late UserApiClient userApiClient;
    late UserRepository subject;

    setUp(() {
      userApiClient = _MockUserApiClient();
      subject = UserRepository(userApiClient: userApiClient);
    });

    group('list API failures', () {
      for (final endpoint in ['friends', 'followers', 'requests', 'blocked']) {
        for (final message in [null, '请求太频繁，请稍后再试']) {
          test(
            'preserves API feedback from $endpoint with message=$message',
            () async {
              Future<List<UserResponse>> fetch() => switch (endpoint) {
                'friends' => userApiClient.getFriends('owner', page: 2),
                'followers' => userApiClient.getFollowers('owner', page: 2),
                'requests' => userApiClient.getFollowRequests(page: 2),
                _ => userApiClient.getBlockedUsers(page: 2),
              };
              when(fetch).thenThrow(
                UserApiClientApiFailure(statusCode: 403, message: message),
              );
              final request = switch (endpoint) {
                'friends' => subject.getFriends('owner', page: 2),
                'followers' => subject.getFollowers('owner', page: 2),
                'requests' => subject.getFollowRequests(page: 2),
                _ => subject.getBlockedUsers(page: 2),
              };
              await expectLater(
                request,
                throwsA(
                  isA<UserRepositoryApiFailure>()
                      .having((error) => error.statusCode, 'statusCode', 403)
                      .having((error) => error.message, 'message', message),
                ),
              );
              verify(fetch).called(1);
            },
          );
        }
      }
    });

    group('isFollowing', () {
      test('forwards both user identifiers', () async {
        when(
          () => userApiClient.isFollowing(
            userId: 'peer',
            targetUserId: 'account',
          ),
        ).thenAnswer((_) async => true);

        expect(
          await subject.isFollowing(
            userId: 'peer',
            targetUserId: 'account',
          ),
          isTrue,
        );
        verify(
          () => userApiClient.isFollowing(
            userId: 'peer',
            targetUserId: 'account',
          ),
        ).called(1);
      });
    });

    group('isBlocked', () {
      test('forwards the user identifier', () async {
        when(
          () => userApiClient.isBlocked('peer'),
        ).thenAnswer((_) async => true);

        expect(await subject.isBlocked('peer'), isTrue);
        verify(() => userApiClient.isBlocked('peer')).called(1);
      });
    });

    group('setBlocked', () {
      test(
        'forwards the requested state and invalidates the cached profile',
        () async {
          subject.cacheUser(
            const UserProfile(
              id: 'peer',
              name: 'Peer',
              screenName: 'peer',
            ),
          );
          when(
            () => userApiClient.setBlocked('peer', blocked: true),
          ).thenAnswer((_) async => true);

          expect(await subject.setBlocked('peer', blocked: true), isTrue);
          expect(subject.getCachedUser('peer'), isNull);
          verify(
            () => userApiClient.setBlocked('peer', blocked: true),
          ).called(1);
        },
      );
    });

    group('getFriends', () {
      test('forwards the page and maps and caches users', () async {
        when(
          () => userApiClient.getFriends('owner', page: 2),
        ).thenAnswer((_) async => [_response]);
        final users = await subject.getFriends('owner', page: 2);
        expect(users, [_profile]);
        expect(subject.getCachedUser(_profile.id), _profile);
        verify(() => userApiClient.getFriends('owner', page: 2)).called(1);
      });
      test('returns an empty page when pagination ends', () async {
        when(
          () => userApiClient.getFriends('owner', page: 3),
        ).thenAnswer((_) async => []);
        expect(await subject.getFriends('owner', page: 3), isEmpty);
      });
      test('propagates failures for the requested page', () async {
        when(
          () => userApiClient.getFriends('owner', page: 2),
        ).thenThrow(const UserApiClientUnknownFailure());
        await expectLater(
          subject.getFriends('owner', page: 2),
          throwsA(isA<UserApiClientUnknownFailure>()),
        );
      });
    });

    group('getFollowers', () {
      test('forwards the page and maps and caches users', () async {
        when(
          () => userApiClient.getFollowers('owner', page: 2),
        ).thenAnswer((_) async => [_response]);
        final users = await subject.getFollowers('owner', page: 2);
        expect(users, [_profile]);
        expect(subject.getCachedUser(_profile.id), _profile);
        verify(() => userApiClient.getFollowers('owner', page: 2)).called(1);
      });
      test('returns an empty page when pagination ends', () async {
        when(
          () => userApiClient.getFollowers('owner', page: 3),
        ).thenAnswer((_) async => []);
        expect(await subject.getFollowers('owner', page: 3), isEmpty);
      });
      test('propagates failures for the requested page', () async {
        when(
          () => userApiClient.getFollowers('owner', page: 2),
        ).thenThrow(const UserApiClientUnknownFailure());
        await expectLater(
          subject.getFollowers('owner', page: 2),
          throwsA(isA<UserApiClientUnknownFailure>()),
        );
      });
    });

    group('setFollowing', () {
      for (final following in [true, false]) {
        test(
          'forwards following=$following and invalidates cached profiles',
          () async {
            subject.cacheUser(_profile);
            when(
              () => userApiClient.setFollowing('peer', following: following),
            ).thenAnswer((_) async => following);
            expect(
              await subject.setFollowing('peer', following: following),
              following,
            );
            expect(subject.getCachedUser(_profile.id), isNull);
            verify(
              () => userApiClient.setFollowing('peer', following: following),
            ).called(1);
            verifyNoMoreInteractions(userApiClient);
          },
        );
      }
      for (final message in [' 已发出关注请求，请等待确认。 ', '', '  ', null]) {
        test(
          'exposes follow feedback and retains cache for message=$message',
          () async {
            subject.cacheUser(_profile);
            when(
              () => userApiClient.setFollowing('peer', following: true),
            ).thenThrow(
              UserApiClientApiFailure(statusCode: 403, message: message),
            );
            await expectLater(
              subject.setFollowing('peer', following: true),
              throwsA(
                isA<FollowActionFailure>().having(
                  (error) => error.message,
                  'message',
                  message != null && message.trim().isNotEmpty
                      ? message.trim()
                      : null,
                ),
              ),
            );
            expect(subject.getCachedUser(_profile.id), _profile);
            verify(
              () => userApiClient.setFollowing('peer', following: true),
            ).called(1);
          },
        );
      }
      test('retains cached profiles on failure', () async {
        subject.cacheUser(_profile);
        when(
          () => userApiClient.setFollowing('peer', following: true),
        ).thenThrow(const UserApiClientUnknownFailure());
        await expectLater(
          subject.setFollowing('peer', following: true),
          throwsA(isA<UserApiClientUnknownFailure>()),
        );
        expect(subject.getCachedUser(_profile.id), _profile);
      });
    });

    group('cacheUser', () {
      test('makes a profile summary available synchronously', () {
        subject.cacheUser(_summary);

        expect(subject.getCachedUser(_summary.id), _summary);
      });

      test(
        'retains existing profile fields when a later summary omits them',
        () {
          subject
            ..cacheUser(_profile)
            ..cacheUser(_summary);

          expect(subject.getCachedUser(_profile.id), _profile);
        },
      );
    });

    group('getUser', () {
      test('returns and caches the mapped $UserProfile', () async {
        when(
          () => userApiClient.getUser(_profile.id),
        ).thenAnswer((_) async => _response);

        final result = await subject.getUser(_profile.id);

        expect(result, _profile);
        expect(subject.getCachedUser(_profile.id), _profile);
        verify(() => userApiClient.getUser(_profile.id)).called(1);
      });
    });

    group('getNotificationCounts', () {
      test('returns mapped $UserNotificationCounts', () async {
        when(
          () => userApiClient.getNotificationCounts(),
        ).thenAnswer((_) async => _notificationResponse);

        final result = await subject.getNotificationCounts();

        expect(result, _notificationCounts);
        verify(() => userApiClient.getNotificationCounts()).called(1);
      });
    });
  });
}

const _notificationResponse = NotificationCountsResponse(
  mentions: 2,
  directMessages: 3,
  friendRequests: 4,
);

const _notificationCounts = UserNotificationCounts(
  mentions: 2,
  directMessages: 3,
  friendRequests: 4,
);

const _summary = UserProfile(
  id: 'user-a',
  name: '饭友 A',
  screenName: 'fanfou_a',
);

const _response = UserResponse(
  id: 'user-a',
  name: '饭友 A',
  screenName: 'fanfou_a',
  avatarUrl: 'https://example.com/avatar.png',
  description: '写点什么。',
  location: '上海',
  url: 'https://example.com',
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

const _profile = UserProfile(
  id: 'user-a',
  name: '饭友 A',
  screenName: 'fanfou_a',
  avatarUrl: 'https://example.com/avatar.png',
  description: '写点什么。',
  location: '上海',
  url: 'https://example.com',
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
