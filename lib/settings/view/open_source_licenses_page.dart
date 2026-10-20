import 'package:dan/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Displays the licenses bundled with the application's dependencies.
class OpenSourceLicensesPage extends StatelessWidget {
  /// Creates the open-source licenses page.
  const OpenSourceLicensesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LicensePage(applicationName: context.l10n.loginBrandLogoLabel);
  }
}
