import 'package:shinenet_vpn/common/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';

class ServerInfo {
  final String name;
  final String config;
  final String? ip;
  final String? countryCode;
  final int? ping;
  
  ServerInfo({
    required this.name,
    required this.config,
    this.ip,
    this.countryCode,
    this.ping,
  });
}

class ServerSelectionModal extends StatefulWidget {
  final String selectedServer;
  final Function(String) onServerSelected;
  final List<ServerInfo> healthyServers;

  ServerSelectionModal({
    required this.selectedServer, 
    required this.onServerSelected,
    this.healthyServers = const [],
  });

  @override
  _ServerSelectionModalState createState() => _ServerSelectionModalState();
}

class _ServerSelectionModalState extends State<ServerSelectionModal>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late List<AnimationController> _itemControllers;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: ThemeColor.mediumAnimation,
      vsync: this,
    );
    
    _itemControllers = List.generate(
      3 + widget.healthyServers.length,
      (index) => AnimationController(
        duration: Duration(milliseconds: 300 + (index * 100)),
        vsync: this,
      ),
    );
    
    _animationController.forward();
    
    // Stagger the item animations
    for (int i = 0; i < _itemControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 100), () {
        if (mounted) {
          _itemControllers[i].forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    for (var controller in _itemControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: ThemeColor.backgroundColor,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ThemeColor.xlRadius),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Modern handle bar with gradient
          Container(
            margin: EdgeInsets.only(top: ThemeColor.smallSpacing),
            width: 50,
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ThemeColor.primaryColor.withValues(alpha: 0.3),
                  ThemeColor.secondaryColor.withValues(alpha: 0.3),
                ],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header with gradient background
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(ThemeColor.largeSpacing),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ThemeColor.primaryColor.withValues(alpha: 0.05),
                  ThemeColor.secondaryColor.withValues(alpha: 0.02),
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(ThemeColor.mediumSpacing),
                  decoration: BoxDecoration(
                    gradient: ThemeColor.primaryGradient,
                    borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
                    boxShadow: [
                      BoxShadow(
                        color: ThemeColor.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.dns_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                SizedBox(width: ThemeColor.largeSpacing),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'select_server_title'.tr(),
                        style: ThemeColor.headingStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'choose_server_location'.tr(),
                        style: ThemeColor.captionStyle(
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(ThemeColor.largeSpacing),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Automatic server option
                  _buildModernServerCard(
                    title: 'automatic'.tr(),
                    subtitle: 'best_server_auto'.tr(),
                    icon: Icons.auto_awesome_rounded,
                    serverType: 'server_automatic'.tr(),
                    isSelected: widget.selectedServer == 'server_automatic'.tr(),
                    onTap: () => _selectServer(context, 'server_automatic'.tr()),
                  ),
                  
                  // Healthy servers section
                  if (widget.healthyServers.isNotEmpty) ...[
                    SizedBox(height: ThemeColor.largeSpacing),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ThemeColor.mediumSpacing,
                        vertical: ThemeColor.smallSpacing,
                      ),
                      decoration: BoxDecoration(
                        color: ThemeColor.surfaceColor,
                        borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
                        border: Border.all(
                          color: ThemeColor.borderColor,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.health_and_safety_rounded,
                            color: ThemeColor.successColor,
                            size: 20,
                          ),
                          SizedBox(width: ThemeColor.smallSpacing),
                          Text(
                            'healthy_servers'.tr(),
                            style: ThemeColor.bodyStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: ThemeColor.successColor,
                            ),
                          ),
                          Spacer(),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: ThemeColor.smallSpacing,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: ThemeColor.successColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${widget.healthyServers.length}',
                              style: ThemeColor.captionStyle(
                                fontSize: 12,
                                color: ThemeColor.successColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: ThemeColor.mediumSpacing),
                    ...widget.healthyServers.map((server) => 
                      Padding(
                        padding: EdgeInsets.only(bottom: ThemeColor.mediumSpacing),
                        child: _buildHealthyServerCard(server),
                      ),
                    ).toList(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Modern server card with enhanced design
  Widget _buildModernServerCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String serverType,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: ThemeColor.mediumAnimation,
      decoration: BoxDecoration(
        gradient: isSelected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ThemeColor.primaryColor.withValues(alpha: 0.1),
                  ThemeColor.secondaryColor.withValues(alpha: 0.05),
                ],
              )
            : null,
        borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
        border: Border.all(
          color: isSelected
              ? ThemeColor.primaryColor
              : ThemeColor.borderColor,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: ThemeColor.primaryColor.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: EdgeInsets.all(ThemeColor.largeSpacing),
            child: Row(
              children: [
                // Icon container
                Container(
                  padding: EdgeInsets.all(ThemeColor.mediumSpacing),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? ThemeColor.primaryGradient
                        : LinearGradient(
                            colors: [
                              ThemeColor.surfaceColor,
                              ThemeColor.surfaceColor.withValues(alpha: 0.8),
                            ],
                          ),
                    borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: ThemeColor.primaryColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : ThemeColor.primaryColor,
                    size: 24,
                  ),
                ),
                SizedBox(width: ThemeColor.largeSpacing),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: ThemeColor.bodyStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isSelected 
                                    ? ThemeColor.primaryColor
                                    : ThemeColor.primaryText,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: ThemeColor.smallSpacing,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                gradient: ThemeColor.primaryGradient,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: ThemeColor.primaryColor.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                'active'.tr(),
                                style: ThemeColor.captionStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: ThemeColor.captionStyle(
                          fontSize: 14,
                          color: isSelected
                              ? ThemeColor.primaryColor.withValues(alpha: 0.8)
                              : ThemeColor.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Selection indicator
                AnimatedContainer(
                  duration: ThemeColor.fastAnimation,
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? ThemeColor.primaryColor
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? ThemeColor.primaryColor
                          : ThemeColor.borderColor,
                      width: 2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: ThemeColor.primaryColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    color: isSelected ? Colors.white : Colors.transparent,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  void _selectServer(BuildContext context, String server) {
    HapticFeedback.lightImpact();
    widget.onServerSelected(server);
  }
  
  String _countryCodeToFlagEmoji(String countryCode) {
    if (countryCode.isEmpty) return '🏳️';
    
    try {
      // Validate country code format
      if (countryCode.length != 2) return '🏳️';
      
      // Convert to uppercase
      countryCode = countryCode.toUpperCase();
      
      // Check if it's a valid ISO 3166-1 alpha-2 code
      final validLetters = RegExp(r'^[A-Z]{2}$');
      if (!validLetters.hasMatch(countryCode)) return '🏳️';
      
      // Convert to flag emoji
      final flag = countryCode.codeUnits
          .map((codeUnit) => String.fromCharCode(0x1F1E6 + codeUnit - 0x41))
          .join();
      return flag;
    } catch (e) {
      print('Error converting country code to flag emoji: $e');
      return '🏳️';
    }
  }
  
  // Enhanced healthy server card
  Widget _buildHealthyServerCard(ServerInfo server) {
    final isSelected = widget.selectedServer == server.config;
    final pingColor = server.ping != null
        ? (server.ping! < 100
            ? ThemeColor.successColor
            : server.ping! < 300
                ? ThemeColor.warningColor
                : ThemeColor.errorColor)
        : ThemeColor.mutedText;
    
    return AnimatedContainer(
      duration: ThemeColor.mediumAnimation,
      decoration: BoxDecoration(
        gradient: isSelected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ThemeColor.primaryColor.withValues(alpha: 0.1),
                  ThemeColor.secondaryColor.withValues(alpha: 0.05),
                ],
              )
            : null,
        borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
        border: Border.all(
          color: isSelected
              ? ThemeColor.primaryColor
              : ThemeColor.borderColor,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: ThemeColor.primaryColor.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onServerSelected(server.config);
          },
          child: Padding(
            padding: EdgeInsets.all(ThemeColor.largeSpacing),
            child: Row(
              children: [
                // Server icon container
                Container(
                  padding: EdgeInsets.all(ThemeColor.mediumSpacing),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? ThemeColor.primaryGradient
                        : LinearGradient(
                            colors: [
                              ThemeColor.surfaceColor,
                              ThemeColor.surfaceColor.withValues(alpha: 0.8),
                            ],
                          ),
                    borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: ThemeColor.primaryColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    Icons.dns_rounded,
                    color: isSelected ? Colors.white : ThemeColor.primaryColor,
                    size: 24,
                  ),
                ),
                SizedBox(width: ThemeColor.largeSpacing),
                
                // Server info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              server.name,
                              style: ThemeColor.bodyStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? ThemeColor.primaryColor
                                    : ThemeColor.primaryText,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: ThemeColor.smallSpacing,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                gradient: ThemeColor.primaryGradient,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: ThemeColor.primaryColor.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                'active'.tr(),
                                style: ThemeColor.captionStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.speed_rounded,
                            size: 16,
                            color: pingColor,
                          ),
                          SizedBox(width: 4),
                          Text(
                            server.ping != null ? '${server.ping}ms' : 'not_available'.tr(),
                            style: ThemeColor.captionStyle(
                              fontSize: 14,
                              color: pingColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: pingColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 4),
                          Text(
                            _getPingStatus(server.ping),
                            style: ThemeColor.captionStyle(
                              fontSize: 12,
                              color: pingColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Selection indicator
                AnimatedContainer(
                  duration: ThemeColor.fastAnimation,
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? ThemeColor.primaryColor
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? ThemeColor.primaryColor
                          : ThemeColor.borderColor,
                      width: 2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: ThemeColor.primaryColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    color: isSelected ? Colors.white : Colors.transparent,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  String _getPingStatus(int? ping) {
    if (ping == null) return 'ping_unknown'.tr();
    if (ping < 100) return 'ping_excellent'.tr();
    if (ping < 300) return 'ping_good'.tr();
    return 'ping_slow'.tr();
  }
}