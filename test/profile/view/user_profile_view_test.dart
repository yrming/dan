import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dan/app/navigation/routes.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:dan/profile/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:remixicon/remixicon.dart';
import 'package:user_repository/user_repository.dart';

import '../../helpers/helpers.dart';

class _MockUserProfileCubit extends MockCubit<UserProfileState>
    implements UserProfileCubit {}

void main() {
  group(UserProfileView, () {
    late UserProfileCubit userProfileCubit;

    setUp(() {
      userProfileCubit = _MockUserProfileCubit();
    });

    Future<void> pumpView(
      WidgetTester tester,
      UserProfileState state, {
      bool isCurrentUser = false,
      int? friendRequestCount,
    }) async {
      when(() => userProfileCubit.state).thenReturn(state);
      await tester.pumpApp(
        BlocProvider.value(
          value: userProfileCubit,
          child: UserProfileView(
            userId: 'user-a',
            isCurrentUser: isCurrentUser,
            friendRequestCount: friendRequestCount,
          ),
        ),
      );
    }

    Future<GoRouter> pumpViewWithRouter(
      WidgetTester tester,
      UserProfileState state, {
      required bool isCurrentUser,
    }) async {
      when(() => userProfileCubit.state).thenReturn(state);
      final router = GoRouter(
        initialLocation: '/profile',
        routes: [
          GoRoute(
            path: '/profile',
            builder: (_, _) => BlocProvider.value(
              value: userProfileCubit,
              child: UserProfileView(
                userId: 'user-a',
                isCurrentUser: isCurrentUser,
              ),
            ),
          ),
          GoRoute(
            name: AppRouteName.userStatuses,
            path: AppRoutePath.userStatuses,
            builder: (_, state) => Text(
              'statuses-${state.pathParameters['userId']}',
            ),
          ),
          GoRoute(
            name: AppRouteName.userPhotos,
            path: AppRoutePath.userPhotos,
            builder: (_, state) => Text(
              'photos-${state.pathParameters['userId']}',
            ),
          ),
          GoRoute(
            name: AppRouteName.favorites,
            path: AppRoutePath.favorites,
            builder: (_, state) => Text(
              'favorites-${state.pathParameters['userId']}',
            ),
          ),
          GoRoute(
            name: AppRouteName.following,
            path: AppRoutePath.following,
            builder: (_, state) => Text(
              'following-${state.pathParameters['userId']}',
            ),
          ),
          GoRoute(
            name: AppRouteName.followers,
            path: AppRoutePath.followers,
            builder: (_, state) => Text(
              'followers-${state.pathParameters['userId']}',
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpRouterApp(router);
      await tester.pump();
      return router;
    }

    testWidgets('renders the shared account header structure', (
      tester,
    ) async {
      await pumpView(
        tester,
        const UserProfileLoadSuccess(
          profile: _profile,
        ),
        friendRequestCount: 4,
      );
      final context = tester.element(find.byType(UserProfileView));

      expect(find.byType(ProfileHeader), findsOneWidget);
      expect(find.text(_profile.name), findsOneWidget);
      expect(find.byIcon(Icons.man), findsOneWidget);
      expect(find.byIcon(Icons.woman), findsNothing);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.man)).color,
        const Color(0xFF14AEFF),
      );
      expect(
        find.text(context.l10n.userProfileAccountHandle(_profile.id)),
        findsOneWidget,
      );
      // The header no longer uses the legacy location labels.
      expect(
        find.text('所在地：${_profile.location}'),
        findsNothing,
      );
      expect(
        find.text('${_profile.id} / 所在地：${_profile.location}'),
        findsNothing,
      );
      expect(
        find.text(
          context.l10n.userProfileAccountHandle(_profile.screenName),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(ProfileHeader),
          matching: find.text(_profile.description!),
        ),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('user-profile-description'))).dx,
        tester
            .getTopLeft(
              find.text(context.l10n.userProfileAccountHandle(_profile.id)),
            )
            .dx,
      );
    });

    testWidgets('renders a circular avatar with a divider border', (
      tester,
    ) async {
      await pumpView(
        tester,
        const UserProfileLoadSuccess(profile: _profile),
      );
      final avatarFinder = find.byKey(const Key('user-profile-avatar'));
      final context = tester.element(avatarFinder);
      final avatar = tester.widget<UserAvatar>(avatarFinder);

      expect(avatar.imageUrl, _profile.avatarUrl);
      expect(avatar.borderRadius, isNull);
      expect(avatar.borderColor, context.appColors.divider);
      expect(avatar.borderWidth, 0.5);
      final avatarContainer = tester.widget<Container>(
        find.descendant(
          of: avatarFinder,
          matching: find.byType(Container),
        ),
      );
      final avatarDecoration =
          avatarContainer.foregroundDecoration! as BoxDecoration;
      final avatarBorder = avatarDecoration.border! as Border;
      expect(avatarDecoration.shape, BoxShape.circle);
      expect(avatarBorder.top.color, context.appColors.divider);
      expect(avatarBorder.top.width, 0.5);
      expect(
        find.descendant(
          of: avatarFinder,
          matching: find.byType(ClipOval),
        ),
        findsOneWidget,
      );
    });

    testWidgets('uses compact spacing above the account identity', (
      tester,
    ) async {
      await pumpView(
        tester,
        const UserProfileLoadSuccess(profile: _profile),
      );

      final headerFinder = find.byType(ProfileHeader);
      final avatarFinder = find.byKey(const Key('user-profile-avatar'));
      final context = tester.element(headerFinder);

      expect(
        tester.getTopLeft(avatarFinder).dy - tester.getTopLeft(headerFinder).dy,
        context.appSizing.scaled(AppSpacing.sm),
      );
    });

    testWidgets('shows the female gender icon after the profile name', (
      tester,
    ) async {
      const profile = UserProfile(
        id: 'user-a',
        name: '饭友 A',
        screenName: 'fanfou_a',
        gender: '女',
      );
      await pumpView(
        tester,
        const UserProfileLoadSuccess(profile: profile),
      );

      expect(find.byIcon(Icons.woman), findsOneWidget);
      expect(find.byIcon(Icons.man), findsNothing);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.woman)).color,
        const Color(0xFFC84040),
      );
    });

    testWidgets('does not show a gender icon for an unknown gender', (
      tester,
    ) async {
      const profile = UserProfile(
        id: 'user-a',
        name: '饭友 A',
        screenName: 'fanfou_a',
        gender: '未知',
      );
      await pumpView(
        tester,
        const UserProfileLoadSuccess(profile: profile),
      );

      expect(find.byIcon(Icons.woman), findsNothing);
      expect(find.byIcon(Icons.man), findsNothing);
    });

    testWidgets('does not render the superseded settings list action', (
      tester,
    ) async {
      when(() => userProfileCubit.state).thenReturn(
        const UserProfileLoadSuccess(profile: _profile),
      );
      await tester.pumpApp(
        BlocProvider.value(
          value: userProfileCubit,
          child: const UserProfileView(userId: 'user-a'),
        ),
      );
      final context = tester.element(find.byType(UserProfileView));

      expect(
        find.text(context.l10n.userProfileFavoritesLabel),
        findsOneWidget,
      );
      expect(
        find.text(context.l10n.userProfileSettingsLabel),
        findsNothing,
      );
      expect(
        find.text('外观与显示偏好'),
        findsNothing,
      );
      expect(find.text(_profile.description!), findsOneWidget);
    });

    testWidgets('shows the complete multi-line biography in the header', (
      tester,
    ) async {
      const profile = UserProfile(
        id: 'user-a',
        name: '饭友 A',
        screenName: 'fanfou_a',
        description: '第一行简介\n第二行简介\n第三行简介',
      );
      await pumpView(
        tester,
        const UserProfileLoadSuccess(profile: profile),
      );

      final biography = tester.widget<Text>(
        find.byKey(const Key('user-profile-description')),
      );
      final context = tester.element(find.byType(UserProfileView));

      expect(biography.data, profile.description);
      expect(biography.maxLines, isNull);
      expect(
        find.text(context.l10n.userProfileAccountHandle(profile.id)),
        findsOneWidget,
      );
      expect(
        biography.style,
        tester
            .element(find.byType(ProfileHeader))
            .appTypography
            .accountDescription,
      );
    });

    testWidgets('shows a non-empty profile URL below the biography', (
      tester,
    ) async {
      await pumpView(
        tester,
        const UserProfileLoadSuccess(profile: _profile),
      );

      expect(find.byKey(const Key('user-profile-url')), findsOneWidget);
      expect(find.text(_profile.url!), findsOneWidget);
      final context = tester.element(find.byType(ProfileHeader));
      final followSummaryFinder = find.byKey(
        const Key('user-profile-follow-summary'),
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('user-profile-url'))).style,
        context.appTypography.accountDescription.copyWith(
          color: context.appColors.wechatLinkText,
        ),
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('user-profile-url'))).dy,
        greaterThan(
          tester
              .getBottomLeft(find.byKey(const Key('user-profile-description')))
              .dy,
        ),
      );
      expect(followSummaryFinder, findsOneWidget);
      final followingText = find.text(
        '${_profile.friendsCount} '
        '${context.l10n.userProfileFollowingLabel}',
      );
      expect(followingText, findsOneWidget);
      expect(
        find.text(
          '${_profile.followersCount} '
          '${context.l10n.userProfileFollowersLabel}',
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<Text>(followingText).style,
        context.appTypography.accountDescription.copyWith(
          color: context.appColors.textSecondary,
        ),
      );
      expect(
        tester.getTopLeft(followSummaryFinder).dy,
        greaterThan(
          tester.getBottomLeft(find.byKey(const Key('user-profile-url'))).dy,
        ),
      );
    });

    testWidgets('hides a blank profile URL', (tester) async {
      const profile = UserProfile(
        id: 'user-a',
        name: '饭友 A',
        screenName: 'fanfou_a',
        description: '写点什么。',
        url: '   ',
      );
      await pumpView(
        tester,
        const UserProfileLoadSuccess(profile: profile),
      );

      expect(find.byKey(const Key('user-profile-url')), findsNothing);
      expect(
        find.byKey(const Key('user-profile-follow-summary')),
        findsOneWidget,
      );
      expect(find.text('0 关注'), findsOneWidget);
      expect(find.text('0 粉丝'), findsOneWidget);
    });

    testWidgets(
      'keeps the profile header surface behind the revealed top overscroll',
      (tester) async {
        when(() => userProfileCubit.state).thenReturn(
          const UserProfileLoadSuccess(profile: _profile),
        );
        await tester.pumpApp(
          BlocProvider.value(
            value: userProfileCubit,
            child: const UserProfileView(userId: 'user-a'),
          ),
          theme: AppTheme.light().copyWith(platform: TargetPlatform.iOS),
        );

        final listFinder = find.byType(ListView);
        final headerFinder = find.byType(ProfileHeader);
        final overscrollSurfaceFinder = find.byKey(
          const Key('user-profile-overscroll-surface'),
        );
        final initialHeaderTop = tester.getTopLeft(headerFinder).dy;
        final viewportTop = tester.getTopLeft(listFinder).dy;

        final gesture = await tester.startGesture(
          tester.getTopLeft(listFinder) + const Offset(120, 120),
        );
        await gesture.moveBy(const Offset(0, 240));
        await tester.pump();

        final pulledHeaderRect = tester.getRect(headerFinder);
        final overscrollSurfaceRect = tester.getRect(overscrollSurfaceFinder);
        final overscrollSurface = tester.widget<ColoredBox>(
          overscrollSurfaceFinder,
        );
        final context = tester.element(headerFinder);

        expect(pulledHeaderRect.top, greaterThan(initialHeaderTop));
        expect(overscrollSurfaceRect.top, lessThanOrEqualTo(viewportTop));
        expect(overscrollSurfaceRect.bottom, pulledHeaderRect.bottom);
        expect(
          overscrollSurface.color,
          Theme.of(context).colorScheme.surface,
        );

        await gesture.up();
      },
    );

    testWidgets('removes the legacy following and followers menu group', (
      tester,
    ) async {
      await pumpView(
        tester,
        const UserProfileLoadSuccess(profile: _profile),
      );
      final context = tester.element(find.byType(UserProfileView));

      expect(find.text(_profile.description!), findsOneWidget);
      expect(
        find.text(context.l10n.userProfileAccountHandle(_profile.id)),
        findsOneWidget,
      );
      expect(find.byType(ProfileMenuSection), findsOneWidget);
      expect(find.byType(ProfileTile), findsNWidgets(3));
      expect(find.text(context.l10n.userProfileMessagesLabel), findsOneWidget);
      expect(find.text('${_profile.statusesCount}'), findsOneWidget);
      expect(find.text(context.l10n.userProfilePhotosLabel), findsOneWidget);
      expect(find.text('${_profile.photoCount}'), findsOneWidget);
      expect(
        find.text(context.l10n.userProfileFavoritesLabel),
        findsOneWidget,
      );
      expect(find.text('${_profile.favoritesCount}'), findsOneWidget);
      expect(find.byIcon(RemixIcons.message_line), findsOneWidget);
      expect(find.byIcon(RemixIcons.multi_image_line), findsOneWidget);
      expect(find.byIcon(RemixIcons.star_line), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(3));
      final profileTiles = tester
          .widgetList<ProfileTile>(
            find.byType(ProfileTile),
          )
          .toList();
      expect(
        profileTiles.map((tile) => tile.icon),
        [
          RemixIcons.message_line,
          RemixIcons.multi_image_line,
          RemixIcons.star_line,
        ],
      );
      expect(find.byIcon(RemixIcons.user_shared_line), findsNothing);
      expect(find.byIcon(RemixIcons.user_received_line), findsNothing);
      expect(find.byIcon(RemixIcons.user_add_line), findsNothing);
      for (final icon in [
        RemixIcons.message_line,
        RemixIcons.multi_image_line,
        RemixIcons.star_line,
      ]) {
        expect(
          tester.widget<Icon>(find.byIcon(icon)).color,
          context.appColors.textBase,
        );
      }
    });

    testWidgets('does not play a ripple when an entry is tapped', (
      tester,
    ) async {
      await pumpView(
        tester,
        const UserProfileLoadSuccess(profile: _profile),
      );
      final inkWells = tester.widgetList<InkWell>(
        find.descendant(
          of: find.byType(ProfileMenuSection),
          matching: find.byType(InkWell),
        ),
      );

      expect(inkWells.length, 3);
      for (final inkWell in inkWells) {
        final theme = Theme.of(tester.element(find.byWidget(inkWell)));
        expect(
          inkWell.splashFactory ?? theme.splashFactory,
          NoSplash.splashFactory,
        );
        expect(
          inkWell.highlightColor ?? theme.highlightColor,
          AppColors.transparent,
        );
        expect(inkWell.hoverColor, AppColors.transparent);
      }
    });

    testWidgets('hides the entry chevrons for a locked profile', (
      tester,
    ) async {
      const profile = UserProfile(
        id: 'user-a',
        name: '饭友 A',
        screenName: 'fanfou_a',
        protected: true,
        following: false,
      );
      await pumpView(tester, const UserProfileLoadSuccess(profile: profile));

      expect(find.byType(ProfileTile), findsNWidgets(3));
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('opens the protected content dialog from every entry', (
      tester,
    ) async {
      const profile = UserProfile(
        id: 'user-a',
        name: '饭友 A',
        screenName: 'fanfou_a',
        protected: true,
        following: false,
      );
      await pumpView(
        tester,
        const UserProfileLoadSuccess(profile: profile),
      );
      final context = tester.element(find.text(profile.name));
      final l10n = context.l10n;

      for (final label in [
        l10n.userProfileMessagesLabel,
        l10n.userProfilePhotosLabel,
        l10n.userProfileFavoritesLabel,
      ]) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();

        expect(find.text(l10n.userProfileProtectedDialogTitle), findsOneWidget);
        expect(
          find.text(l10n.userProfileProtectedDialogContent),
          findsOneWidget,
        );
        expect(
          find.text(l10n.userProfileProtectedDialogCancelLabel),
          findsOneWidget,
        );
        expect(
          find.text(l10n.userProfileProtectedDialogFollowUnknownLabel),
          findsOneWidget,
        );
        expect(
          tester
              .widget<Text>(
                find.text(l10n.userProfileProtectedDialogFollowUnknownLabel),
              )
              .style
              ?.color,
          context.appColors.wechatLinkText,
        );

        await tester.tap(
          find.text(l10n.userProfileProtectedDialogFollowUnknownLabel),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(l10n.userProfileProtectedDialogTitle),
          findsNothing,
        );
      }
    });

    for (final gender in const ['男', '女', null]) {
      testWidgets('shows the gendered follow label for gender: $gender', (
        tester,
      ) async {
        const profile = UserProfile(
          id: 'user-a',
          name: '饭友 A',
          screenName: 'fanfou_a',
          protected: true,
          following: false,
        );
        final genderedProfile = UserProfile(
          id: profile.id,
          name: profile.name,
          screenName: profile.screenName,
          protected: true,
          following: false,
          gender: gender,
        );
        await pumpView(
          tester,
          UserProfileLoadSuccess(profile: genderedProfile),
        );
        final l10n = tester.element(find.text(genderedProfile.name)).l10n;
        final expectedLabel = switch (gender) {
          '男' => l10n.userProfileProtectedDialogFollowMaleLabel,
          '女' => l10n.userProfileProtectedDialogFollowFemaleLabel,
          _ => l10n.userProfileProtectedDialogFollowUnknownLabel,
        };

        await tester.tap(find.text(l10n.userProfileMessagesLabel));
        await tester.pumpAndSettle();

        expect(find.text(expectedLabel), findsOneWidget);
      });
    }

    testWidgets('keeps the dialog open when the cancel action is tapped', (
      tester,
    ) async {
      const profile = UserProfile(
        id: 'user-a',
        name: '饭友 A',
        screenName: 'fanfou_a',
        protected: true,
        following: false,
      );
      await pumpView(
        tester,
        const UserProfileLoadSuccess(profile: profile),
      );
      final context = tester.element(find.text(profile.name));
      final l10n = context.l10n;

      await tester.tap(find.text(l10n.userProfileMessagesLabel));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.userProfileProtectedDialogCancelLabel));
      await tester.pumpAndSettle();

      expect(find.text(l10n.userProfileProtectedDialogTitle), findsNothing);
      expect(find.text(l10n.userProfileMessagesLabel), findsOneWidget);
    });

    testWidgets('navigates instead of showing the dialog when following', (
      tester,
    ) async {
      const profile = UserProfile(
        id: 'user-a',
        name: '饭友 A',
        screenName: 'fanfou_a',
        protected: true,
        following: true,
      );
      await pumpViewWithRouter(
        tester,
        const UserProfileLoadSuccess(profile: profile),
        isCurrentUser: false,
      );
      final context = tester.element(find.text(profile.name));

      expect(find.byIcon(Icons.chevron_right), findsNWidgets(3));

      await tester.tap(find.text(context.l10n.userProfileMessagesLabel));
      await tester.pumpAndSettle();

      expect(find.text('statuses-user-a'), findsOneWidget);
      expect(find.byType(AppAlertDialog), findsNothing);
    });

    testWidgets('navigates instead of showing the dialog for the current '
        'account while protected', (tester) async {
      const profile = UserProfile(
        id: 'user-a',
        name: '饭友 A',
        screenName: 'fanfou_a',
        protected: true,
        following: false,
      );
      await pumpViewWithRouter(
        tester,
        const UserProfileLoadSuccess(profile: profile),
        isCurrentUser: true,
      );
      final context = tester.element(find.text(profile.name));

      await tester.tap(find.text(context.l10n.userProfileFavoritesLabel));
      await tester.pumpAndSettle();

      expect(find.text('favorites-user-a'), findsOneWidget);
      expect(find.byType(AppAlertDialog), findsNothing);
    });

    testWidgets('shows follow requests in the active account summary', (
      tester,
    ) async {
      await pumpView(
        tester,
        const UserProfileLoadSuccess(
          profile: _profile,
        ),
        friendRequestCount: 4,
      );
      final context = tester.element(find.byType(ProfileHeader));

      expect(
        find.text(
          context.l10n.userProfileFollowRequestsCount(4),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(RemixIcons.user_add_line), findsNothing);
    });

    for (final isCurrentUser in [true, false]) {
      testWidgets(
        'reloads the profile after returning from a relation list only for '
        'the current account=$isCurrentUser',
        (tester) async {
          when(() => userProfileCubit.load()).thenAnswer((_) async {});
          final router = await pumpViewWithRouter(
            tester,
            const UserProfileLoadSuccess(profile: _profile),
            isCurrentUser: isCurrentUser,
          );
          final context = tester.element(find.byType(UserProfileView));

          await tester.tap(
            find.text(
              '${_profile.friendsCount} '
              '${context.l10n.userProfileFollowingLabel}',
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('following-user-a'), findsOneWidget);

          router.pop();
          await tester.pumpAndSettle();

          if (isCurrentUser) {
            verify(() => userProfileCubit.load()).called(1);
          } else {
            verifyNever(() => userProfileCubit.load());
          }
        },
      );
    }

    group('returning from status lists', () {
      for (final isCurrentUser in [true, false]) {
        for (final entry in [
          (label: '消息', destination: 'statuses-user-a', count: 42),
          (label: '收藏', destination: 'favorites-user-a', count: 5),
          (label: '照片', destination: 'photos-user-a', count: 7),
        ]) {
          testWidgets(
            'refreshes after ${entry.label} only for '
            'the current account=$isCurrentUser',
            (tester) async {
              when(() => userProfileCubit.load()).thenAnswer((_) async {});
              final router = await pumpViewWithRouter(
                tester,
                const UserProfileLoadSuccess(profile: _profile),
                isCurrentUser: isCurrentUser,
              );

              await tester.tap(find.text(entry.label));
              await tester.pumpAndSettle();
              expect(find.text(entry.destination), findsOneWidget);
              expect(
                router.state.uri.queryParameters['profileItemCount'],
                '${entry.count}',
              );
              verifyNever(() => userProfileCubit.load());

              router.pop();
              await tester.pumpAndSettle();

              expect(find.byType(UserProfileView), findsOneWidget);
              if (isCurrentUser) {
                verify(() => userProfileCubit.load()).called(1);
              } else {
                verifyNever(() => userProfileCubit.load());
              }
            },
          );
        }
      }
    });

    testWidgets('shows zero for profile information without known counts', (
      tester,
    ) async {
      const profile = UserProfile(
        id: 'user-a',
        name: '饭友 A',
        screenName: 'fanfou_a',
      );

      await pumpView(
        tester,
        const UserProfileLoadSuccess(profile: profile),
      );

      expect(find.text('0'), findsNWidgets(3));
    });

    testWidgets('extends information dividers across the full section width', (
      tester,
    ) async {
      await pumpView(
        tester,
        const UserProfileLoadSuccess(profile: _profile),
      );

      final sectionRect = tester.getRect(find.byType(ProfileMenuSection).first);
      final dividerRect = tester.getRect(find.byType(Divider).first);

      expect(dividerRect.left, sectionRect.left);
      expect(dividerRect.right, sectionRect.right);
    });

    testWidgets('keeps cached profile content visible while refreshing', (
      tester,
    ) async {
      await pumpView(
        tester,
        const UserProfileLoadInProgress(profile: _profile),
      );

      expect(find.text(_profile.name), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    group('load failure feedback', () {
      for (final profile in [null, _profile]) {
        testWidgets(
          'shows a snackbar without an action when loading fails '
          'with cached profile=${profile != null}',
          (tester) async {
            final states = StreamController<UserProfileState>();
            addTearDown(states.close);
            final loading = UserProfileLoadInProgress(profile: profile);
            whenListen(userProfileCubit, states.stream, initialState: loading);
            when(() => userProfileCubit.load()).thenAnswer((_) async {});
            await tester.pumpApp(
              Scaffold(
                body: BlocProvider.value(
                  value: userProfileCubit,
                  child: const UserProfileView(userId: 'user-a'),
                ),
              ),
            );
            final context = tester.element(find.byType(UserProfileView));
            expect(find.byType(SnackBar), findsNothing);

            states.add(UserProfileLoadFailure(profile: profile));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));

            expect(
              find.descendant(
                of: find.byType(SnackBar),
                matching: find.text(context.l10n.retryPageMessage),
              ),
              findsOneWidget,
            );
            expect(find.byType(AppRetryView), findsNothing);
            if (profile != null) {
              expect(find.text(profile.name), findsOneWidget);
              expect(find.byType(ProfileMenuSection), findsOneWidget);
            }

            expect(
              tester.widget<SnackBar>(find.byType(SnackBar)).action,
              isNull,
            );
            expect(find.byType(AppSnackBarAction), findsNothing);
            verifyNever(() => userProfileCubit.load());
            await tester.pump(const Duration(seconds: 5));
            await tester.pump(const Duration(milliseconds: 300));
            expect(find.byType(SnackBar), findsNothing);

            states
              ..add(loading)
              ..add(UserProfileLoadFailure(profile: profile));
            await tester.pump();
            await tester.pump(const Duration(seconds: 1));
            expect(find.byType(SnackBar), findsOneWidget);
          },
        );
      }
    });
  });
}

const _profile = UserProfile(
  id: 'user-a',
  name: '饭友 A',
  screenName: 'fanfou_a',
  avatarUrl: 'https://example.com/avatar.png',
  description: '写点什么。',
  location: '上海',
  url: 'https://example.com',
  gender: '男',
  followersCount: 12,
  friendsCount: 8,
  favoritesCount: 5,
  statusesCount: 42,
  photoCount: 7,
);
