import 'dart:async';
import 'dart:io';

import 'package:fanfou/fanfou.dart' as fanfou;
import 'package:fanfou_error_parser/fanfou_error_parser.dart';
import 'package:status_repository/src/exceptions/exceptions.dart';
import 'package:status_repository/src/models/models.dart';
import 'package:status_repository/src/status_photo_upload_preparer.dart';

const _defaultPageSize = 20;
const _statusResponseFormat = 'html';

/// Creates a Fanfou client scoped to the current active account.
typedef StatusClientFactory = Future<fanfou.FanfouClient> Function();

/// Returns the identifier of the account currently used by [StatusRepository].
typedef ActiveAccountIdProvider = String? Function();

/// Repository for Fanfou statuses.
///
/// The repository owns status-oriented operations and transforms Fanfou SDK
/// response models into app domain models. It receives a client factory instead
/// of reading authentication state itself so account switching remains owned by
/// the application composition root.
class StatusRepository {
  /// Creates a status repository.
  factory StatusRepository({
    required StatusClientFactory clientFactory,
    required ActiveAccountIdProvider activeAccountIdProvider,
    StatusPhotoUploadPreparer photoUploadPreparer =
        const StatusPhotoUploadPreparer(),
  }) {
    return StatusRepository._(
      clientFactory,
      activeAccountIdProvider,
      photoUploadPreparer,
    );
  }

  StatusRepository._(
    this._clientFactory,
    this._activeAccountIdProvider,
    this._photoUploadPreparer,
  );

  final StatusPhotoUploadPreparer _photoUploadPreparer;

  final StatusClientFactory _clientFactory;

  final ActiveAccountIdProvider _activeAccountIdProvider;

  final StreamController<StatusChange> _statusChangesController =
      StreamController<StatusChange>.broadcast();

  /// Successful status mutations, scoped by account identifier.
  Stream<StatusChange> get statusChanges => _statusChangesController.stream;

  /// Returns one page of the active account's home timeline.
  Future<StatusPage> getHomeTimeline({
    int limit = _defaultPageSize,
    String? sinceId,
    String? maxId,
  }) async {
    _validateLimit(limit);
    final response = await _withClient(
      (client) => client.statuses.homeTimeline(
        format: _statusResponseFormat,
        count: limit,
        sinceId: sinceId,
        maxId: maxId,
      ),
    );
    return _statusIdPage(response, limit: limit, previousMaxId: maxId);
  }

  /// Returns one page of public statuses from non-protected accounts.
  Future<StatusPage> getPublicTimeline({
    int limit = _defaultPageSize,
    String? sinceId,
    String? maxId,
  }) async {
    _validateLimit(limit);
    final response = await _withClient(
      (client) => client.statuses.publicTimeline(
        format: _statusResponseFormat,
        count: limit,
        sinceId: sinceId,
        maxId: maxId,
      ),
    );
    return _statusIdPage(response, limit: limit, previousMaxId: maxId);
  }

  /// Searches statuses matching [query], newest first.
  ///
  /// When [userId] is supplied, the search uses that user's timeline.
  Future<StatusPage> searchStatuses({
    required String query,
    String? userId,
    int limit = _defaultPageSize,
    String? sinceId,
    String? maxId,
  }) async {
    _validateLimit(limit);
    final keyword = query.trim();
    if (keyword.isEmpty) {
      throw ArgumentError.value(query, 'query', 'Must not be empty.');
    }
    return _searchStatuses(
      keyword,
      limit: limit,
      userId: userId,
      sinceId: sinceId,
      maxId: maxId,
    );
  }

  /// Searches statuses posted by the currently authenticated account.
  ///
  /// Fanfou uses `/search/user_timeline` for this endpoint and accepts an
  /// omitted `id` to mean the current account.
  Future<StatusPage> searchMyStatuses({
    required String query,
    int limit = _defaultPageSize,
    String? sinceId,
    String? maxId,
  }) async {
    _validateLimit(limit);
    final keyword = query.trim();
    if (keyword.isEmpty) {
      throw ArgumentError.value(query, 'query', 'Must not be empty.');
    }
    return _searchStatuses(
      keyword,
      limit: limit,
      mine: true,
      sinceId: sinceId,
      maxId: maxId,
    );
  }

  Future<StatusPage> _searchStatuses(
    String keyword, {
    required int limit,
    String? userId,
    bool mine = false,
    String? sinceId,
    String? maxId,
  }) async {
    final response = await _withClient(
      (client) => mine || userId != null
          ? client.search.userTimeline(
              keyword,
              id: userId,
              format: _statusResponseFormat,
              count: limit,
              sinceId: sinceId,
              maxId: maxId,
            )
          : client.search.publicTimeline(
              keyword,
              format: _statusResponseFormat,
              count: limit,
              sinceId: sinceId,
              maxId: maxId,
            ),
    );
    return _statusIdPage(response, limit: limit, previousMaxId: maxId);
  }

