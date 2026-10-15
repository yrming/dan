import 'dart:async';

import 'package:appearance_repository/appearance_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:dan/appearance/appearance.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:dan/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/helpers.dart';

class _MockAppearanceCubit extends MockCubit<AppearanceState>
    implements AppearanceCubit {}

void main() {
  group(FontSizeView, () {
    late AppearanceCubit cubit;
    late StreamController<AppearanceState> states;

    setUp(() {
      cubit = _MockAppearanceCubit();
      states = StreamController<AppearanceState>();
      when(() => cubit.updateFontSize(any())).thenAnswer((_) async {});
    });

    tearDown(() async {
      await states.close();
      await cubit.close();
    });

    Future<void> pumpView(
      WidgetTester tester, {
      AppearanceState initialState = _defaultState,
      ThemeMode themeMode = ThemeMode.light,
    }) async {
      whenListen(cubit, states.stream, initialState: initialState);
      await tester.pumpApp(
        BlocProvider.value(
          value: cubit,
          child: const Scaffold(body: FontSizeView()),
        ),
        themeMode: themeMode,
      );
    }

    InlineSpan previewText(WidgetTester tester) {
      final context = tester.element(find.byType(FontSizeView));
      return tester
          .widget<Text>(
            find.text(context.l10n.appearanceFontPreviewText),
          )
          .textSpan!;
    }

    group('initial display', () {
      for (final size in [16.0, 18.0]) {
        testWidgets('previews the saved font size $size with nine steps', (
          tester,
        ) async {
          await pumpView(
            tester,
            initialState: AppearanceState(
              status: AppearanceStatus.success,
              settings: AppearanceSettings(fontSize: size),
            ),
          );
          final context = tester.element(find.byType(FontSizeView));
          final slider = tester.widget<Slider>(find.byType(Slider));
          expect(slider.value, size);
          expect(slider.min, 12);
          expect(slider.max, 20);
          expect(slider.divisions, 8);
          expect(previewText(tester).style?.fontSize, size);
          expect(
            find.text(context.l10n.appearanceFontPreviewName),
            findsOneWidget,
          );
          expect(slider.semanticFormatterCallback!(16), '16 号');
          expect(
            find.text(context.l10n.appearanceFontSizeStandard),
            findsNothing,
          );
          verifyNever(() => cubit.updateFontSize(any()));
        });
      }
    });

    group('adjustment', () {
      testWidgets(
        'scales the preview heading and instructions with font size',
        (
          tester,
        ) async {
          await pumpView(tester);
          final l10n = tester.element(find.byType(FontSizeView)).l10n;
          final labels = [
            l10n.appearanceFontPreviewTitle,
            l10n.appearanceFontSizeHint,
          ];
          final originalSizes = [
            for (final label in labels)
              tester.widget<Text>(find.text(label)).style!.fontSize!,
          ];

          for (final size in [20.0, 12.0]) {
            states.add(
              AppearanceState(
                status: AppearanceStatus.saving,
                settings: AppearanceSettings(fontSize: size),
              ),
            );
            await tester.pump();

            for (var index = 0; index < labels.length; index++) {
              expect(
                tester.widget<Text>(find.text(labels[index])).style!.fontSize,
                originalSizes[index] *
                    size /
                    AppearanceSettings.defaultFontSize,
              );
            }
          }
        },
      );

      testWidgets('saves and previews each step before the drag ends', (
        tester,
      ) async {
        final hapticCalls = <MethodCall>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'HapticFeedback.vibrate') hapticCalls.add(call);
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        when(() => cubit.updateFontSize(any())).thenAnswer((invocation) async {
          states.add(
            AppearanceState(
              status: AppearanceStatus.saving,
              settings: AppearanceSettings(
                fontSize: invocation.positionalArguments.first as double,
              ),
            ),
          );
        });
        await pumpView(tester);
        expect(hapticCalls, isEmpty);
        final sliderFinder = find.byType(Slider);
        final originalRect = tester.getRect(sliderFinder);
        final gesture = await tester.startGesture(originalRect.center);
        await gesture.moveBy(const Offset(500, 0));
        await tester.pump();

        verify(() => cubit.updateFontSize(20)).called(1);
        expect(tester.widget<Slider>(sliderFinder).value, 20);
        expect(previewText(tester).style?.fontSize, 20);
        expect(tester.getSize(sliderFinder), originalRect.size);
        expect(tester.getRect(sliderFinder).left, originalRect.left);
        expect(hapticCalls, hasLength(1));
        expect(
          hapticCalls.single.arguments,
          'HapticFeedbackType.selectionClick',
        );
        await gesture.moveBy(const Offset(-1, 0));
        await tester.pump();
        expect(hapticCalls, hasLength(1));
        await gesture.up();
        await tester.pump();
      });

      testWidgets('restores the saved preview and reports a save failure', (
        tester,
      ) async {
        await pumpView(tester);
        states.add(
          const AppearanceState(
            status: AppearanceStatus.saving,
            settings: AppearanceSettings(fontSize: 20),
          ),
        );
        await tester.pump();
        expect(previewText(tester).style?.fontSize, 20);

        states.add(_defaultState.copyWith(status: AppearanceStatus.failure));
        await tester.pump();
        final context = tester.element(find.byType(FontSizeView));
        expect(tester.widget<Slider>(find.byType(Slider)).value, 16);
        expect(previewText(tester).style?.fontSize, 16);
        expect(find.text(context.l10n.appearanceSaveFailure), findsOneWidget);
      });

      testWidgets('disables adjustments while preferences are loading', (
        tester,
      ) async {
        await pumpView(
          tester,
          initialState: _defaultState.copyWith(
            status: AppearanceStatus.loading,
          ),
        );
        expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
      });
    });

    group('layout', () {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        testWidgets('keeps the slider reachable on a small screen in $mode', (
          tester,
        ) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(320, 480);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          await pumpView(
            tester,
            themeMode: mode,
            initialState: const AppearanceState(
              status: AppearanceStatus.success,
              settings: AppearanceSettings(
                fontSize: 20,
              ),
            ),
          );
          expect(tester.takeException(), isNull);
          expect(find.byType(Slider).hitTestable(), findsOneWidget);
          final context = tester.element(find.byType(Slider));
          expect(
            Theme.of(context).brightness,
            mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
          );
          await tester.drag(find.byType(ListView), const Offset(0, -300));
          await tester.pump();
          expect(find.byType(Slider).hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    });
  });
}

const _defaultState = AppearanceState(
  status: AppearanceStatus.success,
  settings: AppearanceSettings(),
);
