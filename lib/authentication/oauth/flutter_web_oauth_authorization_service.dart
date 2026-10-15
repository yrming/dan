import 'package:dan/authentication/oauth/oauth_authorization_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

/// Signature used to replace the platform authenticator in tests.
typedef OAuthWebAuthenticator =
    Future<String> Function({
      required String url,
      required String callbackUrlScheme,
      FlutterWebAuth2Options options,
    });

/// Runs Fanfou OAuth in the platform system-browser authentication session.
final class FlutterWebOAuthAuthorizationService
    implements OAuthAuthorizationService {
  /// Creates the production browser authorization service.
  FlutterWebOAuthAuthorizationService({
    OAuthWebAuthenticator? authenticate,
  }) : _authenticate = authenticate ?? FlutterWebAuth2.authenticate;

  static const _callbackScheme = 'dev.yrm.dan';
  static final _callbackUri = Uri(
    scheme: _callbackScheme,
    host: 'oauth',
    path: '/callback',
  );

  final OAuthWebAuthenticator _authenticate;

  @override
  Uri get callbackUri => _callbackUri;

  @override
  Future<Uri> authorize(Uri authorizationUri) async {
    try {
      final result = await _authenticate(
        url: authorizationUri.toString(),
        callbackUrlScheme: _callbackScheme,
        options: const FlutterWebAuth2Options(preferEphemeral: true),
      );
      return Uri.parse(result);
    } on PlatformException catch (error) {
      if (error.code == 'CANCELED') {
        throw const OAuthAuthorizationCancelled();
      }
      throw const OAuthAuthorizationLaunchFailure();
    } on Object catch (_) {
      throw const OAuthAuthorizationLaunchFailure();
    }
  }
}
