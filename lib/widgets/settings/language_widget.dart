import 'package:shinenet_vpn/common/theme.dart';
import 'package:shinenet_vpn/common/font_helper.dart';
import 'package:shinenet_vpn/common/liquid_glass_container.dart';
import 'package:shinenet_vpn/services/language_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';

class LanguageWidget extends StatefulWidget {
  const LanguageWidget({super.key});

  @override
  State<LanguageWidget> createState() => _LanguageWidgetState();
}

class _LanguageWidgetState extends State<LanguageWidget> {
  String _selectedLanguageCode = 'en';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSelectedLanguage();
  }

  // Refresh language when widget becomes visible again
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadSelectedLanguage();
  }

  Future<void> _loadSelectedLanguage() async {
    try {
      // Load from saved preference instead of context
      final savedLanguage = await LanguageManager.getSavedLanguage();
      if (mounted) {
        setState(() {
          _selectedLanguageCode = savedLanguage;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _selectedLanguageCode = 'en'; // fallback to English
        });
      }
    }
  }

  Future<void> _changeLanguage(String languageCode) async {
    if (_selectedLanguageCode == languageCode) return;

    setState(() => _isLoading = true);

    try {
      final success =
          await LanguageManager.changeLanguage(context, languageCode);

      if (success) {
        setState(() => _selectedLanguageCode = languageCode);
        HapticFeedback.lightImpact();

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'language_changed_successfully'.tr(),
                style: FontHelper.getBodyStyle(
                  color: Colors.white,
                  context: context,
                ),
              ),
              backgroundColor: ThemeColor.successColor,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.all(ThemeColor.mediumSpacing),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
              ),
            ),
          );

          // Force rebuild of parent contexts
          // This ensures the UI updates immediately
          Future.delayed(Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          });
        }
      } else {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'language_change_failed'.tr(),
                style: FontHelper.getBodyStyle(
                  color: Colors.white,
                  context: context,
                ),
              ),
              backgroundColor: ThemeColor.errorColor,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.all(ThemeColor.mediumSpacing),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
              ),
            ),
          );
        }
      }
    } catch (e) {
      // Handle unexpected errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'language_change_failed'.tr(),
              style: FontHelper.getBodyStyle(
                color: Colors.white,
                context: context,
              ),
            ),
            backgroundColor: ThemeColor.errorColor,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(ThemeColor.mediumSpacing),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
          style: FontHelper.getHeadingStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            context: context,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.all(ThemeColor.mediumSpacing),
              children: [
                Text(
                  'choose_preferred_language'.tr(),
                  style: FontHelper.getCaptionStyle(
                    fontSize: 16,
                    color: ThemeColor.mutedText,
                    context: context,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: ThemeColor.largeSpacing),

                // Language options
                for (final language in LanguageManager.getAllLanguages())
                  Padding(
                    padding: EdgeInsets.only(bottom: ThemeColor.smallSpacing),
                    child: _buildLanguageCard(language),
                  ),
              ],
            ),
    );
  }

  Widget _buildLanguageCard(LanguageInfo language) {
    final isSelected = _selectedLanguageCode == language.code;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
        border: Border.all(
          color: isSelected
              ? ThemeColor.primaryColor
              : ThemeColor.borderColor.withOpacity(0.7),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: LiquidGlassContainer(
        borderRadius: ThemeColor.mediumRadius,
        blurSigma: 28,
        padding: EdgeInsets.all(ThemeColor.mediumSpacing),
        showShadow: isSelected,
        showBorder: false,
        gradientColors: isSelected
            ? [
                ThemeColor.primaryColor.withValues(alpha: 0.35),
                ThemeColor.primaryColor.withValues(alpha: 0.08),
              ]
            : [
                Colors.white.withOpacity(0.16),
                Colors.white.withOpacity(0.04),
              ],
        opacity: isSelected ? 0.2 : 0.1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
            onTap: _isLoading ? null : () => _changeLanguage(language.code),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? ThemeColor.primaryColor.withValues(alpha: 0.15)
                        : Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
                  ),
                  child: Text(
                    language.flag,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                SizedBox(width: ThemeColor.mediumSpacing),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LanguageManager.getLanguageDisplayName(
                          language.code,
                          context,
                        ),
                        style: FontHelper.getBodyStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isSelected
                              ? ThemeColor.primaryColor
                              : ThemeColor.primaryText,
                          context: context,
                        ),
                      ),
                      if (language.nativeName !=
                          LanguageManager.getLanguageDisplayName(
                            language.code,
                            context,
                          ))
                        Text(
                          language.nativeName,
                          style: FontHelper.getCaptionStyle(
                            fontSize: 14,
                            color: ThemeColor.mutedText,
                            context: context,
                          ),
                        ),
                    ],
                  ),
                ),
                if (_isLoading && _selectedLanguageCode == language.code)
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        ThemeColor.primaryColor,
                      ),
                    ),
                  )
                else if (isSelected)
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
