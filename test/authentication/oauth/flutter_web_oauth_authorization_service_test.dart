import 'package:dan/authentication/authentication.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

void main() {
  group(FlutterWebOAuthAuthorizationService, () {
    test(
      'uses the namespaced callback and returns the parsed callback',
      () async {
        late String capturedUrl;
        late String capturedScheme;
        late FlutterWebAuth2Options capturedOptions;
        final subject = FlutterWebOAuthAuthorizationService(
          authenticate:
              ({
                required url,
                required callbackUrlScheme,
                options = const FlutterWebAuth2Options(),
              }) async {
                capturedUrl = url;
                capturedScheme = callbackUrlScheme;
                capturedOptions = options;
                return _callbackUri.toString();
              },
        );

        final result = await subject.authorize(_authorizationUri);

        expect(subject.callbackUri, Uri.parse('dev.yrm.dan://oauth/callback'));
        expect(capturedUrl, _authorizationUri.toString());
        expect(capturedScheme, 'dev.yrm.dan');
        expect(capturedOptions.preferEphemeral, isTrue);
        expect(result, _callbackUri);
      },
    );

    test('maps platform cancellation to a sanitized cancellation', () async {
      final subject = FlutterWebOAuthAuthorizationService(
        authenticate:
            ({
              required url,
              required callbackUrlScheme,
              options = const FlutterWebAuth2Options(),
            }) async {
              throw PlatformException(
                code: 'CANCELED',
                message: 'sensitive platform details',
              );
            },
      );

      await expectLater(
        subject.authorize(_authorizationUri),
        throwsA(isA<OAuthAuthorizationCancelled>()),
      );
    });

    test('maps other errors to a sanitized launch failure', () async {
      final subject = FlutterWebOAuthAuthorizationService(
        authenticate:
            ({
              required url,
              required callbackUrlScheme,
              options = const FlutterWebAuth2Options(),
            }) async {
              throw PlatformException(
                code: 'FAILED',
                message: 'sensitive platform details',
              );
            },
      );

      await expectLater(
        subject.authorize(_authorizationUri),
        throwsA(isA<OAuthAuthorizationLaunchFailure>()),
      );
    });
  });
}

final Uri _authorizationUri = Uri.parse(
  'https://fanfou.com/oauth/authorize?oauth_token=request-token',
);
final Uri _callbackUri = Uri.parse(
  'dev.yrm.dan://oauth/callback?oauth_token=request-token&oauth_verifier=pin',
);
