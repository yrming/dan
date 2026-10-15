import 'package:bloc_test/bloc_test.dart';
import 'package:dan/blacklist/cubit/blacklist_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_repository/user_repository.dart';

class _MockUserRepository extends Mock implements UserRepository {}

void main() {
  group(BlacklistCubit, () {
    late UserRepository repository;

    setUp(() {
      repository = _MockUserRepository();
    });

    blocTest<BlacklistCubit, BlacklistState>(
      'emits success with blocked users when loading succeeds',
      setUp: () {
        when(() => repository.getBlockedUsers()).thenAnswer(
          (_) async => [_user],
        );
      },
      build: () => BlacklistCubit(repository: repository),
      act: (cubit) => cubit.load(),
      expect: () => [
        const BlacklistState(),
        const BlacklistState(
          status: BlacklistStatus.success,
          users: [_user],
          hasMore: false,
        ),
      ],
      verify: (_) {
        verify(() => repository.getBlockedUsers()).called(1);
      },
    );

    blocTest<BlacklistCubit, BlacklistState>(
      'emits failure when loading fails',
      setUp: () {
        when(() => repository.getBlockedUsers()).thenThrow(
          StateError('network'),
        );
      },
      build: () => BlacklistCubit(repository: repository),
      act: (cubit) => cubit.load(),
      expect: () => [
        const BlacklistState(),
        const BlacklistState(status: BlacklistStatus.failure),
      ],
    );

    blocTest<BlacklistCubit, BlacklistState>(
      'removes a user after the repository confirms the request',
      build: () {
        when(() => repository.removeBlockedUser(_user.id)).thenAnswer(
          (_) async => _user,
        );
        return BlacklistCubit(repository: repository);
      },
      seed: () => const BlacklistState(
        status: BlacklistStatus.success,
        users: [_user],
        hasMore: false,
      ),
      act: (cubit) => cubit.remove(_user.id),
      expect: () => [
        const BlacklistState(
          status: BlacklistStatus.success,
          users: [_user],
          hasMore: false,
          removingIds: {_userId},
        ),
        const BlacklistState(
          status: BlacklistStatus.success,
          hasMore: false,
        ),
      ],
      verify: (_) {
        verify(() => repository.removeBlockedUser(_user.id)).called(1);
      },
    );

    blocTest<BlacklistCubit, BlacklistState>(
      'keeps a user and reports an action failure when removal fails',
      build: () {
        when(() => repository.removeBlockedUser(_user.id)).thenThrow(
          StateError('network'),
        );
        return BlacklistCubit(repository: repository);
      },
      seed: () => const BlacklistState(
        status: BlacklistStatus.success,
        users: [_user],
        hasMore: false,
      ),
      act: (cubit) => cubit.remove(_user.id),
      expect: () => [
        const BlacklistState(
          status: BlacklistStatus.success,
          users: [_user],
          hasMore: false,
          removingIds: {_userId},
        ),
        const BlacklistState(
          status: BlacklistStatus.success,
          users: [_user],
          hasMore: false,
          actionFailureCount: 1,
        ),
      ],
    );
  });
}

const _userId = 'blocked-user';

const _user = UserProfile(
  id: _userId,
  name: 'Blocked User',
  screenName: 'blocked',
);
