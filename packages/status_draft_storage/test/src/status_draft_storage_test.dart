import 'dart:io';
import 'dart:typed_data';
import 'package:status_draft_storage/status_draft_storage.dart';
import 'package:test/test.dart';

void main() {
  group(StatusDraftStorage, () {
    late Directory directory;
    late StatusDraftStorage storage;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('dan_draft_test_');
      storage = StatusDraftStorage(directory: () async => directory);
    });
    tearDown(() async => directory.delete(recursive: true));
    group('read and write', () {
      test('returns null when no draft was saved', () async {
        expect(await storage.read('author'), isNull);
      });
      test(
        'restores exact text and photo after storage is recreated',
        () async {
          final bytes = Uint8List.fromList([1, 2, 3]);
          await storage.write(
            'author',
            StoredStatusDraft(
              content: '  草稿\n第二行 ',
              photoPath: '/temporary/photo.PNG',
              photoBytes: bytes,
            ),
          );
          final reopened = StatusDraftStorage(directory: () async => directory);
          final draft = (await reopened.read('author'))!;
          expect(draft.content, '  草稿\n第二行 ');
          expect(draft.photoBytes, bytes);
          expect(await File(draft.photoPath!).readAsBytes(), bytes);
          expect(draft.photoPath, startsWith(directory.path));
        },
      );
      test(
        'replaces content and removes the old attachment from the draft',
        () async {
          await storage.write(
            'author',
            StoredStatusDraft(
              content: '旧',
              photoPath: '/a.jpg',
              photoBytes: Uint8List.fromList([1]),
            ),
          );
          await storage.write('author', const StoredStatusDraft(content: '新'));
          final draft = (await storage.read('author'))!;
          expect(draft.content, '新');
          expect(draft.photoPath, isNull);
          expect(draft.photoBytes, isNull);
        },
      );
    });
    group('delete', () {
      test('isolates accounts and clears only the requested account', () async {
        await storage.write('../first', const StoredStatusDraft(content: '甲'));
        await storage.write('second', const StoredStatusDraft(content: '乙'));
        await storage.delete('../first');
        await storage.delete('../first');
        expect(await storage.read('../first'), isNull);
        expect((await storage.read('second'))!.content, '乙');
      });
    });
  });
}
