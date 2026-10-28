import 'package:dan/app/theme/app_colors.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/direct_messages/direct_messages.dart';
import 'package:direct_message_repository/direct_message_repository.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group(DirectMessageBubble, () {
    const message = DirectMessage(
      id: 'dm-link',
      text: 'https://example.com/article',
      createdAt: 'Tue Jul 28 00:20:00 +0000 2026',
      senderId: 'account-a',
      recipientId: 'user-b',
    );

    testWidgets('opens a link message when the bubble is tapped', (
      tester,
    ) async {
      Uri? launchedUri;

      await tester.pumpApp(
        Scaffold(
          body: DirectMessageBubble(
            message: message,
            isSentByActiveAccount: true,
            externalLinkLauncher: (uri) async {
              launchedUri = uri;
              return true;
            },
          ),
        ),
      );

      await tester.tap(find.text(message.text));
      await tester.pump();

      expect(launchedUri, Uri.parse(message.text));
    });

    testWidgets('reports long presses through the callback', (tester) async {
      var longPressCount = 0;
      await tester.pumpApp(
        Scaffold(
          body: DirectMessageBubble(
            message: message,
            isSentByActiveAccount: true,
            onLongPress: () => longPressCount++,
          ),
        ),
      );

      await tester.longPress(find.text(message.text));
      await tester.pump();

      expect(longPressCount, 1);
    });

    testWidgets('renders without an avatar or bubble tail', (tester) async {
      await tester.pumpApp(
        const Scaffold(
          body: DirectMessageBubble(
            message: message,
            isSentByActiveAccount: true,
          ),
        ),
      );

      expect(find.byType(UserAvatar), findsNothing);
      expect(
        find.descendant(
          of: find.byType(DirectMessageBubble),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
    });

    testWidgets('recognizes and opens a link embedded in message text', (
      tester,
    ) async {
      const embeddedMessage = DirectMessage(
        id: 'dm-embedded-link',
        text: '请忽略：https://docs.google.com/spreadsheets/d/example',
        createdAt: 'Tue Jul 28 00:20:00 +0000 2026',
        senderId: 'user-b',
        recipientId: 'account-a',
      );
      Uri? launchedUri;

      await tester.pumpApp(
        Scaffold(
          body: DirectMessageBubble(
            message: embeddedMessage,
            isSentByActiveAccount: false,
            externalLinkLauncher: (uri) async {
              launchedUri = uri;
              return true;
            },
          ),
        ),
      );

      final text = tester.widget<Text>(find.byType(Text));
      final spans = (text.textSpan! as TextSpan).children!.cast<TextSpan>();
      final linkSpan = spans.singleWhere(
        (span) => span.text!.startsWith('https://'),
      );
      (linkSpan.recognizer! as TapGestureRecognizer).onTap!();
      await tester.pump();

      expect(
        launchedUri,
        Uri.parse('https://docs.google.com/spreadsheets/d/example'),
      );
    });

    testWidgets('uses the light theme direct-message colors', (tester) async {
      const incoming = DirectMessage(
        id: 'dm-incoming',
        text: '收到',
        createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
        senderId: 'user-b',
        recipientId: 'account-a',
      );

      await tester.pumpApp(
        const Scaffold(
          body: Column(
            children: [
              DirectMessageBubble(
                message: incoming,
                isSentByActiveAccount: false,
              ),
              DirectMessageBubble(
                message: message,
                isSentByActiveAccount: true,
              ),
            ],
          ),
        ),
      );

      final containers = tester.widgetList<Container>(find.byType(Container));
      final bubbleColors = containers
          .map((container) => (container.decoration as BoxDecoration?)?.color)
          .whereType<Color>()
          .toList();

      expect(
        bubbleColors,
        contains(AppColors.danLight.directMessageIncomingBubble),
      );
      expect(
        bubbleColors,
        contains(AppColors.danLight.wechatGreen),
      );

      final textWidgets = tester.widgetList<Text>(find.byType(Text)).toList();
      expect(
        (textWidgets[0].textSpan! as TextSpan).style!.color,
        const Color(0xFF000000),
      );
      expect(
        (textWidgets[1].textSpan! as TextSpan).style!.color,
        AppColors.danLight.textBase,
      );
      final linkSpan = ((textWidgets[1].textSpan! as TextSpan).children!)
          .cast<TextSpan>()
          .singleWhere((span) => span.text == message.text);
      expect(
        linkSpan.style!.color,
        AppColors.danLight.directMessageLinkText,
      );
    });

    testWidgets('uses the dark theme direct-message colors', (tester) async {
      const incoming = DirectMessage(
        id: 'dm-incoming',
        text: '收到',
        createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
        senderId: 'user-b',
        recipientId: 'account-a',
      );

      await tester.pumpApp(
        const Scaffold(
          body: Column(
            children: [
              DirectMessageBubble(
                message: incoming,
                isSentByActiveAccount: false,
              ),
              DirectMessageBubble(
                message: message,
                isSentByActiveAccount: true,
              ),
            ],
          ),
        ),
        themeMode: ThemeMode.dark,
      );

      final containers = tester.widgetList<Container>(find.byType(Container));
      final bubbleColors = containers
          .map((container) => (container.decoration as BoxDecoration?)?.color)
          .whereType<Color>()
          .toList();

      expect(
        bubbleColors,
        contains(AppColors.danDark.directMessageIncomingBubble),
      );
      expect(
        bubbleColors,
        contains(AppColors.danDark.wechatGreen),
      );

      final textWidgets = tester.widgetList<Text>(find.byType(Text)).toList();
      expect(
        (textWidgets[0].textSpan! as TextSpan).style!.color,
        const Color(0xFFF3F5F7),
      );
      expect(
        (textWidgets[1].textSpan! as TextSpan).style!.color,
        AppColors.danDark.textBase,
      );
      final linkSpan = ((textWidgets[1].textSpan! as TextSpan).children!)
          .cast<TextSpan>()
          .singleWhere((span) => span.text == message.text);
      expect(
        linkSpan.style!.color,
        AppColors.danDark.directMessageLinkText,
      );
    });
  });
}
