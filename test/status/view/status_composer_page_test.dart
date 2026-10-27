import 'dart:async';
import 'dart:convert';

import 'package:appearance_repository/appearance_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/view/app_subpage_app_bar.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:dan/status/status.dart';
import 'package:flutter/cupertino.dart' show CupertinoTheme;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:remixicon/remixicon.dart';

import '../../helpers/helpers.dart';

class _MockStatusComposerCubit extends MockCubit<StatusComposerState>
    implements StatusComposerCubit {}

void main() {
  group(StatusComposerView, () {
    late StatusComposerCubit statusComposerCubit;

    setUp(() {
      statusComposerCubit = _MockStatusComposerCubit();
      when(() => statusComposerCubit.pickPhoto()).thenAnswer((_) async {});
      when(
        () => statusComposerCubit.publish(),
      ).thenAnswer((_) async {});
    });

    Future<void> pumpView(
      WidgetTester tester, {
      StatusComposerState state = const StatusComposerState(),
      Stream<StatusComposerState>? states,
      ThemeData? theme,
      StatusComposerMode mode = StatusComposerMode.compose,
    }) async {
      if (states == null) {
        when(() => statusComposerCubit.state).thenReturn(state);
      } else {
        whenListen(statusComposerCubit, states, initialState: state);
      }
      await tester.pumpApp(
        BlocProvider.value(
          value: statusComposerCubit,
          child: StatusComposerView(mode: mode),
        ),
        theme: theme,
      );
    }

    testWidgets('renders an empty full-screen composer', (tester) async {
      await pumpView(tester);
      final context = tester.element(find.byType(StatusComposerView));
      final publishButton = tester.widget<FilledButton>(
        find.byKey(const Key('status-composer-publish')),
      );
      final buttonStyle = Theme.of(context).filledButtonTheme.style!;

      expect(find.text(context.l10n.statusComposerPageTitle), findsOneWidget);
      expect(find.text(context.l10n.statusComposerHint), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(
        tester
            .widget<UserAvatar>(
              find.byKey(const Key('status-composer-avatar')),
            )
            .imageUrl,
        isNull,
      );
      expect(
        find.byTooltip(context.l10n.statusComposerAddPhotoLabel),
        findsOneWidget,
      );
      final toolbarDecoration =
          tester
                  .widget<DecoratedBox>(
                    find.byKey(const Key('status-composer-photo-toolbar')),
                  )
                  .decoration
              as BoxDecoration;
      final toolbarBorder = toolbarDecoration.border! as Border;
      expect(toolbarBorder.top.color, AppColors.danLight.divider);
      expect(toolbarBorder.top.width, 0);
      expect(
        tester
            .widget<AppSubpageAppBar>(find.byType(AppSubpageAppBar))
            .showBottomDivider,
        isFalse,
      );
      expect(publishButton.onPressed, isNull);
      expect(
        tester.getSize(find.byKey(const Key('status-composer-publish'))),
        const Size(80, 36),
      );
      final disabledBackground = buttonStyle.backgroundColor?.resolve({
        WidgetState.disabled,
      });
      expect(
        disabledBackground,
        AppColors.danLight.wechatGreen.withValues(alpha: 0.3),
      );
      expect(
        buttonStyle.foregroundColor?.resolve({WidgetState.disabled}),
        AppColors.wechatGreenForeground,
      );
    });

    testWidgets('inserts a hashtag pair at the cursor', (tester) async {
      await pumpView(tester);
      final input = find.byType(TextField);
      final field = tester.widget<TextField>(input);
      field.controller!.value = const TextEditingValue(
        text: '你好世界',
        selection: TextSelection.collapsed(offset: 2),
      );

      await tester.tap(find.byKey(const Key('status-composer-hashtag')));
      await tester.pump();

      expect(field.controller!.text, '你好##世界');
      expect(
        field.controller!.selection,
        const TextSelection.collapsed(offset: 3),
      );
      verify(() => statusComposerCubit.contentChanged('你好##世界')).called(1);
    });

    group('remaining characters', () {
      for (final dark in [false, true]) {
        for (final mode in StatusComposerMode.values) {
          testWidgets(
            'updates the counter and publish limit, $mode dark=$dark',
            (
              tester,
            ) async {
              final states = StreamController<StatusComposerState>();
              addTearDown(states.close);
              when(() => statusComposerCubit.contentChanged(any())).thenAnswer((
                invocation,
              ) {
                states.add(
                  StatusComposerState(
                    content: invocation.positionalArguments.single as String,
                  ),
                );
              });
              await pumpView(
                tester,
                states: states.stream,
                mode: mode,
                theme: dark ? AppTheme.dark() : AppTheme.light(),
              );
              final counter = find.byKey(
                const Key('status-composer-remaining-characters'),
              );
              final input = find.byType(TextField);
              final button = find.byKey(const Key('status-composer-publish'));
              final context = tester.element(counter);
              expect(tester.widget<Text>(counter).data, '140');

              if (mode == StatusComposerMode.compose) {
                final icon = find.byIcon(RemixIcons.image_line);
                final toolbar = find.byKey(
                  const Key('status-composer-photo-toolbar'),
                );
                expect(tester.getCenter(counter).dy, tester.getCenter(icon).dy);
                expect(tester.getCenter(icon).dx, lessThan(60));
                expect(
                  tester.getTopRight(counter).dx,
                  greaterThan(tester.getTopRight(toolbar).dx - 30),
                );
              }

              for (final count in [139, 140, 141, 140, 0]) {
                await tester.enterText(input, '字' * count);
                await tester.pump();
                expect(tester.widget<Text>(counter).data, '${140 - count}');
                expect(
                  tester.widget<Text>(counter).style!.color,
                  count > 140
                      ? AppColors.wechatRed
                      : context.appColors.textSecondary,
                );
                expect(
                  tester.widget<FilledButton>(button).onPressed,
                  count > 0 && count <= 140 ? isNotNull : isNull,
                );
                expect(
                  tester.widget<TextField>(input).controller!.text,
                  '字' * count,
                );
              }
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    });

    group('text alignment', () {
      for (final (multilineText, fontSize) in [
        ('第一行\n第二行', 16.0),
        ('很长的正文' * 30, 16.0),
        ('第一行\n第二行', AppearanceSettings.maximumFontSize),
      ]) {
        testWidgets(
          'centers a single line and top-aligns multiple lines for '
          '${multilineText.contains('\n') ? 'newlines' : 'wrapping'} '
          'at font size $fontSize',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = const Size(320, 800);
            addTearDown(tester.view.reset);
            await pumpView(
              tester,
              theme: AppTheme.light(
                appearance: AppearanceSettings(fontSize: fontSize),
              ),
            );

            final avatar = find.byKey(const Key('status-composer-avatar'));
            final input = find.byType(TextField);
            final editable = find.byElementPredicate(
              (element) => element.renderObject is RenderEditable,
            );
            final avatarTop = tester.getTopLeft(avatar).dy;
            expect(tester.getCenter(editable).dy, tester.getCenter(avatar).dy);

            await tester.enterText(input, '一行正文');
            await tester.pump();
            expect(tester.getCenter(editable).dy, tester.getCenter(avatar).dy);

            await tester.enterText(input, multilineText);
            await tester.pump();
            expect(tester.getTopLeft(editable).dy, avatarTop);
            expect(tester.getTopLeft(avatar).dy, avatarTop);
            expect(
              tester.getSize(editable).height,
              greaterThan(tester.getSize(avatar).height),
            );

            await tester.enterText(input, '一行');
            await tester.pump();
            expect(tester.getCenter(editable).dy, tester.getCenter(avatar).dy);
            expect(tester.takeException(), isNull);
          },
        );
      }
    });

    group('photo picker', () {
      late StatusComposerPhoto photo;
      setUp(() {
        photo = StatusComposerPhoto(
          path: '/photo.png',
          bytes: base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYPj/HwADAgH/5ncLrgAAAABJRU5ErkJggg==',
          ),
        );
      });

      testWidgets('opens the picker from the bottom photo button', (
        tester,
      ) async {
        await pumpView(tester);
        await tester.tap(find.byKey(const Key('status-composer-add-photo')));
        await tester.pump();
        verify(() => statusComposerCubit.pickPhoto()).called(1);
      });

      for (final result in ['selected', 'cancelled', 'failed']) {
        testWidgets('restores text focus and cursor when picking is $result', (
          tester,
        ) async {
          final states = StreamController<StatusComposerState>();
          addTearDown(states.close);
          const draft = StatusComposerState(content: '继续编辑草稿');
          await pumpView(tester, state: draft, states: states.stream);
          await tester.showKeyboard(find.byType(TextField));
          final input = tester.widget<TextField>(find.byType(TextField));
          const selection = TextSelection.collapsed(offset: 2);
          input.controller!.selection = selection;
          await tester.pump();

          await tester.tap(find.byKey(const Key('status-composer-add-photo')));
          states.add(
            draft.copyWith(
              photoSelectionStatus: StatusPhotoSelectionStatus.picking,
            ),
          );
          await tester.pump();
          expect(input.focusNode!.hasFocus, isFalse);

          states.add(
            draft.copyWith(
              photo: result == 'selected' ? photo : null,
              photoSelectionStatus: result == 'failed'
                  ? StatusPhotoSelectionStatus.failure
                  : StatusPhotoSelectionStatus.idle,
            ),
          );
          await tester.pump();
          await tester.pump();
          expect(input.focusNode!.hasFocus, isTrue);
          expect(tester.testTextInput.isVisible, isTrue);
          expect(input.controller!.text, draft.content);
          expect(input.controller!.selection, selection);
          verify(() => statusComposerCubit.pickPhoto()).called(1);
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('keeps the toolbar above the keyboard and bottom safe area', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 800);
        tester.view.viewPadding = const FakeViewPadding(bottom: 24);
        tester.view.padding = const FakeViewPadding(bottom: 24);
        addTearDown(tester.view.reset);
        await pumpView(tester);

        final toolbar = find.byKey(const Key('status-composer-photo-toolbar'));
        final button = find.byKey(const Key('status-composer-add-photo'));
        final avatar = find.byKey(const Key('status-composer-avatar'));
        final input = find.byType(TextField);
        expect(
          tester.getTopRight(avatar).dx,
          lessThan(tester.getTopLeft(input).dx),
        );
        expect(tester.getCenter(avatar).dy, tester.getCenter(input).dy);
        expect(tester.getBottomLeft(toolbar).dy, 776);
        expect(
          find.byKey(const Key('status-composer-photo-attachment')),
          findsNothing,
        );

        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        tester.view.padding = FakeViewPadding.zero;
        await tester.pump();
        expect(tester.getBottomLeft(toolbar).dy, 500);
        expect(button.hitTestable(), findsOneWidget);

        await tester.enterText(
          find.byType(TextField),
          List.filled(30, '一行正文').join('\n'),
        );
        await tester.pump();
        expect(tester.getBottomLeft(toolbar).dy, 500);
        await tester.tap(button);
        await tester.pump();
        verify(() => statusComposerCubit.pickPhoto()).called(1);

        tester.view.viewInsets = FakeViewPadding.zero;
        tester.view.padding = const FakeViewPadding(bottom: 24);
        await tester.pump();
        expect(tester.getBottomLeft(toolbar).dy, 776);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'previews a selected photo and keeps replacement in the toolbar',
        (tester) async {
          await pumpView(
            tester,
            state: StatusComposerState(photo: photo, content: '保留草稿'),
          );
          await tester.runAsync(() async {
            await precacheImage(
              MemoryImage(photo.bytes),
              tester.element(find.byType(StatusComposerView)),
            );
          });
          await tester.pump();
          final context = tester.element(find.byType(StatusComposerView));
          expect(
            find.byKey(const Key('status-composer-photo-preview')),
            findsOneWidget,
          );
          expect(
            find.byTooltip(context.l10n.statusComposerReplacePhotoLabel),
            findsOneWidget,
          );
          expect(
            tester
                .widget<FilledButton>(
                  find.byKey(const Key('status-composer-publish')),
                )
                .onPressed,
            isNotNull,
          );
          await tester.tap(find.byKey(const Key('status-composer-add-photo')));
          await tester.pump();
          verify(() => statusComposerCubit.pickPhoto()).called(1);
          await tester.tap(
            find.byKey(const Key('status-composer-photo-preview')),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(
            find.byKey(const Key('status-composer-photo-fullscreen')),
            findsOneWidget,
          );
          verifyNever(() => statusComposerCubit.pickPhoto());
          await tester.tap(
            find.byKey(const Key('status-image-viewer-photo-0')),
          );
          await tester.pump(
            kDoubleTapTimeout + const Duration(milliseconds: 50),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(
            find.byKey(const Key('status-composer-photo-preview')),
            findsOneWidget,
          );
          expect(
            find.byTooltip(context.l10n.statusComposerRemovePhotoLabel),
            findsOneWidget,
          );
          expect(find.byType(BottomSheet), findsNothing);
          expect(find.text('保留草稿'), findsOneWidget);
          verifyNever(() => statusComposerCubit.removePhoto());
        },
      );

      testWidgets('removes the photo using its close button', (tester) async {
        await pumpView(tester, state: StatusComposerState(photo: photo));
        final photoFinder = find.byKey(
          const Key('status-composer-photo-preview'),
        );
        final input = find.byType(TextField);
        expect(tester.getSize(photoFinder).width, tester.getSize(input).width);
        expect(tester.getTopLeft(photoFinder).dx, tester.getTopLeft(input).dx);
        await tester.tap(find.byKey(const Key('status-composer-remove-photo')));
        await tester.pump();
        verify(() => statusComposerCubit.removePhoto()).called(1);
        expect(
          find.byKey(const Key('status-composer-photo-fullscreen')),
          findsNothing,
        );
      });

      testWidgets('long pressing the photo opens no actions', (
        tester,
      ) async {
        await pumpView(tester, state: StatusComposerState(photo: photo));
        await tester.longPress(
          find.byKey(const Key('status-composer-photo-preview')),
        );
        await tester.pump();

        expect(find.byType(BottomSheet), findsNothing);
        expect(
          find.byKey(const Key('status-composer-photo-preview')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('status-composer-photo-fullscreen')),
          findsNothing,
        );
        verifyNever(() => statusComposerCubit.pickPhoto());
        verifyNever(() => statusComposerCubit.removePhoto());
      });

      testWidgets('does not show photo actions for an empty slot', (
        tester,
      ) async {
        await pumpView(tester);
        await tester.longPress(
          find.byKey(const Key('status-composer-add-photo')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(BottomSheet), findsNothing);
        verifyNever(() => statusComposerCubit.removePhoto());
      });

      testWidgets(
        'shows toolbar progress and restores the icon on cancellation',
        (
          tester,
        ) async {
          final states = StreamController<StatusComposerState>();
          addTearDown(states.close);
          await pumpView(tester, states: states.stream);
          expect(find.byIcon(RemixIcons.image_line), findsOneWidget);

          states.add(
            const StatusComposerState(
              photoSelectionStatus: StatusPhotoSelectionStatus.picking,
            ),
          );
          await tester.pump();
          expect(find.byIcon(RemixIcons.image_line), findsNothing);
          expect(find.byType(CircularProgressIndicator), findsOneWidget);

          states.add(const StatusComposerState());
          await tester.pump();
          expect(find.byIcon(RemixIcons.image_line), findsOneWidget);
          expect(find.byType(CircularProgressIndicator), findsNothing);
        },
      );

      testWidgets('disables photo actions and publishing while selecting', (
        tester,
      ) async {
        await pumpView(
          tester,
          state: StatusComposerState(
            photo: photo,
            photoSelectionStatus: StatusPhotoSelectionStatus.picking,
          ),
        );
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.tap(find.byKey(const Key('status-composer-remove-photo')));
        verifyNever(() => statusComposerCubit.removePhoto());
        expect(
          tester
              .widget<IconButton>(
                find.byKey(const Key('status-composer-add-photo')),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<InkWell>(
                find.byKey(const Key('status-composer-photo-attachment')),
              )
              .onTap,
          isNull,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('status-composer-publish')),
              )
              .onPressed,
          isNull,
        );
      });

      testWidgets('does not preview the photo while publishing', (
        tester,
      ) async {
        await pumpView(
          tester,
          state: StatusComposerState(
            photo: photo,
            submissionStatus: StatusComposerSubmissionStatus.inProgress,
          ),
        );
        await tester.tap(
          find.byKey(const Key('status-composer-photo-preview')),
        );
        await tester.pump();

        expect(
          find.byKey(const Key('status-composer-photo-fullscreen')),
          findsNothing,
        );
        verifyNever(() => statusComposerCubit.removePhoto());
      });

      for (final duringSelection in [true, false]) {
        testWidgets(
          'explains allowed formats on rejection, selection=$duringSelection',
          (tester) async {
            await pumpView(
              tester,
              states: Stream.value(
                StatusComposerState(
                  photoSelectionStatus: duringSelection
                      ? StatusPhotoSelectionStatus.unsupportedFormat
                      : StatusPhotoSelectionStatus.idle,
                  submissionStatus: duringSelection
                      ? StatusComposerSubmissionStatus.initial
                      : StatusComposerSubmissionStatus.unsupportedPhotoFormat,
                ),
              ),
            );
            await tester.pump();
            final context = tester.element(find.byType(StatusComposerView));
            expect(
              find.text(context.l10n.statusComposerPhotoFormatFailure),
              findsOneWidget,
            );
          },
        );
      }

      testWidgets('shows a localized message when selection fails', (
        tester,
      ) async {
        await pumpView(
          tester,
          states: Stream.value(
            const StatusComposerState(
              photoSelectionStatus: StatusPhotoSelectionStatus.failure,
            ),
          ),
        );
        await tester.pump();
        final context = tester.element(find.byType(StatusComposerView));
        expect(
          find.text(context.l10n.statusComposerPhotoPickFailure),
          findsOneWidget,
        );
      });
    });

    testWidgets('forwards draft changes to the cubit', (tester) async {
      await pumpView(tester);

      await tester.enterText(find.byType(TextField), '新的动态');
      await tester.pump();

      verify(() => statusComposerCubit.contentChanged('新的动态')).called(1);
    });

    testWidgets('uses the theme primary color for the cursor', (
      tester,
    ) async {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        await pumpView(tester, theme: theme);
        final context = tester.element(find.byType(TextField));

        expect(
          tester.widget<EditableText>(find.byType(EditableText)).cursorColor,
          theme.colorScheme.primary,
        );
        expect(
          CupertinoTheme.of(context).primaryColor,
          theme.colorScheme.primary,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('submits a non-empty draft', (tester) async {
      await pumpView(
        tester,
        state: const StatusComposerState(content: '新的动态'),
      );

      await tester.tap(
        find.byKey(const Key('status-composer-publish')),
      );
      await tester.pump();

      verify(() => statusComposerCubit.publish()).called(1);
    });

    testWidgets('renders white publish text in both themes and button states', (
      tester,
    ) async {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        for (final content in ['', '新的动态']) {
          await pumpView(
            tester,
            state: StatusComposerState(content: content),
            theme: theme,
          );
          final context = tester.element(find.byType(StatusComposerView));
          final labelContext = tester.element(
            find.text(context.l10n.statusComposerPublishLabel),
          );
          final style = DefaultTextStyle.of(labelContext).style;

          expect(style.color, AppColors.wechatGreenForeground);
          expect(style.fontSize, 15 * theme.extension<AppSizing>()!.scale);
          expect(style.fontWeight, FontWeight.w500);
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
    });

    testWidgets('shows progress and disables editing while publishing', (
      tester,
    ) async {
      await pumpView(
        tester,
        state: const StatusComposerState(
          content: '新的动态',
          submissionStatus: StatusComposerSubmissionStatus.inProgress,
        ),
        theme: AppTheme.light(),
      );

      final indicatorFinder = find.byType(CircularProgressIndicator);
      final indicator = tester.widget<CircularProgressIndicator>(
        indicatorFinder,
      );
      final sizing = AppTheme.light().extension<AppSizing>()!;

      expect(indicatorFinder, findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('status-composer-publish'))).width,
        80,
      );
      expect(indicator.color, AppColors.wechatGreenForeground);
      expect(indicator.strokeCap, StrokeCap.round);
      expect(
        tester.getSize(indicatorFinder),
        Size.square(sizing.scaled(16)),
      );
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const Key('status-composer-close')),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('shows a localized message when publishing fails', (
      tester,
    ) async {
      await pumpView(
        tester,
        states: Stream.value(
          const StatusComposerState(
            content: '新的动态',
            submissionStatus: StatusComposerSubmissionStatus.failure,
          ),
        ),
      );
      await tester.pump();
      final context = tester.element(find.byType(StatusComposerView));

      expect(find.text(context.l10n.statusComposerFailure), findsOneWidget);
    });
  });
}
