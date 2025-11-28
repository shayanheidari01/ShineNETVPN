import 'package:shinenet_vpn/common/theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class VpnCard extends StatefulWidget {
  final int downloadSpeed;
  final int uploadSpeed;
  final String selectedServer;
  final String selectedServerType;
  final String duration;
  final int download;
  final int upload;

  const VpnCard({
    super.key,
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.download,
    required this.upload,
    required this.selectedServer,
    required this.selectedServerType,
    required this.duration,
  });

  @override
  State<VpnCard> createState() => _VpnCardState();
}

class _VpnCardState extends State<VpnCard> with TickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Improved Duration timer at the top
        _buildEnhancedTimerDisplay(),
        // Main content card
        AnimatedContainer(
          duration: ThemeColor.mediumAnimation,
          width: double.infinity,
          constraints: BoxConstraints(maxWidth: 400),
          padding: EdgeInsets.all(ThemeColor.largeSpacing),
          decoration: ThemeColor.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(ThemeColor.smallSpacing),
                    decoration: BoxDecoration(
                      color: ThemeColor.primaryColor.withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(ThemeColor.smallRadius),
                      border: Border.all(
                        color: ThemeColor.primaryColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: ThemeColor.buildServerIcon(
                      serverType: widget.selectedServerType,
                      size: 24,
                      isSelected: true,
                    ),
                  ),
                  SizedBox(width: ThemeColor.mediumSpacing),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.selectedServer,
                          style: ThemeColor.bodyStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: ThemeColor.primaryText,
                          ),
                        ),
                        SizedBox(height: ThemeColor.smallSpacing),
                        _buildIpDisplay(),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: ThemeColor.largeSpacing),
              Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      ThemeColor.dividerColor,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              SizedBox(height: ThemeColor.largeSpacing),
              Row(
                children: [
                  Expanded(
                    child: _buildStatColumn(
                      icon: Icons.speed_rounded,
                      download: formatBytes(widget.downloadSpeed),
                      upload: formatBytes(widget.uploadSpeed),
                      status: 'realtime_usage'.tr(),
                      color: ThemeColor.successColor,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 60,
                    color: ThemeColor.dividerColor,
                  ),
                  Expanded(
                    child: _buildStatColumn(
                      icon: Icons.data_usage_rounded,
                      download: formatSpeedBytes(widget.download),
                      upload: formatSpeedBytes(widget.upload),
                      status: 'total_usage'.tr(),
                      color: ThemeColor.primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Enhanced timer display with better visual design
  Widget _buildEnhancedTimerDisplay() {
    return Container(
      margin: EdgeInsets.only(bottom: ThemeColor.mediumSpacing),
      padding: EdgeInsets.symmetric(
        horizontal: ThemeColor.largeSpacing,
        vertical: ThemeColor.mediumSpacing,
      ),
      decoration: BoxDecoration(
        color: ThemeColor.cardColor,
        borderRadius: BorderRadius.circular(ThemeColor.xlRadius),
        border: Border.all(
          color: ThemeColor.primaryColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: ThemeColor.shadowColor.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Tooltip(
            message: 'connected_for'
                .tr()
                .replaceAll('{{duration}}', widget.duration),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: ThemeColor.primaryColor
                        .withValues(alpha: 0.1 + 0.1 * _pulseController.value),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.timer_rounded,
                    color: ThemeColor.primaryColor,
                    size: 20,
                  ),
                ),
                SizedBox(width: ThemeColor.mediumSpacing),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'connection_time'.tr(),
                      style: ThemeColor.captionStyle(
                        color: ThemeColor.secondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _formatDuration(widget.duration),
                      style: ThemeColor.headingStyle(
                        color: ThemeColor.primaryText,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Format duration for better readability
  String _formatDuration(String duration) {
    // If the duration is already in a good format, return it as is
    if (duration.contains(':') && duration.length >= 5) {
      // Handle HH:MM:SS format
      final parts = duration.split(':');
      if (parts.length == 3) {
        final hours = int.tryParse(parts[0]) ?? 0;
        final minutes = int.tryParse(parts[1]) ?? 0;
        // final seconds = int.tryParse(parts[2]) ?? 0;

        if (hours > 0) {
          return '${hours}h ${minutes}m';
        } else if (minutes > 0) {
          return '${minutes}m';
        } else {
          return '< 1m';
        }
      }
      return duration;
    }

    // Handle other formats (like seconds only)
    if (duration.contains('s') || duration.contains('sec')) {
      return duration;
    }

    // Try to parse as seconds
    try {
      final seconds = int.tryParse(duration) ?? 0;
      if (seconds >= 3600) {
        final hours = seconds ~/ 3600;
        final minutes = (seconds % 3600) ~/ 60;
        if (minutes > 0) {
          return '${hours}h ${minutes}m';
        } else {
          return '${hours}h';
        }
      } else if (seconds >= 60) {
        final minutes = seconds ~/ 60;
        return '${minutes}m';
      } else {
        return '${seconds}s';
      }
    } catch (e) {
      // If parsing fails, return the original duration
      print('Error formatting duration: $e');
    }

    // Return original duration if we can't format it better
    return duration;
  }

  String formatBytes(int bytes) {
    if (bytes <= 0) return '0Byte';

    const int kb = 1024;
    const int mb = kb * 1024;
    const int gb = mb * 1024;

    if (bytes < kb) return '$bytes Byte${bytes > 1 ? 's' : ''}';
    if (bytes < mb) return '${(bytes / kb).toStringAsFixed(2)}KB';
    if (bytes < gb) return '${(bytes / mb).toStringAsFixed(2)}MB';
    return '${(bytes / gb).toStringAsFixed(2)}GB';
  }

  String formatSpeedBytes(int bytes) {
    if (bytes <= 0) return '0byte/s';

    const int kb = 1024;
    const int mb = kb * 1024;
    const int gb = mb * 1024;

    if (bytes < kb) return '${bytes}byte/s';
    if (bytes < mb) return '${(bytes / kb).toStringAsFixed(2)}KB/s';
    if (bytes < gb) return '${(bytes / mb).toStringAsFixed(2)}MB/s';
    return '${(bytes / gb).toStringAsFixed(2)}GB/s';
  }

  Widget _buildIpDisplay() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ThemeColor.mediumSpacing,
        vertical: ThemeColor.smallSpacing,
      ),
      decoration: BoxDecoration(
        color: ThemeColor.surfaceColor,
        borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
        border: Border.all(
          color: ThemeColor.borderColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.language_rounded,
            color: ThemeColor.primaryColor,
            size: 16,
          ),
          SizedBox(width: ThemeColor.smallSpacing),
          Expanded(
            child: Text(
              'ip_lookup_disabled'.tr(),
              style: ThemeColor.captionStyle(
                color: ThemeColor.secondaryText,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn({
    required IconData icon,
    required String download,
    required String upload,
    required String status,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(ThemeColor.smallSpacing),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        SizedBox(height: ThemeColor.smallSpacing),
        Text(
          status,
          style: ThemeColor.captionStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.download_rounded,
              color: ThemeColor.successColor,
              size: 12,
            ),
            SizedBox(width: 4),
            Text(
              download,
              style: ThemeColor.captionStyle(
                color: ThemeColor.primaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.upload_rounded,
              color: ThemeColor.warningColor,
              size: 12,
            ),
            SizedBox(width: 4),
            Text(
              upload,
              style: ThemeColor.captionStyle(
                color: ThemeColor.primaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
