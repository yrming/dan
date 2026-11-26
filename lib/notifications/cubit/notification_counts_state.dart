import 'package:equatable/equatable.dart';
import 'package:user_repository/user_repository.dart';

/// Base state for unread notification counters.
sealed class NotificationCountsState extends Equatable {
  /// Creates a notification counter state.
  const new({this.counts});

  /// Latest counters, when they have been loaded.
  final UserNotificationCounts? counts;

  /// Number of unread mentions.
  int? get mentions => counts?.mentions;

  /// Number of unread direct messages.
  int? get directMessages => counts?.directMessages;

  /// Number of pending follow requests.
  int? get friendRequests => counts?.friendRequests;

  @override
  List<Object?> get props => [counts];
}

/// No notification counters have been requested.
final class NotificationCountsInitial extends NotificationCountsState {
  /// Creates an initial notification counter state.
  const new();
}

/// Notification counters are being loaded.
final class NotificationCountsLoadInProgress extends NotificationCountsState {
  /// Creates a loading notification counter state.
  const new({super.counts});
}

/// Notification counters loaded successfully.
final class NotificationCountsLoadSuccess extends NotificationCountsState {
  /// Creates a successful notification counter state.
  const new({required UserNotificationCounts counts}) : super(counts: counts);
}

/// Notification counters could not be loaded.
final class NotificationCountsLoadFailure extends NotificationCountsState {
  /// Creates a failed notification counter state.
  const new({super.counts});
}
