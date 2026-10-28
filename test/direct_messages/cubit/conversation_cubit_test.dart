import 'package:bloc_test/bloc_test.dart';
import 'package:dan/direct_messages/cubit/cubit.dart';
import 'package:direct_message_repository/direct_message_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDirectMessageRepository extends Mock
    implements DirectMessageRepository {}

void main() {
  group(ConversationCubit, () {
    late DirectMessageRepository directMessageRepository;

    const incomingMessage = DirectMessage(
      id: 'dm-1',
      text: '你好',
      createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
      senderId: 'user-b',
      recipientId: 'account-a',
      senderScreenName: 'fanfou_b',
    );

    const outgoingMessage = DirectMessage(
      id: 'dm-2',
      text: '你好！最近怎么样？',
      createdAt: 'Tue Jul 28 00:10:00 +0000 2026',
      senderId: 'account-a',
      recipientId: 'user-b',
    );

    DirectMessage olderMessage(int index) => DirectMessage(
      id: 'dm-old-$index',
      text: '更早的消息 $index',
      createdAt: 'Mon Jul 27 00:00:00 +0000 2026',
      senderId: 'user-b',
      recipientId: 'account-a',
      senderScreenName: 'fanfou_b',
    );

    DirectMessageHistoryPage page(
      List<DirectMessage> messages, {
      bool hasMore = false,
      int? nextPage,
    }) => DirectMessageHistoryPage(
      messages: messages,
      hasMore: hasMore,
      nextPage: nextPage,
    );

    setUp(() {
      directMessageRepository = _MockDirectMessageRepository();
    });

    ConversationCubit buildCubit({
      String? initialPeerScreenName,
      String? activeAccountId = 'account-a',
    }) {
      return ConversationCubit(
        directMessageRepository: directMessageRepository,
        userId: 'user-b',
        activeAccountId: activeAccountId,
        initialPeerScreenName: initialPeerScreenName,
      );
    }

    test('has an initial state of $ConversationInitial', () {
      final cubit = buildCubit();

      expect(cubit.state, equals(const ConversationInitial()));
    });

    test('uses the initial peer screen name as the initial state header', () {
      final cubit = buildCubit(initialPeerScreenName: 'fanfou_b');

      expect(
        cubit.state,
        equals(const ConversationInitial(peerScreenName: 'fanfou_b')),
      );
    });

    group('load', () {
      blocTest<ConversationCubit, ConversationState>(
        'emits [loading, success] when the repository returns messages',
        setUp: () {
          when(
            () => directMessageRepository.getConversation(
              'user-b',
              limit: 20,
              page: 1,
            ),
          ).thenAnswer((_) async => page([incomingMessage, outgoingMessage]));
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          const ConversationLoadInProgress(),
          const ConversationLoadSuccess(
            messages: [incomingMessage, outgoingMessage],
            peerScreenName: 'fanfou_b',
          ),
        ],
        verify: (_) {
          verify(
            () => directMessageRepository.getConversation(
              'user-b',
              limit: 20,
              page: 1,
            ),
          ).called(1);
        },
      );

      blocTest<ConversationCubit, ConversationState>(
        'falls back to the peer screen name from the messages',
        setUp: () {
          when(
            () => directMessageRepository.getConversation(
              'user-b',
              limit: 20,
              page: 1,
            ),
          ).thenAnswer((_) async => page([incomingMessage, outgoingMessage]));
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        seed: () => const ConversationLoadInProgress(),
        expect: () => [
          const ConversationLoadSuccess(
            messages: [incomingMessage, outgoingMessage],
            peerScreenName: 'fanfou_b',
          ),
        ],
      );

      blocTest<ConversationCubit, ConversationState>(
        'keeps pagination available when a full page is returned',
        setUp: () {
          when(
            () => directMessageRepository.getConversation(
              'user-b',
              limit: 20,
              page: 1,
            ),
          ).thenAnswer(
            (_) async => page(
              [incomingMessage, outgoingMessage],
              hasMore: true,
              nextPage: 2,
            ),
          );
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        seed: () => const ConversationLoadInProgress(),
        expect: () => [
          const ConversationLoadSuccess(
            messages: [incomingMessage, outgoingMessage],
            peerScreenName: 'fanfou_b',
            hasMore: true,
            nextPage: 2,
          ),
        ],
      );

      blocTest<ConversationCubit, ConversationState>(
        'emits [loading, success] with an empty list when the conversation '
        'is empty',
        setUp: () {
          when(
            () => directMessageRepository.getConversation(
              'user-b',
              limit: 20,
              page: 1,
            ),
          ).thenAnswer((_) async => page(const []));
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          const ConversationLoadInProgress(),
          const ConversationLoadSuccess(messages: []),
        ],
      );

      blocTest<ConversationCubit, ConversationState>(
        'emits [loading, failure] when the repository fails',
        setUp: () {
          when(
            () => directMessageRepository.getConversation(
              'user-b',
              limit: 20,
              page: 1,
            ),
          ).thenThrow(const DirectMessageRepositoryUnknownFailure());
        },
        build: () => buildCubit(initialPeerScreenName: 'fanfou_b'),
        act: (cubit) => cubit.load(),
        expect: () => [
          const ConversationLoadInProgress(peerScreenName: 'fanfou_b'),
          const ConversationLoadFailure(peerScreenName: 'fanfou_b'),
        ],
      );
    });

    group('loadMore', () {
      blocTest<ConversationCubit, ConversationState>(
        'prepends the older page and advances the page cursor',
        setUp: () {
          when(
            () => directMessageRepository.getConversation(
              'user-b',
              limit: 20,
              page: 2,
            ),
          ).thenAnswer(
            (_) async => page(
              [olderMessage(1), olderMessage(2)],
              hasMore: true,
              nextPage: 3,
            ),
          );
        },
        build: buildCubit,
        seed: () => const ConversationLoadSuccess(
          messages: [incomingMessage, outgoingMessage],
          peerScreenName: 'fanfou_b',
          hasMore: true,
          nextPage: 2,
        ),
        act: (cubit) => cubit.loadMore(),
        expect: () => [
          const ConversationLoadSuccess(
            messages: [incomingMessage, outgoingMessage],
            peerScreenName: 'fanfou_b',
            hasMore: true,
            nextPage: 2,
            historyLoadStatus: ConversationHistoryLoadStatus.inProgress,
          ),
          ConversationLoadSuccess(
            messages: [
              incomingMessage,
              outgoingMessage,
              olderMessage(1),
              olderMessage(2),
            ],
            peerScreenName: 'fanfou_b',
            hasMore: true,
            nextPage: 3,
          ),
        ],
        verify: (_) {
          verify(
            () => directMessageRepository.getConversation(
              'user-b',
              limit: 20,
              page: 2,
            ),
          ).called(1);
        },
      );

      blocTest<ConversationCubit, ConversationState>(
        'stops pagination when the older page is not full',
        setUp: () {
          when(
            () => directMessageRepository.getConversation(
              'user-b',
              limit: 20,
              page: 2,
            ),
          ).thenAnswer((_) async => page([olderMessage(1)]));
        },
        build: buildCubit,
        seed: () => const ConversationLoadSuccess(
          messages: [incomingMessage],
          hasMore: true,
          nextPage: 2,
        ),
        act: (cubit) => cubit.loadMore(),
        expect: () => [
          const ConversationLoadSuccess(
            messages: [incomingMessage],
            hasMore: true,
            nextPage: 2,
            historyLoadStatus: ConversationHistoryLoadStatus.inProgress,
          ),
          ConversationLoadSuccess(
            messages: [incomingMessage, olderMessage(1)],
          ),
        ],
      );

      blocTest<ConversationCubit, ConversationState>(
        'skips messages already present in the list',
        setUp: () {
          when(
            () => directMessageRepository.getConversation(
              'user-b',
              limit: 20,
              page: 2,
            ),
          ).thenAnswer((_) async => page([incomingMessage, olderMessage(1)]));
        },
        build: buildCubit,
        seed: () => const ConversationLoadSuccess(
          messages: [incomingMessage],
          hasMore: true,
          nextPage: 2,
        ),
        act: (cubit) => cubit.loadMore(),
        expect: () => [
          const ConversationLoadSuccess(
            messages: [incomingMessage],
            hasMore: true,
            nextPage: 2,
            historyLoadStatus: ConversationHistoryLoadStatus.inProgress,
          ),
          ConversationLoadSuccess(
            messages: [incomingMessage, olderMessage(1)],
          ),
        ],
      );

      blocTest<ConversationCubit, ConversationState>(
        'emits a failure history status and keeps the list when loading '
        'more fails',
        setUp: () {
          when(
            () => directMessageRepository.getConversation(
              'user-b',
              limit: 20,
              page: 2,
            ),
          ).thenThrow(const DirectMessageRepositoryUnknownFailure());
        },
        build: buildCubit,
        seed: () => const ConversationLoadSuccess(
          messages: [incomingMessage],
          hasMore: true,
          nextPage: 2,
        ),
        act: (cubit) => cubit.loadMore(),
        expect: () => [
          const ConversationLoadSuccess(
            messages: [incomingMessage],
            hasMore: true,
            nextPage: 2,
            historyLoadStatus: ConversationHistoryLoadStatus.inProgress,
          ),
          const ConversationLoadSuccess(
            messages: [incomingMessage],
            hasMore: true,
            nextPage: 2,
            historyLoadStatus: ConversationHistoryLoadStatus.failure,
          ),
        ],
      );

      blocTest<ConversationCubit, ConversationState>(
        'retries the same history page after failure and preserves messages',
        build: buildCubit,
        seed: () => const ConversationLoadSuccess(
          messages: [incomingMessage],
          hasMore: true,
          nextPage: 2,
        ),
        act: (cubit) async {
          when(
            () => directMessageRepository.getConversation(
              'user-b',
              limit: 20,
              page: 2,
            ),
          ).thenThrow(
            const DirectMessageRepositoryApiFailure(
              statusCode: 403,
              message: '请求太频繁',
            ),
          );
          await cubit.loadMore();
          when(
            () => directMessageRepository.getConversation(
              'user-b',
              limit: 20,
              page: 2,
            ),
          ).thenAnswer((_) async => page([olderMessage(1)]));
          await cubit.loadMore();
        },
        expect: () => [
          const ConversationLoadSuccess(
            messages: [incomingMessage],
            hasMore: true,
            nextPage: 2,
            historyLoadStatus: ConversationHistoryLoadStatus.inProgress,
          ),
          const ConversationLoadSuccess(
            messages: [incomingMessage],
            hasMore: true,
            nextPage: 2,
            historyLoadStatus: ConversationHistoryLoadStatus.failure,
            failureMessage: '请求太频繁',
          ),
          const ConversationLoadSuccess(
            messages: [incomingMessage],
            hasMore: true,
            nextPage: 2,
            historyLoadStatus: ConversationHistoryLoadStatus.inProgress,
            failureMessage: '请求太频繁',
          ),
          ConversationLoadSuccess(
            messages: [incomingMessage, olderMessage(1)],
            failureMessage: '请求太频繁',
          ),
        ],
        verify: (_) => verify(
          () => directMessageRepository.getConversation(
            'user-b',
            limit: 20,
            page: 2,
          ),
        ).called(2),
      );

      blocTest<ConversationCubit, ConversationState>(
        'does nothing when no earlier page is available',
        build: buildCubit,
        seed: () => const ConversationLoadSuccess(messages: [incomingMessage]),
        act: (cubit) => cubit.loadMore(),
        expect: () => <ConversationState>[],
        verify: (_) {
          verifyNever(
            () => directMessageRepository.getConversation(
              any(),
              limit: any(named: 'limit'),
              page: any(named: 'page'),
            ),
          );
        },
      );
    });

    group('sendMessage', () {
      blocTest<ConversationCubit, ConversationState>(
        'emits progress then adds the sent message to the conversation',
        setUp: () {
          when(
            () => directMessageRepository.sendMessage('user-b', '发送内容'),
          ).thenAnswer((_) async => outgoingMessage);
        },
        build: buildCubit,
        seed: () => const ConversationLoadSuccess(
          messages: [incomingMessage],
        ),
        act: (cubit) => cubit.sendMessage('发送内容'),
        expect: () => [
          const ConversationLoadSuccess(
            messages: [incomingMessage],
            sendStatus: ConversationSendStatus.inProgress,
          ),
          const ConversationLoadSuccess(
            messages: [outgoingMessage, incomingMessage],
          ),
        ],
        verify: (_) {
          verify(
            () => directMessageRepository.sendMessage('user-b', '发送内容'),
          ).called(1);
        },
      );

      blocTest<ConversationCubit, ConversationState>(
        'emits a send failure while keeping existing messages',
        setUp: () {
          when(
            () => directMessageRepository.sendMessage('user-b', '发送内容'),
          ).thenThrow(const DirectMessageRepositoryUnknownFailure());
        },
        build: buildCubit,
        seed: () => const ConversationLoadSuccess(
          messages: [incomingMessage],
        ),
        act: (cubit) => cubit.sendMessage('发送内容'),
        expect: () => [
          const ConversationLoadSuccess(
            messages: [incomingMessage],
            sendStatus: ConversationSendStatus.inProgress,
          ),
          const ConversationLoadSuccess(
            messages: [incomingMessage],
            sendStatus: ConversationSendStatus.failure,
          ),
        ],
      );
    });

    group('deleteMessage', () {
      blocTest<ConversationCubit, ConversationState>(
        'emits progress then removes the deleted message',
        setUp: () {
          when(
            () => directMessageRepository.deleteMessage('dm-2'),
          ).thenAnswer((_) async {});
        },
        build: buildCubit,
        seed: () => const ConversationLoadSuccess(
          messages: [outgoingMessage, incomingMessage],
        ),
        act: (cubit) => cubit.deleteMessage('dm-2'),
        expect: () => [
          const ConversationLoadSuccess(
            messages: [outgoingMessage, incomingMessage],
            deletionStatus: ConversationDeletionStatus.inProgress,
          ),
          const ConversationLoadSuccess(messages: [incomingMessage]),
        ],
        verify: (_) {
          verify(() => directMessageRepository.deleteMessage('dm-2')).called(
            1,
          );
        },
      );

      blocTest<ConversationCubit, ConversationState>(
        'emits a deletion failure with the API message',
        setUp: () {
          when(() => directMessageRepository.deleteMessage('dm-2')).thenThrow(
            const DirectMessageRepositoryApiFailure(
              statusCode: 403,
              message: '没有权限删除',
            ),
          );
        },
        build: buildCubit,
        seed: () => const ConversationLoadSuccess(
          messages: [outgoingMessage, incomingMessage],
        ),
        act: (cubit) => cubit.deleteMessage('dm-2'),
        expect: () => [
          const ConversationLoadSuccess(
            messages: [outgoingMessage, incomingMessage],
            deletionStatus: ConversationDeletionStatus.inProgress,
          ),
          const ConversationLoadSuccess(
            messages: [outgoingMessage, incomingMessage],
            deletionStatus: ConversationDeletionStatus.failure,
            failureMessage: '没有权限删除',
          ),
        ],
      );

      blocTest<ConversationCubit, ConversationState>(
        'does nothing before the conversation loads',
        build: buildCubit,
        seed: () => const ConversationInitial(),
        act: (cubit) => cubit.deleteMessage('dm-2'),
        expect: () => <ConversationState>[],
        verify: (_) {
          verifyNever(() => directMessageRepository.deleteMessage(any()));
        },
      );
    });
  });
}
