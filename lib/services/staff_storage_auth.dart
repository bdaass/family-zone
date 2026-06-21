import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Client-side guard before Storage uploads.
///
/// Storage rules authorize staff using the Firestore `users/{uid}.role` field
/// (same as [firestore.rules]). Refreshes the auth token after syncing claims.
class StaffStorageAuth {
  /// Verifies the signed-in user has a staff role in Firestore.
  ///
  /// Returns the Firestore role (`admin` or `employee`) — use this for writes
  /// so moderation fields match [firestore.rules], not a possibly stale UI role.
  static Future<String> prepareForUpload() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'user-not-signed-in', message: 'Sign in required to upload.');
    }

    final role = await _firestoreRole(user.uid);
    if (role == null) {
      throw FirebaseAuthException(code: 'profile-missing', message: 'User profile not found in Firestore.');
    }

    if (role != 'admin' && role != 'employee') {
      throw FirebaseAuthException(
        code: 'staff-role-required',
        message: 'Only staff can upload.',
      );
    }

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable('syncMyRoleClaims');
      await callable.call();
      await user.getIdToken(true);
    } catch (e) {
      debugPrint('StaffStorageAuth: claim sync skipped: $e');
      await user.getIdToken(true);
    }

    return role;
  }

  static Future<String?> _firestoreRole(String uid) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return doc.data()?['role']?.toString() ?? 'client';
  }
}
