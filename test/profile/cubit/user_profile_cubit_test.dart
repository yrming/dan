import 'package:authentication_repository/authentication_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:dan/profile/profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_repository/user_repository.dart';

class _MockUserRepository extends Mock implements UserRepository {}

class _MockAuthenticationRepository extends Mock
    implements AuthenticationRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(_account);
  });

  group(UserProfileCubit, () {
    late UserRepository userRepository;
    late AuthenticationRepository authenticationRepository;

    setUp(() {
      userRepository = _MockUserRepository();
      authenticationRepository = _MockAuthenticationRepository();
      when(
        () => authenticationRepository.updateAccount(any()),
      ).thenAnswer(
        (invocation) async =>
            invocation.positionalArguments.single as AuthenticatedAccount,
      );
    });

    test('uses the supplied profile summary as its initial state', () {
      final subject = UserProfileCubit(
        userRepository: userRepository,
        userId: _profile.id,
        initialProfile: _summary,
      );
      addTearDown(subject.close);

      expect(subject.state, const UserProfileInitial(profile: _summary));
    });

    group('load', () {
      blocTest<UserProfileCubit, UserProfileState>(
        'loads whether the displayed user follows the active account',
        setUp: () {
          when(
            () => userRepository.getUser(_profile.id),
          ).thenAnswer((_) async => _profile);
          when(
            () => userRepository.isFollowing(
              userId: _profile.id,
              targetUserId: 'active-account',
            ),
          ).thenAnswer((_) async => true);
        },
        build: () => UserProfileCubit(
          userRepository: userRepository,
          userId: _profile.id,
          activeAccountId: 'active-account',
        ),
        act: (cubit) => cubit.load(),
        expect: () => const [
          UserProfileLoadInProgress(),
          UserProfileLoadSuccess(profile: _profile, followedBy: true),
        ],
      );

      blocTest<UserProfileCubit, UserProfileState>(
        'refreshes the supplied existing profile',
        setUp: () {
          when(
            () => userRepository.getUser(_profile.id),
          ).thenAnswer((_) async => _refreshedProfile);
        },
        build: () => UserProfileCubit(
          userRepository: userRepository,
          userId: _profile.id,
          initialProfile: _profile,
          authenticationRepository: authenticationRepository,
        ),
        act: (cubit) => cubit.load(),
        expect: () => const [
          UserProfileLoadInProgress(profile: _profile),
          UserProfileLoadSuccess(profile: _refreshedProfile),
        ],
        verify: (_) {
          verify(() => userRepository.getUser(_profile.id)).called(1);
          verify(
            () => authenticationRepository.updateAccount(_refreshedAccount),
          ).called(1);
        },
      );

      blocTest<UserProfileCubit, UserProfileState>(
        'keeps the refreshed profile when account persistence fails',
        setUp: () {
          when(
            () => userRepository.getUser(_profile.id),
          ).thenAnswer((_) async => _refreshedProfile);
          when(
            () => authenticationRepository.updateAccount(_refreshedAccount),
          ).thenThrow(const AuthenticationStorageFailure());
        },
        build: () => UserProfileCubit(
          userRepository: userRepository,
          userId: _profile.id,
          initialProfile: _profile,
          authenticationRepository: authenticationRepository,
        ),
        act: (cubit) => cubit.load(),
        expect: () => const [
          UserProfileLoadInProgress(profile: _profile),
          UserProfileLoadSuccess(profile: _refreshedProfile),
        ],
      );

      blocTest<UserProfileCubit, UserProfileState>(
        'emits loading and success when the repository returns data',
        setUp: () {
          when(
            () => userRepository.getUser(_profile.id),
          ).thenAnswer((_) async => _profile);
        },
        build: () => UserProfileCubit(
          userRepository: userRepository,
          userId: _profile.id,
          initialProfile: _summary,
        ),
        act: (cubit) => cubit.load(),
        expect: () => const [
          UserProfileLoadInProgress(profile: _summary),
          UserProfileLoadSuccess(profile: _profile),
        ],
        verify: (_) {
          verify(() => userRepository.getUser(_profile.id)).called(1);
          verifyNever(() => userRepository.getNotificationCounts());
        },
      );

      blocTest<UserProfileCubit, UserProfileState>(
        'retains the summary when the repository throws',
        setUp: () {
          when(
            () => userRepository.getUser(_profile.id),
          ).thenThrow(StateError('offline'));
        },
        build: () => UserProfileCubit(
          userRepository: userRepository,
          userId: _profile.id,
          initialProfile: _summary,
        ),
        act: (cubit) => cubit.load(),
        expect: () => const [
          UserProfileLoadInProgress(profile: _summary),
          UserProfileLoadFailure(profile: _summary),
        ],
      );
    });

    group('toggleFollowing', () {
      blocTest<UserProfileCubit, UserProfileState>(
        'reports server feedback on repeated failures '
        'and clears it for unknown errors',
        build: () => UserProfileCubit(
          userRepository: userRepository,
          userId: _profile.id,
          activeAccountId: 'active-account',
        ),
        seed: () => const UserProfileLoadSuccess(profile: _profile),
        act: (cubit) async {
          when(
            () => userRepository.setFollowing(_profile.id, following: true),
          ).thenThrow(const FollowActionFailure(message: '请等待确认'));
          await cubit.toggleFollowing();
          await cubit.toggleFollowing();
          when(
            () => userRepository.setFollowing(_profile.id, following: true),
          ).thenThrow(StateError('offline'));
          await cubit.toggleFollowing();
        },
        expect: () => [
          for (var count = 0; count < 3; count++) ...[
            UserProfileLoadSuccess(
              profile: _profile,
              isFollowingUpdating: true,
              actionFailureCount: count,
            ),
            UserProfileLoadSuccess(
              profile: _profile,
              actionFailureCount: count + 1,
              actionFailureMessage: count < 2 ? '请等待确认' : null,
            ),
          ],
        ],
        verify: (_) {
          verify(
            () => userRepository.setFollowing(_profile.id, following: true),
          ).called(3);
        },
      );

      blocTest<UserProfileCubit, UserProfileState>(
        'follows the displayed user and updates the profile',
        setUp: () {
          when(
            () => userRepository.getUser(_profile.id),
          ).thenAnswer((_) async => _profile);
          when(
            () => userRepository.isFollowing(
              userId: _profile.id,
              targetUserId: 'active-account',
            ),
          ).thenAnswer((_) async => true);
          when(
            () => userRepository.setFollowing(_profile.id, following: true),
          ).thenAnswer((_) async => true);
        },
        build: () => UserProfileCubit(
          userRepository: userRepository,
          userId: _profile.id,
          activeAccountId: 'active-account',
        ),
        act: (cubit) async {
          await cubit.load();
          await cubit.toggleFollowing();
        },
        skip: 2,
        expect: () => [
          const UserProfileLoadSuccess(
            profile: _profile,
            followedBy: true,
            isFollowingUpdating: true,
          ),
          UserProfileLoadSuccess(
            profile: _profile.copyWithFollowing(following: true),
            followedBy: true,
          ),
        ],
        verify: (_) {
          verify(
            () => userRepository.setFollowing(_profile.id, following: true),
          ).called(1);
        },
      );
    });

    group('toggleBlocked', () {
      blocTest<UserProfileCubit, UserProfileState>(
        'blocks the displayed user and reports success state',
        build: () {
          when(
            () => userRepository.isFollowing(
              userId: 'active-account',
              targetUserId: _profile.id,
            ),
          ).thenAnswer((_) async => true);
          when(
            () => userRepository.isFollowing(
              userId: _profile.id,
              targetUserId: 'active-account',
            ),
          ).thenAnswer((_) async => false);
          when(
            () => userRepository.setBlocked(_profile.id, blocked: true),
          ).thenAnswer((_) async => true);
          return UserProfileCubit(
            userRepository: userRepository,
            userId: _profile.id,
            activeAccountId: 'active-account',
          );
        },
        seed: () => const UserProfileLoadSuccess(
          profile: _profile,
          isBlocked: false,
        ),
        act: (cubit) => cubit.toggleBlocked(),
        expect: () => [
          const UserProfileLoadSuccess(
            profile: _profile,
            isBlocked: false,
            isBlockActionInProgress: true,
          ),
          UserProfileLoadSuccess(
            profile: _profile.copyWithFollowing(following: true),
            followedBy: false,
            isBlocked: true,
            blockActionCount: 1,
          ),
        ],
        verify: (_) {
          verify(
            () => userRepository.isFollowing(
              userId: 'active-account',
              targetUserId: _profile.id,
            ),
          ).called(1);
          verify(
            () => userRepository.isFollowing(
              userId: _profile.id,
              targetUserId: 'active-account',
            ),
          ).called(1);
          verify(
            () => userRepository.setBlocked(_profile.id, blocked: true),
          ).called(1);
        },
      );

      blocTest<UserProfileCubit, UserProfileState>(
        'reports server feedback when blocking fails',
        build: () {
          when(
            () => userRepository.setBlocked(_profile.id, blocked: false),
          ).thenThrow(const BlockActionFailure(message: '无法取消拉黑'));
          return UserProfileCubit(
            userRepository: userRepository,
            userId: _profile.id,
            activeAccountId: 'active-account',
          );
        },
        seed: () => const UserProfileLoadSuccess(
          profile: _profile,
          isBlocked: true,
        ),
        act: (cubit) => cubit.toggleBlocked(),
        expect: () => const [
          UserProfileLoadSuccess(
            profile: _profile,
            isBlocked: true,
            isBlockActionInProgress: true,
          ),
          UserProfileLoadSuccess(
            profile: _profile,
            isBlocked: true,
            blockActionFailureCount: 1,
            blockActionFailed: true,
            blockActionMessage: '无法取消拉黑',
          ),
        ],
      );
    });
  });
}

const _summary = UserProfile(
  id: 'user-a',
  name: '饭友 A',
  screenName: 'fanfou_a',
);

const _account = AuthenticatedAccount(
  id: 'user-a',
  name: '饭友 A',
  screenName: 'fanfou_a',
);

const _profile = UserProfile(
  id: 'user-a',
  name: '饭友 A',
  screenName: 'fanfou_a',
  description: '写点什么。',
  location: '上海',
  followersCount: 12,
  friendsCount: 8,
  statusesCount: 42,
);

const _refreshedProfile = UserProfile(
  id: 'user-a',
  name: '饭友 A（已刷新）',
  screenName: 'fanfou_a',
  description: '刷新后的简介。',
  location: '上海',
  url: 'https://fanfou.com/fanfou_a',
  protected: true,
  following: false,
  followersCount: 13,
  friendsCount: 8,
  statusesCount: 43,
);

const _refreshedAccount = AuthenticatedAccount(
  id: 'user-a',
  name: '饭友 A（已刷新）',
  screenName: 'fanfou_a',
  description: '刷新后的简介。',
  location: '上海',
  url: 'https://fanfou.com/fanfou_a',
  protected: true,
  following: false,
  followersCount: 13,
  friendsCount: 8,
  statusesCount: 43,
);
