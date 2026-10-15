import 'dart:developer';

import 'package:appearance_repository/appearance_repository.dart';
import 'package:authentication_repository/authentication_repository.dart';
import 'package:dan/app/app.dart';
import 'package:dan/appearance/appearance.dart';
import 'package:dan/authentication/authentication.dart';
import 'package:dan/bootstrap.dart';
import 'package:dan/status/status.dart';
import 'package:direct_message_repository/direct_message_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:status_repository/status_repository.dart';
import 'package:user_api_client/user_api_client.dart';
import 'package:user_repository/user_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final configuration = FanfouConfiguration.fromEnvironment();
  final clientFactory = FanfouAuthenticationClientFactory(
    consumerKey: configuration.consumerKey,
    consumerSecret: configuration.consumerSecret,
  );
  final authenticationRepository = AuthenticationRepository(
    clientFactory: clientFactory.call,
    sessionStorage: SharedPreferencesAuthenticationSessionStorage(),
  );
  final statusRepository = StatusRepository(
    clientFactory: authenticationRepository.createClientForActiveAccount,
    activeAccountIdProvider: () =>
        authenticationRepository.currentAuthentication.activeAccount?.id,
  );
  final directMessageRepository = DirectMessageRepository(
    clientFactory: authenticationRepository.createClientForActiveAccount,
  );
  final userRepository = UserRepository(
    userApiClient: UserApiClient(
      clientFactory: authenticationRepository.createClientForActiveAccount,
    ),
  );
  final oauthAuthorizationService = FlutterWebOAuthAuthorizationService();
  final statusImageActionsService = DefaultStatusImageActionsService();
  final statusPhotoPicker = DefaultStatusPhotoPicker(ImagePicker());
  final appearanceRepository = AppearanceRepository(
    storage: SharedPreferencesAppearanceSettingsStorage(),
  );
  AppearanceSettings initialAppearanceSettings;
  try {
    initialAppearanceSettings = await appearanceRepository.load();
  } on Object catch (error, stackTrace) {
    log(
      'Unable to restore appearance settings.',
      error: error,
      stackTrace: stackTrace,
    );
    initialAppearanceSettings = const AppearanceSettings();
  }

  await bootstrap(
    () => App(
      appearanceRepository: appearanceRepository,
      authenticationRepository: authenticationRepository,
      initialAppearanceSettings: initialAppearanceSettings,
      oauthAuthorizationService: oauthAuthorizationService,
      statusImageActionsService: statusImageActionsService,
      statusPhotoPicker: statusPhotoPicker,
      statusRepository: statusRepository,
      statusDraftRepository: StatusDraftRepository.local(
        directory: getApplicationSupportDirectory,
      ),
      directMessageRepository: directMessageRepository,
      userRepository: userRepository,
    ),
  );
}
