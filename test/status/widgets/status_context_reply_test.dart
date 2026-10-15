import 'package:dan/status/widgets/status_body_text.dart';
import 'package:dan/status/widgets/status_context_reply.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:status_repository/status_repository.dart' as status_repository;

import '../../helpers/helpers.dart';

void main() {
  group(StatusContextReply, () {
    group('interaction', () {
      testWidgets('opens reply actions when the comment is tapped', (
        tester,
      ) async {
        var taps = 0;
        await tester.pumpApp(
          Scaffold(
            body: StatusContextReply(
              status: _reply,
              authorName: 'Author',
              onAuthorTap: () {},
              onTap: () => taps++,
            ),
          ),
        );

        expect(
          find.text('Author: Reply text', findRichText: true),
          findsOneWidget,
        );
        await tester.tap(find.byType(StatusContextReply));
        await tester.pump();
        expect(taps, 1);
      });

      testWidgets('opens the author without opening reply actions', (
        tester,
      ) async {
        var authorTaps = 0;
        var replyTaps = 0;
        await tester.pumpApp(
          Scaffold(
            body: StatusContextReply(
              status: _reply,
              authorName: 'Author',
              onAuthorTap: () => authorTaps++,
              onTap: () => replyTaps++,
            ),
          ),
        );

        await tester.tapAt(
          tester.getTopLeft(find.byType(StatusBodyText)) + const Offset(10, 8),
        );
        await tester.pump();
        expect(authorTaps, 1);
        expect(replyTaps, 0);
      });
    });
  });
}

const _reply = status_repository.Status(
  id: 'reply',
  text: 'Reply text',
  createdAt: '',
  author: status_repository.StatusAuthor(
    id: 'author',
    name: 'Author',
    screenName: 'author',
  ),
);
