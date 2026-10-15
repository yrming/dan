import 'package:appearance_repository/src/models/app_theme_mode.dart';
import 'package:appearance_repository/src/models/status_photo_style.dart';
import 'package:equatable/equatable.dart';

/// Persisted appearance preferences for the application.
final class AppearanceSettings extends Equatable {
  /// Creates appearance settings.
  const AppearanceSettings({
    this.fontSize = defaultFontSize,
    this.themeMode = AppThemeMode.system,
    this.statusPhotoStyle = StatusPhotoStyle.x,
  }) : assert(
         fontSize >= minimumFontSize && fontSize <= maximumFontSize,
         'fontSize must be between minimumFontSize and maximumFontSize.',
       );

  /// Default application font size and the baseline for UI scaling.
  static const defaultFontSize = 16.0;

  /// Smallest supported application font size.
  static const minimumFontSize = 12.0;

  /// Largest supported application font size.
  static const maximumFontSize = 20.0;

  /// Base font size selected by the user.
  final double fontSize;

  /// Light, dark, or system-controlled theme mode.
  final AppThemeMode themeMode;

  /// Layout used to display status photos.
  final StatusPhotoStyle statusPhotoStyle;

  /// Scale applied to dimensions designed at the default font-size baseline.
  double get scale => fontSize / defaultFontSize;

  /// Creates a copy with selected fields replaced.
  AppearanceSettings copyWith({
    double? fontSize,
    AppThemeMode? themeMode,
    StatusPhotoStyle? statusPhotoStyle,
  }) {
    return AppearanceSettings(
      fontSize: fontSize ?? this.fontSize,
      themeMode: themeMode ?? this.themeMode,
      statusPhotoStyle: statusPhotoStyle ?? this.statusPhotoStyle,
    );
  }

  @override
  List<Object> get props => [fontSize, themeMode, statusPhotoStyle];
}
