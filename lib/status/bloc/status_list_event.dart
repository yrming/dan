part of 'status_list_bloc.dart';

/// User and repository events handled by [StatusListBloc].
sealed class StatusListEvent extends Equatable {
  const StatusListEvent();

  @override
  List<Object?> get props => const [];
}

/// The first page was requested for a newly created list.
final class StatusListInitialLoadRequested extends StatusListEvent {
  /// Creates an initial-load request.
  const StatusListInitialLoadRequested();
}

/// The user requested the newest page while preserving visible content.
final class StatusListRefreshRequested extends StatusListEvent {
  /// Creates a refresh request.
  const StatusListRefreshRequested();
}

/// The user approached the end of the loaded list.
final class StatusListLoadMoreRequested extends StatusListEvent {
  /// Creates a load-more request.
  const StatusListLoadMoreRequested();
}

/// The repository published a mutation for a status.
final class StatusListStatusChanged extends StatusListEvent {
  /// Creates a repository change event.
  const StatusListStatusChanged(this.change);

  /// Account-scoped repository change.
  final StatusChange change;

  @override
  List<Object?> get props => [change];
}

/// The user requested deletion of one status.
final class StatusListStatusDeletionRequested extends StatusListEvent {
  /// Creates a status deletion request.
  const StatusListStatusDeletionRequested(this.statusId);

  /// Status to delete.
  final String statusId;

  @override
  List<Object?> get props => [statusId];
}

/// The user requested toggling one status's favorite state.
final class StatusListStatusFavoriteToggled extends StatusListEvent {
  /// Creates a favorite toggle request.
  const StatusListStatusFavoriteToggled(this.statusId);

  /// Status whose favorite state should be toggled.
  final String statusId;

  @override
  List<Object?> get props => [statusId];
}

/// The user submitted or cleared a public status search.
final class StatusListSearchSubmitted extends StatusListEvent {
  /// Creates a search request.
  const StatusListSearchSubmitted(this.query);

  /// Keyword entered by the user.
  final String query;

  @override
  List<Object?> get props => [query];
}
