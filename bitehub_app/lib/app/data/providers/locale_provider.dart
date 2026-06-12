import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  static const _storageKey = 'app_locale';

  Locale _locale = const Locale('ar');

  Locale get locale => _locale;
  bool get isArabic => _locale.languageCode == 'ar';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_storageKey);
    _locale = Locale(code == 'en' ? 'en' : 'ar');
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    final code = locale.languageCode == 'en' ? 'en' : 'ar';
    if (_locale.languageCode == code) {
      return;
    }
    _locale = Locale(code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, code);
    notifyListeners();
  }

  Future<void> toggle() {
    return setLocale(Locale(isArabic ? 'en' : 'ar'));
  }
}
