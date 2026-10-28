import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:direct_message_repository/direct_message_repository.dart';
import 'package:equatable/equatable.dart';

part 'conversation_list_event.dart';
part 'conversation_list_state.dart';

/// Coordinates loading, refresh, and pagination for one conversation list.
class ConversationListBloc
    extends Bloc<ConversationListEvent, ConversationListState> {
  /// Creates a conversation list bloc.
  ConversationListBloc({required this._directMessageRepository})
    : super(const ConversationListState()) {
    on<ConversationListConversationOpened>(_onConversationOpened);
    on<ConversationListInitialLoadRequested>(
      _onInitialLoadRequested,
      transformer: restartable(),
    );
    on<ConversationListRefreshRequested>(
      _onRefreshRequested,
      transformer: restartable(),
    );
    on<ConversationListLoadMoreRequested>(
      _onLoadMoreRequested,
      transformer: droppable(),
    );
    on<ConversationListMessageChanged>(
      _onMessageChanged,
      transformer: sequential(),
    );

    _messageChangesSubscription = _directMessageRepository.messageChanges
        .listen(
          (change) => add(ConversationListMessageChanged(change: change)),
          onError: addError,
        );
  }

  final DirectMessageRepository _directMessageRepository;

  late final StreamSubscription<DirectMessageChange>
  _messageChangesSubscription;

  static const _pageSize = 20;

  @override
  Future<void> close() async {
    await _messageChangesSubscription.cancel();
    return super.close();
  }

  void _onConversationOpened(
    ConversationListConversationOpened event,
    Emitter<ConversationListState> emit,
  ) {
    emit(
      state.copyWith(
        conversations: List.unmodifiable([
          for (final conversation in state.conversations)
            if (conversation.otherUserId == event.userId &&
                conversation.hasUnread)
              conversation.copyWith(hasUnread: false)
            else
              conversation,
        ]),
      ),
    );
  }

  Future<void> _onInitialLoadRequested(
    ConversationListInitialLoadRequested event,
    Emitter<ConversationListState> emit,
  ) async {
    emit(
      const ConversationListState(status: ConversationListStatus.loading),
    );
    try {
      final page = await _fetchPage(page: 1);
      emit(_stateFromFirstPage(page));
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(
        ConversationListState(
          status: ConversationListStatus.failure,
          failureMessage: error is DirectMessageRepositoryApiFailure
              ? error.message
              : null,
        ),
      );
    }
  }

  Future<void> _onRefreshRequested(
    ConversationListRefreshRequested event,
    Emitter<ConversationListState> emit,
  ) async {
    emit(
      state.copyWith(
        refreshStatus: ConversationRefreshStatus.inProgress,
        loadMoreStatus: ConversationLoadMoreStatus.idle,
      ),
    );
    try {
      final page = await _fetchPage(page: 1);
      final conversations = page.conversations.isEmpty
          ? state.conversations
          : _mergeConversations(page.conversations, state.conversations);
      emit(
        state.copyWith(
          status: conversations.isEmpty
              ? ConversationListStatus.empty
              : ConversationListStatus.success,
          refreshStatus: ConversationRefreshStatus.idle,
          conversations: conversations,
          hasMore: page.hasMore,
          nextPage: page.nextPage,
        ),
      );
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(
        state.copyWith(
          refreshStatus: ConversationRefreshStatus.failure,
          failureMessage: error is DirectMessageRepositoryApiFailure
              ? error.message
              : null,
        ),
      );
    }
  }

  Future<void> _onLoadMoreRequested(
    ConversationListLoadMoreRequested event,
    Emitter<ConversationListState> emit,
  ) async {
    if (state.status != ConversationListStatus.success ||
        state.refreshStatus == ConversationRefreshStatus.inProgress ||
        state.loadMoreStatus == ConversationLoadMoreStatus.inProgress ||
        !state.hasMore ||
        state.nextPage == null) {
      return;
    }

    final requestPage = state.nextPage!;
    final previousConversations = state.conversations;
    emit(state.copyWith(loadMoreStatus: ConversationLoadMoreStatus.inProgress));
    try {
      final page = await _fetchPage(page: requestPage);
      final conversations = _mergeConversations(
        previousConversations,
        page.conversations,
      );
      final nextPage = page.nextPage;
      final hasMore =
          page.hasMore && nextPage != null && nextPage != requestPage;
      emit(
        state.copyWith(
          loadMoreStatus: ConversationLoadMoreStatus.idle,
          conversations: conversations,
          hasMore: hasMore,
          nextPage: hasMore ? nextPage : null,
        ),
      );
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(
        state.copyWith(
          loadMoreStatus: ConversationLoadMoreStatus.failure,
          failureMessage: error is DirectMessageRepositoryApiFailure
              ? error.message
              : null,
        ),
      );
    }
  }

  /// Applies repository mutations, such as a deleted message refreshing the
  /// affected conversation summaries in place.
  Future<void> _onMessageChanged(
    ConversationListMessageChanged event,
    Emitter<ConversationListState> emit,
  ) async {
    if (event.change is! DirectMessageDeleted) return;
    if (state.status != ConversationListStatus.success) return;
    try {
      final page = await _fetchPage(page: 1);
      emit(
        state.copyWith(
          conversations: _mergeConversations(
            page.conversations,
            state.conversations,
          ),
          hasMore: page.hasMore,
          nextPage: page.nextPage,
        ),
      );
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
    }
  }

  Future<DirectMessageConversationPage> _fetchPage({required int page}) {
    return _directMessageRepository.getConversationList(
      limit: _pageSize,
      page: page,
    );
  }

  ConversationListState _stateFromFirstPage(
    DirectMessageConversationPage page,
  ) {
    return ConversationListState(
      status: page.conversations.isEmpty
          ? ConversationListStatus.empty
          : ConversationListStatus.success,
      conversations: page.conversations,
      hasMore: page.hasMore,
      nextPage: page.nextPage,
    );
  }

  List<DirectMessageConversation> _mergeConversations(
    Iterable<DirectMessageConversation> first,
    Iterable<DirectMessageConversation> second,
  ) {
    final conversationsByUserId = <String, DirectMessageConversation>{};
    for (final conversation in first) {
      conversationsByUserId[conversation.otherUserId] = conversation;
    }
    for (final conversation in second) {
      conversationsByUserId.putIfAbsent(
        conversation.otherUserId,
        () => conversation,
      );
    }
    return conversationsByUserId.values.toList();
  }
}
