import 'dart:async';

import 'package:appearance_repository/appearance_repository.dart';
import 'package:dan/app/navigation/routes.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:dan/status/widgets/status_action_button.dart';
import 'package:dan/status/widgets/status_list_item.dart';
import 'package:dan/status/widgets/status_photo.dart';
import 'package:dan/status/widgets/wechat_status_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:remixicon/remixicon.dart';
import 'package:status_repository/status_repository.dart' as status_repository;
import 'package:user_repository/user_repository.dart';

import '../../helpers/helpers.dart';

class _MockUserRepository extends Mock implements UserRepository {}

void main() {
  group(StatusListItem, () {
    late UserRepository userRepository;

    setUp(() {
      userRepository = _MockUserRepository();
    });

    Future<GoRouter> pumpStatusListItem(
      WidgetTester tester, {
      AppearanceSettings appearance = const AppearanceSettings(),
      status_repository.Status status = _status,
      VoidCallback? onStatusActionTap,
      FutureOr<void> Function()? onStatusDelete,
      VoidCallback? onStatusFavoriteToggle,
    }) async {
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, _) => RepositoryProvider.value(
              value: userRepository,
              child: SingleChildScrollView(
                child: StatusListItem(
                  status: status,
                  onStatusActionTap: onStatusActionTap,
                  onStatusDelete: onStatusDelete,
                  onStatusFavoriteToggle: onStatusFavoriteToggle,
                ),
              ),
            ),
          ),
          GoRoute(
            name: AppRouteName.statusDetail,
            path: AppRoutePath.statusDetail,
            builder: (_, state) => Text(
              'status-${state.pathParameters['statusId']}',
            ),
          ),
          GoRoute(
            name: AppRouteName.statusImageViewer,
            path: AppRoutePath.statusImageViewer,
            builder: (_, state) => Text(
              'image-${state.uri.queryParameters['url']}',
            ),
          ),
          GoRoute(
            name: AppRouteName.userProfile,
            path: AppRoutePath.userProfile,
            builder: (_, state) => Text(
              'profile-${state.pathParameters['userId']}',
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpRouterApp(
        router,
        theme: AppTheme.light(appearance: appearance),
        themeMode: ThemeMode.light,
      );
      await tester.pump();
      return router;
    }

    testWidgets(
      'displays the list item with a large route-scoped photo by default',
      (tester) async {
        await pumpStatusListItem(tester);

        expect(find.byType(WeChatStatusListItem), findsOneWidget);
        final photo = tester.widget<StatusPhoto>(find.byType(StatusPhoto));
        expect(photo.style, StatusPhotoStyle.x);
        expect(
          photo.heroTag,
          'status-photo-home-${_status.id}-'
          'https://example.com/status-photo-large.png',
        );
      },
    );

    testWidgets('uses the small photo style when selected', (
      tester,
    ) async {
      await pumpStatusListItem(
        tester,
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

    testWidgets('forwards the WeChat status action callback', (tester) async {
      var actionTapCount = 0;
      final router = await pumpStatusListItem(
        tester,
        onStatusActionTap: () => actionTapCount++,
      );

      await tester.ensureVisible(find.byType(StatusActionButton));
      await tester.pump();
      await tester.tap(find.byType(StatusActionButton));
      await tester.pump();

      expect(actionTapCount, 1);
      expect(router.state.uri.path, '/home');
    });

    testWidgets('opens one grouped status action sheet', (tester) async {
      await pumpStatusListItem(tester);
      final context = tester.element(find.byType(StatusActionButton));

      await tester.ensureVisible(find.byType(StatusActionButton));
      await tester.pump();
      await tester.tap(find.byType(StatusActionButton));
      await tester.pumpTransition();

      expect(find.byKey(const Key('status-action-sheet')), findsOneWidget);
      expect(find.byKey(const Key('status-action-group')), findsOneWidget);
      expect(find.byKey(const Key('status-action-divider-0')), findsOneWidget);
      expect(find.byKey(const Key('status-action-divider-1')), findsOneWidget);
      expect(find.text(context.l10n.statusActionReplyLabel), findsOneWidget);
      expect(
        find.text(context.l10n.statusActionFavoriteLabel),
        findsOneWidget,
      );
      expect(find.text(context.l10n.statusActionRepostLabel), findsOneWidget);
      expect(find.byIcon(RemixIcons.message_2_line), findsOneWidget);
      expect(find.byIcon(RemixIcons.star_line), findsOneWidget);
      expect(find.byIcon(RemixIcons.repeat_line), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const Key('status-reply-action'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('status-repost-action'))).dy,
        ),
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('status-repost-action'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('status-favorite-action'))).dy,
        ),
      );
      expect(find.byKey(const Key('status-delete-group')), findsNothing);
      expect(find.byIcon(RemixIcons.delete_bin_7_line), findsNothing);
    });

    testWidgets('adds a destructive delete group for a self status', (
      tester,
    ) async {
      await pumpStatusListItem(
        tester,
        status: _status.copyWith(isSelf: true),
      );
      final context = tester.element(find.byType(StatusActionButton));

      await tester.ensureVisible(find.byType(StatusActionButton));
      await tester.pump();
      await tester.tap(find.byType(StatusActionButton));
      await tester.pumpTransition();

      final deleteLabelFinder = find.text(context.l10n.statusActionDeleteLabel);
      final deleteIconFinder = find.byIcon(RemixIcons.delete_bin_7_line);

      expect(find.byKey(const Key('status-delete-group')), findsOneWidget);
      expect(find.byKey(const Key('status-delete-action')), findsOneWidget);
      expect(deleteLabelFinder, findsOneWidget);
      expect(deleteIconFinder, findsOneWidget);
      expect(
        tester.widget<Text>(deleteLabelFinder).style?.color,
        context.appColors.destructiveAction,
      );
      expect(
        tester.widget<Icon>(deleteIconFinder).color,
        context.appColors.destructiveAction,
      );
      expect(context.appColors.destructiveAction, const Color(0xFFFF3040));
    });

    testWidgets('hides reply for a self status', (tester) async {
      await pumpStatusListItem(
        tester,
        status: _status.copyWith(isSelf: true),
      );
      final context = tester.element(find.byType(StatusActionButton));
      await tester.ensureVisible(find.byType(StatusActionButton));
      await tester.pump();
      await tester.tap(find.byType(StatusActionButton));
      await tester.pumpTransition();

      expect(find.byKey(const Key('status-reply-action')), findsNothing);
      expect(find.text(context.l10n.statusActionReplyLabel), findsNothing);
      expect(find.byKey(const Key('status-repost-action')), findsOneWidget);
      expect(find.byKey(const Key('status-favorite-action')), findsOneWidget);
    });

    testWidgets('invokes the favorite callback from the action sheet', (
      tester,
    ) async {
      var favoriteCount = 0;
      await pumpStatusListItem(
        tester,
        onStatusFavoriteToggle: () => favoriteCount++,
      );

      await tester.ensureVisible(find.byType(StatusActionButton));
      await tester.pump();
      await tester.tap(find.byType(StatusActionButton));
      await tester.pumpTransition();
      await tester.tap(find.byKey(const Key('status-favorite-action')));
      await tester.pumpTransition();

      expect(favoriteCount, 1);
    });

    testWidgets('uses the favorite color for an already favorited status', (
      tester,
    ) async {
      await pumpStatusListItem(
        tester,
        status: _status.copyWith(isFavorited: true),
      );
      await tester.ensureVisible(find.byType(StatusActionButton));
      await tester.pump();
      await tester.tap(find.byType(StatusActionButton));
      await tester.pumpTransition();

      final favoriteIcon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(const Key('status-favorite-action')),
          matching: find.byType(Icon),
        ),
      );
      expect(favoriteIcon.icon, RemixIcons.star_fill);
      expect(favoriteIcon.color, const Color(0xFFFFDD33));
    });

    testWidgets('shows a delete confirmation dialog for a self status', (
      tester,
    ) async {
      var deleteCount = 0;
      await pumpStatusListItem(
        tester,
        status: _status.copyWith(isSelf: true),
        onStatusDelete: () => deleteCount++,
      );
      final context = tester.element(find.byType(StatusActionButton));
      final title = context.l10n.statusDeleteDialogTitle;
      final content = context.l10n.statusDeleteDialogContent;
      final cancelLabel = context.l10n.statusDeleteDialogCancelLabel;
      final confirmLabel = context.l10n.statusDeleteDialogConfirmLabel;

      await tester.ensureVisible(find.byType(StatusActionButton));
      await tester.pump();
      await tester.tap(find.byType(StatusActionButton));
      await tester.pumpTransition();
      await tester.tap(find.byKey(const Key('status-delete-action')));
      await tester.pumpTransition();

      expect(find.byType(AppAlertDialog), findsOneWidget);
      expect(find.text(title), findsOneWidget);
      expect(find.text(content), findsOneWidget);

      await tester.tap(find.text(cancelLabel));
      await tester.pumpTransition();
      expect(find.byType(AppAlertDialog), findsNothing);
      expect(deleteCount, 0);

      await tester.ensureVisible(find.byType(StatusActionButton));
      await tester.pump();
      await tester.tap(find.byType(StatusActionButton));
      await tester.pumpTransition();
      await tester.tap(find.byKey(const Key('status-delete-action')));
      await tester.pumpTransition();
      await tester.tap(find.text(confirmLabel));
      await tester.pumpTransition();

      expect(deleteCount, 1);
    });

    testWidgets('keeps confirmation busy until deletion succeeds', (
      tester,
    ) async {
      final request = Completer<void>();
      var calls = 0;
      await pumpStatusListItem(
        tester,
        status: _status.copyWith(isSelf: true),
        onStatusDelete: () {
          calls++;
          return request.future;
        },
      );
      final context = tester.element(find.byType(StatusActionButton));
      await tester.ensureVisible(find.byType(StatusActionButton));
      await tester.pump();
      await tester.tap(find.byType(StatusActionButton));
      await tester.pumpTransition();
      await tester.tap(find.byKey(const Key('status-delete-action')));
      await tester.pumpTransition();
      await tester.tap(find.text(context.l10n.statusDeleteDialogConfirmLabel));
      await tester.pump();

      expect(find.byType(AppAlertDialog), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.getSize(find.byType(CircularProgressIndicator)),
        const Size(16, 16),
      );
      await tester.tap(find.byType(CircularProgressIndicator));
      await tester.tap(find.text(context.l10n.statusDeleteDialogCancelLabel));
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(calls, 1);
      expect(find.byType(AppAlertDialog), findsOneWidget);

      request.complete();
      await tester.pumpTransition();
      expect(find.byType(AppAlertDialog), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('restores confirmation after deletion fails and allows retry', (
      tester,
    ) async {
      var calls = 0;
      await pumpStatusListItem(
        tester,
        status: _status.copyWith(isSelf: true),
        onStatusDelete: () async {
          calls++;
          if (calls == 1) throw StateError('network failure');
        },
      );
      final context = tester.element(find.byType(StatusActionButton));
      await tester.ensureVisible(find.byType(StatusActionButton));
      await tester.pump();
      await tester.tap(find.byType(StatusActionButton));
      await tester.pumpTransition();
      await tester.tap(find.byKey(const Key('status-delete-action')));
      await tester.pumpTransition();
      await tester.tap(find.text(context.l10n.statusDeleteDialogConfirmLabel));
      await tester.pumpTransition();

      expect(find.byType(AppAlertDialog), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text(context.l10n.statusDeleteFailure), findsOneWidget);
      await tester.tap(find.text(context.l10n.statusDeleteDialogConfirmLabel));
      await tester.pumpTransition();
      expect(calls, 2);
      expect(find.byType(AppAlertDialog), findsNothing);
    });

    testWidgets('opens the author profile from the nickname', (tester) async {
      final router = await pumpStatusListItem(tester);

      await tester.tap(find.text(_status.author.name));
      await tester.pumpTransition();

      expect(
        router.state.uri.path,
        '/${_status.author.id}',
      );
      expect(
        router.state.uri.queryParameters,
        const {'presentation': 'pushed'},
      );
      expect(find.text('profile-${_status.author.id}'), findsOneWidget);
      verify(
        () => userRepository.cacheUser(
          UserProfile(
            id: _status.author.id,
            name: _status.author.name,
            screenName: _status.author.screenName,
            gender: _status.author.gender,
            avatarUrl: _status.author.avatarUrl,
            description: _status.author.description,
            url: _status.author.url,
            location: _status.author.location,
            createdAt: _status.author.createdAt,
            protected: _status.author.protected,
            following: _status.author.following,
            followersCount: _status.author.followersCount,
            friendsCount: _status.author.friendsCount,
            favoritesCount: _status.author.favoritesCount,
            statusesCount: _status.author.statusesCount,
            photoCount: _status.author.photoCount,
          ),
        ),
      ).called(1);
    });

    testWidgets('opens the author profile from the avatar', (tester) async {
      final router = await pumpStatusListItem(tester);

      await tester.tap(find.bySemanticsLabel(_status.author.name).first);
      await tester.pumpTransition();

      expect(router.state.uri.path, '/${_status.author.id}');
      expect(find.text('profile-${_status.author.id}'), findsOneWidget);
      verify(
        () => userRepository.cacheUser(
          UserProfile(
            id: _status.author.id,
            name: _status.author.name,
            screenName: _status.author.screenName,
            gender: _status.author.gender,
            avatarUrl: _status.author.avatarUrl,
            description: _status.author.description,
            url: _status.author.url,
            location: _status.author.location,
            createdAt: _status.author.createdAt,
            protected: _status.author.protected,
            following: _status.author.following,
            followersCount: _status.author.followersCount,
            friendsCount: _status.author.friendsCount,
            favoritesCount: _status.author.favoritesCount,
            statusesCount: _status.author.statusesCount,
            photoCount: _status.author.photoCount,
          ),
        ),
      ).called(1);
    });

    testWidgets('opens status detail from the body', (tester) async {
      final router = await pumpStatusListItem(tester);

      await tester.tap(find.text(_status.text));
      await tester.pumpTransition();

      expect(
        router.state.uri.path,
        '/${_status.author.id}/status/${_status.id}',
      );
    });

    testWidgets('opens the image viewer directly from the photo', (
      tester,
    ) async {
      final router = await pumpStatusListItem(tester);

      await tester.tap(find.byType(StatusPhoto));
      await tester.pumpTransition();

      expect(router.state.uri.path, AppRoutePath.statusImageViewer);
      expect(
        find.text('image-${_status.photo!.viewerUrl}'),
        findsOneWidget,
      );
    });
  });
}

const _status = status_repository.Status(
  id: 'status-with-photo',
  text: 'hello',
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
    gender: '男',
    description: 'Status author biography',
    url: 'https://example.com/user-a',
    location: 'Shanghai',
    createdAt: 'Thu Feb 5 00:00:00 +0800 2009',
    protected: true,
    following: false,
    followersCount: 12,
    friendsCount: 8,
    favoritesCount: 5,
    statusesCount: 42,
    photoCount: 7,
  ),
);
