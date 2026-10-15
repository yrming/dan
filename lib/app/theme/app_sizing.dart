import 'dart:ui' show lerpDouble;

import 'package:dan/app/theme/app_layout.dart';
import 'package:dan/app/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Theme-provided dimensions derived from the user's base font size.
@immutable
final class AppSizing extends ThemeExtension<AppSizing> {
  /// Creates application sizing tokens for [scale].
  const AppSizing({required this.scale});

  /// Scale relative to the default application font-size baseline.
  final double scale;

  /// Scales an arbitrary design dimension.
  double scaled(double value, {double? minimum, double? maximum}) {
    var result = value * scale;
    if (minimum != null && result < minimum) {
      result = minimum;
    }
    if (maximum != null && result > maximum) {
      result = maximum;
    }
    return result;
  }

  /// iOS navigation bar height.
  double get appBarToolbarHeight => scaled(
    AppLayout.appBarToolbarHeight,
    minimum: AppLayout.appBarToolbarHeight,
  );

  /// Horizontal inset used by application bars.
  double get appBarHorizontalPadding => scaled(AppSpacing.md);

  /// Account avatar size used by application bars based on the 32px baseline.
  double get appBarAccountAvatarSize => scaled(32);

  /// iOS tab bar height.
  double get bottomNavigationBarHeight => scaled(
    AppLayout.bottomNavigationBarHeight,
    minimum: AppLayout.bottomNavigationBarHeight,
  );

  /// Status author avatar size based on the 44px design baseline.
  double get statusAvatarSize => scaled(44);

  /// Status body font size based on the 16px design baseline.
  double get statusFontSize => scaled(16);

  /// Navigation icon size based on the 26px design baseline.
  double get navigationIconSize => scaled(26);

  /// Central create-status button width.
  double get createStatusButtonWidth => scaled(
    AppLayout.createStatusButtonWidth,
  );

  /// Central create-status button height.
  double get createStatusButtonHeight => scaled(
    AppLayout.createStatusButtonHeight,
  );

  /// Central create-status button plus-sign length.
  double get createStatusButtonPlusSize => scaled(
    AppLayout.createStatusButtonPlusSize,
  );

  /// Shared stroke width for the create-status border and plus sign.
  double get createStatusButtonStrokeWidth => scaled(
    AppLayout.createStatusButtonStrokeWidth,
  );

  @override
  AppSizing copyWith({double? scale}) => AppSizing(scale: scale ?? this.scale);

  @override
  AppSizing lerp(covariant AppSizing? other, double t) {
    if (other == null) {
      return this;
    }
    return AppSizing(scale: lerpDouble(scale, other.scale, t) ?? scale);
  }
}

/// Convenient access to Dan's sizing theme extension.
extension AppSizingBuildContext on BuildContext {
  /// Scaled application dimensions for the current theme.
  AppSizing get appSizing {
    return Theme.of(this).extension<AppSizing>() ?? const AppSizing(scale: 1);
  }
}
