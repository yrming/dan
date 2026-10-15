import 'package:status_repository/status_repository.dart';
import 'package:test/test.dart';

void main() {
  group(StatusPhotoUrls, () {
    test('supports value equality', () {
      expect(
        const StatusPhotoUrls(
          thumbnailUrl: 'https://example.com/photo-thumb.png',
          imageUrl: 'https://example.com/photo.png',
          largeUrl: 'https://example.com/photo-large.png',
        ),
        equals(
          const StatusPhotoUrls(
            thumbnailUrl: 'https://example.com/photo-thumb.png',
            imageUrl: 'https://example.com/photo.png',
            largeUrl: 'https://example.com/photo-large.png',
          ),
        ),
      );
    });

    test('returns the thumbnail URL for compact previews', () {
      const photo = StatusPhotoUrls(
        thumbnailUrl: 'https://example.com/photo-thumb.png',
        imageUrl: 'https://example.com/photo.png',
        largeUrl: 'https://example.com/photo-large.png',
      );

      expect(photo.previewUrl, 'https://example.com/photo-thumb.png');
    });

    test('returns the regular image URL for inline display', () {
      const photo = StatusPhotoUrls(
        thumbnailUrl: 'https://example.com/photo-thumb.png',
        imageUrl: 'https://example.com/photo.png',
        largeUrl: 'https://example.com/photo-large.png',
      );

      expect(photo.displayUrl, 'https://example.com/photo.png');
    });

    test('returns the large URL for full-screen viewing', () {
      const photo = StatusPhotoUrls(
        thumbnailUrl: 'https://example.com/photo-thumb.png',
        imageUrl: 'https://example.com/photo.png',
        largeUrl: 'https://example.com/photo-large.png',
      );

      expect(photo.viewerUrl, 'https://example.com/photo-large.png');
    });
  });
}
