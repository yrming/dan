import 'dart:convert';

import 'package:appearance_repository/appearance_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores all appearance preferences as one versioned JSON value.
final class SharedPreferencesAppearanceSettingsStorage
    implements AppearanceSettingsStorage {
  /// Creates a shared-preferences appearance settings store.
  SharedPreferencesAppearanceSettingsStorage({
    SharedPreferencesAsync? preferences,
  }) : _preferences = preferences ?? SharedPreferencesAsync();

  static const _storageVersion = 1;
  static const _settingsKey = 'dan.appearance.settings';

  final SharedPreferencesAsync _preferences;

  @override
  Future<AppearanceSettings?> read() async {
    final source = await _preferences.getString(_settingsKey);
    if (source == null) {
      return null;
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on Object {
      await _preferences.remove(_settingsKey);
      return null;
    }
    if (decoded is! Map<String, Object?>) {
      await _preferences.remove(_settingsKey);
      return null;
    }

    if (decoded['version'] != _storageVersion) {
      throw StateError('Unsupported appearance storage version.');
    }

    final fontSize = decoded['fontSize'];
    final themeMode = _themeModeFromName(decoded['themeMode']);
    final statusPhotoStyle = _statusPhotoStyleFromName(
      decoded['statusPhotoStyle'],
    );
    if (fontSize is! num ||
        fontSize < AppearanceSettings.minimumFontSize ||
        fontSize > AppearanceSettings.maximumFontSize ||
        themeMode == null ||
        statusPhotoStyle == null) {
      await _preferences.remove(_settingsKey);
      return null;
    }

    return AppearanceSettings(
      fontSize: fontSize.toDouble(),
      themeMode: themeMode,
      statusPhotoStyle: statusPhotoStyle,
    );
  }

  @override
  Future<void> write(AppearanceSettings settings) {
    return _preferences.setString(
      _settingsKey,
      jsonEncode(<String, Object>{
        'version': _storageVersion,
        'fontSize': settings.fontSize,
        'themeMode': settings.themeMode.name,
        'statusPhotoStyle': settings.statusPhotoStyle.name,
      }),
    );
  }

  static AppThemeMode? _themeModeFromName(Object? source) {
    if (source is! String) {
      return null;
    }
    for (final value in AppThemeMode.values) {
      if (value.name == source) {
        return value;
      }
    }
    return null;
  }

  static StatusPhotoStyle? _statusPhotoStyleFromName(Object? source) {
    if (source is! String) {
      return null;
    }
    for (final value in StatusPhotoStyle.values) {
      if (value.name == source) {
        return value;
      }
    }
    return null;
  }
}
