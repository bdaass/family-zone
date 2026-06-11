import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ContactService {
  static Future<void> submitMessage({
    required String message,
    required bool anonymous,
    String? name,
    String? email,
    String? phone,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Message cannot be empty');
    }

    await FirebaseFirestore.instance.collection('contact_messages').add({
      'message': trimmed,
      'anonymous': anonymous,
      'name': anonymous ? null : name?.trim(),
      'email': anonymous ? null : email?.trim(),
      'phone': anonymous ? null : phone?.trim(),
      'userId': anonymous ? null : user?.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
