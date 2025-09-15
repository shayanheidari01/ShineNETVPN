import 'package:shinenet_vpn/common/theme.dart';
import 'package:shinenet_vpn/widgets/settings/blocked_apps_widget.dart';
import 'package:shinenet_vpn/widgets/settings/language_widget.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsWidget extends StatefulWidget {
  SettingsWidget({super.key});

  @override
  _SettingsWidgetState createState() => _SettingsWidgetState();
}

class _SettingsWidgetState extends State<SettingsWidget> {
  String? _selectedLanguage;

  @override
  void initState() {
    super.initState();
    _loadSelectedLanguage();
  }

  // بارگذاری زبان از SharedPreferences
  void _loadSelectedLanguage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedLanguage = prefs.getString('selectedLanguage') ?? 'English';
    });
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
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: EdgeInsets.symmetric(
                  horizontal: ThemeColor.mediumSpacing,
                  vertical: ThemeColor.smallSpacing,
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'setting'.tr(),
                      style: ThemeColor.headingStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
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

  // Simplified settings section
  Widget _buildSimplifiedSettingsSection() {
    return Container(
      decoration: ThemeColor.cardDecoration(),
      child: Padding(
        padding: EdgeInsets.all(ThemeColor.largeSpacing),
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
    return Container(
      padding: EdgeInsets.all(ThemeColor.mediumSpacing),
      decoration: BoxDecoration(
        color: ThemeColor.successColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
        border: Border.all(
          color: ThemeColor.successColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ThemeColor.successColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
            ),
            child: Icon(
              Icons.security_rounded,
              color: ThemeColor.successColor,
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
                  style: ThemeColor.bodyStyle(
                    fontWeight: FontWeight.w600,
                    color: ThemeColor.primaryText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  'no_logs_policy'.tr(),
                  style: ThemeColor.captionStyle(
                    color: ThemeColor.successColor.withValues(alpha: 0.8),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
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
          subtitle: _selectedLanguage ?? 'language_english'.tr(),
          color: ThemeColor.warningColor,
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context)
                .push(
              MaterialPageRoute(
                builder: (context) => LanguageWidget(
                  selectedLanguage: _selectedLanguage!,
                ),
              ),
            )
                .then((value) {
              _loadSelectedLanguage();
            });
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
        child: Container(
          padding: EdgeInsets.all(ThemeColor.mediumSpacing),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
            border: Border.all(
              color: color.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
                ),
                child: Icon(
                  icon,
                  color: color,
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
                      style: ThemeColor.bodyStyle(
                        fontWeight: FontWeight.w600,
                        color: ThemeColor.primaryText,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: ThemeColor.captionStyle(
                        color: ThemeColor.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: color,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Simplified app info
  Widget _buildSimplifiedAppInfo() {
    return Container(
      decoration: ThemeColor.cardDecoration(),
      child: Padding(
        padding: EdgeInsets.all(ThemeColor.largeSpacing),
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
                    style: ThemeColor.bodyStyle(
                      fontWeight: FontWeight.w600,
                      color: ThemeColor.primaryText,
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
                    value: '1.0.4',
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
    return Container(
      padding: EdgeInsets.all(ThemeColor.mediumSpacing),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: ThemeColor.smallSpacing),
          Text(
            value,
            style: ThemeColor.bodyStyle(
              fontWeight: FontWeight.w700,
              color: color,
              fontSize: 16,
            ),
          ),
          Text(
            title,
            style: ThemeColor.captionStyle(
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

}
