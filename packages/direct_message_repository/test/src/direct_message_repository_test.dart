import 'package:direct_message_repository/direct_message_repository.dart';
import 'package:fanfou/fanfou.dart' as fanfou;
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockFanfouClient extends Mock implements fanfou.FanfouClient {}

class _MockDirectMessagesApi extends Mock implements fanfou.DirectMessagesApi {}

void main() {
  group(DirectMessageRepository, () {
    late fanfou.FanfouClient fanfouClient;
    late fanfou.DirectMessagesApi directMessagesApi;
    late DirectMessageRepository subject;

    setUp(() {
      fanfouClient = _MockFanfouClient();
      directMessagesApi = _MockDirectMessagesApi();
      when(() => fanfouClient.directMessages).thenReturn(directMessagesApi);
      when(() => fanfouClient.close()).thenReturn(null);
      subject = DirectMessageRepository(
        clientFactory: () async => fanfouClient,
        activeAccountIdProvider: () => 'account-a',
      );
    });

    group('getConversationList', () {
      test(
        'returns $DirectMessageConversation list when the API call succeeds',
        () async {
          when(
            () => directMessagesApi.conversationList(count: 20, page: 1),
          ).thenAnswer((_) async => [_fanfouSummary]);

          final result = await subject.getConversationList(limit: 20, page: 1);

          expect(
            result,
            const DirectMessageConversationPage(
              conversations: [_conversation],
              hasMore: false,
              nextPage: null,
            ),
          );
          verify(
            () => directMessagesApi.conversationList(count: 20, page: 1),
          ).called(1);
          verify(() => fanfouClient.close()).called(1);
        },
      );

      for (final outgoing in [false, true]) {
        test(
          'matches otherId to full peer details for outgoing=$outgoing',
          () async {
            final dm = fanfou.DirectMessage(
              id: 'dm-1',
              text: '你好',
              createdAt: 'today',
              senderId: outgoing ? 'account-a' : 'user-b',
              recipientId: outgoing ? 'user-b' : 'account-a',
              sender: outgoing ? _fanfouActiveUser : _fanfouPeerUser,
              recipient: outgoing ? _fanfouPeerUser : _fanfouActiveUser,
            );
            when(
              () => directMessagesApi.conversationList(count: 20, page: 1),
            ).thenAnswer(
              (_) async => [
                fanfou.ConversationSummary(
                  dm: dm,
                  otherId: 'user-b',
                  msgNum: 1,
                  newConv: false,
                ),
              ],
            );
            final result = await subject.getConversationList(
              limit: 20,
              page: 1,
            );
            final conversation = result.conversations.single;
            expect(conversation.otherUser, _peerDetails);
            expect(conversation.otherUserId, _peerDetails.id);
            expect(conversation.otherUserScreenName, _peerDetails.screenName);
            expect(conversation.otherUserAvatarUrl, _peerDetails.avatarUrl);
          },
        );
      }
      for (final otherId in ['account-a', 'user-b', 'unknown']) {
        test(
          'uses only matching fallback fields for otherId=$otherId',
          () async {
            when(
              () => directMessagesApi.conversationList(count: 20, page: 1),
            ).thenAnswer(
              (_) async => [
                fanfou.ConversationSummary(
                  dm: fanfou.DirectMessage(
                    id: 'dm-1',
                    text: '你好',
                    createdAt: 'today',
                    senderId: 'account-a',
                    recipientId: 'user-b',
                    senderScreenName: 'Account',
                    recipientScreenName: 'Peer',
                    sender: _fanfouActiveUser,
                  ),
                  otherId: otherId,
                  msgNum: 1,
                  newConv: false,
                ),
              ],
            );
            final result = await subject.getConversationList(
              limit: 20,
              page: 1,
            );
            final conversation = result.conversations.single;
            expect(conversation.otherUserScreenName, switch (otherId) {
              'account-a' => 'account',
              'user-b' => 'Peer',
              _ => null,
            });
            expect(
              conversation.otherUser?.id,
              otherId == 'account-a' ? otherId : null,
            );
          },
        );
      }

      test('requests the provided page and limit', () async {
        when(
          () => directMessagesApi.conversationList(count: 5, page: 2),
        ).thenAnswer((_) async => const []);

        await subject.getConversationList(limit: 5, page: 2);

        verify(
          () => directMessagesApi.conversationList(count: 5, page: 2),
        ).called(1);
      });

      test(
        'falls back to sender fields when the peer user is missing',
        () async {
          const summaryWithoutPeer = DirectMessageConversation(
            otherUserId: 'user-b',
            lastMessage: DirectMessage(
              id: 'dm-1',
              text: '你好',
              createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
              senderId: 'user-b',
              recipientId: 'account-a',
              senderScreenName: 'fanfou_b',
            ),
            messageCount: 1,
            hasUnread: true,
            otherUserScreenName: 'fanfou_b',
          );
          when(
            () => directMessagesApi.conversationList(count: 20, page: 1),
          ).thenAnswer(
            (_) async => [
              fanfou.ConversationSummary(
                dm: _fanfouMessageWithoutUsers,
                otherId: 'user-b',
                msgNum: 1,
                newConv: true,
              ),
            ],
          );

          final result = await subject.getConversationList(limit: 20, page: 1);

          expect(result.conversations, const [summaryWithoutPeer]);
          expect(result.hasMore, isFalse);
          expect(result.nextPage, isNull);
        },
      );

      test(
        'keeps loading available when the API returns a full page',
        () async {
          when(
            () => directMessagesApi.conversationList(count: 2, page: 1),
          ).thenAnswer((_) async => [_fanfouSummary, _fanfouSummary]);

          final result = await subject.getConversationList(limit: 2, page: 1);

          expect(result.hasMore, isTrue);
          expect(result.nextPage, 2);
        },
      );

      test(
        'throws an API failure when Fanfou responds with an error',
        () async {
          when(
            () => directMessagesApi.conversationList(count: 20, page: 1),
          ).thenThrow(fanfou.FanfouApiException(500, 'boom'));

          await expectLater(
            subject.getConversationList(limit: 20, page: 1),
            throwsA(
              isA<DirectMessageRepositoryApiFailure>().having(
                (failure) => failure.statusCode,
                'statusCode',
                500,
              ),
            ),
          );
        },
      );

      test(
        'throws an unknown failure when the client cannot be created',
        () async {
          final subjectWithBrokenFactory = DirectMessageRepository(
            clientFactory: () async => throw Exception('no session'),
            activeAccountIdProvider: () => 'account-a',
          );

          await expectLater(
            subjectWithBrokenFactory.getConversationList(limit: 20, page: 1),
            throwsA(isA<DirectMessageRepositoryUnknownFailure>()),
          );
        },
      );

      test(
        'throws an unknown failure when the call fails unexpectedly',
        () async {
          when(
            () => directMessagesApi.conversationList(count: 20, page: 1),
          ).thenThrow(StateError('bad parse'));

          await expectLater(
            subject.getConversationList(limit: 20, page: 1),
            throwsA(isA<DirectMessageRepositoryUnknownFailure>()),
          );
        },
      );
    });

    group('getConversation', () {
      test('returns $DirectMessage list when the API call succeeds', () async {
        when(
          () => directMessagesApi.conversation('user-b', count: 20, page: 1),
        ).thenAnswer((_) async => [_fanfouMessageWithUsers]);

        final result = await subject.getConversation(
          'user-b',
          limit: 20,
          page: 1,
        );

        expect(result.messages, const [_incomingMessage]);
        expect(result.hasMore, isFalse);
        expect(result.nextPage, isNull);
        verify(
          () => directMessagesApi.conversation('user-b', count: 20, page: 1),
        ).called(1);
        verify(() => fanfouClient.close()).called(1);
      });

      test(
        'keeps pagination available when the API returns a full page',
        () async {
          when(
            () => directMessagesApi.conversation('user-b', count: 2, page: 1),
          ).thenAnswer(
            (_) async => [_fanfouMessageWithUsers, _fanfouMessageWithoutUsers],
          );

          final result = await subject.getConversation(
            'user-b',
            limit: 2,
            page: 1,
          );

          expect(result.hasMore, isTrue);
          expect(result.nextPage, 2);
        },
      );

      test('requests the provided page and limit', () async {
        when(
          () => directMessagesApi.conversation('user-b', count: 5, page: 3),
        ).thenAnswer((_) async => const []);

        await subject.getConversation('user-b', limit: 5, page: 3);

        verify(
          () => directMessagesApi.conversation('user-b', count: 5, page: 3),
        ).called(1);
      });

      test('rejects an empty user id', () async {
        await expectLater(
          subject.getConversation(' ', limit: 20, page: 1),
          throwsA(isA<ArgumentError>()),
        );
        verifyNever(() => fanfouClient.directMessages);
      });

      test(
        'throws an API failure when Fanfou responds with an error',
        () async {
          when(
            () => directMessagesApi.conversation('user-b', count: 20, page: 1),
          ).thenThrow(fanfou.FanfouApiException(403, 'denied'));

          await expectLater(
            subject.getConversation('user-b', limit: 20, page: 1),
            throwsA(
              isA<DirectMessageRepositoryApiFailure>().having(
                (failure) => failure.statusCode,
                'statusCode',
                403,
              ),
            ),
          );
        },
      );
    });

    group('sendMessage', () {
      test(
        'returns the sent $DirectMessage when the API call succeeds',
        () async {
          when(
            () => directMessagesApi.send(user: 'user-b', text: '你好'),
          ).thenAnswer((_) async => _fanfouMessageWithUsers);

          final result = await subject.sendMessage('user-b', '你好');

          expect(result, _incomingMessage);
          verify(
            () => directMessagesApi.send(user: 'user-b', text: '你好'),
          ).called(1);
          verify(() => fanfouClient.close()).called(1);
        },
      );

      test('rejects an empty message without calling the API', () async {
        await expectLater(
          subject.sendMessage('user-b', ' '),
          throwsA(isA<ArgumentError>()),
        );
        verifyNever(() => fanfouClient.directMessages);
      });
    });

    group('deleteMessage', () {
      test('deletes the message when the API call succeeds', () async {
        when(
          () => directMessagesApi.destroy('dm-1'),
        ).thenAnswer((_) async => _fanfouMessageWithUsers);

        await subject.deleteMessage('dm-1');

        verify(() => directMessagesApi.destroy('dm-1')).called(1);
        verify(() => fanfouClient.close()).called(1);
      });

      test('rejects an empty id without calling the API', () async {
        await expectLater(
          subject.deleteMessage(' '),
          throwsA(isA<ArgumentError>()),
        );
        verifyNever(() => fanfouClient.directMessages);
      });

      test('maps API errors to a repository failure', () async {
        when(
          () => directMessagesApi.destroy('dm-1'),
        ).thenThrow(fanfou.FanfouApiException(403, 'denied'));

        await expectLater(
          subject.deleteMessage('dm-1'),
          throwsA(
            isA<DirectMessageRepositoryApiFailure>().having(
              (failure) => failure.statusCode,
              'statusCode',
              403,
            ),
          ),
        );
        verify(() => fanfouClient.close()).called(1);
      });

      test(
        'publishes a $DirectMessageDeleted change for the active account',
        () async {
          when(
            () => directMessagesApi.destroy('dm-1'),
          ).thenAnswer((_) async => _fanfouMessageWithUsers);

          final changes = <DirectMessageChange>[];
          final subscription = subject.messageChanges.listen(changes.add);
          addTearDown(subscription.cancel);

          await subject.deleteMessage('dm-1');
          await Future<void>.delayed(Duration.zero);

          expect(changes, const [
            DirectMessageDeleted(accountId: 'account-a', messageId: 'dm-1'),
          ]);
        },
      );

      test('skips publishing without an active account', () async {
        final subjectWithoutAccount = DirectMessageRepository(
          clientFactory: () async => fanfouClient,
          activeAccountIdProvider: () => null,
        );
        when(
          () => directMessagesApi.destroy('dm-1'),
        ).thenAnswer((_) async => _fanfouMessageWithUsers);

        final changes = <DirectMessageChange>[];
        final subscription = subjectWithoutAccount.messageChanges.listen(
          changes.add,
        );
        addTearDown(subscription.cancel);

        await subjectWithoutAccount.deleteMessage('dm-1');
        await Future<void>.delayed(Duration.zero);

        expect(changes, isEmpty);
      });
    });
  });
}

