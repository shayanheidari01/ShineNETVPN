import 'package:shinenet_vpn/common/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';

class LanguageWidget extends StatefulWidget {
  final String selectedLanguage;

  LanguageWidget({required this.selectedLanguage});

  @override
  _LanguageWidgetState createState() => _LanguageWidgetState();
}

class _LanguageWidgetState extends State<LanguageWidget> {
  late String _selectedLanguage;

  @override
  void initState() {
    super.initState();
    _selectedLanguage =
        widget.selectedLanguage; // مقدار اولیه را از ورودی دریافت کنید
  }

  // ذخیره زبان انتخاب شده در SharedPreferences
  void _saveSelectedLanguage(String language) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedLanguage', language);
  }

  // تغییر زبان با استفاده از easy_localization
  void _changeLocale(BuildContext context, String language) {
    if (language == 'language_english'.tr()) {
      context.setLocale(Locale('en', 'US'));
    } else if (language == 'language_persian'.tr()) {
      context.setLocale(Locale('fa', 'IR'));
    } else if (language == 'language_chinese'.tr()) {
      context.setLocale(Locale('zh', 'CN'));
    } else if (language == 'language_russian'.tr()) {
      context.setLocale(Locale('ru', 'RU'));
    } else if (language == 'language_spanish'.tr()) {
      context.setLocale(Locale('es', 'ES'));
    } else if (language == 'language_french'.tr()) {
      context.setLocale(Locale('fr', 'FR'));
    } else if (language == 'language_german'.tr()) {
      context.setLocale(Locale('de', 'DE'));
    } else if (language == 'language_hindi'.tr()) {
      context.setLocale(Locale('hi', 'IN'));
    } else if (language == 'language_portuguese'.tr()) {
      context.setLocale(Locale('pt', 'BR'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColor.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'select_language'.tr(),
          style: ThemeColor.headingStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.all(ThemeColor.mediumSpacing),
        child: Column(
          children: [
            // Simple description
            Text(
              'choose_preferred_language'.tr(),
              style: ThemeColor.captionStyle(
                fontSize: 16,
                color: ThemeColor.mutedText,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: ThemeColor.largeSpacing),
            
            // Language options
            Expanded(
              child: ListView(
                children: [
                  _buildSimpleLanguageCard(
                    context,
                    'language_english'.tr(),
                    '🇺🇸',
                    'English',
                  ),
                  SizedBox(height: ThemeColor.smallSpacing),
                  _buildSimpleLanguageCard(
                    context,
                    'language_persian'.tr(),
                    '🇮🇷',
                    'فارسی',
                  ),
                  SizedBox(height: ThemeColor.smallSpacing),
                  _buildSimpleLanguageCard(
                    context,
                    'language_chinese'.tr(),
                    '🇨🇳',
                    '中文',
                  ),
                  SizedBox(height: ThemeColor.smallSpacing),
                  _buildSimpleLanguageCard(
                    context,
                    'language_russian'.tr(),
                    '🇷🇺',
                    'Русский',
                  ),
                  SizedBox(height: ThemeColor.smallSpacing),
                  _buildSimpleLanguageCard(
                    context,
                    'language_spanish'.tr(),
                    '🇪🇸',
                    'Español',
                  ),
                  SizedBox(height: ThemeColor.smallSpacing),
                  _buildSimpleLanguageCard(
                    context,
                    'language_french'.tr(),
                    '🇫🇷',
                    'Français',
                  ),
                  SizedBox(height: ThemeColor.smallSpacing),
                  _buildSimpleLanguageCard(
                    context,
                    'language_german'.tr(),
                    '🇩🇪',
                    'Deutsch',
                  ),
                  SizedBox(height: ThemeColor.smallSpacing),
                  _buildSimpleLanguageCard(
                    context,
                    'language_hindi'.tr(),
                    '🇮🇳',
                    'हिंदी',
                  ),
                  SizedBox(height: ThemeColor.smallSpacing),
                  _buildSimpleLanguageCard(
                    context,
                    'language_portuguese'.tr(),
                    '🇧🇷',
                    'Português',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildSimpleLanguageCard(
    BuildContext context,
    String language,
    String flag,
    String nativeName,
  ) {
    final isSelected = _selectedLanguage == language;
    
    return Container(
      decoration: ThemeColor.cardDecoration(
        withBorder: true,
        withShadow: false,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _selectedLanguage = language;
              _saveSelectedLanguage(language);
              _changeLocale(context, language);
            });
          },
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: ThemeColor.mediumSpacing,
              vertical: ThemeColor.largeSpacing,
            ),
            child: Row(
              children: [
                // Flag
                Text(
                  flag,
                  style: TextStyle(fontSize: 24),
                ),
                SizedBox(width: ThemeColor.mediumSpacing),
                
                // Language name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        language,
                        style: ThemeColor.bodyStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (nativeName != language) ...[
                        SizedBox(height: 2),
                        Text(
                          nativeName,
                          style: ThemeColor.captionStyle(
                            fontSize: 14,
                            color: ThemeColor.mutedText,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Selection indicator
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: ThemeColor.primaryColor,
                    size: 24,
                  )
                else
                  Icon(
                    Icons.radio_button_unchecked,
                    color: ThemeColor.borderColor,
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
