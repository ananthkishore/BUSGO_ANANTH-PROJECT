import 'package:firebase_auth/firebase_auth.dart';

import '../errors/auth_failure.dart';

class AuthExceptionMapper {
  static String fromFirebaseAuth(FirebaseAuthException exception) {
    switch (exception.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-not-found':
        return 'No account was found for this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'The email or password is incorrect.';
      case 'email-already-in-use':
        return 'This email is already registered. Please sign in instead.';
      case 'weak-password':
        return 'Choose a stronger password with at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'requires-recent-login':
        return 'Please sign in again to continue.';
      case 'network-request-failed':
      case 'network_error':
        return 'Network connection failed. Please try again.';
      case 'user-disabled':
        return 'This account has been disabled.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  static String fromFirestore(dynamic exception) {
    final code = exception is FirebaseException ? exception.code : null;
    final message = exception is FirebaseException ? exception.message : null;
    if (code == 'permission-denied' ||
        (message ?? '').toLowerCase().contains('permission')) {
      return 'You do not have permission to complete this action.';
    }
    if (code == 'unavailable' || code == 'network-request-failed') {
      return 'Unable to add bus. Please check your internet connection and try again.';
    }
    if (code == 'failed-precondition') {
      return 'Firestore is not ready for this operation. Check the Firebase configuration.';
    }
    return 'Unable to add bus. Please try again.';
  }
}

void throwAuthFailureFromException(Object exception) {
  if (exception is FirebaseAuthException) {
    throw AuthFailure(AuthExceptionMapper.fromFirebaseAuth(exception));
  }

  if (exception is FirebaseException) {
    throw AuthFailure(AuthExceptionMapper.fromFirestore(exception));
  }

  throw const AuthFailure('Something went wrong. Please try again.');
}
