part of 'login_bloc.dart';

/// User actions handled by [LoginBloc].
sealed class LoginEvent extends Equatable {
  const LoginEvent();

  @override
  List<Object?> get props => const [];
}

/// Browser-based OAuth authorization was requested.
final class LoginOAuthRequested extends LoginEvent {
  /// Creates an OAuth authorization request event.
  const LoginOAuthRequested();
}
