import 'package:dan/app/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

/// Reading styles adapted from the website's document-prose typography.
MarkdownStyleSheet documentMarkdownStyle(BuildContext context) {
  final theme = Theme.of(context);
  final colors = context.appColors;
  final sizing = context.appSizing;
  final body = theme.textTheme.bodyMedium!.copyWith(
    color: colors.documentBody,
    fontSize: sizing.scaled(16),
    height: 1.6,
    letterSpacing: 0,
  );
  final heading = body.copyWith(
    color: colors.textBase,
    fontWeight: FontWeight.w500,
  );

  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    p: body,
    // List items use ten pixels; paragraph padding adds six more for prose.
    blockSpacing: sizing.scaled(AppSpacing.space10),
    pPadding: EdgeInsets.only(bottom: sizing.scaled(AppSpacing.space6)),
    h1: heading.copyWith(
      fontSize: sizing.scaled(26),
      height: 1.4,
    ),
    h1Padding: EdgeInsets.only(bottom: sizing.scaled(18)),
    h2: heading.copyWith(
      fontSize: sizing.scaled(20),
      height: 1.5,
    ),
    h2Padding: EdgeInsets.only(
      top: sizing.scaled(AppSpacing.xl),
      bottom: sizing.scaled(AppSpacing.space6),
    ),
    h3: heading.copyWith(fontSize: sizing.scaled(17)),
    h3Padding: EdgeInsets.only(
      top: sizing.scaled(AppSpacing.sm),
      bottom: sizing.scaled(2),
    ),
    strong: body.copyWith(
      color: colors.textBase,
      fontWeight: FontWeight.w600,
    ),
    a: body.copyWith(
      color: colors.textBase,
      decoration: TextDecoration.underline,
      decorationColor: colors.documentMuted,
    ),
    listBullet: body.copyWith(color: colors.documentMuted),
    listIndent: sizing.scaled(AppSpacing.lg),
    listBulletPadding: EdgeInsets.only(right: sizing.scaled(AppSpacing.xxs)),
    code: body.copyWith(
      fontFamily: 'monospace',
      fontSize: body.fontSize! * 0.9,
      backgroundColor: colors.groupedBackground,
    ),
    blockquote: body.copyWith(color: colors.documentMuted),
    blockquoteDecoration: BoxDecoration(
      border: Border(left: BorderSide(color: colors.divider, width: 3)),
    ),
    blockquotePadding: EdgeInsets.symmetric(
      horizontal: sizing.scaled(AppSpacing.md),
      vertical: sizing.scaled(AppSpacing.xs),
    ),
    codeblockDecoration: BoxDecoration(
      color: colors.groupedBackground,
      borderRadius: BorderRadius.circular(AppSpacing.xxs),
    ),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(top: BorderSide(color: colors.divider)),
    ),
  );
}

/// Recognizes a block of emphasized key/value lines immediately after a title.
class DocumentMetadataSyntax extends md.BlockSyntax {
  /// Creates the optional document metadata syntax.
  const DocumentMetadataSyntax();

  @override
  RegExp get pattern => RegExp(r'^\*\*([^*]+[：:][^*]+)\*\*\s*$');

  @override
  bool canParse(md.BlockParser parser) {
    if (parser.parentSyntax != null || !super.canParse(parser)) return false;
    var previous = parser.lines.indexOf(parser.current) - 1;
    while (previous >= 0 && parser.lines[previous].content.trim().isEmpty) {
      previous--;
    }
    return previous >= 0 &&
        parser.lines[previous].content.startsWith('# ') &&
        parser.next != null &&
        pattern.hasMatch(parser.next!.content);
  }

  @override
  md.Node parse(md.BlockParser parser) {
    final lines = <String>[];
    while (!parser.isDone) {
      final match = pattern.firstMatch(parser.current.content);
      if (match == null) break;
      lines.add(match.group(1)!);
      parser.advance();
    }
    return md.Element.text('document-metadata', lines.join('\n'));
  }
}

/// Renders document metadata as selectable text, leaving prose to Markdown.
class DocumentMetadataBuilder extends MarkdownElementBuilder {
  @override
  bool isBlockElement() => true;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final sizing = context.appSizing;
    return Padding(
      padding: EdgeInsets.only(bottom: sizing.scaled(22)),
      child: SelectableText(
        element.textContent,
        style: Theme.of(context).textTheme.bodySmall!.copyWith(
          color: context.appColors.documentMuted,
          fontSize: sizing.scaled(13),
          fontWeight: FontWeight.w400,
          height: 2,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
