import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

/// Host that shows a failure toast when its button is tapped.
class _FailureToastLauncher extends StatelessWidget {
  const _FailureToastLauncher({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => showAppFailureToast(context, message: message),
          child: const Text('Show failure'),
        ),
      ),
    );
  }
}

void main() {
  group('showAppFailureToast', () {
    testWidgets('shows the server message when present', (tester) async {
      await tester.pumpApp(const _FailureToastLauncher(message: 'Server down'));

      await tester.tap(find.text('Show failure'));
      await tester.pump();

      expect(find.text('Server down'), findsOneWidget);
    });

    testWidgets('falls back to the generic message when blank', (
      tester,
    ) async {
      await tester.pumpApp(const _FailureToastLauncher(message: '  '));

      await tester.tap(find.text('Show failure'));
      await tester.pump();

      final context = tester.element(find.byType(Scaffold));
      expect(find.text(context.l10n.retryPageMessage), findsOneWidget);
    });
  });
}
