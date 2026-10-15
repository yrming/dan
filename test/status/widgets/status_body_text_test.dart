import 'package:dan/app/navigation/routes.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/status/widgets/status_body_text.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_repository/user_repository.dart';

import '../../helpers/helpers.dart';

class _MockUserRepository extends Mock implements UserRepository {}

void main() {
  group(StatusBodyText, () {
    testWidgets('opens the mentioned user profile when a mention is tapped', (
      tester,
    ) async {
      final UserRepository userRepository = _MockUserRepository();
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, _) => RepositoryProvider.value(
              value: userRepository,
              child: const Scaffold(
                body: StatusBodyText(
                  text: '你好 @<a href="https://fanfou.com/user-id">user_a</a>',
                  linkColor: AppColors.wechatLightLink,
                ),
              ),
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
      await tester.pumpRouterApp(router);

      _tapSpan(tester, '@user_a');
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/user-id');
      expect(
        router.state.uri.queryParameters,
        const {'presentation': 'pushed'},
      );
      expect(find.text('profile-user-id'), findsOneWidget);
      verify(
        () => userRepository.cacheUser(
          const UserProfile(
            id: 'user-id',
            name: '',
            screenName: 'user_a',
          ),
        ),
      ).called(1);
    });

    testWidgets('opens an HTTPS link with the external launcher', (
      tester,
    ) async {
      Uri? launchedUri;
      await tester.pumpApp(
        StatusBodyText(
          text:
              '查看 <a href="https://example.com/docs?q=flutter&amp;lang=zh#section">官网</a>。',
          linkColor: AppColors.wechatLightLink,
          externalLinkLauncher: (uri) async {
            launchedUri = uri;
            return true;
          },
        ),
      );

      _tapSpan(tester, '官网');
      await tester.pump();

      expect(
        launchedUri,
        Uri.parse('https://example.com/docs?q=flutter&lang=zh#section'),
      );
    });

    testWidgets('ignores a link whose href is not HTTP or HTTPS', (
      tester,
    ) async {
      Uri? launchedUri;
      await tester.pumpApp(
        StatusBodyText(
          text: '查看 <a href="javascript:alert(1)">危险链接</a>',
          linkColor: AppColors.wechatLightLink,
          externalLinkLauncher: (uri) async {
            launchedUri = uri;
            return true;
          },
        ),
      );

      _tapSpan(tester, '危险链接');
      await tester.pump();

      expect(launchedUri, isNull);
    });

    testWidgets('opens a hashtag through the supplied topic callback', (
      tester,
    ) async {
      String? topic;
      await tester.pumpApp(
        StatusBodyText(
          text: '#<a href="/q/Flutter">Flutter开发</a>#',
          linkColor: AppColors.wechatLightLink,
          onHashtagTap: (value) => topic = value,
        ),
      );

      final span = _spanWithText(tester, '#Flutter开发#');

      expect(span.style?.color, AppColors.wechatLightLink);
      expect(span.recognizer, isNotNull);
      (span.recognizer! as TapGestureRecognizer).onTap!();
      expect(topic, '#Flutter开发#');
    });

    testWidgets('decodes entities and strips unsupported HTML markup', (
      tester,
    ) async {
      await tester.pumpApp(
        const StatusBodyText(
          text: 'A &amp; B <strong>加粗</strong>',
          linkColor: AppColors.wechatLightLink,
        ),
      );

      expect(find.text('A & B 加粗'), findsOneWidget);
      expect(find.textContaining('<strong>'), findsNothing);
    });

    testWidgets('does not apply line height outside the first and last lines', (
      tester,
    ) async {
      await tester.pumpApp(
        const StatusBodyText(
          text: '第一行\n第二行',
          linkColor: AppColors.wechatLightLink,
        ),
      );

      final text = tester.widget<Text>(find.byType(Text));

      expect(
        text.textHeightBehavior,
        const TextHeightBehavior(
          applyHeightToFirstAscent: false,
          applyHeightToLastDescent: false,
          leadingDistribution: TextLeadingDistribution.even,
        ),
      );
    });
  });
}

void _tapSpan(WidgetTester tester, String text) {
  final recognizer = _spanWithText(tester, text).recognizer;
  expect(recognizer, isA<TapGestureRecognizer>());
  (recognizer! as TapGestureRecognizer).onTap!();
}

TextSpan _spanWithText(WidgetTester tester, String text) {
  final body = tester.widget<Text>(find.byType(Text));
  final root = body.textSpan! as TextSpan;
  return root.children!.cast<TextSpan>().singleWhere(
    (span) => span.text == text,
  );
}
