part of 'status_list_bloc.dart';

/// Overall status for the first visible page.
enum StatusListStatus {
  /// Nothing has been requested yet.
  initial,

  /// The first page is loading without existing content.
  loading,

  /// At least one status is available.
  success,

  /// The feed has no statuses.
  empty,

  /// The first page could not be loaded.
  failure,
}

/// State of a pull-to-refresh operation.
enum StatusRefreshStatus {
  /// No refresh is running.
  idle,

  /// The newest page is being loaded.
  inProgress,

  /// The latest refresh failed while existing content was retained.
  failure,
}

/// State of an infinite-scroll request.
enum StatusLoadMoreStatus {
  /// No pagination request is running.
  idle,

  /// The next page is being loaded.
  inProgress,

  /// The latest pagination request failed.
  failure,
}

/// Mutation action that failed for a single status.
enum StatusAction {
  /// Status deletion.
  delete,

  /// Favorite or unfavorite mutation.
  favorite,
}

/// Sanitized failure for one status mutation.
final class StatusActionFailure extends Equatable {
  /// Creates a status action failure.
  const StatusActionFailure({
    required this.statusId,
    required this.action,
    this.message,
  });

  /// Status whose mutation failed.
  final String statusId;

  /// Failed mutation type.
  final StatusAction action;

  final String? message;

  @override
  List<Object?> get props => [statusId, action, message];
}

/// Result of a successful favorite toggle.
final class StatusFavoriteSuccess extends Equatable {
  const StatusFavoriteSuccess({
    required this.statusId,
    required this.isFavorited,
  });

  final String statusId;
  final bool isFavorited;

  @override
  List<Object?> get props => [statusId, isFavorited];
}

/// Immutable state for a timeline-like status list.
final class StatusListState extends Equatable {
  /// Creates status list state.
  StatusListState({
    this.status = StatusListStatus.initial,
    this.searchQuery = '',
    this.hasProfileCountMismatch = false,
    this.refreshStatus = StatusRefreshStatus.idle,
    this.loadMoreStatus = StatusLoadMoreStatus.idle,
    Iterable<Status> statuses = const [],
    this.hasMore = true,
    this.nextCursor,
    Iterable<String> deletingStatusIds = const {},
    Iterable<String> updatingFavoriteStatusIds = const {},
    this.actionFailure,
    this.favoriteSuccess,
    this.requestFailureMessage,
  }) : statuses = List<Status>.unmodifiable(statuses),
       deletingStatusIds = Set<String>.unmodifiable(deletingStatusIds),
       updatingFavoriteStatusIds = Set<String>.unmodifiable(
         updatingFavoriteStatusIds,
       );

  /// Overall first-page status.
  final StatusListStatus status;

  /// Submitted keyword for a search feed.
  final String searchQuery;

  /// Whether a positive profile count conflicts with an empty first page.
  final bool hasProfileCountMismatch;

  /// Pull-to-refresh status.
  final StatusRefreshStatus refreshStatus;

  /// Infinite-scroll status.
  final StatusLoadMoreStatus loadMoreStatus;

  /// Loaded statuses in display order.
  final List<Status> statuses;

  /// Whether another page may be available.
  final bool hasMore;

  /// Opaque repository cursor for the next page.
  final String? nextCursor;

  /// Status identifiers currently being deleted.
  final Set<String> deletingStatusIds;

  /// Status identifiers currently changing favorite state.
  final Set<String> updatingFavoriteStatusIds;

  /// Most recent sanitized mutation failure.
  final StatusActionFailure? actionFailure;

  final StatusFavoriteSuccess? favoriteSuccess;
  final String? requestFailureMessage;

  /// Returns a copy with selected fields replaced.
  StatusListState copyWith({
    StatusListStatus? status,
    bool? hasProfileCountMismatch,
    StatusRefreshStatus? refreshStatus,
    StatusLoadMoreStatus? loadMoreStatus,
    Iterable<Status>? statuses,
    bool? hasMore,
    Object? nextCursor = _unset,
    Iterable<String>? deletingStatusIds,
    Iterable<String>? updatingFavoriteStatusIds,
    Object? actionFailure = _unset,
    Object? favoriteSuccess = _unset,
    Object? requestFailureMessage = _unset,
  }) {
    return StatusListState(
      status: status ?? this.status,
      hasProfileCountMismatch:
          hasProfileCountMismatch ?? this.hasProfileCountMismatch,
      searchQuery: searchQuery,
      refreshStatus: refreshStatus ?? this.refreshStatus,
      loadMoreStatus: loadMoreStatus ?? this.loadMoreStatus,
      statuses: statuses ?? this.statuses,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor == _unset
          ? this.nextCursor
          : nextCursor as String?,
      deletingStatusIds: deletingStatusIds ?? this.deletingStatusIds,
      updatingFavoriteStatusIds:
          updatingFavoriteStatusIds ?? this.updatingFavoriteStatusIds,
      actionFailure: actionFailure == _unset
          ? this.actionFailure
          : actionFailure as StatusActionFailure?,
      favoriteSuccess: favoriteSuccess == _unset
          ? this.favoriteSuccess
          : favoriteSuccess as StatusFavoriteSuccess?,
      requestFailureMessage: requestFailureMessage == _unset
          ? this.requestFailureMessage
          : requestFailureMessage as String?,
    );
  }

  @override
  List<Object?> get props => [
    status,
    hasProfileCountMismatch,
    searchQuery,
    refreshStatus,
    loadMoreStatus,
    statuses,
    hasMore,
    nextCursor,
    deletingStatusIds,
    updatingFavoriteStatusIds,
    actionFailure,
    favoriteSuccess,
    requestFailureMessage,
  ];
}

const _unset = Object();
