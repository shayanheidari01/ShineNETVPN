import 'package:shinenet_vpn/common/theme.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutScreen extends StatefulWidget {
  AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String? version;

  @override
  void initState() {
    super.initState();
    _getVersion();
  }

  Future<void> _getVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      version = packageInfo.version;
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
                      'about'.tr(),
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
                  // Simplified app header
                  _buildSimplifiedAppHeader(),
                  SizedBox(height: ThemeColor.largeSpacing),
                  
                  // Simplified features
                  _buildSimplifiedFeatures(),
                  SizedBox(height: ThemeColor.largeSpacing),
                  
                  // Simplified contact section
                  _buildSimplifiedContactSection(),
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

  // Simplified app header
  Widget _buildSimplifiedAppHeader() {
    return Container(
      decoration: ThemeColor.cardDecoration(
        withGradient: true,
        withShadow: true,
      ),
      child: Padding(
        padding: EdgeInsets.all(ThemeColor.largeSpacing),
        child: Column(
          children: [
            // App logo
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ThemeColor.largeRadius),
                boxShadow: [
                  BoxShadow(
                    color: ThemeColor.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(ThemeColor.mediumSpacing),
                child: Icon(
                  Icons.vpn_lock_rounded,
                  color: ThemeColor.primaryColor,
                  size: 40,
                ),
              ),
            ),
            SizedBox(height: ThemeColor.mediumSpacing),
            Text(
              'app_title'.tr(),
              style: ThemeColor.headingStyle(
                fontSize: 28,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: ThemeColor.smallSpacing),
            Text(
              'about_description'.tr(),
              style: ThemeColor.bodyStyle(
                color: Colors.white.withValues(alpha: 0.9),
              ).copyWith(height: 1.6),
              textAlign: TextAlign.center,
            ),
            if (version != null) ...[
              SizedBox(height: ThemeColor.mediumSpacing),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ThemeColor.mediumSpacing,
                  vertical: ThemeColor.smallSpacing,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(ThemeColor.largeRadius),
                ),
                child: Text(
                  '${'version_title'.tr()}: $version',
                  style: ThemeColor.captionStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Simplified features
  Widget _buildSimplifiedFeatures() {
    return Container(
      decoration: ThemeColor.cardDecoration(),
      child: Padding(
        padding: EdgeInsets.all(ThemeColor.largeSpacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.star_rounded,
                  color: ThemeColor.warningColor,
                  size: 20,
                ),
                SizedBox(width: ThemeColor.smallSpacing),
                Text(
                  'key_features'.tr(),
                  style: ThemeColor.bodyStyle(
                    fontWeight: FontWeight.w600,
                    color: ThemeColor.primaryText,
                  ),
                ),
              ],
            ),
            SizedBox(height: ThemeColor.mediumSpacing),
            Row(
              children: [
                Expanded(
                  child: _buildFeatureItem(
                    icon: Icons.security_rounded,
                    title: 'secure'.tr(),
                    color: ThemeColor.successColor,
                  ),
                ),
                Expanded(
                  child: _buildFeatureItem(
                    icon: Icons.speed_rounded,
                    title: 'fast'.tr(),
                    color: ThemeColor.primaryColor,
                  ),
                ),
                Expanded(
                  child: _buildFeatureItem(
                    icon: Icons.code_rounded,
                    title: 'open_source'.tr(),
                    color: ThemeColor.warningColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(ThemeColor.mediumSpacing),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: color,
            size: 32,
          ),
        ),
        SizedBox(height: ThemeColor.smallSpacing),
        Text(
          title,
          style: ThemeColor.bodyStyle(
            fontWeight: FontWeight.w600,
            color: ThemeColor.primaryText,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // Simplified contact section
  Widget _buildSimplifiedContactSection() {
    return Container(
      decoration: ThemeColor.cardDecoration(),
      child: Padding(
        padding: EdgeInsets.all(ThemeColor.largeSpacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.connect_without_contact_rounded,
                  color: ThemeColor.primaryColor,
                  size: 20,
                ),
                SizedBox(width: ThemeColor.smallSpacing),
                Text(
                  'connect_with_us'.tr(),
                  style: ThemeColor.bodyStyle(
                    fontWeight: FontWeight.w600,
                    color: ThemeColor.primaryText,
                  ),
                ),
              ],
            ),
            SizedBox(height: ThemeColor.mediumSpacing),
            _buildContactButton(
              icon: Icons.email_rounded,
              title: 'email_support'.tr(),
              subtitle: 'support_email'.tr(),
              color: ThemeColor.primaryColor,
              onTap: () async {
                HapticFeedback.lightImpact();
                final Uri emailLaunchUri = Uri(
                  scheme: 'mailto',
                  path: 'support_email'.tr(),
                  queryParameters: {
                    'subject': 'support_email_subject'.tr()
                  },
                );
                await launchUrl(emailLaunchUri);
              },
            ),
            SizedBox(height: ThemeColor.smallSpacing),
            _buildContactButton(
              icon: Icons.chat_rounded,
              title: 'telegram_channel'.tr(),
              subtitle: 'join_community'.tr(),
              color: ThemeColor.successColor,
              onTap: () async {
                HapticFeedback.lightImpact();
                await launchUrl(
                  Uri.parse('https://t.me/ShineNETVPN'),
                  mode: LaunchMode.externalApplication,
                );
              },
            ),
            SizedBox(height: ThemeColor.smallSpacing),
            _buildContactButton(
              icon: Icons.code_rounded,
              title: 'open_source'.tr(),
              subtitle: 'view_on_github'.tr(),
              color: ThemeColor.secondaryText,
              onTap: () async {
                HapticFeedback.lightImpact();
                await launchUrl(
                  Uri.parse('https://github.com/shayanheidari01/ShineNETVPN'),
                  mode: LaunchMode.externalApplication,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactButton({
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
                  size: 20,
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
                Text(
                  'app_information'.tr(),
                  style: ThemeColor.bodyStyle(
                    fontWeight: FontWeight.w600,
                    color: ThemeColor.primaryText,
                  ),
                ),
              ],
            ),
            SizedBox(height: ThemeColor.mediumSpacing),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    icon: Icons.update_rounded,
                    title: 'version'.tr(),
                    value: version ?? '1.0.3',
                    color: ThemeColor.primaryColor,
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    icon: Icons.code_rounded,
                    title: 'license'.tr(),
                    value: 'mit_license'.tr(),
                    color: ThemeColor.successColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: ThemeColor.largeSpacing),
            Text(
              'copyright'.tr(),
              style: ThemeColor.captionStyle(
                color: ThemeColor.mutedText,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Column(
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
    );
  }

}