const _incomingMessage = DirectMessage(
  id: 'dm-1',
  text: '你好',
  createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
  senderId: 'user-b',
  recipientId: 'account-a',
  senderScreenName: 'fanfou_b',
);

const _conversation = DirectMessageConversation(
  otherUserId: 'user-b',
  lastMessage: _incomingMessage,
  messageCount: 12,
  hasUnread: true,
  otherUserScreenName: 'fanfou_b',
  otherUserAvatarUrl: 'https://example.com/user-b-large.png',
  otherUser: _peerDetails,
);

final _fanfouPeerUser = fanfou.User(
  id: 'user-b',
  name: '饭友 B',
  screenName: 'fanfou_b',
  profileImageUrl: 'https://example.com/user-b.png',
  profileImageUrlLarge: 'https://example.com/user-b-large.png',
  description: '对方简介',
  location: '上海',
  url: 'https://example.com/peer',
  protected: true,
  following: false,
  followersCount: 224,
  friendsCount: 178,
  favouritesCount: 135,
  statusesCount: 795,
  gender: '女',
  photoCount: 141,
  createdAt: 'Tue Apr 03 01:13:38 +0000 2012',
  birthday: '1990-12-02',
);

final _fanfouActiveUser = fanfou.User(
  id: 'account-a',
  name: 'Account',
  screenName: 'account',
);

