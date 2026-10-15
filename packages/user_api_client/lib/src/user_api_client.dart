import 'dart:convert';

import 'package:fanfou/fanfou.dart' as fanfou;
import 'package:fanfou_error_parser/fanfou_error_parser.dart';
import 'package:user_api_client/src/exceptions/exceptions.dart';
import 'package:user_api_client/src/models/models.dart';

/// Creates a Fanfou client scoped to the active account.
typedef UserClientFactory = Future<fanfou.FanfouClient> Function();

/// Typed data client for Fanfou user endpoints.
class UserApiClient {
  /// Creates a user API client.
  factory UserApiClient({required UserClientFactory clientFactory}) {
    return UserApiClient._(clientFactory);
  }

  UserApiClient._(this._clientFactory);

  /// Number of users requested per following or followers page.
  static const relationPageSize = 60;

  final UserClientFactory _clientFactory;

  /// Returns unread notification counters for the active account.
  Future<NotificationCountsResponse> getNotificationCounts() async {
    final fanfou.FanfouClient client;
    try {
      client = await _clientFactory();
    } on Object catch (_) {
      throw const UserApiClientUnknownFailure();
    }

    try {
      final counts = await client.account.notification();
      return NotificationCountsResponse(
        mentions: counts.mentions,
        directMessages: counts.directMessages,
        friendRequests: counts.friendRequests,
      );
    } on fanfou.FanfouApiException catch (error) {
      throw UserApiClientApiFailure(
        statusCode: error.statusCode,
        message: parseFanfouApiError(error.body),
      );
    } on Object catch (_) {
      throw const UserApiClientUnknownFailure();
    } finally {
      client.close();
    }
  }

  /// Returns the user identified by [userId].
  Future<UserResponse> getUser(String userId) async {
    if (userId.trim().isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Must not be empty.');
    }

    final fanfou.FanfouClient client;
    try {
      client = await _clientFactory();
    } on Object catch (_) {
      throw const UserApiClientUnknownFailure();
    }

    try {
      final user = await client.users.show(id: userId, format: 'html');
      return UserResponse(
        id: user.id,
        name: user.name,
        screenName: user.screenName,
        avatarUrl: user.profileImageUrlLarge ?? user.profileImageUrl,
        description: user.description,
        location: user.location,
        url: user.url,
        protected: user.protected,
        following: user.following,
        followersCount: user.followersCount,
        friendsCount: user.friendsCount,
        favoritesCount: user.favouritesCount,
        statusesCount: user.statusesCount,
        gender: user.gender,
        photoCount: user.photoCount,
        createdAt: user.createdAt,
        birthday: user.birthday,
      );
    } on fanfou.FanfouApiException catch (error) {
      throw UserApiClientApiFailure(
        statusCode: error.statusCode,
        message: parseFanfouApiError(error.body),
      );
    } on Object catch (_) {
      throw const UserApiClientUnknownFailure();
    } finally {
      client.close();
    }
  }

  /// Whether [userId] follows [targetUserId].
  Future<bool> isFollowing({
    required String userId,
    required String targetUserId,
  }) async {
    if (userId.trim().isEmpty) throw ArgumentError.value(userId, 'userId');
    if (targetUserId.trim().isEmpty) {
      throw ArgumentError.value(targetUserId, 'targetUserId');
    }
    final fanfou.FanfouClient client;
    try {
      client = await _clientFactory();
    } on Object {
      throw const UserApiClientUnknownFailure();
    }
    try {
      return await client.friendships.exists(
        userA: userId,
        userB: targetUserId,
      );
    } on fanfou.FanfouApiException catch (error) {
      throw UserApiClientApiFailure(
        statusCode: error.statusCode,
        message: parseFanfouApiError(error.body),
      );
    } on Object {
      throw const UserApiClientUnknownFailure();
    } finally {
      client.close();
    }
  }

