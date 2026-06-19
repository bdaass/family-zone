import 'package:flutter/material.dart';

class LocaleService extends ChangeNotifier {
  LocaleService._();

  static final LocaleService instance = LocaleService._();

  Locale _locale = const Locale('ar');

  Locale get locale => _locale;

  bool get isArabic => _locale.languageCode == 'ar';

  String get languageCode => _locale.languageCode;

  void setEnglish() {
    if (!isArabic) return;
    _locale = const Locale('en');
    notifyListeners();
  }

  void setArabic() {
    if (isArabic) return;
    _locale = const Locale('ar');
    notifyListeners();
  }

  void toggle() {
    _locale = isArabic ? const Locale('en') : const Locale('ar');
    notifyListeners();
  }
}