final _fanfouMessageWithUsers = fanfou.DirectMessage(
  id: 'dm-1',
  createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
  text: '你好',
  senderId: 'user-b',
  recipientId: 'account-a',
  sender: _fanfouPeerUser,
  recipient: _fanfouActiveUser,
  senderScreenName: 'fanfou_b',
);

final _fanfouMessageWithoutUsers = fanfou.DirectMessage(
  id: 'dm-1',
  createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
  text: '你好',
  senderId: 'user-b',
  recipientId: 'account-a',
  senderScreenName: 'fanfou_b',
);

final _fanfouSummary = fanfou.ConversationSummary(
  dm: _fanfouMessageWithUsers,
  otherId: 'user-b',
  msgNum: 12,
  newConv: true,
);

const _peerDetails = DirectMessageUser(
  id: 'user-b',
  name: '饭友 B',
  screenName: 'fanfou_b',
  avatarUrl: 'https://example.com/user-b-large.png',
  description: '对方简介',
  location: '上海',
  url: 'https://example.com/peer',
  protected: true,
  following: false,
  followersCount: 224,
  friendsCount: 178,
  favoritesCount: 135,
  statusesCount: 795,
  gender: '女',
  photoCount: 141,
  createdAt: 'Tue Apr 03 01:13:38 +0000 2012',
  birthday: '1990-12-02',
);
