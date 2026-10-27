import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/blacklist/cubit/blacklist_cubit.dart';
import 'package:dan/blacklist/view/blacklist_view.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_repository/user_repository.dart';

import '../../helpers/helpers.dart';

class _MockBlacklistCubit extends MockCubit<BlacklistState>
    implements BlacklistCubit {}

void main() {
  group(BlacklistView, () {
    late BlacklistCubit cubit;

    setUp(() {
      cubit = _MockBlacklistCubit();
      when(() => cubit.state).thenReturn(
        const BlacklistState(
          status: BlacklistStatus.success,
          users: [_user],
          hasMore: false,
        ),
      );
      when(() => cubit.remove(_user.id)).thenAnswer((_) async {});
    });

    group('pagination retry', () {
      testWidgets(
        'retries a failed page on upward drag without a retry footer',
        (tester) async {
          when(() => cubit.state).thenReturn(
            const BlacklistState(
              status: BlacklistStatus.success,
              loadMoreError: true,
              users: [_user],
            ),
          );
          when(() => cubit.loadMore()).thenAnswer((_) async {});
          await tester.pumpApp(
            BlocProvider.value(
              value: cubit,
              child: const Scaffold(body: BlacklistView()),
            ),
          );
          expect(find.byType(AppRetryView), findsNothing);
          verifyNever(() => cubit.loadMore());
          await tester.drag(find.byType(ListView), const Offset(0, -200));
          await tester.pump();
          verify(() => cubit.loadMore()).called(greaterThan(0));
        },
      );
    });

    group('request failure feedback', () {
      for (final message in [null, '', '   ', ' 请求太频繁，请稍后再试 ']) {
        testWidgets('shows no-action feedback for message=$message ', (
          tester,
        ) async {
          const initial = BlacklistState(
            status: BlacklistStatus.success,
            users: [_user],
          );
          final states = StreamController<BlacklistState>();
          addTearDown(states.close);
          whenListen(cubit, states.stream, initialState: initial);
          await tester.pumpApp(
            BlocProvider.value(
              value: cubit,
              child: const Scaffold(body: BlacklistView()),
            ),
          );
          for (var attempt = 0; attempt < 2; attempt++) {
            states.add(initial.copyWith(loadingMore: true));
            await tester.pump();
            states.add(
              initial.copyWith(
                loadMoreError: true,
                requestFailureMessage: message,
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
          }
        });
      }
    });

    testWidgets('confirms before removing a user from the blacklist', (
      tester,
    ) async {
      await tester.pumpApp(
        BlocProvider.value(
          value: cubit,
          child: const Scaffold(body: BlacklistView()),
        ),
      );

      await tester.tap(find.text('移出'));
      await tester.pump();

      expect(find.text('移出黑名单？'), findsOneWidget);
      final context = tester.element(find.byType(BlacklistView));
      expect(
        find.text(
          context.l10n.confirmationDialogContent,
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('移出').last);
      await tester.pump();

      verify(() => cubit.remove(_user.id)).called(1);
    });

    testWidgets('shows the empty illustration when nobody is blocked', (
      tester,
    ) async {
      when(() => cubit.state).thenReturn(
        const BlacklistState(status: BlacklistStatus.success, hasMore: false),
      );

      await tester.pumpApp(
        BlocProvider.value(
          value: cubit,
          child: const Scaffold(body: BlacklistView()),
        ),
      );

      expect(find.byType(AppEmptyView), findsOneWidget);
      expect(find.byType(Text), findsNothing);
    });
  });
}

const _user = UserProfile(
  id: 'blocked-user',
  name: 'Blocked User',
  screenName: 'blocked',
);
