import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/status/status.dart';
import 'package:dan/status/widgets/status_mention_suggestions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:status_repository/status_repository.dart';
import '../../helpers/helpers.dart';

class _MockStatuses extends Mock implements StatusRepository {}

class _MockPicker extends Mock implements StatusPhotoPicker {}

const _author = StatusAuthor(id: 'friend-id', name: '饭友', screenName: '饭友');
void main() {
  group(StatusMentionSuggestions, () {
    late StatusRepository statuses;
    late StatusComposerCubit composer;
    setUp(() {
      statuses = _MockStatuses();
      when(() => statuses.getMentions(limit: 60)).thenAnswer(
        (_) async => StatusPage(
          statuses: const [
            Status(id: '1', text: '@me', createdAt: '', author: _author),
          ],
          hasMore: false,
        ),
      );
      composer = StatusComposerCubit(
        statusRepository: statuses,
        photoPicker: _MockPicker(),
      );
    });
    tearDown(() => composer.close());
    Future<void> pump(
      WidgetTester tester, {
      StatusComposerMode mode = StatusComposerMode.compose,
    }) => tester.pumpApp(
      RepositoryProvider.value(
        value: statuses,
        child: BlocProvider.value(
          value: composer,
          child: StatusComposerView(accountId: 'me', mode: mode),
        ),
      ),
    );
    final editor = find.byKey(const Key('status-composer-text-field'));
    final popup = find.byKey(const Key('status-mention-suggestions'));
    group('completion', () {
      for (final mode in StatusComposerMode.values) {
        testWidgets(
          'toolbar starts an inline mention and completes it in $mode',
          (tester) async {
            await pump(tester, mode: mode);
            await tester.enterText(editor, '你好世界');
            final field = tester.widget<TextField>(editor);
            field.controller!.selection = const TextSelection.collapsed(
              offset: 2,
            );
            await tester.tap(find.byKey(const Key('status-composer-mention')));
            await tester.pumpAndSettle();
            expect(field.controller!.text, '你好 @ 世界');
            expect(popup, findsOneWidget);
            expect(find.byType(BottomSheet), findsNothing);
            expect(field.focusNode!.hasFocus, isTrue);
            await tester.tap(find.text('@friend-id'));
            await tester.pumpAndSettle();
            expect(field.controller!.text, '你好 @饭友 世界');
            expect(composer.state.content, field.controller!.text);
            expect(field.focusNode!.hasFocus, isTrue);
            expect(popup, findsNothing);
          },
        );
      }
      testWidgets(
        'typing @ opens suggestions below the token and filters locally',
        (tester) async {
          await pump(tester);
          await tester.enterText(editor, '第一行\n@');
          await tester.pumpAndSettle();
          expect(popup, findsOneWidget);
          expect(
            tester.getTopLeft(popup).dy,
            greaterThan(tester.getTopLeft(editor).dy),
          );
          await tester.enterText(editor, '第一行\n@饭');
          await tester.pumpAndSettle();
          await tester.tap(find.text('@friend-id'));
          await tester.pumpAndSettle();
          expect(
            tester.widget<TextField>(editor).controller!.text,
            '第一行\n@饭友 ',
          );
          verify(() => statuses.getMentions(limit: 60)).called(1);
        },
      );
      testWidgets(
        'space and deleting @ dismiss suggestions without changing text',
        (tester) async {
          await pump(tester);
          await tester.enterText(editor, '@');
          await tester.pumpAndSettle();
          await tester.enterText(editor, '@ ');
          await tester.pumpAndSettle();
          expect(popup, findsNothing);
          await tester.enterText(editor, '@');
          await tester.pumpAndSettle();
          await tester.enterText(editor, '');
          await tester.pumpAndSettle();
          expect(popup, findsNothing);
        },
      );
      testWidgets('closes after retry when there are no recent users', (
        tester,
      ) async {
        when(
          () => statuses.getMentions(limit: 60),
        ).thenThrow(Exception('offline'));
        await pump(tester);
        await tester.enterText(editor, '@');
        await tester.pumpAndSettle();
        when(() => statuses.getMentions(limit: 60)).thenAnswer(
          (_) async => StatusPage(statuses: const [], hasMore: false),
        );
        await tester.tap(find.text('重试'));
        await tester.pumpAndSettle();
        expect(popup, findsNothing);
        expect(find.byType(AppEmptyView), findsNothing);
      });
      testWidgets('keeps suggestions open when no recent user matches', (
        tester,
      ) async {
        await pump(tester);
        await tester.enterText(editor, '@missing');
        await tester.pumpAndSettle();
        expect(popup, findsOneWidget);
        expect(find.byType(AppEmptyView), findsOneWidget);
      });
      testWidgets('closes suggestions when there are no recent users', (
        tester,
      ) async {
        when(() => statuses.getMentions(limit: 60)).thenAnswer(
          (_) async => StatusPage(statuses: const [], hasMore: false),
        );
        await pump(tester);
        await tester.enterText(editor, '@');
        await tester.pumpAndSettle();
        expect(popup, findsNothing);
        verify(() => statuses.getMentions(limit: 60)).called(1);
      });
    });
  });
}
