import 'package:shinenet_vpn/common/theme.dart';
import 'package:shinenet_vpn/common/font_helper.dart';
import 'package:shinenet_vpn/widgets/settings/blocked_apps_widget.dart';
import 'package:shinenet_vpn/widgets/settings/language_widget.dart';
import 'package:shinenet_vpn/widgets/settings/font_accessibility_widget.dart';
import 'package:shinenet_vpn/common/liquid_glass_container.dart';
import 'package:shinenet_vpn/services/language_manager.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SettingsWidget extends StatefulWidget {
  SettingsWidget({super.key});

  @override
  _SettingsWidgetState createState() => _SettingsWidgetState();
}

class _SettingsWidgetState extends State<SettingsWidget> {
  String _selectedLanguage = '';
  bool _isLoading = false;

  // Cached gradients for performance
  late final List<Color> _primaryGradient;
  late final List<Color> _successGradient;
  late final List<Color> _warningGradient;
  late final List<Color> _neutralGradient;

  @override
  void initState() {
    super.initState();
    _initializeGradients();
    _loadSelectedLanguage();
  }

  // Initialize gradients once to avoid repeated calculations
  void _initializeGradients() {
    _primaryGradient = _tintedGlassGradient(
      ThemeColor.primaryColor,
      highlight: 0.24,
      lowlight: 0.06,
    );
    _successGradient = _tintedGlassGradient(
      ThemeColor.successColor,
      highlight: 0.26,
      lowlight: 0.07,
    );
    _warningGradient = _tintedGlassGradient(
      ThemeColor.warningColor,
      highlight: 0.22,
      lowlight: 0.05,
    );
    _neutralGradient = _neutralGlassGradient(
      highlight: 0.18,
      lowlight: 0.04,
    );
  }

