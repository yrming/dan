part of 'conversation_list_bloc.dart';

/// Load status of the conversation list as a whole.
enum ConversationListStatus {
  /// No load was requested yet.
  initial,

  /// The first page is loading.
  loading,

  /// The list finished loading and holds no conversations.
  empty,

  /// The list finished loading and holds conversations.
  success,

  /// The first page failed to load.
  failure,
}

/// Status of an incremental load-more request.
enum ConversationLoadMoreStatus {
  /// No load-more request is in flight.
  idle,

  /// A load-more request is in flight.
  inProgress,

  /// The last load-more request failed and can be retried.
  failure,
}

/// Status of a pull-to-refresh request.
enum ConversationRefreshStatus {
  /// No refresh request is in flight.
  idle,

  /// A refresh request is in flight.
  inProgress,

  /// The last refresh request failed.
  failure,
}

/// State of the direct message conversation list.
final class ConversationListState extends Equatable {
  /// Creates a conversation list state.
  const ConversationListState({
    this.status = ConversationListStatus.initial,
    this.conversations = const [],
    this.hasMore = false,
    this.nextPage,
    this.loadMoreStatus = ConversationLoadMoreStatus.idle,
    this.refreshStatus = ConversationRefreshStatus.idle,
    this.failureMessage,
  });

  /// Overall load status of the list.
  final ConversationListStatus status;

  /// Conversations ordered newest first.
  final List<DirectMessageConversation> conversations;

  /// Whether another page of conversations may exist.
  final bool hasMore;

  /// Page number to request next, or `null` when [hasMore] is false.
  final int? nextPage;

  /// Status of the incremental load-more request.
  final ConversationLoadMoreStatus loadMoreStatus;

  /// Status of the pull-to-refresh request.
  final ConversationRefreshStatus refreshStatus;

  final String? failureMessage;

  /// Returns a copy with selected fields replaced.
  ConversationListState copyWith({
    ConversationListStatus? status,
    List<DirectMessageConversation>? conversations,
    bool? hasMore,
    Object? nextPage = _unset,
    ConversationLoadMoreStatus? loadMoreStatus,
    ConversationRefreshStatus? refreshStatus,
    Object? failureMessage = _unset,
  }) {
    return ConversationListState(
      status: status ?? this.status,
      conversations: conversations ?? this.conversations,
      hasMore: hasMore ?? this.hasMore,
      nextPage: nextPage == _unset ? this.nextPage : nextPage as int?,
      loadMoreStatus: loadMoreStatus ?? this.loadMoreStatus,
      refreshStatus: refreshStatus ?? this.refreshStatus,
      failureMessage: failureMessage == _unset
          ? this.failureMessage
          : failureMessage as String?,
    );
  }

  @override
  List<Object?> get props => [
    status,
    conversations,
    hasMore,
    nextPage,
    loadMoreStatus,
    refreshStatus,
    failureMessage,
  ];
}

const _unset = Object();
