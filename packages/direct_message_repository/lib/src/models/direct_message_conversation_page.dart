import 'package:direct_message_repository/src/models/direct_message_conversation.dart';
import 'package:equatable/equatable.dart';

/// One page of the active account's direct message conversations.
final class DirectMessageConversationPage extends Equatable {
  /// Creates a direct message conversation page.
  const DirectMessageConversationPage({
    required this.conversations,
    required this.hasMore,
    required this.nextPage,
  });

  /// Conversations ordered newest first.
  final List<DirectMessageConversation> conversations;

  /// Whether another page may follow.
  final bool hasMore;

  /// Page number to request next, or `null` when [hasMore] is false.
  final int? nextPage;

  @override
  List<Object?> get props => [conversations, hasMore, nextPage];
}
