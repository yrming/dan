/// User-selectable application theme modes.
///
/// This repository-owned enum keeps the package independent from Flutter's
/// `ThemeMode` type.
enum AppThemeMode {
  /// Follow the operating system setting.
  system,

  /// Always use the light theme.
  light,

  /// Always use the dark theme.
  dark,
}
