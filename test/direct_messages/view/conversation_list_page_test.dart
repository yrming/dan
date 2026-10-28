import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dan/app/navigation/routes.dart';
import 'package:dan/app/view/app_subpage_app_bar.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/direct_messages/direct_messages.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:dan/notifications/notifications.dart';
import 'package:dan/profile/profile.dart';
import 'package:direct_message_repository/direct_message_repository.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Badge;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_repository/user_repository.dart';

import '../../helpers/helpers.dart';

class _MockDirectMessageRepository extends Mock
    implements DirectMessageRepository {}

class _MockUserRepository extends Mock implements UserRepository {}

class _MockNotificationCountsCubit extends MockCubit<NotificationCountsState>
    implements NotificationCountsCubit {}

DirectMessageConversation _conversationForUser(
  int index, {
  bool withProfile = false,
  bool hasUnread = false,
}) {
  return DirectMessageConversation(
    otherUserId: 'user-$index',
    otherUser: withProfile ? _peerDetails : null,
    lastMessage: DirectMessage(
      id: 'dm-$index',
      text: '最近在做什么？$index',
      createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
      senderId: 'user-$index',
      recipientId: 'account-a',
      senderScreenName: 'fanfou_b_$index',
    ),
    messageCount: index,
    hasUnread: hasUnread,
    otherUserScreenName: 'fanfou_b_$index',
    otherUserAvatarUrl: 'https://example.com/user-$index.png',
  );
}

