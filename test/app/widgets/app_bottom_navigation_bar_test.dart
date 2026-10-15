import 'dart:ui' show Tristate;

import 'package:dan/app/navigation/navigation.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group(AppBottomNavigationBar, () {
    testWidgets('renders text tabs with the central create action', (
      tester,
    ) async {
      await tester.pumpApp(
        Scaffold(
          bottomNavigationBar: AppBottomNavigationBar(
            selectedTab: AppShellTab.home,
            onTabSelected: (_) {},
          ),
        ),
      );
      final context = tester.element(find.byType(AppBottomNavigationBar));

      expect(find.byType(Icon), findsNothing);
      expect(find.text(context.l10n.homePageTitle), findsOneWidget);
      expect(find.text(context.l10n.mentionsPageTitle), findsOneWidget);
      expect(find.text(context.l10n.browsePageTitle), findsOneWidget);
      expect(find.text(context.l10n.userProfileTabLabel), findsOneWidget);
      expect(
        tester.widget<Text>(find.text(context.l10n.homePageTitle)).style,
        context.appTypography.selectedNavigationLabel,
      );
      expect(
        tester.widget<Text>(find.text(context.l10n.mentionsPageTitle)).style,
        context.appTypography.navigationLabel,
      );
      final createStatusVisual = find.byKey(
        const Key('app-bottom-navigation-create-status-visual'),
      );
      final horizontalPlus = find.byKey(
        const Key(
          'app-bottom-navigation-create-status-plus-horizontal',
        ),
      );
      final verticalPlus = find.byKey(
        const Key(
          'app-bottom-navigation-create-status-plus-vertical',
        ),
      );
      expect(tester.getSize(createStatusVisual), const Size(34, 26));
      expect(tester.getSize(horizontalPlus), const Size(14, 2));
      expect(tester.getSize(verticalPlus), const Size(2, 14));
      expect(
        tester.widget<ColoredBox>(horizontalPlus).color,
        context.appColors.textBase,
      );
      expect(
        tester.widget<ColoredBox>(verticalPlus).color,
        context.appColors.textBase,
      );
      final createStatusDecoration =
          tester.widget<DecoratedBox>(createStatusVisual).decoration
              as BoxDecoration;
      expect(createStatusDecoration.color, isNull);
      expect(
        createStatusDecoration.border,
        Border.all(
          color: context.appColors.textBase,
          width: 2,
        ),
      );
      expect(
        createStatusDecoration.borderRadius,
        const BorderRadius.all(Radius.circular(10)),
      );
      expect(find.text(context.l10n.createStatusLabel), findsNothing);
      expect(find.text(context.l10n.userProfilePageTitle), findsNothing);
    });

    testWidgets('exposes labeled tabs and reports the selected tab', (
      tester,
    ) async {
      final semanticsHandle = tester.ensureSemantics();
      await tester.pumpApp(
        Scaffold(
          bottomNavigationBar: AppBottomNavigationBar(
            selectedTab: AppShellTab.mentions,
            onTabSelected: (_) {},
          ),
        ),
      );
      final context = tester.element(find.byType(AppBottomNavigationBar));
      final selectedSemantics = tester.getSemantics(
        find.bySemanticsLabel(context.l10n.mentionsPageTitle),
      );

      expect(
        find.bySemanticsLabel(context.l10n.homePageTitle),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(context.l10n.browsePageTitle),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(context.l10n.createStatusLabel),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(context.l10n.userProfilePageTitle),
        findsOneWidget,
      );
      expect(selectedSemantics.flagsCollection.isButton, isTrue);
      expect(
        selectedSemantics.flagsCollection.isSelected,
        Tristate.isTrue,
      );
      semanticsHandle.dispose();
    });

    testWidgets('shows an unread badge on the mentions tab', (tester) async {
      await tester.pumpApp(
        Scaffold(
          bottomNavigationBar: AppBottomNavigationBar(
            selectedTab: AppShellTab.home,
            mentionsBadgeCount: 2,
            onTabSelected: (_) {},
          ),
        ),
      );

      expect(
        find.byKey(const Key('app-bottom-navigation-mentions-badge')),
        findsOneWidget,
      );
      expect(find.text('2'), findsOneWidget);
      expect(find.bySemanticsLabel('提到，2 条未读'), findsOneWidget);
    });

    testWidgets('hides the mentions badge when there are no unread mentions', (
      tester,
    ) async {
      await tester.pumpApp(
        Scaffold(
          bottomNavigationBar: AppBottomNavigationBar(
            selectedTab: AppShellTab.home,
            mentionsBadgeCount: 0,
            onTabSelected: (_) {},
          ),
        ),
      );

      expect(
        find.byKey(const Key('app-bottom-navigation-mentions-badge')),
        findsNothing,
      );
    });

    testWidgets('shows an unread badge on the mine tab', (tester) async {
      await tester.pumpApp(
        Scaffold(
          bottomNavigationBar: AppBottomNavigationBar(
            selectedTab: AppShellTab.home,
            mineBadgeCount: 3,
            onTabSelected: (_) {},
          ),
        ),
      );

      expect(
        find.byKey(const Key('app-bottom-navigation-mine-badge')),
        findsOneWidget,
      );
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('hides the mine badge when there are no unread messages', (
      tester,
    ) async {
      await tester.pumpApp(
        Scaffold(
          bottomNavigationBar: AppBottomNavigationBar(
            selectedTab: AppShellTab.home,
            mineBadgeCount: 0,
            onTabSelected: (_) {},
          ),
        ),
      );

      expect(
        find.byKey(const Key('app-bottom-navigation-mine-badge')),
        findsNothing,
      );
    });

    testWidgets('uses dark theme text colors for navigation state', (
      tester,
    ) async {
      await tester.pumpApp(
        Scaffold(
          bottomNavigationBar: AppBottomNavigationBar(
            selectedTab: AppShellTab.home,
            onTabSelected: (_) {},
          ),
        ),
        themeMode: ThemeMode.dark,
      );
      final context = tester.element(find.byType(AppBottomNavigationBar));

      expect(
        tester.widget<Text>(find.text(context.l10n.homePageTitle)).style?.color,
        context.appColors.textBase,
      );
      expect(
        tester
            .widget<Text>(find.text(context.l10n.mentionsPageTitle))
            .style
            ?.color,
        context.appColors.textSecondary,
      );
      expect(
        tester
            .widget<ColoredBox>(
              find.byKey(
                const Key(
                  'app-bottom-navigation-create-status-plus-horizontal',
                ),
              ),
            )
            .color,
        context.appColors.textBase,
      );
      final createStatusVisual = find.byKey(
        const Key('app-bottom-navigation-create-status-visual'),
      );
      final createStatusDecoration =
          tester.widget<DecoratedBox>(createStatusVisual).decoration
              as BoxDecoration;
      expect(createStatusDecoration.color, isNull);
      expect(
        createStatusDecoration.border,
        Border.all(
          color: context.appColors.textBase,
          width: 2,
        ),
      );
    });

    testWidgets('reports an unselected tab tap without haptic feedback', (
      tester,
    ) async {
      AppShellTab? tappedTab;
      final platformCalls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          platformCalls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpApp(
        Scaffold(
          bottomNavigationBar: AppBottomNavigationBar(
            selectedTab: AppShellTab.home,
            onTabSelected: (tab) => tappedTab = tab,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const Key('app-bottom-navigation-browse')),
      );

      expect(tappedTab, AppShellTab.browse);
      expect(
        platformCalls.where(
          (call) => call.method == 'HapticFeedback.vibrate',
        ),
        isEmpty,
      );
    });

    testWidgets('calls the create-status callback from the central action', (
      tester,
    ) async {
      var createStatusPressed = false;
      final platformCalls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          platformCalls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpApp(
        Scaffold(
          bottomNavigationBar: AppBottomNavigationBar(
            selectedTab: AppShellTab.home,
            onTabSelected: (_) {},
            onCreateStatusPressed: () => createStatusPressed = true,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const Key('app-bottom-navigation-create-status')),
      );
      await tester.pump();

      expect(createStatusPressed, isTrue);
      expect(
        platformCalls,
        contains(
          isA<MethodCall>()
              .having(
                (call) => call.method,
                'method',
                'HapticFeedback.vibrate',
              )
              .having(
                (call) => call.arguments,
                'arguments',
                'HapticFeedbackType.lightImpact',
              ),
        ),
      );
    });

    testWidgets('does not provide haptic feedback for the selected tab', (
      tester,
    ) async {
      final platformCalls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          platformCalls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpApp(
        Scaffold(
          bottomNavigationBar: AppBottomNavigationBar(
            selectedTab: AppShellTab.home,
            onTabSelected: (_) {},
          ),
        ),
      );

      await tester.tap(
        find.byKey(const Key('app-bottom-navigation-home')),
        warnIfMissed: false,
      );

      expect(
        platformCalls.where(
          (call) => call.method == 'HapticFeedback.vibrate',
        ),
        isEmpty,
      );
    });

    testWidgets('uses textBase for the selected create-status action', (
      tester,
    ) async {
      await tester.pumpApp(
        Scaffold(
          bottomNavigationBar: AppBottomNavigationBar(
            selectedTab: AppShellTab.home,
            onTabSelected: (_) {},
            isCreateStatusSelected: true,
          ),
        ),
      );

      final context = tester.element(find.byType(AppBottomNavigationBar));
      expect(
        tester
            .widget<ColoredBox>(
              find.byKey(
                const Key(
                  'app-bottom-navigation-create-status-plus-horizontal',
                ),
              ),
            )
            .color,
        context.appColors.textBase,
      );
      final createStatusDecoration =
          tester
                  .widget<DecoratedBox>(
                    find.byKey(
                      const Key('app-bottom-navigation-create-status-visual'),
                    ),
                  )
                  .decoration
              as BoxDecoration;
      expect(
        createStatusDecoration.border,
        Border.all(color: context.appColors.textBase, width: 2),
      );
    });
  });
}
