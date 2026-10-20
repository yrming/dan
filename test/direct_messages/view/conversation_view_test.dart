import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/direct_messages/cubit/cubit.dart';
import 'package:dan/direct_messages/view/conversation_view.dart';
import 'package:direct_message_repository/direct_message_repository.dart';
import 'package:flutter/material.dart';
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
              expect(
                tester.widget<SnackBar>(find.byType(SnackBar)).action,
                isNull,
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
    });
  });
}
