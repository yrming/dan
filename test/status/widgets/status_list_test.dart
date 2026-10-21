import 'dart:async';

import 'package:appearance_repository/appearance_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:dan/status/status.dart';
import 'package:dan/status/widgets/status_action_button.dart';
import 'package:dan/status/widgets/status_list_item.dart';
import 'package:flutter/cupertino.dart' show CupertinoSliverRefreshControl;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:status_repository/status_repository.dart' as status_repository;

import '../../helpers/helpers.dart';

class _MockStatusListBloc extends MockBloc<StatusListEvent, StatusListState>
    implements StatusListBloc {}

void main() {
  group(StatusList, () {
    late StatusListBloc statusListBloc;
    late StreamController<StatusListState> states;

    setUp(() {
      statusListBloc = _MockStatusListBloc();
      states = StreamController<StatusListState>.broadcast();
      when(() => statusListBloc.stream).thenAnswer((_) => states.stream);
    });

    tearDown(() async {
      await states.close();
    });

    Future<void> pumpStatusList(
      WidgetTester tester,
      StatusListState state, {
      AppearanceSettings appearance = const AppearanceSettings(),
      TargetPlatform platform = TargetPlatform.android,
      ThemeMode themeMode = ThemeMode.light,
      String routePath = '/home',
      bool personalEmpty = false,
    }) async {
      when(() => statusListBloc.state).thenReturn(state);
      final router = GoRouter(
        initialLocation: routePath,
        routes: [
          GoRoute(
            path: routePath,
            builder: (_, _) => Scaffold(
              body: BlocProvider.value(
                value: statusListBloc,
                child: StatusList(personalEmpty: personalEmpty),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpRouterApp(
        router,
        theme: AppTheme.light(
          appearance: appearance,
          platform: platform,
        ),
        darkTheme: AppTheme.dark(
          appearance: appearance,
          platform: platform,
        ),
        themeMode: themeMode,
      );
      await tester.pump();
    }

    for (final fails in [false, true]) {
      testWidgets('waits for the list deletion result with failure=$fails', (
        tester,
      ) async {
        final initial = StatusListState(
          status: StatusListStatus.success,
          statuses: [_status.copyWith(isSelf: true)],
          hasMore: false,
        );
        await pumpStatusList(tester, initial);
        final context = tester.element(find.byType(StatusList));
        await tester.tap(find.byType(StatusActionButton));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('status-delete-action')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(context.l10n.statusDeleteDialogConfirmLabel),
        );
        states.add(initial.copyWith(deletingStatusIds: {_status.id}));
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        verify(
          () =>
              statusListBloc.add(StatusListStatusDeletionRequested(_status.id)),
        ).called(1);
        states.add(
          initial.copyWith(
            actionFailure: fails
                ? StatusActionFailure(
                    statusId: _status.id,
                    action: StatusAction.delete,
                  )
                : null,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(
          find.byType(AppAlertDialog),
          fails ? findsOneWidget : findsNothing,
        );
        if (fails) {
          expect(find.text(context.l10n.statusDeleteFailure), findsOneWidget);
        }
      });
    }

    group('request failure feedback', () {
      for (final refresh in [true, false]) {
        for (final message in [null, '', '   ', ' 请求太频繁，请稍后再试 ']) {
          testWidgets(
            'shows no-action feedback for refresh=$refresh, message=$message',
            (tester) async {
              final initial = StatusListState(
                status: StatusListStatus.success,
                statuses: const [_status],
                hasMore: false,
              );
              await pumpStatusList(tester, initial);
              for (var attempt = 0; attempt < 2; attempt++) {
                states.add(
                  initial.copyWith(
                    refreshStatus: refresh
                        ? StatusRefreshStatus.inProgress
                        : StatusRefreshStatus.idle,
                    loadMoreStatus: refresh
                        ? StatusLoadMoreStatus.idle
                        : StatusLoadMoreStatus.inProgress,
                  ),
                );
                await tester.pump();
                states.add(
                  initial.copyWith(
                    refreshStatus: refresh
                        ? StatusRefreshStatus.failure
                        : StatusRefreshStatus.idle,
                    loadMoreStatus: refresh
                        ? StatusLoadMoreStatus.idle
                        : StatusLoadMoreStatus.failure,
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
                expect(find.byType(StatusListItem), findsOneWidget);
                expect(find.byType(AppRetryView), findsNothing);
              }
            },
          );
        }
      }
    });

    group('empty message', () {
      for (final personal in [true, false]) {
        testWidgets('shows the empty message for personal=$personal', (
          tester,
        ) async {
          await pumpStatusList(
            tester,
            StatusListState(status: StatusListStatus.empty),
            personalEmpty: personal,
          );

          expect(
            find.text(
              '这次季候风\n吹得格外凶\n仿佛世上一切\n已经消失所踪',
            ),
            findsOneWidget,
          );
          expect(find.byType(AppEmptyView), findsNothing);
        });
      }
    });

    group('no end indicator', () {
      for (final hasMore in [true, false]) {
        for (final loadMoreStatus in StatusLoadMoreStatus.values) {
          testWidgets(
            'hasMore=$hasMore and loadMoreStatus=$loadMoreStatus',
            (tester) async {
              await pumpStatusList(
                tester,
                StatusListState(
                  status: StatusListStatus.success,
                  statuses: const [_status],
                  hasMore: hasMore,
                  loadMoreStatus: loadMoreStatus,
                ),
              );
              expect(
                find.text('有时候有时候我会相信一切有尽头'),
                findsNothing,
              );
            },
          );
        }
      }
      for (final status in [
        StatusListStatus.loading,
        StatusListStatus.empty,
        StatusListStatus.failure,
      ]) {
        testWidgets('does not mark $status as exhausted content', (
          tester,
        ) async {
          await pumpStatusList(
            tester,
            StatusListState(status: status, hasMore: false),
          );
          expect(find.bySemanticsLabel('没有更多了'), findsNothing);
        });
      }
    });

    testWidgets(
      'keeps refreshing until the bloc completes a full refresh cycle',
      (tester) async {
        final state = StatusListState(
          status: StatusListStatus.success,
          statuses: const [_status],
          hasMore: false,
        );
        await pumpStatusList(tester, state);
        final refreshControl = tester.widget<CupertinoSliverRefreshControl>(
          find.byType(CupertinoSliverRefreshControl, skipOffstage: false),
        );

        var refreshCompleted = false;
        final refresh = refreshControl.onRefresh!().then((_) {
          refreshCompleted = true;
        });
        verify(
          () => statusListBloc.add(const StatusListRefreshRequested()),
        ).called(1);
        states.add(
          state.copyWith(loadMoreStatus: StatusLoadMoreStatus.failure),
        );
        await tester.pump();
        expect(refreshCompleted, isFalse);

        states.add(
          state.copyWith(refreshStatus: StatusRefreshStatus.inProgress),
        );
        await tester.pump(const Duration(milliseconds: 1000));
        expect(refreshCompleted, isFalse);

        states.add(state);
        await tester.pump();

        await refresh;
        expect(refreshCompleted, isTrue);
      },
    );

    testWidgets(
      'keeps the refresh indicator active for at least 1000 milliseconds',
      (tester) async {
        final state = StatusListState(
          status: StatusListStatus.success,
          statuses: const [_status],
          hasMore: false,
        );
        await pumpStatusList(tester, state);
        final refreshControl = tester.widget<CupertinoSliverRefreshControl>(
          find.byType(CupertinoSliverRefreshControl, skipOffstage: false),
        );

        var refreshCompleted = false;
        final refresh = refreshControl.onRefresh!().then((_) {
          refreshCompleted = true;
        });
        states
          ..add(
            state.copyWith(refreshStatus: StatusRefreshStatus.inProgress),
          )
          ..add(state);
        await tester.pump();

        await tester.pump(const Duration(milliseconds: 999));
        expect(refreshCompleted, isFalse);

        await tester.pump(const Duration(milliseconds: 1));
        await refresh;
        expect(refreshCompleted, isTrue);
      },
    );

    for (final hasMore in [true, false]) {
      testWidgets(
        'auto-fills a short first page only when more data is available: '
        '$hasMore',
        (tester) async {
          await pumpStatusList(
            tester,
            StatusListState(status: StatusListStatus.loading),
          );

          states.add(
            StatusListState(
              status: StatusListStatus.success,
              statuses: [
                _status,
                _status.copyWith(id: 'status-1', text: 'status 1'),
              ],
              hasMore: hasMore,
              nextCursor: hasMore ? 'cursor-a' : null,
            ),
          );
          await tester.pump();
          await tester.pump();

          if (hasMore) {
            verify(
              () => statusListBloc.add(const StatusListLoadMoreRequested()),
            ).called(greaterThanOrEqualTo(1));
          } else {
            verifyNever(
              () => statusListBloc.add(const StatusListLoadMoreRequested()),
            );
            expect(find.byType(StatusListSkeleton), findsNothing);
            expect(find.bySemanticsLabel('没有更多了'), findsNothing);
          }
        },
      );
    }

    testWidgets(
      'does not auto-fill when the first page already fills the viewport',
      (tester) async {
        final statuses = List<status_repository.Status>.generate(
          30,
          (index) => _status.copyWith(
            id: 'status-$index',
            text: 'status $index',
          ),
        );
        await pumpStatusList(
          tester,
          StatusListState(status: StatusListStatus.loading),
        );

        states.add(
          StatusListState(
            status: StatusListStatus.success,
            statuses: statuses,
            nextCursor: 'cursor-a',
          ),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump();

        verifyNever(
          () => statusListBloc.add(const StatusListLoadMoreRequested()),
        );
      },
    );

    testWidgets('dispatches load more when scrolling near the end', (
      tester,
    ) async {
      final statuses = List<status_repository.Status>.generate(
        30,
        (index) => _status.copyWith(
          id: 'status-$index',
          text: 'status $index',
        ),
      );
      await pumpStatusList(
        tester,
        StatusListState(
          status: StatusListStatus.success,
          statuses: statuses,
          nextCursor: 'cursor-a',
        ),
      );

      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -3000),
      );
      await tester.pump();

      verify(
        () => statusListBloc.add(const StatusListLoadMoreRequested()),
      ).called(greaterThanOrEqualTo(1));
    });

    testWidgets('retries failed pagination on another upward drag', (
      tester,
    ) async {
      await pumpStatusList(
        tester,
        StatusListState(
          status: StatusListStatus.success,
          loadMoreStatus: StatusLoadMoreStatus.failure,
          statuses: const [_status],
          nextCursor: 'cursor-a',
        ),
      );

      expect(find.byType(AppRetryView), findsNothing);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pump();

      verify(
        () => statusListBloc.add(const StatusListLoadMoreRequested()),
      ).called(greaterThan(0));
    });

    testWidgets(
      'shows pagination failure without a footer or automatic retry',
      (
        tester,
      ) async {
        final loading = StatusListState(
          status: StatusListStatus.success,
          loadMoreStatus: StatusLoadMoreStatus.inProgress,
          statuses: List.generate(
            20,
            (index) => _status.copyWith(id: '$index'),
          ),
          nextCursor: 'cursor-a',
        );
        await pumpStatusList(tester, loading);
        final scrollView = tester.widget<CustomScrollView>(
          find.byType(CustomScrollView),
        );
        final controller = scrollView.controller!;
        controller.jumpTo(controller.position.maxScrollExtent - 40);
        await tester.pump();
        clearInteractions(statusListBloc);

        final failure = loading.copyWith(
          loadMoreStatus: StatusLoadMoreStatus.failure,
        );
        when(() => statusListBloc.state).thenReturn(failure);
        states.add(failure);
        await tester.pump();
        await tester.pump();

        expect(find.byType(AppRetryView), findsNothing);
        expect(find.text('很抱歉，出错了，请重试。'), findsOneWidget);
        expect(tester.widget<SnackBar>(find.byType(SnackBar)).action, isNull);
        verifyNever(
          () => statusListBloc.add(const StatusListLoadMoreRequested()),
        );
      },
    );

    testWidgets(
      'shows one skeleton item while loading more statuses',
      (tester) async {
        await pumpStatusList(
          tester,
          StatusListState(
            status: StatusListStatus.success,
            loadMoreStatus: StatusLoadMoreStatus.inProgress,
            statuses: const [_status],
            nextCursor: 'cursor-a',
          ),
        );

        final skeleton = tester.widget<StatusListSkeleton>(
          find.byType(StatusListSkeleton),
        );

        expect(skeleton.itemCount, 1);
        expect(skeleton.shrinkWrap, isTrue);
        expect(find.byType(ShaderMask), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    testWidgets('shows animated skeleton items during the initial load', (
      tester,
    ) async {
      await pumpStatusList(
        tester,
        StatusListState(status: StatusListStatus.loading),
      );

      final initialMask = tester.widget<ShaderMask>(find.byType(ShaderMask));
      await tester.pump(Durations.medium2);
      final updatedMask = tester.widget<ShaderMask>(find.byType(ShaderMask));

      expect(find.byType(StatusListSkeleton), findsOneWidget);
      expect(find.text('加载中'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(updatedMask, isNot(same(initialMask)));
    });

    testWidgets('uses dark skeleton colors in dark mode', (tester) async {
      await pumpStatusList(
        tester,
        StatusListState(status: StatusListStatus.loading),
        themeMode: ThemeMode.dark,
      );

      final coloredBoxes = tester.widgetList<ColoredBox>(
        find.descendant(
          of: find.byType(StatusListSkeleton),
          matching: find.byType(ColoredBox),
        ),
      );

      expect(coloredBoxes, isNotEmpty);
      expect(
        coloredBoxes.every(
          (box) => box.color == AppColors.danDark.skeletonBase,
        ),
        isTrue,
      );
    });

    testWidgets('stops shimmer when animations are disabled', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      await pumpStatusList(
        tester,
        StatusListState(status: StatusListStatus.loading),
      );

      expect(find.byType(StatusListSkeleton), findsOneWidget);
      expect(find.byType(ShaderMask), findsNothing);
    });

    testWidgets('renders an attached photo below the status text', (
      tester,
    ) async {
      await pumpStatusList(
        tester,
        StatusListState(
          status: StatusListStatus.success,
          statuses: const [_statusWithPhoto],
          hasMore: false,
        ),
      );

      final photo = tester.widget<StatusPhoto>(find.byType(StatusPhoto));

      expect(find.text(_statusWithPhoto.text), findsOneWidget);
      expect(find.byType(WeChatStatusListItem), findsOneWidget);
      expect(photo.imageUrl, 'https://example.com/status-photo-large.png');
      expect(photo.style, StatusPhotoStyle.x);
      expect(
        photo.heroTag,
        'status-photo-home-${_statusWithPhoto.id}-'
        'https://example.com/status-photo-large.png',
      );
      expect(find.byType(StatusActionButton), findsOneWidget);
    });

    testWidgets('dispatches a favorite toggle from the status action sheet', (
      tester,
    ) async {
      await pumpStatusList(
        tester,
        StatusListState(
          status: StatusListStatus.success,
          statuses: const [_status],
          hasMore: false,
        ),
      );

      await tester.tap(find.byType(StatusActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('status-favorite-action')));
      await tester.pumpAndSettle();

      verify(
        () => statusListBloc.add(
          const StatusListStatusFavoriteToggled('status-a'),
        ),
      ).called(1);
    });

    testWidgets('shows a snackbar after a favorite succeeds', (tester) async {
      final initial = StatusListState(
        status: StatusListStatus.success,
        statuses: const [_status],
        hasMore: false,
      );
      await pumpStatusList(tester, initial);
      await tester.tap(find.byType(StatusActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('status-favorite-action')));
      states.add(
        initial.copyWith(
          favoriteSuccess: const StatusFavoriteSuccess(
            statusId: 'status-a',
            isFavorited: true,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('已收藏'), findsOneWidget);
    });

    testWidgets(
      'uses the current route as the status photo Hero scope',
      (tester) async {
        await pumpStatusList(
          tester,
          StatusListState(
            status: StatusListStatus.success,
            statuses: const [_statusWithPhoto],
            hasMore: false,
          ),
          routePath: '/mentions',
        );

        final photo = tester.widget<StatusPhoto>(find.byType(StatusPhoto));

        expect(
          photo.heroTag,
          'status-photo-mentions-${_statusWithPhoto.id}-'
          'https://example.com/status-photo-large.png',
        );
      },
    );

    testWidgets('uses the primary text color for the status author', (
      tester,
    ) async {
      await pumpStatusList(
        tester,
        StatusListState(
          status: StatusListStatus.success,
          statuses: const [_status],
          hasMore: false,
        ),
      );

      final author = tester.widget<Text>(find.text(_status.author.name));

      expect(author.style?.color, AppColors.danLight.textBase);
    });

    testWidgets('does not render the author screen name in status metadata', (
      tester,
    ) async {
      await pumpStatusList(
        tester,
        StatusListState(
          status: StatusListStatus.success,
          statuses: const [_status],
          hasMore: false,
        ),
      );

      expect(
        find.textContaining('@${_status.author.screenName}'),
        findsNothing,
      );
    });

    testWidgets('uses the small photo style when selected', (
      tester,
    ) async {
      await pumpStatusList(
        tester,
        StatusListState(
          status: StatusListStatus.success,
          statuses: const [_statusWithPhoto],
          hasMore: false,
        ),
        appearance: const AppearanceSettings(
          statusPhotoStyle: StatusPhotoStyle.wechat,
        ),
      );

      expect(find.byType(WeChatStatusListItem), findsOneWidget);
      expect(
        tester.widget<StatusPhoto>(find.byType(StatusPhoto)).style,
        StatusPhotoStyle.wechat,
      );
    });

    testWidgets('formats Fanfou created at values as a readable Chinese date', (
      tester,
    ) async {
      const status = status_repository.Status(
        id: 'fanfou-status',
        text: 'fanfou time',
        createdAt: 'Tue Jul 28 00:00:00 +0000 2025',
        author: status_repository.StatusAuthor(
          id: 'user-fanfou',
          name: 'Fanfou User',
          screenName: 'fanfou_user',
        ),
      );
      await pumpStatusList(
        tester,
        StatusListState(
          status: StatusListStatus.success,
          statuses: const [status],
          hasMore: false,
        ),
      );

      expect(find.textContaining('2025年7月28日'), findsOneWidget);
      expect(find.textContaining(status.createdAt), findsNothing);
    });

    testWidgets('formats ISO created at values as a readable Chinese date', (
      tester,
    ) async {
      const status = status_repository.Status(
        id: 'iso-status',
        text: 'iso time',
        createdAt: '2025-07-28T00:00:00Z',
        author: status_repository.StatusAuthor(
          id: 'user-iso',
          name: 'ISO User',
          screenName: 'iso_user',
        ),
      );
      await pumpStatusList(
        tester,
        StatusListState(
          status: StatusListStatus.success,
          statuses: const [status],
          hasMore: false,
        ),
      );

      expect(find.textContaining('2025年7月28日'), findsOneWidget);
    });

    testWidgets('keeps an empty feed pull-to-refreshable', (tester) async {
      await pumpStatusList(
        tester,
        StatusListState(
          status: StatusListStatus.empty,
          hasMore: false,
        ),
      );

      expect(
        find.byType(CupertinoSliverRefreshControl, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.byType(RefreshIndicator), findsNothing);
      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(
        tester.widget<CustomScrollView>(find.byType(CustomScrollView)).physics,
        isA<BouncingScrollPhysics>(),
      );
    });

    testWidgets(
      'uses a Cupertino sliver refresh control and bouncing physics on Android',
      (tester) async {
        final state = StatusListState(
          status: StatusListStatus.success,
          statuses: const [_status],
          hasMore: false,
        );
        await pumpStatusList(tester, state);

        expect(
          Theme.of(tester.element(find.byType(StatusList))).platform,
          TargetPlatform.android,
        );
        final refreshControlFinder = find.byType(
          CupertinoSliverRefreshControl,
          skipOffstage: false,
        );
        expect(refreshControlFinder, findsOneWidget);
        expect(find.byType(RefreshIndicator), findsNothing);
        final refreshControl = tester.widget<CupertinoSliverRefreshControl>(
          refreshControlFinder,
        );
        final refresh = refreshControl.onRefresh!();
        verify(
          () => statusListBloc.add(const StatusListRefreshRequested()),
        ).called(1);
        states
          ..add(
            state.copyWith(refreshStatus: StatusRefreshStatus.inProgress),
          )
          ..add(state);
        await tester.pump(const Duration(milliseconds: 1000));
        await refresh;

        final physics = tester
            .widget<CustomScrollView>(find.byType(CustomScrollView))
            .physics;
        expect(physics, isA<BouncingScrollPhysics>());
        expect(physics?.parent, isA<AlwaysScrollableScrollPhysics>());
      },
    );
  });
}

const _status = status_repository.Status(
  id: 'status-a',
  text: 'hello',
  createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
  author: status_repository.StatusAuthor(
    id: 'user-a',
    name: 'User A',
    screenName: 'user_a',
  ),
);

const _statusWithPhoto = status_repository.Status(
  id: 'status-with-photo',
  text: '许愿躲打下次见面',
  createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
  photo: status_repository.StatusPhotoUrls(
    thumbnailUrl: 'https://example.com/status-photo-thumb.png',
    imageUrl: 'https://example.com/status-photo.png',
    largeUrl: 'https://example.com/status-photo-large.png',
  ),
  author: status_repository.StatusAuthor(
    id: 'user-photo',
    name: '青妖姬',
    screenName: 'photo_user',
  ),
);
