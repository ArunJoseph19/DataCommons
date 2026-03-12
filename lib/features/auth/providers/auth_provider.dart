import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Auth state — wraps Firebase Auth operations.
class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final FirebaseAuth _auth;

  AuthNotifier(this._auth) : super(const AsyncValue.loading()) {
    _auth.authStateChanges().listen((user) {
      state = AsyncValue.data(user);
    });
  }

  /// Sign up with email, password, and display name.
  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = const AsyncValue.loading();
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user?.updateDisplayName(displayName);
      state = AsyncValue.data(credential.user);
    } on FirebaseAuthException catch (e, st) {
      state = AsyncValue.error(_friendlyAuthError(e.code), st);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Log in with email/password.
  Future<void> logIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      state = AsyncValue.data(credential.user);
    } on FirebaseAuthException catch (e, st) {
      state = AsyncValue.error(_friendlyAuthError(e.code), st);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Send password reset email.
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Sign out.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  String _friendlyAuthError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}

/// Provider for auth state
final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier(FirebaseAuth.instance);
});
