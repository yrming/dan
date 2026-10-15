import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:user_repository/user_repository.dart';

enum FollowListAction { follow, unfollow, followBack }

class FollowListState extends Equatable {
  FollowListState({
    List<UserProfile> users = const [],
    this.loading = true,
    this.error = false,
    this.loadingMore = false,
    this.loadMoreError = false,
    this.hasMore = true,
    Map<String, FollowListAction> actions = const {},
    Set<String> updatingIds = const {},
    this.actionFailureCount = 0,
    this.actionFailureMessage,
    this.requestSentCount = 0,
  }) : users = List.unmodifiable(users),
       actions = Map.unmodifiable(actions),
       updatingIds = Set.unmodifiable(updatingIds);

  final List<UserProfile> users;
  final bool loading;
  final bool error;
  final bool loadingMore;
  final bool loadMoreError;
  final bool hasMore;
  final Map<String, FollowListAction> actions;
  final Set<String> updatingIds;
  final int actionFailureCount;

  /// Server feedback for the latest action failure.
  final String? actionFailureMessage;
  final int requestSentCount;

  /// Updates state, clearing transient failure feedback unless supplied.
  FollowListState copyWith({
    List<UserProfile>? users,
    bool? loading,
    bool? error,
    bool? loadingMore,
    bool? loadMoreError,
    bool? hasMore,
    Map<String, FollowListAction>? actions,
    Set<String>? updatingIds,
    int? actionFailureCount,
    String? actionFailureMessage,
    int? requestSentCount,
  }) => FollowListState(
    users: users ?? this.users,
    loading: loading ?? this.loading,
    error: error ?? this.error,
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreError: loadMoreError ?? this.loadMoreError,
    hasMore: hasMore ?? this.hasMore,
    actions: actions ?? this.actions,
    updatingIds: updatingIds ?? this.updatingIds,
    actionFailureCount: actionFailureCount ?? this.actionFailureCount,
    actionFailureMessage: actionFailureMessage,
    requestSentCount: requestSentCount ?? this.requestSentCount,
  );

  @override
  List<Object?> get props => [
    users,
    loading,
    error,
    loadingMore,
    loadMoreError,
    hasMore,
    actions,
    updatingIds,
    actionFailureCount,
    actionFailureMessage,
    requestSentCount,
  ];
}

class FollowListCubit extends Cubit<FollowListState> {
  FollowListCubit({
    required this._repository,
    required this._userId,
    required this._followers,
    this._accountId,
  }) : super(FollowListState());

  final UserRepository _repository;
  final String _userId;
  final bool _followers;
  final String? _accountId;
  int _nextPage = 1;
  bool _requestInFlight = false;

  Future<void> load() async {
    if (isClosed || _requestInFlight || state.updatingIds.isNotEmpty) return;
    _nextPage = 1;
    await _loadPage(initial: true);
  }

  Future<void> loadMore() async {
    if (isClosed ||
        _requestInFlight ||
        state.loading ||
        state.error ||
        !state.hasMore) {
      return;
    }
    await _loadPage(initial: false);
  }

  FollowListAction _initialAction(UserProfile user) {
    final isOwnList = _accountId == _userId;
    if (isOwnList && !_followers || user.following == true) {
      return FollowListAction.unfollow;
    }
    return isOwnList && _followers
        ? FollowListAction.followBack
        : FollowListAction.follow;
  }

  Future<void> toggleFollowing(String userId) async {
    final action = state.actions[userId];
    if (isClosed || action == null || state.updatingIds.contains(userId)) {
      return;
    }
    final following = action != FollowListAction.unfollow;
    emit(state.copyWith(updatingIds: {...state.updatingIds, userId}));
    try {
      final confirmed = await _repository.setFollowing(
        userId,
        following: following,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          actions: {
            ...state.actions,
            userId: confirmed
                ? FollowListAction.unfollow
                : _accountId == _userId && _followers
                ? FollowListAction.followBack
                : FollowListAction.follow,
          },
          updatingIds: {...state.updatingIds}..remove(userId),
          requestSentCount:
              state.requestSentCount + (following && !confirmed ? 1 : 0),
        ),
      );
    } on Object catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          updatingIds: {...state.updatingIds}..remove(userId),
          actionFailureCount: state.actionFailureCount + 1,
          actionFailureMessage: error is FollowActionFailure
              ? error.message
              : null,
        ),
      );
    }
  }

  Future<void> _loadPage({required bool initial}) async {
    _requestInFlight = true;
    final previous = state;
    emit(
      state.copyWith(
        users: initial ? const [] : previous.users,
        loading: initial,
        error: false,
        loadMoreError: false,
        hasMore: true,
        actions: initial ? const {} : state.actions,
        loadingMore: !initial,
      ),
    );
    try {
      final users = _followers
          ? await _repository.getFollowers(_userId, page: _nextPage)
          : await _repository.getFriends(_userId, page: _nextPage);
      if (isClosed) return;
      final byId = <String, UserProfile>{
        if (!initial)
          for (final user in state.users) user.id: user,
        for (final user in users) user.id: user,
      };
      _nextPage++;
      emit(
        state.copyWith(
          users: byId.values.toList(),
          loading: false,
          loadingMore: false,
          actions: {
            for (final user in users)
              if (_accountId != null && user.id != _accountId)
                user.id: _initialAction(user),
            ...state.actions,
          },
          hasMore: users.length >= UserRepository.relationPageSize,
        ),
      );
    } on Object {
      if (isClosed) return;
      emit(
        state.copyWith(
          users: initial ? const [] : state.users,
          loading: false,
          loadingMore: false,
          error: initial,
          loadMoreError: !initial,
          hasMore: previous.hasMore,
        ),
      );
    } finally {
      _requestInFlight = false;
    }
  }
}
