import 'package:dan/app/theme/app_colors.dart';
import 'package:dan/app/theme/app_sizing.dart';
import 'package:flutter/material.dart';

/// Application-specific typography expressed in product semantics.
@immutable
final class AppTypography extends ThemeExtension<AppTypography> {
  /// Creates application typography tokens.
  const AppTypography({
    required this.navigationTitle,
    required this.navigationLabel,
    required this.selectedNavigationLabel,
    required this.brandTagline,
    required this.loginConsent,
    required this.errorMessage,
    required this.settingsValue,
    required this.settingsSectionTitle,
    required this.accountName,
    required this.accountHandle,
    required this.accountDescription,
    required this.menuTitle,
    required this.menuSubtitle,
    required this.statusAuthor,
    required this.statusHandle,
    required this.statusBody,
    required this.dialogTitle,
    required this.dialogContent,
    required this.dialogAction,
    required this.actionSheetItem,
    required this.routeIdentifier,
  });

  /// Creates typography for the active sizing and color scheme.
  factory AppTypography.fromTheme({
    required AppSizing sizing,
    required ColorScheme colorScheme,
    required AppColors colors,
  }) {
    return AppTypography._create(
      sizing: sizing,
      colorScheme: colorScheme,
      colors: colors,
      navigationTitleWeight: FontWeight.w500,
      navigationFontSize: 16,
      statusAuthorColor: colors.textBase,
      statusAuthorFontSize: 16,
      statusHandleFontSize: 14,
      statusBodyFontSize: 16,
      statusBodyHeight: 1.4,
    );
  }

  factory AppTypography._create({
    required AppSizing sizing,
    required ColorScheme colorScheme,
    required AppColors colors,
    required FontWeight navigationTitleWeight,
    required double navigationFontSize,
    required Color statusAuthorColor,
    required double statusAuthorFontSize,
    required double statusHandleFontSize,
    required double statusBodyFontSize,
    required double statusBodyHeight,
  }) {
    TextStyle style(
      double fontSize, {
      Color? color,
      FontWeight fontWeight = FontWeight.w400,
      double? height,
    }) {
      return TextStyle(
        color: color ?? colors.textBase,
        fontSize: sizing.scaled(fontSize),
        fontWeight: fontWeight,
        height: height,
      );
    }

    return AppTypography(
      navigationTitle: style(
        navigationFontSize,
        fontWeight: navigationTitleWeight,
      ),
      navigationLabel: style(
        navigationFontSize,
        color: colors.textSecondary,
      ),
      selectedNavigationLabel: style(
        navigationFontSize,
        color: colors.textBase,
        fontWeight: navigationTitleWeight,
      ),
      brandTagline: style(28, fontWeight: FontWeight.w500, height: 1.25),
      loginConsent: style(12, color: colors.textSecondary),
      errorMessage: style(
        15,
        color: colorScheme.error,
        fontWeight: FontWeight.w600,
      ),
      settingsValue: style(15),
      settingsSectionTitle: style(16),
      accountName: style(22, fontWeight: FontWeight.w500, height: 1),
      accountHandle: style(16, height: 1),
      accountDescription: style(16),
      menuTitle: style(16),
      menuSubtitle: style(16, color: colors.textSecondary),
      statusAuthor: style(
        statusAuthorFontSize,
        color: statusAuthorColor,
        fontWeight: FontWeight.w500,
        height: 1,
      ),
      statusHandle: style(
        statusHandleFontSize,
        height: 1,
        color: colors.textSecondary,
      ),
      statusBody: style(statusBodyFontSize, height: statusBodyHeight),
      dialogTitle: style(16, fontWeight: FontWeight.w500, height: 1.4),
      dialogContent: style(
        15,
        color: colors.textSecondary,
        height: 1.4,
      ),
      dialogAction: style(16),
      actionSheetItem: style(16, fontWeight: FontWeight.w500),
      routeIdentifier: style(12),
    );
  }

  /// Navigation bar title.
  final TextStyle navigationTitle;

  /// Unselected bottom navigation label.
  final TextStyle navigationLabel;

  /// Selected bottom navigation label.
  final TextStyle selectedNavigationLabel;

  /// Login brand tagline.
  final TextStyle brandTagline;

  /// Login terms and privacy notice.
  final TextStyle loginConsent;

  /// User-visible error message.
  final TextStyle errorMessage;

  /// Current value displayed in a settings control.
  final TextStyle settingsValue;

  /// Settings section title.
  final TextStyle settingsSectionTitle;

  /// User display name in the shared profile header.
  final TextStyle accountName;

  /// User handle in the shared profile header.
  final TextStyle accountHandle;

  /// User biography in the shared profile header.
  final TextStyle accountDescription;

  /// Primary text in a grouped menu row.
  final TextStyle menuTitle;

  /// Secondary text in a grouped menu row.
  final TextStyle menuSubtitle;

  /// Status author in a timeline.
  final TextStyle statusAuthor;

  /// Status handle in a timeline.
  final TextStyle statusHandle;

  /// Status body text.
  final TextStyle statusBody;

  /// Title line in a centered alert dialog.
  final TextStyle dialogTitle;

  /// Content line in a centered alert dialog.
  final TextStyle dialogContent;

