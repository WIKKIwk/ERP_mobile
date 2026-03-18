import 'package:flutter/widgets.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [
    Locale('uz'),
    Locale('en'),
  ];

  static AppLocalizations of(BuildContext context) {
    final localizations =
        Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(localizations != null, 'AppLocalizations not found in context');
    return localizations!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  bool get isUzbek => locale.languageCode == 'uz';

  String get appTitle => isUzbek ? 'Accord' : 'Accord';
  String get profileTitle => isUzbek ? 'Profil' : 'Profile';
  String get werkaAccount => isUzbek ? 'Werka akkaunti' : 'Werka account';
  String get supplierAccount =>
      isUzbek ? 'Supplier akkaunti' : 'Supplier account';
  String get customerAccount =>
      isUzbek ? 'Customer akkaunti' : 'Customer account';
  String get adminAccount => isUzbek ? 'Admin akkaunti' : 'Admin account';
  String get nicknameSaveFailed =>
      isUzbek ? 'Nickname saqlanmadi' : 'Nickname was not saved';
  String get imagePickFailed =>
      isUzbek ? 'Rasm tanlanmadi' : 'Image selection failed';
  String get imageSaveFailed =>
      isUzbek ? 'Rasm saqlanmadi' : 'Image was not saved';
  String get save => isUzbek ? 'Saqlash' : 'Save';
  String get saveChanges => isUzbek ? 'O‘zgarishlarni saqlash' : 'Save changes';
  String get phoneLabel => isUzbek ? 'Telefon' : 'Phone';
  String get legalNameLabel => isUzbek ? 'Asl ism' : 'Legal name';
  String get nicknameLabel => isUzbek ? 'Nickname' : 'Nickname';
  String get nicknameHint =>
      isUzbek ? 'O‘zingizga ko‘rinadigan ism' : 'The name visible to you';
  String get securityTitle => isUzbek ? 'Xavfsizlik' : 'Security';
  String get pinEnabled =>
      isUzbek ? '4 xonali PIN yoqilgan' : 'A 4-digit PIN is enabled';
  String get pinDisabled => isUzbek
      ? 'App uchun 4 xonali PIN o‘rnating'
      : 'Set a 4-digit PIN for the app';
  String get pinSaving => isUzbek ? 'Saqlanmoqda...' : 'Saving...';
  String get pinSet => isUzbek ? 'PIN o‘rnatish' : 'Set PIN';
  String get pinChange => isUzbek ? 'PIN almashtirish' : 'Change PIN';
  String get pinRemove => isUzbek ? 'PIN o‘chirish' : 'Remove PIN';
  String get biometricEnableTitle => isUzbek
      ? 'Biometrik autentifikatsiyani yoqish'
      : 'Enable biometric authentication';
  String get biometricEnabledBody => isUzbek
      ? 'Yoqilgan. App Face ID yoki fingerprint bilan tez ochiladi.'
      : 'Enabled. The app can be unlocked quickly with Face ID or fingerprint.';
  String get biometricDisabledBody => isUzbek
      ? 'O‘chirilgan. Face ID yoki fingerprint bilan tez ochish ishlamaydi.'
      : 'Disabled. Fast unlock with Face ID or fingerprint is off.';
  String get languageTitle => isUzbek ? 'Til' : 'Language';
  String get languageBody =>
      isUzbek ? 'Ilova tilini tanlang' : 'Choose the app language';
  String get uzbek => isUzbek ? 'O‘zbekcha' : 'Uzbek';
  String get english => 'English';
  String get selectedImageNotice => isUzbek
      ? 'Yangi rasm tanlandi. Saqlashni bossangiz profil yangilanadi.'
      : 'A new image was selected. Save to update the profile.';
  String get appLockTitle => isUzbek ? 'App qulfi' : 'App lock';
  String get appLockSubtitle =>
      isUzbek ? '4 xonali PIN kiriting' : 'Enter your 4-digit PIN';
  String get unlock => isUzbek ? 'Ochish' : 'Unlock';
  String get checking => isUzbek ? 'Tekshirilmoqda...' : 'Checking...';
  String get biometricCta =>
      isUzbek ? 'Biometrik autentifikatsiya' : 'Biometric authentication';
  String get pinWrong => isUzbek ? 'PIN noto‘g‘ri' : 'Incorrect PIN';
  String get biometricFailed => isUzbek
      ? 'Biometrik tasdiq bajarilmadi'
      : 'Biometric verification did not complete';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
        (item) => item.languageCode == locale.languageCode,
      );

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
