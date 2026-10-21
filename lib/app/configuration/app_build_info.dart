import 'dart:developer';

import 'package:package_info_plus/package_info_plus.dart';

/// Installed application metadata, loaded at the composition root.
class AppBuildInfo {
  /// Creates metadata; empty values represent unavailable platform information.
  const AppBuildInfo({this.version = '', this.buildNumber = ''});

  /// User-facing release version.
  final String version;

  /// Platform build identifier.
  final String buildNumber;

  /// Reads the installed package without preventing startup on failure.
  static Future<AppBuildInfo> load({
    Future<PackageInfo> Function()? loader,
  }) async {
    try {
      final info = await (loader ?? PackageInfo.fromPlatform)();
      return AppBuildInfo(version: info.version, buildNumber: info.buildNumber);
    } on Object catch (error, stackTrace) {
      log(
        'Unable to read package information.',
        error: error,
        stackTrace: stackTrace,
      );
      return const AppBuildInfo();
    }
  }
}