  /// Action button label in a centered alert dialog.
  final TextStyle dialogAction;

  /// Label for an individual action-sheet item.
  final TextStyle actionSheetItem;

  /// Resource identifier displayed with an error.
  final TextStyle routeIdentifier;

  @override
  AppTypography copyWith({
    TextStyle? navigationTitle,
    TextStyle? navigationLabel,
    TextStyle? selectedNavigationLabel,
    TextStyle? brandTagline,
    TextStyle? loginConsent,
    TextStyle? errorMessage,
    TextStyle? settingsValue,
    TextStyle? settingsSectionTitle,
    TextStyle? accountName,
    TextStyle? accountHandle,
    TextStyle? accountDescription,
    TextStyle? menuTitle,
    TextStyle? menuSubtitle,
    TextStyle? statusAuthor,
    TextStyle? statusHandle,
    TextStyle? statusBody,
    TextStyle? dialogTitle,
    TextStyle? dialogContent,
    TextStyle? dialogAction,
    TextStyle? actionSheetItem,
    TextStyle? routeIdentifier,
  }) {
    return AppTypography(
      navigationTitle: navigationTitle ?? this.navigationTitle,
      navigationLabel: navigationLabel ?? this.navigationLabel,
      selectedNavigationLabel:
          selectedNavigationLabel ?? this.selectedNavigationLabel,
      brandTagline: brandTagline ?? this.brandTagline,
      loginConsent: loginConsent ?? this.loginConsent,
      errorMessage: errorMessage ?? this.errorMessage,
      settingsValue: settingsValue ?? this.settingsValue,
      settingsSectionTitle: settingsSectionTitle ?? this.settingsSectionTitle,
      accountName: accountName ?? this.accountName,
      accountHandle: accountHandle ?? this.accountHandle,
      accountDescription: accountDescription ?? this.accountDescription,
      menuTitle: menuTitle ?? this.menuTitle,
      menuSubtitle: menuSubtitle ?? this.menuSubtitle,
      statusAuthor: statusAuthor ?? this.statusAuthor,
      statusHandle: statusHandle ?? this.statusHandle,
      statusBody: statusBody ?? this.statusBody,
      dialogTitle: dialogTitle ?? this.dialogTitle,
      dialogContent: dialogContent ?? this.dialogContent,
      dialogAction: dialogAction ?? this.dialogAction,
      actionSheetItem: actionSheetItem ?? this.actionSheetItem,
      routeIdentifier: routeIdentifier ?? this.routeIdentifier,
    );
  }

  @override
  AppTypography lerp(covariant AppTypography? other, double t) {
    if (other == null) return this;

    return AppTypography(
      navigationTitle: TextStyle.lerp(
        navigationTitle,
        other.navigationTitle,
        t,
      )!,
      navigationLabel: TextStyle.lerp(
        navigationLabel,
        other.navigationLabel,
        t,
      )!,
      selectedNavigationLabel: TextStyle.lerp(
        selectedNavigationLabel,
        other.selectedNavigationLabel,
        t,
      )!,
      brandTagline: TextStyle.lerp(brandTagline, other.brandTagline, t)!,
      loginConsent: TextStyle.lerp(loginConsent, other.loginConsent, t)!,
      errorMessage: TextStyle.lerp(errorMessage, other.errorMessage, t)!,
      settingsValue: TextStyle.lerp(settingsValue, other.settingsValue, t)!,
      settingsSectionTitle: TextStyle.lerp(
        settingsSectionTitle,
        other.settingsSectionTitle,
        t,
      )!,
      accountName: TextStyle.lerp(accountName, other.accountName, t)!,
      accountHandle: TextStyle.lerp(accountHandle, other.accountHandle, t)!,
      accountDescription: TextStyle.lerp(
        accountDescription,
        other.accountDescription,
        t,
      )!,
      menuTitle: TextStyle.lerp(menuTitle, other.menuTitle, t)!,
      menuSubtitle: TextStyle.lerp(menuSubtitle, other.menuSubtitle, t)!,
      statusAuthor: TextStyle.lerp(
        statusAuthor,
        other.statusAuthor,
        t,
      )!,
      statusHandle: TextStyle.lerp(
        statusHandle,
        other.statusHandle,
        t,
      )!,
      statusBody: TextStyle.lerp(statusBody, other.statusBody, t)!,
      dialogTitle: TextStyle.lerp(dialogTitle, other.dialogTitle, t)!,
      dialogContent: TextStyle.lerp(dialogContent, other.dialogContent, t)!,
      dialogAction: TextStyle.lerp(dialogAction, other.dialogAction, t)!,
      actionSheetItem: TextStyle.lerp(
        actionSheetItem,
        other.actionSheetItem,
        t,
      )!,
      routeIdentifier: TextStyle.lerp(
        routeIdentifier,
        other.routeIdentifier,
        t,
      )!,
    );
  }
}

/// Convenient access to application typography from the current theme.
extension AppTypographyBuildContext on BuildContext {
  /// Application-specific typography tokens.
  AppTypography get appTypography {
    final typography = Theme.of(this).extension<AppTypography>();
    assert(typography != null, 'AppTypography is not registered in ThemeData.');
    return typography!;
  }
}
