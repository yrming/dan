import 'package:equatable/equatable.dart';
import 'package:user_repository/user_repository.dart';

/// Base state for loading a user profile.
sealed class UserProfileState extends Equatable {
  /// Creates a user profile state.
  const UserProfileState({this.profile});

  /// Profile available for display, including a cached summary.
  final UserProfile? profile;

  @override
  List<Object?> get props => [profile];
}

/// Profile loading has not started.
final class UserProfileInitial extends UserProfileState {
  /// Creates an initial profile state.
  const UserProfileInitial({super.profile});
}

/// Profile loading is in progress.
final class UserProfileLoadInProgress extends UserProfileState {
  /// Creates an in-progress profile state.
  const UserProfileLoadInProgress({super.profile});
}

/// Profile loading completed successfully.
final class UserProfileLoadSuccess extends UserProfileState {
  /// Creates a successful profile state.
  const UserProfileLoadSuccess({
    required UserProfile profile,
    this.followedBy,
    this.isFollowingUpdating = false,
    this.actionFailureCount = 0,
    this.actionFailureMessage,
    this.requestSentCount = 0,
    this.isBlocked,
    this.isBlockActionInProgress = false,
    this.blockActionCount = 0,
    this.blockActionFailureCount = 0,
    this.blockActionFailed = false,
    this.blockActionMessage,
  }) : super(profile: profile);

  /// Whether the displayed user follows the active account, when known.
  final bool? followedBy;

  /// Whether a follow or unfollow request is in progress.
  final bool isFollowingUpdating;

  /// Number of failed follow actions, for one-time feedback.
  final int actionFailureCount;

  /// Server feedback for the latest action failure.
  final String? actionFailureMessage;

  /// Number of follow requests awaiting approval, for one-time feedback.
  final int requestSentCount;

  /// Whether the active account has blocked the displayed user.
  final bool? isBlocked;

  /// Whether a block or unblock request is in progress.
  final bool isBlockActionInProgress;

  /// Number of completed block actions, for one-time feedback.
  final int blockActionCount;

  /// Number of failed block actions, for one-time feedback.
  final int blockActionFailureCount;

  /// Whether the latest block action failed.
  final bool blockActionFailed;

  /// Server feedback for the latest block action failure.
  final String? blockActionMessage;

  /// Updates the loaded profile and its follow action state.
  /// Clears transient failure feedback unless a new message is supplied.
  UserProfileLoadSuccess copyWith({
    UserProfile? profile,
    bool? followedBy,
    bool? isFollowingUpdating,
    int? actionFailureCount,
    String? actionFailureMessage,
    int? requestSentCount,
    bool? isBlocked,
    bool? isBlockActionInProgress,
    int? blockActionCount,
    int? blockActionFailureCount,
    bool? blockActionFailed,
    String? blockActionMessage,
  }) => UserProfileLoadSuccess(
    profile: profile ?? this.profile!,
    followedBy: followedBy ?? this.followedBy,
    isFollowingUpdating: isFollowingUpdating ?? this.isFollowingUpdating,
    actionFailureCount: actionFailureCount ?? this.actionFailureCount,
    actionFailureMessage: actionFailureMessage,
    requestSentCount: requestSentCount ?? this.requestSentCount,
    isBlocked: isBlocked ?? this.isBlocked,
    isBlockActionInProgress:
        isBlockActionInProgress ?? this.isBlockActionInProgress,
    blockActionCount: blockActionCount ?? this.blockActionCount,
    blockActionFailureCount:
        blockActionFailureCount ?? this.blockActionFailureCount,
    blockActionFailed: blockActionFailed ?? this.blockActionFailed,
    blockActionMessage: blockActionMessage,
  );

  @override
  List<Object?> get props => [
    ...super.props,
    followedBy,
    isFollowingUpdating,
    actionFailureCount,
    actionFailureMessage,
    requestSentCount,
    isBlocked,
    isBlockActionInProgress,
    blockActionCount,
    blockActionFailureCount,
    blockActionFailed,
    blockActionMessage,
  ];
}

/// Profile loading failed.
final class UserProfileLoadFailure extends UserProfileState {
  /// Creates a failed profile state.
  const UserProfileLoadFailure({super.profile});
}
