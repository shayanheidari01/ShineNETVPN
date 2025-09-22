import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

/// Centralized language management service
class LanguageManager {
  static const String _languageKey = 'selected_language';
  static const String _fontScaleKey = 'font_scale';

  // Supported languages with their configurations
  static const Map<String, LanguageInfo> supportedLanguages = {
    'en': LanguageInfo(
      code: 'en',
      countryCode: 'US',
      name: 'English',
      nativeName: 'English',
      flag: '🇺🇸',
      isRTL: false,
      needsSpecialFont: false,
    ),
    'fa': LanguageInfo(
      code: 'fa',
      countryCode: 'IR',
      name: 'Persian',
      nativeName: 'فارسی',
      flag: '🇮🇷',
      isRTL: true,
      needsSpecialFont: true,
    ),
    'ar': LanguageInfo(
      code: 'ar',
      countryCode: 'SA',
      name: 'Arabic',
      nativeName: 'العربية',
      flag: '🇸🇦',
      isRTL: true,
      needsSpecialFont: true,
    ),
    'zh': LanguageInfo(
      code: 'zh',
      countryCode: 'CN',
      name: 'Chinese',
      nativeName: '中文',
      flag: '🇨🇳',
      isRTL: false,
      needsSpecialFont: true,
    ),
    'ru': LanguageInfo(
      code: 'ru',
      countryCode: 'RU',
      name: 'Russian',
      nativeName: 'Русский',
      flag: '🇷🇺',
      isRTL: false,
      needsSpecialFont: false,
    ),
    'es': LanguageInfo(
      code: 'es',
      countryCode: 'ES',
      name: 'Spanish',
      nativeName: 'Español',
      flag: '🇪🇸',
      isRTL: false,
      needsSpecialFont: false,
    ),
    'fr': LanguageInfo(
      code: 'fr',
      countryCode: 'FR',
      name: 'French',
      nativeName: 'Français',
      flag: '🇫🇷',
      isRTL: false,
      needsSpecialFont: false,
    ),
    'de': LanguageInfo(
      code: 'de',
      countryCode: 'DE',
      name: 'German',
      nativeName: 'Deutsch',
      flag: '🇩🇪',
      isRTL: false,
      needsSpecialFont: false,
    ),
    'hi': LanguageInfo(
      code: 'hi',
      countryCode: 'IN',
      name: 'Hindi',
      nativeName: 'हिंदी',
      flag: '🇮🇳',
      isRTL: false,
      needsSpecialFont: true,
    ),
    'pt': LanguageInfo(
      code: 'pt',
      countryCode: 'BR',
      name: 'Portuguese',
      nativeName: 'Português',
      flag: '🇧🇷',
      isRTL: false,
      needsSpecialFont: false,
    ),
  };

  /// Get current language information (checks saved preference if context is not reliable)
  static LanguageInfo getCurrentLanguage([BuildContext? context]) {
    try {
      final currentLocale = context?.locale.languageCode ?? 'en';
      return supportedLanguages[currentLocale] ?? supportedLanguages['en']!;
    } catch (e) {
      developer.log('Error getting current language',
          error: e, name: 'LanguageManager');
      return supportedLanguages['en']!;
    }
  }

  /// Get current language information from saved preference (async)
  static Future<LanguageInfo> getCurrentLanguageFromPreference() async {
    try {
      final savedLanguage = await getSavedLanguage();
      return supportedLanguages[savedLanguage] ?? supportedLanguages['en']!;
    } catch (e) {
      developer.log('Error getting current language from preference',
          error: e, name: 'LanguageManager');
      return supportedLanguages['en']!;
    }
  }

  /// Get language information by code
  static LanguageInfo? getLanguageInfo(String languageCode) {
    return supportedLanguages[languageCode];
  }

  /// Get all supported languages as list
  static List<LanguageInfo> getAllLanguages() {
    return supportedLanguages.values.toList();
  }

  /// Change language and save preference
  static Future<bool> changeLanguage(
      BuildContext context, String languageCode) async {
    try {
      final languageInfo = supportedLanguages[languageCode];
      if (languageInfo == null) {
        developer.log('Unsupported language: $languageCode',
            name: 'LanguageManager');
        return false;
      }

      // Change locale in EasyLocalization
      await context
          .setLocale(Locale(languageInfo.code, languageInfo.countryCode));

      // Save preference
      await _saveLanguagePreference(languageCode);

      developer.log('Language changed to: ${languageInfo.name}',
          name: 'LanguageManager');
      return true;
    } catch (e) {
      developer.log('Error changing language',
          error: e, name: 'LanguageManager');
      return false;
    }
  }

