import 'dart:async';

import 'package:direct_message_repository/src/exceptions/exceptions.dart';
import 'package:direct_message_repository/src/models/models.dart';
import 'package:fanfou/fanfou.dart' as fanfou;
import 'package:fanfou_error_parser/fanfou_error_parser.dart';

/// Creates a Fanfou client scoped to the active account.
typedef DirectMessageClientFactory = Future<fanfou.FanfouClient> Function();

/// Returns the identifier of the account currently used by the repository.
typedef DirectMessageActiveAccountIdProvider = String? Function();

/// Repository for Fanfou direct messages.
///
/// The repository owns direct-message operations and transforms Fanfou SDK
/// response models into app domain models. It receives a client factory
/// instead of reading authentication state itself so account switching
/// remains owned by the application composition root.
class DirectMessageRepository {
  /// Creates a direct message repository.
  factory DirectMessageRepository({
    required DirectMessageClientFactory clientFactory,
    required DirectMessageActiveAccountIdProvider activeAccountIdProvider,
  }) {
    return DirectMessageRepository._(clientFactory, activeAccountIdProvider);
  }

  DirectMessageRepository._(
    this._clientFactory,
    this._activeAccountIdProvider,
  );

  final DirectMessageClientFactory _clientFactory;
  final DirectMessageActiveAccountIdProvider _activeAccountIdProvider;

  final StreamController<DirectMessageChange> _messageChangesController =
      StreamController<DirectMessageChange>.broadcast();

  /// Successful direct-message mutations, scoped by account identifier.
  Stream<DirectMessageChange> get messageChanges =>
      _messageChangesController.stream;

  /// Returns one page of the active account's conversations, newest first.
  Future<DirectMessageConversationPage> getConversationList({
    required int limit,
    required int page,
  }) async {
    final response = await _withClient(
      (client) =>
          client.directMessages.conversationList(count: limit, page: page),
    );
    final conversations = response
        .map(_conversationFromSummary)
        .toList(growable: false);
    final hasMore = conversations.length >= limit;
    return DirectMessageConversationPage(
      conversations: conversations,
      hasMore: hasMore,
      nextPage: hasMore ? page + 1 : null,
    );
  }

  /// Returns one page of messages exchanged with [userId], newest first.
  Future<DirectMessageHistoryPage> getConversation(
    String userId, {
    required int limit,
    required int page,
  }) async {
    if (userId.trim().isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Must not be empty.');
    }

    final response = await _withClient(
      (client) =>
          client.directMessages.conversation(userId, count: limit, page: page),
    );
    final messages = response.map(_messageFromSdk).toList(growable: false);
    final hasMore = messages.length >= limit;
    return DirectMessageHistoryPage(
      messages: messages,
      hasMore: hasMore,
      nextPage: hasMore ? page + 1 : null,
    );
  }

  /// Sends a direct message to [userId].
  Future<DirectMessage> sendMessage(String userId, String text) async {
    if (userId.trim().isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Must not be empty.');
    }
    if (text.trim().isEmpty) {
      throw ArgumentError.value(text, 'text', 'Must not be empty.');
    }

    final response = await _withClient(
      (client) => client.directMessages.send(user: userId, text: text),
    );
    return _messageFromSdk(response);
  }

  /// Deletes the direct message [messageId].
  Future<void> deleteMessage(String messageId) async {
    if (messageId.trim().isEmpty) {
      throw ArgumentError.value(messageId, 'messageId', 'Must not be empty.');
    }

    await _withClient((client) => client.directMessages.destroy(messageId));
    final accountId = _activeAccountIdProvider();
    if (accountId != null && accountId.isNotEmpty) {
      _messageChangesController.add(
        DirectMessageDeleted(accountId: accountId, messageId: messageId),
      );
    }
  }

  /// Releases the message change stream.
  Future<void> close() => _messageChangesController.close();

  Future<R> _withClient<R>(
    Future<R> Function(fanfou.FanfouClient client) action,
  ) async {
    final fanfou.FanfouClient client;
    try {
      client = await _clientFactory();
    } on Object catch (_, stackTrace) {
      Error.throwWithStackTrace(
        const DirectMessageRepositoryUnknownFailure(),
        stackTrace,
      );
    }

    try {
      return await action(client);
    } on fanfou.FanfouApiException catch (error) {
      throw DirectMessageRepositoryApiFailure(
        statusCode: error.statusCode,
        message: parseFanfouApiError(error.body),
      );
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        DirectMessageRepositoryUnknownFailure(cause: error),
        stackTrace,
      );
    } finally {
      client.close();
    }
  }

  DirectMessageConversation _conversationFromSummary(
    fanfou.ConversationSummary summary,
  ) {
    final message = _messageFromSdk(summary.dm);
    final otherUser = _otherUserFrom(summary.dm, otherId: summary.otherId);
    return DirectMessageConversation(
      otherUserId: summary.otherId,
      lastMessage: message,
      messageCount: summary.msgNum,
      hasUnread: summary.newConv,
      otherUserScreenName:
          otherUser?.screenName ??
          (summary.dm.senderId == summary.otherId
              ? summary.dm.senderScreenName
              : summary.dm.recipientId == summary.otherId
              ? summary.dm.recipientScreenName
              : null),
      otherUserAvatarUrl: _avatarUrl(otherUser),
      otherUser: otherUser == null
          ? null
          : DirectMessageUser(
              id: otherUser.id,
              name: otherUser.name,
              screenName: otherUser.screenName,
              avatarUrl: _avatarUrl(otherUser),
              description: otherUser.description,
              location: otherUser.location,
              url: otherUser.url,
              protected: otherUser.protected,
              following: otherUser.following,
              followersCount: otherUser.followersCount,
              friendsCount: otherUser.friendsCount,
              favoritesCount: otherUser.favouritesCount,
              statusesCount: otherUser.statusesCount,
              gender: otherUser.gender,
              photoCount: otherUser.photoCount,
              createdAt: otherUser.createdAt,
              birthday: otherUser.birthday,
            ),
    );
  }

  DirectMessage _messageFromSdk(fanfou.DirectMessage message) {
    return DirectMessage(
      id: message.id,
      text: message.text,
      createdAt: message.createdAt,
      senderId: message.senderId,
      recipientId: message.recipientId,
      senderScreenName: message.sender?.screenName ?? message.senderScreenName,
    );
  }

  fanfou.User? _otherUserFrom(
    fanfou.DirectMessage message, {
    required String otherId,
  }) {
    final sender = message.sender;
    if (sender != null && sender.id == otherId) return sender;
    final recipient = message.recipient;
    if (recipient != null && recipient.id == otherId) return recipient;
    return null;
  }

  String? _avatarUrl(fanfou.User? user) {
    if (user == null) return null;
    return user.profileImageUrlLarge ?? user.profileImageUrl;
  }
}
