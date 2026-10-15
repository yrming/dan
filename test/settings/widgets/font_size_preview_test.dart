import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/settings/widgets/font_size_preview.dart';
import 'package:dan/status/status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group(FontSizePreview, () {
    group('rendering', () {
      testWidgets('uses the status renderer with the supplied message', (
        tester,
      ) async {
        await tester.pumpApp(
          const Scaffold(body: FontSizePreview()),
        );

        const text = '早上和旦哥领证了，刚才我挣扎了半天对着她叫了声太太，她立马掐住我的脖子说太你妈。';
        const avatarUrl =
            'https://s3.meituan.net/v1/'
            'mss_3d027b52ec5a4d589e68050845611e68/'
            'avatar/l0/01/d9/ta.jpg?1381056277';
        expect(find.byType(WeChatStatusListItem), findsOneWidget);
        expect(find.text(text), findsOneWidget);
        expect(find.text('2019年9月25日'), findsOneWidget);
        expect(
          tester.widget<UserAvatar>(find.byType(UserAvatar)).imageUrl,
          avatarUrl,
        );
        expect(find.byType(StatusPhoto), findsNothing);

        await tester.tap(find.text(text));
        await tester.tap(find.byType(UserAvatar));
        await tester.tap(
          find.byKey(const Key('wechat-status-action-hit-target')),
        );
        await tester.pump();
        expect(find.byType(FontSizePreview), findsOneWidget);
        expect(find.byType(BottomSheet), findsNothing);
        expect(tester.takeException(), isNull);
      });
    });
  });
}
