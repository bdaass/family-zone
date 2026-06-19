import 'package:firebase_auth/firebase_auth.dart';

import '../l10n/app_strings.dart';

/// Maps thrown errors to short, non-technical messages for end users.
class UserFacingError {
  UserFacingError._();

  static String message(
    Object error, {
    String fallbackKey = 'generic_error',
  }) {
    if (error is StateError) {
      final mapped = _stateErrorMessage(error.message);
      if (mapped != null) return mapped;
    }
    if (error is FirebaseAuthException) {
      return authMessage(error);
    }
    return S.of(fallbackKey);
  }

  static String authMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return S.of('auth_error_invalid_email');
      case 'user-disabled':
        return S.of('auth_error_user_disabled');
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return S.of('auth_error_wrong_credentials');
      case 'email-already-in-use':
        return S.of('auth_error_email_in_use');
      case 'weak-password':
        return S.of('auth_error_weak_password');
      case 'too-many-requests':
        return S.of('auth_error_too_many');
      case 'network-request-failed':
        return S.of('auth_error_network');
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
        return S.of('auth_error_cancelled');
      default:
        return S.of('auth_error_generic');
    }
  }

  static String? _stateErrorMessage(String? code) {
    switch (code) {
      case 'product_id_taken':
        return S.of('product_id_taken');
      case 'product_not_found':
        return S.of('product_not_found');
      case 'rate_limited':
        return S.of('message_rate_limited');
      case 'image_process_failed':
        return S.of('image_process_failed');
      case 'image_too_large':
        return S.of('image_too_large');
      default:
        return null;
    }
  }
}
