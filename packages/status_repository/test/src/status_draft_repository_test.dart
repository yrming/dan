import 'dart:typed_data';
import 'package:mocktail/mocktail.dart';
import 'package:status_draft_storage/status_draft_storage.dart';
import 'package:status_repository/status_repository.dart';
import 'package:test/test.dart';

class _MockStorage extends Mock implements StatusDraftStorage {}

void main() {
  group(StatusDraftRepository, () {
    late StatusDraftStorage storage;
    late StatusDraftRepository repository;
    setUpAll(() {
      registerFallbackValue(const StoredStatusDraft(content: ''));
    });
    setUp(() {
      storage = _MockStorage();
      repository = StatusDraftRepository(storage: storage);
    });
    group('load', () {
      test('maps saved text and photo into an immutable draft', () async {
        final bytes = Uint8List.fromList([1, 2]);
        when(() => storage.read('a')).thenAnswer(
          (_) async => StoredStatusDraft(
            content: '内容',
            photoPath: '/a.png',
            photoBytes: bytes,
          ),
        );
        final draft = (await repository.load('a'))!;
        bytes[0] = 9;
        expect(draft.content, '内容');
        expect(draft.photoPath, '/a.png');
        expect(draft.photoBytes, [1, 2]);
        verify(() => storage.read('a')).called(1);
      });
      test('returns null for an account without a draft', () async {
        when(() => storage.read('a')).thenAnswer((_) async => null);
        expect(await repository.load('a'), isNull);
      });
      test('propagates storage failures', () async {
        when(() => storage.read('a')).thenThrow(Exception('unavailable'));
        await expectLater(repository.load('a'), throwsException);
      });
    });
    group('save and clear', () {
      test('passes the account and exact content to storage', () async {
        when(() => storage.write(any(), any())).thenAnswer((_) async {});
        when(() => storage.delete(any())).thenAnswer((_) async {});
        await repository.save('a', StatusDraft(content: ' 内容 '));
        final saved =
            verify(() => storage.write('a', captureAny())).captured.single
                as StoredStatusDraft;
        expect(saved.content, ' 内容 ');
        await repository.clear('a');
        verify(() => storage.delete('a')).called(1);
      });
    });
  });
}
