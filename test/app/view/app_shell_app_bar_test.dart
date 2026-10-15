import 'package:dan/app/navigation/navigation.dart';
import 'package:dan/app/navigation/scroll_to_top_scope.dart';
import 'package:dan/app/view/app_shell_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';

import '../../helpers/helpers.dart';

void main() {
  group(AppShellAppBar, () {
    testWidgets('shows 提到 for the mentions tab', (tester) async {
      await tester.pumpApp(
        const Scaffold(
          appBar: AppShellAppBar(selectedTab: AppShellTab.mentions),
        ),
      );

      expect(find.text('提到'), findsOneWidget);
    });

    testWidgets('scrolls the selected tab to the top after a double tap', (
      tester,
    ) async {
      final controller = ScrollToTopController();
      var scrollToTopCalled = false;
      controller.register(
        AppShellTab.home,
        () => scrollToTopCalled = true,
      );
      await tester.pumpApp(
        ScrollToTopScope(
          controller: controller,
          child: const Scaffold(
            appBar: AppShellAppBar(selectedTab: AppShellTab.home),
          ),
        ),
      );

      await tester.tap(find.byType(AppBar));
      await tester.tap(find.byType(AppBar));
      await tester.pump();

      expect(scrollToTopCalled, isTrue);
    });

    testWidgets('shows 发现 for the browse tab', (tester) async {
      await tester.pumpApp(
        const Scaffold(
          appBar: AppShellAppBar(selectedTab: AppShellTab.browse),
        ),
      );

      expect(find.text('发现'), findsOneWidget);
    });

    testWidgets('opens search from the browse app bar', (tester) async {
      var pressed = false;
      await tester.pumpApp(
        Scaffold(
          appBar: AppShellAppBar(
            selectedTab: AppShellTab.browse,
            onBrowseSearchPressed: () => pressed = true,
          ),
        ),
      );
      expect(find.byTooltip('搜索'), findsOneWidget);
      await tester.tap(find.byIcon(RemixIcons.search_line));
      expect(pressed, isTrue);
    });

    testWidgets('shows active account actions for the profile tab', (
      tester,
    ) async {
      var settingsPressed = false;
      var searchPressed = false;
      var accountManagementPressed = false;

      await tester.pumpApp(
        Scaffold(
          appBar: AppShellAppBar(
            selectedTab: AppShellTab.mine,
            onMineSettingsPressed: () => settingsPressed = true,
            onMineSearchPressed: () => searchPressed = true,
            onMineAccountManagementPressed: () =>
                accountManagementPressed = true,
          ),
        ),
      );

      expect(find.byIcon(RemixIcons.menu_2_line), findsOneWidget);
      expect(find.byIcon(RemixIcons.search_line), findsOneWidget);
      expect(find.byIcon(RemixIcons.mail_line), findsOneWidget);
      expect(find.byTooltip('私信'), findsOneWidget);
      expect(tester.widget<AppBar>(find.byType(AppBar)).shape, const Border());

      await tester.tap(find.byIcon(RemixIcons.menu_2_line));
      await tester.tap(find.byIcon(RemixIcons.search_line));
      await tester.tap(find.byIcon(RemixIcons.mail_line));

      expect(settingsPressed, isTrue);
      expect(searchPressed, isTrue);
      expect(accountManagementPressed, isTrue);
    });

    testWidgets('shows search as the leftmost profile tab action', (
      tester,
    ) async {
      await tester.pumpApp(
        const Scaffold(
          appBar: AppShellAppBar(selectedTab: AppShellTab.mine),
        ),
      );

      final actionIcons = tester
          .widget<AppBar>(
            find.byType(AppBar),
          )
          .actions!
          .cast<IconButton>()
          .map((action) => (action.icon as Icon).icon);

      expect(actionIcons, [RemixIcons.search_line, RemixIcons.mail_line]);
    });
  });
}
