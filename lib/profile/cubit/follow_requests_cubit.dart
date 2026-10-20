import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:user_repository/user_repository.dart';

enum FollowRequestAction { accept, ignore }

class FollowRequestsState extends Equatable {
  FollowRequestsState({
    List<UserProfile> users = const [],
    this.loading = true,
    this.error = false,
    this.loadingMore = false,
    this.loadMoreError = false,
    this.requestFailureMessage,
    this.hasMore = true,
    Set<String> updatingIds = const {},
    Map<String, FollowRequestAction> updatingActions = const {},
    this.actionFailureCount = 0,
    this.actionSuccessCount = 0,
    this.actionFailureMessage,
  }) : users = List.unmodifiable(users),
       updatingIds = Set.unmodifiable(updatingIds),
       updatingActions = Map.unmodifiable(updatingActions);

  final List<UserProfile> users;
  final bool loading;
  final bool error;
  final bool loadingMore;
  final bool loadMoreError;
  final String? requestFailureMessage;
  final bool hasMore;
  final Set<String> updatingIds;
  final Map<String, FollowRequestAction> updatingActions;
  final int actionFailureCount;
  final int actionSuccessCount;
  final String? actionFailureMessage;

  FollowRequestsState copyWith({
    List<UserProfile>? users,
    bool? loading,
    bool? error,
    bool? loadingMore,
    bool? loadMoreError,
    String? requestFailureMessage,
    bool? hasMore,
    Set<String>? updatingIds,
    Map<String, FollowRequestAction>? updatingActions,
    int? actionFailureCount,
    int? actionSuccessCount,
    String? actionFailureMessage,
  }) => FollowRequestsState(
    users: users ?? this.users,
    loading: loading ?? this.loading,
    error: error ?? this.error,
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreError: loadMoreError ?? this.loadMoreError,
    requestFailureMessage: requestFailureMessage,
    hasMore: hasMore ?? this.hasMore,
    updatingIds: updatingIds ?? this.updatingIds,
    updatingActions: updatingActions ?? this.updatingActions,
    actionFailureCount: actionFailureCount ?? this.actionFailureCount,
    actionSuccessCount: actionSuccessCount ?? this.actionSuccessCount,
    actionFailureMessage: actionFailureMessage,
  );

  @override
  List<Object?> get props => [
    users,
    loading,
    error,
    loadingMore,
    loadMoreError,
    requestFailureMessage,
    hasMore,
    updatingIds,
    updatingActions,
    actionFailureCount,
    actionSuccessCount,
    actionFailureMessage,
  ];
}

class FollowRequestsCubit extends Cubit<FollowRequestsState> {
  FollowRequestsCubit({required this._repository})
    : super(FollowRequestsState());

  final UserRepository _repository;
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

  Future<void> accept(String userId) => _resolve(userId, accept: true);

  Future<void> ignore(String userId) => _resolve(userId, accept: false);

  Future<void> _resolve(String userId, {required bool accept}) async {
    if (isClosed || !state.users.any((user) => user.id == userId)) return;
    if (state.updatingIds.contains(userId)) return;
    emit(
      state.copyWith(
        updatingIds: {...state.updatingIds, userId},
        updatingActions: {
          ...state.updatingActions,
          userId: accept
              ? FollowRequestAction.accept
              : FollowRequestAction.ignore,
        },
      ),
    );
    try {
      if (accept) {
        await _repository.acceptFollowRequest(userId);
      } else {
        await _repository.ignoreFollowRequest(userId);
      }
      if (isClosed) return;
      emit(
        state.copyWith(
          users: state.users.where((user) => user.id != userId).toList(),
          updatingIds: {...state.updatingIds}..remove(userId),
          updatingActions: {...state.updatingActions}..remove(userId),
          actionSuccessCount: state.actionSuccessCount + 1,
        ),
      );
    } on Object catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          updatingIds: {...state.updatingIds}..remove(userId),
          updatingActions: {...state.updatingActions}..remove(userId),
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
        loadingMore: !initial,
      ),
    );
    try {
      final users = await _repository.getFollowRequests(page: _nextPage);
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
          hasMore: users.length >= UserRepository.relationPageSize,
        ),
      );
    } on Object catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          users: initial ? const [] : state.users,
          loading: false,
          loadingMore: false,
          error: initial,
          loadMoreError: !initial,
          requestFailureMessage: error is UserRepositoryApiFailure
              ? error.message
              : null,
          hasMore: previous.hasMore,
        ),
      );
    } finally {
      _requestInFlight = false;
    }
  }
}
