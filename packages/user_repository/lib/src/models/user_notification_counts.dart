import 'package:equatable/equatable.dart';

/// Unread notification counters for the active account.
final class UserNotificationCounts extends Equatable {
  /// Creates notification counters.
  const UserNotificationCounts({
    required this.mentions,
    required this.directMessages,
    required this.friendRequests,
  });

  /// Number of unread mentions.
  final int mentions;

  /// Number of unread direct messages.
  final int directMessages;

  /// Number of pending follow requests.
  final int friendRequests;

  @override
  List<Object> get props => [mentions, directMessages, friendRequests];
}