void main() {
  group(ConversationListPage, () {
    late DirectMessageRepository directMessageRepository;
    late UserRepository userRepository;
    late NotificationCountsCubit notificationCountsCubit;
    UserProfile? cachedProfile;

    setUpAll(() {
      registerFallbackValue(_peerProfile);
    });

    const pageSize = 20;
    final conversation = _conversationForUser(1);
    final fullPage = List.generate(pageSize, _conversationForUser);

    setUp(() {
      directMessageRepository = _MockDirectMessageRepository();
      when(() => directMessageRepository.messageChanges).thenAnswer(
        (_) => const Stream.empty(),
      );
      userRepository = _MockUserRepository();
      notificationCountsCubit = _MockNotificationCountsCubit();
      when(
        () => notificationCountsCubit.state,
      ).thenReturn(const NotificationCountsInitial());
      cachedProfile = null;
      when(() => userRepository.cacheUser(any())).thenAnswer((invocation) {
        cachedProfile = invocation.positionalArguments.single as UserProfile;
      });
      when(
        () => userRepository.getCachedUser(any()),
      ).thenAnswer((_) => cachedProfile);
      when(
        () => userRepository.getUser(any()),
      ).thenAnswer((_) async => _peerProfile);
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
    });

    Future<void> pumpPage(WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: '/direct-messages',
        routes: [
          GoRoute(
            name: AppRouteName.userProfile,
            path: '/users/:userId',
            builder: (_, state) => RepositoryProvider.value(
              value: userRepository,
              child: BlocProvider.value(
                value: notificationCountsCubit,
                child: UserProfilePage(userId: state.pathParameters['userId']!),
              ),
            ),
          ),
          GoRoute(
            name: AppRouteName.directMessageList,
            path: '/direct-messages',
            builder: (_, _) => MultiRepositoryProvider(
              providers: [
                RepositoryProvider.value(value: directMessageRepository),
                RepositoryProvider.value(value: userRepository),
              ],
              child: const ConversationListPage(),
            ),
            routes: [
              GoRoute(
                name: AppRouteName.directMessageConversation,
                path: ':userId',
                builder: (context, state) => RepositoryProvider.value(
                  value: directMessageRepository,
                  child: ConversationPage(
                    userId: state.pathParameters['userId']!,
                    conversation: switch (state.extra) {
                      final DirectMessageConversation conversation =>
                        conversation,
                      _ => null,
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpRouterApp(router);
      await tester.pump();
      await tester.pump();
    }

    testWidgets('renders the direct messages title', (tester) async {
      await pumpPage(tester);
      final context = tester.element(find.byType(ConversationListPage));

      expect(
        find.descendant(
          of: find.byType(AppSubpageAppBar),
          matching: find.text(context.l10n.directMessagesPageTitle),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows shimmer skeletons while conversations are loading', (
      tester,
    ) async {
      final request = Completer<DirectMessageConversationPage>();
      when(
        () => directMessageRepository.getConversationList(
          limit: any(named: 'limit'),
          page: any(named: 'page'),
        ),
      ).thenAnswer((_) => request.future);

      await pumpPage(tester);

      expect(find.byType(ConversationListSkeleton), findsOneWidget);
      expect(find.byType(ShaderMask), findsOneWidget);
      expect(find.byType(CupertinoActivityIndicator), findsNothing);

      request.complete(
        const DirectMessageConversationPage(
          conversations: [],
          hasMore: false,
          nextPage: null,
        ),
      );
      await tester.pump();
    });

    testWidgets('renders conversation entries when the load succeeds', (
      tester,
    ) async {
      when(
        () => directMessageRepository.getConversationList(
          limit: any(named: 'limit'),
          page: any(named: 'page'),
        ),
      ).thenAnswer(
        (_) async => DirectMessageConversationPage(
          conversations: [conversation],
          hasMore: false,
          nextPage: null,
        ),
      );

      await pumpPage(tester);

      expect(find.text('fanfou_b_1'), findsOneWidget);
      expect(find.text('最近在做什么？1'), findsOneWidget);
      verify(
        () => directMessageRepository.getConversationList(
          limit: pageSize,
          page: 1,
        ),
      ).called(1);
    });

    testWidgets('renders the empty illustration without conversations', (
      tester,
    ) async {
      when(
        () => directMessageRepository.getConversationList(
          limit: any(named: 'limit'),
          page: any(named: 'page'),
        ),
      ).thenAnswer(
        (_) async => const DirectMessageConversationPage(
          conversations: [],
          hasMore: false,
          nextPage: null,
        ),
      );

      await pumpPage(tester);
      final context = tester.element(find.byType(ConversationListView));

      expect(find.byType(AppEmptyView), findsOneWidget);
      expect(find.text(context.l10n.directMessagesEmptyLabel), findsNothing);
    });

    testWidgets('renders the failure label with a working retry action', (
      tester,
    ) async {
      when(
        () => directMessageRepository.getConversationList(
          limit: any(named: 'limit'),
          page: any(named: 'page'),
        ),
      ).thenThrow(const DirectMessageRepositoryApiFailure(statusCode: 500));

      await pumpPage(tester);
      final context = tester.element(find.byType(ConversationListView));

      expect(
        find.text(context.l10n.retryPageMessage),
        findsOneWidget,
      );

      when(
        () => directMessageRepository.getConversationList(
          limit: any(named: 'limit'),
          page: any(named: 'page'),
        ),
      ).thenAnswer(
        (_) async => DirectMessageConversationPage(
          conversations: [conversation],
          hasMore: false,
          nextPage: null,
        ),
      );
      await tester.tap(find.text(context.l10n.retryButtonLabel));
      await tester.pump();
      await tester.pump();

      expect(find.text('fanfou_b_1'), findsOneWidget);
      verify(
        () => directMessageRepository.getConversationList(
          limit: any(named: 'limit'),
          page: any(named: 'page'),
        ),
      ).called(2);
    });

    testWidgets('opens the conversation when the last message is tapped', (
      tester,
    ) async {
      when(
        () => directMessageRepository.getConversationList(
          limit: any(named: 'limit'),
          page: any(named: 'page'),
        ),
      ).thenAnswer(
        (_) async => DirectMessageConversationPage(
          conversations: [conversation],
          hasMore: false,
          nextPage: null,
        ),
      );

      await pumpPage(tester);
      await tester.tap(find.text('最近在做什么？1'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(ConversationPage), findsOneWidget);
      final router = GoRouter.of(tester.element(find.byType(ConversationPage)));
      expect(
        router.state.uri.path,
        '/direct-messages/${conversation.otherUserId}',
      );
      expect(
        find.descendant(
          of: find.byType(ConversationPage),
          matching: find.text('fanfou_b_1'),
        ),
        findsOneWidget,
      );
    });

    group('opening an unread conversation', () {
      for (final historyFails in [false, true]) {
        testWidgets(
          'clears only the opened badge locally '
          'with historyFails=$historyFails',
          (tester) async {
            final unread = _conversationForUser(
              1,
              withProfile: true,
              hasUnread: true,
            );
            final otherUnread = _conversationForUser(2, hasUnread: true);
            when(
              () => directMessageRepository.getConversationList(
                limit: pageSize,
                page: 1,
              ),
            ).thenAnswer(
              (_) async => DirectMessageConversationPage(
                conversations: [unread, otherUnread],
                hasMore: false,
                nextPage: null,
              ),
            );
            if (historyFails) {
              when(
                () => directMessageRepository.getConversation(
                  'user-1',
                  limit: pageSize,
                  page: 1,
                ),
              ).thenThrow(const DirectMessageRepositoryUnknownFailure());
            }
            await pumpPage(tester);
            int unreadCount() => tester
                .widgetList<Badge>(find.byType(Badge))
                .where((badge) => badge.isLabelVisible)
                .length;
            expect(unreadCount(), 2);
            final bloc = tester
                .element(find.byType(ConversationListView))
                .read<ConversationListBloc>();
            await tester.tap(find.text('最近在做什么？1'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
            expect(find.byType(ConversationPage), findsOneWidget);
            expect(bloc.state.conversations, [
              _conversationForUser(1, withProfile: true),
              otherUnread,
            ]);

            GoRouter.of(tester.element(find.byType(ConversationPage))).pop();
            await tester.pumpAndSettle(
              const Duration(milliseconds: 100),
              EnginePhase.sendSemanticsUpdate,
              const Duration(seconds: 5),
            );
            expect(unreadCount(), 1);
            expect(find.text('最近在做什么？1'), findsOneWidget);
            expect(find.text('最近在做什么？2'), findsOneWidget);
            verify(
              () => directMessageRepository.getConversationList(
                limit: pageSize,
                page: 1,
              ),
            ).called(1);
          },
        );
      }
    });

    group('profile navigation', () {
      for (final target in ['avatar', 'nickname']) {
        for (final withProfile in [true, false]) {
          testWidgets(
            'opens profile from $target with details=$withProfile '
            'before refreshing',
            (tester) async {
              final profileRequest = Completer<UserProfile>();
              when(
                () => userRepository.getUser('user-1'),
              ).thenAnswer((_) => profileRequest.future);
              when(
                () => directMessageRepository.getConversationList(
                  limit: any(named: 'limit'),
                  page: any(named: 'page'),
                ),
              ).thenAnswer(
                (_) async => DirectMessageConversationPage(
                  conversations: [
                    _conversationForUser(
                      1,
                      withProfile: withProfile,
                      hasUnread: true,
                    ),
                  ],
                  hasMore: false,
                  nextPage: null,
                ),
              );
              await pumpPage(tester);
              final router = GoRouter.of(
                tester.element(find.byType(ConversationListPage)),
              );
              await tester.tap(
                target == 'avatar'
                    ? find.byType(UserAvatar)
                    : find.text('fanfou_b_1'),
              );
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 400));

              expect(find.byType(UserProfilePage), findsOneWidget);
              expect(router.state.uri.path, '/users/user-1');
              expect(
                router.state.uri.queryParameters['presentation'],
                'pushed',
              );
              expect(find.byType(ConversationPage), findsNothing);
              final header = tester.widget<ProfileHeader>(
                find.byType(ProfileHeader),
              );
              expect(header.id, 'user-1');
              expect(header.name, withProfile ? _peerProfile.name : '');
              expect(header.screenName, 'fanfou_b_1');
              expect(header.avatarUrl, 'https://example.com/user-1.png');
              if (withProfile) {
                expect(cachedProfile, _peerProfile);
                expect(find.text(_peerProfile.description!), findsOneWidget);
                expect(header.followersCount, 224);
                expect(header.friendsCount, 178);
              } else {
                expect(
                  cachedProfile,
                  const UserProfile(
                    id: 'user-1',
                    name: '',
                    screenName: 'fanfou_b_1',
                    avatarUrl: 'https://example.com/user-1.png',
                  ),
                );
              }
              verify(() => userRepository.getUser('user-1')).called(1);
              verifyNever(
                () => directMessageRepository.getConversation(
                  any(),
                  limit: any(named: 'limit'),
                  page: any(named: 'page'),
                ),
              );

              profileRequest.complete(
                const UserProfile(
                  id: 'user-1',
                  name: '更新后的昵称',
                  screenName: 'fanfou_b_1',
                  description: '更新后的简介',
                ),
              );
              await tester.pump();
              await tester.pump();
              expect(find.text('更新后的昵称'), findsOneWidget);
              expect(find.text('更新后的简介'), findsOneWidget);
              router.pop();
              await tester.pumpAndSettle(
                const Duration(milliseconds: 100),
                EnginePhase.sendSemanticsUpdate,
                const Duration(seconds: 5),
              );
              expect(find.byType(ConversationListPage), findsOneWidget);
              expect(find.text('最近在做什么？1'), findsOneWidget);
              expect(
                tester.widget<Badge>(find.byType(Badge)).isLabelVisible,
                isTrue,
              );
              verify(
                () => directMessageRepository.getConversationList(
                  limit: pageSize,
                  page: 1,
                ),
              ).called(1);
            },
          );
        }
      }
    });

    testWidgets('loads the next page when scrolled to the bottom', (
      tester,
    ) async {
      when(
        () => directMessageRepository.getConversationList(
          limit: pageSize,
          page: 1,
        ),
      ).thenAnswer(
        (_) async => DirectMessageConversationPage(
          conversations: fullPage,
          hasMore: true,
          nextPage: 2,
        ),
      );
      when(
        () => directMessageRepository.getConversationList(
          limit: pageSize,
          page: 2,
        ),
      ).thenAnswer(
        (_) async => DirectMessageConversationPage(
          conversations: [_conversationForUser(pageSize + 1)],
          hasMore: false,
          nextPage: null,
        ),
      );

      await pumpPage(tester);

      expect(find.text('fanfou_b_${pageSize + 1}'), findsNothing);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
      await tester.pump();
      await tester.pump();

      expect(find.text('fanfou_b_${pageSize + 1}'), findsOneWidget);
      verify(
        () => directMessageRepository.getConversationList(
          limit: pageSize,
          page: 2,
        ),
      ).called(1);
    });

    testWidgets('shows a toast and retries pagination on the next drag', (
      tester,
    ) async {
      when(
        () => directMessageRepository.getConversationList(
          limit: pageSize,
          page: 1,
        ),
      ).thenAnswer(
        (_) async => DirectMessageConversationPage(
          conversations: fullPage,
          hasMore: true,
          nextPage: 2,
        ),
      );
      when(
        () => directMessageRepository.getConversationList(
          limit: pageSize,
          page: 2,
        ),
      ).thenThrow(const DirectMessageRepositoryApiFailure(statusCode: 500));

      await pumpPage(tester);
      final context = tester.element(find.byType(ConversationListView));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
      await tester.pump();
      await tester.pump();

      expect(find.text(context.l10n.retryButtonLabel), findsNothing);
      expect(find.text(context.l10n.retryPageMessage), findsOneWidget);

      when(
        () => directMessageRepository.getConversationList(
          limit: pageSize,
          page: 2,
        ),
      ).thenAnswer(
        (_) async => DirectMessageConversationPage(
          conversations: [_conversationForUser(pageSize + 1)],
          hasMore: false,
          nextPage: null,
        ),
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump();
      await tester.pump();

      expect(find.text('fanfou_b_${pageSize + 1}'), findsOneWidget);
      verify(
        () => directMessageRepository.getConversationList(
          limit: pageSize,
          page: 2,
        ),
      ).called(2);
    });

    testWidgets('shows one skeleton item while loading the next page', (
      tester,
    ) async {
      final nextPageRequest = Completer<DirectMessageConversationPage>();
      when(
        () => directMessageRepository.getConversationList(
          limit: pageSize,
          page: 1,
        ),
      ).thenAnswer(
        (_) async => DirectMessageConversationPage(
          conversations: fullPage,
          hasMore: true,
          nextPage: 2,
        ),
      );
      when(
        () => directMessageRepository.getConversationList(
          limit: pageSize,
          page: 2,
        ),
      ).thenAnswer((_) => nextPageRequest.future);

      await pumpPage(tester);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
      await tester.pump();

      final skeleton = tester.widget<ConversationListSkeleton>(
        find.byType(ConversationListSkeleton),
      );
      expect(skeleton.itemCount, 1);
      expect(skeleton.shrinkWrap, isTrue);
      expect(find.byType(CupertinoActivityIndicator), findsNothing);

      nextPageRequest.complete(
        const DirectMessageConversationPage(
          conversations: [],
          hasMore: false,
          nextPage: null,
        ),
      );
      await tester.pump();
    });
  });
}

const _peerDetails = DirectMessageUser(
  id: 'user-1',
  name: '饭友 B',
  screenName: 'fanfou_b_1',
  avatarUrl: 'https://example.com/user-1.png',
  description: '对方简介',
  location: '上海',
  url: 'https://example.com/peer',
  protected: true,
  following: false,
  followersCount: 224,
  friendsCount: 178,
  favoritesCount: 135,
  statusesCount: 795,
  gender: '女',
  photoCount: 141,
  createdAt: 'Tue Apr 03 01:13:38 +0000 2012',
  birthday: '1990-12-02',
);

const _peerProfile = UserProfile(
  id: 'user-1',
  name: '饭友 B',
  screenName: 'fanfou_b_1',
  avatarUrl: 'https://example.com/user-1.png',
  description: '对方简介',
  location: '上海',
  url: 'https://example.com/peer',
  protected: true,
  following: false,
  followersCount: 224,
  friendsCount: 178,
  favoritesCount: 135,
  statusesCount: 795,
  gender: '女',
  photoCount: 141,
  createdAt: 'Tue Apr 03 01:13:38 +0000 2012',
  birthday: '1990-12-02',
);
