import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shinenet_vpn/common/theme.dart';
import 'package:shinenet_vpn/common/font_helper.dart';

/// Optimized server list widget with enhanced performance and UI
class SimpleServerListWidget extends StatefulWidget {
  final List<Map<String, dynamic>> servers;
  final String? selectedServer;
  final Function(String) onServerSelected;
  final bool showPing;
  final bool showCountryFlags;
  final bool allowRefresh;
  final VoidCallback? onRefresh;

  const SimpleServerListWidget({
    Key? key,
    required this.servers,
    this.selectedServer,
    required this.onServerSelected,
    this.showPing = true,
    this.showCountryFlags = true,
    this.allowRefresh = true,
    this.onRefresh,
  }) : super(key: key);

  @override
  State<SimpleServerListWidget> createState() => _SimpleServerListWidgetState();
}

class _SimpleServerListWidgetState extends State<SimpleServerListWidget>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.servers.isEmpty) {
      return _buildEmptyState();
    }

    final list = ListView.builder(
      padding: EdgeInsets.all(ThemeColor.mediumSpacing),
      itemCount: widget.servers.length,
      itemBuilder: (context, index) {
        final server = widget.servers[index];
        return _buildOptimizedServerCard(server, index);
      },
    );

    // Enable pull-to-refresh when allowed and callback provided
    if (widget.allowRefresh && widget.onRefresh != null) {
      return RefreshIndicator(
        onRefresh: () async {
          widget.onRefresh!.call();
        },
        child: list,
      );
    }

    return list;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.dns_rounded,
            size: 64,
            color: ThemeColor.mutedText,
          ),
          SizedBox(height: ThemeColor.mediumSpacing),
          Text(
            'no_servers_available'.tr(),
            style: FontHelper.getBodyStyle(
              fontSize: 16,
              color: ThemeColor.mutedText,
              context: context,
            ),
          ),
          if (widget.allowRefresh && widget.onRefresh != null) ...[
            SizedBox(height: ThemeColor.mediumSpacing),
            ElevatedButton.icon(
              onPressed: widget.onRefresh,
              icon: Icon(Icons.refresh_rounded),
              label: Text('refresh_servers'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeColor.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Simplified server card with clean design
  Widget _buildOptimizedServerCard(Map<String, dynamic> server, int index) {
    final isSelected = widget.selectedServer == server['config'];
    final ping = server['ping'] as int? ?? -1;
    final serverConfig = server['config'] as String? ?? '';
    final isTestingPing = server['isTestingPing'] as bool? ?? false;
    final name = server['name'] as String? ?? 'Unknown Server';
    final location = server['location'] as String? ?? name;

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? ThemeColor.primaryColor.withValues(alpha: 0.1)
            : ThemeColor.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? ThemeColor.primaryColor : ThemeColor.borderColor.withValues(alpha: 0.3),
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: _buildSimpleServerIcon(isSelected),
        title: Text(
          location,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: isSelected
                ? ThemeColor.primaryColor
                : ThemeColor.primaryText,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // Keep UI minimal: no subtitle
        subtitle: null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Minimal: only compact ping indicator
            if (widget.showPing) _buildCompactPingIndicator(ping, isTestingPing),
            SizedBox(width: 12),
            // Selection indicator
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? ThemeColor.primaryColor : ThemeColor.mutedText,
              size: 22,
            ),
          ],
        ),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onServerSelected(server['config']);
        },
      ),
    );
  }

  Widget _buildSimpleServerIcon(bool isSelected) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isSelected
            ? ThemeColor.primaryColor
            : ThemeColor.surfaceColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.dns_rounded,
        color: isSelected ? Colors.white : ThemeColor.primaryColor,
        size: 18,
      ),
    );
  }

  Widget _buildServerSubtitle(Map<String, dynamic> server) {
    final serverConfig = server['config'] as String? ?? '';
    final isAutomatic = serverConfig == 'Automatic';
    final ping = server['ping'] as int? ?? -1;
    final isTestingPing = server['isTestingPing'] as bool? ?? false;
    final ip = '';

    if (isAutomatic) {
      return Text(
        'best_server_automatically_selected'.tr(),
        style: FontHelper.getCaptionStyle(
          fontSize: 12,
          color: ThemeColor.mutedText,
          context: context,
        ),
      );
    }

    // Build subtitle with server info and ping status
    final serverName = server['name'] as String? ?? 'Unknown Server';
    String pingStatus = '';
    Color pingStatusColor = ThemeColor.mutedText;
    
    
    if (isTestingPing) {
      pingStatus = ' • ${'ping_testing_status'.tr()}';
      pingStatusColor = ThemeColor.primaryColor;
    } else if (ping == 0) {
      pingStatus = ' • ${'ping_ready_test'.tr()}';
      pingStatusColor = ThemeColor.mutedText;
    } else if (ping < 0) {
      pingStatus = ' • -1ms';
      pingStatusColor = ThemeColor.errorColor;
    } else if (ping >= 9999) {
      pingStatus = ' • ${'ping_slow_connection'.tr()}';
      pingStatusColor = Colors.orange;
    } else if (ping < 200) {
      pingStatus = ' • ${'ping_excellent_ms'.tr(namedArgs: {'ping': ping.toString()})}';
      pingStatusColor = ThemeColor.successColor; // سبز برای زیر 200ms
    } else if (ping < 400) {
      pingStatus = ' • ${'ping_good_ms'.tr(namedArgs: {'ping': ping.toString()})}';
      pingStatusColor = ThemeColor.warningColor; // زرد برای 200-400ms
    } else {
      pingStatus = ' • ${'ping_poor_ms'.tr(namedArgs: {'ping': ping.toString()})}';
      pingStatusColor = ThemeColor.errorColor; // قرمز برای بالای 400ms
    }

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: serverName,
            style: FontHelper.getCaptionStyle(
              fontSize: 12,
              color: ThemeColor.mutedText,
              context: context,
            ),
          ),
          TextSpan(
            text: pingStatus,
            style: FontHelper.getCaptionStyle(
              fontSize: 11,
              color: pingStatusColor,
              fontWeight: FontWeight.w600,
              context: context,
            ),
          ),
          // IP hidden for simpler UI
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildConnectionStatusDot(int ping, bool isTestingPing) {
    Color dotColor;
    
    if (isTestingPing) {
      // Animated dot during testing
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: ThemeColor.primaryColor,
          shape: BoxShape.circle,
        ),
        child: CircularProgressIndicator(
          strokeWidth: 1,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    } else if (ping == 0) {
      dotColor = ThemeColor.mutedText;
    } else if (ping < 0) {
      dotColor = ThemeColor.errorColor;
    } else if (ping >= 9999) {
      dotColor = Colors.orange; // نارنجی برای timeout
    } else if (ping < 200) {
      dotColor = ThemeColor.successColor; // سبز برای زیر 200ms
    } else if (ping < 400) {
      dotColor = ThemeColor.warningColor; // زرد برای 200-400ms
    } else {
      dotColor = ThemeColor.errorColor; // قرمز برای بالای 400ms
    }

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: dotColor,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildCompactPingIndicator(int ping, bool isTestingPing) {
    // Only numeric display. While testing or not available: show loading animation
    if (isTestingPing) {
      return _buildLoadingIndicator();
    }

    if (ping == 0) {
      return _buildLoadingIndicator();
    }
    
    if (ping < 0) {
      return _buildNumericPingBadge('-1', ThemeColor.errorColor);
    }

    // For timeout we still show numeric 9999ms per app convention
    final display = '${ping}ms';

    // Minimal color hint based on ranges, but no text labels
    Color pingColor;
    if (ping >= 9999) {
      pingColor = Colors.orange; // نارنجی برای timeout
    } else if (ping < 200) {
      pingColor = ThemeColor.successColor; // سبز برای زیر 200ms
    } else if (ping < 400) {
      pingColor = ThemeColor.warningColor; // زرد برای 200-400ms
    } else {
      pingColor = ThemeColor.errorColor; // قرمز برای بالای 400ms
    }

    return _buildNumericPingBadge(display, pingColor);
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ThemeColor.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(ThemeColor.primaryColor),
        ),
      ),
    );
  }

  Widget _buildNumericPingBadge(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Get color for ranking badge with extended support for more ranks
  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Color(0xFFFFD700); // Gold
      case 2:
        return Color(0xFFC0C0C0); // Silver
      case 3:
        return Color(0xFFCD7F32); // Bronze
      case 4:
      case 5:
        return Color(0xFF4CAF50); // Green for top 5
      case 6:
      case 7:
      case 8:
        return Color(0xFF2196F3); // Blue for 6-8
      case 9:
      case 10:
        return Color(0xFF9C27B0); // Purple for 9-10
      default:
        return ThemeColor.mutedText; // Gray for others
    }
  }

  /// Get display text for ranking
  String _getRankDisplay(int rank) {
    if (rank <= 9) {
      return rank.toString();
    } else {
      return '9+';
    }
  }
}
