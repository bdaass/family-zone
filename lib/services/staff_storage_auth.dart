import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Client-side guard before Storage uploads.
///
/// Storage rules authorize staff using the Firestore `users/{uid}.role` field
/// (same as [firestore.rules]), not JWT custom claims.
class StaffStorageAuth {
  /// Verifies the signed-in user has a staff role in Firestore.
  static Future<void> prepareForUpload() async {
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
        message: 'Only staff can upload. Your Firestore role is "$role" (expected admin or employee).',
      );
    }
  }

  static Future<String?> _firestoreRole(String uid) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return doc.data()?['role']?.toString() ?? 'client';
  }
}
