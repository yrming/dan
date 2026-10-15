import 'package:dan/settings/view/legal_document_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../helpers/fake_webview_platform.dart';
import '../../helpers/helpers.dart';

void main() {
  group(LegalDocumentPage, () {
    late FakeWebViewPlatform platform;
    late WebViewPlatform? previousPlatform;

    setUp(() {
      previousPlatform = WebViewPlatform.instance;
      platform = FakeWebViewPlatform();
      WebViewPlatform.instance = platform;
    });

    tearDown(
      () =>
          WebViewPlatform.instance = previousPlatform ?? FakeWebViewPlatform(),
    );

    testWidgets('adds light color mode to the document URL', (tester) async {
      await tester.pumpApp(const LegalDocumentPage());

      expect(platform.backgroundColor, Colors.white);
      expect(platform.requests, [
        Uri.parse(
          'https://dan.yrm.dev/user-agreement?source=dan&colorMode=light',
        ),
      ]);
    });

    testWidgets('adds dark color mode to the document URL', (tester) async {
      await tester.pumpApp(
        const LegalDocumentPage(privacyPolicy: true),
        themeMode: ThemeMode.dark,
      );

      expect(platform.backgroundColor, const Color(0xFF0F0F0F));
      expect(platform.requests, [
        Uri.parse(
          'https://dan.yrm.dev/privacy-policy?source=dan&colorMode=dark',
        ),
      ]);
    });
  });
}