  /// Returns one page of statuses that mention the active account.
  Future<StatusPage> getMentions({
    int limit = _defaultPageSize,
    String? sinceId,
    String? maxId,
  }) async {
    _validateLimit(limit);
    final response = await _withClient(
      (client) => client.statuses.mentions(
        format: _statusResponseFormat,
        count: limit,
        sinceId: sinceId,
        maxId: maxId,
      ),
    );
    return _statusIdPage(response, limit: limit, previousMaxId: maxId);
  }

  /// Returns one page of statuses posted by [userId].
  Future<StatusPage> getUserTimeline({
    required String userId,
    int limit = _defaultPageSize,
    String? sinceId,
    String? maxId,
  }) async {
    _validateUserId(userId);
    _validateLimit(limit);
    final response = await _withClient(
      (client) => client.statuses.userTimeline(
        id: userId,
        format: _statusResponseFormat,
        count: limit,
        sinceId: sinceId,
        maxId: maxId,
      ),
    );
    return _statusIdPage(response, limit: limit, previousMaxId: maxId);
  }

  /// Returns one page of photo statuses posted by [userId].
  Future<StatusPage> getPhotoTimeline({
    required String userId,
    int limit = _defaultPageSize,
    String? sinceId,
    String? maxId,
  }) async {
    _validateUserId(userId);
    _validateLimit(limit);
    final response = await _withClient(
      (client) => client.photos.userTimeline(
        id: userId,
        format: _statusResponseFormat,
        count: limit,
        sinceId: sinceId,
        maxId: maxId,
      ),
    );
    return _statusIdPage(response, limit: limit, previousMaxId: maxId);
  }

  /// Returns one page of statuses favorited by [userId].
  Future<StatusPage> getFavorites({
    required String userId,
    int limit = _defaultPageSize,
    String? cursor,
  }) async {
    _validateUserId(userId);
    _validateLimit(limit);
    final page = cursor == null ? 1 : int.tryParse(cursor);
    if (page == null || page < 1) {
      throw ArgumentError.value(cursor, 'cursor', 'Invalid page cursor.');
    }

    final response = await _withClient(
      (client) => client.favorites.list(
        id: userId,
        format: _statusResponseFormat,
        count: limit,
        page: page,
      ),
    );
    final statuses = _mapStatuses(response);
    final hasMore = response.length >= limit;
    return StatusPage(
      statuses: statuses,
      hasMore: hasMore,
      nextCursor: hasMore ? '${page + 1}' : null,
    );
  }

  /// Returns one status by [statusId].
  Future<Status> getStatus(String statusId) async {
    final status = await _withClient(
      (client) => client.statuses.show(
        statusId,
        format: _statusResponseFormat,
      ),
    );
    return _mapStatus(status);
  }

  /// Returns the recent conversation around [statusId].
  Future<List<Status>> getContextTimeline(String statusId) async {
    final statuses = await _withClient(
      (client) => client.statuses.contextTimeline(
        statusId,
        format: _statusResponseFormat,
      ),
    );
    return _mapStatuses(statuses);
  }

