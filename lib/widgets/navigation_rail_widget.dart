import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_v2ray_client/flutter_v2ray.dart';
import 'package:iconsax/iconsax.dart';
import 'dart:math';
import 'package:shinenet_vpn/common/theme.dart';

class NavigationRailWidget extends StatefulWidget {
  final int selectedIndex;
  final ValueNotifier<V2RayStatus> singStatus;
  final Function(int) onDestinationSelected;

  NavigationRailWidget({
    Key? key,
    required this.selectedIndex,
    required this.singStatus,
    required this.onDestinationSelected,
  }) : super(key: key);

  @override
  State<NavigationRailWidget> createState() => _NavigationRailWidgetState();
}

class _NavigationRailWidgetState extends State<NavigationRailWidget> {

  String formatBytes(int bytes) {
    if (bytes <= 0) return '0B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(2)}${suffixes[i]}';
  }

  String formatSpeedBytes(int bytes) {
    if (bytes <= 0) return '0B/s';
    const suffixes = ['B/s', 'KB/s', 'MB/s', 'GB/s'];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(2)}${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isExtraWideScreen = size.width > 1200;

    return Container(
      width: isExtraWideScreen ? 200 : 88,
      decoration: BoxDecoration(
        color: ThemeColor.surfaceColor,
        border: Border(
          right: BorderSide(
            color: ThemeColor.borderColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 50),
            // App title without icon
            if (isExtraWideScreen)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ThemeColor.mediumSpacing,
                  vertical: ThemeColor.smallSpacing,
                ),
                decoration: BoxDecoration(
                  color: ThemeColor.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
                  border: Border.all(
                    color: ThemeColor.primaryColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  'app_title'.tr(),
                  style: ThemeColor.bodyStyle(
                    fontWeight: FontWeight.w600,
                    color: ThemeColor.primaryText,
                  ),
                ),
              ),
          const Spacer(),
          _buildNavItems(isExtraWideScreen),
          const SizedBox(height: 16),
          // Connection status indicator
          _buildConnectionStatus(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildNavItems(bool isExtraWideScreen) {
    return Column(
      children: [
        _buildNavItem(
          Iconsax.setting_2,
          'settings'.tr(),
          0,
          isExtraWideScreen,
        ),
        _buildNavItem(
          Iconsax.home_2,
          'home'.tr(),
          1,
          isExtraWideScreen,
        ),
        _buildNavItem(
          Iconsax.info_circle,
          'about'.tr(),
          2,
          isExtraWideScreen,
        ),
      ],
    );
  }

  Widget _buildNavItem(
    IconData? icon,
    String label,
    int index,
    bool showLabel,
  ) {
    final isSelected = widget.selectedIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onDestinationSelected(index);
          },
          borderRadius: BorderRadius.circular(ThemeColor.largeRadius),
          child: AnimatedContainer(
            duration: ThemeColor.mediumAnimation,
            curve: Curves.easeInOut,
            width: showLabel ? 180 : 70,
            padding: EdgeInsets.symmetric(
              vertical: showLabel ? 16 : 12,
              horizontal: showLabel ? 20 : 16,
            ),
            decoration: BoxDecoration(
              gradient: isSelected 
                  ? LinearGradient(
                      colors: [
                        ThemeColor.primaryColor.withValues(alpha: 0.2),
                        ThemeColor.primaryColor.withValues(alpha: 0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isSelected 
                  ? null
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(ThemeColor.largeRadius),
              border: isSelected 
                  ? Border.all(
                      color: ThemeColor.primaryColor.withValues(alpha: 0.4),
                      width: 1.5,
                    )
                  : Border.all(
                      color: ThemeColor.borderColor.withValues(alpha: 0.2),
                      width: 1,
                    ),
              boxShadow: isSelected 
                  ? [
                      BoxShadow(
                        color: ThemeColor.primaryColor.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: showLabel 
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(
                          icon,
                          color: isSelected 
                              ? ThemeColor.primaryColor 
                              : ThemeColor.mutedText,
                          size: 20,
                        ),
                        SizedBox(width: ThemeColor.smallSpacing),
                      ],
                      Flexible(
                        child: AnimatedDefaultTextStyle(
                          duration: ThemeColor.mediumAnimation,
                          style: ThemeColor.bodyStyle(
                            color: isSelected 
                                ? ThemeColor.primaryColor 
                                : ThemeColor.mutedText,
                            fontWeight: isSelected 
                                ? FontWeight.w700 
                                : FontWeight.w500,
                            fontSize: 14,
                          ),
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Icon(
                      icon ?? Icons.circle,
                      color: isSelected 
                          ? ThemeColor.primaryColor 
                          : ThemeColor.mutedText,
                      size: 24,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // Add connection status indicator
  Widget _buildConnectionStatus() {
    return ValueListenableBuilder<V2RayStatus>(
      valueListenable: widget.singStatus,
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

        return Container(
          margin: EdgeInsets.symmetric(horizontal: 16),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedRotation(
                turns: isConnecting ? 1 : 0,
                duration: Duration(seconds: 1),
                child: Icon(
                  statusIcon,
                  color: statusColor,
                  size: 16,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusText,
                  style: ThemeColor.captionStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
