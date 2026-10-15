/// Data returned by Fanfou's user endpoint.
final class UserResponse {
  /// Creates a typed user response.
  const UserResponse({
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

  /// Preferred large avatar URL.
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
}
