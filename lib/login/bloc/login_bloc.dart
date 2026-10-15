import 'package:authentication_repository/authentication_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:dan/authentication/oauth/oauth_authorization_service.dart';
import 'package:equatable/equatable.dart';

part 'login_event.dart';
part 'login_state.dart';

/// Coordinates browser-based Fanfou login.
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  /// Creates a login bloc backed by [authenticationRepository].
  factory LoginBloc({
    required AuthenticationRepository authenticationRepository,
    required OAuthAuthorizationService oauthAuthorizationService,
  }) {
    return LoginBloc._(
      authenticationRepository,
      oauthAuthorizationService,
    );
  }

  LoginBloc._(
    this._authenticationRepository,
    this._oauthAuthorizationService,
  ) : super(const LoginState()) {
    on<LoginOAuthRequested>(_onOAuthRequested);
  }

  final AuthenticationRepository _authenticationRepository;
  final OAuthAuthorizationService _oauthAuthorizationService;

  Future<void> _onOAuthRequested(
    LoginOAuthRequested event,
    Emitter<LoginState> emit,
  ) async {
    if (state.isInProgress) return;

    emit(state.copyWith(status: LoginSubmissionStatus.oauthInProgress));
    try {
      final authorizationUri = await _authenticationRepository
          .beginOAuthAuthorization(
            callbackUri: _oauthAuthorizationService.callbackUri,
          );
      final callbackUri = await _oauthAuthorizationService.authorize(
        authorizationUri,
      );
      await _authenticationRepository.completeOAuthAuthorization(callbackUri);
      emit(const LoginState(status: LoginSubmissionStatus.success));
    } on OAuthAuthorizationCancelled {
      emit(state.copyWith(status: LoginSubmissionStatus.initial));
    } on OAuthAuthorizationLaunchFailure {
      emit(state.copyWith(status: LoginSubmissionStatus.oauthFailure));
    } on AuthenticationFailure catch (failure) {
      emit(
        state.copyWith(
          status: _statusForFailure(failure),
          errorMessage: failure is AuthenticationApiFailure
              ? failure.message
              : null,
        ),
      );
    } on Object {
      emit(state.copyWith(status: LoginSubmissionStatus.failure));
    } finally {
      _authenticationRepository.cancelOAuthAuthorization();
    }
  }

  LoginSubmissionStatus _statusForFailure(AuthenticationFailure failure) {
    return switch (failure) {
      AuthenticationApiFailure() => LoginSubmissionStatus.apiFailure,
      AuthenticationStorageFailure() => LoginSubmissionStatus.storageFailure,
      OAuthAuthorizationDeniedFailure() => LoginSubmissionStatus.oauthDenied,
      OAuthAuthorizationNotStartedFailure() ||
      InvalidOAuthCallbackFailure() ||
      OAuthAuthorizationStateMismatchFailure() =>
        LoginSubmissionStatus.oauthFailure,
      MalformedAuthenticationResponseFailure() ||
      InvalidCredentialsFailure() ||
      AuthenticationUnknownFailure() ||
      AccountNotFoundFailure() ||
      AccountUnavailableFailure() => LoginSubmissionStatus.failure,
    };
  }
}
