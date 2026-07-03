import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pages/dashboard.dart';
import 'firebase_options.dart';
import 'l10n/app_strings.dart';
import 'services/cart_service.dart';
import 'services/locale_service.dart';
import 'theme/app_theme.dart';
import 'utils/web_platform.dart';
import 'widgets/force_update_gate.dart';

Future<void>? _firebaseBootstrap;

Future<void> _ensureFirebase() {
  return _firebaseBootstrap ??= Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ).then((_) {
    if (kIsWeb && WebPlatform.isIOSWeb) {
      FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
    }
    CartService.instance.bindAuth();
  });
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  WebPlatform.configure();
  if (kIsWeb) {
    GoogleFonts.config.allowRuntimeFetching = false;
  }
  runApp(const BootstrapApp());
}

/// Shows the first frame immediately so the HTML splash can dismiss, then connects Firebase.
class BootstrapApp extends StatelessWidget {
  const BootstrapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ensureFirebase(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: AppColors.cream,
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/logo.png', width: 88, height: 88),
                    const SizedBox(height: 20),
                    const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppColors.coral,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: AppColors.cream,
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not connect. Check your internet and refresh.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.inkMuted, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          );
        }

        return const ForceUpdateGate(child: FamilyZoneApp());
      },
    );
  }
}

class FamilyZoneApp extends StatelessWidget {
  const FamilyZoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocaleService.instance,
      builder: (context, _) {
        final locale = LocaleService.instance.locale;
        final isRtl = LocaleService.instance.isArabic;

        return MaterialApp(
          title: S.of('app_title'),
          debugShowCheckedModeBanner: false,
          theme: AppTheme.forLocale(locale),
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            return Directionality(
              textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
              child: DefaultTextStyle(
                style: AppTheme.bodyFont(isArabic: isRtl),
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: const DashboardPage(),
        );
      },
    );
  }
}
