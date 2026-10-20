import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dan/app/widgets/widgets.dart';
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

    group('pagination retry', () {
      testWidgets(
        'retries failed pagination on upward drag without automatic retries',
        (tester) async {
          await pumpView(
            tester,
            const ConversationListState(
              status: ConversationListStatus.success,
              conversations: [_conversation],
              hasMore: true,
              nextPage: 2,
              loadMoreStatus: ConversationLoadMoreStatus.failure,
            ),
          );
          expect(find.byType(AppRetryView), findsNothing);
          verifyNever(
            () => bloc.add(const ConversationListLoadMoreRequested()),
          );
          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -200),
          );
          await tester.pump();
          verify(
            () => bloc.add(const ConversationListLoadMoreRequested()),
          ).called(greaterThan(0));
        },
      );
    });

    group('request failure feedback', () {
      for (final refresh in [true, false]) {
        for (final message in [null, '', '   ', ' 请求太频繁，请稍后再试 ']) {
          testWidgets(
            'shows no-action feedback for message=$message refresh=$refresh',
            (tester) async {
              const initial = ConversationListState(
                status: ConversationListStatus.success,
                conversations: [_conversation],
              );
              final states = StreamController<ConversationListState>();
              addTearDown(states.close);
              whenListen(bloc, states.stream, initialState: initial);
              await tester.pumpApp(
                BlocProvider.value(
                  value: bloc,
                  child: const Scaffold(body: ConversationListView()),
                ),
              );
              for (var attempt = 0; attempt < 2; attempt++) {
                states.add(
                  initial.copyWith(
                    refreshStatus: refresh
                        ? ConversationRefreshStatus.inProgress
                        : ConversationRefreshStatus.idle,
                    loadMoreStatus: refresh
                        ? ConversationLoadMoreStatus.idle
                        : ConversationLoadMoreStatus.inProgress,
                  ),
                );
                await tester.pump();
                states.add(
                  initial.copyWith(
                    refreshStatus: refresh
                        ? ConversationRefreshStatus.failure
                        : ConversationRefreshStatus.idle,
                    loadMoreStatus: refresh
                        ? ConversationLoadMoreStatus.idle
                        : ConversationLoadMoreStatus.failure,
                    failureMessage: message,
                  ),
                );
                await tester.pump();
                await tester.pump(const Duration(milliseconds: 300));
                expect(
                  find.text(
                    message?.trim().isNotEmpty == true
                        ? message!.trim()
                        : '很抱歉，出错了，请重试。',
                  ),
                  findsOneWidget,
                );
                expect(
                  tester.widget<SnackBar>(find.byType(SnackBar)).action,
                  isNull,
                );
                expect(find.byType(AppRetryView), findsNothing);
              }
            },
          );
        }
      }
    });

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
