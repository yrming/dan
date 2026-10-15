part of 'status_detail_cubit.dart';

/// Status detail loading status.
enum StatusDetailStatus {
  /// Nothing has been requested yet.
  initial,

  /// A request is in progress.
  loading,

  /// Status loaded successfully.
  success,

  /// The request failed.
  failure,
}

/// Result of a favorite mutation on the detail page.
enum StatusFavoriteActionStatus {
  /// No operation has started.
  initial,

  /// The status was favorited.
  favorited,

  /// The status was unfavorited.
  unfavorited,

  /// The operation failed.
  failure,
}

/// State for one status detail page.
final class StatusDetailState extends Equatable {
  /// Creates a status detail state.
  StatusDetailState({
    this.status = StatusDetailStatus.initial,
    this.statusDetail,
    this.contextStatus = StatusDetailStatus.initial,
    this.originUnavailable = false,
    this.favoriteActionStatus = StatusFavoriteActionStatus.initial,
    this.favoriteActionMessage,
    List<Status> replies = const [],
  }) : replies = List.unmodifiable(replies);

  /// Current loading status.
  final StatusDetailStatus status;

  /// Loaded status detail.
  final Status? statusDetail;

  /// Loading state of the conversation, independent of the cached status.
  final StatusDetailStatus contextStatus;

  /// Whether the original message was deleted or is not accessible.
  final bool originUnavailable;

  /// Latest favorite mutation result.
  final StatusFavoriteActionStatus favoriteActionStatus;

  final String? favoriteActionMessage;

  /// Conversation messages excluding the original status.
  final List<Status> replies;

  /// Whether the initial reply conversation still needs to be resolved.
  bool get isResolvingReply =>
      (statusDetail?.inReplyToStatusId?.isNotEmpty ?? false) &&
      replies.isEmpty &&
      !originUnavailable &&
      (contextStatus == StatusDetailStatus.initial ||
          contextStatus == StatusDetailStatus.loading);

  /// Returns a copy with updated fields.
  StatusDetailState copyWith({
    StatusDetailStatus? status,
    Status? statusDetail,
    StatusDetailStatus? contextStatus,
    bool? originUnavailable,
    StatusFavoriteActionStatus? favoriteActionStatus,
    List<Status>? replies,
    Object? favoriteActionMessage = _unset,
  }) {
    return StatusDetailState(
      status: status ?? this.status,
      statusDetail: statusDetail ?? this.statusDetail,
      contextStatus: contextStatus ?? this.contextStatus,
      originUnavailable: originUnavailable ?? this.originUnavailable,
      favoriteActionStatus: favoriteActionStatus ?? this.favoriteActionStatus,
      favoriteActionMessage: favoriteActionMessage == _unset
          ? this.favoriteActionMessage
          : favoriteActionMessage as String?,
      replies: replies ?? this.replies,
    );
  }

  @override
  List<Object?> get props => [
    status,
    statusDetail,
    contextStatus,
    originUnavailable,
    favoriteActionStatus,
    favoriteActionMessage,
    replies,
  ];
}

const _unset = Object();
