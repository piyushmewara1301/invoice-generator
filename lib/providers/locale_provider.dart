import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  static const _prefKey = 'app_locale';

  Locale _locale = const Locale('en');
  Locale get locale => _locale;

  static const supportedLocales = [
    Locale('en'),
    Locale('hi'),
    Locale('gu'),
    Locale('mr'),
    Locale('ta'),
    Locale('te'),
  ];

  static const localeNames = {
    'en': 'English',
    'hi': 'हिन्दी',
    'gu': 'ગુજરાતી',
    'mr': 'मराठी',
    'ta': 'தமிழ்',
    'te': 'తెలుగు',
  };

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefKey) ?? 'en';
    _locale = Locale(code);
    // notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    print('>>> LocaleProvider: locale changed to ${locale.languageCode}');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, locale.languageCode);
    notifyListeners();
  }
}
