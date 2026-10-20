import 'package:dan/l10n/l10n.dart';
import 'package:dan/settings/view/markdown_document_view.dart';
import 'package:flutter/material.dart';

/// Route boundary for reading a legal document inside the application.
class LegalDocumentPage extends StatelessWidget {
  /// Creates the agreement page, or the privacy policy when requested.
  const LegalDocumentPage({this.privacyPolicy = false, super.key});

  /// Whether to show the privacy policy instead of the user agreement.
  final bool privacyPolicy;

  @override
  Widget build(BuildContext context) {
    return MarkdownDocumentView(
      title: privacyPolicy
          ? context.l10n.settingsPrivacyPolicyLabel
          : context.l10n.settingsUserAgreementLabel,
      assetPath: privacyPolicy
          ? 'assets/privacy-policy.md'
          : 'assets/user-agreement.md',
    );
  }
}
