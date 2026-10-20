import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dan/profile/profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_repository/user_repository.dart';

class _MockUserRepository extends Mock implements UserRepository {}

const _first = UserProfile(id: 'a', name: 'A', screenName: 'a');
const _second = UserProfile(id: 'b', name: 'B', screenName: 'b');

void main() {
  group(FollowListCubit, () {
    for (final followers in [false, true]) {
      group(followers ? 'followers' : 'following', () {
        late UserRepository repository;
        late Future<List<UserProfile>> Function(int) fetch;
        late List<UserProfile> fullPage;
        late List<UserProfile> nextFullPage;

        setUp(() {
          repository = _MockUserRepository();
          fullPage = [
            _first,
            for (var i = 1; i < UserRepository.relationPageSize; i++)
              UserProfile(
                id: 'user-$i',
                name: 'User $i',
                screenName: 'user-$i',
              ),
          ];
          nextFullPage = [...fullPage.skip(1), _second];
          fetch = (page) => followers
              ? repository.getFollowers('owner', page: page)
              : repository.getFriends('owner', page: page);
          when(() => fetch(1)).thenAnswer((_) async => fullPage);
          when(() => fetch(2)).thenAnswer((_) async => nextFullPage);
          when(() => fetch(3)).thenAnswer((_) async => []);
        });

        FollowListCubit build() => FollowListCubit(
          repository: repository,
          userId: 'owner',
          followers: followers,
        );

        group('load', () {
          blocTest<FollowListCubit, FollowListState>(
            'starts loading and permits pagination after a full first page',
            build: build,
            act: (cubit) => cubit.load(),
            expect: () => [
              FollowListState(),
              FollowListState(users: fullPage, loading: false),
            ],
            verify: (_) => verify(() => fetch(1)).called(1),
          );
          for (final count in [1, 4, UserRepository.relationPageSize - 1]) {
            blocTest<FollowListCubit, FollowListState>(
              'ends pagination after a first page with $count users',
              setUp: () => when(() => fetch(1)).thenAnswer(
                (_) async => fullPage.take(count).toList(),
              ),
              build: build,
              act: (cubit) async {
                await cubit.load();
                await cubit.loadMore();
              },
              expect: () => [
                FollowListState(),
                FollowListState(
                  users: fullPage.take(count).toList(),
                  loading: false,
                  hasMore: false,
                ),
              ],
              verify: (_) {
                verify(() => fetch(1)).called(1);
                verifyNoMoreInteractions(repository);
              },
            );
          }
          blocTest<FollowListCubit, FollowListState>(
            'ends pagination when the first page is empty',
            setUp: () => when(() => fetch(1)).thenAnswer((_) async => []),
            build: build,
            act: (cubit) async {
              await cubit.load();
              await cubit.loadMore();
            },
            expect: () => [
              FollowListState(),
              FollowListState(loading: false, hasMore: false),
            ],
            verify: (_) => verifyNever(() => fetch(2)),
          );
          blocTest<FollowListCubit, FollowListState>(
            'retries the first page after an initial failure',
            build: build,
            act: (cubit) async {
              when(() => fetch(1)).thenThrow(StateError('offline'));
              await cubit.load();
              await cubit.loadMore();
              when(() => fetch(1)).thenAnswer((_) async => [_first]);
              await cubit.load();
            },
            expect: () => [
              FollowListState(),
              FollowListState(loading: false, error: true),
              FollowListState(),
              FollowListState(
                users: const [_first],
                loading: false,
                hasMore: false,
              ),
            ],
            verify: (_) {
              verify(() => fetch(1)).called(2);
              verifyNever(() => fetch(2));
            },
          );
        });

        group('loadMore', () {
          group('pagination failure feedback', () {
            for (final message in [null, '请求太频繁，请稍后再试']) {
              blocTest<FollowListCubit, FollowListState>(
                'preserves loaded users and retries the failed page '
                'with message=$message',
                setUp: () {
                  when(() => fetch(1)).thenThrow(
                    UserRepositoryApiFailure(statusCode: 403, message: message),
                  );
                },
                build: build,
                seed: () => FollowListState(users: fullPage, loading: false),
                act: (cubit) async {
                  await cubit.loadMore();
                  when(() => fetch(1)).thenAnswer((_) async => []);
                  await cubit.loadMore();
                },
                expect: () {
                  final initial = FollowListState(
                    users: fullPage,
                    loading: false,
                  );
                  return [
                    initial.copyWith(loadingMore: true),
                    initial.copyWith(
                      loadMoreError: true,
                      requestFailureMessage: message,
                    ),
                    initial.copyWith(loadingMore: true),
                    initial.copyWith(hasMore: false),
                  ];
                },
                verify: (cubit) {
                  expect(cubit.state.users, fullPage);
                  expect(cubit.state.requestFailureMessage, isNull);
                  verify(() => fetch(1)).called(2);
                },
              );
            }
          });

          blocTest<FollowListCubit, FollowListState>(
            'loads page two after the endpoint returns 60 users',
            setUp: () {
              when(() => fetch(1)).thenAnswer(
                (_) async => List.generate(
                  60,
                  (i) =>
                      UserProfile(id: 'peer-$i', name: '$i', screenName: '$i'),
                ),
              );
              when(() => fetch(2)).thenAnswer((_) async => [_second]);
            },
            build: build,
            act: (cubit) async {
              await cubit.load();
              await cubit.loadMore();
              await cubit.loadMore();
            },
            verify: (cubit) {
              expect(cubit.state.users, hasLength(61));
              expect(cubit.state.hasMore, isFalse);
              verifyInOrder([() => fetch(1), () => fetch(2)]);
              verifyNoMoreInteractions(repository);
            },
          );
          blocTest<FollowListCubit, FollowListState>(
            'keeps paginating a full overlapping page and stops on empty data',
            build: build,
            act: (cubit) async {
              await cubit.load();
              await cubit.loadMore();
              await cubit.loadMore();
              await cubit.loadMore();
            },
            expect: () => [
              FollowListState(),
              FollowListState(users: fullPage, loading: false),
              FollowListState(
                users: fullPage,
                loading: false,
                loadingMore: true,
              ),
              FollowListState(users: [...fullPage, _second], loading: false),
              FollowListState(
                users: [...fullPage, _second],
                loading: false,
                loadingMore: true,
              ),
              FollowListState(
                users: [...fullPage, _second],
                loading: false,
                hasMore: false,
              ),
            ],
            verify: (_) {
              verifyInOrder([() => fetch(1), () => fetch(2), () => fetch(3)]);
              verifyNoMoreInteractions(repository);
            },
          );
          blocTest<FollowListCubit, FollowListState>(
            'ends pagination after a short last page without another request',
            setUp: () => when(() => fetch(2)).thenAnswer(
              (_) async => [_first, _second],
            ),
            build: build,
            act: (cubit) async {
              await cubit.load();
              await cubit.loadMore();
              await cubit.loadMore();
            },
            expect: () => [
              FollowListState(),
              FollowListState(users: fullPage, loading: false),
              FollowListState(
                users: fullPage,
                loading: false,
                loadingMore: true,
              ),
              FollowListState(
                users: [...fullPage, _second],
                loading: false,
                hasMore: false,
              ),
            ],
            verify: (_) {
              verifyInOrder([() => fetch(1), () => fetch(2)]);
              verifyNoMoreInteractions(repository);
            },
          );
          blocTest<FollowListCubit, FollowListState>(
            'retains users and retries the same page after failure',
            build: build,
            act: (cubit) async {
              await cubit.load();
              when(() => fetch(2)).thenThrow(StateError('offline'));
              await cubit.loadMore();
              when(() => fetch(2)).thenAnswer((_) async => [_second]);
              await cubit.loadMore();
            },
            expect: () => [
              FollowListState(),
              FollowListState(users: fullPage, loading: false),
              FollowListState(
                users: fullPage,
                loading: false,
                loadingMore: true,
              ),
              FollowListState(
                users: fullPage,
                loading: false,
                loadMoreError: true,
              ),
              FollowListState(
                users: fullPage,
                loading: false,
                loadingMore: true,
              ),
              FollowListState(
                users: [...fullPage, _second],
                loading: false,
                hasMore: false,
              ),
            ],
            verify: (_) => verify(() => fetch(2)).called(2),
          );
          blocTest<FollowListCubit, FollowListState>(
            'ignores concurrent initial and pagination requests',
            build: build,
            act: (cubit) async {
              final firstRequest = Completer<List<UserProfile>>();
              when(() => fetch(1)).thenAnswer((_) => firstRequest.future);
              final initial = cubit.load();
              await cubit.load();
              await cubit.loadMore();
              firstRequest.complete(fullPage);
              await initial;
              final nextRequest = Completer<List<UserProfile>>();
              when(() => fetch(2)).thenAnswer((_) => nextRequest.future);
              final more = cubit.loadMore();
              await cubit.loadMore();
              await cubit.load();
              nextRequest.complete([_second]);
              await more;
            },
            expect: () => [
              FollowListState(),
              FollowListState(users: fullPage, loading: false),
              FollowListState(
                users: fullPage,
                loading: false,
                loadingMore: true,
              ),
              FollowListState(
                users: [...fullPage, _second],
                loading: false,
                hasMore: false,
              ),
            ],
            verify: (_) {
              verify(() => fetch(1)).called(1);
              verify(() => fetch(2)).called(1);
            },
          );
          blocTest<FollowListCubit, FollowListState>(
            'does not emit when disposed during pagination',
            build: build,
            act: (cubit) async {
              await cubit.load();
              final request = Completer<List<UserProfile>>();
              when(() => fetch(2)).thenAnswer((_) => request.future);
              final more = cubit.loadMore();
              await cubit.close();
              request.complete([_second]);
              await more;
            },
            expect: () => [
              FollowListState(),
              FollowListState(users: fullPage, loading: false),
              FollowListState(
                users: fullPage,
                loading: false,
                loadingMore: true,
              ),
            ],
          );
        });
      });
    }
  });
  group('$FollowListCubit relationship actions', () {
    late UserRepository repository;
    setUp(() => repository = _MockUserRepository());

    group('initial actions', () {
      for (final own in [true, false]) {
        for (final followers in [true, false]) {
          for (final following in [true, false, null]) {
            final owner = own ? 'me' : 'other';
            final user = UserProfile(
              id: 'peer',
              name: 'Peer',
              screenName: 'peer',
              following: following,
            );
            final expected = own && !followers || following == true
                ? FollowListAction.unfollow
                : own && followers
                ? FollowListAction.followBack
                : FollowListAction.follow;
            blocTest<FollowListCubit, FollowListState>(
              'uses list data for own=$own followers=$followers '
              'following=$following',
              setUp: () {
                if (followers) {
                  when(
                    () => repository.getFollowers(owner),
                  ).thenAnswer((_) async => [user]);
                } else {
                  when(
                    () => repository.getFriends(owner),
                  ).thenAnswer((_) async => [user]);
                }
              },
              build: () => FollowListCubit(
                repository: repository,
                accountId: 'me',
                userId: owner,
                followers: followers,
              ),
              act: (cubit) => cubit.load(),
              expect: () => [
                FollowListState(),
                FollowListState(
                  users: [user],
                  loading: false,
                  hasMore: false,
                  actions: {'peer': expected},
                ),
              ],
              verify: (_) {
                if (followers) {
                  verify(
                    () => repository.getFollowers(owner),
                  ).called(1);
                } else {
                  verify(() => repository.getFriends(owner)).called(1);
                }
                verifyNoMoreInteractions(repository);
              },
            );
          }
        }
      }
      blocTest<FollowListCubit, FollowListState>(
        'does not offer an action for the active account',
        setUp: () => when(() => repository.getFriends('other')).thenAnswer(
          (_) async => const [
            UserProfile(id: 'me', name: 'Me', screenName: 'me'),
          ],
        ),
        build: () => FollowListCubit(
          repository: repository,
          accountId: 'me',
          userId: 'other',
          followers: false,
        ),
        act: (cubit) async {
          await cubit.load();
          await cubit.toggleFollowing('me');
        },
        verify: (cubit) {
          expect(cubit.state.actions, isEmpty);
          verify(() => repository.getFriends('other')).called(1);
          verifyNoMoreInteractions(repository);
        },
      );
    });
    group('toggleFollowing', () {
      FollowListCubit build() => FollowListCubit(
        repository: repository,
        accountId: 'me',
        userId: 'me',
        followers: true,
      );
      FollowListState ready() => FollowListState(
        users: const [_first],
        loading: false,
        actions: const {'a': FollowListAction.followBack},
      );
      blocTest<FollowListCubit, FollowListState>(
        'follows back then unfollows without extra queries',
        build: build,
        seed: ready,
        setUp: () {
          when(
            () => repository.setFollowing('a', following: true),
          ).thenAnswer((_) async => true);
          when(
            () => repository.setFollowing('a', following: false),
          ).thenAnswer((_) async => false);
        },
        act: (cubit) async {
          await cubit.toggleFollowing('a');
          await cubit.toggleFollowing('a');
        },
        expect: () => [
          ready().copyWith(updatingIds: {'a'}),
          ready().copyWith(actions: {'a': FollowListAction.unfollow}),
          ready().copyWith(
            actions: {'a': FollowListAction.unfollow},
            updatingIds: {'a'},
          ),
          ready(),
        ],
        verify: (_) {
          verify(() => repository.setFollowing('a', following: true)).called(1);
          verify(
            () => repository.setFollowing('a', following: false),
          ).called(1);
          verifyNoMoreInteractions(repository);
        },
      );
      blocTest<FollowListCubit, FollowListState>(
        'reports server feedback and clears it when retry succeeds',
        build: build,
        seed: ready,
        act: (cubit) async {
          when(
            () => repository.setFollowing('a', following: true),
          ).thenThrow(const FollowActionFailure(message: '请等待确认'));
          await cubit.toggleFollowing('a');
          when(
            () => repository.setFollowing('a', following: true),
          ).thenAnswer((_) async => true);
          await cubit.toggleFollowing('a');
        },
        expect: () => [
          ready().copyWith(updatingIds: {'a'}),
          ready().copyWith(
            actionFailureCount: 1,
            actionFailureMessage: '请等待确认',
          ),
          ready().copyWith(actionFailureCount: 1, updatingIds: {'a'}),
          ready().copyWith(
            actionFailureCount: 1,
            actions: {'a': FollowListAction.unfollow},
          ),
        ],
        verify: (_) {
          verify(() => repository.setFollowing('a', following: true)).called(2);
        },
      );
      blocTest<FollowListCubit, FollowListState>(
        'keeps the prior action on failure and permits retry',
        build: build,
        seed: ready,
        act: (cubit) async {
          when(
            () => repository.setFollowing('a', following: true),
          ).thenThrow(StateError('offline'));
          await cubit.toggleFollowing('a');
          when(
            () => repository.setFollowing('a', following: true),
          ).thenAnswer((_) async => true);
          await cubit.toggleFollowing('a');
        },
        expect: () => [
          ready().copyWith(updatingIds: {'a'}),
          ready().copyWith(actionFailureCount: 1),
          ready().copyWith(actionFailureCount: 1, updatingIds: {'a'}),
          ready().copyWith(
            actionFailureCount: 1,
            actions: {'a': FollowListAction.unfollow},
          ),
        ],
      );
      blocTest<FollowListCubit, FollowListState>(
        'blocks repeated taps while allowing pagination to finish',
        build: build,
        seed: ready,
        act: (cubit) async {
          final mutation = Completer<bool>();
          final page = Completer<List<UserProfile>>();
          when(
            () => repository.setFollowing('a', following: true),
          ).thenAnswer((_) => mutation.future);
          when(
            () => repository.getFollowers('me'),
          ).thenAnswer((_) => page.future);
          final more = cubit.loadMore();
          final update = cubit.toggleFollowing('a');
          await cubit.toggleFollowing('a');
          mutation.complete(true);
          await update;
          page.complete([_first, _second]);
          await more;
        },
        verify: (cubit) {
          expect(cubit.state.users, [_first, _second]);
          expect(cubit.state.actions['a'], FollowListAction.unfollow);
          expect(cubit.state.updatingIds, isEmpty);
          verify(() => repository.setFollowing('a', following: true)).called(1);
        },
      );
      blocTest<FollowListCubit, FollowListState>(
        'keeps pending requests as follow back',
        build: build,
        seed: ready,
        setUp: () => when(
          () => repository.setFollowing('a', following: true),
        ).thenAnswer((_) async => false),
        act: (cubit) => cubit.toggleFollowing('a'),
        expect: () => [
          ready().copyWith(updatingIds: {'a'}),
          ready().copyWith(requestSentCount: 1),
        ],
      );
      blocTest<FollowListCubit, FollowListState>(
        'ignores completion after the page is disposed',
        build: build,
        seed: ready,
        act: (cubit) async {
          final request = Completer<bool>();
          when(
            () => repository.setFollowing('a', following: true),
          ).thenAnswer((_) => request.future);
          final update = cubit.toggleFollowing('a');
          await cubit.close();
          request.complete(true);
          await update;
        },
        expect: () => [
          ready().copyWith(updatingIds: {'a'}),
        ],
      );
    });
  });
  group(FollowListState, () {
    test('protects loaded users from mutation', () {
      final users = [_first];
      final state = FollowListState(users: users);
      users.clear();
      expect(state.users, [_first]);
      expect(() => state.users.add(_second), throwsUnsupportedError);
    });
  });
}