  // Refresh language when returning from language screen
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isLoading) {
      _loadSelectedLanguage();
    }
  }

  // Load current language from LanguageManager using saved preference
  void _loadSelectedLanguage() async {
    if (_isLoading) return; // Prevent duplicate calls

    _isLoading = true;
    try {
      final currentLang =
          await LanguageManager.getCurrentLanguageFromPreference();
      if (mounted) {
        setState(() {
          _selectedLanguage = LanguageManager.getLanguageDisplayName(
            currentLang.code,
            context,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _selectedLanguage = 'language_english'.tr();
        });
      }
    } finally {
      _isLoading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColor.backgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Modern app bar consistent with home screen
            SliverAppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              floating: true,
              pinned: false,
              expandedHeight: 80,
              automaticallyImplyLeading: false,
              title: Container(
                width: double.infinity,
                height: 80,
                alignment: Alignment.center,
                child: Text(
                  'setting'.tr(),
                  style: FontHelper.getHeadingStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    context: context,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            // Main content
            SliverPadding(
              padding: EdgeInsets.all(ThemeColor.mediumSpacing),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Simplified settings sections
                  _buildSimplifiedSettingsSection(),
                  SizedBox(height: ThemeColor.largeSpacing),

                  // Simplified app info
                  _buildSimplifiedAppInfo(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Simplified settings section with RepaintBoundary
  Widget _buildSimplifiedSettingsSection() {
    return RepaintBoundary(
      child: LiquidGlassContainer(
        padding: EdgeInsets.all(ThemeColor.largeSpacing),
        borderRadius: ThemeColor.largeRadius,
        blurSigma: 16, // Reduced from 28 to 16 (43% reduction)
        gradientColors: _primaryGradient, // Use cached gradient
        borderColor: ThemeColor.primaryColor.withValues(alpha: 0.25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Security info
            _buildSecurityInfo(),
            SizedBox(height: ThemeColor.largeSpacing),

            // Settings options
            _buildSettingsOptions(),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityInfo() {
    return RepaintBoundary(
      child: LiquidGlassContainer(
        padding: EdgeInsets.all(ThemeColor.mediumSpacing),
        borderRadius: ThemeColor.mediumRadius,
        blurSigma: 12, // Reduced from 24 to 12 (50% reduction)
        gradientColors: _successGradient, // Use cached gradient
        borderColor: ThemeColor.successColor.withValues(alpha: 0.35),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
              ),
              child: Icon(
                Icons.security_rounded,
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
                    'privacy_security'.tr(),
                    style: FontHelper.getBodyStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      context: context,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'no_logs_policy'.tr(),
                    style: FontHelper.getCaptionStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      context: context,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsOptions() {
    return Column(
      children: [
        _buildSettingOption(
          icon: Icons.apps_rounded,
          title: 'block_application'.tr(),
          subtitle: 'control_apps_bypass'.tr(),
          color: ThemeColor.primaryColor,
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => BlockedAppsWidgets(),
              ),
            );
          },
        ),
        SizedBox(height: ThemeColor.mediumSpacing),
        _buildSettingOption(
          icon: Icons.translate_rounded,
          title: 'language'.tr(),
          subtitle: _selectedLanguage.isNotEmpty
              ? _selectedLanguage
              : 'language_english'.tr(),
          color: ThemeColor.warningColor,
          onTap: () async {
            HapticFeedback.lightImpact();
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const LanguageWidget(),
              ),
            );
            // Use async/await pattern for better performance
            if (mounted) {
              _loadSelectedLanguage();
            }
          },
        ),
        SizedBox(height: ThemeColor.mediumSpacing),
        _buildSettingOption(
          icon: Icons.text_fields_rounded,
          title: 'font_accessibility'.tr(),
          subtitle: 'font_size_settings'.tr(),
          color: ThemeColor.primaryColor.withValues(alpha: 0.8),
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const FontAccessibilityWidget(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSettingOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    // Select appropriate cached gradient based on color
    List<Color> gradientColors;
    if (color == ThemeColor.warningColor) {
      gradientColors = _warningGradient;
    } else if (color == ThemeColor.primaryColor ||
        color == ThemeColor.primaryColor.withValues(alpha: 0.8)) {
      gradientColors = _primaryGradient;
    } else {
      gradientColors =
          _tintedGlassGradient(color, highlight: 0.22, lowlight: 0.05);
    }

    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
          child: LiquidGlassContainer(
            padding: EdgeInsets.all(ThemeColor.mediumSpacing),
            borderRadius: ThemeColor.mediumRadius,
            blurSigma: 8, // Reduced from 22 to 8 (64% reduction)
            showShadow: false,
            gradientColors: gradientColors, // Use cached or computed gradient
            borderColor: color.withValues(alpha: 0.3),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
                  ),
                  child: Icon(
                    icon,
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
                        title,
                        style: FontHelper.getBodyStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          context: context,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: FontHelper.getCaptionStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          context: context,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Simplified app info with RepaintBoundary
  Widget _buildSimplifiedAppInfo() {
    return RepaintBoundary(
      child: LiquidGlassContainer(
        padding: EdgeInsets.all(ThemeColor.largeSpacing),
        borderRadius: ThemeColor.largeRadius,
        blurSigma: 12, // Reduced from 26 to 12 (54% reduction)
        gradientColors: _neutralGradient, // Use cached gradient
        borderColor: ThemeColor.primaryColor.withValues(alpha: 0.2),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_rounded,
                  color: ThemeColor.primaryColor,
                  size: 20,
                ),
                SizedBox(width: ThemeColor.smallSpacing),
                Expanded(
                  child: Text(
                    'app_information'.tr(),
                    style: FontHelper.getBodyStyle(
                      fontWeight: FontWeight.w600,
                      color: ThemeColor.primaryText,
                      context: context,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: ThemeColor.mediumSpacing),
            Row(
              children: [
                Expanded(
                  child: _buildInfoCard(
                    icon: Icons.update_rounded,
                    title: 'version'.tr(),
                    value: '1.1.1',
                    color: ThemeColor.primaryColor,
                  ),
                ),
                SizedBox(width: ThemeColor.smallSpacing),
                Expanded(
                  child: _buildInfoCard(
                    icon: Icons.code_rounded,
                    title: 'license'.tr(),
                    value: 'mit_license'.tr(),
                    color: ThemeColor.successColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    // Select appropriate cached gradient based on color
    List<Color> gradientColors;
    if (color == ThemeColor.primaryColor) {
      gradientColors = _primaryGradient;
    } else if (color == ThemeColor.successColor) {
      gradientColors = _successGradient;
    } else {
      gradientColors =
          _tintedGlassGradient(color, highlight: 0.2, lowlight: 0.05);
    }

    return RepaintBoundary(
      child: LiquidGlassContainer(
        padding: EdgeInsets.all(ThemeColor.mediumSpacing),
        borderRadius: ThemeColor.mediumRadius,
        blurSigma: 6, // Reduced from 20 to 6 (70% reduction)
        showShadow: false,
        gradientColors: gradientColors, // Use cached or computed gradient
        borderColor: color.withValues(alpha: 0.3),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            SizedBox(height: ThemeColor.smallSpacing),
            Text(
              value,
              style: FontHelper.getBodyStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontSize: 16,
                context: context,
              ),
            ),
            Text(
              title,
              style: FontHelper.getCaptionStyle(
                color: Colors.white.withValues(alpha: 0.85),
                context: context,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Color> _tintedGlassGradient(
    Color tint, {
    double highlight = 0.22,
    double lowlight = 0.06,
  }) {
    return [
      tint.withOpacity(highlight.clamp(0.0, 1.0)),
      Colors.white.withOpacity(lowlight.clamp(0.0, 1.0)),
    ];
  }

  List<Color> _neutralGlassGradient({
    double highlight = 0.16,
    double lowlight = 0.05,
  }) {
    return [
      Colors.white.withOpacity(highlight.clamp(0.0, 1.0)),
      Colors.white.withOpacity(lowlight.clamp(0.0, 1.0)),
    ];
  }
}
