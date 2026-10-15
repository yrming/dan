import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:dan/status/models/status_feed.dart';
import 'package:equatable/equatable.dart';
import 'package:status_repository/status_repository.dart';

part 'status_list_event.dart';
part 'status_list_state.dart';

/// Coordinates loading, pagination, and mutations for one account feed.
class StatusListBloc extends Bloc<StatusListEvent, StatusListState> {
  /// Creates a status list bloc.
  factory StatusListBloc({
    required StatusRepository statusRepository,
    required StatusFeed feed,
    required String accountId,
    String? userId,
  }) {
    return StatusListBloc._(
      statusRepository,
      feed,
      accountId,
      userId ?? accountId,
    );
  }

  StatusListBloc._(
    this._statusRepository,
    this._feed,
    this._accountId,
    this._userId,
  ) : super(StatusListState()) {
    on<StatusListSearchSubmitted>(
      _onSearchSubmitted,
      transformer: restartable(),
    );
    on<StatusListInitialLoadRequested>(
      _onInitialLoadRequested,
      transformer: restartable(),
    );
    on<StatusListRefreshRequested>(
      _onRefreshRequested,
      transformer: restartable(),
    );
    on<StatusListLoadMoreRequested>(
      _onLoadMoreRequested,
      transformer: droppable(),
    );
    on<StatusListStatusChanged>(
      _onStatusChanged,
      transformer: sequential(),
    );
    on<StatusListStatusDeletionRequested>(_onStatusDeletionRequested);
    on<StatusListStatusFavoriteToggled>(_onStatusFavoriteToggled);

    _statusChangesSubscription = _statusRepository.statusChanges
        .where((change) => change.accountId == _accountId)
        .listen(
          (change) => add(StatusListStatusChanged(change)),
          onError: addError,
        );
  }

  final StatusRepository _statusRepository;
  final StatusFeed _feed;
  final String _accountId;
  final String _userId;
  late final StreamSubscription<StatusChange> _statusChangesSubscription;

  int _requestVersion = 0;

  Future<void> _onInitialLoadRequested(
    StatusListInitialLoadRequested event,
    Emitter<StatusListState> emit,
  ) async {
    await _loadFirstPage(state.searchQuery, emit);
  }

  Future<void> _onSearchSubmitted(
    StatusListSearchSubmitted event,
    Emitter<StatusListState> emit,
  ) async {
    if (_feed != StatusFeed.search &&
        _feed != StatusFeed.searchMine &&
        _feed != StatusFeed.searchUser) {
      return;
    }
    await _loadFirstPage(event.query.trim(), emit);
  }

  Future<void> _loadFirstPage(
    String query,
    Emitter<StatusListState> emit,
  ) async {
    final requestVersion = ++_requestVersion;
    if ((_feed == StatusFeed.search ||
            _feed == StatusFeed.searchMine ||
            _feed == StatusFeed.searchUser) &&
        query.isEmpty) {
      emit(StatusListState(hasMore: false));
      return;
    }
    emit(StatusListState(status: StatusListStatus.loading, searchQuery: query));
    try {
      final page = await _fetchPage();
      if (emit.isDone || requestVersion != _requestVersion) return;
      emit(_stateFromFirstPage(page));
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      if (emit.isDone || requestVersion != _requestVersion) return;
      emit(
        StatusListState(
          status: StatusListStatus.failure,
          searchQuery: query,
          requestFailureMessage: error is StatusRepositoryApiFailure
              ? error.message
              : null,
        ),
      );
    }
  }

  Future<void> _onRefreshRequested(
    StatusListRefreshRequested event,
    Emitter<StatusListState> emit,
  ) async {
    final requestVersion = ++_requestVersion;
    emit(
      state.copyWith(
        refreshStatus: StatusRefreshStatus.inProgress,
        loadMoreStatus: StatusLoadMoreStatus.idle,
      ),
    );
    try {
      final page = await _fetchPage(
        sinceId: state.statuses.isEmpty ? null : state.statuses.first.id,
      );
      if (emit.isDone || requestVersion != _requestVersion) return;
      final statuses = page.statuses.isEmpty
          ? state.statuses
          : _mergeStatuses(page.statuses, state.statuses);
      final hadStatuses = state.statuses.isNotEmpty;
      final preservePaginationFrontier =
          hadStatuses && _feed != StatusFeed.favorites;
      emit(
        state.copyWith(
          status: statuses.isEmpty
              ? StatusListStatus.empty
              : StatusListStatus.success,
          refreshStatus: StatusRefreshStatus.idle,
          statuses: statuses,
          hasMore: preservePaginationFrontier ? state.hasMore : page.hasMore,
          nextCursor: preservePaginationFrontier
              ? state.nextCursor
              : page.nextCursor,
        ),
      );
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      if (emit.isDone || requestVersion != _requestVersion) return;
      emit(
        state.copyWith(
          refreshStatus: StatusRefreshStatus.failure,
          requestFailureMessage: error is StatusRepositoryApiFailure
              ? error.message
              : null,
        ),
      );
    }
  }

