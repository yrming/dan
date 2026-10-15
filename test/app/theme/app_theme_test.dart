import 'package:appearance_repository/appearance_repository.dart';
import 'package:dan/app/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(AppTheme, () {
    test('maps the theme WeChat green into the color scheme', () {
      final lightTheme = AppTheme.light();
      final darkTheme = AppTheme.dark();

      expect(lightTheme.colorScheme.primary, AppColors.danLight.wechatGreen);
      expect(
        lightTheme.colorScheme.onPrimary,
        AppColors.wechatGreenForeground,
      );
      expect(darkTheme.colorScheme.primary, AppColors.danDark.wechatGreen);
      expect(
        darkTheme.colorScheme.onPrimary,
        AppColors.wechatGreenForeground,
      );
      for (final theme in [lightTheme, darkTheme]) {
        expect(
          theme.filledButtonTheme.style?.foregroundColor?.resolve({}),
          AppColors.wechatGreenForeground,
        );
        expect(
          theme.filledButtonTheme.style?.foregroundColor?.resolve({
            WidgetState.disabled,
          }),
          AppColors.wechatGreenForeground,
        );
      }
    });

    test('maps application color tokens into light and dark themes', () {
      final lightTheme = AppTheme.light();
      final darkTheme = AppTheme.dark();

      expect(lightTheme.extension<AppColors>(), same(AppColors.danLight));
      expect(lightTheme.colorScheme.primary, AppColors.danLight.wechatGreen);
      expect(lightTheme.colorScheme.surface, AppColors.danLight.bgBase);
      expect(darkTheme.extension<AppColors>(), same(AppColors.danDark));
      expect(darkTheme.colorScheme.primary, AppColors.danDark.wechatGreen);
      expect(darkTheme.colorScheme.surface, AppColors.danDark.bgBase);
    });

    test('creates distinct light and dark themes', () {
      expect(AppTheme.light().brightness, Brightness.light);
      expect(AppTheme.dark().brightness, Brightness.dark);
    });

    test('uses platform system fonts without overriding the font family', () {
      for (final platform in TargetPlatform.values) {
        final theme = AppTheme.light(platform: platform);
        final typography = theme.extension<AppTypography>()!;

        expect(theme.platform, platform);
        expect(typography.statusBody.fontFamily, isNull);
        expect(theme.appBarTheme.titleTextStyle?.fontFamily, isNull);
      }
    });

    test('uses Cupertino separator colors in light and dark themes', () {
      expect(
        AppTheme.light().colorScheme.outlineVariant,
        AppColors.danLight.divider,
      );
      expect(
        AppTheme.dark().colorScheme.outlineVariant,
        AppColors.danDark.divider,
      );
    });

    test(
      'uses the shared floating snack bar style in light and dark themes',
      () {
        final lightSnackBar = AppTheme.light().snackBarTheme;
        final darkSnackBar = AppTheme.dark().snackBarTheme;

        expect(lightSnackBar.behavior, SnackBarBehavior.floating);
        expect(lightSnackBar.backgroundColor, const Color(0xFF313131));
        expect(
          lightSnackBar.contentTextStyle?.color,
          const Color(0xFFFBFBFB),
        );
        expect(darkSnackBar.behavior, SnackBarBehavior.floating);
        expect(darkSnackBar.backgroundColor, const Color(0xFF242424));
        expect(
          darkSnackBar.contentTextStyle?.color,
          const Color(0xFFFBFBFB),
        );
        expect(lightSnackBar.contentTextStyle?.fontSize, 16);
        expect(darkSnackBar.contentTextStyle?.fontSize, 16);

        final scaledSnackBar = AppTheme.light(
          appearance: const AppearanceSettings(fontSize: 20),
        ).snackBarTheme;
        expect(scaledSnackBar.contentTextStyle?.fontSize, 20);
      },
    );

    test('registers and maps application color tokens', () {
      final lightTheme = AppTheme.light();
      final darkTheme = AppTheme.dark();

      expect(
        lightTheme.extension<AppStyle>()?.statusPhotoStyle,
        StatusPhotoStyle.x,
      );
      expect(lightTheme.extension<AppColors>(), same(AppColors.danLight));
      expect(lightTheme.colorScheme.surface, AppColors.danLight.bgBase);
      expect(lightTheme.colorScheme.onSurface, AppColors.danLight.textBase);
      expect(
        lightTheme.colorScheme.onSurfaceVariant,
        AppColors.danLight.textSecondary,
      );
      expect(
        lightTheme.colorScheme.outlineVariant,
        AppColors.danLight.divider,
      );
      expect(
        darkTheme.extension<AppStyle>()?.statusPhotoStyle,
        StatusPhotoStyle.x,
      );
      expect(darkTheme.extension<AppColors>(), same(AppColors.danDark));
      expect(darkTheme.colorScheme.surface, AppColors.danDark.bgBase);
      expect(darkTheme.colorScheme.onSurface, AppColors.danDark.textBase);
    });

    test('registers the selected status photo style', () {
      final theme = AppTheme.light(
        appearance: const AppearanceSettings(
          statusPhotoStyle: StatusPhotoStyle.wechat,
        ),
      );

      expect(
        theme.extension<AppStyle>()?.statusPhotoStyle,
        StatusPhotoStyle.wechat,
      );
    });

    test('scales typography and dimensions from the 16px baseline', () {
      final theme = AppTheme.light(
        appearance: const AppearanceSettings(fontSize: 20),
      );
      final sizing = theme.extension<AppSizing>()!;

      expect(sizing.scale, closeTo(20 / 16, 0.000001));
      expect(sizing.statusFontSize, closeTo(16 * (20 / 16), 0.000001));
      expect(sizing.statusAvatarSize, closeTo(44 * (20 / 16), 0.000001));
      expect(
        sizing.appBarAccountAvatarSize,
        closeTo(32 * (20 / 16), 0.000001),
      );
      expect(
        sizing.appBarHorizontalPadding,
        closeTo(16 * (20 / 16), 0.000001),
      );
      expect(
        theme.extension<AppTypography>()?.statusBody.fontSize,
        closeTo(16 * (20 / 16), 0.000001),
      );
      expect(sizing.appBarToolbarHeight, closeTo(44 * (20 / 16), 0.000001));
      expect(
        theme.appBarTheme.toolbarHeight,
        closeTo(44 * (20 / 16), 0.000001),
      );
      expect(
        theme.appBarTheme.iconTheme?.size,
        closeTo(26 * (20 / 16), 0.000001),
      );
      expect(
        theme.appBarTheme.iconTheme?.color,
        AppColors.danLight.textBase,
      );
      expect(
        theme.appBarTheme.actionsIconTheme?.size,
        closeTo(26 * (20 / 16), 0.000001),
      );
      expect(
        theme.appBarTheme.actionsIconTheme?.color,
        AppColors.danLight.textBase,
      );
      expect(
        sizing.bottomNavigationBarHeight,
        closeTo(50 * (20 / 16), 0.000001),
      );
    });

    test('registers application-specific typography', () {
      final lightTheme = AppTheme.light();
      final darkTheme = AppTheme.dark();
      final lightTypography = lightTheme.extension<AppTypography>()!;
      final darkTypography = darkTheme.extension<AppTypography>()!;

      expect(lightTypography.statusBody.fontSize, 16);
      expect(
        darkTypography.statusBody.color,
        darkTheme.colorScheme.onSurface,
      );
    });

    test('does not shrink navigation hit areas below their baselines', () {
      final theme = AppTheme.light(
        appearance: const AppearanceSettings(fontSize: 12),
      );
      final sizing = theme.extension<AppSizing>()!;

      expect(sizing.appBarToolbarHeight, 44);
      expect(sizing.bottomNavigationBarHeight, 50);
    });

    test('uses 16px application bar content insets at the baseline scale', () {
      final theme = AppTheme.light();

      expect(theme.appBarTheme.titleSpacing, 16);
      expect(
        theme.appBarTheme.actionsPadding,
        const EdgeInsetsDirectional.only(end: 16),
      );
      expect(theme.appBarTheme.toolbarHeight, 44);
    });
  });
}
