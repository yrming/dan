import 'dart:convert';

import 'package:appearance_repository/appearance_repository.dart';
import 'package:dan/appearance/appearance.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSharedPreferencesAsync extends Mock
    implements SharedPreferencesAsync {}

void main() {
  group(SharedPreferencesAppearanceSettingsStorage, () {
    late SharedPreferencesAsync preferences;
    late String? storedSettings;
    late SharedPreferencesAppearanceSettingsStorage subject;

    setUp(() {
      preferences = _MockSharedPreferencesAsync();
      storedSettings = null;
      when(() => preferences.getString(_settingsKey)).thenAnswer(
        (_) async => storedSettings,
      );
      when(() => preferences.remove(_settingsKey)).thenAnswer((_) async {
        storedSettings = null;
      });
      when(
        () => preferences.setString(_settingsKey, any()),
      ).thenAnswer((invocation) async {
        storedSettings = invocation.positionalArguments[1] as String;
      });
      subject = SharedPreferencesAppearanceSettingsStorage(
        preferences: preferences,
      );
    });

    group('read', () {
      test('returns null when no settings have been stored', () async {
        expect(await subject.read(), isNull);
        verify(() => preferences.getString(_settingsKey)).called(1);
      });

      test('preserves stored small-photo $AppearanceSettings', () async {
        storedSettings = jsonEncode(<String, Object>{
          'version': 1,
          'fontSize': 18,
          'themeMode': 'dark',
          'statusPhotoStyle': 'wechat',
        });

        expect(
          await subject.read(),
          const AppearanceSettings(
            fontSize: 18,
            themeMode: AppThemeMode.dark,
            statusPhotoStyle: StatusPhotoStyle.wechat,
          ),
        );
      });

      test('deletes malformed JSON and returns null', () async {
        storedSettings = '{not-json';

        expect(await subject.read(), isNull);
        expect(storedSettings, isNull);
        verify(() => preferences.remove(_settingsKey)).called(1);
      });

      test('deletes settings containing unsupported values', () async {
        storedSettings = jsonEncode(<String, Object>{
          'version': 1,
          'fontSize': 21,
          'themeMode': 'automatic',
          'statusPhotoStyle': 'tiles',
        });

        expect(await subject.read(), isNull);
        expect(storedSettings, isNull);
      });

      test('deletes settings below the minimum font size', () async {
        storedSettings = jsonEncode(<String, Object>{
          'version': 1,
          'fontSize': 11,
          'themeMode': 'system',
          'statusPhotoStyle': 'wechat',
        });

        expect(await subject.read(), isNull);
        expect(storedSettings, isNull);
        verify(() => preferences.remove(_settingsKey)).called(1);
      });

      test('preserves an unsupported version and throws a state error', () {
        storedSettings = jsonEncode(<String, Object>{
          'version': 2,
          'fontSize': 15,
          'themeMode': 'system',
          'statusPhotoStyle': 'x',
        });
        final originalSettings = storedSettings;

        expect(subject.read, throwsStateError);
        expect(storedSettings, originalSettings);
        verifyNever(() => preferences.remove(_settingsKey));
      });

      test('propagates platform preference failures', () {
        final failure = PlatformException(code: 'unavailable');
        when(() => preferences.getString(_settingsKey)).thenThrow(failure);

        expect(subject.read, throwsA(same(failure)));
      });
    });

    group('write', () {
      test('stores all settings in one versioned JSON document', () async {
        const settings = AppearanceSettings(
          themeMode: AppThemeMode.light,
        );

        await subject.write(settings);

        final decoded = jsonDecode(storedSettings!) as Map<String, Object?>;
        expect(decoded, <String, Object?>{
          'version': 1,
          'fontSize': 16.0,
          'themeMode': 'light',
          'statusPhotoStyle': 'x',
        });
        verify(() => preferences.setString(_settingsKey, any())).called(1);
      });
    });
  });
}

const _settingsKey = 'dan.appearance.settings';
