import 'package:dan/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Loading boundary shown while stored accounts are restored.
class AuthenticationLoadingPage extends StatelessWidget {
  /// Creates an authentication loading page.
  const AuthenticationLoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(
          semanticsLabel: context.l10n.authenticationLoadingLabel,
        ),
      ),
    );
  }
}
