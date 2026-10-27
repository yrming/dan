import 'package:appearance_repository/appearance_repository.dart';
import 'package:dan/app/theme/app_colors.dart';
import 'package:dan/app/theme/app_layout.dart';
import 'package:dan/app/theme/app_sizing.dart';
import 'package:dan/app/theme/app_spacing.dart';
import 'package:dan/app/theme/app_style.dart';
import 'package:dan/app/theme/app_typography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Material themes for the Dan application.
abstract final class AppTheme {
  /// Creates the light application theme for [appearance].
  static ThemeData light({
    AppearanceSettings appearance = const AppearanceSettings(),
    TargetPlatform? platform,
  }) {
    const brightness = Brightness.light;
    const colors = AppColors.danLight;
    final primary = colors.wechatGreen;
    return _createTheme(
      appearance: appearance,
      brightness: brightness,
      colors: colors,
      primary: primary,
      onPrimary: AppColors.wechatGreenForeground,
      platform: platform ?? defaultTargetPlatform,
      systemUiOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: AppColors.transparent,
        systemNavigationBarColor: colors.bgBase,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  /// Creates the dark application theme for [appearance].
  static ThemeData dark({
    AppearanceSettings appearance = const AppearanceSettings(),
    TargetPlatform? platform,
  }) {
    const brightness = Brightness.dark;
    const colors = AppColors.danDark;
    final primary = colors.wechatGreen;
    return _createTheme(
      appearance: appearance,
      brightness: brightness,
      colors: colors,
      primary: primary,
      onPrimary: AppColors.wechatGreenForeground,
      platform: platform ?? defaultTargetPlatform,
      systemUiOverlayStyle: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: AppColors.transparent,
        systemNavigationBarColor: colors.bgBase,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  static ThemeData _createTheme({
    required AppearanceSettings appearance,
    required Brightness brightness,
    required AppColors colors,
    required Color primary,
    required Color onPrimary,
    required TargetPlatform platform,
    required SystemUiOverlayStyle systemUiOverlayStyle,
  }) {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: brightness,
        ).copyWith(
          primary: primary,
          onPrimary: onPrimary,
          error: AppColors.wechatRed,
          surface: colors.bgBase,
          onSurface: colors.textBase,
          onSurfaceVariant: colors.textSecondary,
          outlineVariant: colors.divider,
        );
    const buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppLayout.buttonRadius)),
    );
    final sizing = AppSizing(scale: appearance.scale);
    final typography = AppTypography.fromTheme(
      sizing: sizing,
      colorScheme: colorScheme,
      colors: colors,
    );
    final baseTheme = ThemeData(
      colorScheme: colorScheme,
      platform: platform,
      useMaterial3: true,
      splashFactory: NoSplash.splashFactory,
      splashColor: AppColors.transparent,
      highlightColor: AppColors.transparent,
    );
    return baseTheme.copyWith(
      scaffoldBackgroundColor: colorScheme.surface,
      extensions: [
        colors,
        sizing,
        AppStyle(
          statusPhotoStyle: appearance.statusPhotoStyle,
        ),
        typography,
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        toolbarHeight: sizing.appBarToolbarHeight,
        iconTheme: IconThemeData(
          color: colors.textBase,
          size: sizing.navigationIconSize,
        ),
        actionsIconTheme: IconThemeData(
          color: colors.textBase,
          size: sizing.navigationIconSize,
        ),
        actionsPadding: EdgeInsetsDirectional.only(
          end: sizing.appBarHorizontalPadding,
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: sizing.appBarHorizontalPadding,
        titleTextStyle: typography.navigationTitle,
        shape: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant,
            width: 0,
          ),
        ),
        systemOverlayStyle: systemUiOverlayStyle,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 0,
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 12,
        overlayColor: AppColors.transparent,
        thumbShape: RoundSliderThumbShape(
          elevation: 0,
          pressedElevation: 0,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
      ),
      badgeTheme: const BadgeThemeData(
        textColor: AppColors.wechatGreenForeground,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          disabledBackgroundColor: primary.withValues(alpha: 0.3),
          textStyle: typography.settingsValue.copyWith(
            fontWeight: FontWeight.w500,
          ),
          foregroundColor: AppColors.wechatGreenForeground,
          disabledForegroundColor: AppColors.wechatGreenForeground,
          shape: buttonShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: buttonShape),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(shape: buttonShape),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(shape: buttonShape),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        shape: buttonShape,
      ),
    );
  }
}
