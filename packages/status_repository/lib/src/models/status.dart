import 'package:equatable/equatable.dart';
import 'package:status_repository/src/models/status_author.dart';
import 'package:status_repository/src/models/status_photo_urls.dart';

/// Domain model for a Fanfou status.
final class Status extends Equatable {
  /// Creates a status.
  const Status({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.author,
    this.photo,
    this.source,
    this.isFavorited = false,
    this.isSelf = false,
    this.inReplyToStatusId,
    this.inReplyToUserId,
  });

  /// Stable status identifier.
  final String id;

  /// Status body returned in the requested API format.
  ///
  /// The application requests HTML so semantic links can be rendered safely.
  final String text;

  /// Raw Fanfou creation timestamp.
  final String createdAt;

  /// Status author.
  final StatusAuthor author;

  /// Attached photo URLs, when available.
  final StatusPhotoUrls? photo;

  /// Client name this status was posted from, when available.
  final String? source;

  /// Whether the active account has favorited this status.
  final bool isFavorited;

  /// Whether this status belongs to the active account.
  final bool isSelf;

  /// Parent status identifier, or null when this is an original status.
  final String? inReplyToStatusId;

  /// Author identifier of the status this message replies to.
  final String? inReplyToUserId;

  /// Returns a copy with selected fields replaced.
  Status copyWith({
    String? id,
    String? text,
    String? createdAt,
    StatusAuthor? author,
    Object? photo = _unset,
    String? source,
    bool? isFavorited,
    bool? isSelf,
    Object? inReplyToStatusId = _unset,
    Object? inReplyToUserId = _unset,
  }) {
    return Status(
      id: id ?? this.id,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      author: author ?? this.author,
      photo: photo == _unset ? this.photo : photo as StatusPhotoUrls?,
      source: source ?? this.source,
      isFavorited: isFavorited ?? this.isFavorited,
      isSelf: isSelf ?? this.isSelf,
      inReplyToStatusId: inReplyToStatusId == _unset
          ? this.inReplyToStatusId
          : inReplyToStatusId as String?,
      inReplyToUserId: inReplyToUserId == _unset
          ? this.inReplyToUserId
          : inReplyToUserId as String?,
    );
  }

  @override
  List<Object?> get props => [
    id,
    text,
    createdAt,
    author,
    photo,
    source,
    isFavorited,
    isSelf,
    inReplyToStatusId,
    inReplyToUserId,
  ];
}

const _unset = Object();
