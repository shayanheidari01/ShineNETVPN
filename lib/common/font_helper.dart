import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

/// Enhanced font helper with multi-language support and accessibility features
class FontHelper {
  // Font family mappings for different languages with local fallbacks
  static const Map<String, FontConfig> _languageFonts = {
    'fa': FontConfig(
      regular: 'SM', // Use local Shabnam font first to avoid network issues
      bold: 'SM',
      display: 'SM',
      fallback: 'Roboto', // System fallback
    ),
    'ar': FontConfig(
      regular: 'SM', // Use local font first to avoid network issues
      bold: 'SM',
      display: 'SM',
      fallback: 'Roboto',
    ),
    'hi': FontConfig(
      regular: 'Noto Sans Devanagari',
      bold: 'Noto Sans Devanagari',
      display: 'Noto Sans Devanagari',
      fallback: 'Roboto',
    ),
    'zh': FontConfig(
      regular: 'Noto Sans SC',
      bold: 'Noto Sans SC',
      display: 'Noto Sans SC',
      fallback: 'Roboto',
    ),
    'ru': FontConfig(
      regular: 'Inter',
      bold: 'Inter',
      display: 'Inter',
      fallback: 'Roboto',
    ),
    // Default for Latin scripts (en, es, fr, de, pt)
    'default': FontConfig(
      regular: 'Inter',
      bold: 'Inter',
      display: 'Inter',
      fallback: 'Roboto',
    ),
  };

  // Cache for font scale factor
  static double? _cachedFontScale;
  static String? _cachedLocale;
  static FontConfig? _cachedFontConfig;

  /// Get appropriate font family based on current locale
  static String getFontFamily([BuildContext? context]) {
    final currentLocale = _getCurrentLocale(context);
    final fontConfig = _getFontConfig(currentLocale);
    return fontConfig.regular;
  }

  /// Get font family based on language and weight
  static String getFontFamilyByWeight(FontWeight fontWeight,
      [BuildContext? context]) {
    final currentLocale = _getCurrentLocale(context);
    final fontConfig = _getFontConfig(currentLocale);

    if (fontWeight.index >= FontWeight.w700.index) {
      return fontConfig.bold;
    } else if (fontWeight.index >= FontWeight.w600.index) {
      return fontConfig.display;
    }
    return fontConfig.regular;
  }

  /// Get Persian font family based on weight (legacy support)
  static String getPersianFontFamily(FontWeight fontWeight) {
    if (fontWeight.index >= FontWeight.w700.index) {
      return 'SB'; // ShabnamBold for bold weights
    }
    return 'SM'; // ShabnamMedium for normal weights
  }

  /// Check if current locale is Persian
  static bool isPersianLocale([BuildContext? context]) {
    return _getCurrentLocale(context) == 'fa';
  }

  /// Check if current locale is Arabic
  static bool isArabicLocale([BuildContext? context]) {
    return _getCurrentLocale(context) == 'ar';
  }

  /// Check if current locale is RTL (Right-to-Left)
  static bool isRTLLocale([BuildContext? context]) {
    final locale = _getCurrentLocale(context);
    return locale == 'fa' || locale == 'ar';
  }

  /// Check if current locale needs special font handling
  static bool needsSpecialFont([BuildContext? context]) {
    final locale = _getCurrentLocale(context);
    return locale == 'fa' || locale == 'ar' || locale == 'hi' || locale == 'zh';
  }

