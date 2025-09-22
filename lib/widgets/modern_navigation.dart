import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shinenet_vpn/common/theme.dart';
import 'package:flutter_v2ray_client/flutter_v2ray.dart';

class ModernNavigation extends StatefulWidget {
  final int selectedIndex;
  final ValueNotifier<V2RayStatus> v2rayStatus;
  final Function(int) onDestinationSelected;
  final bool isWideScreen;

  const ModernNavigation({
    super.key,
    required this.selectedIndex,
    required this.v2rayStatus,
    required this.onDestinationSelected,
    required this.isWideScreen,
  });

  @override
  State<ModernNavigation> createState() => _ModernNavigationState();
}

class _ModernNavigationState extends State<ModernNavigation>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isWideScreen) {
      return _buildDesktopNavigation();
    } else {
      return _buildMobileNavigation();
    }
  }

  Widget _buildDesktopNavigation() {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: ThemeColor.surfaceColor,
        border: Border(
          right: BorderSide(
            color: ThemeColor.borderColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: ThemeColor.shadowColor.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 40),
          _buildAppHeader(),
          const SizedBox(height: 40),
          Expanded(
            child: _buildNavigationItems(),
          ),
          const SizedBox(height: 20),
          _buildConnectionStatus(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMobileNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: ThemeColor.surfaceColor,
        border: Border(
          top: BorderSide(
            color: ThemeColor.borderColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: ThemeColor.shadowColor.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _buildMobileNavigationItems(),
          ),
        ),
      ),
    );
  }

  Widget _buildAppHeader() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ThemeColor.primaryColor.withValues(alpha: 0.1),
                  ThemeColor.primaryColor.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(ThemeColor.largeRadius),
              border: Border.all(
                color: ThemeColor.primaryColor.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ThemeColor.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
                  ),
                  child: Icon(
                    Icons.vpn_lock_rounded,
                    color: ThemeColor.primaryColor,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'app_title'.tr(),
                  style: ThemeColor.headingStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: ThemeColor.primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'secure_vpn'.tr(),
                  style: ThemeColor.captionStyle(
                    color: ThemeColor.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<_NavigationItem> _getNavigationItems() {
    return [
      _NavigationItem(
        icon: Iconsax.setting_2,
        label: 'settings'.tr(),
        index: 0,
      ),
      _NavigationItem(
        icon: Iconsax.home_2,
        label: 'home'.tr(),
        index: 1,
      ),
      _NavigationItem(
        icon: Iconsax.info_circle,
        label: 'about'.tr(),
        index: 2,
      ),
    ];
  }

  Widget _buildNavigationItems() {
    final navItems = _getNavigationItems();
    return Column(
      children: navItems.map((item) => _buildNavigationItem(item)).toList(),
    );
  }

  Widget _buildNavigationItem(_NavigationItem item) {
    final isSelected = widget.selectedIndex == item.index;
    
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isSelected ? _scaleAnimation.value : 1.0,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onDestinationSelected(item.index);
                },
                borderRadius: BorderRadius.circular(ThemeColor.largeRadius),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [
                              ThemeColor.primaryColor.withValues(alpha: 0.15),
                              ThemeColor.primaryColor.withValues(alpha: 0.08),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isSelected ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(ThemeColor.largeRadius),
                    border: isSelected
                        ? Border.all(
                            color: ThemeColor.primaryColor.withValues(alpha: 0.3),
                            width: 1.5,
                          )
                        : Border.all(
                            color: ThemeColor.borderColor.withValues(alpha: 0.1),
                            width: 1,
                          ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: ThemeColor.primaryColor.withValues(alpha: 0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? ThemeColor.primaryColor.withValues(alpha: 0.2)
                              : ThemeColor.surfaceColor.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
                        ),
                        child: Icon(
                          item.icon,
                          color: isSelected
                              ? ThemeColor.primaryColor
                              : ThemeColor.mutedText,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          item.label,
                          style: ThemeColor.bodyStyle(
                            color: isSelected
                                ? ThemeColor.primaryColor
                                : ThemeColor.mutedText,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: ThemeColor.primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildMobileNavigationItems() {
    final navItems = _getNavigationItems();
    return navItems.map((item) => _buildMobileNavigationItem(item)).toList();
  }

  Widget _buildMobileNavigationItem(_NavigationItem item) {
    final isSelected = widget.selectedIndex == item.index;

    return Expanded(
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: isSelected ? _scaleAnimation.value : 1.0,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onDestinationSelected(item.index);
                },
                borderRadius: BorderRadius.circular(ThemeColor.largeRadius),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [
                              ThemeColor.primaryColor.withValues(alpha: 0.15),
                              ThemeColor.primaryColor.withValues(alpha: 0.08),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isSelected ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(ThemeColor.largeRadius),
                    border: isSelected
                        ? Border.all(
                            color: ThemeColor.primaryColor.withValues(alpha: 0.3),
                            width: 1.5,
                          )
                        : Border.all(
                            color: ThemeColor.borderColor.withValues(alpha: 0.1),
                            width: 1,
                          ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: ThemeColor.primaryColor.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? ThemeColor.primaryColor.withValues(alpha: 0.2)
                              : ThemeColor.surfaceColor.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
                        ),
                        child: Icon(
                          item.icon,
                          color: isSelected
                              ? ThemeColor.primaryColor
                              : ThemeColor.mutedText,
                          size: 18,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.label,
                        style: ThemeColor.captionStyle(
                          color: isSelected
                              ? ThemeColor.primaryColor
                              : ThemeColor.mutedText,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return ValueListenableBuilder<V2RayStatus>(
      valueListenable: widget.v2rayStatus,
      builder: (context, status, _) {
        final normalized = status.state.toUpperCase();
        final isConnected = normalized == 'CONNECTED';
        final isConnecting = normalized == 'CONNECTING';

        Color statusColor;
        IconData statusIcon;
        String statusText;

        if (isConnected) {
          statusColor = ThemeColor.successColor;
          statusIcon = Icons.check_circle_rounded;
          statusText = 'connected'.tr();
        } else if (isConnecting) {
          statusColor = ThemeColor.warningColor;
          statusIcon = Icons.sync_rounded;
          statusText = 'connecting'.tr();
        } else {
          statusColor = ThemeColor.mutedText;
          statusIcon = Icons.radio_button_unchecked_rounded;
          statusText = 'disconnected'.tr();
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(ThemeColor.largeRadius),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              AnimatedRotation(
                turns: isConnecting ? 1 : 0,
                duration: const Duration(seconds: 1),
                child: Icon(
                  statusIcon,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'status'.tr(),
                      style: ThemeColor.captionStyle(
                        color: statusColor.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      statusText,
                      style: ThemeColor.bodyStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NavigationItem {
  final IconData icon;
  final String label;
  final int index;

  _NavigationItem({
    required this.icon,
    required this.label,
    required this.index,
  });
}
