import 'package:equatable/equatable.dart';

/// Identity metadata for a Fanfou account stored by the application.
final class AuthenticatedAccount extends Equatable {
  /// Creates an authenticated account.
  const AuthenticatedAccount({
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

  /// Stable Fanfou user identifier used as the account storage key.
  final String id;

  /// Display name.
  final String name;

  /// Fanfou screen name.
  final String screenName;

  /// Preferred avatar URL, when available.
  final String? avatarUrl;

  /// User biography returned during account verification.
  final String? description;

  /// User-provided location returned during account verification.
  final String? location;

  /// User-provided home page URL returned during account verification.
  final String? url;

  /// Whether the account is protected, returned during account verification.
  final bool? protected;

  /// Whether the active account follows this user, returned during account
  /// verification.
  final bool? following;

  /// Number of followers returned during account verification.
  final int? followersCount;

  /// Number of followed accounts returned during account verification.
  final int? friendsCount;

  /// Number of favorited statuses returned during account verification.
  final int? favoritesCount;

  /// Number of published statuses returned during account verification.
  final int? statusesCount;

  /// User-provided gender returned during account verification.
  final String? gender;

  /// Number of published photos returned during account verification.
  final int? photoCount;

  /// Account creation time returned during account verification.
  final String? createdAt;

  /// User-provided birthday returned during account verification.
  final String? birthday;

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

  @override
  bool get stringify => false;
}
