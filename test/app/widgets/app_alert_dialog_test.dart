import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  const title = '删除帖子?';
  const content = '这篇帖子一旦删除便无法恢复。';
  const cancelLabel = '取消';
  const confirmLabel = '删除';
  const confirmColor = Color(0xFFFA5151);

  Finder descendantOf(Type type) {
    return find.descendant(
      of: find.byType(AppAlertDialog),
      matching: find.byType(type),
    );
  }

  Finder separatorFinder() {
    return find.byWidgetPredicate(
      (widget) => widget is SizedBox && widget.width == 0.5,
    );
  }

  Future<void> pumpDialog(WidgetTester tester) async {
    await tester.pumpApp(
      Builder(
        builder: (context) => AppAlertDialog(
          title: title,
          content: content,
          cancelAction: AppDialogAction(
            label: cancelLabel,
            color: context.appColors.textBase,
            onPressed: doNothing,
          ),
          confirmAction: const AppDialogAction(
            label: confirmLabel,
            color: confirmColor,
            onPressed: doNothing,
          ),
        ),
      ),
    );
  }

  Future<void> pumpOpener(
    WidgetTester tester, {
    required VoidCallback onCancel,
    required VoidCallback onConfirm,
  }) async {
    await tester.pumpApp(
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () => showAppAlertDialog(
                context,
                title: title,
                content: content,
                cancelAction: AppDialogAction(
                  label: cancelLabel,
                  color: context.appColors.textBase,
                  onPressed: onCancel,
                ),
                confirmAction: AppDialogAction(
                  label: confirmLabel,
                  color: confirmColor,
                  onPressed: onConfirm,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  group(AppAlertDialog, () {
    testWidgets('renders the title and content with dialog typography', (
      tester,
    ) async {
      await pumpDialog(tester);
      final context = tester.element(find.text(title));
      final typography = context.appTypography;

      expect(
        tester.widget<Text>(find.text(title)).style,
        typography.dialogTitle,
      );
      expect(
        tester.widget<Text>(find.text(content)).style,
        typography.dialogContent,
      );
    });

    testWidgets('sizes the surface to the shared dialog metrics', (
      tester,
    ) async {
      await pumpDialog(tester);
      final context = tester.element(find.text(title));
      final sizing = context.appSizing;
      final surfaceFinder = descendantOf(ClipRRect);

      expect(
        tester.getSize(surfaceFinder).width,
        sizing.scaled(AppLayout.alertDialogWidth, minimum: 280),
      );
      expect(
        tester.widget<ClipRRect>(surfaceFinder).borderRadius,
        BorderRadius.circular(
          sizing.scaled(AppLayout.alertDialogRadius, minimum: 16),
        ),
      );
      expect(tester.getSize(descendantOf(Divider)).width, 280);
      expect(tester.getSize(separatorFinder()).width, 0.5);
      expect(
        tester.getSize(separatorFinder()).height,
        sizing.scaled(AppLayout.alertDialogActionHeight, minimum: 48),
      );
    });

    testWidgets('paints the surface and dividers with theme tokens', (
      tester,
    ) async {
      await pumpDialog(tester);
      final context = tester.element(find.text(title));
      final colors = context.appColors;

      expect(
        tester.widget<Material>(descendantOf(Material)).color,
        colors.dialogBackground,
      );
      expect(colors.dialogBackground, const Color(0xFFFFFFFF));
      expect(
        tester
            .widget<ColoredBox>(
              find.descendant(
                of: separatorFinder(),
                matching: find.byType(ColoredBox),
              ),
            )
            .color,
        colors.divider,
      );
      expect(Theme.of(context).dividerTheme.color, colors.divider);
    });

    testWidgets('paints the surface with the dark dialog color in dark mode', (
      tester,
    ) async {
      await tester.pumpApp(
        Builder(
          builder: (context) => AppAlertDialog(
            title: title,
            content: content,
            cancelAction: AppDialogAction(
              label: cancelLabel,
              color: context.appColors.textBase,
              onPressed: doNothing,
            ),
            confirmAction: const AppDialogAction(
              label: confirmLabel,
              color: confirmColor,
              onPressed: doNothing,
            ),
          ),
        ),
        themeMode: ThemeMode.dark,
      );
      final context = tester.element(find.text(title));

      expect(
        tester.widget<Material>(descendantOf(Material)).color,
        context.appColors.dialogBackground,
      );
      expect(context.appColors.dialogBackground, const Color(0xFF181818));
    });

    testWidgets('renders the action labels with their action colors', (
      tester,
    ) async {
      await pumpDialog(tester);
      final context = tester.element(find.text(title));
      final sizing = context.appSizing;

      expect(
        tester.widget<Text>(find.text(cancelLabel)).style?.color,
        context.appColors.textBase,
      );
      expect(
        tester.widget<Text>(find.text(confirmLabel)).style?.color,
        confirmColor,
      );
      expect(
        tester.widget<Text>(find.text(confirmLabel)).style?.fontSize,
        sizing.scaled(16),
      );
    });

    testWidgets('does not play a ripple when an action is tapped', (
      tester,
    ) async {
      await pumpDialog(tester);
      final inkWells = tester.widgetList<InkWell>(
        find.descendant(
          of: find.byType(AppAlertDialog),
          matching: find.byType(InkWell),
        ),
      );

      expect(inkWells.length, 2);
      for (final inkWell in inkWells) {
        final theme = Theme.of(tester.element(find.byWidget(inkWell)));
        expect(
          inkWell.splashFactory ?? theme.splashFactory,
          NoSplash.splashFactory,
        );
        expect(
          inkWell.highlightColor ?? theme.highlightColor,
          AppColors.transparent,
        );
        expect(inkWell.hoverColor, AppColors.transparent);
      }
    });

    testWidgets('pops the dialog and invokes the confirm action', (
      tester,
    ) async {
      var cancelCount = 0;
      var confirmCount = 0;
      await pumpOpener(
        tester,
        onCancel: () => cancelCount++,
        onConfirm: () => confirmCount++,
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);

      await tester.tap(find.text(confirmLabel));
      await tester.pumpAndSettle();

      expect(confirmCount, 1);
      expect(cancelCount, 0);
      expect(find.text(title), findsNothing);
    });

    testWidgets('pops the dialog and invokes the cancel action', (
      tester,
    ) async {
      var cancelCount = 0;
      var confirmCount = 0;
      await pumpOpener(
        tester,
        onCancel: () => cancelCount++,
        onConfirm: () => confirmCount++,
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(cancelLabel));
      await tester.pumpAndSettle();

      expect(cancelCount, 1);
      expect(confirmCount, 0);
      expect(find.text(title), findsNothing);
    });

    testWidgets('stays open when the barrier is tapped', (tester) async {
      await pumpOpener(tester, onCancel: doNothing, onConfirm: doNothing);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(40, 40));
      await tester.pumpAndSettle();

      expect(find.text(title), findsOneWidget);
    });
  });
}

void doNothing() {}
