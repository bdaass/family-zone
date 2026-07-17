import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Firebase ID token for staff-only `/media/.../barcode.jpg` requests on web.
class StaffMediaAuth {
  StaffMediaAuth._();

  static Future<Map<String, String>?> headers() async {
    if (!kIsWeb) return null;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) return null;
    return {'Authorization': 'Bearer $token'};
  }
}
