import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:naijapulse/core/error/failures.dart';
import 'package:naijapulse/features/auth/domain/usecases/get_cached_session.dart';
import 'package:naijapulse/features/auth/domain/usecases/login_user.dart';
import 'package:naijapulse/features/auth/domain/usecases/logout_user.dart';
import 'package:naijapulse/features/auth/domain/usecases/register_user.dart';
import 'package:naijapulse/features/auth/presentation/bloc/auth_event.dart';
import 'package:naijapulse/features/auth/presentation/bloc/auth_state.dart';

export 'auth_event.dart';
export 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required GetCachedSession getCachedSession,
    required LoginUser loginUser,
    required RegisterUser registerUser,
    required LogoutUser logoutUser,
  }) : _getCachedSession = getCachedSession,
       _loginUser = loginUser,
       _registerUser = registerUser,
       _logoutUser = logoutUser,
       super(const AuthState()) {
    on<AuthSessionCheckedRequested>(_onSessionChecked);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  final GetCachedSession _getCachedSession;
  final LoginUser _loginUser;
  final RegisterUser _registerUser;
  final LogoutUser _logoutUser;

  Future<void> _onSessionChecked(
    AuthSessionCheckedRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final session = await _getCachedSession();
      if (session == null) {
        emit(const AuthState(status: AuthStatus.unauthenticated));
        return;
      }
      emit(AuthState(status: AuthStatus.authenticated, session: session));
    } catch (error) {
      emit(
        AuthState(
          status: AuthStatus.failure,
          errorMessage: mapFailure(error).message,
        ),
      );
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading, errorMessage: null));
    try {
      final session = await _loginUser(
        email: event.email,
        password: event.password,
      );
      emit(AuthState(status: AuthStatus.authenticated, session: session));
    } catch (error) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          errorMessage: mapFailure(error).message,
        ),
      );
    }
  }

  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading, errorMessage: null));
    try {
      final session = await _registerUser(
        email: event.email,
        password: event.password,
        displayName: event.displayName,
      );
      emit(AuthState(status: AuthStatus.authenticated, session: session));
    } catch (error) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          errorMessage: mapFailure(error).message,
        ),
      );
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading, errorMessage: null));
    try {
      await _logoutUser();
      emit(const AuthState(status: AuthStatus.unauthenticated));
    } catch (error) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          errorMessage: mapFailure(error).message,
        ),
      );
    }
  }
}
