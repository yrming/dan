import 'dart:async';

import 'package:dan/app/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/helpers.dart';

/// Host that shows a toast with a fixed message when its button is tapped.
class _ToastLauncher extends StatelessWidget {
  const _ToastLauncher({required this.buttonLabel, required this.message});

  final String buttonLabel;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => showAppToast(context, message),
          child: Text(buttonLabel),
        ),
      ),
    );
  }
}

/// Pumps enough frames for a toast animation phase to settle. Animation
/// frames report the clock before each pump, so every phase needs one pump
/// to advance the clock and one more pump for the frame that completes it.
Future<void> pumpToastFrames(WidgetTester tester) async {
  const step = Duration(milliseconds: 300);
  await tester.pump(step);
  await tester.pump(step);
}

void main() {
  group('showAppToast', () {
    group('button tap', () {
      testWidgets('shows the message in a toast', (tester) async {
        await tester.pumpApp(
          const _ToastLauncher(buttonLabel: 'Show toast', message: 'Saved'),
        );

        await tester.tap(find.text('Show toast'));
        await tester.pump();

        expect(find.text('Saved'), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
        final decoration =
            tester
                    .widget<DecoratedBox>(
                      find.ancestor(
                        of: find.text('Saved'),
                        matching: find.byType(DecoratedBox),
                      ),
                    )
                    .decoration
                as BoxDecoration;
        expect(decoration.color, const Color(0xFF313131));
      });

      testWidgets('removes the toast after the display duration', (
        tester,
      ) async {
        await tester.pumpApp(
          const _ToastLauncher(buttonLabel: 'Show toast', message: 'Saved'),
        );

        await tester.tap(find.text('Show toast'));
        await tester.pump();
        await pumpToastFrames(tester);
        expect(find.text('Saved'), findsOneWidget);

        await tester.pump(const Duration(seconds: 3));
        await pumpToastFrames(tester);

        expect(find.text('Saved'), findsNothing);
      });

      testWidgets('replaces the current toast without queueing', (
        tester,
      ) async {
        await tester.pumpApp(
          Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => showAppToast(context, 'First message'),
                      child: const Text('First'),
                    ),
                    TextButton(
                      onPressed: () => showAppToast(context, 'Second message'),
                      child: const Text('Second'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('First'));
        await tester.pump();
        await pumpToastFrames(tester);
        expect(find.text('First message'), findsOneWidget);

        await tester.tap(find.text('Second'));
        await tester.pump();
        expect(find.text('First message'), findsOneWidget);
        expect(find.text('Second message'), findsOneWidget);

        await pumpToastFrames(tester);
        expect(find.text('First message'), findsNothing);
        expect(find.text('Second message'), findsOneWidget);

        await tester.pump(const Duration(seconds: 3));
        await pumpToastFrames(tester);
        expect(find.text('Second message'), findsNothing);
      });

      testWidgets('replaces a toast triggered in the same frame', (
        tester,
      ) async {
        await tester.pumpApp(
          Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => TextButton(
                  onPressed: () {
                    showAppToast(context, 'First message');
                    showAppToast(context, 'Second message');
                  },
                  child: const Text('Show twice'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show twice'));
        await tester.pump();

        expect(find.text('First message'), findsNothing);
        expect(find.text('Second message'), findsOneWidget);
      });

      testWidgets('keeps the toast across route changes', (tester) async {
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => Scaffold(
                body: Center(
                  child: Builder(
                    builder: (context) => TextButton(
                      onPressed: () {
                        showAppToast(context, 'Saved');
                        unawaited(context.push('/second'));
                      },
                      child: const Text('Show toast'),
                    ),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '/second',
              builder: (context, state) =>
                  const Scaffold(body: Center(child: Text('Second page'))),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpRouterApp(router);

        await tester.tap(find.text('Show toast'));
        await tester.pump();
        expect(find.text('Saved'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 600));

        expect(find.text('Second page'), findsOneWidget);
        expect(find.text('Saved'), findsOneWidget);
      });
    });

    testWidgets('does nothing when no overlay is available', (tester) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            showAppToast(context, 'Orphan');
            return const SizedBox.shrink();
          },
        ),
      );

      expect(find.text('Orphan'), findsNothing);
    });
  });
}