  /// Get TextStyle with appropriate font for current locale
  static TextStyle getTextStyle({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    double? height,
    double? letterSpacing,
    BuildContext? context,
    bool useAccessibilityScale = true,
  }) {
    try {
      final currentLocale = _getCurrentLocale(context);
      final scaledFontSize = useAccessibilityScale
          ? _getScaledFontSize(fontSize, context)
          : fontSize;

      final fontConfig = _getFontConfig(currentLocale);
      final baseStyle = TextStyle(
        fontSize: scaledFontSize,
        fontWeight: fontWeight,
        color: color,
        height: height ?? _getOptimalLineHeight(currentLocale),
        letterSpacing: letterSpacing ?? _getOptimalLetterSpacing(currentLocale),
      );

      // Handle Persian and Arabic with local fonts
      if (currentLocale == 'fa' || currentLocale == 'ar') {
        // Use local fonts for Persian/Arabic to avoid network issues
        try {
          return TextStyle(
            fontFamily: 'SM', // Local Shabnam font
            fontSize: scaledFontSize,
            fontWeight: fontWeight,
            color: color,
            height: height,
            letterSpacing: letterSpacing,
          );
        } catch (e) {
          developer.log('Local font error for Persian/Arabic, using system fallback',
              error: e, name: 'FontHelper');
          // Ultimate fallback to system font
          return TextStyle(
            fontSize: scaledFontSize,
            fontWeight: fontWeight,
            color: color,
            height: height,
            letterSpacing: letterSpacing,
          );
        }
      }
      // Handle Hindi with Google Fonts
      else if (currentLocale == 'hi') {
        try {
          return GoogleFonts.notoSansDevanagari(
            fontSize: scaledFontSize,
            fontWeight: fontWeight,
            color: color,
            height: height ?? _getOptimalLineHeight(currentLocale),
            letterSpacing:
                letterSpacing ?? _getOptimalLetterSpacing(currentLocale),
          );
        } catch (e) {
          developer.log('Google Fonts Hindi error, using fallback',
              error: e, name: 'FontHelper');
          return GoogleFonts.inter(
            fontSize: scaledFontSize,
            fontWeight: fontWeight,
            color: color,
            height: height ?? _getOptimalLineHeight(currentLocale),
            letterSpacing:
                letterSpacing ?? _getOptimalLetterSpacing(currentLocale),
          );
        }
      }
      // Handle Chinese with Google Fonts
      else if (currentLocale == 'zh') {
        try {
          return GoogleFonts.notoSansSc(
            fontSize: scaledFontSize,
            fontWeight: fontWeight,
            color: color,
            height: height ?? _getOptimalLineHeight(currentLocale),
            letterSpacing:
                letterSpacing ?? _getOptimalLetterSpacing(currentLocale),
          );
        } catch (e) {
          developer.log('Google Fonts Chinese error, using fallback',
              error: e, name: 'FontHelper');
          return GoogleFonts.inter(
            fontSize: scaledFontSize,
            fontWeight: fontWeight,
            color: color,
            height: height ?? _getOptimalLineHeight(currentLocale),
            letterSpacing:
                letterSpacing ?? _getOptimalLetterSpacing(currentLocale),
          );
        }
      }
      // Use Google Fonts Inter for Latin scripts
      else {
        try {
          return GoogleFonts.inter(
            fontSize: scaledFontSize,
            fontWeight: fontWeight,
            color: color,
            height: height ?? _getOptimalLineHeight(currentLocale),
            letterSpacing:
                letterSpacing ?? _getOptimalLetterSpacing(currentLocale),
          );
        } catch (e) {
          developer.log('Google Fonts Inter error, using system fallback',
              error: e, name: 'FontHelper');
          return baseStyle;
        }
      }
    } catch (e) {
      developer.log('Font loading error', error: e, name: 'FontHelper');
      // Ultimate fallback to system default with scaling
      final scaledFontSize = useAccessibilityScale
          ? _getScaledFontSize(fontSize, context)
          : fontSize;
      return TextStyle(
        fontSize: scaledFontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );
    }
  }

