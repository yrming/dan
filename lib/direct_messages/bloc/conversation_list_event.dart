part of 'conversation_list_bloc.dart';

/// Base type for conversation list events.
sealed class ConversationListEvent extends Equatable {
  /// Creates a conversation list event.
  const ConversationListEvent();

  @override
  List<Object?> get props => [];
}

/// Records a conversation opened from the list.
final class ConversationListConversationOpened extends ConversationListEvent {
  /// Records opening a conversation so its local unread indicator is cleared.
  const ConversationListConversationOpened({required this.userId});

  /// Identifier of the conversation peer.
  final String userId;

  @override
  List<Object?> get props => [userId];
}

/// Requests the first page of conversations.
final class ConversationListInitialLoadRequested extends ConversationListEvent {
  /// Creates an initial load request.
  const ConversationListInitialLoadRequested();
}

/// Requests a refresh of the conversation list.
final class ConversationListRefreshRequested extends ConversationListEvent {
  /// Creates a refresh request.
  const ConversationListRefreshRequested();
}

/// Requests the next page of conversations.
final class ConversationListLoadMoreRequested extends ConversationListEvent {
  /// Creates a load-more request.
  const ConversationListLoadMoreRequested();
}

/// Applies a direct-message mutation published by the repository.
final class ConversationListMessageChanged extends ConversationListEvent {
  /// Creates a message change event.
  const ConversationListMessageChanged({required this.change});

  /// Published mutation to apply to the list.
  final DirectMessageChange change;

  @override
  List<Object?> get props => [change];
}
