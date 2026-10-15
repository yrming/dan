import 'package:status_repository/status_repository.dart';
import 'package:test/test.dart';

void main() {
  group(StatusPage, () {
    test('copies input statuses into an immutable list', () {
      final statuses = <Status>[_status];
      final page = StatusPage(
        statuses: statuses,
        hasMore: true,
        nextCursor: 'cursor-a',
      );

      statuses.clear();

      expect(page.statuses, const [_status]);
      expect(page.statuses.clear, throwsUnsupportedError);
    });
  });
}

const _status = Status(
  id: 'status-a',
  text: 'hello',
  createdAt: 'Tue Jul 28 00:00:00 +0000 2026',
  author: StatusAuthor(
    id: 'user-a',
    name: 'User A',
    screenName: 'user_a',
  ),
);
