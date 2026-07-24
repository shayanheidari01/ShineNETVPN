import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shinenet_vpn/common/theme.dart';
import 'package:shinenet_vpn/screens/scan_mode_screen.dart';
import 'package:shinenet_vpn/services/language_manager.dart';
import 'package:shinenet_vpn/widgets/settings/blocked_apps_widget.dart';
import 'package:shinenet_vpn/widgets/settings/font_accessibility_widget.dart';
import 'package:shinenet_vpn/widgets/settings/language_widget.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedLanguage = '';
  String? _appVersion;
  bool _loadingLanguage = false;

  @override
  void initState() {
    super.initState();
    _loadSelectedLanguage();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _appVersion = info.version);
  }

  Future<void> _loadSelectedLanguage() async {
    if (_loadingLanguage) return;
    _loadingLanguage = true;
    try {
      final language =
          await LanguageManager.getCurrentLanguageFromPreference();
      if (!mounted) return;
      setState(() {
        _selectedLanguage =
            LanguageManager.getLanguageDisplayName(language.code, context);
      });
    } catch (_) {
      if (mounted) {
        setState(() => _selectedLanguage = 'language_english'.tr());
      }
    } finally {
      _loadingLanguage = false;
    }
  }

  Future<void> _open(Widget page, {bool refreshLanguage = false}) async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
    if (refreshLanguage && mounted) await _loadSelectedLanguage();
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
                'setting'.tr(),
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
                  _privacyCard(context),
                  const SizedBox(height: 24),
                  _sectionLabel(context, 'setting'.tr()),
                  const SizedBox(height: 10),
                  _settingsGroup(context),
                  const SizedBox(height: 24),
                  _sectionLabel(context, 'app_information'.tr()),
                  const SizedBox(height: 10),
                  _appInfo(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _privacyCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ThemeColor.primaryColor.withValues(alpha: 0.16),
            ThemeColor.cardColor,
          ],
        ),
        borderRadius: BorderRadius.circular(ThemeColor.largeRadius),
        border: Border.all(
          color: ThemeColor.primaryColor.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: ThemeColor.primaryColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: ThemeColor.primaryColor,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'privacy_security'.tr(),
                  style: ThemeColor.bodyStyle(
                    color: ThemeColor.primaryText,
                    fontWeight: FontWeight.w700,
                    context: context,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'no_logs_policy'.tr(),
                  style: ThemeColor.captionStyle(context: context),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.verified_user_rounded,
            size: 20,
            color: ThemeColor.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        label.toUpperCase(),
        style: ThemeColor.captionStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: ThemeColor.mutedText,
          context: context,
        ).copyWith(letterSpacing: 1.1),
      ),
    );
  }

  Widget _settingsGroup(BuildContext context) {
    final items = [
      _SettingItem(
        Icons.radar_rounded,
        'scan_mode'.tr(),
        'scan_mode_settings_subtitle'.tr(),
        () => _open(const ScanModeScreen()),
      ),
      _SettingItem(
        Icons.grid_view_rounded,
        'block_application'.tr(),
        'control_apps_bypass'.tr(),
        () => _open(BlockedAppsWidget()),
      ),
      _SettingItem(
        Icons.translate_rounded,
        'language'.tr(),
        _selectedLanguage.isEmpty
            ? 'language_english'.tr()
            : _selectedLanguage,
        () => _open(const LanguageWidget(), refreshLanguage: true),
      ),
      _SettingItem(
        Icons.format_size_rounded,
        'font_accessibility'.tr(),
        'font_size_settings'.tr(),
        () => _open(const FontAccessibilityWidget()),
      ),
    ];

    return Container(
      decoration: ThemeColor.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];
          return Column(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: item.onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 15,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: ThemeColor.elevatedSurface,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            item.icon,
                            size: 21,
                            color: ThemeColor.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: ThemeColor.bodyStyle(
                                  color: ThemeColor.primaryText,
                                  fontWeight: FontWeight.w600,
                                  context: context,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    ThemeColor.captionStyle(context: context),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: ThemeColor.mutedText,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (index != items.length - 1)
                const Divider(height: 1, indent: 72),
            ],
          );
        }),
      ),
    );
  }

  Widget _appInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: ThemeColor.cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: _infoValue(
              context,
              Icons.layers_outlined,
              'version'.tr(),
              _appVersion ?? '—',
            ),
          ),
          const SizedBox(
            height: 42,
            child: VerticalDivider(width: 24),
          ),
          Expanded(
            child: _infoValue(
              context,
              Icons.code_rounded,
              'license'.tr(),
              'mit_license'.tr(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoValue(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(icon, color: ThemeColor.secondaryText, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: ThemeColor.bodyStyle(
                  color: ThemeColor.primaryText,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  context: context,
                ),
              ),
              Text(
                label,
                style: ThemeColor.captionStyle(
                  fontSize: 11,
                  context: context,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingItem {
  const _SettingItem(this.icon, this.title, this.subtitle, this.onTap);

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}
