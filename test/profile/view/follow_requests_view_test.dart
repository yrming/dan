import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/profile/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_repository/user_repository.dart';

import '../../helpers/helpers.dart';

class _MockFollowRequestsCubit extends MockCubit<FollowRequestsState>
    implements FollowRequestsCubit {}

void main() {
  group(FollowRequestsView, () {
    late FollowRequestsCubit cubit;

    setUp(() {
      cubit = _MockFollowRequestsCubit();
    });

    group('pagination retry', () {
      testWidgets(
        'retries a failed page on upward drag without a retry footer',
        (tester) async {
          when(() => cubit.state).thenReturn(
            FollowRequestsState(
              loading: false,
              loadMoreError: true,
              users: const [
                UserProfile(id: 'user', name: 'Name', screenName: 'screen'),
              ],
            ),
          );
          when(() => cubit.loadMore()).thenAnswer((_) async {});
          await tester.pumpApp(
            BlocProvider.value(
              value: cubit,
              child: const Scaffold(body: FollowRequestsView()),
            ),
          );
          expect(find.byType(AppRetryView), findsNothing);
          verifyNever(() => cubit.loadMore());
          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -200),
          );
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
          final initial = FollowRequestsState(
            loading: false,
            users: const [
              UserProfile(id: 'user', name: 'Name', screenName: 'screen'),
            ],
          );
          final states = StreamController<FollowRequestsState>();
          addTearDown(states.close);
          whenListen(cubit, states.stream, initialState: initial);
          await tester.pumpApp(
            BlocProvider.value(
              value: cubit,
              child: const Scaffold(body: FollowRequestsView()),
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
            expect(
              tester.widget<SnackBar>(find.byType(SnackBar)).action,
              isNull,
            );
            expect(find.byType(AppRetryView), findsNothing);
          }
        });
      }
    });

    group('empty message', () {
      testWidgets('shows the empty illustration when there are no requests', (
        tester,
      ) async {
        when(() => cubit.state).thenReturn(
          FollowRequestsState(loading: false, hasMore: false),
        );
        await tester.pumpApp(
          BlocProvider.value(
            value: cubit,
            child: const Scaffold(body: FollowRequestsView()),
          ),
        );

        expect(find.byType(AppEmptyView), findsOneWidget);
        expect(
          find.text('这次季候风\n吹得格外凶\n仿佛世上一切\n已经消失所踪'),
          findsNothing,
        );
      });
    });

    group('request list items', () {
      testWidgets('does not show a splash when the item is tapped', (
        tester,
      ) async {
        when(() => cubit.state).thenReturn(
          FollowRequestsState(
            users: const [
              UserProfile(id: 'user', name: 'Name', screenName: 'screen'),
            ],
            loading: false,
            hasMore: false,
          ),
        );
        await tester.pumpApp(
          BlocProvider.value(
            value: cubit,
            child: const Scaffold(body: FollowRequestsView()),
          ),
        );

        final tile = tester.widget<ListTile>(find.byType(ListTile));

        expect(
          tile.splashColor ??
              Theme.of(tester.element(find.byType(ListTile))).splashColor,
          AppColors.transparent,
        );
      });
    });
  });
}
