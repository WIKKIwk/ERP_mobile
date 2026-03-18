import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleController extends ChangeNotifier {
  LocaleController._();

  static final LocaleController instance = LocaleController._();
  static const String prefsKey = 'app_locale_code';

  Locale _locale = const Locale('uz');

  Locale get locale => _locale;
  bool get isUzbek => _locale.languageCode == 'uz';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(prefsKey);
    _locale = saved == 'en' ? const Locale('en') : const Locale('uz');
    notifyListeners();
  }

  Future<void> setLocale(Locale nextLocale) async {
    if (_locale.languageCode == nextLocale.languageCode) {
      return;
    }
    _locale = nextLocale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, nextLocale.languageCode);
  }
}
