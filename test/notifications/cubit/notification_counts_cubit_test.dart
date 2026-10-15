import 'package:bloc_test/bloc_test.dart';
import 'package:dan/notifications/notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_repository/user_repository.dart';

class _MockUserRepository extends Mock implements UserRepository {}

void main() {
  group(NotificationCountsCubit, () {
    late UserRepository userRepository;

    setUp(() {
      userRepository = _MockUserRepository();
    });

    blocTest<NotificationCountsCubit, NotificationCountsState>(
      'loads notification counts after an account is verified',
      setUp: () {
        when(
          () => userRepository.getNotificationCounts(),
        ).thenAnswer((_) async => _counts);
      },
      build: () => NotificationCountsCubit(userRepository: userRepository),
      act: (cubit) => cubit.accountChanged('account-a'),
      expect: () => const [
        NotificationCountsLoadInProgress(),
        NotificationCountsLoadSuccess(counts: _counts),
      ],
      verify: (_) {
        verify(() => userRepository.getNotificationCounts()).called(1);
      },
    );

    blocTest<NotificationCountsCubit, NotificationCountsState>(
      'does not reload when the same account remains active',
      setUp: () {
        when(
          () => userRepository.getNotificationCounts(),
        ).thenAnswer((_) async => _counts);
      },
      build: () => NotificationCountsCubit(userRepository: userRepository),
      act: (cubit) async {
        await cubit.accountChanged('account-a');
        await cubit.accountChanged('account-a');
      },
      expect: () => const [
        NotificationCountsLoadInProgress(),
        NotificationCountsLoadSuccess(counts: _counts),
      ],
      verify: (_) {
        verify(() => userRepository.getNotificationCounts()).called(1);
      },
    );

    blocTest<NotificationCountsCubit, NotificationCountsState>(
      'clears notification counts when the account is signed out',
      build: () => NotificationCountsCubit(userRepository: userRepository),
      seed: () => const NotificationCountsLoadSuccess(counts: _counts),
      act: (cubit) => cubit.reset(),
      expect: () => const [NotificationCountsInitial()],
    );

    blocTest<NotificationCountsCubit, NotificationCountsState>(
      'keeps counters unavailable when loading fails',
      setUp: () {
        when(
          () => userRepository.getNotificationCounts(),
        ).thenThrow(StateError('offline'));
      },
      build: () => NotificationCountsCubit(userRepository: userRepository),
      act: (cubit) => cubit.accountChanged('account-a'),
      expect: () => const [
        NotificationCountsLoadInProgress(),
        NotificationCountsLoadFailure(),
      ],
    );
  });
}

const _counts = UserNotificationCounts(
  mentions: 2,
  directMessages: 3,
  friendRequests: 4,
);
