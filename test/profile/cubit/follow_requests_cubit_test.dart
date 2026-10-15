import 'package:bloc_test/bloc_test.dart';
import 'package:dan/profile/profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_repository/user_repository.dart';

class _MockUserRepository extends Mock implements UserRepository {}

const _user = UserProfile(id: 'u1', name: 'User', screenName: 'user');

void main() {
  group(FollowRequestsCubit, () {
    late UserRepository repository;

    setUp(() {
      repository = _MockUserRepository();
    });

    FollowRequestsCubit build() => FollowRequestsCubit(repository: repository);

    blocTest<FollowRequestsCubit, FollowRequestsState>(
      'emits loaded requests and removes a request after accepting it',
      setUp: () {
        when(
          () => repository.getFollowRequests(),
        ).thenAnswer((_) async => [_user]);
        when(
          () => repository.acceptFollowRequest('u1'),
        ).thenAnswer((_) async => _user);
      },
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.accept('u1');
      },
      expect: () => [
        FollowRequestsState(),
        FollowRequestsState(
          users: const [_user],
          loading: false,
          hasMore: false,
        ),
        FollowRequestsState(
          users: const [_user],
          loading: false,
          hasMore: false,
          updatingIds: const {'u1'},
          updatingActions: const {'u1': FollowRequestAction.accept},
        ),
        FollowRequestsState(
          loading: false,
          hasMore: false,
          actionSuccessCount: 1,
        ),
      ],
      verify: (_) {
        verify(() => repository.getFollowRequests()).called(1);
        verify(() => repository.acceptFollowRequest('u1')).called(1);
      },
    );

    blocTest<FollowRequestsCubit, FollowRequestsState>(
      'keeps a request and reports a failure when ignoring fails',
      setUp: () {
        when(
          () => repository.getFollowRequests(),
        ).thenAnswer((_) async => [_user]);
        when(
          () => repository.ignoreFollowRequest('u1'),
        ).thenThrow(StateError('offline'));
      },
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.ignore('u1');
      },
      expect: () => [
        FollowRequestsState(),
        FollowRequestsState(
          users: const [_user],
          loading: false,
          hasMore: false,
        ),
        FollowRequestsState(
          users: const [_user],
          loading: false,
          updatingIds: const {'u1'},
          updatingActions: const {'u1': FollowRequestAction.ignore},
          hasMore: false,
        ),
        FollowRequestsState(
          users: const [_user],
          loading: false,
          actionFailureCount: 1,
          hasMore: false,
        ),
      ],
      verify: (_) =>
          verify(() => repository.ignoreFollowRequest('u1')).called(1),
    );
  });
}
