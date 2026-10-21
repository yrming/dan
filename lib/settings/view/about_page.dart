import 'package:dan/l10n/l10n.dart';
import 'package:dan/settings/view/markdown_document_view.dart';
import 'package:flutter/material.dart';

/// Route boundary for reading the application's about document.
class AboutPage extends StatelessWidget {
  /// Creates the about page.
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MarkdownDocumentView(
      title: context.l10n.settingsAboutLabel,
      assetPath: 'assets/about.md',
    );
  }
}
