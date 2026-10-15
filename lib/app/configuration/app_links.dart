import 'package:url_launcher/url_launcher.dart';

/// Shared application links and external link behavior.
abstract final class AppLinks {
  /// The application's user agreement.
  static final Uri userAgreement = Uri.parse(
    'https://dan.yrm.dev/user-agreement',
  );

  /// The application's privacy policy.
  static final Uri privacyPolicy = Uri.parse(
    'https://dan.yrm.dev/privacy-policy',
  );

  /// Opens [uri] in the device's external application.
  static Future<bool> openExternal(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
