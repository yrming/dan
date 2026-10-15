import 'package:status_repository/status_repository.dart';
import 'package:test/test.dart';

void main() {
  group(StatusPhotoFormat, () {
    group('detect', () {
      for (final entry in {
        'image.jpg': ([255, 216, 255], StatusPhotoFormat.jpeg),
        'image.JPEG': ([255, 216, 255], StatusPhotoFormat.jpeg),
        'image.PNG': ([137, 80, 78, 71, 13, 10, 26, 10], StatusPhotoFormat.png),
        'image.gif': ('GIF87a'.codeUnits, StatusPhotoFormat.gif),
        'image.GIF': ('GIF89a'.codeUnits, StatusPhotoFormat.gif),
      }.entries) {
        test('accepts matching signature and extension ${entry.key}', () {
          expect(
            StatusPhotoFormat.detect(entry.key, entry.value.$1),
            entry.value.$2,
          );
        });
      }
      for (final path in [
        'photo.webp',
        'photo.heic',
        'photo',
        'photo.jpg.exe',
        'photo.png',
      ]) {
        test('rejects unsupported or mismatched extension $path', () {
          expect(
            () => StatusPhotoFormat.detect(path, [255, 216, 255]),
            throwsA(isA<StatusRepositoryPhotoFormatFailure>()),
          );
        });
      }
      test('rejects a truncated header', () {
        expect(
          () => StatusPhotoFormat.detect('photo.jpg', [255, 216]),
          throwsA(isA<StatusRepositoryPhotoFormatFailure>()),
        );
      });
    });
  });
}
