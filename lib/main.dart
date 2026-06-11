import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'pages/dashboard.dart';
import 'firebase_options.dart';
import 'l10n/app_strings.dart';
import 'services/cart_service.dart';
import 'services/locale_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  CartService.instance.bindAuth();
  runApp(const FamilyZoneApp());
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