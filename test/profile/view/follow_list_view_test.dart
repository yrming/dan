import 'package:bloc_test/bloc_test.dart';
import 'package:dan/app/navigation/navigation.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/profile/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_repository/user_repository.dart';

import '../../helpers/helpers.dart';

class _MockFollowListCubit extends MockCubit<FollowListState>
    implements FollowListCubit {}

void main() {
  group(FollowListView, () {
    late FollowListCubit cubit;
    late List<UserProfile> users;

    setUp(() {
      cubit = _MockFollowListCubit();
      users = List.generate(
        20,
        (i) => UserProfile(
          id: '$i',
          name: 'User $i',
          screenName: 'user$i',
        ),
      );
      when(() => cubit.toggleFollowing(any())).thenAnswer((_) async {});
      when(() => cubit.load()).thenAnswer((_) async {});
      when(() => cubit.loadMore()).thenAnswer((_) async {});
    });

    Future<void> pumpView(
      WidgetTester tester,
      FollowListState state, {
      bool followers = false,
      bool personal = false,
    }) async {
      when(() => cubit.state).thenReturn(state);
      await tester.pumpApp(
        BlocProvider.value(
          value: cubit,
          child: Scaffold(
            body: FollowListView(followers: followers, personal: personal),
          ),
        ),
      );
    }

    group('scroll', () {
      testWidgets('requests another page near the bottom', (tester) async {
        await pumpView(tester, FollowListState(users: users, loading: false));
        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -1600),
        );
        await tester.pump();
        verify(() => cubit.loadMore()).called(greaterThan(0));
      });
      testWidgets('supports pulling up a list shorter than the viewport', (
        tester,
      ) async {
        await pumpView(
          tester,
          FollowListState(users: users.take(2).toList(), loading: false),
        );
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
        await tester.pump();
        verify(() => cubit.loadMore()).called(greaterThan(0));
      });
      for (final mode in ['loading', 'failed', 'finished']) {
        testWidgets('does not load automatically while $mode', (tester) async {
          await pumpView(
            tester,
            FollowListState(
              users: users,
              loading: false,
              loadingMore: mode == 'loading',
              loadMoreError: mode == 'failed',
              hasMore: mode != 'finished',
            ),
          );
          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -1600),
          );
          await tester.pump();
          verifyNever(() => cubit.loadMore());
        });
      }
    });
    group('profile navigation', () {
      for (final target in ['avatar', 'name', 'description', 'button']) {
        testWidgets('handles tapping the $target', (tester) async {
          const user = UserProfile(
            id: 'peer',
            name: 'Nickname',
            screenName: 'peer',
            description: 'Biography',
          );
          when(() => cubit.state).thenReturn(
            FollowListState(
              users: const [user],
              loading: false,
              actions: const {'peer': FollowListAction.follow},
            ),
          );
          final router = GoRouter(
            initialLocation: '/list',
            routes: [
              GoRoute(
                path: '/list',
                builder: (_, _) => BlocProvider.value(
                  value: cubit,
                  child: const Scaffold(body: FollowListView(followers: false)),
                ),
              ),
              GoRoute(
                name: AppRouteName.userProfile,
                path: AppRoutePath.userProfile,
                builder: (_, state) => Scaffold(
                  body: Text('Profile ${state.pathParameters['userId']}'),
                ),
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpRouterApp(router);
          await tester.tap(switch (target) {
            'avatar' => find.byType(UserAvatar),
            'name' => find.text('Nickname'),
            'description' => find.text('Biography'),
            _ => find.byType(FilledButton),
          });
          await tester.pumpAndSettle(
            const Duration(milliseconds: 100),
            EnginePhase.sendSemanticsUpdate,
            const Duration(seconds: 5),
          );
          if (target == 'button') {
            expect(find.text('Profile peer'), findsNothing);
            verify(() => cubit.toggleFollowing('peer')).called(1);
          } else {
            expect(find.text('Profile peer'), findsOneWidget);
            expect(router.state.uri.queryParameters['presentation'], 'pushed');
            verifyNever(() => cubit.toggleFollowing(any()));
            router.pop();
            await tester.pumpAndSettle(
              const Duration(milliseconds: 100),
              EnginePhase.sendSemanticsUpdate,
              const Duration(seconds: 5),
            );
            expect(find.text('Nickname'), findsOneWidget);
          }
        });
      }
    });
    group('follow buttons', () {
      for (final (action, label) in [
        (FollowListAction.follow, '关注'),
        (FollowListAction.unfollow, '取关'),
        (FollowListAction.followBack, '回关'),
      ]) {
        testWidgets('shows $label and dispatches the user identifier', (
          tester,
        ) async {
          await pumpView(
            tester,
            FollowListState(
              users: users.take(1).toList(),
              loading: false,
              actions: {'0': action},
            ),
          );
          await tester.tap(find.text(label));
          await tester.pump();
          verify(() => cubit.toggleFollowing('0')).called(1);
        });
      }
      testWidgets('disables only the user being updated', (tester) async {
        await pumpView(
          tester,
          FollowListState(
            users: users.take(2).toList(),
            loading: false,
            actions: const {
              '0': FollowListAction.follow,
              '1': FollowListAction.unfollow,
            },
            updatingIds: const {'0'},
          ),
        );
        final buttons = tester
            .widgetList<FilledButton>(find.byType(FilledButton))
            .toList();
        expect(buttons[0].onPressed, isNull);
        expect(buttons[1].onPressed, isNotNull);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
      testWidgets('uses the compact fixed button size and rounded corners', (
        tester,
      ) async {
        await pumpView(
          tester,
          FollowListState(
            users: users.take(1).toList(),
            loading: false,
            actions: const {'0': FollowListAction.follow},
          ),
        );
        final finder = find.widgetWithText(FilledButton, '关注');
        final button = tester.widget<FilledButton>(finder);
        final context = tester.element(finder);
        final shape =
            button.style?.shape?.resolve({}) ??
            Theme.of(context).filledButtonTheme.style!.shape!.resolve({});

        expect(tester.getSize(finder), const Size(80, 34));
        expect(
          shape,
          const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        );
      });
      testWidgets('shows server feedback without changing the follow action', (
        tester,
      ) async {
        final initial = FollowListState(
          users: users.take(1).toList(),
          loading: false,
          actions: const {'0': FollowListAction.follow},
        );
        whenListen(
          cubit,
          Stream.fromIterable([
            initial.copyWith(
              actionFailureCount: 1,
              actionFailureMessage: '已向 小婴 发出关注请求，请等待确认。',
            ),
          ]),
          initialState: initial,
        );
        await pumpView(tester, initial);
        await tester.pump();
        expect(find.text('已向 小婴 发出关注请求，请等待确认。'), findsOneWidget);
        expect(find.text('操作失败，请重试'), findsNothing);
        expect(find.text('关注'), findsOneWidget);
      });
      testWidgets('shows a failure without changing the action', (
        tester,
      ) async {
        final initial = FollowListState(
          users: users.take(1).toList(),
          loading: false,
          actions: const {'0': FollowListAction.follow},
        );
        whenListen(
          cubit,
          Stream.fromIterable([initial.copyWith(actionFailureCount: 1)]),
          initialState: initial,
        );
        await pumpView(tester, initial);
        await tester.pump();
        expect(find.text('操作失败，请重试'), findsOneWidget);
        expect(find.text('关注'), findsOneWidget);
      });
    });
    group('render', () {
      testWidgets('shows a single-line description instead of the handle', (
        tester,
      ) async {
        final description = List.filled(50, '很长的用户描述').join();
        await pumpView(
          tester,
          FollowListState(
            users: [
              UserProfile(
                id: 'bio',
                name: 'Name',
                screenName: 'handle',
                description: description,
              ),
            ],
            loading: false,
          ),
        );
        expect(find.text(description), findsOneWidget);
        expect(find.text('handle'), findsNothing);
        final subtitle = tester.widget<Text>(find.text(description));
        expect(subtitle.maxLines, 1);
        expect(subtitle.overflow, TextOverflow.ellipsis);
        expect(tester.takeException(), isNull);
      });
      testWidgets('leaves the description empty when it is missing', (
        tester,
      ) async {
        await pumpView(
          tester,
          FollowListState(
            users: users.take(1).toList(),
            loading: false,
          ),
        );
        final tile = tester.widget<ListTile>(find.byType(ListTile));
        expect((tile.subtitle! as Text).data, isEmpty);
        expect(find.text('User 0'), findsOneWidget);
      });

      testWidgets('shows a thin divider below every user including the last', (
        tester,
      ) async {
        await pumpView(
          tester,
          FollowListState(
            users: users.take(3).toList(),
            loading: false,
          ),
        );
        expect(find.byType(ListTile), findsNWidgets(3));
        expect(find.byType(Divider), findsNWidgets(3));
      });
      testWidgets('preserves users and shows loading more at the bottom', (
        tester,
      ) async {
        await pumpView(
          tester,
          FollowListState(
            users: users.take(2).toList(),
            loading: false,
            loadingMore: true,
          ),
        );
        expect(find.text('User 0'), findsOneWidget);
        expect(find.byType(FollowListSkeleton), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });
      testWidgets('retries pagination without hiding existing users', (
        tester,
      ) async {
        await pumpView(
          tester,
          FollowListState(
            users: users.take(2).toList(),
            loading: false,
            loadMoreError: true,
          ),
        );
        expect(find.text('User 0'), findsOneWidget);
        expect(find.text('很抱歉，出错了，请重试。'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, '重试'));
        await tester.pump();
        verify(() => cubit.loadMore()).called(1);
      });
      testWidgets('retries initial loading', (tester) async {
        await pumpView(tester, FollowListState(loading: false, error: true));
        expect(find.text('很抱歉，出错了，请重试。'), findsOneWidget);
        await tester.tap(find.byType(FilledButton));
        await tester.pump();
        verify(() => cubit.load()).called(1);
      });
      for (final followers in [true, false]) {
        testWidgets('shows initial skeleton for followers=$followers', (
          tester,
        ) async {
          await pumpView(tester, FollowListState(), followers: followers);
          expect(find.byType(FollowListSkeleton), findsOneWidget);
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(find.byType(FilledButton), findsNothing);
        });
      }
      testWidgets('replaces the skeleton with loaded users', (tester) async {
        final initial = FollowListState();
        whenListen(
          cubit,
          Stream.fromIterable([
            FollowListState(users: users.take(2).toList(), loading: false),
          ]),
          initialState: initial,
        );
        await pumpView(tester, initial);
        expect(find.byType(FollowListSkeleton), findsOneWidget);
        await tester.pump();
        expect(find.byType(FollowListSkeleton), findsNothing);
        expect(find.text('User 0'), findsOneWidget);
      });
      for (final followers in [true, false]) {
        for (final personal in [true, false]) {
          testWidgets(
            'shows the empty message for followers=$followers '
            'and personal=$personal',
            (tester) async {
              await pumpView(
                tester,
                FollowListState(loading: false, hasMore: false),
                followers: followers,
                personal: personal,
              );
              expect(
                find.text(
                  personal
                      ? '你似季候风\n抵挡计划全也无用\n然后是场空'
                      : '这次季候风\n吹得格外凶\n仿佛世上一切\n已经消失所踪',
                ),
                findsOneWidget,
              );
            },
          );
        }
      }
      testWidgets('ends the list without a footer or pagination prompt', (
        tester,
      ) async {
        await pumpView(
          tester,
          FollowListState(
            users: users.take(2).toList(),
            loading: false,
            hasMore: false,
          ),
        );
        expect(find.bySemanticsLabel('没有更多了'), findsNothing);
        expect(find.text('没有更多了'), findsNothing);
        expect(find.text('上拉加载更多'), findsNothing);
        expect(find.text('有时候有时候我会相信一切有尽头'), findsNothing);
      });
    });
  });
}
