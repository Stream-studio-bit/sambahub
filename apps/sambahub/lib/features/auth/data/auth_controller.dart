import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/failure_mapper.dart';
import 'auth_repository.dart';
import '../domain/auth_user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthState {
  const AuthState({this.user, this.isLoading = false, this.failure});

  final AuthUser? user;
  final bool isLoading;
  final Failure? failure;

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    AuthUser? user,
    bool clearUser = false,
    bool? isLoading,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return AuthState(
      user: clearUser ? null : user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}

class AuthController extends Notifier<AuthState> {
  late AuthRepository _repository;

  @override
  AuthState build() {
    _repository = ref.read(authRepositoryProvider);
    return AuthState(user: _repository.currentUser);
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _run(() => _repository.signIn(email: email, password: password));
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    await _run(
      () => _repository.signUp(
        email: email,
        password: password,
        name: name,
      ),
    );
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    try {
      await _repository.signOut();
      state = const AuthState();
    } catch (error) {
      state = AuthState(failure: FailureMapper.from(error));
    }
  }

  void clearFailure() {
    state = state.copyWith(clearFailure: true);
  }

  Future<void> _run(Future<AuthUser?> Function() operation) async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    try {
      final user = await operation();
      state = AuthState(user: user, isLoading: false);
    } catch (error) {
      state = AuthState(failure: FailureMapper.from(error));
    }
  }
}
