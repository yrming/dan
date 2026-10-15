import 'package:bloc_test/bloc_test.dart';
import 'package:dan/direct_messages/bloc/conversation_list_bloc.dart';
import 'package:direct_message_repository/direct_message_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDirectMessageRepository extends Mock
    implements DirectMessageRepository {}

DirectMessageConversation _conversationForUser(
  int index, {
  bool hasUnread = false,
}) {
  return DirectMessageConversation(
    otherUserId: 'user-$index',
    lastMessage: DirectMessage(
      id: 'dm-$index',
      text: '你好 $index',
      createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
      senderId: 'user-$index',
      recipientId: 'account-a',
    ),
    messageCount: index,
    hasUnread: hasUnread,
    otherUserScreenName: 'user_$index',
  );
}

void main() {
  group(ConversationListBloc, () {
    late DirectMessageRepository directMessageRepository;

    const pageSize = 20;
    final fullPage = List.generate(pageSize, _conversationForUser);
    final shortPage = List.generate(
      pageSize,
      _conversationForUser,
    ).take(3).toList();
    final secondPage = List.generate(
      pageSize,
      (index) => _conversationForUser(index + pageSize),
    );
    final shortSecondPage = secondPage.take(3).toList();

    setUp(() {
      directMessageRepository = _MockDirectMessageRepository();
    });

    ConversationListBloc buildBloc() {
      return ConversationListBloc(
        directMessageRepository: directMessageRepository,
      );
    }

    test('has an initial state of initial with no conversations', () {
      final bloc = buildBloc();

      expect(
        bloc.state,
        equals(const ConversationListState()),
      );
    });

    group('ConversationListConversationOpened', () {
      blocTest<ConversationListBloc, ConversationListState>(
        'clears the selected unread conversation on a later page '
        'without requests',
        build: buildBloc,
        seed: () => ConversationListState(
          status: ConversationListStatus.success,
          conversations: [
            ...fullPage,
            _conversationForUser(20, hasUnread: true),
            _conversationForUser(21, hasUnread: true),
          ],
          hasMore: true,
          nextPage: 3,
        ),
        act: (bloc) => bloc.add(
          const ConversationListConversationOpened(userId: 'user-21'),
        ),
        expect: () => [
          ConversationListState(
            status: ConversationListStatus.success,
            conversations: [
              ...fullPage,
              _conversationForUser(20, hasUnread: true),
              _conversationForUser(21),
            ],
            hasMore: true,
            nextPage: 3,
          ),
        ],
        verify: (_) => verifyZeroInteractions(directMessageRepository),
      );
      for (final userId in ['user-0', 'unknown']) {
        blocTest<ConversationListBloc, ConversationListState>(
          'does not change the list for a read or absent conversation: $userId',
          build: buildBloc,
          seed: () => ConversationListState(
            status: ConversationListStatus.success,
            conversations: fullPage,
          ),
          act: (bloc) =>
              bloc.add(ConversationListConversationOpened(userId: userId)),
          expect: () => <ConversationListState>[],
          verify: (_) => verifyZeroInteractions(directMessageRepository),
        );
      }
    });

    group('ConversationListInitialLoadRequested', () {
      blocTest<ConversationListBloc, ConversationListState>(
        'emits [loading, success] when the repository returns a short page',
        setUp: () {
          when(
            () => directMessageRepository.getConversationList(
              limit: any(named: 'limit'),
              page: any(named: 'page'),
            ),
          ).thenAnswer(
            (_) async => DirectMessageConversationPage(
              conversations: shortPage,
              hasMore: false,
              nextPage: null,
            ),
          );
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const ConversationListInitialLoadRequested()),
        expect: () => [
          const ConversationListState(
            status: ConversationListStatus.loading,
          ),
          ConversationListState(
            status: ConversationListStatus.success,
            conversations: shortPage,
          ),
        ],
        verify: (_) {
          verify(
            () => directMessageRepository.getConversationList(
              limit: pageSize,
              page: 1,
            ),
          ).called(1);
        },
      );

      blocTest<ConversationListBloc, ConversationListState>(
        'keeps loading available when the repository returns a full page',
        setUp: () {
          when(
            () => directMessageRepository.getConversationList(
              limit: any(named: 'limit'),
              page: any(named: 'page'),
            ),
          ).thenAnswer(
            (_) async => DirectMessageConversationPage(
              conversations: fullPage,
              hasMore: true,
              nextPage: 2,
            ),
          );
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const ConversationListInitialLoadRequested()),
        expect: () => [
          const ConversationListState(
            status: ConversationListStatus.loading,
          ),
          ConversationListState(
            status: ConversationListStatus.success,
            conversations: fullPage,
            hasMore: true,
            nextPage: 2,
          ),
        ],
      );

      blocTest<ConversationListBloc, ConversationListState>(
        'emits [loading, empty] when there are no conversations',
        setUp: () {
          when(
            () => directMessageRepository.getConversationList(
              limit: any(named: 'limit'),
              page: any(named: 'page'),
            ),
          ).thenAnswer(
            (_) async => const DirectMessageConversationPage(
              conversations: [],
              hasMore: false,
              nextPage: null,
            ),
          );
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const ConversationListInitialLoadRequested()),
        expect: () => [
          const ConversationListState(
            status: ConversationListStatus.loading,
          ),
          const ConversationListState(status: ConversationListStatus.empty),
        ],
      );

      blocTest<ConversationListBloc, ConversationListState>(
        'emits [loading, failure] when the repository fails',
        setUp: () {
          when(
            () => directMessageRepository.getConversationList(
              limit: any(named: 'limit'),
              page: any(named: 'page'),
            ),
          ).thenThrow(const DirectMessageRepositoryApiFailure(statusCode: 500));
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const ConversationListInitialLoadRequested()),
        expect: () => [
          const ConversationListState(
            status: ConversationListStatus.loading,
          ),
          const ConversationListState(status: ConversationListStatus.failure),
        ],
      );
    });

    group('ConversationListRefreshRequested', () {
      blocTest<ConversationListBloc, ConversationListState>(
        'merges refreshed conversations ahead of the existing list',
        setUp: () {
          when(
            () => directMessageRepository.getConversationList(
              limit: any(named: 'limit'),
              page: any(named: 'page'),
            ),
          ).thenAnswer(
            (_) async => DirectMessageConversationPage(
              conversations: shortSecondPage,
              hasMore: false,
              nextPage: null,
            ),
          );
        },
        build: buildBloc,
        seed: () => ConversationListState(
          status: ConversationListStatus.success,
          conversations: fullPage,
          hasMore: true,
          nextPage: 2,
        ),
        act: (bloc) => bloc.add(const ConversationListRefreshRequested()),
        expect: () => [
          ConversationListState(
            status: ConversationListStatus.success,
            conversations: fullPage,
            hasMore: true,
            nextPage: 2,
            refreshStatus: ConversationRefreshStatus.inProgress,
          ),
          ConversationListState(
            status: ConversationListStatus.success,
            conversations: [...shortSecondPage, ...fullPage],
          ),
        ],
      );

      blocTest<ConversationListBloc, ConversationListState>(
        'emits a failure refresh status and keeps the list when the refresh '
        'fails',
        setUp: () {
          when(
            () => directMessageRepository.getConversationList(
              limit: any(named: 'limit'),
              page: any(named: 'page'),
            ),
          ).thenThrow(const DirectMessageRepositoryUnknownFailure());
        },
        build: buildBloc,
        seed: () => ConversationListState(
          status: ConversationListStatus.success,
          conversations: shortPage,
        ),
        act: (bloc) => bloc.add(const ConversationListRefreshRequested()),
        expect: () => [
          ConversationListState(
            status: ConversationListStatus.success,
            conversations: shortPage,
            refreshStatus: ConversationRefreshStatus.inProgress,
          ),
          ConversationListState(
            status: ConversationListStatus.success,
            conversations: shortPage,
            refreshStatus: ConversationRefreshStatus.failure,
          ),
        ],
      );
    });

    group('ConversationListLoadMoreRequested', () {
      blocTest<ConversationListBloc, ConversationListState>(
        'appends the next page and advances the page cursor',
        setUp: () {
          when(
            () => directMessageRepository.getConversationList(
              limit: any(named: 'limit'),
              page: any(named: 'page'),
            ),
          ).thenAnswer(
            (_) async => DirectMessageConversationPage(
              conversations: secondPage,
              hasMore: true,
              nextPage: 3,
            ),
          );
        },
        build: buildBloc,
        seed: () => ConversationListState(
          status: ConversationListStatus.success,
          conversations: fullPage,
          hasMore: true,
          nextPage: 2,
        ),
        act: (bloc) => bloc.add(const ConversationListLoadMoreRequested()),
        expect: () => [
          ConversationListState(
            status: ConversationListStatus.success,
            conversations: fullPage,
            hasMore: true,
            nextPage: 2,
            loadMoreStatus: ConversationLoadMoreStatus.inProgress,
          ),
          ConversationListState(
            status: ConversationListStatus.success,
            conversations: [...fullPage, ...secondPage],
            hasMore: true,
            nextPage: 3,
          ),
        ],
        verify: (_) {
          verify(
            () => directMessageRepository.getConversationList(
              limit: pageSize,
              page: 2,
            ),
          ).called(1);
        },
      );

      blocTest<ConversationListBloc, ConversationListState>(
        'stops loading when the next page is shorter than the page size',
        setUp: () {
          when(
            () => directMessageRepository.getConversationList(
              limit: any(named: 'limit'),
              page: any(named: 'page'),
            ),
          ).thenAnswer(
            (_) async => DirectMessageConversationPage(
              conversations: shortSecondPage,
              hasMore: false,
              nextPage: null,
            ),
          );
        },
        build: buildBloc,
        seed: () => ConversationListState(
          status: ConversationListStatus.success,
          conversations: fullPage,
          hasMore: true,
          nextPage: 2,
        ),
        act: (bloc) => bloc.add(const ConversationListLoadMoreRequested()),
        expect: () => [
          ConversationListState(
            status: ConversationListStatus.success,
            conversations: fullPage,
            hasMore: true,
            nextPage: 2,
            loadMoreStatus: ConversationLoadMoreStatus.inProgress,
          ),
          ConversationListState(
            status: ConversationListStatus.success,
            conversations: [...fullPage, ...shortSecondPage],
          ),
        ],
      );

      blocTest<ConversationListBloc, ConversationListState>(
        'emits a failure load-more status and keeps the list when loading '
        'more fails',
        setUp: () {
          when(
            () => directMessageRepository.getConversationList(
              limit: any(named: 'limit'),
              page: any(named: 'page'),
            ),
          ).thenThrow(const DirectMessageRepositoryUnknownFailure());
        },
        build: buildBloc,
        seed: () => ConversationListState(
          status: ConversationListStatus.success,
          conversations: shortPage,
          hasMore: true,
          nextPage: 2,
        ),
        act: (bloc) => bloc.add(const ConversationListLoadMoreRequested()),
        expect: () => [
          ConversationListState(
            status: ConversationListStatus.success,
            conversations: shortPage,
            hasMore: true,
            nextPage: 2,
            loadMoreStatus: ConversationLoadMoreStatus.inProgress,
          ),
          ConversationListState(
            status: ConversationListStatus.success,
            conversations: shortPage,
            hasMore: true,
            nextPage: 2,
            loadMoreStatus: ConversationLoadMoreStatus.failure,
          ),
        ],
      );

      blocTest<ConversationListBloc, ConversationListState>(
        'does nothing when no more pages are available',
        build: buildBloc,
        seed: () => ConversationListState(
          status: ConversationListStatus.success,
          conversations: shortPage,
        ),
        act: (bloc) => bloc.add(const ConversationListLoadMoreRequested()),
        expect: () => <ConversationListState>[],
        verify: (_) {
          verifyNever(
            () => directMessageRepository.getConversationList(
              limit: any(named: 'limit'),
              page: any(named: 'page'),
            ),
          );
        },
      );
    });
  });
}
