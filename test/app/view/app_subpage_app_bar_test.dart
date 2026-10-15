import 'package:dan/app/view/app_subpage_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group(AppSubpageAppBar, () {
    testWidgets('centers its title at the configured toolbar height', (
      tester,
    ) async {
      const toolbarHeight = 52.0;
      await tester.pumpApp(
        const Scaffold(
          appBar: AppSubpageAppBar(
            title: 'Profile',
            toolbarHeight: toolbarHeight,
          ),
        ),
      );

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.centerTitle, isTrue);
      expect(appBar.toolbarHeight, toolbarHeight);
      expect(find.text('Profile'), findsOneWidget);
    });

    test('reports its toolbar height as the preferred size', () {
      const appBar = AppSubpageAppBar(title: 'Profile', toolbarHeight: 52);

      expect(appBar.preferredSize, const Size.fromHeight(52));
    });

    testWidgets('removes its bottom divider when requested', (tester) async {
      await tester.pumpApp(
        const Scaffold(
          appBar: AppSubpageAppBar(
            title: 'Profile',
            showBottomDivider: false,
          ),
        ),
      );

      expect(tester.widget<AppBar>(find.byType(AppBar)).shape, const Border());
    });

    testWidgets('suppresses the implicit leading control when requested', (
      tester,
    ) async {
      await tester.pumpApp(
        const Scaffold(
          appBar: AppSubpageAppBar(
            title: 'Profile',
            automaticallyImplyLeading: false,
          ),
        ),
      );

      expect(
        tester.widget<AppBar>(find.byType(AppBar)).automaticallyImplyLeading,
        isFalse,
      );
    });

    testWidgets('renders the supplied trailing actions', (tester) async {
      await tester.pumpApp(
        Scaffold(
          appBar: AppSubpageAppBar(
            title: 'Profile',
            actions: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.settings_outlined),
        ),
        findsOneWidget,
      );
    });

    testWidgets('forwards the configured trailing action padding', (
      tester,
    ) async {
      const actionsPadding = EdgeInsetsDirectional.only(end: 4);
      await tester.pumpApp(
        const Scaffold(
          appBar: AppSubpageAppBar(
            title: 'Profile',
            actionsPadding: actionsPadding,
          ),
        ),
      );

      expect(
        tester.widget<AppBar>(find.byType(AppBar)).actionsPadding,
        actionsPadding,
      );
    });
  });
}
