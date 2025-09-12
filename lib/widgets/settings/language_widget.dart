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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColor.backgroundColor,
      body: CustomScrollView(
        slivers: [
          // Modern app bar
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            floating: true,
            pinned: false,
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      ThemeColor.primaryColor.withValues(alpha: 0.1),
                      ThemeColor.secondaryColor.withValues(alpha: 0.05),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(ThemeColor.mediumSpacing),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(ThemeColor.mediumSpacing),
                          decoration: BoxDecoration(
                            gradient: ThemeColor.primaryGradient,
                            borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
                            boxShadow: [
                              BoxShadow(
                                color: ThemeColor.primaryColor.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.language_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        SizedBox(width: ThemeColor.mediumSpacing),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'select_language'.tr(),
                                style: ThemeColor.headingStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'choose_preferred_language'.tr(),
                                style: ThemeColor.captionStyle(
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Language options
          SliverPadding(
            padding: EdgeInsets.all(ThemeColor.mediumSpacing),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildLanguageCard(
                  context,
                  'language_english'.tr(),
                  '🇺🇸',
                  'language_english'.tr(),
                  'country_united_states'.tr(),
                ),
                SizedBox(height: ThemeColor.mediumSpacing),
                _buildLanguageCard(
                  context,
                  'language_persian'.tr(),
                  '🇮🇷',
                  'language_persian'.tr(),
                  'country_iran'.tr(),
                ),
                SizedBox(height: ThemeColor.mediumSpacing),
                _buildLanguageCard(
                  context,
                  'language_chinese'.tr(),
                  '🇨🇳',
                  'language_chinese'.tr(),
                  'country_china'.tr(),
                ),
                SizedBox(height: ThemeColor.mediumSpacing),
                _buildLanguageCard(
                  context,
                  'language_russian'.tr(),
                  '🇷🇺',
                  'language_russian'.tr(),
                  'country_russia'.tr(),
                ),
              ]),
            ),
          ),
        ],
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

  Widget _buildLanguageCard(
    BuildContext context,
    String language,
    String flag,
    String englishName,
    String country,
  ) {
    final isSelected = _selectedLanguage == language;
    
    return AnimatedContainer(
      duration: ThemeColor.mediumAnimation,
      decoration: BoxDecoration(
        gradient: isSelected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ThemeColor.primaryColor.withValues(alpha: 0.1),
                  ThemeColor.secondaryColor.withValues(alpha: 0.05),
                ],
              )
            : null,
        borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
        border: Border.all(
          color: isSelected
              ? ThemeColor.primaryColor
              : ThemeColor.borderColor,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: ThemeColor.primaryColor.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
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
            padding: EdgeInsets.all(ThemeColor.largeSpacing),
            child: Row(
              children: [
                // Flag container
                Container(
                  padding: EdgeInsets.all(ThemeColor.mediumSpacing),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? ThemeColor.primaryColor.withValues(alpha: 0.1)
                        : ThemeColor.surfaceColor,
                    borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
                    border: Border.all(
                      color: isSelected
                          ? ThemeColor.primaryColor
                          : ThemeColor.borderColor,
                    ),
                  ),
                  child: Text(
                    flag,
                    style: TextStyle(fontSize: 32),
                  ),
                ),
                SizedBox(width: ThemeColor.largeSpacing),
                
                // Language info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        language,
                        style: ThemeColor.bodyStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? ThemeColor.primaryColor
                              : ThemeColor.primaryText,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '$englishName • $country',
                        style: ThemeColor.captionStyle(
                          fontSize: 14,
                          color: isSelected
                              ? ThemeColor.primaryColor.withValues(alpha: 0.8)
                              : ThemeColor.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Selection indicator
                AnimatedContainer(
                  duration: ThemeColor.fastAnimation,
                  padding: EdgeInsets.all(8),
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
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
