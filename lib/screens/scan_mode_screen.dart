import 'package:shinenet_vpn/common/theme.dart';
import 'package:shinenet_vpn/common/font_helper.dart';
import 'package:shinenet_vpn/common/liquid_glass_container.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScanModeScreen extends StatefulWidget {
  const ScanModeScreen({super.key});

  @override
  State<ScanModeScreen> createState() => _ScanModeScreenState();
}

class _ScanModeScreenState extends State<ScanModeScreen> {
  String _selectedScanMode = 'turbo';
  String _selectedIpVersion = 'v4';
  String _selectedProtocol = 'masque';
  String _selectedTransport = 'h3';
  String _selectedObfuscation = 'firewall';
  static const String _scanModeKey = 'selected_aether_scan_mode';
  static const String _ipVersionKey = 'selected_ip_version';
  static const String _protocolKey = 'selected_aether_protocol';
  static const String _transportKey = 'selected_aether_transport';
  static const String _obfuscationKey = 'selected_aether_obfuscation';

  late final List<Color> _primaryGradient;
  late final List<Color> _successGradient;
  late final List<Color> _warningGradient;
  late final List<Color> _neutralGradient;

  @override
  void initState() {
    super.initState();
    _initializeGradients();
    _loadPreferences();
  }

  void _initializeGradients() {
    _primaryGradient = _tintedGlassGradient(ThemeColor.primaryColor, highlight: 0.24, lowlight: 0.06);
    _successGradient = _tintedGlassGradient(ThemeColor.successColor, highlight: 0.26, lowlight: 0.07);
    _warningGradient = _tintedGlassGradient(ThemeColor.warningColor, highlight: 0.22, lowlight: 0.05);
    _neutralGradient = _neutralGlassGradient(highlight: 0.18, lowlight: 0.04);
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _selectedScanMode = prefs.getString(_scanModeKey) ?? 'turbo';
        _selectedIpVersion = prefs.getString(_ipVersionKey) ?? 'v4';
        _selectedProtocol = prefs.getString(_protocolKey) ?? 'masque';
        _selectedTransport = prefs.getString(_transportKey) ?? 'auto';
        _selectedObfuscation = prefs.getString(_obfuscationKey) ?? 'firewall';
      });
    }
  }

  Future<void> _savePreference(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is String) {
      await prefs.setString(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColor.backgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Show back button when opened from Settings as a pushed route
            SliverAppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              floating: true,
              pinned: false,
              expandedHeight: 80,
              leading: Navigator.of(context).canPop()
                  ? IconButton(
                      icon: Icon(Icons.arrow_back_rounded,
                          color: ThemeColor.primaryText),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  : null,
              title: Text(
                'scan_mode'.tr(),
                style: FontHelper.getHeadingStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  context: context,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              centerTitle: true,
            ),
            SliverPadding(
              padding: EdgeInsets.all(ThemeColor.mediumSpacing),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildDescriptionSection(),
                  SizedBox(height: ThemeColor.largeSpacing),
                  _buildProtocolSection(),
                  SizedBox(height: ThemeColor.largeSpacing),
                  _buildTransportSection(),
                  SizedBox(height: ThemeColor.largeSpacing),
                  _buildScanModeSection(),
                  SizedBox(height: ThemeColor.largeSpacing),
                  _buildIpVersionSection(),
                  SizedBox(height: ThemeColor.largeSpacing),
                  _buildObfuscationSection(),
                  SizedBox(height: ThemeColor.largeSpacing),
                  _buildCurrentParametersCard(),
                  SizedBox(height: ThemeColor.largeSpacing),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return RepaintBoundary(
      child: LiquidGlassContainer(
        padding: EdgeInsets.all(ThemeColor.largeSpacing),
        borderRadius: ThemeColor.largeRadius,
        blurSigma: 16,
        gradientColors: _primaryGradient,
        borderColor: ThemeColor.primaryColor.withValues(alpha: 0.25),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
              ),
              child: Icon(
                Icons.info_outline_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            SizedBox(width: ThemeColor.mediumSpacing),
            Expanded(
              child: Text(
                'scan_mode_description'.tr(),
                style: FontHelper.getBodyStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: 14,
                  context: context,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Protocol Section ---
  Widget _buildProtocolSection() {
    return RepaintBoundary(
      child: LiquidGlassContainer(
        padding: EdgeInsets.all(ThemeColor.largeSpacing),
        borderRadius: ThemeColor.largeRadius,
        blurSigma: 16,
        gradientColors: _neutralGradient,
        borderColor: ThemeColor.borderColor.withValues(alpha: 0.3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.vpn_key_rounded, color: ThemeColor.primaryColor, size: 20),
                SizedBox(width: ThemeColor.smallSpacing),
                Text(
                  'protocol_selection'.tr(),
                  style: FontHelper.getBodyStyle(
                    fontWeight: FontWeight.w700,
                    color: ThemeColor.primaryText,
                    context: context,
                  ),
                ),
              ],
            ),
            SizedBox(height: ThemeColor.largeSpacing),
            Row(
              children: [
                Expanded(
                  child: _buildProtocolOption(
                    value: 'masque',
                    name: 'protocol_masque'.tr(),
                    description: 'protocol_masque_desc'.tr(),
                    icon: Icons.http_rounded,
                  ),
                ),
                SizedBox(width: ThemeColor.smallSpacing),
                Expanded(
                  child: _buildProtocolOption(
                    value: 'wireguard',
                    name: 'protocol_wireguard'.tr(),
                    description: 'protocol_wireguard_desc'.tr(),
                    icon: Icons.speed_rounded,
                  ),
                ),
                SizedBox(width: ThemeColor.smallSpacing),
                Expanded(
                  child: _buildProtocolOption(
                    value: 'gool',
                    name: 'protocol_gool'.tr(),
                    description: 'protocol_gool_desc'.tr(),
                    icon: Icons.layers_rounded,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProtocolOption({
    required String value,
    required String name,
    required String description,
    required IconData icon,
  }) {
    final isSelected = _selectedProtocol == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _selectedProtocol = value);
          _savePreference(_protocolKey, value);
        },
        borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? ThemeColor.primaryColor.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
            border: Border.all(
              color: isSelected ? ThemeColor.primaryColor : Colors.white.withValues(alpha: 0.08),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? ThemeColor.primaryColor : ThemeColor.mutedText,
                size: 24,
              ),
              SizedBox(height: 6),
              Text(
                name,
                style: FontHelper.getBodyStyle(
                  fontWeight: FontWeight.w700,
                  color: isSelected ? ThemeColor.primaryColor : ThemeColor.primaryText,
                  fontSize: 12,
                  context: context,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 3),
              Text(
                description,
                style: FontHelper.getCaptionStyle(
                  color: isSelected
                      ? ThemeColor.primaryColor.withValues(alpha: 0.8)
                      : ThemeColor.mutedText,
                  fontSize: 10,
                  context: context,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Transport Section (only for MASQUE) ---
  Widget _buildTransportSection() {
    if (_selectedProtocol != 'masque') return SizedBox.shrink();

    return RepaintBoundary(
      child: LiquidGlassContainer(
        padding: EdgeInsets.all(ThemeColor.largeSpacing),
        borderRadius: ThemeColor.largeRadius,
        blurSigma: 16,
        gradientColors: _neutralGradient,
        borderColor: ThemeColor.borderColor.withValues(alpha: 0.3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.swap_horiz_rounded, color: ThemeColor.primaryColor, size: 20),
                SizedBox(width: ThemeColor.smallSpacing),
                Text(
                  'transport_selection'.tr(),
                  style: FontHelper.getBodyStyle(
                    fontWeight: FontWeight.w700,
                    color: ThemeColor.primaryText,
                    context: context,
                  ),
                ),
              ],
            ),
            SizedBox(height: ThemeColor.largeSpacing),
            Row(
              children: [
                Expanded(
                  child: _buildTransportOption(
                    value: 'auto',
                    name: 'Auto',
                    description: 'H2 first, then H3',
                    icon: Icons.autorenew_rounded,
                  ),
                ),
                SizedBox(width: ThemeColor.smallSpacing),
                Expanded(
                  child: _buildTransportOption(
                    value: 'h3',
                    name: 'transport_h3'.tr(),
                    description: 'transport_h3_desc'.tr(),
                    icon: Icons.bolt_rounded,
                  ),
                ),
                SizedBox(width: ThemeColor.smallSpacing),
                Expanded(
                  child: _buildTransportOption(
                    value: 'h2',
                    name: 'transport_h2'.tr(),
                    description: 'transport_h2_desc'.tr(),
                    icon: Icons.cable_rounded,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransportOption({
    required String value,
    required String name,
    required String description,
    required IconData icon,
  }) {
    final isSelected = _selectedTransport == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _selectedTransport = value);
          _savePreference(_transportKey, value);
        },
        borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? ThemeColor.primaryColor.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
            border: Border.all(
              color: isSelected ? ThemeColor.primaryColor : Colors.white.withValues(alpha: 0.08),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? ThemeColor.primaryColor : ThemeColor.mutedText,
                size: 24,
              ),
              SizedBox(height: 6),
              Text(
                name,
                style: FontHelper.getBodyStyle(
                  fontWeight: FontWeight.w700,
                  color: isSelected ? ThemeColor.primaryColor : ThemeColor.primaryText,
                  fontSize: 13,
                  context: context,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 3),
              Text(
                description,
                style: FontHelper.getCaptionStyle(
                  color: isSelected
                      ? ThemeColor.primaryColor.withValues(alpha: 0.8)
                      : ThemeColor.mutedText,
                  fontSize: 10,
                  context: context,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Scan Mode Section ---
  Widget _buildScanModeSection() {
    return RepaintBoundary(
      child: LiquidGlassContainer(
        padding: EdgeInsets.all(ThemeColor.largeSpacing),
        borderRadius: ThemeColor.largeRadius,
        blurSigma: 16,
        gradientColors: _neutralGradient,
        borderColor: ThemeColor.borderColor.withValues(alpha: 0.3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed_rounded, color: ThemeColor.primaryColor, size: 20),
                SizedBox(width: ThemeColor.smallSpacing),
                Text(
                  'scan_intensity'.tr(),
                  style: FontHelper.getBodyStyle(
                    fontWeight: FontWeight.w700,
                    color: ThemeColor.primaryText,
                    context: context,
                  ),
                ),
              ],
            ),
            SizedBox(height: ThemeColor.largeSpacing),
            _buildScanModeOption(
              mode: 'turbo',
              name: 'scan_turbo'.tr(),
              description: 'scan_turbo_desc'.tr(),
              icon: Icons.bolt_rounded,
              color: ThemeColor.warningColor,
              params: '45s \u2022 \u226420',
            ),
            SizedBox(height: ThemeColor.smallSpacing),
            _buildScanModeOption(
              mode: 'balanced',
              name: 'scan_balanced'.tr(),
              description: 'scan_balanced_desc'.tr(),
              icon: Icons.balance_rounded,
              color: ThemeColor.successColor,
              params: '120s \u2022 \u226416',
            ),
            SizedBox(height: ThemeColor.smallSpacing),
            _buildScanModeOption(
              mode: 'thorough',
              name: 'scan_thorough'.tr(),
              description: 'scan_thorough_desc'.tr(),
              icon: Icons.radar_rounded,
              color: ThemeColor.primaryColor,
              params: '300s \u2022 \u226420',
            ),
            SizedBox(height: ThemeColor.smallSpacing),
            _buildScanModeOption(
              mode: 'stealth',
              name: 'scan_stealth'.tr(),
              description: 'scan_stealth_desc'.tr(),
              icon: Icons.visibility_off_rounded,
              color: ThemeColor.mutedText,
              params: '180s \u2022 \u22643',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanModeOption({
    required String mode,
    required String name,
    required String description,
    required IconData icon,
    required Color color,
    required String params,
  }) {
    final isSelected = _selectedScanMode == mode;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _selectedScanMode = mode);
          _savePreference(_scanModeKey, mode);
        },
        borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          padding: EdgeInsets.all(ThemeColor.mediumSpacing),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
            border: Border.all(
              color: isSelected ? color : Colors.white.withValues(alpha: 0.08),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? color : ThemeColor.mutedText,
                  size: 20,
                ),
              ),
              SizedBox(width: ThemeColor.mediumSpacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: FontHelper.getBodyStyle(
                              fontWeight: FontWeight.w700,
                              color: isSelected ? color : ThemeColor.primaryText,
                              fontSize: 14,
                              context: context,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? color.withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            params,
                            style: FontHelper.getCaptionStyle(
                              color: isSelected ? color : ThemeColor.mutedText,
                              fontSize: 10,
                              context: context,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 3),
                    Text(
                      description,
                      style: FontHelper.getCaptionStyle(
                        color: isSelected
                            ? color.withValues(alpha: 0.85)
                            : ThemeColor.mutedText,
                        fontSize: 11,
                        context: context,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? color : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? color : ThemeColor.mutedText.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Icon(Icons.check, color: Colors.white, size: 13)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- IP Version Section ---
  Widget _buildIpVersionSection() {
    return RepaintBoundary(
      child: LiquidGlassContainer(
        padding: EdgeInsets.all(ThemeColor.largeSpacing),
        borderRadius: ThemeColor.largeRadius,
        blurSigma: 16,
        gradientColors: _neutralGradient,
        borderColor: ThemeColor.borderColor.withValues(alpha: 0.3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.language_rounded, color: ThemeColor.primaryColor, size: 20),
                SizedBox(width: ThemeColor.smallSpacing),
                Text(
                  'ip_version'.tr(),
                  style: FontHelper.getBodyStyle(
                    fontWeight: FontWeight.w700,
                    color: ThemeColor.primaryText,
                    context: context,
                  ),
                ),
              ],
            ),
            SizedBox(height: ThemeColor.largeSpacing),
            Row(
              children: [
                Expanded(
                  child: _buildIpOption(
                    value: 'v4',
                    label: 'IPv4',
                    description: 'ip_v4_desc'.tr(),
                    isSelected: _selectedIpVersion == 'v4',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _selectedIpVersion = 'v4');
                      _savePreference(_ipVersionKey, 'v4');
                    },
                  ),
                ),
                SizedBox(width: ThemeColor.smallSpacing),
                Expanded(
                  child: _buildIpOption(
                    value: 'v6',
                    label: 'IPv6',
                    description: 'ip_v6_desc'.tr(),
                    isSelected: _selectedIpVersion == 'v6',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _selectedIpVersion = 'v6');
                      _savePreference(_ipVersionKey, 'v6');
                    },
                  ),
                ),
                SizedBox(width: ThemeColor.smallSpacing),
                Expanded(
                  child: _buildIpOption(
                    value: 'both',
                    label: 'Dual',
                    description: 'ip_both_desc'.tr(),
                    isSelected: _selectedIpVersion == 'both',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _selectedIpVersion = 'both');
                      _savePreference(_ipVersionKey, 'both');
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIpOption({
    required String value,
    required String label,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? ThemeColor.primaryColor.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
            border: Border.all(
              color: isSelected ? ThemeColor.primaryColor : Colors.white.withValues(alpha: 0.08),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                value == 'v4' ? Icons.wifi_rounded : (value == 'v6' ? Icons.wifi_find_rounded : Icons.device_hub_rounded),
                color: isSelected ? ThemeColor.primaryColor : ThemeColor.mutedText,
                size: 24,
              ),
              SizedBox(height: 6),
              Text(
                label,
                style: FontHelper.getBodyStyle(
                  fontWeight: FontWeight.w700,
                  color: isSelected ? ThemeColor.primaryColor : ThemeColor.primaryText,
                  fontSize: 13,
                  context: context,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 3),
              Text(
                description,
                style: FontHelper.getCaptionStyle(
                  color: isSelected
                      ? ThemeColor.primaryColor.withValues(alpha: 0.8)
                      : ThemeColor.mutedText,
                  fontSize: 10,
                  context: context,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Obfuscation Section ---
  Widget _buildObfuscationSection() {
    return RepaintBoundary(
      child: LiquidGlassContainer(
        padding: EdgeInsets.all(ThemeColor.largeSpacing),
        borderRadius: ThemeColor.largeRadius,
        blurSigma: 16,
        gradientColors: _neutralGradient,
        borderColor: ThemeColor.borderColor.withValues(alpha: 0.3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shuffle_rounded, color: ThemeColor.primaryColor, size: 20),
                SizedBox(width: ThemeColor.smallSpacing),
                Text(
                  'obfuscation'.tr(),
                  style: FontHelper.getBodyStyle(
                    fontWeight: FontWeight.w700,
                    color: ThemeColor.primaryText,
                    context: context,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(
              'obfuscation_desc'.tr(),
              style: FontHelper.getCaptionStyle(
                color: ThemeColor.mutedText,
                fontSize: 12,
                context: context,
              ),
            ),
            SizedBox(height: ThemeColor.largeSpacing),
            _buildObfuscationOption(
              value: 'firewall',
              name: 'obf_firewall'.tr(),
              description: 'obf_firewall_desc'.tr(),
            ),
            SizedBox(height: ThemeColor.smallSpacing),
            _buildObfuscationOption(
              value: 'balanced',
              name: 'obf_balanced'.tr(),
              description: 'obf_balanced_desc'.tr(),
            ),
            SizedBox(height: ThemeColor.smallSpacing),
            _buildObfuscationOption(
              value: 'aggressive',
              name: 'obf_aggressive'.tr(),
              description: 'obf_aggressive_desc'.tr(),
            ),
            SizedBox(height: ThemeColor.smallSpacing),
            _buildObfuscationOption(
              value: 'light',
              name: 'obf_light'.tr(),
              description: 'obf_light_desc'.tr(),
            ),
            SizedBox(height: ThemeColor.smallSpacing),
            _buildObfuscationOption(
              value: 'off',
              name: 'obf_off'.tr(),
              description: 'obf_off_desc'.tr(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildObfuscationOption({
    required String value,
    required String name,
    required String description,
  }) {
    final isSelected = _selectedObfuscation == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _selectedObfuscation = value);
          _savePreference(_obfuscationKey, value);
        },
        borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          padding: EdgeInsets.all(ThemeColor.mediumSpacing),
          decoration: BoxDecoration(
            color: isSelected
                ? ThemeColor.primaryColor.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
            border: Border.all(
              color: isSelected ? ThemeColor.primaryColor : Colors.white.withValues(alpha: 0.08),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? ThemeColor.primaryColor : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? ThemeColor.primaryColor : ThemeColor.mutedText.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Icon(Icons.check, color: Colors.white, size: 13)
                    : null,
              ),
              SizedBox(width: ThemeColor.mediumSpacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: FontHelper.getBodyStyle(
                        fontWeight: FontWeight.w700,
                        color: isSelected ? ThemeColor.primaryColor : ThemeColor.primaryText,
                        fontSize: 14,
                        context: context,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      description,
                      style: FontHelper.getCaptionStyle(
                        color: isSelected
                            ? ThemeColor.primaryColor.withValues(alpha: 0.85)
                            : ThemeColor.mutedText,
                        fontSize: 12,
                        context: context,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentParametersCard() {
    final params = _getScanParameters(_selectedScanMode);

    return RepaintBoundary(
      child: LiquidGlassContainer(
        padding: EdgeInsets.all(ThemeColor.largeSpacing),
        borderRadius: ThemeColor.largeRadius,
        blurSigma: 16,
        gradientColors: _successGradient,
        borderColor: ThemeColor.successColor.withValues(alpha: 0.25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings_rounded, color: Colors.white, size: 20),
                SizedBox(width: ThemeColor.smallSpacing),
                Text(
                  'current_parameters'.tr(),
                  style: FontHelper.getBodyStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    context: context,
                  ),
                ),
              ],
            ),
            SizedBox(height: ThemeColor.mediumSpacing),
            _buildParameterRow('concurrency'.tr(), '${params['concurrency']}'),
            _buildParameterRow('timeout'.tr(), '${params['timeout']}'),
            _buildParameterRow('deadline'.tr(), '${params['deadline']}'),
            _buildParameterRow('target_gateways'.tr(), '${params['target']}'),
            _buildParameterRow('subnet_scan'.tr(), params['fullSubnet'] ? 'Full /24' : 'Sampled'),
            _buildParameterRow('quiet_period'.tr(), '${params['quiet']}'),
            _buildParameterRow('early_exit'.tr(), params['earlyExit'] ? 'Yes' : 'No'),
            _buildParameterRow('sample_per_cidr'.tr(), '${params['sample']}'),
          ],
        ),
      ),
    );
  }

  Widget _buildParameterRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: FontHelper.getCaptionStyle(
              color: Colors.white.withValues(alpha: 0.85),
              context: context,
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              value,
              style: FontHelper.getBodyStyle(
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontSize: 13,
                context: context,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getScanParameters(String mode) {
    switch (mode) {
      case 'turbo':
        return {
          'concurrency': '20 probes',
          'timeout': '6s per probe',
          'deadline': '45s total',
          'target': '1 (first hit)',
          'fullSubnet': false,
          'quiet': '0s',
          'earlyExit': true,
          'sample': '64 per /24',
        };
      case 'balanced':
        return {
          'concurrency': '16 probes',
          'timeout': '6s per probe',
          'deadline': '120s total',
          'target': '6 gateways',
          'fullSubnet': false,
          'quiet': '20s',
          'earlyExit': false,
          'sample': '140 per /24',
        };
      case 'thorough':
        return {
          'concurrency': '20 probes',
          'timeout': '10s per probe',
          'deadline': '300s total',
          'target': 'All (exhaustive)',
          'fullSubnet': true,
          'quiet': '30s',
          'earlyExit': false,
          'sample': 'Full (all hosts)',
        };
      case 'stealth':
        return {
          'concurrency': '3 probes',
          'timeout': '12s per probe',
          'deadline': '180s total',
          'target': '4 gateways',
          'fullSubnet': false,
          'quiet': '25s',
          'earlyExit': false,
          'sample': '64 per /24',
        };
      default:
        return {
          'concurrency': '16 probes',
          'timeout': '6s per probe',
          'deadline': '120s total',
          'target': '6 gateways',
          'fullSubnet': false,
          'quiet': '20s',
          'earlyExit': false,
          'sample': '140 per /24',
        };
    }
  }

  List<Color> _tintedGlassGradient(Color tint, {double highlight = 0.22, double lowlight = 0.06}) {
    return [
      tint.withValues(alpha: highlight.clamp(0.0, 1.0)),
      Colors.white.withValues(alpha: lowlight.clamp(0.0, 1.0)),
    ];
  }

  List<Color> _neutralGlassGradient({double highlight = 0.16, double lowlight = 0.05}) {
    return [
      Colors.white.withValues(alpha: highlight.clamp(0.0, 1.0)),
      Colors.white.withValues(alpha: lowlight.clamp(0.0, 1.0)),
    ];
  }
}
