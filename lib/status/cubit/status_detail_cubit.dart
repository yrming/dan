import 'package:bloc/bloc.dart';
import 'package:dan/app/widgets/fanfou_timestamp.dart';
import 'package:equatable/equatable.dart';
import 'package:status_repository/status_repository.dart';
import 'package:user_repository/user_repository.dart';

part 'status_detail_state.dart';

/// Loads an original status and its conversation.
class StatusDetailCubit extends Cubit<StatusDetailState> {
  /// Creates a status detail cubit.
  factory StatusDetailCubit({
    required StatusRepository statusRepository,
    required UserRepository userRepository,
    required String statusId,
    Status? initialStatus,
  }) => StatusDetailCubit._(
    statusRepository,
    userRepository,
    statusId,
    initialStatus,
  );

  StatusDetailCubit._(
    this._statusRepository,
    this._userRepository,
    this._statusId,
    this._selectedStatus,
  ) : super(
        StatusDetailState(
          status: _selectedStatus == null
              ? StatusDetailStatus.initial
              : StatusDetailStatus.success,
          statusDetail: _selectedStatus,
        ),
      );

  final StatusRepository _statusRepository;
  final UserRepository _userRepository;
  final String _statusId;
  Status? _selectedStatus;
  bool _isLoading = false;

  /// Loads the selected status and resolves context only for a reply.
  Future<void> load() async {
    if (state.contextStatus == StatusDetailStatus.success) return;
    await refresh();
  }

  /// Reloads context around the route's status, including newly posted replies.
  Future<void> refresh() async {
    if (_isLoading || isClosed) return;
    _isLoading = true;
    emit(
      state.copyWith(
        status: state.statusDetail == null
            ? StatusDetailStatus.loading
            : StatusDetailStatus.success,
        contextStatus: StatusDetailStatus.loading,
      ),
    );
    try {
      final selected =
          _selectedStatus ?? await _statusRepository.getStatus(_statusId);
      if (isClosed) return;
      _selectedStatus = selected;
      if (selected.inReplyToStatusId?.isEmpty ?? true) {
        emit(
          StatusDetailState(
            status: StatusDetailStatus.success,
            statusDetail: selected,
            contextStatus: StatusDetailStatus.success,
          ),
        );
        return;
      }
      if (state.statusDetail == null) {
        emit(
          state.copyWith(
            status: StatusDetailStatus.success,
            statusDetail: selected,
          ),
        );
      }
      await _loadContext(selected);
    } on Object catch (_) {
      if (!isClosed) {
        emit(
          state.copyWith(
            status: state.statusDetail == null
                ? StatusDetailStatus.failure
                : StatusDetailStatus.success,
            contextStatus: StatusDetailStatus.failure,
          ),
        );
      }
    } finally {
      _isLoading = false;
    }
  }

  Future<void> _loadContext(Status selected) async {
    final statuses = <String, Status>{selected.id: selected};
    Status? origin;
    var current = selected;
    try {
      final context = await _statusRepository.getContextTimeline(selected.id);
      if (isClosed) return;
      for (final status in context) {
        statuses[status.id] = status;
      }
      // A context can include its original even if an intermediate reply has
      // been deleted. Prefer that original over fetching the missing reply.
      current = _findOrigin(context) ?? statuses[selected.id]!;
      final visited = <String>{};
      while (true) {
        if (!visited.add(current.id)) {
          throw StateError('Cyclic status reply chain.');
        }
        final parentId = current.inReplyToStatusId;
        if (parentId == null || parentId.isEmpty) {
          origin = current;
          break;
        }
        if (!statuses.containsKey(parentId)) {
          final ancestors = await _statusRepository.getContextTimeline(
            parentId,
          );
          if (isClosed) return;
          for (final status in ancestors) {
            statuses[status.id] = status;
          }
          final knownOrigin = _findOrigin(ancestors);
          if (knownOrigin != null) {
            origin = knownOrigin;
            break;
          }
          // Context is limited to recent messages and can omit its target.
          if (!statuses.containsKey(parentId)) {
            statuses[parentId] = await _statusRepository.getStatus(parentId);
            if (isClosed) return;
          }
        }
        current = statuses[parentId]!;
      }
    } on StatusRepositoryApiFailure catch (error) {
      if (error.statusCode != 403 && error.statusCode != 404) rethrow;
      // Keep readable replies even when an ancestor is no longer accessible.
    }
    if (isClosed) return;
    final displayedStatus = origin ?? await _unavailableOrigin(current);
    if (isClosed) return;
    emit(
      state.copyWith(
        status: StatusDetailStatus.success,
        statusDetail: displayedStatus,
        originUnavailable: origin == null,
        contextStatus: StatusDetailStatus.success,
        replies: _orderedReplies(statuses, origin?.id),
      ),
    );
  }

