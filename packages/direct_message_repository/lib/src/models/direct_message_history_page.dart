import 'package:direct_message_repository/src/models/direct_message.dart';
import 'package:equatable/equatable.dart';

/// One page of the direct messages exchanged with a user.
final class DirectMessageHistoryPage extends Equatable {
  /// Creates a direct message history page.
  const DirectMessageHistoryPage({
    required this.messages,
    required this.hasMore,
    required this.nextPage,
  });

  /// Messages ordered newest first.
  final List<DirectMessage> messages;

  /// Whether another, older page may follow.
  final bool hasMore;

  /// Page number to request next, or `null` when [hasMore] is false.
  final int? nextPage;

  @override
  List<Object?> get props => [messages, hasMore, nextPage];
}