  /// Save language preference
  static Future<void> _saveLanguagePreference(String languageCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, languageCode);
    } catch (e) {
      developer.log('Error saving language preference',
          error: e, name: 'LanguageManager');
    }
  }

  /// Get saved language preference
  static Future<String> getSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_languageKey) ?? 'en';
    } catch (e) {
      developer.log('Error getting saved language',
          error: e, name: 'LanguageManager');
      return 'en';
    }
  }

  /// Initialize language from saved preference
  static Future<void> initializeLanguage(BuildContext context) async {
    try {
      final savedLanguage = await getSavedLanguage();
      final languageInfo = supportedLanguages[savedLanguage];

      if (languageInfo != null) {
        await context
            .setLocale(Locale(languageInfo.code, languageInfo.countryCode));
        developer.log('Language initialized to: ${languageInfo.name}',
            name: 'LanguageManager');
      }
    } catch (e) {
      developer.log('Error initializing language',
          error: e, name: 'LanguageManager');
    }
  }

  /// Get supported locales for EasyLocalization
  static List<Locale> getSupportedLocales() {
    return supportedLanguages.values
        .map((lang) => Locale(lang.code, lang.countryCode))
        .toList();
  }

  /// Get fallback locale
  static Locale getFallbackLocale() {
    final english = supportedLanguages['en']!;
    return Locale(english.code, english.countryCode);
  }

  /// Get start locale (checks saved preference first)
  static Locale getStartLocale() {
    // This is synchronous, but we can't await here
    // The saved preference will be handled by EasyLocalization's saveLocale: true
    return getFallbackLocale();
  }

  /// Get start locale asynchronously (checks saved preference)
  static Future<Locale> getStartLocaleAsync() async {
    try {
      final savedLanguage = await getSavedLanguage();
      final languageInfo = supportedLanguages[savedLanguage];
      if (languageInfo != null) {
        developer.log('Using saved language: ${languageInfo.name}',
            name: 'LanguageManager');
        return Locale(languageInfo.code, languageInfo.countryCode);
      }
    } catch (e) {
      developer.log('Error getting start locale, using fallback',
          error: e, name: 'LanguageManager');
    }
    return getFallbackLocale();
  }

  /// Check if language is RTL
  static bool isRTL([BuildContext? context]) {
    final currentLang = getCurrentLanguage(context);
    return currentLang.isRTL;
  }

  /// Get language display name (localized)
  static String getLanguageDisplayName(String languageCode,
      [BuildContext? context]) {
    try {
      final key = 'language_${_getLanguageKey(languageCode)}';
      return key.tr();
    } catch (e) {
      final langInfo = supportedLanguages[languageCode];
      return langInfo?.name ?? languageCode.toUpperCase();
    }
  }

  /// Get language key for translation
  static String _getLanguageKey(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'english';
      case 'fa':
        return 'persian';
      case 'ar':
        return 'arabic';
      case 'zh':
        return 'chinese';
      case 'ru':
        return 'russian';
      case 'es':
        return 'spanish';
      case 'fr':
        return 'french';
      case 'de':
        return 'german';
      case 'hi':
        return 'hindi';
      case 'pt':
        return 'portuguese';
      default:
        return languageCode;
    }
  }

  /// Font scale management

  /// Set font scale preference
  static Future<void> setFontScale(double scale) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_fontScaleKey, scale.clamp(0.8, 2.0));
      developer.log('Font scale set to: $scale', name: 'LanguageManager');
    } catch (e) {
      developer.log('Error setting font scale',
          error: e, name: 'LanguageManager');
    }
  }

  /// Get font scale preference
  static Future<double> getFontScale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(_fontScaleKey) ?? 1.0;
    } catch (e) {
      developer.log('Error getting font scale',
          error: e, name: 'LanguageManager');
      return 1.0;
    }
  }

  /// Reset all preferences
  static Future<void> resetPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_languageKey);
      await prefs.remove(_fontScaleKey);
      developer.log('Language preferences reset', name: 'LanguageManager');
    } catch (e) {
      developer.log('Error resetting preferences',
          error: e, name: 'LanguageManager');
    }
  }
}

/// Language information model
class LanguageInfo {
  final String code;
  final String countryCode;
  final String name;
  final String nativeName;
  final String flag;
  final bool isRTL;
  final bool needsSpecialFont;

  const LanguageInfo({
    required this.code,
    required this.countryCode,
    required this.name,
    required this.nativeName,
    required this.flag,
    required this.isRTL,
    required this.needsSpecialFont,
  });

  Locale get locale => Locale(code, countryCode);

  @override
  String toString() => '$name ($nativeName)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LanguageInfo && other.code == code;
  }

  @override
  int get hashCode => code.hashCode;
}
