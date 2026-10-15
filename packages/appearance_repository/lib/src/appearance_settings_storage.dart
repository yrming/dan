import 'package:appearance_repository/src/models/models.dart';

/// Storage boundary used by the appearance repository.
abstract interface class AppearanceSettingsStorage {
  /// Reads the persisted settings, or `null` when no settings exist.
  Future<AppearanceSettings?> read();

  /// Persists the complete [settings] document.
  Future<void> write(AppearanceSettings settings);
}