  Future<void> _onLoadMoreRequested(
    StatusListLoadMoreRequested event,
    Emitter<StatusListState> emit,
  ) async {
    if (state.status != StatusListStatus.success ||
        state.refreshStatus == StatusRefreshStatus.inProgress ||
        state.loadMoreStatus == StatusLoadMoreStatus.inProgress ||
        !state.hasMore ||
        state.nextCursor == null) {
      return;
    }

    final requestVersion = _requestVersion;
    final cursor = state.nextCursor;
    final previousStatuses = state.statuses;
    emit(state.copyWith(loadMoreStatus: StatusLoadMoreStatus.inProgress));
    try {
      final page = await _fetchPage(maxId: cursor);
      if (emit.isDone || requestVersion != _requestVersion) return;
      final statuses = _mergeStatuses(previousStatuses, page.statuses);
      final nextCursor = page.nextCursor;
      final hasMore =
          page.hasMore && nextCursor != null && nextCursor != cursor;
      emit(
        state.copyWith(
          loadMoreStatus: StatusLoadMoreStatus.idle,
          statuses: statuses,
          hasMore: hasMore,
          nextCursor: hasMore ? nextCursor : null,
        ),
      );
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      if (emit.isDone || requestVersion != _requestVersion) return;
      emit(
        state.copyWith(
          loadMoreStatus: StatusLoadMoreStatus.failure,
          requestFailureMessage: error is StatusRepositoryApiFailure
              ? error.message
              : null,
        ),
      );
    }
  }

  void _onStatusChanged(
    StatusListStatusChanged event,
    Emitter<StatusListState> emit,
  ) {
    if (event.change.accountId != _accountId) return;
    if ((_feed == StatusFeed.search ||
            _feed == StatusFeed.searchMine ||
            _feed == StatusFeed.searchUser) &&
        state.status != StatusListStatus.success &&
        state.status != StatusListStatus.empty) {
      return;
    }
    final statuses = switch (event.change) {
      StatusCreated(:final status) => _applyCreatedStatus(status),
      StatusDeleted(:final statusId) =>
        state.statuses.where((status) => status.id != statusId).toList(),
      StatusUpdated(:final status) => _applyUpdatedStatus(status),
    };
    if (identical(statuses, state.statuses)) return;
    emit(
      state.copyWith(
        status: statuses.isEmpty
            ? StatusListStatus.empty
            : StatusListStatus.success,
        statuses: statuses,
      ),
    );
  }

  Future<void> _onStatusDeletionRequested(
    StatusListStatusDeletionRequested event,
    Emitter<StatusListState> emit,
  ) async {
    if (state.deletingStatusIds.contains(event.statusId)) return;
    emit(
      state.copyWith(
        deletingStatusIds: {...state.deletingStatusIds, event.statusId},
        actionFailure: null,
      ),
    );
    try {
      await _statusRepository.deleteStatus(event.statusId);
      emit(
        state.copyWith(
          deletingStatusIds: state.deletingStatusIds.difference({
            event.statusId,
          }),
        ),
      );
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(
        state.copyWith(
          deletingStatusIds: state.deletingStatusIds.difference({
            event.statusId,
          }),
          actionFailure: StatusActionFailure(
            statusId: event.statusId,
            action: StatusAction.delete,
            message: error is StatusRepositoryApiFailure ? error.message : null,
          ),
        ),
      );
    }
  }

  Future<void> _onStatusFavoriteToggled(
    StatusListStatusFavoriteToggled event,
    Emitter<StatusListState> emit,
  ) async {
    if (state.updatingFavoriteStatusIds.contains(event.statusId)) return;
    final status = _statusById(event.statusId);
    if (status == null) return;
    final willFavorite = !status.isFavorited;
    emit(
      state.copyWith(
        updatingFavoriteStatusIds: {
          ...state.updatingFavoriteStatusIds,
          event.statusId,
        },
        actionFailure: null,
      ),
    );
    try {
      if (status.isFavorited) {
        await _statusRepository.unfavoriteStatus(event.statusId);
      } else {
        await _statusRepository.favoriteStatus(event.statusId);
      }
      emit(
        state.copyWith(
          updatingFavoriteStatusIds: state.updatingFavoriteStatusIds.difference(
            {event.statusId},
          ),
          favoriteSuccess: StatusFavoriteSuccess(
            statusId: event.statusId,
            isFavorited: willFavorite,
          ),
        ),
      );
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(
        state.copyWith(
          updatingFavoriteStatusIds: state.updatingFavoriteStatusIds.difference(
            {event.statusId},
          ),
          favoriteSuccess: null,
          actionFailure: StatusActionFailure(
            statusId: event.statusId,
            action: StatusAction.favorite,
            message: error is StatusRepositoryApiFailure ? error.message : null,
          ),
        ),
      );
    }
  }

