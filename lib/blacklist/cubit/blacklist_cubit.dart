import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:user_repository/user_repository.dart';

enum BlacklistStatus { loading, success, failure }

final class BlacklistState extends Equatable {
  const BlacklistState({
    this.status = BlacklistStatus.loading,
    this.users = const [],
    this.loadingMore = false,
    this.loadMoreError = false,
    this.requestFailureMessage,
    this.hasMore = true,
    this.removingIds = const {},
    this.actionFailureCount = 0,
    this.actionFailureMessage,
  });

  final BlacklistStatus status;
  final List<UserProfile> users;
  final bool loadingMore;
  final bool loadMoreError;
  final String? requestFailureMessage;
  final bool hasMore;
  final Set<String> removingIds;
  final int actionFailureCount;
  final String? actionFailureMessage;

  BlacklistState copyWith({
    BlacklistStatus? status,
    List<UserProfile>? users,
    bool? loadingMore,
    bool? loadMoreError,
    String? requestFailureMessage,
    bool? hasMore,
    Set<String>? removingIds,
    int? actionFailureCount,
    String? actionFailureMessage,
  }) => BlacklistState(
    status: status ?? this.status,
    users: users ?? this.users,
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreError: loadMoreError ?? this.loadMoreError,
    requestFailureMessage: requestFailureMessage,
    hasMore: hasMore ?? this.hasMore,
    removingIds: removingIds ?? this.removingIds,
    actionFailureCount: actionFailureCount ?? this.actionFailureCount,
    actionFailureMessage: actionFailureMessage,
  );

  @override
  List<Object?> get props => [
    status,
    users,
    loadingMore,
    loadMoreError,
    requestFailureMessage,
    hasMore,
    removingIds,
    actionFailureCount,
    actionFailureMessage,
  ];
}

class BlacklistCubit extends Cubit<BlacklistState> {
  BlacklistCubit({required this._repository}) : super(const BlacklistState());

  final UserRepository _repository;
  int _nextPage = 1;
  bool _requestInFlight = false;

  Future<void> load() async {
    if (isClosed || _requestInFlight) return;
    _nextPage = 1;
    await _loadPage(initial: true);
  }

  Future<void> remove(String userId) async {
    if (isClosed || state.removingIds.contains(userId)) return;
    emit(state.copyWith(removingIds: {...state.removingIds, userId}));
    try {
      await _repository.removeBlockedUser(userId);
      if (isClosed) return;
      emit(
        state.copyWith(
          users: state.users.where((user) => user.id != userId).toList(),
          removingIds: {...state.removingIds}..remove(userId),
        ),
      );
    } on Object catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          removingIds: {...state.removingIds}..remove(userId),
          actionFailureCount: state.actionFailureCount + 1,
          actionFailureMessage: error is FollowActionFailure
              ? error.message
              : null,
        ),
      );
    }
  }

  Future<void> loadMore() async {
    if (isClosed ||
        _requestInFlight ||
        state.status == BlacklistStatus.loading ||
        state.status == BlacklistStatus.failure ||
        !state.hasMore) {
      return;
    }
    await _loadPage(initial: false);
  }

  Future<void> _loadPage({required bool initial}) async {
    _requestInFlight = true;
    emit(
      state.copyWith(
        status: initial ? BlacklistStatus.loading : BlacklistStatus.success,
        users: initial ? const [] : state.users,
        loadingMore: !initial,
        loadMoreError: false,
        hasMore: initial || state.hasMore,
      ),
    );
    try {
      final users = await _repository.getBlockedUsers(page: _nextPage);
      if (isClosed) return;
      final byId = <String, UserProfile>{
        if (!initial)
          for (final user in state.users) user.id: user,
        for (final user in users) user.id: user,
      };
      _nextPage++;
      emit(
        state.copyWith(
          status: BlacklistStatus.success,
          users: byId.values.toList(growable: false),
          loadingMore: false,
          hasMore: users.length == UserRepository.relationPageSize,
        ),
      );
    } on Object catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: initial ? BlacklistStatus.failure : BlacklistStatus.success,
          loadingMore: false,
          loadMoreError: !initial,
          requestFailureMessage: error is UserRepositoryApiFailure
              ? error.message
              : null,
        ),
      );
    } finally {
      _requestInFlight = false;
    }
  }
}
