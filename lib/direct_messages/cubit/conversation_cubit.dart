import 'package:bloc/bloc.dart';
import 'package:dan/direct_messages/cubit/conversation_state.dart';
import 'package:direct_message_repository/direct_message_repository.dart';

/// Loads the messages exchanged with one peer account.
class ConversationCubit extends Cubit<ConversationState> {
  /// Creates a conversation cubit.
  ConversationCubit({
    required this._directMessageRepository,
    required this._userId,
    required this._activeAccountId,
    String? initialPeerScreenName,
  }) : _initialPeerScreenName = initialPeerScreenName,
       super(ConversationInitial(peerScreenName: initialPeerScreenName));

  final DirectMessageRepository _directMessageRepository;
  final String _userId;
  final String? _activeAccountId;
  final String? _initialPeerScreenName;

  static const _pageSize = 20;

  /// Loads the messages exchanged with the peer account.
  Future<void> load() async {
    emit(ConversationLoadInProgress(peerScreenName: _initialPeerScreenName));
    try {
      final page = await _directMessageRepository.getConversation(
        _userId,
        limit: _pageSize,
        page: 1,
      );
      emit(
        ConversationLoadSuccess(
          messages: page.messages,
          hasMore: page.hasMore,
          nextPage: page.nextPage,
          peerScreenName:
              _initialPeerScreenName ?? _peerScreenNameFrom(page.messages),
        ),
      );
    } on Object catch (error) {
      emit(
        ConversationLoadFailure(
          peerScreenName: _initialPeerScreenName,
          message: error is DirectMessageRepositoryApiFailure
              ? error.message
              : null,
        ),
      );
    }
  }

  /// Loads one earlier page of messages and prepends it to the list.
  Future<void> loadMore() async {
    final state = this.state;
    if (state is! ConversationLoadSuccess ||
        !state.hasMore ||
        state.nextPage == null ||
        state.historyLoadStatus == ConversationHistoryLoadStatus.inProgress) {
      return;
    }

    final requestPage = state.nextPage!;
    final previousMessages = state.messages;
    emit(
      state.copyWith(
        historyLoadStatus: ConversationHistoryLoadStatus.inProgress,
      ),
    );
    try {
      final page = await _directMessageRepository.getConversation(
        _userId,
        limit: _pageSize,
        page: requestPage,
      );
      final knownMessageIds = previousMessages
          .map((message) => message.id)
          .toSet();
      final olderMessages = page.messages
          .where((message) => !knownMessageIds.contains(message.id))
          .toList();
      final nextPage = page.nextPage;
      final hasMore =
          page.hasMore && nextPage != null && nextPage != requestPage;
      emit(
        state.copyWith(
          // The array is newest first, so the older page goes to the end
          // (the visual top of the chronologically rendered transcript).
          messages: [...previousMessages, ...olderMessages],
          hasMore: hasMore,
          nextPage: hasMore ? nextPage : null,
          historyLoadStatus: ConversationHistoryLoadStatus.idle,
        ),
      );
    } on Object catch (error) {
      emit(
        state.copyWith(
          historyLoadStatus: ConversationHistoryLoadStatus.failure,
          failureMessage: error is DirectMessageRepositoryApiFailure
              ? error.message
              : null,
        ),
      );
    }
  }

  /// Sends [text] to the conversation peer and adds the result to the list.
  Future<void> sendMessage(String text) async {
    final state = this.state;
    if (state is! ConversationLoadSuccess ||
        state.sendStatus == ConversationSendStatus.inProgress ||
        text.trim().isEmpty) {
      return;
    }

    emit(state.copyWith(sendStatus: ConversationSendStatus.inProgress));
    try {
      final message = await _directMessageRepository.sendMessage(
        _userId,
        text.trim(),
      );
      emit(
        state.copyWith(
          messages: [message, ...state.messages],
          sendStatus: ConversationSendStatus.idle,
        ),
      );
    } on Object catch (error) {
      emit(
        state.copyWith(
          sendStatus: ConversationSendStatus.failure,
          failureMessage: error is DirectMessageRepositoryApiFailure
              ? error.message
              : null,
        ),
      );
    }
  }

  /// Deletes [messageId] and removes it from the transcript.
  Future<void> deleteMessage(String messageId) async {
    final state = this.state;
    if (state is! ConversationLoadSuccess ||
        state.deletionStatus == ConversationDeletionStatus.inProgress) {
      return;
    }

    emit(
      state.copyWith(deletionStatus: ConversationDeletionStatus.inProgress),
    );
    try {
      await _directMessageRepository.deleteMessage(messageId);
      emit(
        state.copyWith(
          messages: state.messages
              .where((message) => message.id != messageId)
              .toList(),
          deletionStatus: ConversationDeletionStatus.idle,
        ),
      );
    } on Object catch (error) {
      emit(
        state.copyWith(
          deletionStatus: ConversationDeletionStatus.failure,
          failureMessage: error is DirectMessageRepositoryApiFailure
              ? error.message
              : null,
        ),
      );
    }
  }

  String? _peerScreenNameFrom(List<DirectMessage> messages) {
    for (final message in messages) {
      if (message.senderId != _activeAccountId) {
        return message.senderScreenName;
      }
    }
    return null;
  }
}
