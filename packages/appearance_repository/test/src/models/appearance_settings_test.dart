import 'package:appearance_repository/appearance_repository.dart';
import 'package:test/test.dart';

void main() {
  group(AppearanceSettings, () {
    test('uses the documented defaults', () {
      const settings = AppearanceSettings();

      expect(settings.fontSize, 16);
      expect(settings.scale, 1);
      expect(AppearanceSettings.minimumFontSize, 12);
      expect(settings.themeMode, AppThemeMode.system);
      expect(settings.statusPhotoStyle, StatusPhotoStyle.x);
    });

    test('derives scale from the default 16px baseline', () {
      const settings = AppearanceSettings(fontSize: 20);

      expect(settings.scale, closeTo(20 / 16, 0.000001));
    });

    test('copyWith preserves fields that are not replaced', () {
      const settings = AppearanceSettings(
        fontSize: 18,
        themeMode: AppThemeMode.dark,
        statusPhotoStyle: StatusPhotoStyle.wechat,
      );

      expect(
        settings.copyWith(fontSize: 17),
        const AppearanceSettings(
          fontSize: 17,
          themeMode: AppThemeMode.dark,
          statusPhotoStyle: StatusPhotoStyle.wechat,
        ),
      );
    });

    test('copyWith replaces the status photo style', () {
      const settings = AppearanceSettings();

      expect(
        settings.copyWith(statusPhotoStyle: StatusPhotoStyle.wechat),
        const AppearanceSettings(statusPhotoStyle: StatusPhotoStyle.wechat),
      );
    });
  });
}
