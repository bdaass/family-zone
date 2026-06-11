import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../l10n/app_strings.dart';

class AuthModalSheet extends StatefulWidget {
  const AuthModalSheet({super.key});

  @override
  State<AuthModalSheet> createState() => _AuthModalSheetState();
}

class _AuthModalSheetState extends State<AuthModalSheet> {
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  bool isLoginMode = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.of('auth_error_title')),
        content: Text(error),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.of('ok')))],
      ),
    );
  }

  Future<void> registerWithEmail(String email, String password) async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
      _showToast(S.of('auth_registered'));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showErrorDialog(e.toString());
    }
  }

  Future<void> loginWithEmail(String email, String password) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      _showToast(S.of('auth_welcome_back'));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showErrorDialog(e.toString());
    }
  }

  Future<void> loginWithGoogle() async {
    try {
      setState(() => _isLoading = true);
      UserCredential userCredential;

      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        googleProvider.setCustomParameters({'prompt': 'select_account'});
        userCredential = await FirebaseAuth.instance.signInWithPopup(googleProvider);
      } else {
        // Clear cached Google session so the account picker is shown every time.
        await _googleSignIn.signOut();
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          setState(() => _isLoading = false);
          return;
        }
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      }
      _showToast(S.fmt('auth_google_success', {'email': userCredential.user?.email ?? ''}));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showErrorDialog(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 20),
          Text(
            isLoginMode ? S.of('auth_sign_in_title') : S.of('auth_register_title'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF111111)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            decoration: InputDecoration(labelText: S.of('auth_email'), border: const OutlineInputBorder()),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(labelText: S.of('auth_password'), border: const OutlineInputBorder()),
            obscureText: true,
          ),
          const SizedBox(height: 20),
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF111111)))
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF111111),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    final email = _emailController.text.trim();
                    final password = _passwordController.text.trim();
                    if (email.isEmpty || password.isEmpty) {
                      _showToast(S.of('auth_fields_required'));
                      return;
                    }
                    if (isLoginMode) {
                      loginWithEmail(email, password);
                    } else {
                      registerWithEmail(email, password);
                    }
                  },
                  child: Text(isLoginMode ? S.of('auth_login_button') : S.of('auth_register_button')),
                ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
            icon: const Icon(Icons.g_mobiledata, size: 28),
            label: Text(S.of('auth_google_button')),
            onPressed: _isLoading ? null : loginWithGoogle,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() => isLoginMode = !isLoginMode),
            child: Text(isLoginMode ? S.of('auth_switch_to_register') : S.of('auth_switch_to_sign_in')),
          ),
        ],
      ),
    );
  }
}