  /// Follows or unfollows a user and returns the confirmed following status.
  Future<bool> setFollowing(String userId, {required bool following}) async {
    if (userId.trim().isEmpty) throw ArgumentError.value(userId, 'userId');
    final fanfou.FanfouClient client;
    try {
      client = await _clientFactory();
    } on Object {
      throw const UserApiClientUnknownFailure();
    }
    try {
      final user = following
          ? await client.friendships.create(userId)
          : await client.friendships.destroy(userId);
      return user.following ?? following;
    } on fanfou.FanfouApiException catch (error) {
      throw UserApiClientApiFailure(
        statusCode: error.statusCode,
        message: _errorMessage(error.body),
      );
    } on Object {
      throw const UserApiClientUnknownFailure();
    } finally {
      client.close();
    }
  }

  /// Whether the authenticated account has blocked [userId].
  Future<bool> isBlocked(String userId) async {
    if (userId.trim().isEmpty) throw ArgumentError.value(userId, 'userId');
    final fanfou.FanfouClient client;
    try {
      client = await _clientFactory();
    } on Object {
      throw const UserApiClientUnknownFailure();
    }
    try {
      await client.blocks.exists(userId, mode: 'lite');
      return true;
    } on fanfou.FanfouApiException catch (error) {
      if (error.statusCode == 404) return false;
      throw UserApiClientApiFailure(
        statusCode: error.statusCode,
        message: parseFanfouApiError(error.body),
      );
    } on Object {
      throw const UserApiClientUnknownFailure();
    } finally {
      client.close();
    }
  }

  /// Blocks or unblocks a user and returns the requested state.
  Future<bool> setBlocked(String userId, {required bool blocked}) async {
    if (userId.trim().isEmpty) throw ArgumentError.value(userId, 'userId');
    final fanfou.FanfouClient client;
    try {
      client = await _clientFactory();
    } on Object {
      throw const UserApiClientUnknownFailure();
    }
    try {
      if (blocked) {
        await client.blocks.create(userId, mode: 'lite');
      } else {
        await client.blocks.destroy(userId, mode: 'lite');
      }
      return blocked;
    } on fanfou.FanfouApiException catch (error) {
      throw UserApiClientApiFailure(
        statusCode: error.statusCode,
        message: parseFanfouApiError(error.body),
      );
    } on Object {
      throw const UserApiClientUnknownFailure();
    } finally {
      client.close();
    }
  }

