import 'package:shinenet_vpn/common/theme.dart';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

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

class _VpnCardState extends State<VpnCard> {
  String? ipText;
  String? ipflag;
  bool isLoading = false;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Duration timer at the top
        Container(
          margin: EdgeInsets.only(bottom: ThemeColor.mediumSpacing),
          padding: EdgeInsets.symmetric(
            horizontal: ThemeColor.mediumSpacing,
            vertical: ThemeColor.smallSpacing,
          ),
          decoration: BoxDecoration(
            gradient: ThemeColor.primaryGradient,
            borderRadius: BorderRadius.circular(ThemeColor.largeRadius),
            boxShadow: [
              BoxShadow(
                color: ThemeColor.primaryColor.withOpacity(0.3),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.access_time_rounded,
                color: Colors.white,
                size: 16,
              ),
              SizedBox(width: ThemeColor.smallSpacing),
              Text(
                widget.duration,
                style: ThemeColor.bodyStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
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
                      color: ThemeColor.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
                      border: Border.all(
                        color: ThemeColor.primaryColor.withOpacity(0.3),
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
                        _buildIpButton(),
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
                      status: context.tr('realtime_usage'),
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
                      status: context.tr('total_usage'),
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

  Widget _buildIpButton() {
    return Container(
      decoration: BoxDecoration(
        color: ThemeColor.surfaceColor,
        borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
        border: Border.all(
          color: ThemeColor.borderColor.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: ThemeColor.shadowColor.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
          onTap: () async {
            HapticFeedback.lightImpact();
            setState(() => isLoading = true);
            try {
              final ipInfo = await getIpApi();
              setState(() {
                ipflag = countryCodeToFlagEmoji(ipInfo['countryCode']!);
                ipText = ipInfo['ip'];
                isLoading = false;
              });
            } catch (e) {
              setState(() {
                isLoading = false;
              });
            }
          },
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: ThemeColor.mediumSpacing,
              vertical: ThemeColor.smallSpacing,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  LoadingAnimationWidget.threeArchedCircle(
                    color: ThemeColor.primaryColor,
                    size: 16,
                  )
                else ...[
                  Icon(
                    ipText != null ? Icons.language_rounded : Icons.visibility_rounded,
                    color: ThemeColor.primaryColor,
                    size: 16,
                  ),
                  SizedBox(width: ThemeColor.smallSpacing),
                  Text(
                    ipText ?? context.tr('show_ip'),
                    style: ThemeColor.captionStyle(
                      color: ThemeColor.secondaryText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (ipflag != null) ...[
                    SizedBox(width: ThemeColor.smallSpacing),
                    Text(
                      ipflag!,
                      style: TextStyle(
                        fontSize: 16,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
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

String countryCodeToFlagEmoji(String countryCode) {
  countryCode = countryCode.toUpperCase();
  final flag = countryCode.codeUnits
      .map((codeUnit) => String.fromCharCode(0x1F1E6 + codeUnit - 0x41))
      .join();

  return Text(
        flag,
        style: const TextStyle(
          fontSize: 16,
        ),
      ).data ??
      flag;
}

Future<Map<String, String>> getIpApi() async {
  try {
    final dio = Dio();

    final response = await dio.get(
      'https://freeipapi.com/api/json',
      options: Options(
        headers: {
          'X-Content-Type-Options': 'nosniff',
        },
      ),
    );

    if (response.statusCode == 200) {
      final data = response.data;
      if (data != null && data is Map) {
        String ip = data['ipAddress'] ?? 'Unknown IP';

        if (ip.contains('.')) {
          // IPv4
          final parts = ip.split('.');
          if (parts.length == 4) {
            ip = '${parts[0]}.*.*.${parts[3]}';
          }
        } else if (ip.contains(':')) {
          // IPv6
          final parts = ip.split(':');
          if (parts.length > 4) {
            ip = '${parts[0]}:${parts[1]}:****:${parts.last}';
          }
        }

        return {'countryCode': data['countryCode'] ?? 'Unknown', 'ip': ip};
      }
    }

    return {'countryCode': 'Unknown', 'ip': 'Unknown IP'};
  } catch (e) {
    print('Error getting IP info: $e');
    return {'countryCode': 'Error', 'ip': 'Error'};
  }
}
