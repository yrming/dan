import 'package:dan/settings/widgets/document_markdown_style.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;

void main() {
  group(DocumentMetadataSyntax, () {
    group('parse', () {
      late md.Document document;

      setUp(() {
        document = md.Document(
          blockSyntaxes: const [DocumentMetadataSyntax()],
        );
      });

      test('preserves all metadata lines and the following paragraph', () {
        final nodes = document.parseLines(const [
          '# Title',
          '',
          '**Version: 1.0**  ',
          '**Date: 2026-09-25**',
          '',
          'Introduction with **emphasis**.',
        ]);

        expect(nodes.map((node) => (node as md.Element).tag), [
          'h1',
          'document-metadata',
          'p',
        ]);
        expect(nodes[1].textContent, 'Version: 1.0\nDate: 2026-09-25');
        expect(nodes[2].textContent, 'Introduction with emphasis.');
      });

      test('keeps an ordinary introduction and later emphasized prose', () {
        final nodes = document.parseLines(const [
          '# About',
          '',
          '**A small app** with [a website](https://example.com).',
          '',
          '**Version: 1.0**',
          '**Date: today**',
        ]);

        expect(nodes.map((node) => (node as md.Element).tag), ['h1', 'p', 'p']);
        final intro = nodes[1] as md.Element;
        expect(
          intro.children!.whereType<md.Element>().map((node) => node.tag),
          ['strong', 'a'],
        );
      });
    });
  });
}
