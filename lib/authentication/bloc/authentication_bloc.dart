import 'package:authentication_repository/authentication_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'authentication_event.dart';
part 'authentication_state.dart';

/// Keeps the application synchronized with the authentication repository.
class AuthenticationBloc
    extends Bloc<AuthenticationEvent, AuthenticationState> {
  /// Creates an application-level authentication bloc.
  factory AuthenticationBloc({
    required AuthenticationRepository authenticationRepository,
  }) {
    return AuthenticationBloc._(authenticationRepository);
  }

  AuthenticationBloc._(this._authenticationRepository)
    : super(const AuthenticationInitial()) {
    on<AuthenticationSubscriptionRequested>(_onSubscriptionRequested);
    on<AuthenticationSignOutRequested>(_onSignOutRequested);
    on<AuthenticationAccountSwitchRequested>(_onAccountSwitchRequested);
  }

  final AuthenticationRepository _authenticationRepository;

  Future<void> _onSignOutRequested(
    AuthenticationSignOutRequested event,
    Emitter<AuthenticationState> emit,
  ) async {
    final accountId =
        _authenticationRepository.currentAuthentication.activeAccount?.id;
    if (accountId == null) {
      return;
    }
    await _authenticationRepository.removeAccount(accountId);
  }

  Future<void> _onAccountSwitchRequested(
    AuthenticationAccountSwitchRequested event,
    Emitter<AuthenticationState> emit,
  ) async {
    await _authenticationRepository.switchAccount(event.accountId);
  }

  Future<void> _onSubscriptionRequested(
    AuthenticationSubscriptionRequested event,
    Emitter<AuthenticationState> emit,
  ) async {
    if (state is! AuthenticationInitial &&
        state is! AuthenticationRestoreFailure) {
      return;
    }

    emit(const AuthenticationLoadInProgress());
    await emit.forEach(
      _authenticationSnapshots(),
      onData: _stateFromSnapshot,
      onError: (error, stackTrace) => const AuthenticationRestoreFailure(),
    );
  }

  Stream<AuthenticationSnapshot> _authenticationSnapshots() async* {
    yield await _authenticationRepository.restoreAccounts();
    yield* _authenticationRepository.authentication;
  }

  AuthenticationState _stateFromSnapshot(AuthenticationSnapshot snapshot) {
    return switch (snapshot.status) {
      AuthenticationStatus.unknown => const AuthenticationLoadInProgress(),
      AuthenticationStatus.authenticated => AuthenticationAuthenticated(
        snapshot,
      ),
      AuthenticationStatus.unauthenticated => AuthenticationUnauthenticated(
        snapshot,
      ),
    };
  }
}
