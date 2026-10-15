import 'package:equatable/equatable.dart';

/// Author information attached to a Fanfou status.
final class StatusAuthor extends Equatable {
  /// Creates a status author.
  const StatusAuthor({
    required this.id,
    required this.name,
    required this.screenName,
    this.gender,
    this.avatarUrl,
    this.description,
    this.url,
    this.location,
    this.createdAt,
    this.protected,
    this.following,
    this.followersCount,
    this.friendsCount,
    this.favoritesCount,
    this.statusesCount,
    this.photoCount,
  });

  /// Stable Fanfou user identifier.
  final String id;

  /// Display name.
  final String name;

  /// Screen name.
  final String screenName;

  /// User-provided gender supplied by the status response.
  final String? gender;

  /// Preferred avatar URL, when available.
  final String? avatarUrl;

  /// User biography supplied by the status response.
  final String? description;

  /// User-provided website supplied by the status response.
  final String? url;

  /// User-provided location supplied by the status response.
  final String? location;

  /// Raw Fanfou registration timestamp supplied by the status response.
  final String? createdAt;

  /// Whether the account is protected, supplied by the status response.
  final bool? protected;

  /// Whether the active account follows this user, supplied by the status
  /// response.
  final bool? following;

  /// Number of followers supplied by the status response.
  final int? followersCount;

  /// Number of followed accounts supplied by the status response.
  final int? friendsCount;

  /// Number of favorited statuses supplied by the status response.
  final int? favoritesCount;

  /// Number of published statuses supplied by the status response.
  final int? statusesCount;

  /// Number of published photos supplied by the status response.
  final int? photoCount;

  @override
  List<Object?> get props => [
    id,
    name,
    screenName,
    gender,
    avatarUrl,
    description,
    url,
    location,
    createdAt,
    protected,
    following,
    followersCount,
    friendsCount,
    favoritesCount,
    statusesCount,
    photoCount,
  ];
}
