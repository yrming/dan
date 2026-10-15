import 'package:dan/status/status.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:status_repository/status_repository.dart';

class _MockImagePicker extends Mock implements ImagePicker {}

class _MockXFile extends Mock implements XFile {}

void main() {
  group(DefaultStatusPhotoPicker, () {
    late ImagePicker imagePicker;
    late DefaultStatusPhotoPicker subject;

    setUp(() {
      imagePicker = _MockImagePicker();
      subject = DefaultStatusPhotoPicker(imagePicker);
    });

    group('pickPhoto', () {
      test(
        'reads the selected gallery photo without requesting metadata',
        () async {
          final file = _MockXFile();
          final bytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
          when(() => file.path).thenReturn('/photo.png');
          when(file.readAsBytes).thenAnswer((_) async => bytes);
          when(
            () => imagePicker.pickImage(
              source: ImageSource.gallery,
              requestFullMetadata: false,
            ),
          ).thenAnswer((_) async => file);

          final result = (await subject.pickPhoto())!;

          expect(result.path, '/photo.png');
          expect(result.bytes, [137, 80, 78, 71, 13, 10, 26, 10]);
          bytes[0] = 9;
          expect(result.bytes.first, 137);
          expect(() => result.bytes[0] = 4, throwsUnsupportedError);
          verify(
            () => imagePicker.pickImage(
              source: ImageSource.gallery,
              requestFullMetadata: false,
            ),
          ).called(1);
        },
      );

      test('rejects a renamed unsupported image at selection', () async {
        final file = _MockXFile();
        when(() => file.path).thenReturn('/photo.jpg');
        when(
          file.readAsBytes,
        ).thenAnswer((_) async => Uint8List.fromList('RIFFxxxxWEBP'.codeUnits));
        when(
          () => imagePicker.pickImage(
            source: ImageSource.gallery,
            requestFullMetadata: false,
          ),
        ).thenAnswer((_) async => file);
        await expectLater(
          subject.pickPhoto(),
          throwsA(isA<StatusRepositoryPhotoFormatFailure>()),
        );
      });

      test('returns null when the user cancels', () async {
        when(
          () => imagePicker.pickImage(
            source: ImageSource.gallery,
            requestFullMetadata: false,
          ),
        ).thenAnswer((_) async => null);
        expect(await subject.pickPhoto(), isNull);
      });

      test('sanitizes platform permission errors', () async {
        when(
          () => imagePicker.pickImage(
            source: ImageSource.gallery,
            requestFullMetadata: false,
          ),
        ).thenThrow(PlatformException(code: 'photo_access_denied'));
        await expectLater(
          subject.pickPhoto(),
          throwsA(isA<StatusPhotoPickFailure>()),
        );
      });

      for (final empty in [true, false]) {
        test('rejects an unreadable or empty photo, empty=$empty', () async {
          final file = _MockXFile();
          when(
            () => imagePicker.pickImage(
              source: ImageSource.gallery,
              requestFullMetadata: false,
            ),
          ).thenAnswer((_) async => file);
          when(file.readAsBytes).thenAnswer((_) async {
            if (empty) return Uint8List(0);
            throw StateError('read failed');
          });
          await expectLater(
            subject.pickPhoto(),
            throwsA(isA<StatusPhotoPickFailure>()),
          );
        });
      }
    });
  });
}
