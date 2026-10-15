import 'package:appearance_repository/src/appearance_settings_storage.dart';
import 'package:appearance_repository/src/models/models.dart';

/// Provides persisted application appearance settings.
class AppearanceRepository {
  /// Creates an appearance repository backed by [storage].
  const AppearanceRepository({required this.storage});

  /// Storage used to persist the complete settings document.
  final AppearanceSettingsStorage storage;

  /// Loads the stored settings, or the defaults when none have been saved.
  Future<AppearanceSettings> load() async {
    return await storage.read() ?? const AppearanceSettings();
  }

  /// Persists [settings].
  Future<void> save(AppearanceSettings settings) => storage.write(settings);

  /// Restores and persists the default appearance settings.
  Future<AppearanceSettings> reset() async {
    const settings = AppearanceSettings();
    await storage.write(settings);
    return settings;
  }
}
