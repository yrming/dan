import 'dart:async';

import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/view/app_subpage_app_bar.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/settings/widgets/document_markdown_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Displays a bundled Markdown document using the active application theme.
class MarkdownDocumentView extends StatefulWidget {
  /// Creates a reader for the Markdown asset at [assetPath].
  const MarkdownDocumentView({
    required this.title,
    required this.assetPath,
    super.key,
  });

  /// Title displayed in the app bar.
  final String title;

  /// Asset bundle path for the Markdown document.
  final String assetPath;

  @override
  State<MarkdownDocumentView> createState() => _MarkdownDocumentViewState();
}

class _MarkdownDocumentViewState extends State<MarkdownDocumentView> {
  late Future<String> _document;

  @override
  void initState() {
    super.initState();
    _document = _loadDocument();
  }

  @override
  void didUpdateWidget(covariant MarkdownDocumentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _document = _loadDocument();
    }
  }

  Future<String> _loadDocument() async {
    final source = await rootBundle.loadString(widget.assetPath);
    return _stripFrontMatter(source);
  }

  String _stripFrontMatter(String source) {
    final normalized = source.startsWith('\uFEFF')
        ? source.substring(1)
        : source;
    if (!normalized.startsWith('---\n') && !normalized.startsWith('---\r\n')) {
      return normalized.trim();
    }

    final markers = RegExp(r'^---\r?$', multiLine: true).allMatches(normalized);
    Match? closing;
    for (final marker in markers.skip(1)) {
      closing = marker;
      break;
    }
    if (closing == null) {
      throw const FormatException('Unterminated Markdown front matter');
    }
    return normalized.substring(closing.end).trim();
  }

  void _retry() {
    setState(() => _document = _loadDocument());
  }

  Future<void> _openLink(String? href) async {
    if (href == null) return;
    final uri = Uri.tryParse(href);
    if (uri == null ||
        !const {'http', 'https', 'mailto'}.contains(uri.scheme)) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.appSizing;

    return Scaffold(
      appBar: AppSubpageAppBar(
        title: widget.title,
        toolbarHeight: sizing.appBarToolbarHeight,
      ),
      body: ColoredBox(
        color: context.appColors.bgBase,
        child: FutureBuilder<String>(
          future: _document,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return AppRetryView(onRetry: _retry);
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            return SafeArea(
              top: false,
              bottom: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: sizing.scaled(AppSpacing.md),
                  vertical: sizing.scaled(AppSpacing.sm),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: MarkdownBody(
                      data: snapshot.data!,
                      selectable: true,
                      fitContent: false,
                      onTapLink: (_, href, _) => unawaited(_openLink(href)),
                      styleSheet: documentMarkdownStyle(context),
                      blockSyntaxes: const [DocumentMetadataSyntax()],
                      builders: {
                        'document-metadata': DocumentMetadataBuilder(),
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
