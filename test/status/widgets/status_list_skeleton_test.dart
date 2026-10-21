import 'package:appearance_repository/appearance_repository.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/status/widgets/status_action_button.dart';
import 'package:dan/status/widgets/status_body_text.dart';
import 'package:dan/status/widgets/status_list_skeleton.dart';
import 'package:dan/status/widgets/wechat_status_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:status_repository/status_repository.dart' as status_repository;

import '../../helpers/helpers.dart';

void main() {
  group(StatusListSkeleton, () {
    group('timeline layout', () {
      for (final fontSize in [12.0, 16.0, 20.0]) {
        for (final direction in TextDirection.values) {
          testWidgets(
            'matches the status item spacing at $fontSize in $direction',
            (tester) async {
              Future<void> pumpContent(Widget child) => tester.pumpApp(
                Scaffold(
                  body: Directionality(
                    textDirection: direction,
                    child: MediaQuery(
                      data: const MediaQueryData(disableAnimations: true),
                      child: Column(children: [child]),
                    ),
                  ),
                ),
                theme: AppTheme.light(
                  appearance: AppearanceSettings(fontSize: fontSize),
                ),
                themeMode: ThemeMode.light,
              );

              await pumpContent(
                const WeChatStatusListItem(
                  status: _status,
                  authorName: 'Author',
                  onAuthorTap: null,
                  onStatusTap: null,
                ),
              );
              final avatar = tester.getRect(find.byType(UserAvatar));
              final author = tester.getRect(find.text('Author'));
              final body = tester.getRect(find.byType(StatusBodyText));
              final metadata = tester.getRect(
                find
                    .ancestor(
                      of: find.byType(StatusActionButton),
                      matching: find.byType(Row),
                    )
                    .first,
              );

              await pumpContent(
                const StatusListSkeleton(
                  semanticLabel: 'Loading',
                  itemCount: 1,
                  shrinkWrap: true,
                ),
              );
              final shapes = find.descendant(
                of: find.byType(StatusListSkeleton),
                matching: find.byType(ClipRRect),
              );
              expect(shapes, findsNWidgets(5));
              final skeletonAvatar = tester.getRect(shapes.at(0));
              final skeletonAuthor = tester.getRect(shapes.at(1));
              final firstBodyLine = tester.getRect(shapes.at(2));
              final lastBodyLine = tester.getRect(shapes.at(3));
              final skeletonMetadata = tester.getRect(shapes.at(4));

              expect(skeletonAvatar, avatar);
              expect(
                firstBodyLine.top - skeletonAuthor.bottom,
                closeTo(body.top - author.bottom, 0.01),
              );
              expect(
                skeletonMetadata.top - lastBodyLine.bottom,
                closeTo(metadata.top - body.bottom, 0.01),
              );
              expect(firstBodyLine.left, closeTo(metadata.left, 0.01));
              expect(firstBodyLine.right, closeTo(metadata.right, 0.01));
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    });
  });
}

const _status = status_repository.Status(
  id: 'status',
  text: 'First line\nSecond line',
  createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
  author: status_repository.StatusAuthor(
    id: 'author',
    name: 'Author',
    screenName: 'author',
  ),
);