  Future<Status> _unavailableOrigin(Status reply) async {
    final userId = reply.inReplyToUserId ?? '';
    UserProfile? user;
    final userRepository = _userRepository;
    if (userId.isNotEmpty) {
      try {
        user = await userRepository.getUser(userId);
      } on Object {
        // Keep readable context even if the author's profile is unavailable.
        user = userRepository.getCachedUser(userId);
      }
    }
    return Status(
      id: reply.inReplyToStatusId ?? '',
      text: '',
      createdAt: '',
      author: StatusAuthor(
        id: userId,
        name: user?.name ?? '',
        screenName: user?.screenName ?? '',
        avatarUrl: user?.avatarUrl,
      ),
    );
  }

  Status? _findOrigin(Iterable<Status> statuses) => statuses
      .where((status) => status.inReplyToStatusId?.isEmpty ?? true)
      .firstOrNull;

  List<Status> _orderedReplies(Map<String, Status> statuses, String? originId) {
    final ordered = statuses.values.toList()
      ..sort((a, b) {
        final first = tryParseFanfouCreatedAt(a.createdAt);
        final second = tryParseFanfouCreatedAt(b.createdAt);
        return first == null || second == null ? 0 : first.compareTo(second);
      });
    final result = <Status>[];
    final visited = <String>{};
    void add(Status status) {
      if (!visited.add(status.id)) return;
      final parent = statuses[status.inReplyToStatusId];
      if (parent != null) add(parent);
      if (status.id != originId) result.add(status);
    }

    ordered.forEach(add);
    return result;
  }

  /// Retries the status or context request that failed.
  Future<void> retry() => refresh();

  /// Toggles the favorite state of the displayed status.
  Future<void> toggleFavorite() async {
    final status = state.statusDetail;
    if (status == null) return;
    emit(
      state.copyWith(
        favoriteActionStatus: StatusFavoriteActionStatus.initial,
      ),
    );
    try {
      final updated = status.isFavorited
          ? await _statusRepository.unfavoriteStatus(status.id)
          : await _statusRepository.favoriteStatus(status.id);
      if (isClosed) return;
      _selectedStatus = updated;
      emit(
        state.copyWith(
          statusDetail: updated,
          favoriteActionStatus: updated.isFavorited
              ? StatusFavoriteActionStatus.favorited
              : StatusFavoriteActionStatus.unfavorited,
        ),
      );
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      if (isClosed) return;
      emit(
        state.copyWith(
          favoriteActionStatus: StatusFavoriteActionStatus.failure,
          favoriteActionMessage: error is StatusRepositoryApiFailure
              ? error.message
              : null,
        ),
      );
    }
  }

  /// Deletes the original status displayed at the top of the page.
  Future<void> delete() => _statusRepository.deleteStatus(
    state.statusDetail?.id ?? _statusId,
  );

  /// Deletes a conversation reply and removes it without leaving the page.
  Future<void> deleteReply(String statusId) async {
    await _statusRepository.deleteStatus(statusId);
    if (isClosed) return;
    final replies = state.replies
        .where((reply) => reply.id != statusId)
        .toList();
    if (_selectedStatus?.id == statusId) {
      // Future refreshes must not seed the conversation with a deleted reply.
      _selectedStatus = state.originUnavailable
          ? replies.firstOrNull
          : state.statusDetail;
    }
    emit(
      state.copyWith(
        replies: replies,
      ),
    );
  }
}
