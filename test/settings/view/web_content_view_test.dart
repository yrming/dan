import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/settings/view/web_content_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../helpers/fake_webview_platform.dart';
import '../../helpers/helpers.dart';

void main() {
  group(WebContentView, () {
    late FakeWebViewPlatform platform;
    late WebViewPlatform? previousPlatform;
    final uri = Uri.parse('https://dan.yrm.dev/user-agreement');

    setUp(() {
      previousPlatform = WebViewPlatform.instance;
      platform = FakeWebViewPlatform();
      WebViewPlatform.instance = platform;
    });

    tearDown(
      () =>
          WebViewPlatform.instance = previousPlatform ?? FakeWebViewPlatform(),
    );

    Future<void> pumpDocument(WidgetTester tester) => tester.pumpApp(
      WebContentView(title: '用户协议', uri: uri),
    );

    group('loading', () {
      testWidgets('loads the document and hides progress after completion', (
        tester,
      ) async {
        await pumpDocument(tester);
        expect(platform.requests, [uri]);
        expect(find.text('用户协议'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        platform.delegate.onFinished(uri.toString());
        await tester.pump();
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(find.byType(WebViewWidget), findsOneWidget);
      });

      testWidgets('retries the original document after a main-frame error', (
        tester,
      ) async {
        await pumpDocument(tester);
        platform.delegate.onError(
          const WebResourceError(
            errorCode: -2,
            description: 'offline',
            isForMainFrame: true,
          ),
        );
        platform.delegate.onFinished(uri.toString());
        await tester.pump();
        expect(find.byType(AppRetryView), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        await tester.tap(find.text('重试'));
        await tester.pump();
        expect(platform.requests, [uri, uri]);
        expect(find.byType(AppRetryView), findsNothing);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        platform.delegate.onStarted(uri.toString());
        platform.delegate.onFinished(uri.toString());
        await tester.pump();
        expect(find.byType(WebViewWidget), findsOneWidget);
      });

      testWidgets('ignores failures of embedded resources', (tester) async {
        await pumpDocument(tester);
        platform.delegate.onError(
          const WebResourceError(
            errorCode: -2,
            description: 'image failed',
            isForMainFrame: false,
          ),
        );
        platform.delegate.onFinished(uri.toString());
        await tester.pump();
        expect(find.byType(AppRetryView), findsNothing);
        expect(find.byType(WebViewWidget), findsOneWidget);
      });

      testWidgets('shows retry when the platform cannot load the request', (
        tester,
      ) async {
        platform.loadError = Exception('unavailable');
        await pumpDocument(tester);
        await tester.pump();
        expect(find.byType(AppRetryView), findsOneWidget);
      });

      testWidgets('shows retry for a main-frame HTTP error', (tester) async {
        await pumpDocument(tester);
        platform.delegate.onHttpError(
          HttpResponseError(
            request: WebResourceRequest(uri: uri),
          ),
        );
        await tester.pump();
        expect(find.byType(AppRetryView), findsOneWidget);
      });

      testWidgets('ignores late callbacks after the reader is closed', (
        tester,
      ) async {
        await pumpDocument(tester);
        await tester.pumpApp(const SizedBox());
        platform.delegate.onFinished(uri.toString());
        expect(tester.takeException(), isNull);
      });
    });

    group('navigation', () {
      testWidgets('keeps web links inside the view and blocks app schemes', (
        tester,
      ) async {
        await pumpDocument(tester);
        expect(
          await platform.delegate.onNavigation(
            NavigationRequest(
              url: uri.toString(),
              isMainFrame: true,
            ),
          ),
          NavigationDecision.navigate,
        );
        expect(
          await platform.delegate.onNavigation(
            const NavigationRequest(
              url: 'mailto:hello@example.com',
              isMainFrame: true,
            ),
          ),
          NavigationDecision.prevent,
        );
      });
    });
  });
}
