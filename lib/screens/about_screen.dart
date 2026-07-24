import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shinenet_vpn/common/theme.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String? _version;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
  }

  Future<void> _launch(Uri uri) async {
    HapticFeedback.selectionClick();
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              automaticallyImplyLeading: false,
              titleSpacing: 20,
              title: Text(
                'about'.tr(),
                style: ThemeColor.headingStyle(
                  fontSize: 24,
                  context: context,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverList.list(
                children: [
                  _intro(context),
                  const SizedBox(height: 24),
                  _sectionTitle(context, 'key_features'.tr()),
                  const SizedBox(height: 10),
                  _features(context),
                  const SizedBox(height: 24),
                  _sectionTitle(context, 'connect_with_us'.tr()),
                  const SizedBox(height: 10),
                  _contacts(context),
                  const SizedBox(height: 24),
                  _footer(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title.toUpperCase(),
        style: ThemeColor.captionStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: ThemeColor.mutedText,
          context: context,
        ).copyWith(letterSpacing: 1.1),
      ),
    );
  }

  Widget _intro(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF17342A), ThemeColor.cardColor],
        ),
        borderRadius: BorderRadius.circular(ThemeColor.largeRadius),
        border: Border.all(
          color: ThemeColor.primaryColor.withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: ThemeColor.primaryGradient,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: ThemeColor.backgroundColor,
                  size: 30,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  'app_title'.tr(),
                  style: ThemeColor.headingStyle(
                    fontSize: 26,
                    context: context,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'about_description'.tr(),
            style: ThemeColor.bodyStyle(
              color: ThemeColor.secondaryText,
              context: context,
            ).copyWith(height: 1.6),
          ),
          if (_version != null) ...[
            const SizedBox(height: 16),
            Text(
              '${'version_title'.tr()}  $_version',
              style: ThemeColor.captionStyle(
                color: ThemeColor.primaryColor,
                fontWeight: FontWeight.w700,
                context: context,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _features(BuildContext context) {
    final features = [
      (Icons.lock_outline_rounded, 'secure'.tr()),
      (Icons.bolt_rounded, 'fast'.tr()),
      (Icons.code_rounded, 'open_source'.tr()),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ThemeColor.cardDecoration(),
      child: Row(
        children: features
            .map(
              (feature) => Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: ThemeColor.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        feature.$1,
                        color: ThemeColor.primaryColor,
                        size: 21,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      feature.$2,
                      textAlign: TextAlign.center,
                      style: ThemeColor.captionStyle(
                        fontWeight: FontWeight.w600,
                        color: ThemeColor.primaryText,
                        context: context,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _contacts(BuildContext context) {
    return Container(
      decoration: ThemeColor.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _contact(
            context,
            Icons.mail_outline_rounded,
            'email_support'.tr(),
            'support_email'.tr(),
            () => _launch(
              Uri(
                scheme: 'mailto',
                path: 'support_email'.tr(),
                queryParameters: {'subject': 'support_email_subject'.tr()},
              ),
            ),
          ),
          _contact(
            context,
            Icons.send_rounded,
            'telegram_channel'.tr(),
            'join_community'.tr(),
            () => _launch(Uri.parse('https://t.me/ShineNETVPN')),
          ),
          _contact(
            context,
            Icons.code_rounded,
            'open_source'.tr(),
            'view_on_github'.tr(),
            () => _launch(
              Uri.parse('https://github.com/shayanheidari01/ShineNETVPN'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contact(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Icon(icon, color: ThemeColor.primaryColor, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: ThemeColor.bodyStyle(
                        color: ThemeColor.primaryText,
                        fontWeight: FontWeight.w600,
                        context: context,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: ThemeColor.captionStyle(context: context),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.open_in_new_rounded,
                color: ThemeColor.mutedText,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footer(BuildContext context) {
    return Column(
      children: [
        Text(
          'copyright'.tr(),
          textAlign: TextAlign.center,
          style: ThemeColor.captionStyle(context: context),
        ),
        const SizedBox(height: 6),
        Text(
          'MIT License',
          style: ThemeColor.captionStyle(
            fontSize: 11,
            color: ThemeColor.mutedText,
            context: context,
          ),
        ),
      ],
    );
  }
}
