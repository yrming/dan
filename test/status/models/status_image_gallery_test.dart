import 'package:dan/status/status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:status_repository/status_repository.dart';

void main() {
  group(StatusImageGallery, () {
    group('construction', () {
      test('snapshots only photo statuses in their original order', () {
        final first = _photo('first');
        final last = _photo('last');
        final statuses = [first, _photo('text').copyWith(photo: null), last];
        final gallery = StatusImageGallery(statuses: statuses);
        statuses.clear();

        expect(gallery.statuses, [first, last]);
        expect(gallery.statuses.clear, throwsUnsupportedError);
      });
    });

    group('statusFor', () {
      test('returns the selected photo status', () {
        final photo = _photo('selected');
        final gallery = StatusImageGallery(statuses: [_photo('first'), photo]);

        expect(gallery.statusFor('selected'), same(photo));
      });

      test('returns null for an absent status or empty gallery', () {
        final gallery = StatusImageGallery(statuses: [_photo('first')]);

        expect(gallery.statusFor('missing'), isNull);
        expect(gallery.statusFor(null), isNull);
        expect(
          StatusImageGallery(statuses: const []).statusFor('missing'),
          isNull,
        );
      });
    });
  });
}

Status _photo(String id) => Status(
  id: id,
  text: 'photo $id',
  createdAt: '2026-10-12',
  author: const StatusAuthor(id: 'user', name: 'User', screenName: 'user'),
  photo: StatusPhotoUrls(imageUrl: 'https://example.com/$id.png'),
);
