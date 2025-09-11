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
              automaticallyImplyLeading: true,
              leading: Container(
                margin: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ThemeColor.surfaceColor,
                  borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: ThemeColor.secondaryText,
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: EdgeInsets.symmetric(
                  horizontal: ThemeColor.mediumSpacing,
                  vertical: ThemeColor.smallSpacing,
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(width: 48), // Space for back button
                    Text(
                      context.tr('setting'),
                      style: ThemeColor.headingStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ThemeColor.surfaceColor,
                        borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
                      ),
                      child: Icon(
                        Icons.tune_rounded,
                        color: ThemeColor.primaryColor,
                        size: 20,
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
                  // Privacy & Security section
                  _buildModernSection(
                    title: 'Privacy & Security',
                    icon: Icons.security_rounded,
                    children: [
                      _buildModernInfoCard(
                        icon: Icons.verified_user_rounded,
                        title: 'Data Protection',
                        subtitle: 'No logs, no tracking policy',
                        color: ThemeColor.successColor,
                      ),
                      SizedBox(height: ThemeColor.smallSpacing),
                      _buildModernInfoCard(
                        icon: Icons.lock_rounded,
                        title: 'Encryption',
                        subtitle: 'Military-grade security protocols',
                        color: ThemeColor.primaryColor,
                      ),
                    ],
                  ),
                  SizedBox(height: ThemeColor.largeSpacing),
                  
                  // App Settings section
                  _buildModernSection(
                    title: context.tr('blocking_settings'),
                    icon: Icons.shield_rounded,
                    children: [
                      _buildModernSettingTile(
                        icon: Icons.apps_rounded,
                        title: context.tr('block_application'),
                        subtitle: 'Control which apps bypass VPN',
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => BlockedAppsWidgets(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: ThemeColor.largeSpacing),
                  
                  // Language Settings section
                  _buildModernSection(
                    title: context.tr('language_settings'),
                    icon: Icons.language_rounded,
                    children: [
                      _buildModernSettingTile(
                        icon: Icons.translate_rounded,
                        title: context.tr('language'),
                        subtitle: _selectedLanguage ?? 'English',
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
                  ),
                  SizedBox(height: ThemeColor.largeSpacing),
                  
                  // App Information section
                  _buildModernSection(
                    title: 'App Information',
                    icon: Icons.info_rounded,
                    children: [
                      _buildModernInfoCard(
                        icon: Icons.update_rounded,
                        title: 'App Version',
                        subtitle: '1.0.0',
                        color: ThemeColor.secondaryColor,
                      ),
                      SizedBox(height: ThemeColor.smallSpacing),
                      _buildModernInfoCard(
                        icon: Icons.code_rounded,
                        title: 'License',
                        subtitle: 'Open Source (MIT)',
                        color: ThemeColor.successColor,
                      ),
                    ],
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Modern section builder consistent with home screen
  Widget _buildModernSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: ThemeColor.mediumSpacing,
            vertical: ThemeColor.smallSpacing,
          ),
          decoration: BoxDecoration(
            color: ThemeColor.surfaceColor,
            borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
            border: Border.all(
              color: ThemeColor.borderColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: ThemeColor.primaryColor,
                size: 18,
              ),
              SizedBox(width: ThemeColor.smallSpacing),
              Text(
                title,
                style: ThemeColor.bodyStyle(
                  fontWeight: FontWeight.w600,
                  color: ThemeColor.primaryText,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: ThemeColor.mediumSpacing),
        ...children,
      ],
    );
  }

  // Modern setting tile matching the home screen design
  Widget _buildModernSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: ThemeColor.mediumAnimation,
      margin: EdgeInsets.only(bottom: ThemeColor.smallSpacing),
      decoration: ThemeColor.cardDecoration(
        withShadow: true,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(ThemeColor.mediumSpacing),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(ThemeColor.smallSpacing),
                  decoration: BoxDecoration(
                    color: ThemeColor.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
                    border: Border.all(
                      color: ThemeColor.primaryColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: ThemeColor.primaryColor,
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
                  color: ThemeColor.mutedText,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Modern info card for non-interactive items
  Widget _buildModernInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return AnimatedContainer(
      duration: ThemeColor.mediumAnimation,
      padding: EdgeInsets.all(ThemeColor.mediumSpacing),
      decoration: ThemeColor.cardDecoration(
        withShadow: true,
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(ThemeColor.smallSpacing),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ),
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
        ],
      ),
    );
  }
}
