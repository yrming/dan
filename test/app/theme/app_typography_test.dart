import 'package:dan/app/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(AppTypography, () {
    late ColorScheme colorScheme;

    setUp(() {
      colorScheme = ColorScheme.fromSeed(seedColor: Colors.blue);
    });

    test('creates semantic styles from the design baselines', () {
      final subject = AppTypography.fromTheme(
        sizing: const AppSizing(scale: 1),
        colorScheme: colorScheme,
        colors: AppColors.danLight,
      );

      expect(
        subject.navigationTitle.fontSize,
        16,
      );
      expect(
        subject.navigationLabel.fontSize,
        16,
      );
      expect(
        subject.selectedNavigationLabel.fontSize,
        16,
      );
      expect(subject.navigationTitle.fontWeight, FontWeight.w500);
      expect(subject.statusBody.fontSize, 16);
      expect(subject.statusAuthor.fontWeight, FontWeight.w500);
      expect(subject.accountName.fontSize, 22);
      expect(subject.accountName.fontWeight, FontWeight.w500);
      expect(subject.menuTitle.fontSize, 16);
      expect(subject.settingsSectionTitle.fontSize, 16);
      expect(subject.settingsSectionTitle.fontWeight, FontWeight.w400);
      expect(subject.actionSheetItem.fontSize, 16);
      expect(subject.actionSheetItem.fontWeight, FontWeight.w500);
      expect(subject.navigationTitle.color, AppColors.danLight.textBase);
      expect(
        subject.navigationLabel.color,
        AppColors.danLight.textSecondary,
      );
      expect(
        subject.selectedNavigationLabel.color,
        AppColors.danLight.textBase,
      );
    });

    test('scales every semantic style with the supplied sizing', () {
      final subject = AppTypography.fromTheme(
        sizing: const AppSizing(scale: 20 / 16),
        colorScheme: colorScheme,
        colors: AppColors.danLight,
      );

      expect(
        subject.statusBody.fontSize,
        closeTo(16 * (20 / 16), 0.000001),
      );
      expect(
        subject.statusHandle.fontSize,
        closeTo(14 * (20 / 16), 0.000001),
      );
      expect(subject.brandTagline.fontSize, closeTo(28 * (20 / 16), 0.000001));
      expect(subject.accountName.fontSize, closeTo(22 * (20 / 16), 0.000001));
      expect(subject.menuTitle.fontSize, closeTo(16 * (20 / 16), 0.000001));
    });

    test('creates the scaled account description style', () {
      final subject = AppTypography.fromTheme(
        sizing: const AppSizing(scale: 20 / 16),
        colorScheme: colorScheme,
        colors: AppColors.danLight,
      );

      expect(
        subject.accountDescription.fontSize,
        closeTo(16 * (20 / 16), 0.000001),
      );
      expect(
        subject.accountDescription.color,
        AppColors.danLight.textBase,
      );
    });

    test('creates the application status and navigation typography', () {
      final typography = AppTypography.fromTheme(
        sizing: const AppSizing(scale: 1),
        colorScheme: colorScheme,
        colors: AppColors.danLight,
      );

      expect(typography.navigationTitle.fontWeight, FontWeight.w500);
      expect(typography.statusAuthor.fontSize, 16);
      expect(
        typography.statusAuthor.color,
        AppColors.danLight.textBase,
      );
      expect(typography.statusBody.fontSize, 16);
      expect(typography.statusBody.height, 1.4);
    });

    test('leaves the font family unset for every semantic style', () {
      final subject = AppTypography.fromTheme(
        sizing: const AppSizing(scale: 1),
        colorScheme: colorScheme,
        colors: AppColors.danLight,
      );

      expect(
        [
          subject.navigationTitle,
          subject.navigationLabel,
          subject.selectedNavigationLabel,
          subject.brandTagline,
          subject.loginConsent,
          subject.errorMessage,
          subject.settingsValue,
          subject.settingsSectionTitle,
          subject.accountName,
          subject.accountHandle,
          subject.accountDescription,
          subject.menuTitle,
          subject.menuSubtitle,
          subject.statusAuthor,
          subject.statusHandle,
          subject.statusBody,
          subject.actionSheetItem,
          subject.routeIdentifier,
        ].map((style) => style.fontFamily),
        everyElement(isNull),
      );
    });
  });
}
