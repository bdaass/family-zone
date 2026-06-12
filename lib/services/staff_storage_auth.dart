import 'package:firebase_auth/firebase_auth.dart';

/// Ensures Firebase Auth custom claims (role) are fresh before Storage writes.
///
/// Storage rules use `request.auth.token.role`, synced from Firestore by
/// `syncUserRoleToClaims`. After an admin role is assigned, the user must
/// refresh their ID token (sign out/in, or [prepareForUpload]).
class StaffStorageAuth {
  static const _maxAttempts = 3;
  static const _retryDelay = Duration(milliseconds: 800);

  /// Refreshes the ID token and verifies the `role` claim is staff.
  static Future<void> prepareForUpload() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'user-not-signed-in', message: 'Sign in required to upload.');
    }

    Object? lastError;

    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      await user.getIdToken(true);
      final role = (await user.getIdTokenResult()).claims?['role'] as String?;

      if (role == 'admin' || role == 'employee') return;

      lastError = role;
      if (attempt < _maxAttempts - 1) {
        await Future<void>.delayed(_retryDelay);
      }
    }

    throw FirebaseAuthException(
      code: 'staff-claim-missing',
      message: 'Your staff permissions are not active yet (role: $lastError). '
          'Sign out and sign back in, or wait a minute after an admin assigns your role.',
    );
  }
}
