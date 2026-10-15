import 'package:equatable/equatable.dart';

/// Application-facing profile for a Fanfou user.
final class UserProfile extends Equatable {
  /// Creates a user profile.
  const UserProfile({
    required this.id,
    required this.name,
    required this.screenName,
    this.avatarUrl,
    this.description,
    this.location,
    this.url,
    this.protected,
    this.following,
    this.followersCount,
    this.friendsCount,
    this.favoritesCount,
    this.statusesCount,
    this.gender,
    this.photoCount,
    this.createdAt,
    this.birthday,
  });

  /// Stable Fanfou user identifier.
  final String id;

  /// Display name.
  final String name;

  /// Fanfou screen name.
  final String screenName;

  /// Preferred avatar URL.
  final String? avatarUrl;

  /// User biography.
  final String? description;

  /// User-provided location.
  final String? location;

  /// User-provided website URL.
  final String? url;

  /// Whether the account is protected, as returned by Fanfou.
  final bool? protected;

  /// Whether the active account follows this user, as returned by Fanfou.
  final bool? following;

  /// Number of followers.
  final int? followersCount;

  /// Number of followed accounts.
  final int? friendsCount;

  /// Number of favorited statuses.
  final int? favoritesCount;

  /// Number of published statuses.
  final int? statusesCount;

  /// User-provided gender.
  final String? gender;

  /// Number of published photos.
  final int? photoCount;

  /// Account creation time as returned by Fanfou.
  final String? createdAt;

  /// User-provided birthday.
  final String? birthday;

  /// Returns this profile with the server-confirmed following status.
  UserProfile copyWithFollowing({required bool following}) => UserProfile(
    id: id,
    name: name,
    screenName: screenName,
    avatarUrl: avatarUrl,
    description: description,
    location: location,
    url: url,
    protected: protected,
    following: following,
    followersCount: followersCount,
    friendsCount: friendsCount,
    favoritesCount: favoritesCount,
    statusesCount: statusesCount,
    gender: gender,
    photoCount: photoCount,
    createdAt: createdAt,
    birthday: birthday,
  );

  @override
  List<Object?> get props => [
    id,
    name,
    screenName,
    avatarUrl,
    description,
    location,
    url,
    protected,
    following,
    followersCount,
    friendsCount,
    favoritesCount,
    statusesCount,
    gender,
    photoCount,
    createdAt,
    birthday,
  ];
}
