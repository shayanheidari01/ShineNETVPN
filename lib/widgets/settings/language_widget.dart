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
    if (language == 'English') {
      context.setLocale(Locale('en', 'US'));
    } else if (language == 'فارسی') {
      context.setLocale(Locale('fa', 'IR'));
    } else if (language == '中文') {
      context.setLocale(Locale('zh', 'CN'));
    } else if (language == 'русский') {
      context.setLocale(Locale('ru', 'RU'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColor.backgroundColor,
      appBar: AppBar(
        title: Text(
          context.tr('select_language'),
          style: ThemeColor.headingStyle(fontSize: 20),
        ),
        backgroundColor: ThemeColor.backgroundColor,
        elevation: 0,
      ),
      body: Padding(
        padding: EdgeInsets.all(ThemeColor.mediumSpacing),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(ThemeColor.mediumSpacing),
              decoration: ThemeColor.cardDecoration(),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(ThemeColor.smallSpacing),
                    decoration: BoxDecoration(
                      gradient: ThemeColor.primaryGradient,
                      borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
                    ),
                    child: Icon(
                      Icons.language_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: ThemeColor.mediumSpacing),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Language Selection',
                          style: ThemeColor.bodyStyle(
                            fontWeight: FontWeight.w600,
                            color: ThemeColor.primaryText,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Choose your preferred language',
                          style: ThemeColor.captionStyle(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: ThemeColor.largeSpacing),
            Expanded(
              child: Container(
                decoration: ThemeColor.cardDecoration(),
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildLanguageTile(
                      context,
                      'English',
                      '🇺🇸',
                      'English',
                    ),
                    _buildDivider(),
                    _buildLanguageTile(
                      context,
                      'فارسی',
                      '🇮🇷',
                      'Persian',
                    ),
                    _buildDivider(),
                    _buildLanguageTile(
                      context,
                      '中文',
                      '🇨🇳',
                      'Chinese',
                    ),
                    _buildDivider(),
                    _buildLanguageTile(
                      context,
                      'русский',
                      '🇷🇺',
                      'Russian',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      color: ThemeColor.dividerColor,
      indent: ThemeColor.mediumSpacing,
      endIndent: ThemeColor.mediumSpacing,
    );
  }

  Widget _buildLanguageTile(
    BuildContext context,
    String language,
    String flag,
    String englishName,
  ) {
    final isSelected = _selectedLanguage == language;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _selectedLanguage = language;
            _saveSelectedLanguage(language);
            _changeLocale(context, language);
          });
        },
        child: Padding(
          padding: EdgeInsets.all(ThemeColor.mediumSpacing),
          child: Row(
            children: [
              Text(
                flag,
                style: TextStyle(fontSize: 28),
              ),
              SizedBox(width: ThemeColor.mediumSpacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      language,
                      style: ThemeColor.bodyStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? ThemeColor.primaryColor
                            : ThemeColor.primaryText,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      englishName,
                      style: ThemeColor.captionStyle(
                        color: isSelected
                            ? ThemeColor.primaryColor.withOpacity(0.8)
                            : ThemeColor.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: ThemeColor.fastAnimation,
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? ThemeColor.primaryColor
                      : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? ThemeColor.primaryColor
                        : ThemeColor.borderColor,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: isSelected ? Colors.white : Colors.transparent,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