  static String? _errorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return null;
      final error = decoded['error'];
      if (error is! String || error.trim().isEmpty) return null;
      return error.trim();
    } on FormatException {
      return null;
    }
  }

  /// Returns users blocked by the authenticated account.
  Future<List<UserResponse>> getBlockedUsers({int page = 1}) async {
    if (page < 1) throw ArgumentError.value(page, 'page');
    final fanfou.FanfouClient client;
    try {
      client = await _clientFactory();
    } on Object {
      throw const UserApiClientUnknownFailure();
    }
    try {
      final users = await client.blocks.blocking(
        count: relationPageSize,
        page: page,
      );
      return users.map(_mapUser).toList(growable: false);
    } on fanfou.FanfouApiException catch (error) {
      throw UserApiClientApiFailure(
        statusCode: error.statusCode,
        message: parseFanfouApiError(error.body),
      );
    } on Object {
      throw const UserApiClientUnknownFailure();
    } finally {
      client.close();
    }
  }

  /// Removes a user from the authenticated account's blacklist.
  Future<UserResponse> removeBlockedUser(String userId) async {
    if (userId.trim().isEmpty) throw ArgumentError.value(userId, 'userId');
    final fanfou.FanfouClient client;
    try {
      client = await _clientFactory();
    } on Object {
      throw const UserApiClientUnknownFailure();
    }
    try {
      return _mapUser(await client.blocks.destroy(userId, mode: 'lite'));
    } on fanfou.FanfouApiException catch (error) {
      throw UserApiClientApiFailure(
        statusCode: error.statusCode,
        message: parseFanfouApiError(error.body),
      );
    } on Object {
      throw const UserApiClientUnknownFailure();
    } finally {
      client.close();
    }
  }

  /// Returns incoming follow requests for the active account.
  Future<List<UserResponse>> getFollowRequests({int page = 1}) async {
    if (page < 1) throw ArgumentError.value(page, 'page');
    final fanfou.FanfouClient client;
    try {
      client = await _clientFactory();
    } on Object {
      throw const UserApiClientUnknownFailure();
    }
    try {
      final users = await client.friendships.requests(
        count: relationPageSize,
        page: page,
        format: 'html',
      );
      return users.map(_mapUser).toList(growable: false);
    } on fanfou.FanfouApiException catch (error) {
      throw UserApiClientApiFailure(
        statusCode: error.statusCode,
        message: parseFanfouApiError(error.body),
      );
    } on UserApiClientFailure {
      rethrow;
    } on Object {
      throw const UserApiClientUnknownFailure();
    } finally {
      client.close();
    }
  }

  /// Accepts an incoming follow request.
  Future<UserResponse> acceptFollowRequest(String userId) =>
      _resolveFollowRequest(userId, accept: true);

  /// Ignores an incoming follow request.
  Future<UserResponse> ignoreFollowRequest(String userId) =>
      _resolveFollowRequest(userId, accept: false);

  Future<UserResponse> _resolveFollowRequest(
    String userId, {
    required bool accept,
  }) async {
    if (userId.trim().isEmpty) throw ArgumentError.value(userId, 'userId');
    final fanfou.FanfouClient client;
    try {
      client = await _clientFactory();
    } on Object {
      throw const UserApiClientUnknownFailure();
    }
    try {
      final user = accept
          ? await client.friendships.accept(userId, format: 'html')
          : await client.friendships.deny(userId, format: 'html');
      return _mapUser(user);
    } on fanfou.FanfouApiException catch (error) {
      throw UserApiClientApiFailure(
        statusCode: error.statusCode,
        message: parseFanfouApiError(error.body),
      );
    } on UserApiClientFailure {
      rethrow;
    } on Object {
      throw const UserApiClientUnknownFailure();
    } finally {
      client.close();
    }
  }

  UserResponse _mapUser(fanfou.User user) => UserResponse(
    id: user.id,
    name: user.name,
    screenName: user.screenName,
    avatarUrl: user.profileImageUrlLarge ?? user.profileImageUrl,
    description: user.description,
    location: user.location,
    url: user.url,
    protected: user.protected,
    following: user.following,
    followersCount: user.followersCount,
    friendsCount: user.friendsCount,
    favoritesCount: user.favouritesCount,
    statusesCount: user.statusesCount,
    gender: user.gender,
    photoCount: user.photoCount,
    createdAt: user.createdAt,
    birthday: user.birthday,
  );

  /// Returns accounts followed by [userId].
  Future<List<UserResponse>> getFriends(String userId, {int page = 1}) =>
      _getRelations(userId, page: page, followers: false);

  /// Returns accounts following [userId].
  Future<List<UserResponse>> getFollowers(String userId, {int page = 1}) =>
      _getRelations(userId, page: page, followers: true);

  Future<List<UserResponse>> _getRelations(
    String userId, {
    required int page,
    required bool followers,
  }) async {
    if (userId.trim().isEmpty) throw ArgumentError.value(userId, 'userId');
    final client = await _clientFactory();
    try {
      final users = followers
          ? await client.users.followers(
              id: userId,
              count: relationPageSize,
              page: page,
              format: 'html',
            )
          : await client.users.friends(
              id: userId,
              count: relationPageSize,
              page: page,
              format: 'html',
            );
      return users
          .map(
            (user) => UserResponse(
              id: user.id,
              name: user.name,
              screenName: user.screenName,
              avatarUrl: user.profileImageUrlLarge ?? user.profileImageUrl,
              description: user.description,
              location: user.location,
              url: user.url,
              protected: user.protected,
              following: user.following,
              followersCount: user.followersCount,
              friendsCount: user.friendsCount,
              favoritesCount: user.favouritesCount,
              statusesCount: user.statusesCount,
              gender: user.gender,
              photoCount: user.photoCount,
              createdAt: user.createdAt,
              birthday: user.birthday,
            ),
          )
          .toList(growable: false);
    } on fanfou.FanfouApiException catch (error) {
      throw UserApiClientApiFailure(
        statusCode: error.statusCode,
        message: parseFanfouApiError(error.body),
      );
    } on UserApiClientFailure {
      rethrow;
    } on Object {
      throw const UserApiClientUnknownFailure();
    } finally {
      client.close();
    }
  }
}
