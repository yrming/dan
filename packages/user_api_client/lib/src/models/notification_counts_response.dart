/// Notification counters returned by Fanfou's account endpoint.
final class NotificationCountsResponse {
  /// Creates typed notification counters.
  const NotificationCountsResponse({
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
}
