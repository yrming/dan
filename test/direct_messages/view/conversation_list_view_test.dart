import 'package:bloc_test/bloc_test.dart';
import 'package:dan/direct_messages/direct_messages.dart';
import 'package:direct_message_repository/direct_message_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';

class _MockConversationListBloc
    extends MockBloc<ConversationListEvent, ConversationListState>
    implements ConversationListBloc {}

void main() {
  group(ConversationListView, () {
    late ConversationListBloc bloc;

    setUp(() => bloc = _MockConversationListBloc());

    Future<void> pumpView(
      WidgetTester tester,
      ConversationListState state,
    ) async {
      when(() => bloc.state).thenReturn(state);
      await tester.pumpApp(
        BlocProvider.value(
          value: bloc,
          child: const Scaffold(body: ConversationListView()),
        ),
      );
    }

    group('no end indicator', () {
      for (final hasMore in [true, false]) {
        for (final loadMoreStatus in ConversationLoadMoreStatus.values) {
          testWidgets('hasMore=$hasMore and loadMoreStatus=$loadMoreStatus', (
            tester,
          ) async {
            await pumpView(
              tester,
              ConversationListState(
                status: ConversationListStatus.success,
                conversations: const [_conversation],
                hasMore: hasMore,
                loadMoreStatus: loadMoreStatus,
              ),
            );
            expect(
              find.text('有时候有时候我会相信一切有尽头'),
              findsNothing,
            );
          });
        }
      }
      for (final status in [
        ConversationListStatus.loading,
        ConversationListStatus.empty,
        ConversationListStatus.failure,
      ]) {
        testWidgets('does not mark $status as exhausted content', (
          tester,
        ) async {
          await pumpView(tester, ConversationListState(status: status));
          expect(find.bySemanticsLabel('没有更多了'), findsNothing);
        });
      }
    });
  });
}

const _conversation = DirectMessageConversation(
  otherUserId: 'peer',
  otherUserScreenName: 'Peer',
  messageCount: 1,
  hasUnread: false,
  lastMessage: DirectMessage(
    id: 'message',
    text: 'Hello',
    createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
    senderId: 'peer',
    recipientId: 'me',
  ),
);
