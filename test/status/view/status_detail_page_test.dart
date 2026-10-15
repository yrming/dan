import 'dart:async';

import 'package:appearance_repository/appearance_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:dan/status/status.dart';
import 'package:dan/status/widgets/status_action_button.dart';
import 'package:dan/status/widgets/status_context_reply.dart';
import 'package:dan/status/widgets/status_detail_skeleton.dart';
import 'package:dan/status/widgets/status_list_item.dart';
import 'package:dan/status/widgets/status_list_item_tap_target.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:status_repository/status_repository.dart' as status_repository;
import 'package:user_repository/user_repository.dart';

import '../../helpers/helpers.dart';

class _MockStatusRepository extends Mock
    implements status_repository.StatusRepository {}

class _MockStatusDetailCubit extends MockCubit<StatusDetailState>
    implements StatusDetailCubit {}

class _MockUserRepository extends Mock implements UserRepository {}

void main() {
  group(StatusDetailView, () {
    late StatusDetailCubit cubit;

    setUp(() {
      cubit = _MockStatusDetailCubit();
      when(() => cubit.state).thenReturn(
        StatusDetailState(
          status: StatusDetailStatus.success,
          statusDetail: _status,
        ),
      );
      when(() => cubit.retry()).thenAnswer((_) async {});
    });

    Future<void> pumpStatusDetailView(
      WidgetTester tester, {
      AppearanceSettings appearance = const AppearanceSettings(),
    }) async {
      await tester.pumpApp(
        BlocProvider<StatusDetailCubit>.value(
          value: cubit,
          child: StatusDetailView(
            userId: _status.author.id,
            statusId: _status.id,
          ),
        ),
        theme: AppTheme.light(appearance: appearance),
        themeMode: ThemeMode.light,
      );
      await tester.pump();
    }

    testWidgets(
      'waits for deletion before dismissing the dialog and detail page',
      (tester) async {
        final repository = _MockStatusRepository();
        final request = Completer<void>();
        when(
          () => repository.getContextTimeline(any()),
        ).thenAnswer((_) async => []);
        when(
          () => repository.deleteStatus(_status.id),
        ).thenAnswer((_) => request.future);
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(body: Text('previous page')),
            ),
            GoRoute(
              path: '/detail',
              builder: (_, _) => MultiRepositoryProvider(
                providers: [
                  RepositoryProvider<status_repository.StatusRepository>.value(
                    value: repository,
                  ),
                  RepositoryProvider<UserRepository>.value(
                    value: _MockUserRepository(),
                  ),
                ],
                child: StatusDetailPage(
                  userId: _status.author.id,
                  statusId: _status.id,
                  initialStatus: _status.copyWith(isSelf: true),
                ),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpRouterApp(router);
        unawaited(router.push<void>('/detail'));
        await tester.pumpTransition();
        final context = tester.element(find.byType(StatusDetailView));
        await tester.ensureVisible(find.byType(StatusActionButton));
        await tester.pump();
        await tester.tap(
          find.byKey(const Key('wechat-status-action-hit-target')),
        );
        await tester.pumpTransition();
        await tester.tap(find.byKey(const Key('status-delete-action')));
        await tester.pumpTransition();
        await tester.tap(
          find.text(context.l10n.statusDeleteDialogConfirmLabel),
        );
        await tester.pump();
        expect(find.byType(AppAlertDialog), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(router.state.uri.path, '/detail');
        verify(() => repository.deleteStatus(_status.id)).called(1);

        request.complete();
        await tester.pumpTransition();
        expect(find.byType(AppAlertDialog), findsNothing);
        expect(find.byType(StatusDetailPage), findsNothing);
        expect(find.text('previous page'), findsOneWidget);
      },
    );

    group('reply loading', () {
      for (final loadingStatus in [
        StatusDetailStatus.initial,
        StatusDetailStatus.loading,
      ]) {
        testWidgets('shows both skeleton regions for $loadingStatus context', (
          tester,
        ) async {
          final semantics = tester.ensureSemantics();
          when(() => cubit.state).thenReturn(
            StatusDetailState(
              status: StatusDetailStatus.success,
              statusDetail: _status.copyWith(inReplyToStatusId: 'original'),
              contextStatus: loadingStatus,
            ),
          );
          await pumpStatusDetailView(tester);

          expect(find.byType(StatusDetailSkeleton), findsOneWidget);
          expect(find.bySemanticsLabel('正在加载动态详情'), findsOneWidget);
          expect(find.bySemanticsLabel('正在加载上下文'), findsOneWidget);
          expect(find.byType(StatusListItem), findsNothing);
          expect(find.text(_status.text), findsNothing);
          expect(find.byType(StatusActionButton), findsNothing);
          semantics.dispose();
        });
      }

      for (final parentId in [null, '']) {
        testWidgets('keeps an original with parent=$parentId visible', (
          tester,
        ) async {
          when(() => cubit.state).thenReturn(
            StatusDetailState(
              status: StatusDetailStatus.success,
              statusDetail: _status.copyWith(inReplyToStatusId: parentId),
              contextStatus: StatusDetailStatus.loading,
            ),
          );
          await pumpStatusDetailView(tester);

          expect(find.byType(StatusDetailSkeleton), findsNothing);
          expect(find.text(_status.text), findsOneWidget);
        });
      }

      testWidgets(
        'replaces the skeleton with original and replies on success',
        (tester) async {
          final reply = _status.copyWith(
            id: 'reply',
            text: 'reply body',
            photo: null,
            inReplyToStatusId: _status.id,
          );
          final updates = StreamController<StatusDetailState>();
          addTearDown(updates.close);
          whenListen(
            cubit,
            updates.stream,
            initialState: StatusDetailState(
              status: StatusDetailStatus.success,
              statusDetail: reply,
              contextStatus: StatusDetailStatus.loading,
            ),
          );
          await pumpStatusDetailView(tester);
          expect(find.byType(StatusDetailSkeleton), findsOneWidget);

          final loaded = StatusDetailState(
            status: StatusDetailStatus.success,
            statusDetail: _status.copyWith(photo: null),
            contextStatus: StatusDetailStatus.success,
            replies: [reply],
          );
          updates.add(loaded);
          await tester.pump();
          expect(find.byType(StatusDetailSkeleton), findsNothing);
          expect(find.text(_status.text), findsOneWidget);
          expect(
            find.text('User A: reply body', findRichText: true),
            findsOneWidget,
          );

          updates.add(
            loaded.copyWith(contextStatus: StatusDetailStatus.loading),
          );
          await tester.pump();
          expect(find.byType(StatusDetailSkeleton), findsNothing);
          expect(find.text(_status.text), findsOneWidget);
          expect(find.byType(StatusContextReply), findsOneWidget);
          expect(find.text('正在加载上下文'), findsNothing);
        },
      );

      testWidgets(
        'leaves the skeleton on failure and shows it again on retry',
        (tester) async {
          final loading = StatusDetailState(
            status: StatusDetailStatus.success,
            statusDetail: _status.copyWith(
              photo: null,
              inReplyToStatusId: 'original',
            ),
            contextStatus: StatusDetailStatus.loading,
          );
          final updates = StreamController<StatusDetailState>();
          addTearDown(updates.close);
          whenListen(cubit, updates.stream, initialState: loading);
          when(
            () => cubit.retry(),
          ).thenAnswer((_) async => updates.add(loading));
          await pumpStatusDetailView(tester);

          updates.add(
            loading.copyWith(contextStatus: StatusDetailStatus.failure),
          );
          await tester.pump();
          expect(find.byType(StatusDetailSkeleton), findsNothing);
          expect(find.text('无法加载上下文，请重试。'), findsOneWidget);
          await tester.tap(find.byType(FilledButton));
          await tester.pump();
          verify(() => cubit.retry()).called(1);
          expect(find.byType(StatusDetailSkeleton), findsOneWidget);

          updates.add(
            loading.copyWith(
              contextStatus: StatusDetailStatus.success,
              originUnavailable: true,
              replies: [loading.statusDetail!],
            ),
          );
          await tester.pump();
          expect(find.byType(StatusDetailSkeleton), findsNothing);
          expect(find.text('原消息已删除或不公开'), findsOneWidget);
          expect(find.byType(StatusContextReply), findsOneWidget);
        },
      );
    });

    group('conversation', () {
      for (final tapAvatar in [false, true]) {
        testWidgets(
          'opens unavailable original author with tapAvatar=$tapAvatar',
          (tester) async {
            final userRepository = _MockUserRepository();
            when(() => cubit.state).thenReturn(
              StatusDetailState(
                status: StatusDetailStatus.success,
                statusDetail: _unavailableStatus,
                originUnavailable: true,
                contextStatus: StatusDetailStatus.success,
              ),
            );
            final router = GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, _) => RepositoryProvider<UserRepository>.value(
                    value: userRepository,
                    child: Scaffold(
                      body: BlocProvider<StatusDetailCubit>.value(
                        value: cubit,
                        child: const StatusDetailView(
                          userId: 'reply-author',
                          statusId: 'reply',
                        ),
                      ),
                    ),
                  ),
                ),
                GoRoute(
                  path: '/users/:userId',
                  name: 'user-profile',
                  builder: (_, state) =>
                      Scaffold(body: Text(state.pathParameters['userId']!)),
                ),
              ],
            );
            addTearDown(router.dispose);
            await tester.pumpRouterApp(router);
            await tester.tap(
              tapAvatar
                  ? find.byType(UserAvatar)
                  : find.text('Original Author'),
            );
            await tester.pumpTransition();
            expect(router.state.uri.path, '/users/origin-author');
          },
        );
      }

      testWidgets(
        'removes a deleted reply while keeping the original visible',
        (tester) async {
          final reply = _status.copyWith(
            id: 'reply',
            text: 'my reply',
            photo: null,
            isSelf: true,
            inReplyToStatusId: _status.id,
          );
          final state = StatusDetailState(
            status: StatusDetailStatus.success,
            statusDetail: _status.copyWith(photo: null),
            replies: [reply],
            contextStatus: StatusDetailStatus.success,
          );
          final updates = StreamController<StatusDetailState>();
          addTearDown(updates.close);
          whenListen(cubit, updates.stream, initialState: state);
          when(() => cubit.deleteReply(reply.id)).thenAnswer((_) async {
            updates.add(state.copyWith(replies: []));
          });
          await pumpStatusDetailView(tester);
          await tester.tap(find.byType(StatusContextReply));
          await tester.pumpTransition();
          await tester.tap(find.byKey(const Key('status-delete-action')));
          await tester.pumpTransition();
          final context = tester.element(find.byType(StatusDetailView));
          await tester.tap(
            find.text(context.l10n.statusDeleteDialogConfirmLabel),
          );
          await tester.pumpTransition();

          verify(() => cubit.deleteReply(reply.id)).called(1);
          expect(find.byType(StatusContextReply), findsNothing);
          expect(find.byType(AppAlertDialog), findsNothing);
          expect(find.text(_status.text), findsOneWidget);
        },
      );

      testWidgets('renders one original with compact inline replies below', (
        tester,
      ) async {
        final reply = _status.copyWith(
          id: 'reply',
          text: 'first reply',
          photo: null,
          inReplyToStatusId: _status.id,
        );
        final nested = reply.copyWith(
          id: 'nested',
          text: 'second reply',
          inReplyToStatusId: reply.id,
        );
        when(() => cubit.state).thenReturn(
          StatusDetailState(
            status: StatusDetailStatus.success,
            statusDetail: _status.copyWith(photo: null),
            contextStatus: StatusDetailStatus.success,
            replies: [reply, nested],
          ),
        );
        await pumpStatusDetailView(tester);

        expect(find.byType(WeChatStatusListItem), findsOneWidget);
        expect(find.byType(UserAvatar), findsOneWidget);
        expect(find.byType(StatusContextReply), findsNWidgets(2));
        expect(
          find.text('User A: first reply', findRichText: true),
          findsOneWidget,
        );
        expect(
          find.text('User A: second reply', findRichText: true),
          findsOneWidget,
        );
        expect(
          tester.getTopLeft(find.text(_status.text)).dy,
          lessThan(tester.getTopLeft(find.byType(StatusContextReply).first).dy),
        );
      });

      testWidgets('keeps replies and hides original actions when unavailable', (
        tester,
      ) async {
        when(() => cubit.state).thenReturn(
          StatusDetailState(
            status: StatusDetailStatus.success,
            statusDetail: _unavailableStatus,
            originUnavailable: true,
            contextStatus: StatusDetailStatus.success,
            replies: [_status.copyWith(photo: null, text: 'readable reply')],
          ),
        );
        await pumpStatusDetailView(tester);

        expect(find.text('原消息已删除或不公开'), findsOneWidget);
        expect(find.byType(WeChatStatusListItem), findsOneWidget);
        expect(find.text('Original Author'), findsOneWidget);
        expect(
          tester.widget<UserAvatar>(find.byType(UserAvatar)).imageUrl,
          _unavailableStatus.author.avatarUrl,
        );
        expect(find.byType(StatusPhoto), findsNothing);
        expect(
          find.byKey(const Key('wechat-status-action-hit-target')),
          findsNothing,
        );
        expect(find.byType(StatusActionButton), findsNothing);
        expect(
          find.text('User A: readable reply', findRichText: true),
          findsOneWidget,
        );
      });

      testWidgets('shows a retry action after context loading fails', (
        tester,
      ) async {
        when(() => cubit.state).thenReturn(
          StatusDetailState(
            status: StatusDetailStatus.success,
            statusDetail: _status.copyWith(photo: null),
            contextStatus: StatusDetailStatus.failure,
          ),
        );
        await pumpStatusDetailView(tester);
        expect(find.text(_status.text), findsOneWidget);
        expect(find.text('无法加载上下文，请重试。'), findsOneWidget);
        await tester.tap(find.byType(FilledButton));
        await tester.pump();
        verify(() => cubit.retry()).called(1);
      });

      testWidgets('does not refresh context when pulled down', (tester) async {
        await pumpStatusDetailView(tester);
        await tester.drag(find.byType(ListView), const Offset(0, 400));
        await tester.pumpTransition();
        expect(find.byType(RefreshIndicator), findsNothing);
        verifyNever(() => cubit.refresh());
      });

      testWidgets(
        'opens the composer for the tapped reply rather than the original',
        (tester) async {
          final reply = _status.copyWith(
            id: 'reply',
            text: 'reply body',
            photo: null,
            inReplyToStatusId: _status.id,
          );
          when(() => cubit.state).thenReturn(
            StatusDetailState(
              status: StatusDetailStatus.success,
              statusDetail: _status.copyWith(photo: null),
              contextStatus: StatusDetailStatus.success,
              replies: [reply],
            ),
          );
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => Scaffold(
                  body: BlocProvider<StatusDetailCubit>.value(
                    value: cubit,
                    child: const StatusDetailView(
                      userId: 'user-a',
                      statusId: 'reply',
                    ),
                  ),
                ),
              ),
              GoRoute(
                path: '/compose',
                name: 'status-composer',
                builder: (_, state) => Scaffold(
                  body: Text(state.uri.queryParameters['sourceStatusId']!),
                ),
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpRouterApp(router);
          await tester.tap(find.byType(StatusContextReply));
          await tester.pumpTransition();
          await tester.tap(find.byKey(const Key('status-reply-action')));
          await tester.pumpTransition();
          expect(router.state.uri.queryParameters['sourceStatusId'], reply.id);
          expect(router.state.uri.queryParameters['mode'], 'reply');
        },
      );
    });

    testWidgets('renders large photos in status detail by default', (
      tester,
    ) async {
      await pumpStatusDetailView(tester);
      final photo = tester.widget<StatusPhoto>(find.byType(StatusPhoto));

      expect(find.byType(StatusListItem), findsOneWidget);
      expect(find.byType(WeChatStatusListItem), findsOneWidget);
      expect(find.textContaining(_status.author.name), findsOneWidget);
      expect(find.text(_status.text), findsOneWidget);
      expect(find.text('2026年7月28日 08:00'), findsOneWidget);
      expect(photo.imageUrl, 'https://example.com/status-photo-large.png');
      expect(photo.style, StatusPhotoStyle.x);
      expect(
        photo.heroTag,
        'status-photo-status-detail-${_status.id}-'
        'https://example.com/status-photo-large.png',
      );
      expect(find.text('@${_status.author.screenName}'), findsNothing);
      expect(find.byType(StatusActionButton), findsOneWidget);
      final avatar = tester.widget<UserAvatar>(find.byType(UserAvatar));
      expect(avatar.size, 44);
      expect(avatar.borderRadius, isNull);
      expect(
        find.descendant(
          of: find.byType(UserAvatar),
          matching: find.byType(ClipOval),
        ),
        findsOneWidget,
      );
    });

    testWidgets('uses the small photo style when selected', (
      tester,
    ) async {
      await pumpStatusDetailView(
        tester,
        appearance: const AppearanceSettings(
          statusPhotoStyle: StatusPhotoStyle.wechat,
        ),
      );
      final photo = tester.widget<StatusPhoto>(find.byType(StatusPhoto));

      expect(find.byType(StatusListItem), findsOneWidget);
      expect(find.byType(WeChatStatusListItem), findsOneWidget);
      expect(find.textContaining(_status.author.name), findsOneWidget);
      expect(find.text(_status.text), findsOneWidget);
      expect(photo.style, StatusPhotoStyle.wechat);
      expect(
        find.textContaining('@${_status.author.screenName}'),
        findsNothing,
      );
      expect(find.byType(StatusActionButton), findsOneWidget);
    });

    testWidgets('does not make status content open another detail page', (
      tester,
    ) async {
      await pumpStatusDetailView(tester);

      final statusTapTargets = tester.widgetList<StatusListItemTapTarget>(
        find.byType(StatusListItemTapTarget),
      );

      expect(statusTapTargets, isNotEmpty);
      expect(statusTapTargets.first.onTap, isNull);
      expect(
        statusTapTargets.skip(1).any((target) => target.onTap != null),
        isTrue,
      );
    });
  });
}

const _status = status_repository.Status(
  id: 'status-a',
  text: 'hello from detail',
  createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
  photo: status_repository.StatusPhotoUrls(
    thumbnailUrl: 'https://example.com/status-photo-thumb.png',
    imageUrl: 'https://example.com/status-photo.png',
    largeUrl: 'https://example.com/status-photo-large.png',
  ),
  author: status_repository.StatusAuthor(
    id: 'user-a',
    name: 'User A',
    screenName: 'user_a',
  ),
);

const _unavailableStatus = status_repository.Status(
  id: 'original',
  text: '',
  createdAt: '',
  author: status_repository.StatusAuthor(
    id: 'origin-author',
    name: 'Original Author',
    screenName: 'original',
    avatarUrl: 'https://example.com/origin.png',
  ),
);
