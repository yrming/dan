import 'package:authentication_repository/authentication_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:dan/profile/cubit/user_profile_state.dart';
import 'package:user_repository/user_repository.dart';

/// Loads one Fanfou user profile.
class UserProfileCubit extends Cubit<UserProfileState> {
  /// Creates a user profile cubit.
  factory UserProfileCubit({
    required UserRepository userRepository,
    required String userId,
    UserProfile? initialProfile,
    String? activeAccountId,
    AuthenticationRepository? authenticationRepository,
  }) {
    return UserProfileCubit._(
      userRepository,
      userId,
      initialProfile,
      authenticationRepository,
      activeAccountId,
    );
  }

  UserProfileCubit._(
    this._userRepository,
    this._userId,
    UserProfile? initialProfile,
    this._authenticationRepository,
    this._activeAccountId,
  ) : super(UserProfileInitial(profile: initialProfile));

  final UserRepository _userRepository;

  final String _userId;
  final AuthenticationRepository? _authenticationRepository;
  final String? _activeAccountId;

  /// Loads or refreshes the requested profile.
  Future<void> load() async {
    if (isClosed ||
        state is UserProfileLoadInProgress ||
        state is UserProfileLoadSuccess &&
            ((state as UserProfileLoadSuccess).isFollowingUpdating ||
                (state as UserProfileLoadSuccess).isBlockActionInProgress)) {
      return;
    }
    final currentProfile = state.profile;
    emit(UserProfileLoadInProgress(profile: currentProfile));
    try {
      final profile = await _userRepository.getUser(_userId);
      await _persistAuthenticatedAccount(profile);
      final followedBy = await _loadFollowedBy();
      if (isClosed) return;
      emit(
        UserProfileLoadSuccess(
          profile: profile,
          followedBy: followedBy,
        ),
      );
    } on Object catch (_) {
      if (isClosed) return;
      emit(UserProfileLoadFailure(profile: currentProfile));
    }
  }

  /// Toggles following and retains the existing relationship on failure.
  Future<void> toggleFollowing() async {
    final current = state;
    if (isClosed ||
        _activeAccountId == null ||
        _activeAccountId == _userId ||
        current is! UserProfileLoadSuccess ||
        current.isFollowingUpdating) {
      return;
    }
    final following = current.profile!.following != true;
    emit(current.copyWith(isFollowingUpdating: true));
    try {
      final confirmed = await _userRepository.setFollowing(
        _userId,
        following: following,
      );
      if (isClosed) return;
      emit(
        current.copyWith(
          profile: current.profile!.copyWithFollowing(following: confirmed),
          isFollowingUpdating: false,
          requestSentCount:
              current.requestSentCount + (following && !confirmed ? 1 : 0),
        ),
      );
    } on Object catch (error) {
      if (isClosed) return;
      emit(
        current.copyWith(
          isFollowingUpdating: false,
          actionFailureCount: current.actionFailureCount + 1,
          actionFailureMessage: error is FollowActionFailure
              ? error.message
              : null,
        ),
      );
    }
  }

  Future<bool?> _loadFollowedBy() async {
    final accountId = _activeAccountId;
    if (accountId == null || accountId == _userId) return null;
    try {
      return await _userRepository.isFollowing(
        userId: _userId,
        targetUserId: accountId,
      );
    } on Object {
      // Profile data and follow actions remain usable if this lookup fails.
      return null;
    }
  }

  Future<bool?> _loadFollowing() async {
    final accountId = _activeAccountId;
    if (accountId == null || accountId == _userId) return null;
    try {
      return await _userRepository.isFollowing(
        userId: accountId,
        targetUserId: _userId,
      );
    } on Object {
      // Keep the current relationship visible if this lookup fails.
      return null;
    }
  }

  /// Checks the latest blocking status before opening the profile menu.
  Future<void> loadBlocked() async {
    final current = state;
    if (isClosed ||
        _activeAccountId == null ||
        _activeAccountId == _userId ||
        current is! UserProfileLoadSuccess ||
        current.isFollowingUpdating ||
        current.isBlockActionInProgress) {
      return;
    }
    emit(current.copyWith(isBlockActionInProgress: true));
    try {
      final blocked = await _userRepository.isBlocked(_userId);
      if (isClosed) return;
      emit(
        current.copyWith(isBlocked: blocked, isBlockActionInProgress: false),
      );
      return;
    } on Object catch (error) {
      if (isClosed) return;
      emit(
        current.copyWith(
          isBlockActionInProgress: false,
          blockActionFailureCount: current.blockActionFailureCount + 1,
          blockActionFailed: true,
          blockActionMessage: error is BlockActionFailure
              ? error.message
              : null,
        ),
      );
      return;
    }
  }

  /// Toggles blocking and retains the existing relationship on failure.
  Future<void> toggleBlocked() async {
    final current = state;
    if (isClosed ||
        _activeAccountId == null ||
        _activeAccountId == _userId ||
        current is! UserProfileLoadSuccess ||
        current.isBlocked == null ||
        current.isFollowingUpdating ||
        current.isBlockActionInProgress) {
      return;
    }
    final blocked = !current.isBlocked!;
    emit(current.copyWith(isBlockActionInProgress: true));
    try {
      final confirmed = await _userRepository.setBlocked(
        _userId,
        blocked: blocked,
      );
      final relationship = await Future.wait<bool?>([
        _loadFollowing(),
        _loadFollowedBy(),
      ]);
      final following = relationship[0];
      final followedBy = relationship[1];
      if (isClosed) return;
      final profile = following == null
          ? current.profile!
          : current.profile!.copyWithFollowing(following: following);
      emit(
        current.copyWith(
          profile: profile,
          followedBy: followedBy ?? current.followedBy,
          isBlocked: confirmed,
          isBlockActionInProgress: false,
          blockActionCount: current.blockActionCount + 1,
          blockActionFailed: false,
        ),
      );
    } on Object catch (error) {
      if (isClosed) return;
      emit(
        current.copyWith(
          isBlockActionInProgress: false,
          blockActionFailureCount: current.blockActionFailureCount + 1,
          blockActionFailed: true,
          blockActionMessage: error is BlockActionFailure
              ? error.message
              : null,
        ),
      );
    }
  }

  Future<void> _persistAuthenticatedAccount(UserProfile profile) async {
    final authenticationRepository = _authenticationRepository;
    if (authenticationRepository == null) return;
    try {
      await authenticationRepository.updateAccount(
        AuthenticatedAccount(
          id: profile.id,
          name: profile.name,
          screenName: profile.screenName,
          avatarUrl: profile.avatarUrl,
          description: profile.description,
          location: profile.location,
          url: profile.url,
          protected: profile.protected,
          following: profile.following,
          followersCount: profile.followersCount,
          friendsCount: profile.friendsCount,
          favoritesCount: profile.favoritesCount,
          statusesCount: profile.statusesCount,
          gender: profile.gender,
          photoCount: profile.photoCount,
          createdAt: profile.createdAt,
          birthday: profile.birthday,
        ),
      );
    } on Object {
      // The freshly loaded profile remains usable if local persistence fails.
    }
  }
}
