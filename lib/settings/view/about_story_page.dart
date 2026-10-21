import 'package:dan/l10n/l10n.dart';
import 'package:dan/settings/view/markdown_document_view.dart';
import 'package:flutter/material.dart';

/// Displays the original story behind Dan.
class AboutStoryPage extends StatelessWidget {
  /// Creates the story page.
  const AboutStoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MarkdownDocumentView(
      title: context.l10n.aboutWhyLabel,
      assetPath: 'assets/about.md',
    );
  }
}
