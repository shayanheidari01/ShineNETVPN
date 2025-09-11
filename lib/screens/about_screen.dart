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
                      context.tr('about'),
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
                        Icons.info_rounded,
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
                  // App logo and title card
                  _buildAppHeaderCard(),
                  SizedBox(height: ThemeColor.largeSpacing),
                  
                  // App features card
                  _buildFeaturesCard(),
                  SizedBox(height: ThemeColor.largeSpacing),
                  
                  // Connect with us section
                  _buildModernSection(
                    title: 'Connect with Us',
                    icon: Icons.connect_without_contact_rounded,
                    children: [
                      _buildModernContactCard(
                        icon: Icons.email_rounded,
                        title: 'Email Support',
                        subtitle: 'shinenetvpn@gmail.com',
                        color: ThemeColor.primaryColor,
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          final Uri emailLaunchUri = Uri(
                            scheme: 'mailto',
                            path: 'shinenetvpn@gmail.com',
                            queryParameters: {
                              'subject': 'ShineNET VPN Support Request'
                            },
                          );
                          await launchUrl(emailLaunchUri);
                        },
                      ),
                      SizedBox(height: ThemeColor.smallSpacing),
                      _buildModernContactCard(
                        icon: Icons.chat_rounded,
                        title: context.tr('telegram_channel'),
                        subtitle: 'Join our community for updates',
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
                      _buildModernContactCard(
                        icon: Icons.code_rounded,
                        title: 'Open Source',
                        subtitle: 'View code on GitHub',
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
                  SizedBox(height: ThemeColor.largeSpacing),
                  
                  // App Information section
                  _buildModernSection(
                    title: 'App Information',
                    icon: Icons.info_rounded,
                    children: [
                      _buildModernInfoCard(
                        icon: Icons.update_rounded,
                        title: 'App Version',
                        subtitle: version ?? '1.0.1',
                        color: ThemeColor.primaryColor,
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
                  SizedBox(height: ThemeColor.largeSpacing),
                  
                  // Copyright info card
                  _buildCopyrightCard(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Modern app header card
  Widget _buildAppHeaderCard() {
    return AnimatedContainer(
      duration: ThemeColor.mediumAnimation,
      padding: EdgeInsets.all(ThemeColor.largeSpacing),
      decoration: ThemeColor.cardDecoration(
        withGradient: true,
        withShadow: true,
      ),
      child: Column(
        children: [
          // App logo with modern design
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ThemeColor.largeRadius),
              boxShadow: [
                BoxShadow(
                  color: ThemeColor.primaryColor.withOpacity(0.3),
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
            context.tr('app_title'),
            style: ThemeColor.headingStyle(
              fontSize: 28,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: ThemeColor.smallSpacing),
          if (version != null)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: ThemeColor.mediumSpacing,
                vertical: ThemeColor.smallSpacing,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(ThemeColor.largeRadius),
              ),
              child: Text(
                '${context.tr('version_title')}: $version',
                style: ThemeColor.captionStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Modern features card
  Widget _buildFeaturesCard() {
    return AnimatedContainer(
      duration: ThemeColor.mediumAnimation,
      padding: EdgeInsets.all(ThemeColor.largeSpacing),
      decoration: ThemeColor.cardDecoration(
        withShadow: true,
      ),
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
                'Key Features',
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
                child: _buildModernFeatureItem(
                  icon: Icons.security_rounded,
                  title: 'Secure',
                  description: 'Military-grade\nencryption',
                  color: ThemeColor.successColor,
                ),
              ),
              Expanded(
                child: _buildModernFeatureItem(
                  icon: Icons.speed_rounded,
                  title: 'Fast',
                  description: 'High-speed\nservers',
                  color: ThemeColor.primaryColor,
                ),
              ),
              Expanded(
                child: _buildModernFeatureItem(
                  icon: Icons.code_rounded,
                  title: 'Open Source',
                  description: 'Transparent\n& trustworthy',
                  color: ThemeColor.warningColor,
                ),
              ),
            ],
          ),
          SizedBox(height: ThemeColor.largeSpacing),
          Divider(
            color: ThemeColor.dividerColor,
            height: 1,
          ),
          SizedBox(height: ThemeColor.largeSpacing),
          Text(
            context.tr('about_description'),
            style: ThemeColor.bodyStyle(
              color: ThemeColor.secondaryText,
            ).copyWith(height: 1.6),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Modern section builder consistent with settings and home
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

  // Modern contact card
  Widget _buildModernContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: ThemeColor.mediumAnimation,
      decoration: ThemeColor.cardDecoration(
        withShadow: true,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
          child: Padding(
            padding: EdgeInsets.all(ThemeColor.mediumSpacing),
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
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: color,
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

  // Modern feature item
  Widget _buildModernFeatureItem({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(ThemeColor.smallSpacing),
      child: Column(
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
              size: 28,
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
          SizedBox(height: 4),
          Text(
            description,
            style: ThemeColor.captionStyle(
              color: ThemeColor.mutedText,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Copyright card
  Widget _buildCopyrightCard() {
    return AnimatedContainer(
      duration: ThemeColor.mediumAnimation,
      padding: EdgeInsets.all(ThemeColor.mediumSpacing),
      decoration: ThemeColor.cardDecoration(
        withShadow: true,
      ),
      child: Column(
        children: [
          Icon(
            Icons.copyright_rounded,
            color: ThemeColor.mutedText,
            size: 20,
          ),
          SizedBox(height: ThemeColor.smallSpacing),
          Text(
            context.tr('copyright'),
            style: ThemeColor.captionStyle(
              color: ThemeColor.mutedText,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
