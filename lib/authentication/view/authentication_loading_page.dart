import 'package:dan/l10n/l10n.dart';
import 'package:flutter/material.dart';

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