  /// Get heading style with appropriate font
  static TextStyle getHeadingStyle({
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.bold,
    Color? color,
    BuildContext? context,
  }) {
    try {
      return getTextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        context: context,
      );
    } catch (e) {
      return TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );
    }
  }

  /// Get body style with appropriate font
  static TextStyle getBodyStyle({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    BuildContext? context,
  }) {
    try {
      return getTextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        context: context,
      );
    } catch (e) {
      return TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );
    }
  }

  /// Get caption style with appropriate font
  static TextStyle getCaptionStyle({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    BuildContext? context,
  }) {
    try {
      return getTextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        context: context,
      );
    } catch (e) {
      return TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );
    }
  }

  /// Apply font theme to entire app with enhanced language support
  static ThemeData getAppTheme([BuildContext? context]) {
    try {
      final currentLocale = _getCurrentLocale(context);

      // Handle Persian and Arabic with Google Fonts
      if (currentLocale == 'fa' || currentLocale == 'ar') {
        try {
          if (currentLocale == 'fa') {
            // Use Vazirmatn for Persian
            return ThemeData(
              textTheme: GoogleFonts.vazirmatnTextTheme(),
            );
          } else {
            // Use Noto Sans Arabic for Arabic
            return ThemeData(
              textTheme: GoogleFonts.notoSansArabicTextTheme(),
            );
          }
        } catch (e) {
          developer.log(
              'Google Fonts Persian/Arabic theme error, using fallback',
              error: e,
              name: 'FontHelper');
          // Fallback to local fonts
          final fontConfig = _getFontConfig(currentLocale);
          return ThemeData(
            fontFamily: fontConfig.fallback,
            textTheme: _createFallbackTextTheme(fontConfig),
          );
        }
      }
      // Handle Hindi with Google Fonts
      else if (currentLocale == 'hi') {
        try {
          return ThemeData(
            textTheme: GoogleFonts.notoSansDevanagariTextTheme(),
          );
        } catch (e) {
          developer.log('Google Fonts Hindi theme error, using fallback',
              error: e, name: 'FontHelper');
          return ThemeData(
            textTheme: GoogleFonts.interTextTheme(),
          );
        }
      }
      // Handle Chinese with Google Fonts
      else if (currentLocale == 'zh') {
        try {
          return ThemeData(
            textTheme: GoogleFonts.notoSansScTextTheme(),
          );
        } catch (e) {
          developer.log('Google Fonts Chinese theme error, using fallback',
              error: e, name: 'FontHelper');
          return ThemeData(
            textTheme: GoogleFonts.interTextTheme(),
          );
        }
      }
      // Use Inter for Latin scripts
      else {
        try {
          return ThemeData(
            textTheme: GoogleFonts.interTextTheme(),
          );
        } catch (e) {
          developer.log('Google Fonts Inter theme error, using system fallback',
              error: e, name: 'FontHelper');
          return ThemeData();
        }
      }
    } catch (e) {
      developer.log('Theme creation error', error: e, name: 'FontHelper');
      return ThemeData(
        textTheme: GoogleFonts.interTextTheme(),
      );
    }
  }

  // Private helper methods

  /// Get current locale code safely
  static String _getCurrentLocale([BuildContext? context]) {
    if (_cachedLocale != null && context == null) {
      return _cachedLocale!;
    }

    String currentLocale = 'en';
    try {
      if (context != null) {
        currentLocale =
            EasyLocalization.of(context)?.locale.languageCode ?? 'en';
        _cachedLocale = currentLocale;
      }
    } catch (e) {
      developer.log('Locale detection error', error: e, name: 'FontHelper');
      currentLocale = 'en';
    }
    return currentLocale;
  }

  /// Get font configuration for a locale
  static FontConfig _getFontConfig(String locale) {
    if (_cachedFontConfig != null && _cachedLocale == locale) {
      return _cachedFontConfig!;
    }

    final config = _languageFonts[locale] ?? _languageFonts['default']!;
    _cachedFontConfig = config;
    return config;
  }


  /// Get scaled font size with accessibility support
  static double _getScaledFontSize(double fontSize, [BuildContext? context]) {
    if (_cachedFontScale != null && context == null) {
      return fontSize * _cachedFontScale!;
    }

    double scale = 1.0;
    try {
      if (context != null) {
        // Use MediaQuery for accessibility scaling
        scale = MediaQuery.textScalerOf(context).scale(1.0).clamp(0.8, 2.0);
        _cachedFontScale = scale;
      }
    } catch (e) {
      developer.log('Font scale error', error: e, name: 'FontHelper');
    }

    return fontSize * scale;
  }

  /// Get optimal line height for language
  static double _getOptimalLineHeight(String locale) {
    switch (locale) {
      case 'fa':
      case 'ar':
        return 1.6; // Better for Persian/Arabic scripts
      case 'zh':
        return 1.5; // Better for Chinese characters
      case 'hi':
        return 1.4; // Better for Devanagari script
      default:
        return 1.3; // Good for Latin scripts
    }
  }

  /// Get optimal letter spacing for language
  static double _getOptimalLetterSpacing(String locale) {
    switch (locale) {
      case 'fa':
      case 'ar':
        return 0.0; // No letter spacing for Arabic scripts
      case 'zh':
        return 0.1; // Slight spacing for Chinese
      default:
        return 0.15; // Standard spacing for Latin scripts
    }
  }

  /// Create fallback text theme for local fonts
  static TextTheme _createFallbackTextTheme(FontConfig fontConfig) {
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: fontConfig.display,
        fontWeight: FontWeight.bold,
      ),
      displayMedium: TextStyle(
        fontFamily: fontConfig.display,
        fontWeight: FontWeight.bold,
      ),
      displaySmall: TextStyle(
        fontFamily: fontConfig.regular,
        fontWeight: FontWeight.w600,
      ),
      headlineLarge: TextStyle(
        fontFamily: fontConfig.bold,
        fontWeight: FontWeight.bold,
      ),
      headlineMedium: TextStyle(
        fontFamily: fontConfig.bold,
        fontWeight: FontWeight.bold,
      ),
      headlineSmall: TextStyle(
        fontFamily: fontConfig.regular,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: TextStyle(
        fontFamily: fontConfig.bold,
        fontWeight: FontWeight.bold,
      ),
      titleMedium: TextStyle(
        fontFamily: fontConfig.regular,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: TextStyle(
        fontFamily: fontConfig.regular,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: TextStyle(
        fontFamily: fontConfig.regular,
        fontWeight: FontWeight.normal,
      ),
      bodyMedium: TextStyle(
        fontFamily: fontConfig.regular,
        fontWeight: FontWeight.normal,
      ),
      bodySmall: TextStyle(
        fontFamily: fontConfig.regular,
        fontWeight: FontWeight.normal,
      ),
      labelLarge: TextStyle(
        fontFamily: fontConfig.regular,
        fontWeight: FontWeight.w500,
      ),
      labelMedium: TextStyle(
        fontFamily: fontConfig.regular,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: TextStyle(
        fontFamily: fontConfig.regular,
        fontWeight: FontWeight.normal,
      ),
    );
  }

  // Accessibility methods

  /// Set custom font scale factor
  static Future<void> setFontScale(double scale) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('font_scale', scale.clamp(0.8, 2.0));
      _cachedFontScale = scale;
      developer.log('Font scale set to $scale', name: 'FontHelper');
    } catch (e) {
      developer.log('Error setting font scale', error: e, name: 'FontHelper');
    }
  }

  /// Get saved font scale factor
  static Future<double> getFontScale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scale = prefs.getDouble('font_scale') ?? 1.0;
      _cachedFontScale = scale;
      return scale;
    } catch (e) {
      developer.log('Error getting font scale', error: e, name: 'FontHelper');
      return 1.0;
    }
  }

  /// Clear font cache
  static void clearCache() {
    _cachedFontScale = null;
    _cachedLocale = null;
    _cachedFontConfig = null;
    developer.log('Font cache cleared', name: 'FontHelper');
  }

  /// Get font preview text for language
  static String getFontPreviewText(String locale) {
    switch (locale) {
      case 'en':
        return 'The quick brown fox jumps';
      case 'fa':
        return 'نمونه متن فارسی با فونت وزیرمتن'; // Persian sample text for Vazirmatn
      case 'ar':
        return 'النص العربي الجميل مع الخط الجديد';
      case 'zh':
        return '中文字体预览文本示例';
      case 'ru':
        return 'Пример русского текста';
      case 'es':
        return 'Texto de ejemplo en español';
      case 'fr':
        return 'Texte d\'exemple en français';
      case 'de':
        return 'Deutscher Beispieltext';
      case 'hi':
        return 'हिंदी फॉन्ट पूर्वावलोकन पाठ';
      case 'pt':
        return 'Texto de exemplo em português';
      default:
        return 'Sample text for preview';
    }
  }
}

/// Font configuration for different languages
class FontConfig {
  final String regular;
  final String bold;
  final String display;
  final String fallback;

  const FontConfig({
    required this.regular,
    required this.bold,
    required this.display,
    required this.fallback,
  });
}
