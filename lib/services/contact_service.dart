import 'package:cloud_functions/cloud_functions.dart';

class ContactService {
  static Future<void> submitMessage({
    required String message,
    required bool anonymous,
    String? name,
    String? email,
    String? phone,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Message cannot be empty');
    }

    final callable = FirebaseFunctions.instance.httpsCallable('submitContactMessage');
    try {
      await callable.call<Map<String, dynamic>>({
        'message': trimmed,
        'anonymous': anonymous,
        if (!anonymous) ...{
          'name': name?.trim(),
          'email': email?.trim(),
          'phone': phone?.trim(),
        },
      });
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') {
        throw StateError('rate_limited');
      }
      rethrow;
    }
  }
}