  Future<StatusPage> _fetchPage({String? sinceId, String? maxId}) {
    return switch (_feed) {
      StatusFeed.home => _statusRepository.getHomeTimeline(
        sinceId: sinceId,
        maxId: maxId,
      ),
      StatusFeed.public => _statusRepository.getPublicTimeline(
        sinceId: sinceId,
        maxId: maxId,
      ),
      StatusFeed.search => _statusRepository.searchStatuses(
        query: state.searchQuery,
        sinceId: sinceId,
        maxId: maxId,
      ),
      StatusFeed.searchMine => _statusRepository.searchMyStatuses(
        query: state.searchQuery,
        sinceId: sinceId,
        maxId: maxId,
      ),
      StatusFeed.searchUser => _statusRepository.searchStatuses(
        query: state.searchQuery,
        userId: _userId,
        sinceId: sinceId,
        maxId: maxId,
      ),
      StatusFeed.mentions => _statusRepository.getMentions(
        sinceId: sinceId,
        maxId: maxId,
      ),
      StatusFeed.user => _statusRepository.getUserTimeline(
        userId: _userId,
        sinceId: sinceId,
        maxId: maxId,
      ),
      StatusFeed.photos => _statusRepository.getPhotoTimeline(
        userId: _userId,
        sinceId: sinceId,
        maxId: maxId,
      ),
      StatusFeed.favorites => _statusRepository.getFavorites(
        userId: _userId,
        cursor: maxId,
      ),
    };
  }

  StatusListState _stateFromFirstPage(StatusPage page) {
    return StatusListState(
      status: page.statuses.isEmpty
          ? StatusListStatus.empty
          : StatusListStatus.success,
      searchQuery: state.searchQuery,
      statuses: page.statuses,
      hasMore: page.hasMore,
      nextCursor: page.nextCursor,
    );
  }

  List<Status> _mergeStatuses(
    Iterable<Status> first,
    Iterable<Status> second,
  ) {
    final statusesById = <String, Status>{};
    for (final status in first) {
      statusesById[status.id] = status;
    }
    for (final status in second) {
      statusesById.putIfAbsent(status.id, () => status);
    }
    return statusesById.values.toList();
  }

  List<Status> _applyUpdatedStatus(Status updatedStatus) {
    final index = state.statuses.indexWhere(
      (status) => status.id == updatedStatus.id,
    );
    if (_feed == StatusFeed.favorites && _userId == _accountId) {
      if (!updatedStatus.isFavorited) {
        if (index == -1) return state.statuses;
        return state.statuses
            .where((status) => status.id != updatedStatus.id)
            .toList();
      }
      if (index == -1) {
        return [updatedStatus, ...state.statuses];
      }
    } else if (index == -1) {
      return state.statuses;
    }

    final statuses = List<Status>.of(state.statuses);
    statuses[index] = updatedStatus;
    return statuses;
  }

  List<Status> _applyCreatedStatus(Status createdStatus) {
    final displaysCreatedStatus = switch (_feed) {
      StatusFeed.user => _userId == _accountId,
      StatusFeed.photos => _userId == _accountId && createdStatus.photo != null,
      // Home visibility is determined by the timeline API after moderation.
      StatusFeed.home ||
      StatusFeed.public ||
      StatusFeed.search ||
      StatusFeed.searchMine ||
      StatusFeed.searchUser ||
      StatusFeed.mentions ||
      StatusFeed.favorites => false,
    };
    if (!displaysCreatedStatus ||
        state.statuses.any((status) => status.id == createdStatus.id)) {
      return state.statuses;
    }
    return [createdStatus, ...state.statuses];
  }

  Status? _statusById(String statusId) {
    for (final status in state.statuses) {
      if (status.id == statusId) return status;
    }
    return null;
  }

  @override
  Future<void> close() async {
    await _statusChangesSubscription.cancel();
    await super.close();
  }
}
