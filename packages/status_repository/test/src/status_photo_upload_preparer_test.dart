import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as image;
import 'package:status_repository/status_repository.dart';
import 'package:test/test.dart';

void main() {
  group(StatusPhotoUploadPreparer, () {
    late Directory directory;
    late File source;
    late StatusPhotoUploadPreparer subject;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('dan-photo-test-');
      source = File('${directory.path}/original.png');
      subject = const StatusPhotoUploadPreparer();
    });

    tearDown(() => directory.delete(recursive: true));

    group('prepare', () {
      for (final size in [100, 4194304]) {
        test('uploads $size bytes unchanged without creating a copy', () async {
          final bytes = Uint8List(size)
            ..setAll(0, image.encodePng(image.Image(width: 1, height: 1)));
          await source.writeAsBytes(bytes);
          final result = await subject.prepare(source);
          expect(result.file.path, source.path);
          expect(result.temporaryDirectory, isNull);
          await result.dispose();
          expect(await source.readAsBytes(), bytes);
        });
      }

      test(
        'compresses a large photo to at most 4 MiB and preserves the original',
        () async {
          final photo = _noisePhoto(1400, 1100);
          final bytes = image.encodePng(photo, level: 0);
          expect(bytes.length, greaterThan(4194304));
          await source.writeAsBytes(bytes);
          final result = await subject.prepare(source);
          addTearDown(result.dispose);

          expect(result.file.path, endsWith('.jpg'));
          expect(await result.file.length(), lessThanOrEqualTo(4194304));
          final decoded = image.decodeJpg(await result.file.readAsBytes())!;
          expect(decoded.width, photo.width);
          expect(decoded.height, photo.height);
          expect(await source.readAsBytes(), bytes);
          await result.dispose();
          expect(result.file.existsSync(), isFalse);
          expect(source.existsSync(), isTrue);
        },
      );

      test(
        'reduces dimensions when quality adjustment alone is insufficient',
        () async {
          subject = const StatusPhotoUploadPreparer(maxBytes: 1500);
          final photo = _noisePhoto(160, 120);
          await source.writeAsBytes(image.encodePng(photo));
          final result = await subject.prepare(source);
          addTearDown(result.dispose);
          final decoded = image.decodeJpg(await result.file.readAsBytes())!;

          expect(await result.file.length(), lessThanOrEqualTo(1500));
          expect(decoded.width, lessThan(photo.width));
          expect(decoded.width / decoded.height, closeTo(4 / 3, 0.05));
        },
      );

      for (final size in [0, 4194305]) {
        test(
          'rejects empty or undecodable oversized input with size $size',
          () async {
            final bytes = Uint8List(size);
            if (size > 0) bytes.setAll(0, [137, 80, 78, 71, 13, 10, 26, 10]);
            await source.writeAsBytes(bytes);
            await expectLater(
              subject.prepare(source),
              throwsA(isA<StatusRepositoryPhotoPreparationFailure>()),
            );
            expect(await source.length(), size);
          },
        );
      }

      test('keeps a GIF at the exact 3 MiB limit unchanged', () async {
        source = File('${directory.path}/animation.GIF');
        final bytes = Uint8List(3145728)
          ..setAll(0, image.encodeGif(image.Image(width: 1, height: 1)));
        await source.writeAsBytes(bytes);
        final result = await subject.prepare(source);
        expect(result.file.path, source.path);
        await result.dispose();
        expect(source.existsSync(), isTrue);
      });

      for (final useDefaultLimit in [true, false]) {
        test(
          'compresses GIF preserving animation, default=$useDefaultLimit',
          () async {
            source = File('${directory.path}/animation.gif');
            final animation = _noisePhoto(100, 80)
              ..loopCount = 3
              ..frameDuration = 120
              ..addFrame(_noisePhoto(100, 80)..frameDuration = 230);
            final encoded = image.encodeGif(animation);
            final limit = useDefaultLimit ? 3145728 : 5000;
            subject = StatusPhotoUploadPreparer(maxGifBytes: limit);
            final bytes = useDefaultLimit
                ? (Uint8List(3145729)..setAll(0, encoded))
                : encoded;
            await source.writeAsBytes(bytes);
            final result = await subject.prepare(source);
            addTearDown(result.dispose);
            expect(result.file.path, endsWith('.gif'));
            expect(result.file.path, isNot(source.path));
            expect(await result.file.length(), lessThanOrEqualTo(limit));
            final decoded = image.decodeGif(await result.file.readAsBytes())!;
            expect(decoded.numFrames, 2);
            expect(decoded.loopCount, 3);
            expect(decoded.frames.map((frame) => frame.frameDuration), [
              120,
              230,
            ]);
            if (!useDefaultLimit) expect(decoded.width, lessThan(100));
            expect(await source.readAsBytes(), bytes);
          },
        );
      }

      for (final name in [
        'photo.webp',
        'photo.heic',
        'photo.jpg',
        'photo.png.exe',
      ]) {
        test(
          'rejects unsupported or mismatched format $name before upload',
          () async {
            source = File('${directory.path}/$name');
            await source.writeAsBytes(
              image.encodePng(image.Image(width: 1, height: 1)),
            );
            await expectLater(
              subject.prepare(source),
              throwsA(isA<StatusRepositoryPhotoFormatFailure>()),
            );
          },
        );
      }

      test('sanitizes a missing file error', () async {
        await expectLater(
          subject.prepare(source),
          throwsA(isA<StatusRepositoryPhotoPreparationFailure>()),
        );
      });
    });
  });
}

image.Image _noisePhoto(int width, int height) {
  final random = Random(42);
  final photo = image.Image(width: width, height: height);
  for (final pixel in photo) {
    pixel.setRgb(random.nextInt(256), random.nextInt(256), random.nextInt(256));
  }
  return photo;
}
