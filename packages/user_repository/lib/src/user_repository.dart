import 'package:user_api_client/user_api_client.dart';
import 'package:user_repository/src/exceptions/block_action_failure.dart';
import 'package:user_repository/src/exceptions/follow_action_failure.dart';
import 'package:user_repository/src/models/models.dart';

/// Repository for loading and temporarily caching Fanfou user profiles.
class UserRepository {
  /// Creates a user repository.
  factory UserRepository({required UserApiClient userApiClient}) {
    return UserRepository._(userApiClient);
  }

  UserRepository._(this._userApiClient);

  /// Number of users in a full following or followers page.
  static const int relationPageSize = UserApiClient.relationPageSize;

  final UserApiClient _userApiClient;
  final Map<String, UserProfile> _cache = {};

  /// Loads unread notification counters for the active account.
  Future<UserNotificationCounts> getNotificationCounts() async {
    final response = await _userApiClient.getNotificationCounts();
    return UserNotificationCounts(
      mentions: response.mentions,
      directMessages: response.directMessages,
      friendRequests: response.friendRequests,
    );
  }

  /// Returns the latest cached profile for [userId], when available.
  UserProfile? getCachedUser(String userId) => _cache[userId];

  /// Stores a profile summary so navigation can render it immediately.
  ///
  /// Existing non-null profile fields are retained when a later summary does
  /// not include them.
  void cacheUser(UserProfile user) {
    final cached = _cache[user.id];
    if (cached == null) {
      _cache[user.id] = user;
      return;
    }
    _cache[user.id] = UserProfile(
      id: user.id,
      name: user.name.isEmpty ? cached.name : user.name,
      screenName: user.screenName.isEmpty ? cached.screenName : user.screenName,
      avatarUrl: user.avatarUrl ?? cached.avatarUrl,
      description: user.description ?? cached.description,
      location: user.location ?? cached.location,
      url: user.url ?? cached.url,
      protected: user.protected ?? cached.protected,
      following: user.following ?? cached.following,
      followersCount: user.followersCount ?? cached.followersCount,
      friendsCount: user.friendsCount ?? cached.friendsCount,
      favoritesCount: user.favoritesCount ?? cached.favoritesCount,
      statusesCount: user.statusesCount ?? cached.statusesCount,
      gender: user.gender ?? cached.gender,
      photoCount: user.photoCount ?? cached.photoCount,
      createdAt: user.createdAt ?? cached.createdAt,
      birthday: user.birthday ?? cached.birthday,
    );
  }

  /// Loads a complete user profile and refreshes the cache.
  Future<UserProfile> getUser(String userId) async {
    final response = await _userApiClient.getUser(userId);
    final user = UserProfile(
      id: response.id,
      name: response.name,
      screenName: response.screenName,
      avatarUrl: response.avatarUrl,
      description: response.description,
      location: response.location,
      url: response.url,
      protected: response.protected,
      following: response.following,
      followersCount: response.followersCount,
      friendsCount: response.friendsCount,
      favoritesCount: response.favoritesCount,
      statusesCount: response.statusesCount,
      gender: response.gender,
      photoCount: response.photoCount,
      createdAt: response.createdAt,
      birthday: response.birthday,
    );
    _cache[user.id] = user;
    return user;
  }

  /// Whether [userId] follows [targetUserId].
  Future<bool> isFollowing({
    required String userId,
    required String targetUserId,
  }) => _userApiClient.isFollowing(userId: userId, targetUserId: targetUserId);

  /// Whether the active account has blocked [userId].
  Future<bool> isBlocked(String userId) async {
    try {
      return await _userApiClient.isBlocked(userId);
    } on UserApiClientApiFailure catch (error) {
      throw BlockActionFailure(message: error.message);
    }
  }

  /// Blocks or unblocks [userId] and returns the confirmed state.
  Future<bool> setBlocked(String userId, {required bool blocked}) async {
    try {
      final result = await _userApiClient.setBlocked(userId, blocked: blocked);
      _cache.remove(userId);
      return result;
    } on UserApiClientApiFailure catch (error) {
      throw BlockActionFailure(message: error.message);
    }
  }

  /// Changes following status and invalidates potentially stale profile counts.
  Future<bool> setFollowing(String userId, {required bool following}) async {
    try {
      final result = await _userApiClient.setFollowing(
        userId,
        following: following,
      );
      _cache.clear();
      return result;
    } on UserApiClientApiFailure catch (error) {
      final message = error.message?.trim();
      throw FollowActionFailure(
        message: message == null || message.isEmpty ? null : message,
      );
    }
  }

  /// Returns blocked users for the active account and caches their profiles.
  Future<List<UserProfile>> getBlockedUsers({int page = 1}) async =>
      _mapUsers(await _userApiClient.getBlockedUsers(page: page));

  /// Removes [userId] from the active account's blacklist.
  Future<UserProfile> removeBlockedUser(String userId) async {
    try {
      final profile = _mapUser(await _userApiClient.removeBlockedUser(userId));
      _cache.remove(userId);
      return profile;
    } on UserApiClientApiFailure catch (error) {
      throw FollowActionFailure(message: error.message);
    }
  }

  /// Returns incoming follow requests for the active account.
  Future<List<UserProfile>> getFollowRequests({int page = 1}) async =>
      _mapUsers(await _userApiClient.getFollowRequests(page: page));

  /// Accepts an incoming follow request.
  Future<UserProfile> acceptFollowRequest(String userId) async {
    try {
      final user = await _userApiClient.acceptFollowRequest(userId);
      final profile = _mapUser(user);
      cacheUser(profile);
      return profile;
    } on UserApiClientApiFailure catch (error) {
      throw FollowActionFailure(message: error.message);
    }
  }

  /// Ignores an incoming follow request.
  Future<UserProfile> ignoreFollowRequest(String userId) async {
    try {
      final user = await _userApiClient.ignoreFollowRequest(userId);
      final profile = _mapUser(user);
      cacheUser(profile);
      return profile;
    } on UserApiClientApiFailure catch (error) {
      throw FollowActionFailure(message: error.message);
    }
  }

  /// Returns accounts followed by [userId].
  Future<List<UserProfile>> getFriends(String userId, {int page = 1}) async =>
      _mapUsers(await _userApiClient.getFriends(userId, page: page));

  /// Returns accounts following [userId].
  Future<List<UserProfile>> getFollowers(String userId, {int page = 1}) async =>
      _mapUsers(await _userApiClient.getFollowers(userId, page: page));

  UserProfile _mapUser(UserResponse response) => UserProfile(
    id: response.id,
    name: response.name,
    screenName: response.screenName,
    avatarUrl: response.avatarUrl,
    description: response.description,
    location: response.location,
    url: response.url,
    protected: response.protected,
    following: response.following,
    followersCount: response.followersCount,
    friendsCount: response.friendsCount,
    favoritesCount: response.favoritesCount,
    statusesCount: response.statusesCount,
    gender: response.gender,
    photoCount: response.photoCount,
    createdAt: response.createdAt,
    birthday: response.birthday,
  );

  List<UserProfile> _mapUsers(List<UserResponse> users) => users
      .map((response) {
        final user = _mapUser(response);
        cacheUser(user);
        return user;
      })
      .toList(growable: false);
}
