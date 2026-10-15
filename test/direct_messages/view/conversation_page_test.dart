import 'dart:async';

import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/direct_messages/direct_messages.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:direct_message_repository/direct_message_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:remixicon/remixicon.dart';
import 'package:user_repository/user_repository.dart';

import '../../helpers/helpers.dart';

class _MockDirectMessageRepository extends Mock
    implements DirectMessageRepository {}

class _MockUserRepository extends Mock implements UserRepository {}

DirectMessageHistoryPage historyPage(
  List<DirectMessage> messages, {
  bool hasMore = false,
  int? nextPage,
}) => DirectMessageHistoryPage(
  messages: messages,
  hasMore: hasMore,
  nextPage: nextPage,
);

void main() {
  group(ConversationPage, () {
    late DirectMessageRepository directMessageRepository;
    late UserRepository userRepository;

    const peerAvatarUrl = 'https://example.com/user-b.png';
    const activeAccountAvatarUrl = 'https://example.com/account-a.png';

    const incomingMessage = DirectMessage(
      id: 'dm-1',
      text: '最近在做什么？',
      createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
      senderId: 'user-b',
      recipientId: 'account-a',
      senderScreenName: 'fanfou_b',
    );

    const outgoingMessage = DirectMessage(
      id: 'dm-2',
      text: '刚出去跑步回来',
      createdAt: 'Tue Jul 28 00:10:00 +0000 2026',
      senderId: 'account-a',
      recipientId: 'user-b',
    );

    const linkMessage = DirectMessage(
      id: 'dm-link',
      text: 'https://example.com/article',
      createdAt: 'Tue Jul 28 00:20:00 +0000 2026',
      senderId: 'account-a',
      recipientId: 'user-b',
    );

    const conversation = DirectMessageConversation(
      otherUserId: 'user-b',
      lastMessage: incomingMessage,
      messageCount: 2,
      hasUnread: false,
      otherUserScreenName: 'fanfou_b',
      otherUserAvatarUrl: peerAvatarUrl,
    );

    const pageSize = 20;

    setUp(() {
      directMessageRepository = _MockDirectMessageRepository();
      userRepository = _MockUserRepository();
      when(() => userRepository.getCachedUser(any())).thenReturn(null);
    });

    Future<void> pumpPage(
      WidgetTester tester, {
      DirectMessageConversation? conversation,
      String? initialPeerScreenName,
      ThemeMode themeMode = ThemeMode.light,
    }) async {
      final router = GoRouter(
        initialLocation: '/direct-messages/user-b',
        routes: [
          GoRoute(
            path: '/direct-messages/:userId',
            builder: (_, _) => MultiRepositoryProvider(
              providers: [
                RepositoryProvider.value(value: directMessageRepository),
                RepositoryProvider.value(value: userRepository),
              ],
              child: ConversationPage(
                userId: 'user-b',
                activeAccountId: 'account-a',
                activeAccountAvatarUrl: activeAccountAvatarUrl,
                initialPeerScreenName: initialPeerScreenName,
                conversation: conversation,
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpRouterApp(router, themeMode: themeMode);
      await tester.pump();
      await tester.pump();
    }

    testWidgets('shows only a spinner while loading chat history', (
      tester,
    ) async {
      final request = Completer<DirectMessageHistoryPage>();
      when(
        () => directMessageRepository.getConversation(
          'user-b',
          limit: pageSize,
          page: 1,
        ),
      ).thenAnswer((_) => request.future);
      await pumpPage(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('正在加载聊天记录'), findsNothing);
      expect(find.bySemanticsLabel('正在加载聊天记录'), findsOneWidget);
      request.complete(historyPage(const []));
      await tester.pump();
    });

    testWidgets('titles the app bar with the passed conversation peer', (
      tester,
    ) async {
      await pumpPage(tester, conversation: conversation);

      expect(find.text('fanfou_b'), findsOneWidget);
      verify(
        () => directMessageRepository.getConversation(
          'user-b',
          limit: 20,
          page: 1,
        ),
      ).called(1);
    });

    testWidgets('titles the app bar with the passed peer screen name', (
      tester,
    ) async {
      when(
        () => directMessageRepository.getConversation(
          'user-b',
          limit: 20,
          page: 1,
        ),
      ).thenAnswer((_) async => historyPage(const []));

      await pumpPage(tester, initialPeerScreenName: 'fanfou_b');

      expect(find.text('fanfou_b'), findsOneWidget);
    });

    testWidgets(
      'falls back to the peer screen name from the loaded messages',
      (tester) async {
        when(
          () => directMessageRepository.getConversation(
            'user-b',
            limit: 20,
            page: 1,
          ),
        ).thenAnswer((_) async => historyPage(const [incomingMessage]));

        await pumpPage(tester);

        expect(find.text('fanfou_b'), findsOneWidget);
      },
    );

    testWidgets('uses the fallback title when the peer name is unknown', (
      tester,
    ) async {
      when(
        () => directMessageRepository.getConversation(
          'user-b',
          limit: 20,
          page: 1,
        ),
      ).thenAnswer((_) async => historyPage(const []));

      await pumpPage(tester);
      final context = tester.element(find.byType(ConversationView));

      expect(
        find.text(context.l10n.directMessageConversationFallbackTitle),
        findsOneWidget,
      );
    });

    testWidgets('renders messages aligned by sender', (tester) async {
      when(
        () => directMessageRepository.getConversation(
          'user-b',
          limit: 20,
          page: 1,
        ),
      ).thenAnswer(
        (_) async => historyPage(const [incomingMessage, outgoingMessage]),
      );

      await pumpPage(tester, conversation: conversation);

      final incomingText = tester.getCenter(find.text(incomingMessage.text));
      final outgoingText = tester.getCenter(find.text(outgoingMessage.text));
      final screenCenter = tester.getSize(find.byType(Scaffold)).width / 2;

      expect(incomingText.dx, lessThan(screenCenter));
      expect(outgoingText.dx, greaterThan(screenCenter));
      expect(find.byType(UserAvatar), findsNothing);
      expect(
        find.descendant(
          of: find.byType(DirectMessageBubble),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
    });

    testWidgets('renders outgoing bubbles with the configured color', (
      tester,
    ) async {
      when(
        () => directMessageRepository.getConversation(
          'user-b',
          limit: 20,
          page: 1,
        ),
      ).thenAnswer((_) async => historyPage(const [outgoingMessage]));

      await pumpPage(tester);

      final bubble = tester.widget<Container>(
        find
            .ancestor(
              of: find.text(outgoingMessage.text),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        (bubble.decoration! as BoxDecoration).color,
        AppColors.danLight.wechatGreen,
      );

      final borderRadius = (bubble.decoration! as BoxDecoration).borderRadius!;
      expect(borderRadius, BorderRadius.circular(18));
    });

    testWidgets('sends a message from the composer', (tester) async {
      when(
        () => directMessageRepository.getConversation(
          'user-b',
          limit: 20,
          page: 1,
        ),
      ).thenAnswer((_) async => historyPage(const [incomingMessage]));
      when(
        () => directMessageRepository.sendMessage('user-b', '新消息'),
      ).thenAnswer((_) async => outgoingMessage);

      await pumpPage(tester);
      final textField = find.byType(TextField);
      await tester.enterText(textField, '新消息');
      await tester.pump();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
      await tester.tap(find.byIcon(RemixIcons.send_ins_line));
      await tester.pump();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );

      verify(
        () => directMessageRepository.sendMessage('user-b', '新消息'),
      ).called(1);
      expect(find.text(outgoingMessage.text), findsOneWidget);
    });

    testWidgets(
      'hides the send button and expands the input while the draft is blank',
      (tester) async {
        when(
          () => directMessageRepository.getConversation(
            'user-b',
            limit: 20,
            page: 1,
          ),
        ).thenAnswer((_) async => historyPage(const [incomingMessage]));

        await pumpPage(tester);
        final sendButton = find.byIcon(RemixIcons.send_ins_line);
        final emptyInputWidth = tester.getSize(find.byType(TextField)).width;

        expect(sendButton, findsNothing);

        await tester.enterText(find.byType(TextField), '新消息');
        await tester.pump();

        expect(sendButton, findsOneWidget);
        expect(
          tester.getSize(find.byType(TextField)).width,
          lessThan(emptyInputWidth),
        );

        await tester.enterText(find.byType(TextField), '   ');
        await tester.pump();

        expect(sendButton, findsNothing);
        expect(tester.getSize(find.byType(TextField)).width, emptyInputWidth);
      },
    );

    testWidgets(
      'renders the send button as a rounded send icon button',
      (
        tester,
      ) async {
        when(
          () => directMessageRepository.getConversation(
            'user-b',
            limit: 20,
            page: 1,
          ),
        ).thenAnswer((_) async => historyPage(const [incomingMessage]));

        await pumpPage(tester);
        final context = tester.element(find.byType(ConversationView));
        await tester.enterText(find.byType(TextField), '新消息');
        await tester.pump();
        final button = tester.widget<TextButton>(
          find
              .ancestor(
                of: find.byIcon(RemixIcons.send_ins_line),
                matching: find.byType(TextButton),
              )
              .first,
        );

        expect(
          button.style?.backgroundColor?.resolve({}),
          context.appColors.wechatGreen,
        );
        expect(
          button.style?.foregroundColor?.resolve({}),
          AppColors.wechatGreenForeground,
        );
        final shape =
            button.style?.shape?.resolve({}) ??
            Theme.of(context).textButtonTheme.style!.shape!.resolve({});
        expect(
          shape,
          const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        );
        expect(find.text(context.l10n.sendButtonLabel), findsNothing);
        expect(
          tester.getSize(
            find
                .ancestor(
                  of: find.byIcon(RemixIcons.send_ins_line),
                  matching: find.byType(TextButton),
                )
                .first,
          ),
          Size(
            context.appSizing.scaled(50),
            context.appSizing.scaled(34),
          ),
        );
      },
    );

    testWidgets('matches the bottom navigation bar content height', (
      tester,
    ) async {
      when(
        () => directMessageRepository.getConversation(
          'user-b',
          limit: 20,
          page: 1,
        ),
      ).thenAnswer((_) async => historyPage(const [incomingMessage]));

      await pumpPage(tester);
      final context = tester.element(find.byType(ConversationView));

      expect(
        tester
            .getSize(find.byKey(const Key('conversation-message-composer')))
            .height,
        greaterThanOrEqualTo(context.appSizing.bottomNavigationBarHeight),
      );
      expect(
        tester.getSize(find.byType(TextField)).height,
        context.appSizing.scaled(44),
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).clipBehavior,
        Clip.none,
      );
    });

    testWidgets('uses base composer background and 16px input padding', (
      tester,
    ) async {
      when(
        () => directMessageRepository.getConversation(
          'user-b',
          limit: 20,
          page: 1,
        ),
      ).thenAnswer((_) async => historyPage(const [incomingMessage]));

      await pumpPage(tester);
      final context = tester.element(find.byType(ConversationView));
      final composer = tester.widget<DecoratedBox>(
        find.byKey(const Key('conversation-message-composer')),
      );
      final padding = tester.widget<Padding>(
        find.byKey(const Key('conversation-message-composer-padding')),
      );
      final textField = tester.widget<TextField>(find.byType(TextField));

      expect(
        (composer.decoration as BoxDecoration).color,
        context.appColors.bgBase,
      );
      expect(
        (composer.decoration as BoxDecoration).border,
        Border(
          top: BorderSide(
            color: context.appColors.divider,
            width: 0,
          ),
        ),
      );
      expect(
        padding.padding,
        EdgeInsets.all(context.appSizing.scaled(AppSpacing.md)),
      );
      expect(
        textField.decoration!.fillColor,
        context.appColors.directMessageInputBackground,
      );
      expect(
        (textField.decoration!.border! as OutlineInputBorder).borderRadius,
        BorderRadius.circular(context.appSizing.scaled(22)),
      );
    });

    testWidgets('uses the dark input background in dark mode', (tester) async {
      when(
        () => directMessageRepository.getConversation(
          'user-b',
          limit: 20,
          page: 1,
        ),
      ).thenAnswer((_) async => historyPage(const [incomingMessage]));

      await pumpPage(tester, themeMode: ThemeMode.dark);
      final context = tester.element(find.byType(ConversationView));
      final composer = tester.widget<DecoratedBox>(
        find.byKey(const Key('conversation-message-composer')),
      );
      final textField = tester.widget<TextField>(find.byType(TextField));

      expect(
        (composer.decoration as BoxDecoration).color,
        context.appColors.bgBase,
      );
      expect(
        (composer.decoration as BoxDecoration).border,
        Border(
          top: BorderSide(
            color: context.appColors.divider,
            width: 0,
          ),
        ),
      );
      expect(
        textField.decoration!.fillColor,
        const Color(0xFF1E1E1E),
      );
      expect(
        (textField.decoration!.border! as OutlineInputBorder).borderRadius,
        BorderRadius.circular(context.appSizing.scaled(22)),
      );
    });

    testWidgets('expands the composer for multiline input', (tester) async {
      when(
        () => directMessageRepository.getConversation(
          'user-b',
          limit: 20,
          page: 1,
        ),
      ).thenAnswer((_) async => historyPage(const [incomingMessage]));

      await pumpPage(tester);
      await tester.enterText(
        find.byType(TextField),
        List.filled(8, '多行消息').join('\n'),
      );
      await tester.pump();

      expect(
        tester.getSize(find.byType(TextField)).height,
        greaterThan(40),
      );
      expect(
        tester
            .getSize(find.byKey(const Key('conversation-message-composer')))
            .height,
        greaterThan(50),
      );
    });

    testWidgets('renders link messages with the direct-message link color', (
      tester,
    ) async {
      when(
        () => directMessageRepository.getConversation(
          'user-b',
          limit: 20,
          page: 1,
        ),
      ).thenAnswer((_) async => historyPage(const [linkMessage]));

      await pumpPage(tester);
      final context = tester.element(find.byType(ConversationView));
      final text = tester.widget<Text>(find.text(linkMessage.text));
      final linkSpan = (text.textSpan! as TextSpan).children!
          .cast<TextSpan>()
          .singleWhere((span) => span.text == linkMessage.text);

      expect(linkSpan.style?.color, context.appColors.directMessageLinkText);
    });

    testWidgets('loads earlier messages when scrolled near the top', (
      tester,
    ) async {
      final fullPage = List.generate(
        pageSize,
        (index) => DirectMessage(
          id: 'dm-$index',
          text: '消息 $index',
          createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
          senderId: index.isEven ? 'user-b' : 'account-a',
          recipientId: 'account-a',
        ),
      );
      when(
        () => directMessageRepository.getConversation(
          'user-b',
          limit: 20,
          page: 1,
        ),
      ).thenAnswer(
        (_) async => historyPage(fullPage, hasMore: true, nextPage: 2),
      );
      when(
        () => directMessageRepository.getConversation(
          'user-b',
          limit: 20,
          page: 2,
        ),
      ).thenAnswer(
        (_) async => historyPage([
          const DirectMessage(
            id: 'dm-old-1',
            text: '更早的一条消息',
            createdAt: 'Mon Jul 27 00:00:00 +0000 2026',
            senderId: 'user-b',
            recipientId: 'account-a',
          ),
        ]),
      );

      await pumpPage(tester);
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, 600));
      await tester.pump();
      await tester.pump();

      // The older page is loaded; scroll up to it to confirm it is rendered.
      await tester.drag(find.byType(ListView), const Offset(0, 2000));
      await tester.pump();

      verify(
        () => directMessageRepository.getConversation(
          'user-b',
          limit: 20,
          page: 2,
        ),
      ).called(1);
      expect(find.text('更早的一条消息'), findsOneWidget);
    });

    testWidgets('keeps the scroll position when earlier messages are '
        'inserted', (tester) async {
      final fullPage = List.generate(
        pageSize,
        (index) => DirectMessage(
          id: 'dm-$index',
          text: '消息 $index',
          createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
          senderId: index.isEven ? 'user-b' : 'account-a',
          recipientId: 'account-a',
        ),
      );
      when(
        () => directMessageRepository.getConversation(
          'user-b',
          limit: 20,
          page: 1,
        ),
      ).thenAnswer(
        (_) async => historyPage(fullPage, hasMore: true, nextPage: 2),
      );
      when(
        () => directMessageRepository.getConversation(
          'user-b',
          limit: 20,
          page: 2,
        ),
      ).thenAnswer(
        (_) async => historyPage(
          List.generate(
            pageSize,
            (index) => DirectMessage(
              id: 'dm-old-$index',
              text: '更早的消息 $index',
              createdAt: 'Mon Jul 27 00:00:00 +0000 2026',
              senderId: 'user-b',
              recipientId: 'account-a',
            ),
          ),
        ),
      );

      await pumpPage(tester);
      await tester.pump();
      final position = tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byKey(const Key('conversation-message-list')),
              matching: find.byType(Scrollable),
            ),
          )
          .position;
      final maxExtentBefore = position.maxScrollExtent;

      // A drag past the history trigger loads the older page. Older
      // messages are appended at the far end of the reversed list, so the
      // viewport must not move at all.
      await tester.drag(find.byType(ListView), const Offset(0, 400));
      await tester.pump();
      final offsetAfterTrigger = position.pixels;

      await tester.pump();
      await tester.pump();

      expect(position.maxScrollExtent, greaterThan(maxExtentBefore));
      expect(position.pixels, equals(offsetAfterTrigger));
      expect(find.text('消息 6'), findsOneWidget);

      // Scroll to the boundary to confirm the older page rendered above the
      // previously loaded messages.
      await tester.drag(find.byType(ListView), const Offset(0, 800));
      await tester.pump();
      expect(find.text('更早的消息 0'), findsOneWidget);
    });

    testWidgets('uses the base background behind the bubbles', (
      tester,
    ) async {
      when(
        () => directMessageRepository.getConversation(
          'user-b',
          limit: 20,
          page: 1,
        ),
      ).thenAnswer((_) async => historyPage(const [incomingMessage]));

      await pumpPage(tester);
      final context = tester.element(find.byType(ConversationView));

      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        context.appColors.bgBase,
      );
    });

    testWidgets('renders the empty label for an empty conversation', (
      tester,
    ) async {
      when(
        () => directMessageRepository.getConversation(
          'user-b',
          limit: 20,
          page: 1,
        ),
      ).thenAnswer((_) async => historyPage(const []));

      await pumpPage(tester);
      final context = tester.element(find.byType(ConversationView));

      expect(
        find.text(context.l10n.directMessageConversationEmptyLabel),
        findsOneWidget,
      );
    });

    testWidgets('renders the failure label with a working retry action', (
      tester,
    ) async {
      when(
        () => directMessageRepository.getConversation(
          'user-b',
          limit: 20,
          page: 1,
        ),
      ).thenThrow(const DirectMessageRepositoryUnknownFailure());

      await pumpPage(tester);
      final context = tester.element(find.byType(ConversationView));

      expect(
        find.text(context.l10n.retryPageMessage),
        findsOneWidget,
      );

      when(
        () => directMessageRepository.getConversation(
          'user-b',
          limit: 20,
          page: 1,
        ),
      ).thenAnswer((_) async => historyPage(const [incomingMessage]));
      await tester.tap(find.text(context.l10n.retryButtonLabel));
      await tester.pump();
      await tester.pump();

      expect(find.text(incomingMessage.text), findsOneWidget);
      verify(
        () => directMessageRepository.getConversation(
          'user-b',
          limit: 20,
          page: 1,
        ),
      ).called(2);
    });
  });
}
