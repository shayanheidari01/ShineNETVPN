import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shinenet_vpn/common/theme.dart';
import 'package:easy_localization/easy_localization.dart';

class StatisticsCard extends StatefulWidget {
  final int downloadSpeed;
  final int uploadSpeed;
  final int download;
  final int upload;
  final String duration;
  final bool isConnected;

  const StatisticsCard({
    super.key,
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.download,
    required this.upload,
    required this.duration,
    required this.isConnected,
  });

  @override
  State<StatisticsCard> createState() => _StatisticsCardState();
}

class _StatisticsCardState extends State<StatisticsCard>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat();

    _slideController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    if (widget.isConnected) {
      _slideController.forward();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(StatisticsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isConnected != widget.isConnected) {
      if (widget.isConnected) {
        _slideController.forward();
      } else {
        _slideController.reverse();
      }
    }
  }

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
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _slideAnimation.value,
          child: Opacity(
            opacity: _slideAnimation.value,
            child: Container(
              decoration: ThemeColor.cardDecoration(
                withShadow: true,
                withGradient: widget.isConnected,
              ),
              child: Padding(
                padding: EdgeInsets.all(ThemeColor.largeSpacing),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with connection status
                    Row(
                      children: [
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: widget.isConnected
                                    ? ThemeColor.successColor.withValues(
                                        alpha: 0.1 + 0.1 * _pulseController.value)
                                    : ThemeColor.mutedText.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
                                border: Border.all(
                                  color: widget.isConnected
                                      ? ThemeColor.successColor.withValues(alpha: 0.3)
                                      : ThemeColor.mutedText.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                widget.isConnected
                                    ? Icons.trending_up_rounded
                                    : Icons.trending_flat_rounded,
                                color: widget.isConnected
                                    ? ThemeColor.successColor
                                    : ThemeColor.mutedText,
                                size: 20,
                              ),
                            );
                          },
                        ),
                        SizedBox(width: ThemeColor.mediumSpacing),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'connection_statistics'.tr(),
                                style: ThemeColor.bodyStyle(
                                  fontWeight: FontWeight.w600,
                                  color: ThemeColor.primaryText,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                widget.isConnected
                                    ? 'active_monitoring'.tr()
                                    : 'inactive_monitoring'.tr(),
                                style: ThemeColor.captionStyle(
                                  color: ThemeColor.mutedText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ThemeColor.largeSpacing),
                    
                    // Statistics grid
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatItem(
                            icon: Icons.download_rounded,
                            label: 'download_speed'.tr(),
                            value: formatSpeedBytes(widget.downloadSpeed),
                            color: ThemeColor.successColor,
                          ),
                        ),
                        SizedBox(width: ThemeColor.mediumSpacing),
                        Expanded(
                          child: _buildStatItem(
                            icon: Icons.upload_rounded,
                            label: 'upload_speed'.tr(),
                            value: formatSpeedBytes(widget.uploadSpeed),
                            color: ThemeColor.warningColor,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ThemeColor.mediumSpacing),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatItem(
                            icon: Icons.data_usage_rounded,
                            label: 'total_download'.tr(),
                            value: formatBytes(widget.download),
                            color: ThemeColor.primaryColor,
                          ),
                        ),
                        SizedBox(width: ThemeColor.mediumSpacing),
                        Expanded(
                          child: _buildStatItem(
                            icon: Icons.cloud_upload_rounded,
                            label: 'total_upload'.tr(),
                            value: formatBytes(widget.upload),
                            color: ThemeColor.secondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(ThemeColor.mediumSpacing),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
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
          SizedBox(height: ThemeColor.smallSpacing),
          Text(
            value,
            style: ThemeColor.bodyStyle(
              fontWeight: FontWeight.w700,
              color: color,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          Text(
            label,
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
}
