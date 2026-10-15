import 'package:status_repository/status_repository.dart';
import 'package:test/test.dart';

void main() {
  group(Status, () {
    test('preserves, replaces and clears the reply relationship', () {
      const original = Status(
        id: 'reply',
        text: 'hello',
        createdAt: '',
        author: StatusAuthor(id: 'user', name: 'User', screenName: 'user'),
        inReplyToStatusId: 'parent',
        inReplyToUserId: 'parent-author',
      );
      expect(original.copyWith(isFavorited: true).inReplyToStatusId, 'parent');
      expect(
        original.copyWith(isFavorited: true).inReplyToUserId,
        'parent-author',
      );
      expect(
        original.copyWith(inReplyToUserId: 'other').inReplyToUserId,
        'other',
      );
      expect(original.copyWith(inReplyToUserId: null).inReplyToUserId, isNull);
      expect(original.copyWith(inReplyToUserId: null), isNot(original));
      expect(
        original.copyWith(inReplyToStatusId: 'other').inReplyToStatusId,
        'other',
      );
      expect(
        original.copyWith(inReplyToStatusId: null).inReplyToStatusId,
        isNull,
      );
      expect(original.copyWith(inReplyToStatusId: null), isNot(original));
    });

    test('supports value equality', () {
      expect(
        const Status(
          id: 'status-a',
          text: 'hello',
          createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
          author: StatusAuthor(
            id: 'user-a',
            name: 'User A',
            screenName: 'user_a',
          ),
        ),
        equals(
          const Status(
            id: 'status-a',
            text: 'hello',
            createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
            author: StatusAuthor(
              id: 'user-a',
              name: 'User A',
              screenName: 'user_a',
            ),
          ),
        ),
      );
    });

    test('copies selected fields without changing the remaining values', () {
      const status = Status(
        id: 'status-a',
        text: 'hello',
        createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
        author: StatusAuthor(
          id: 'user-a',
          name: 'User A',
          screenName: 'user_a',
        ),
        photo: StatusPhotoUrls(
          thumbnailUrl: 'https://example.com/photo-thumb.png',
          imageUrl: 'https://example.com/photo.png',
          largeUrl: 'https://example.com/photo-large.png',
        ),
      );

      expect(
        status.copyWith(isFavorited: true, isSelf: true, photo: null),
        const Status(
          id: 'status-a',
          text: 'hello',
          createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
          author: StatusAuthor(
            id: 'user-a',
            name: 'User A',
            screenName: 'user_a',
          ),
          isFavorited: true,
          isSelf: true,
        ),
      );
    });
  });
}
