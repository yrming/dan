import 'package:direct_message_repository/direct_message_repository.dart';
import 'package:equatable/equatable.dart';

/// Status of an incremental history load of earlier messages.
enum ConversationHistoryLoadStatus {
  /// No history load is in flight.
  idle,

  /// A history load is in flight.
  inProgress,

  /// The last history load failed and can be retried.
  failure,
}

/// Status of sending a new direct message.
enum ConversationSendStatus {
  /// No message is being sent.
  idle,

  /// A message is being sent.
  inProgress,

  /// The last send attempt failed.
  failure,
}

/// Status of deleting an existing direct message.
enum ConversationDeletionStatus {
  /// No deletion is in flight.
  idle,

  /// A deletion is in flight.
  inProgress,

  /// The last deletion attempt failed.
  failure,
}

/// States of the single conversation feature.
sealed class ConversationState extends Equatable {
  /// Creates a conversation state.
  const ConversationState({this.peerScreenName});

  /// Screen name of the peer account, when it is already known.
  ///
  /// Supplied so the header can render before the first load finishes and
  /// after a failure.
  final String? peerScreenName;

  @override
  List<Object?> get props => [peerScreenName];
}

/// Initial state before any load was requested.
final class ConversationInitial extends ConversationState {
  /// Creates the initial conversation state.
  const ConversationInitial({super.peerScreenName});
}

/// A conversation load is in progress.
final class ConversationLoadInProgress extends ConversationState {
  /// Creates the loading conversation state.
  const ConversationLoadInProgress({super.peerScreenName});
}

/// A conversation load succeeded.
final class ConversationLoadSuccess extends ConversationState {
  /// Creates the successful conversation state.
  const ConversationLoadSuccess({
    required this.messages,
    super.peerScreenName,
    this.hasMore = false,
    this.nextPage,
    this.historyLoadStatus = ConversationHistoryLoadStatus.idle,
    this.sendStatus = ConversationSendStatus.idle,
    this.deletionStatus = ConversationDeletionStatus.idle,
    this.failureMessage,
  });

  /// Messages ordered newest first.
  final List<DirectMessage> messages;

  /// Whether an earlier page of messages may exist.
  final bool hasMore;

  /// Page number to request next, or `null` when [hasMore] is false.
  final int? nextPage;

  /// Status of the incremental history load.
  final ConversationHistoryLoadStatus historyLoadStatus;

  /// Status of the latest send attempt.
  final ConversationSendStatus sendStatus;

  /// Status of the latest deletion attempt.
  final ConversationDeletionStatus deletionStatus;

  final String? failureMessage;

  /// Returns a copy with selected fields replaced.
  ConversationLoadSuccess copyWith({
    List<DirectMessage>? messages,
    String? peerScreenName,
    bool? hasMore,
    Object? nextPage = _unset,
    ConversationHistoryLoadStatus? historyLoadStatus,
    ConversationSendStatus? sendStatus,
    ConversationDeletionStatus? deletionStatus,
    Object? failureMessage = _unset,
  }) {
    return ConversationLoadSuccess(
      messages: messages ?? this.messages,
      peerScreenName: peerScreenName ?? this.peerScreenName,
      hasMore: hasMore ?? this.hasMore,
      nextPage: nextPage == _unset ? this.nextPage : nextPage as int?,
      historyLoadStatus: historyLoadStatus ?? this.historyLoadStatus,
      sendStatus: sendStatus ?? this.sendStatus,
      deletionStatus: deletionStatus ?? this.deletionStatus,
      failureMessage: failureMessage == _unset
          ? this.failureMessage
          : failureMessage as String?,
    );
  }

  @override
  List<Object?> get props => [
    messages,
    peerScreenName,
    hasMore,
    nextPage,
    historyLoadStatus,
    sendStatus,
    deletionStatus,
    failureMessage,
  ];
}

/// A conversation load failed.
final class ConversationLoadFailure extends ConversationState {
  /// Creates the failed conversation state.
  const ConversationLoadFailure({super.peerScreenName, this.message});

  final String? message;

  @override
  List<Object?> get props => [...super.props, message];
}

const _unset = Object();
