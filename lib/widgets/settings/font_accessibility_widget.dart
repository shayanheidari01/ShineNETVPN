import 'package:flutter/material.dart';
import 'package:shinenet_vpn/common/theme.dart';
import 'package:shinenet_vpn/common/font_helper.dart';
import 'package:shinenet_vpn/common/liquid_glass_container.dart';
import 'package:shinenet_vpn/services/language_manager.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:developer' as developer;

/// Font accessibility configuration widget
class FontAccessibilityWidget extends StatefulWidget {
  const FontAccessibilityWidget({super.key});

  @override
  State<FontAccessibilityWidget> createState() =>
      _FontAccessibilityWidgetState();
}

class _FontAccessibilityWidgetState extends State<FontAccessibilityWidget> {
  double _fontScale = 1.0;
  bool _highContrast = false;
  bool _useSystemFontScale = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      final fontScale = await LanguageManager.getFontScale();
      setState(() {
        _fontScale = fontScale;
        _isLoading = false;
      });
    } catch (e) {
      developer.log('Error loading font settings',
          error: e, name: 'FontAccessibility');
      setState(() {
        _fontScale = 1.0;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveFontScale(double scale) async {
    try {
      await LanguageManager.setFontScale(scale);
      FontHelper.clearCache();
      setState(() => _fontScale = scale);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Font scale updated successfully',
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
      }
    } catch (e) {
      developer.log('Error saving font scale',
          error: e, name: 'FontAccessibility');

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update font scale',
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
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: ThemeColor.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'font_accessibility'.tr(),
          style: FontHelper.getHeadingStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            context: context,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(ThemeColor.mediumSpacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              'font_size_settings'.tr(),
              'customize_font_size_for_better_readability'.tr(),
            ),
            SizedBox(height: ThemeColor.mediumSpacing),
            _buildFontScaleSection(),
            SizedBox(height: ThemeColor.largeSpacing * 2),
            _buildSectionHeader(
              'font_preview'.tr(),
              'preview_text_with_current_settings'.tr(),
            ),
            SizedBox(height: ThemeColor.mediumSpacing),
            _buildFontPreviewSection(),
            SizedBox(height: ThemeColor.largeSpacing * 2),
            _buildSectionHeader(
              'accessibility_options'.tr(),
              'additional_options_for_better_accessibility'.tr(),
            ),
            SizedBox(height: ThemeColor.mediumSpacing),
            _buildAccessibilityOptions(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: FontHelper.getHeadingStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            context: context,
          ),
        ),
        SizedBox(height: ThemeColor.smallSpacing),
        Text(
          description,
          style: FontHelper.getCaptionStyle(
            fontSize: 14,
            color: ThemeColor.mutedText,
            context: context,
          ),
        ),
      ],
    );
  }

  Widget _buildFontScaleSection() {
    return LiquidGlassContainer(
      padding: EdgeInsets.all(ThemeColor.mediumSpacing),
      borderRadius: ThemeColor.largeRadius,
      blurSigma: 26,
      gradientColors: [
        ThemeColor.surfaceColor.withValues(alpha: 0.75),
        ThemeColor.surfaceColor.withValues(alpha: 0.4),
      ],
      borderColor: ThemeColor.primaryColor.withValues(alpha: 0.35),
      child: Column(
        children: [
          // Current scale display
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'font_scale'.tr(),
                style: FontHelper.getBodyStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  context: context,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: ThemeColor.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
                  border: Border.all(
                      color: ThemeColor.primaryColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${(_fontScale * 100).round()}%',
                  style: FontHelper.getBodyStyle(
                    fontSize: 14,
                    color: ThemeColor.primaryColor,
                    fontWeight: FontWeight.w600,
                    context: context,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: ThemeColor.mediumSpacing),

          // Slider control
          Row(
            children: [
              Icon(
                Icons.text_decrease,
                color: ThemeColor.mutedText,
                size: 20,
              ),
              Expanded(
                child: Slider(
                  value: _fontScale,
                  min: 0.8,
                  max: 2.0,
                  divisions: 24,
                  activeColor: ThemeColor.primaryColor,
                  inactiveColor: ThemeColor.borderColor,
                  onChanged: (value) {
                    setState(() => _fontScale = value);
                  },
                  onChangeEnd: (value) => _saveFontScale(value),
                ),
              ),
              Icon(
                Icons.text_increase,
                color: ThemeColor.mutedText,
                size: 24,
              ),
            ],
          ),

          SizedBox(height: ThemeColor.mediumSpacing),

          // Preset buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPresetButton('extra_small'.tr(), 0.8),
              _buildPresetButton('small'.tr(), 0.9),
              _buildPresetButton('default'.tr(), 1.0),
              _buildPresetButton('large'.tr(), 1.3),
              _buildPresetButton('extra_large'.tr(), 1.6),
            ],
          ),

          SizedBox(height: ThemeColor.smallSpacing),

          // Reset button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _saveFontScale(1.0),
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(
                'reset_to_default'.tr(),
                style: FontHelper.getBodyStyle(
                  fontSize: 14,
                  context: context,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: ThemeColor.mutedText,
                side: BorderSide(color: ThemeColor.borderColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButton(String label, double scale) {
    final isSelected = (_fontScale - scale).abs() < 0.05;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: GestureDetector(
          onTap: () => _saveFontScale(scale),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? ThemeColor.primaryColor : Colors.transparent,
              borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
              border: Border.all(
                color: isSelected
                    ? ThemeColor.primaryColor
                    : ThemeColor.borderColor,
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: FontHelper.getCaptionStyle(
                fontSize: 11,
                color: isSelected ? Colors.white : ThemeColor.secondaryText,
                context: context,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFontPreviewSection() {
    final currentLang = LanguageManager.getCurrentLanguage(context);
    final previewText = FontHelper.getFontPreviewText(currentLang.code);

    return SizedBox(
      width: double.infinity,
      child: LiquidGlassContainer(
        padding: EdgeInsets.all(ThemeColor.mediumSpacing),
        borderRadius: ThemeColor.largeRadius,
        blurSigma: 24,
        gradientColors: [
          ThemeColor.surfaceColor.withValues(alpha: 0.8),
          ThemeColor.surfaceColor.withValues(alpha: 0.45),
        ],
        borderColor: ThemeColor.primaryColor.withValues(alpha: 0.25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Large heading
            Text(
              'large_heading_example'.tr(),
              style: FontHelper.getHeadingStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                context: context,
              ),
            ),

            SizedBox(height: ThemeColor.smallSpacing),

            // Medium heading
            Text(
              'medium_heading_example'.tr(),
              style: FontHelper.getHeadingStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                context: context,
              ),
            ),

            SizedBox(height: ThemeColor.smallSpacing),

            // Body text
            Text(
              previewText,
              style: FontHelper.getBodyStyle(
                fontSize: 16,
                context: context,
              ),
            ),

            SizedBox(height: ThemeColor.smallSpacing),

            // Caption text
            Text(
              'caption_text_example'.tr(),
              style: FontHelper.getCaptionStyle(
                fontSize: 14,
                color: ThemeColor.mutedText,
                context: context,
              ),
            ),

            SizedBox(height: ThemeColor.smallSpacing),

            // Small text
            Text(
              'small_text_example'.tr(),
              style: FontHelper.getCaptionStyle(
                fontSize: 12,
                color: ThemeColor.mutedText,
                context: context,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessibilityOptions() {
    return LiquidGlassContainer(
      padding: EdgeInsets.all(ThemeColor.mediumSpacing),
      borderRadius: ThemeColor.largeRadius,
      blurSigma: 26,
      gradientColors: [
        ThemeColor.surfaceColor.withValues(alpha: 0.78),
        ThemeColor.surfaceColor.withValues(alpha: 0.42),
      ],
      borderColor: ThemeColor.primaryColor.withValues(alpha: 0.3),
      child: Column(
        children: [
          // Use system font scale
          SwitchListTile(
            title: Text(
              'use_system_font_scale'.tr(),
              style: FontHelper.getBodyStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                context: context,
              ),
            ),
            subtitle: Text(
              'follow_device_accessibility_settings'.tr(),
              style: FontHelper.getCaptionStyle(
                fontSize: 14,
                color: ThemeColor.mutedText,
                context: context,
              ),
            ),
            value: _useSystemFontScale,
            onChanged: (value) {
              setState(() => _useSystemFontScale = value);
              // Save preference
            },
            activeThumbColor: ThemeColor.primaryColor,
            contentPadding: EdgeInsets.zero,
          ),

          Divider(color: ThemeColor.borderColor),

          // High contrast mode
          SwitchListTile(
            title: Text(
              'high_contrast_mode'.tr(),
              style: FontHelper.getBodyStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                context: context,
              ),
            ),
            subtitle: Text(
              'increase_text_contrast_for_readability'.tr(),
              style: FontHelper.getCaptionStyle(
                fontSize: 14,
                color: ThemeColor.mutedText,
                context: context,
              ),
            ),
            value: _highContrast,
            onChanged: (value) {
              setState(() => _highContrast = value);
              // Implement high contrast mode
            },
            activeThumbColor: ThemeColor.primaryColor,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
