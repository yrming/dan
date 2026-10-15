import 'package:direct_message_repository/src/models/direct_message.dart';
import 'package:direct_message_repository/src/models/direct_message_user.dart';
import 'package:equatable/equatable.dart';

/// Domain model for one entry of the active account's conversation list.
final class DirectMessageConversation extends Equatable {
  /// Creates a direct message conversation entry.
  const DirectMessageConversation({
    required this.otherUserId,
    required this.lastMessage,
    required this.messageCount,
    required this.hasUnread,
    this.otherUserScreenName,
    this.otherUserAvatarUrl,
    this.otherUser,
  });

  /// Identifier of the account on the other side of the conversation.
  final String otherUserId;

  /// Most recent message exchanged in the conversation.
  final DirectMessage lastMessage;

  /// Total number of messages exchanged with the other account.
  final int messageCount;

  /// Whether the conversation carries unread messages.
  final bool hasUnread;

  /// Screen name of the other account, when the API includes it.
  final String? otherUserScreenName;

  /// Avatar URL of the other account, when the API includes it.
  final String? otherUserAvatarUrl;

  /// Details of the sender or recipient whose ID matches [otherUserId].
  final DirectMessageUser? otherUser;

  /// Returns a copy with an updated unread indicator.
  DirectMessageConversation copyWith({bool? hasUnread}) =>
      DirectMessageConversation(
        otherUserId: otherUserId,
        lastMessage: lastMessage,
        messageCount: messageCount,
        hasUnread: hasUnread ?? this.hasUnread,
        otherUserScreenName: otherUserScreenName,
        otherUserAvatarUrl: otherUserAvatarUrl,
        otherUser: otherUser,
      );

  @override
  List<Object?> get props => [
    otherUserId,
    lastMessage,
    messageCount,
    hasUnread,
    otherUserScreenName,
    otherUserAvatarUrl,
    otherUser,
  ];
}
