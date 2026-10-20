import 'package:appearance_repository/appearance_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:dan/app/widgets/widgets.dart';
import 'package:dan/appearance/appearance.dart';
import 'package:dan/l10n/l10n.dart';
import 'package:dan/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:remixicon/remixicon.dart';

import '../../helpers/helpers.dart';

class _MockAppearanceCubit extends MockCubit<AppearanceState>
    implements AppearanceCubit {}

void main() {
  group(SettingsView, () {
    late AppearanceCubit appearanceCubit;

    setUpAll(() {
      registerFallbackValue(AppThemeMode.system);
      registerFallbackValue(StatusPhotoStyle.wechat);
    });

    setUp(() {
      appearanceCubit = _MockAppearanceCubit();
      when(() => appearanceCubit.state).thenReturn(_defaultState);
      when(
        () => appearanceCubit.updateFontSize(any()),
      ).thenAnswer((_) async {});
      when(
        () => appearanceCubit.updateThemeMode(any()),
      ).thenAnswer((_) async {});
      when(
        () => appearanceCubit.updateStatusPhotoStyle(any()),
      ).thenAnswer((_) async {});
    });

    Future<void> pumpView(
      WidgetTester tester, {
      AppearanceState state = _defaultState,
      Stream<AppearanceState>? states,
      VoidCallback? onFontSizePressed,
      VoidCallback? onBlacklistPressed,
      VoidCallback? onOpenSourceLicensesPressed,
      VoidCallback? onUserAgreementPressed,
      VoidCallback? onPrivacyPolicyPressed,
    }) async {
      if (states == null) {
        when(() => appearanceCubit.state).thenReturn(state);
      } else {
        whenListen(appearanceCubit, states, initialState: state);
      }
      await tester.pumpApp(
        BlocProvider.value(
          value: appearanceCubit,
          child: Scaffold(
            body: SettingsView(
              onFontSizePressed: onFontSizePressed,
              onBlacklistPressed: onBlacklistPressed,
              onOpenSourceLicensesPressed: onOpenSourceLicensesPressed,
              onUserAgreementPressed: onUserAgreementPressed,
              onPrivacyPolicyPressed: onPrivacyPolicyPressed,
            ),
          ),
        ),
        theme: AppTheme.light(),
      );
    }

    testWidgets('renders the current appearance settings', (tester) async {
      await pumpView(tester);
      final context = tester.element(find.byType(SettingsView));

      expect(find.text(context.l10n.appearanceFontSizeTitle), findsOneWidget);
      for (final icon in [
        RemixIcons.font_size,
        RemixIcons.moon_line,
        RemixIcons.image_2_line,
        RemixIcons.arrow_left_right_line,
        RemixIcons.logout_box_r_line,
        RemixIcons.forbid_line,
        RemixIcons.information_line,
        RemixIcons.code_s_slash_line,
        RemixIcons.file_text_line,
        RemixIcons.file_lock_line,
      ]) {
        expect(find.byIcon(icon), findsOneWidget);
      }
      expect(find.byType(Slider), findsNothing);
      expect(
        find.text(context.l10n.appearanceFontSizeValue(16)),
        findsNothing,
      );
      expect(find.text(context.l10n.appearanceThemeModeTitle), findsOneWidget);
      expect(
        find.text(context.l10n.appearanceStatusPhotoStyleTitle),
        findsOneWidget,
      );
      expect(find.text(context.l10n.appearanceThemeModeSystem), findsOneWidget);
      expect(
        find.text(context.l10n.appearanceStatusPhotoStyleFullWidth),
        findsOneWidget,
      );
    });

    testWidgets(
      'opens the blacklist from its own settings group',
      (tester) async {
        var opened = false;
        await pumpView(tester, onBlacklistPressed: () => opened = true);

        await tester.tap(find.byKey(const Key('settings-blacklist-row')));
        await tester.pump();

        expect(opened, isTrue);
      },
    );

    testWidgets('opens licenses from the row immediately below about', (
      tester,
    ) async {
      var opened = false;
      await pumpView(tester, onOpenSourceLicensesPressed: () => opened = true);

      final about = tester.getRect(find.byKey(const Key('settings-about-row')));
      final licenses = find.byKey(
        const Key('settings-open-source-licenses-row'),
      );
      expect(find.text('开源许可'), findsOneWidget);
      expect(tester.getTopLeft(licenses).dy, closeTo(about.bottom + 1, 0.001));
      expect(
        find.descendant(
          of: licenses,
          matching: find.byIcon(RemixIcons.code_s_slash_line),
        ),
        findsOneWidget,
      );
      await tester.tap(licenses);
      expect(opened, isTrue);
    });

    testWidgets('opens the legal entries from the about group', (tester) async {
      var agreementOpened = false;
      var privacyOpened = false;
      await pumpView(
        tester,
        onUserAgreementPressed: () => agreementOpened = true,
        onPrivacyPolicyPressed: () => privacyOpened = true,
      );

      await tester.tap(find.byKey(const Key('settings-user-agreement-row')));
      await tester.tap(find.byKey(const Key('settings-privacy-policy-row')));
      await tester.pump();

      expect(agreementOpened, isTrue);
      expect(privacyOpened, isTrue);
    });

    testWidgets('dismisses either panel without saving a change', (
      tester,
    ) async {
      await pumpView(tester);
      for (final key in [
        'settings-theme-mode-row',
        'settings-photo-style-row',
      ]) {
        await tester.tap(find.byKey(Key(key)));
        await tester.pumpAndSettle();
        expect(find.byType(AppActionSheetGroup), findsOneWidget);
        final items = tester.widgetList<AppActionSheetItem>(
          find.byType(AppActionSheetItem),
        );
        expect(
          items.where((item) => item.iconColor != AppColors.transparent),
          hasLength(1),
        );
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
      }
      verifyNever(() => appearanceCubit.updateThemeMode(any()));
      verifyNever(() => appearanceCubit.updateStatusPhotoStyle(any()));
    });

    testWidgets('prevents opening panels while loading', (tester) async {
      await pumpView(
        tester,
        state: const AppearanceState(
          status: AppearanceStatus.loading,
          settings: AppearanceSettings(),
        ),
      );
      await tester.tap(find.byKey(const Key('settings-theme-mode-row')));
      await tester.tap(find.byKey(const Key('settings-photo-style-row')));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      verifyNever(() => appearanceCubit.updateThemeMode(any()));
      verifyNever(() => appearanceCubit.updateStatusPhotoStyle(any()));
    });

    group('font size', () {
      testWidgets('opens the adjustment page from its setting row', (
        tester,
      ) async {
        var opened = false;
        await pumpView(tester, onFontSizePressed: () => opened = true);
        await tester.tap(find.byKey(const Key('settings-font-size-row')));
        await tester.pump();
        expect(opened, isTrue);
        verifyNever(() => appearanceCubit.updateFontSize(any()));
      });

      testWidgets('keeps only the chevron for a saved nonstandard size', (
        tester,
      ) async {
        await pumpView(
          tester,
          state: const AppearanceState(
            status: AppearanceStatus.success,
            settings: AppearanceSettings(fontSize: 18),
          ),
        );
        final context = tester.element(find.byType(SettingsView));
        expect(
          find.text(context.l10n.appearanceFontSizeValue(18)),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('settings-font-size-row')),
            matching: find.byIcon(Icons.chevron_right),
          ),
          findsOneWidget,
        );
      });
    });

    testWidgets('selects dark mode from the shared action sheet', (
      tester,
    ) async {
      await pumpView(tester);

      await tester.tap(find.byKey(const Key('settings-theme-mode-row')));
      await tester.pumpAndSettle();
      expect(find.byType(AppActionSheetGroup), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('settings-option-AppThemeMode.dark')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);

      verify(
        () => appearanceCubit.updateThemeMode(AppThemeMode.dark),
      ).called(1);
    });

    testWidgets('selects photo style from the shared action sheet', (
      tester,
    ) async {
      await pumpView(tester);

      await tester.tap(find.byKey(const Key('settings-photo-style-row')));
      await tester.pumpAndSettle();
      expect(find.byType(AppActionSheetGroup), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('settings-option-StatusPhotoStyle.wechat')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);

      verify(
        () => appearanceCubit.updateStatusPhotoStyle(StatusPhotoStyle.wechat),
      ).called(1);
    });

    group('renders', () {
      testWidgets('aligns account actions with settings and shows arrows', (
        tester,
      ) async {
        await pumpView(tester);
        final context = tester.element(find.byType(SettingsView));
        final titleLeft = tester
            .getTopLeft(
              find.text(context.l10n.appearanceFontSizeTitle),
            )
            .dx;

        for (final label in [
          context.l10n.accountSwitcherPageTitle,
          context.l10n.signOutLabel,
        ]) {
          expect(
            tester.getTopLeft(find.text(label)).dx,
            closeTo(titleLeft, 0.01),
          );
          final row = find.ancestor(
            of: find.text(label),
            matching: find.byType(ListTile),
          );
          expect(
            find.descendant(
              of: row,
              matching: find.byIcon(Icons.chevron_right),
            ),
            findsOneWidget,
          );
        }
      });
    });

    testWidgets(
      'invokes account actions when their rows are tapped',
      (tester) async {
        var switchAccountPressed = false;
        var signOutPressed = false;
        await tester.pumpApp(
          BlocProvider.value(
            value: appearanceCubit,
            child: Scaffold(
              body: SettingsView(
                onSwitchAccountPressed: () => switchAccountPressed = true,
                onSignOutPressed: () => signOutPressed = true,
              ),
            ),
          ),
          theme: AppTheme.light(),
        );
        final context = tester.element(find.byType(SettingsView));
        final switchAccountRow = find.ancestor(
          of: find.text(context.l10n.accountSwitcherPageTitle),
          matching: find.byType(InkWell),
        );
        final signOutRow = find.ancestor(
          of: find.text(context.l10n.signOutLabel),
          matching: find.byType(InkWell),
        );
        await tester.ensureVisible(signOutRow);
        await tester.pumpAndSettle();
        final switchAccountRect = tester.getRect(switchAccountRow);
        final signOutRect = tester.getRect(signOutRow);

        await tester.tapAt(
          Offset(switchAccountRect.left + 1, switchAccountRect.center.dy),
        );
        await tester.tapAt(
          Offset(signOutRect.right - 1, signOutRect.center.dy),
        );

        expect(switchAccountPressed, isTrue);
        expect(signOutPressed, isTrue);
        expect(find.byType(Divider), findsNWidgets(6));
        expect(
          tester.widget<InkWell>(switchAccountRow).splashFactory ??
              Theme.of(tester.element(switchAccountRow)).splashFactory,
          NoSplash.splashFactory,
        );
        expect(
          tester.widget<InkWell>(signOutRow).splashFactory ??
              Theme.of(tester.element(signOutRow)).splashFactory,
          NoSplash.splashFactory,
        );
        expect(
          tester.widget<InkWell>(switchAccountRow).highlightColor ??
              Theme.of(tester.element(switchAccountRow)).highlightColor,
          Colors.transparent,
        );
        expect(
          tester.widget<InkWell>(signOutRow).highlightColor ??
              Theme.of(tester.element(signOutRow)).highlightColor,
          Colors.transparent,
        );
      },
    );

    testWidgets('shows a localized message when saving fails', (
      tester,
    ) async {
      await pumpView(
        tester,
        states: Stream.value(
          const AppearanceState(
            status: AppearanceStatus.failure,
            settings: AppearanceSettings(),
          ),
        ),
      );
      await tester.pump();
      final context = tester.element(find.byType(SettingsView));

      expect(find.text(context.l10n.appearanceSaveFailure), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}

const _defaultState = AppearanceState(
  status: AppearanceStatus.success,
  settings: AppearanceSettings(),
);
