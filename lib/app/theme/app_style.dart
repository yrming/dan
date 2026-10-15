import 'package:appearance_repository/appearance_repository.dart';
import 'package:flutter/material.dart';

/// Application-wide style tokens that control component variants.
@immutable
final class AppStyle extends ThemeExtension<AppStyle> {
  /// Creates application style tokens.
  const AppStyle({
    required this.statusPhotoStyle,
  });

  /// Current user-selected status photo layout.
  final StatusPhotoStyle statusPhotoStyle;

  @override
  AppStyle copyWith({
    StatusPhotoStyle? statusPhotoStyle,
  }) {
    return AppStyle(
      statusPhotoStyle: statusPhotoStyle ?? this.statusPhotoStyle,
    );
  }

  @override
  AppStyle lerp(covariant AppStyle? other, double t) {
    if (other == null) return this;
    return AppStyle(
      statusPhotoStyle: t < 0.5 ? statusPhotoStyle : other.statusPhotoStyle,
    );
  }
}

/// Convenient access to application style tokens from the current theme.
extension AppStyleBuildContext on BuildContext {
  /// Application-specific style tokens.
  AppStyle get appStyle {
    final style = Theme.of(this).extension<AppStyle>();
    assert(style != null, 'AppStyle is not registered in ThemeData.');
    return style!;
  }

  /// Current user-selected status photo layout.
  StatusPhotoStyle get appStatusPhotoStyle => appStyle.statusPhotoStyle;
}
