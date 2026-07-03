import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Google Sign-In client IDs — must match ios/Runner/Info.plist (GIDClientID + URL scheme).
class GoogleSignInConfig {
  GoogleSignInConfig._();

  static const String iosClientId =
      '280621792365-lu44ooavl6q88v8dnqlvqecdoseflkmu.apps.googleusercontent.com';

  static GoogleSignIn create() {
    return GoogleSignIn(
      scopes: const ['email', 'profile'],
      clientId: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS ? iosClientId : null,
    );
  }
}
