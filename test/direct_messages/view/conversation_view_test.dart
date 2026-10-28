import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/direct_messages/cubit/cubit.dart';
import 'package:dan/direct_messages/view/conversation_view.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:direct_message_repository/direct_message_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';

class _MockConversationCubit extends MockCubit<ConversationState>
    implements ConversationCubit {}

void main() {
  group(ConversationView, () {
    late ConversationCubit cubit;
    late StreamController<ConversationState> states;

    setUp(() {
      cubit = _MockConversationCubit();
      states = StreamController<ConversationState>();
      when(() => cubit.loadMore()).thenAnswer((_) async {});
    });

    tearDown(() async => states.close());

    group('history failure feedback', () {
      for (final message in [null, '', '   ', ' 请求太频繁，请稍后再试 ']) {
        testWidgets(
          'preserves messages and shows no-action feedback '
          'for message=$message',
          (tester) async {
            final initial = ConversationLoadSuccess(
              messages: List.generate(
                30,
                (index) => DirectMessage(
                  id: 'message-$index',
                  text: 'Message $index',
                  createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
                  senderId: 'peer',
                  recipientId: 'me',
                ),
              ),
              hasMore: true,
              nextPage: 2,
            );
            whenListen(cubit, states.stream, initialState: initial);
            await tester.pumpApp(
              BlocProvider.value(
                value: cubit,
                child: const ConversationView(activeAccountId: 'me'),
              ),
            );
            for (var attempt = 0; attempt < 2; attempt++) {
              states.add(
                initial.copyWith(
                  historyLoadStatus: ConversationHistoryLoadStatus.inProgress,
                ),
              );
              await tester.pump();
              states.add(
                initial.copyWith(
                  historyLoadStatus: ConversationHistoryLoadStatus.failure,
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
              expect(find.byType(AppRetryView), findsNothing);
              expect(find.text('Message 0'), findsOneWidget);
            }
            verifyNever(() => cubit.loadMore());
            final scrollable = tester.state<ScrollableState>(
              find.byType(Scrollable).first,
            );
            scrollable.position.jumpTo(
              scrollable.position.maxScrollExtent - 40,
            );
            await tester.pump();
            await tester.drag(find.byType(ListView), const Offset(0, 200));
            await tester.pump();
            verify(() => cubit.loadMore()).called(greaterThan(0));
          },
        );
      }
      testWidgets('does not show failure feedback on a successful load', (
        tester,
      ) async {
        whenListen(
          cubit,
          states.stream,
          initialState: const ConversationLoadInProgress(),
        );
        await tester.pumpApp(
          BlocProvider.value(
            value: cubit,
            child: const ConversationView(activeAccountId: 'me'),
          ),
        );

        states.add(
          ConversationLoadSuccess(
            messages: List.generate(
              1,
              (index) => DirectMessage(
                id: 'message-$index',
                text: 'Message $index',
                createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
                senderId: 'peer',
                recipientId: 'me',
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('很抱歉，出错了，请重试。'), findsNothing);
        expect(find.text('Message 0'), findsOneWidget);
      });
    });

    group('message actions', () {
      const sentMessage = DirectMessage(
        id: 'message-sent',
        text: 'Sent message',
        createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
        senderId: 'me',
        recipientId: 'peer',
      );
      const receivedMessage = DirectMessage(
        id: 'message-received',
        text: 'Received message',
        createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
        senderId: 'peer',
        recipientId: 'me',
      );

      testWidgets('copies the message text from the long-press sheet', (
        tester,
      ) async {
        Object? clipboardText;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              clipboardText = (call.arguments as Map?)?['text'];
            }
            return null;
          },
        );
        whenListen(
          cubit,
          states.stream,
          initialState: const ConversationLoadSuccess(
            messages: [sentMessage],
          ),
        );
        await tester.pumpApp(
          BlocProvider.value(
            value: cubit,
            child: const ConversationView(activeAccountId: 'me'),
          ),
        );

        await tester.longPress(find.text('Sent message'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('direct-message-copy-action')));
        await tester.pumpAndSettle();

        expect(clipboardText, 'Sent message');
        final context = tester.element(find.byType(ConversationView));
        expect(find.text(context.l10n.statusTextCopied), findsOneWidget);
      });

      testWidgets('offers delete for sent and received messages', (
        tester,
      ) async {
        when(() => cubit.deleteMessage(any())).thenAnswer((_) async {});
        whenListen(
          cubit,
          states.stream,
          initialState: const ConversationLoadSuccess(
            messages: [sentMessage, receivedMessage],
          ),
        );
        await tester.pumpApp(
          BlocProvider.value(
            value: cubit,
            child: const ConversationView(activeAccountId: 'me'),
          ),
        );

        await tester.longPress(find.text('Received message'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('direct-message-delete-action')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('direct-message-delete-action')));
        await tester.pumpAndSettle();
        verify(() => cubit.deleteMessage('message-received')).called(1);

        await tester.longPress(find.text('Sent message'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('direct-message-delete-action')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('direct-message-delete-action')));
        await tester.pumpAndSettle();
        verify(() => cubit.deleteMessage('message-sent')).called(1);
      });
    });
  });
}
