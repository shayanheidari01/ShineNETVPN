import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shinenet_vpn/common/theme.dart';
import 'package:shinenet_vpn/utils/server_location_parser.dart';

/// Simple server list widget with minimal UI
class SimpleServerListWidget extends StatefulWidget {
  final List<Map<String, dynamic>> servers;
  final String? selectedServer;
  final Function(String) onServerSelected;

  const SimpleServerListWidget({
    Key? key,
    required this.servers,
    this.selectedServer,
    required this.onServerSelected,
  }) : super(key: key);

  @override
  State<SimpleServerListWidget> createState() => _SimpleServerListWidgetState();
}

class _SimpleServerListWidgetState extends State<SimpleServerListWidget> {
  @override
  Widget build(BuildContext context) {
    if (widget.servers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.dns_rounded,
              size: 48,
              color: ThemeColor.mutedText,
            ),
            SizedBox(height: ThemeColor.mediumSpacing),
            Text(
              'no_servers_available'.tr(),
              style: ThemeColor.bodyStyle(color: ThemeColor.mutedText),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(ThemeColor.mediumSpacing),
      itemCount: widget.servers.length,
      itemBuilder: (context, index) {
        final server = widget.servers[index];
        return _buildServerCard(server);
      },
    );
  }

  Widget _buildServerCard(Map<String, dynamic> server) {
    final isSelected = widget.selectedServer == server['config'];
    final ping = server['ping'] as int? ?? -1;
    final serverConfig = server['config'] as String? ?? '';
    
    // Parse real location from server configuration
    final locationInfo = ServerLocationParser.parseServerLocation(serverConfig);
    final country = locationInfo['country']?.isNotEmpty == true 
        ? locationInfo['country']! 
        : (server['name'] ?? 'Unknown Server');
    final city = locationInfo['city'] ?? '';
    final flag = locationInfo['flag'] ?? '🏳️';
    
    return Container(
      margin: EdgeInsets.only(bottom: ThemeColor.smallSpacing),
      decoration: BoxDecoration(
        color: isSelected ? ThemeColor.primaryColor.withValues(alpha: 0.1) : ThemeColor.cardColor,
        borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
        border: Border.all(
          color: isSelected ? ThemeColor.primaryColor : ThemeColor.borderColor,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
          onTap: () => widget.onServerSelected(server['config']),
          child: Padding(
            padding: EdgeInsets.all(ThemeColor.mediumSpacing),
            child: Row(
              children: [
                // Country flag
                Container(
                  width: 32,
                  height: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: ThemeColor.borderColor, width: 0.5),
                  ),
                  child: Center(
                    child: Text(
                      flag,
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                
                SizedBox(width: ThemeColor.mediumSpacing),
                
                // Server info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        city.isNotEmpty ? '$city, $country' : country,
                        style: ThemeColor.bodyStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (server['ip'] != null && server['ip'].isNotEmpty)
                        Text(
                          server['ip'],
                          style: ThemeColor.captionStyle(fontSize: 12),
                        ),
                    ],
                  ),
                ),
                
                // Ping indicator - always show
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getPingColor(ping).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getPingColor(ping),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    ping > 0 ? (ping >= 9999 ? 'timeout'.tr() : '${ping}ms') : 'not_available_short'.tr(),
                    style: TextStyle(
                      color: _getPingColor(ping),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(width: ThemeColor.smallSpacing),
                
                // Selection indicator
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? ThemeColor.primaryColor : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? ThemeColor.primaryColor : ThemeColor.borderColor,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 12,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getPingColor(int ping) {
    if (ping <= 0) return ThemeColor.errorColor; // Failed/Error
    if (ping >= 9999) return Colors.orange; // Timeout
    if (ping < 100) return ThemeColor.successColor; // Excellent
    if (ping < 300) return ThemeColor.warningColor; // Good
    return ThemeColor.errorColor; // Poor
  }

}
