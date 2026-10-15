import 'package:dan/app/configuration/app_links.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:dan/settings/view/web_content_view.dart';
import 'package:flutter/material.dart';

/// Route boundary for reading a legal document inside the application.
class LegalDocumentPage extends StatelessWidget {
  /// Creates the agreement page, or the privacy policy when requested.
  const LegalDocumentPage({this.privacyPolicy = false, super.key});

  /// Whether to show the privacy policy instead of the user agreement.
  final bool privacyPolicy;

  @override
  Widget build(BuildContext context) {
    final colorMode = Theme.of(context).brightness == Brightness.dark
        ? 'dark'
        : 'light';
    final documentUri = privacyPolicy
        ? AppLinks.privacyPolicy
        : AppLinks.userAgreement;
    final uri = documentUri.replace(
      queryParameters: {
        ...documentUri.queryParameters,
        'source': 'dan',
        'colorMode': colorMode,
      },
    );

    return WebContentView(
      title: privacyPolicy
          ? context.l10n.settingsPrivacyPolicyLabel
          : context.l10n.settingsUserAgreementLabel,
      uri: uri,
    );
  }
}