  /// Creates a status and publishes a [StatusCreated] change.
  Future<Status> createStatus(
    String text, {
    String? inReplyToStatusId,
    String? repostStatusId,
  }) async {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      throw ArgumentError.value(text, 'text', 'Status text cannot be empty.');
    }
    final accountId = _requireActiveAccountId();
    final response = await _withClient(
      (client) => client.statuses.update(
        normalizedText,
        inReplyToStatusId: inReplyToStatusId,
        repostStatusId: repostStatusId,
        format: _statusResponseFormat,
      ),
    );
    final status = _mapStatus(response);
    _statusChangesController.add(
      StatusCreated(accountId: accountId, status: status),
    );
    return status;
  }

  /// Uploads a photo with optional text and emits a created-status event.
  Future<Status> createPhotoStatus({
    required String photoPath,
    String text = '',
  }) async {
    final accountId = _requireActiveAccountId();
    final photo = await _photoUploadPreparer.prepare(File(photoPath));
    try {
      final response = await _withClient(
        (client) => client.photos.upload(
          photo.file,
          status: text.trim().isEmpty ? null : text.trim(),
          format: _statusResponseFormat,
        ),
      );
      final status = _mapStatus(response);
      _statusChangesController.add(
        StatusCreated(accountId: accountId, status: status),
      );
      return status;
    } finally {
      await photo.dispose();
    }
  }

  /// Deletes a status and publishes a [StatusDeleted] change.
  Future<void> deleteStatus(String statusId) async {
    final accountId = _requireActiveAccountId();
    await _withClient(
      (client) => client.statuses.destroy(
        statusId,
        format: _statusResponseFormat,
      ),
    );
    _statusChangesController.add(
      StatusDeleted(accountId: accountId, statusId: statusId),
    );
  }

  /// Favorites a status and publishes its latest value.
  ///
  /// [currentStatus] is the value already displayed by the caller. Fanfou's
  /// favorite mutation responses can contain malformed status text, so the
  /// existing value is used as the source of content.
  Future<Status> favoriteStatus(
    String statusId, {
    required Status currentStatus,
  }) async {
    final accountId = _requireActiveAccountId();
    await _withClient(
      (client) => client.favorites.create(
        statusId,
        format: _statusResponseFormat,
      ),
    );
    final status = currentStatus.copyWith(isFavorited: true);
    _statusChangesController.add(
      StatusUpdated(accountId: accountId, status: status),
    );
    return status;
  }

  /// Removes a favorite and publishes its latest value.
  ///
  /// [currentStatus] is the value already displayed by the caller. Fanfou's
  /// unfavorite response may return a PHP-serialized value in the status text,
  /// so the existing value is used as the source of content.
  Future<Status> unfavoriteStatus(
    String statusId, {
    required Status currentStatus,
  }) async {
    final accountId = _requireActiveAccountId();
    await _withClient(
      (client) => client.favorites.destroy(
        statusId,
        format: _statusResponseFormat,
      ),
    );
    final status = currentStatus.copyWith(isFavorited: false);
    _statusChangesController.add(
      StatusUpdated(accountId: accountId, status: status),
    );
    return status;
  }

  /// Releases the status change stream.
  Future<void> close() => _statusChangesController.close();

  Future<T> _withClient<T>(
    Future<T> Function(fanfou.FanfouClient client) request,
  ) async {
    final fanfou.FanfouClient client;
    try {
      client = await _clientFactory();
    } on Object catch (error) {
      throw StatusRepositoryUnknownFailure(cause: error);
    }

    try {
      return await request(client);
    } on StatusRepositoryFailure {
      rethrow;
    } on fanfou.FanfouApiException catch (error) {
      throw StatusRepositoryApiFailure(
        statusCode: error.statusCode,
        message: parseFanfouApiError(error.body),
      );
    } on Object catch (error) {
      throw StatusRepositoryUnknownFailure(cause: error);
    } finally {
      client.close();
    }
  }

  StatusPage _statusIdPage(
    List<fanfou.Status> response, {
    required int limit,
    required String? previousMaxId,
  }) {
    final statuses = _mapStatuses(response);
    final nextCursor = statuses.isEmpty ? null : statuses.last.id;
    final hasMore =
        response.length >= limit &&
        nextCursor != null &&
        nextCursor != previousMaxId;
    return StatusPage(
      statuses: statuses,
      hasMore: hasMore,
      nextCursor: hasMore ? nextCursor : null,
    );
  }

  List<Status> _mapStatuses(Iterable<fanfou.Status> statuses) {
    return List<Status>.unmodifiable(statuses.map(_mapStatus));
  }

  String _requireActiveAccountId() {
    final accountId = _activeAccountIdProvider();
    if (accountId == null || accountId.isEmpty) {
      throw const StatusRepositoryUnknownFailure();
    }
    return accountId;
  }

  void _validateLimit(int limit) {
    if (limit < 1) {
      throw ArgumentError.value(limit, 'limit', 'Must be greater than zero.');
    }
  }

  void _validateUserId(String userId) {
    if (userId.trim().isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Must not be empty.');
    }
  }

  Status _mapStatus(fanfou.Status status) {
    final user = status.user;
    return Status(
      id: status.id,
      text: status.text,
      createdAt: status.createdAt,
      author: StatusAuthor(
        id: user?.id ?? '',
        name: user?.name ?? '',
        screenName: user?.screenName ?? '',
        gender: user?.gender,
        avatarUrl: user?.profileImageUrlLarge ?? user?.profileImageUrl,
        description: user?.description,
        url: user?.url,
        location: user?.location,
        createdAt: user?.createdAt,
        protected: user?.protected,
        following: user?.following,
        followersCount: user?.followersCount,
        friendsCount: user?.friendsCount,
        favoritesCount: user?.favouritesCount,
        statusesCount: user?.statusesCount,
        photoCount: user?.photoCount,
      ),
      photo: _mapPhoto(status.photo),
      source: _mapSource(status.source),
      isFavorited: status.favorited ?? false,
      isSelf: status.isSelf ?? false,
      inReplyToStatusId: status.inReplyToStatusId?.isEmpty ?? true
          ? null
          : status.inReplyToStatusId,
      inReplyToUserId: status.inReplyToUserId?.isEmpty ?? true
          ? null
          : status.inReplyToUserId,
    );
  }

  /// Reduces a raw Fanfou source value, which is either plain text or an HTML
  /// anchor such as `<a href="...">旦</a>`, to the client name it displays.
  String? _mapSource(String? source) {
    if (source == null) return null;
    var text = source.trim();
    final anchor = RegExp(
      r'<a\b[^>]*>(.*?)</a>',
      caseSensitive: false,
    ).firstMatch(text);
    if (anchor != null) text = anchor.group(1)!;
    text = text
        .replaceAll(RegExp('<[^>]+>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
    return text.isEmpty ? null : text;
  }

  StatusPhotoUrls? _mapPhoto(fanfou.Photo? photo) {
    if (photo == null) return null;
    return StatusPhotoUrls(
      thumbnailUrl: photo.thumbUrl,
      imageUrl: photo.imageUrl,
      largeUrl: photo.largeUrl,
    );
  }
}
