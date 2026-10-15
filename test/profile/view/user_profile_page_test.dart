import 'dart:async';

import 'package:authentication_repository/authentication_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:dan/app/navigation/routes.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/view/app_subpage_app_bar.dart';
import 'package:dan/direct_messages/direct_messages.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:dan/notifications/notifications.dart';
import 'package:dan/profile/profile.dart';
import 'package:direct_message_repository/direct_message_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:remixicon/remixicon.dart';
import 'package:user_repository/user_repository.dart';

import '../../helpers/helpers.dart';

class _MockUserRepository extends Mock implements UserRepository {}

class _MockAuthenticationRepository extends Mock
    implements AuthenticationRepository {}

class _MockDirectMessageRepository extends Mock
    implements DirectMessageRepository {}

class _MockNotificationCountsCubit extends MockCubit<NotificationCountsState>
    implements NotificationCountsCubit {}

void main() {
  setUpAll(() {
    registerFallbackValue(_account);
  });

  group(UserProfilePage, () {
    late UserRepository userRepository;
    late AuthenticationRepository authenticationRepository;
    late DirectMessageRepository directMessageRepository;
    late NotificationCountsCubit notificationCountsCubit;

    setUp(() {
      userRepository = _MockUserRepository();
      authenticationRepository = _MockAuthenticationRepository();
      directMessageRepository = _MockDirectMessageRepository();
      notificationCountsCubit = _MockNotificationCountsCubit();
      when(() => notificationCountsCubit.state).thenReturn(
        const NotificationCountsLoadSuccess(counts: _notificationCounts),
      );
      when(
        () => authenticationRepository.updateAccount(any()),
      ).thenAnswer(
        (invocation) async =>
            invocation.positionalArguments.single as AuthenticatedAccount,
      );
      when(
        () => userRepository.getCachedUser(any()),
      ).thenReturn(null);
      when(
        () => directMessageRepository.getConversation(
          any(),
          limit: any(named: 'limit'),
          page: any(named: 'page'),
        ),
      ).thenAnswer(
        (_) async => const DirectMessageHistoryPage(
          messages: [],
          hasMore: false,
          nextPage: null,
        ),
      );
      when(
        () => userRepository.getUser('another-user'),
      ).thenAnswer((_) async => _otherProfile);
      when(
        () => userRepository.isFollowing(
          userId: 'another-user',
          targetUserId: _account.id,
        ),
      ).thenAnswer((_) async => false);
    });

    Future<void> pumpPage(WidgetTester tester, String userId) {
      return tester.pumpApp(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider.value(value: userRepository),
            RepositoryProvider.value(value: authenticationRepository),
          ],
          child: BlocProvider.value(
            value: notificationCountsCubit,
            child: UserProfilePage(
              userId: userId,
              activeAccount: _account,
            ),
          ),
        ),
      );
    }

    testWidgets('renders the shared profile view for the active account', (
      tester,
    ) async {
      final profileRequest = Completer<UserProfile>();
      when(
        () => userRepository.getUser(_account.id),
      ).thenAnswer((_) => profileRequest.future);

      await pumpPage(tester, _account.id);

      expect(find.byType(UserProfileView), findsOneWidget);
      final profileAppBar = tester.widget<AppSubpageAppBar>(
        find.byType(AppSubpageAppBar),
      );
      expect(profileAppBar.title, isNull);
      expect(profileAppBar.showBottomDivider, isFalse);
      expect(profileAppBar.automaticallyImplyLeading, isTrue);
      expect(
        profileAppBar.actionsPadding,
        const EdgeInsetsDirectional.only(end: AppSpacing.xxs),
      );
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
      expect(find.byIcon(RemixIcons.menu_2_line), findsNothing);
      expect(find.byIcon(RemixIcons.search_line), findsOneWidget);
      expect(find.byIcon(RemixIcons.mail_line), findsOneWidget);
      expect(find.byIcon(RemixIcons.send_ins_line), findsNothing);
      expect(find.byIcon(RemixIcons.more_line), findsNothing);
      final pageContext = tester.element(find.byType(UserProfilePage));
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, RemixIcons.search_line),
            )
            .tooltip,
        pageContext.l10n.userProfileSearchLabel,
      );
      expect(
        tester.widget<Icon>(find.byIcon(RemixIcons.search_line)).color,
        pageContext.appColors.textBase,
      );
      expect(
        tester.getRect(find.byIcon(RemixIcons.search_line)).right,
        lessThan(tester.getRect(find.byIcon(RemixIcons.mail_line)).left),
      );
      expect(
        tester.widget<Icon>(find.byIcon(RemixIcons.mail_line)).color,
        tester.element(find.byType(UserProfilePage)).appColors.textBase,
      );
      final mailIconRect = tester.getRect(find.byIcon(RemixIcons.mail_line));
      final mailButtonRect = tester.getRect(
        find.widgetWithIcon(IconButton, RemixIcons.mail_line),
      );
      final pageRect = tester.getRect(find.byType(Scaffold));
      expect(
        pageRect.right - mailIconRect.right,
        closeTo(AppSpacing.md, 1),
      );
      expect(mailButtonRect.width, greaterThanOrEqualTo(44));
      expect(mailButtonRect.height, greaterThanOrEqualTo(44));
      expect(find.text(_account.description!), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      verify(() => userRepository.getUser(_account.id)).called(1);

      profileRequest.complete(_refreshedAccountProfile);
      await tester.pump();

      expect(find.text(_refreshedAccountProfile.description!), findsOneWidget);
      final context = tester.element(find.byType(UserProfileView));
      expect(
        find.text(
          '${_refreshedAccountProfile.friendsCount} '
          '${context.l10n.userProfileFollowingLabel}',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          '${_refreshedAccountProfile.followersCount} '
          '${context.l10n.userProfileFollowersLabel}',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          context.l10n.userProfileFollowRequestsCount(
            _notificationCounts.friendRequests,
          ),
        ),
        findsOneWidget,
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
      verify(
        () => authenticationRepository.updateAccount(
          _refreshedAccount,
        ),
      ).called(1);
      verifyNever(() => userRepository.getNotificationCounts());
    });

    testWidgets('renders the active account inside the shell without chrome', (
      tester,
    ) async {
      when(
        () => userRepository.getUser(_account.id),
      ).thenAnswer((_) async => _refreshedAccountProfile);

      await tester.pumpApp(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider.value(value: userRepository),
            RepositoryProvider.value(value: authenticationRepository),
          ],
          child: BlocProvider.value(
            value: notificationCountsCubit,
            child: const Scaffold(
              body: MinePage(activeAccount: _account),
            ),
          ),
        ),
      );

      expect(find.byType(MinePage), findsOneWidget);
      expect(find.byType(UserProfileView), findsOneWidget);
      expect(find.byType(AppSubpageAppBar), findsNothing);
      expect(find.text(_account.description!), findsOneWidget);
    });

    testWidgets('renders a user profile for another account identifier', (
      tester,
    ) async {
      final profileRequest = Completer<UserProfile>();
      when(
        () => userRepository.getUser('another-user'),
      ).thenAnswer((_) => profileRequest.future);
      await pumpPage(tester, 'another-user');

      expect(find.byType(UserProfileView), findsOneWidget);
      final profileAppBar = tester.widget<AppSubpageAppBar>(
        find.byType(AppSubpageAppBar),
      );
      expect(profileAppBar.title, isNull);
      expect(profileAppBar.showBottomDivider, isFalse);
      expect(profileAppBar.automaticallyImplyLeading, isTrue);
      expect(tester.widget<AppBar>(find.byType(AppBar)).shape, const Border());
      expect(find.byType(BackButton), findsNothing);
      final searchButtonCenterBeforeLoad = tester.getCenter(
        find.widgetWithIcon(IconButton, RemixIcons.search_line),
      );
      expect(find.byIcon(RemixIcons.menu_2_line), findsNothing);
      expect(find.byIcon(RemixIcons.search_line), findsOneWidget);
      expect(find.byIcon(RemixIcons.mail_line), findsNothing);
      expect(find.byIcon(RemixIcons.send_ins_line), findsOneWidget);
      expect(find.byIcon(RemixIcons.more_line), findsOneWidget);
      expect(find.text('求关'), findsNothing);
      expect(find.text('用户主页'), findsNothing);
      final skeleton = find.byKey(const Key('user-profile-follow-skeleton'));
      expect(skeleton, findsOneWidget);
      expect(find.byKey(const Key('user-profile-follow-action')), findsNothing);
      final skeletonRect = tester.getRect(skeleton);
      profileRequest.complete(_otherProfile);
      await tester.pump();
      expect(find.text(_otherProfile.name), findsOneWidget);
      expect(find.byIcon(RemixIcons.add_line), findsOneWidget);
      expect(
        find.byKey(const Key('user-profile-follow-action')),
        findsOneWidget,
      );
      expect(skeleton, findsNothing);
      expect(
        tester.getRect(find.byKey(const Key('user-profile-follow-action'))),
        skeletonRect,
      );
      expect(
        tester.getCenter(
          find.widgetWithIcon(IconButton, RemixIcons.search_line),
        ),
        searchButtonCenterBeforeLoad,
      );
      verifyNever(() => userRepository.getNotificationCounts());
    });

    for (final message in ['已向 小婴 发出关注请求，请等待确认。', null]) {
      testWidgets('shows follow failure feedback for message=$message', (
        tester,
      ) async {
        when(
          () => userRepository.setFollowing('another-user', following: true),
        ).thenThrow(FollowActionFailure(message: message));
        await pumpPage(tester, 'another-user');
        await tester.pump();
        await tester.tap(find.byKey(const Key('user-profile-follow-action')));
        await tester.pump();
        expect(find.text(message ?? '操作失败，请重试'), findsOneWidget);
        expect(find.byIcon(RemixIcons.add_line), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('user-profile-follow-action')),
              )
              .onPressed,
          isNotNull,
        );
        verify(
          () => userRepository.setFollowing('another-user', following: true),
        ).called(1);
      });
    }

    testWidgets('shows followed with a check for a one-way followed account', (
      tester,
    ) async {
      when(() => userRepository.getUser('another-user')).thenAnswer(
        (_) async => _followedProfile,
      );

      await pumpPage(tester, 'another-user');
      await tester.pump();

      expect(find.text('已关注'), findsOneWidget);
      expect(find.byIcon(RemixIcons.check_line), findsOneWidget);
    });

    testWidgets('shows mutual follow for a mutually followed account', (
      tester,
    ) async {
      when(() => userRepository.getUser('another-user')).thenAnswer(
        (_) async => _mutualProfile,
      );
      when(
        () => userRepository.isFollowing(
          userId: 'another-user',
          targetUserId: _account.id,
        ),
      ).thenAnswer((_) async => true);
      await pumpPage(tester, 'another-user');
      await tester.pump();

      expect(find.text('互相关注'), findsOneWidget);
      expect(find.byIcon(RemixIcons.arrow_left_right_line), findsOneWidget);
      verify(
        () => userRepository.isFollowing(
          userId: 'another-user',
          targetUserId: _account.id,
        ),
      ).called(1);
    });

    testWidgets('opens the protected content dialog for a protected account '
        'being viewed', (tester) async {
      when(() => userRepository.getUser('another-user')).thenAnswer(
        (_) async => _protectedOtherProfile,
      );
      await pumpPage(tester, 'another-user');
      await tester.pump();
      final context = tester.element(find.byType(UserProfileView));
      final l10n = context.l10n;

      await tester.tap(find.text(l10n.userProfileMessagesLabel));
      await tester.pumpAndSettle();

      expect(find.text(l10n.userProfileProtectedDialogTitle), findsOneWidget);
      expect(
        find.text(l10n.userProfileProtectedDialogContent),
        findsOneWidget,
      );
    });

    testWidgets('opens the conversation with the viewed user from the chat '
        'action', (tester) async {
      when(
        () => userRepository.getUser('another-user'),
      ).thenAnswer((_) async => _otherProfile);
      when(
        () => userRepository.getCachedUser('another-user'),
      ).thenReturn(_otherProfile);
      when(
        () => directMessageRepository.getConversation(
          'another-user',
          limit: 20,
          page: 1,
        ),
      ).thenAnswer(
        (_) async => const DirectMessageHistoryPage(
          messages: [],
          hasMore: false,
          nextPage: null,
        ),
      );
      final router = GoRouter(
        initialLocation: '/users/another-user',
        routes: [
          GoRoute(
            path: '/users/:userId',
            builder: (_, _) => MultiRepositoryProvider(
              providers: [
                RepositoryProvider.value(value: userRepository),
                RepositoryProvider.value(value: authenticationRepository),
                RepositoryProvider.value(value: directMessageRepository),
              ],
              child: BlocProvider.value(
                value: notificationCountsCubit,
                child: const UserProfilePage(userId: 'another-user'),
              ),
            ),
          ),
          GoRoute(
            name: AppRouteName.directMessageConversation,
            path: '/direct-messages/:userId',
            builder: (_, state) => MultiRepositoryProvider(
              providers: [
                RepositoryProvider.value(value: directMessageRepository),
                RepositoryProvider.value(value: userRepository),
              ],
              child: ConversationPage(
                userId: 'another-user',
                initialPeerScreenName: state.uri.queryParameters['screenName'],
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpRouterApp(router);
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(RemixIcons.send_ins_line));
      await tester.pump();
      await tester.pump();

      expect(find.byType(ConversationPage), findsOneWidget);
      expect(
        GoRouter.of(
          tester.element(find.byType(ConversationPage)),
        ).state.uri.path,
        '/direct-messages/another-user',
      );
      expect(
        find.descendant(
          of: find.byType(ConversationPage),
          matching: find.text(_otherProfile.screenName),
        ),
        findsOneWidget,
      );
      verify(
        () => directMessageRepository.getConversation(
          'another-user',
          limit: 20,
          page: 1,
        ),
      ).called(1);
    });

    testWidgets('shows trailing chat and more actions for another user', (
      tester,
    ) async {
      await pumpPage(tester, 'another-user');

      final pageContext = tester.element(find.byType(UserProfilePage));
      final moreIconFinder = find.byIcon(RemixIcons.more_line);
      final moreButtonFinder = find.widgetWithIcon(
        IconButton,
        RemixIcons.more_line,
      );
      final moreButton = tester.widget<IconButton>(moreButtonFinder);
      final moreIconRect = tester.getRect(moreIconFinder);
      final moreButtonRect = tester.getRect(moreButtonFinder);
      final pageRect = tester.getRect(find.byType(Scaffold));

      final chatButton = tester.widget<FilledButton>(
        find.byKey(const Key('user-profile-message-action')),
      );
      expect(chatButton.onPressed, isNotNull);
      expect(
        find.text(pageContext.l10n.userProfileSendMessageLabel),
        findsOneWidget,
      );
      expect(
        moreButton.tooltip,
        MaterialLocalizations.of(pageContext).moreButtonTooltip,
      );
      expect(moreButton.onPressed, isNotNull);
      expect(
        tester.widget<Icon>(moreIconFinder).color,
        pageContext.appColors.textBase,
      );
      expect(
        pageRect.right - moreIconRect.right,
        closeTo(AppSpacing.md, 1),
      );
      expect(
        tester
            .getSize(find.byKey(const Key('user-profile-message-action')))
            .height,
        34,
      );
      expect(moreButtonRect.width, greaterThanOrEqualTo(44));
      expect(moreButtonRect.height, greaterThanOrEqualTo(44));
    });
  });
}

const _account = AuthenticatedAccount(
  id: 'account-id',
  name: 'Account',
  screenName: 'account',
  description: 'Current account biography',
  location: 'Shanghai',
  followersCount: 12,
  friendsCount: 8,
  favoritesCount: 5,
  statusesCount: 42,
  gender: '男',
  photoCount: 7,
  createdAt: 'Wed Nov 02 07:49:55 +0000 2011',
  birthday: '1990-01-02',
);

const _otherProfile = UserProfile(
  id: 'another-user',
  name: 'Another User',
  screenName: 'another',
);

const _protectedOtherProfile = UserProfile(
  id: 'another-user',
  name: 'Protected User',
  screenName: 'protected',
  protected: true,
  following: false,
);

const _mutualProfile = UserProfile(
  id: 'another-user',
  name: 'Mutual User',
  screenName: 'mutual',
  following: true,
);

const _followedProfile = UserProfile(
  id: 'another-user',
  name: 'Followed User',
  screenName: 'followed',
  following: true,
);

const _notificationCounts = UserNotificationCounts(
  mentions: 2,
  directMessages: 3,
  friendRequests: 4,
);

const _refreshedAccountProfile = UserProfile(
  id: 'account-id',
  name: 'Refreshed Account',
  screenName: 'account',
  description: 'Refreshed current account biography',
  location: 'Shanghai',
  protected: false,
  following: true,
  followersCount: 13,
  friendsCount: 8,
  favoritesCount: 5,
  statusesCount: 43,
  gender: '男',
  photoCount: 8,
  createdAt: 'Wed Nov 02 07:49:55 +0000 2011',
  birthday: '1990-01-02',
);

const _refreshedAccount = AuthenticatedAccount(
  id: 'account-id',
  name: 'Refreshed Account',
  screenName: 'account',
  description: 'Refreshed current account biography',
  location: 'Shanghai',
  protected: false,
  following: true,
  followersCount: 13,
  friendsCount: 8,
  favoritesCount: 5,
  statusesCount: 43,
  gender: '男',
  photoCount: 8,
  createdAt: 'Wed Nov 02 07:49:55 +0000 2011',
  birthday: '1990-01-02',
);
