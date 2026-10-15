part of 'login_bloc.dart';

/// Sanitized outcomes of a login submission.
enum LoginSubmissionStatus {
  /// No request is running and no failure is being shown.
  initial,

  /// A browser-based OAuth request is running.
  oauthInProgress,

  /// An account was added successfully.
  success,

  /// Fanfou or the network could not complete the request.
  apiFailure,

  /// The authenticated session could not be persisted.
  storageFailure,

  /// The user denied Fanfou browser authorization.
  oauthDenied,

  /// Browser-based OAuth could not be completed safely.
  oauthFailure,

  /// An unexpected, sanitized failure occurred.
  failure,
}

/// Immutable state of browser-based Fanfou login.
final class LoginState extends Equatable {
  /// Creates login state.
  const LoginState({
    this.status = LoginSubmissionStatus.initial,
    this.errorMessage,
  });

  /// Current submission outcome.
  final LoginSubmissionStatus status;

  /// Server-provided error text for the latest failed request.
  final String? errorMessage;

  /// Whether browser authorization currently owns the login flow.
  bool get isInProgress => status == LoginSubmissionStatus.oauthInProgress;

  /// Returns a new state with selected values replaced.
  LoginState copyWith({
    LoginSubmissionStatus? status,
    Object? errorMessage = _unset,
  }) {
    return LoginState(
      status: status ?? this.status,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];

  @override
  String toString() {
    return 'LoginState('
        'status: $status, '
        'errorMessage: $errorMessage, '
        'isInProgress: $isInProgress)';
  }
}

const _unset = Object();
