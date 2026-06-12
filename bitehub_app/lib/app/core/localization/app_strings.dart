import 'package:flutter/widgets.dart';

class AppStrings {
  const AppStrings(this.locale);

  final Locale locale;

  bool get isArabic => locale.languageCode != 'en';

  static AppStrings of(BuildContext context) {
    return AppStrings(Localizations.localeOf(context));
  }

  String text(String arabic, String english) => isArabic ? arabic : english;

  String get home => text('الرئيسية', 'Home');
  String get orders => text('طلباتي', 'Orders');
  String get cart => text('السلة', 'Cart');
  String get wallet => text('المحفظة', 'Wallet');
  String get profile => text('حسابي', 'Profile');
  String get language => text('اللغة', 'Language');
  String get arabic => text('العربية', 'Arabic');
  String get english => text('الإنجليزية', 'English');
}
