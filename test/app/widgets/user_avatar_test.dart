import 'package:cached_network_image/cached_network_image.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group(UserAvatar, () {
    group('renders', () {
      testWidgets('shows a themed fallback when no image is available', (
        tester,
      ) async {
        await tester.pumpApp(
          const Center(
            child: UserAvatar(
              imageUrl: null,
              semanticLabel: 'Alice',
              size: 40,
            ),
          ),
        );
        final context = tester.element(find.byType(UserAvatar));
        final fallback = tester.widget<ColoredBox>(
          find.descendant(
            of: find.byType(UserAvatar),
            matching: find.byType(ColoredBox),
          ),
        );

        expect(
          fallback.color,
          Theme.of(context).extension<AppColors>()!.groupedBackground,
        );
        expect(
          find.descendant(
            of: find.byType(UserAvatar),
            matching: find.byType(Icon),
          ),
          findsNothing,
        );
        expect(
          tester.getSize(find.byType(ClipOval)),
          const Size.square(40),
        );
      });

      testWidgets('uses a disk-cached image sized for the device pixel ratio', (
        tester,
      ) async {
        await tester.pumpApp(
          const MediaQuery(
            data: MediaQueryData(devicePixelRatio: 3),
            child: Offstage(
              child: UserAvatar(
                imageUrl: 'https://example.com/avatar.png',
                semanticLabel: 'Alice',
                size: 40,
              ),
            ),
          ),
        );
        final image = tester.widget<CachedNetworkImage>(
          find.byType(CachedNetworkImage, skipOffstage: false),
        );

        expect(image.imageUrl, 'https://example.com/avatar.png');
        expect(image.fit, BoxFit.cover);
        expect(image.memCacheWidth, 120);
        expect(image.memCacheHeight, 120);
        expect(image.maxWidthDiskCache, 120);
        expect(image.maxHeightDiskCache, 120);
      });

      testWidgets('shows a static themed fallback while the image is loading', (
        tester,
      ) async {
        await tester.pumpApp(
          const Center(
            child: UserAvatar(
              imageUrl: 'https://example.com/loading-avatar.png',
              semanticLabel: 'Alice',
              size: 40,
            ),
          ),
        );
        final context = tester.element(find.byType(UserAvatar));
        final fallback = tester.widget<ColoredBox>(
          find.descendant(
            of: find.byType(UserAvatar),
            matching: find.byType(ColoredBox),
          ),
        );

        expect(
          fallback.color,
          Theme.of(context).extension<AppColors>()!.groupedBackground,
        );
        expect(find.byType(ShaderMask), findsNothing);
        expect(find.byIcon(Icons.person), findsNothing);
      });

      testWidgets('uses a static placeholder when animations are disabled', (
        tester,
      ) async {
        await tester.pumpApp(
          const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Center(
              child: UserAvatar(
                imageUrl: 'https://example.com/static-avatar.png',
                semanticLabel: 'Alice',
                size: 40,
              ),
            ),
          ),
        );
        final image = tester.widget<CachedNetworkImage>(
          find.byType(CachedNetworkImage),
        );

        expect(image.fadeInDuration, Duration.zero);
        expect(image.fadeOutDuration, Duration.zero);
        expect(find.byType(ShaderMask), findsNothing);
      });

      testWidgets('exposes the supplied label as image semantics', (
        tester,
      ) async {
        final semanticsHandle = tester.ensureSemantics();
        await tester.pumpApp(
          const Center(
            child: UserAvatar(
              imageUrl: null,
              semanticLabel: 'Alice',
              size: 40,
            ),
          ),
        );

        final semantics = tester.getSemantics(
          find.bySemanticsLabel('Alice'),
        );

        expect(semantics.label, 'Alice');
        expect(semantics.flagsCollection.isImage, isTrue);
        semanticsHandle.dispose();
      });
    });
  });
}
