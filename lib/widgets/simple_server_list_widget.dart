import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shinenet_vpn/common/theme.dart';
import 'package:shinenet_vpn/services/unified_ping_manager.dart';

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

  // Unified ping manager for real-time ping updates
  final UnifiedPingManager _pingManager = UnifiedPingManager();
  StreamSubscription<Map<String, PingResult>>? _pingUpdateSubscription;

  // Real-time ping results cache
  Map<String, PingResult> _livePingResults = {};

  @override
  void initState() {
    super.initState();
    _initializePingSystem();
  }

  @override
  void dispose() {
    _pingUpdateSubscription?.cancel();
    super.dispose();
  }

  /// Initialize ping system with real-time updates
  void _initializePingSystem() {
    // Initialize ping manager
    _pingManager.initialize();

    // Subscribe to real-time ping updates
    _pingUpdateSubscription = _pingManager.pingUpdates.listen((updates) {
      if (mounted) {
        setState(() {
          _livePingResults.addAll(updates);
        });
      }
    });

    // Load cached ping results
    _loadCachedPingResults();
  }

  /// Load cached ping results for immediate display
  void _loadCachedPingResults() {
    final serverConfigs = widget.servers
        .map((server) => server['config'] as String? ?? '')
        .where((config) => config.isNotEmpty && config != 'Automatic')
        .toList();

    final cachedResults = _pingManager.getCachedResults(serverConfigs);
    if (cachedResults.isNotEmpty && mounted) {
      setState(() {
        _livePingResults.addAll(cachedResults);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.servers.isEmpty) {
      return _buildEmptyState();
    }

    final list = ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      physics: const BouncingScrollPhysics(),
      itemCount: widget.servers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final server = widget.servers[index];
        return _buildGlassServerTile(context, server, index);
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.1),
                    Colors.white.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.dns_rounded,
                size: 48,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'no_servers_available'.tr(),
              style: ThemeColor.bodyStyle(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.8),
                context: context,
              ),
            ),
            if (widget.allowRefresh && widget.onRefresh != null) ...[
              const SizedBox(height: 24),
              GestureDetector(
                onTap: widget.onRefresh,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        ThemeColor.primaryColor.withValues(alpha: 0.2),
                        ThemeColor.primaryColor.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: ThemeColor.primaryColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.refresh_rounded,
                        color: ThemeColor.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'refresh_servers'.tr(),
                        style: TextStyle(
                          color: ThemeColor.primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Liquid Glass server tile with beautiful glass morphism effects
  Widget _buildGlassServerTile(
      BuildContext context, Map<String, dynamic> server, int index) {
    final config = server['config'] as String? ?? '';
    final displayName =
        (server['location'] as String?)?.trim().isNotEmpty == true
            ? server['location'] as String
            : (server['name'] as String?) ?? 'Unknown Server';
    final description = (server['remark'] as String?)?.trim();

    // Get ping from unified ping manager (priority) or fallback to server data
    final pingResult = _livePingResults[config];
    final ping = pingResult?.pingMs ?? (server['ping'] as int? ?? 0);

    final overrideSelected = server['isSelected'] as bool?;
    final selectedServer = widget.selectedServer;
    final isSelected = overrideSelected ??
        (selectedServer != null &&
            (selectedServer == config ||
                selectedServer == displayName ||
                selectedServer == (server['name'] as String?)));

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onServerSelected(config);
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200 + (index * 30)),
        curve: Curves.easeOutCubic,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          ThemeColor.primaryColor.withValues(alpha: 0.25),
                          ThemeColor.primaryColor.withValues(alpha: 0.1),
                        ],
                      )
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.12),
                          Colors.white.withValues(alpha: 0.06),
                        ],
                      ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? ThemeColor.primaryColor.withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.15),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  // Server icon
                  _buildGlassLeadingIcon(isSelected),
                  const SizedBox(width: 12),
                  // Server info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ThemeColor.bodyStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            context: context,
                          ),
                        ),
                        if (description != null && description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ThemeColor.captionStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.7),
                              context: context,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Ping indicator
                  if (widget.showPing) ...[
                    _buildGlassPingBadge(ping, serverConfig: config),
                    const SizedBox(width: 8),
                  ],
                  // Selection indicator
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? ThemeColor.primaryColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      isSelected
                          ? Icons.check_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.6),
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassLeadingIcon(bool isSelected) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSelected
              ? [
                  ThemeColor.primaryColor.withValues(alpha: 0.8),
                  ThemeColor.primaryColor.withValues(alpha: 0.6),
                ]
              : [
                  Colors.white.withValues(alpha: 0.2),
                  Colors.white.withValues(alpha: 0.1),
                ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.dns_rounded,
        color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.8),
        size: 18,
      ),
    );
  }

  Widget _buildGlassPingBadge(int ping, {String? serverConfig}) {
    final pingResult =
        serverConfig != null ? _livePingResults[serverConfig] : null;

    // Determine ping status and display
    final isLiveTesting = pingResult == null && ping == 0;
    final label = _pingLabel(ping, isLiveTesting: isLiveTesting);
    final color = _pingColor(ping, isLiveTesting: isLiveTesting);
    final quality = _getPingQuality(ping);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.2),
            color.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
        // Add subtle glow effect for excellent servers
        boxShadow: quality == PingQuality.excellent
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status indicator icon
          if (isLiveTesting) ...[
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(width: 2),
          ] else if (quality == PingQuality.excellent) ...[
            Icon(
              Icons.flash_on,
              size: 10,
              color: color,
            ),
            const SizedBox(width: 2),
          ] else if (quality == PingQuality.failed) ...[
            Icon(
              Icons.error_outline,
              size: 10,
              color: color,
            ),
            const SizedBox(width: 2),
          ] else if (ping >= 9999) ...[
            Icon(
              Icons.access_time,
              size: 10,
              color: color,
            ),
            const SizedBox(width: 2),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _pingLabel(int ping, {bool isLiveTesting = false}) {
    if (isLiveTesting) return 'testing_short'.tr();
    if (ping < 0) return 'ping_error_short'.tr();
    if (ping == 0) return 'ping_ready_test'.tr();
    if (ping >= 9999) return 'ping_high_short'.tr();
    return '${ping}ms';
  }

  Color _pingColor(int ping, {bool isLiveTesting = false}) {
    if (isLiveTesting) {
      return ThemeColor.primaryColor;
    }

    if (ping < 0) {
      return ThemeColor.errorColor;
    }

    if (ping == 0) {
      return ThemeColor.mutedText;
    }

    if (ping >= 9999) {
      return Colors.orange;
    }

    if (ping < 100) {
      return ThemeColor.successColor;
    }

    if (ping < 300) {
      return ThemeColor.warningColor;
    }

    if (ping < 600) {
      return Colors.orange;
    }

    return ThemeColor.errorColor;
  }

  /// Get ping quality based on unified ping manager standards
  PingQuality _getPingQuality(int ping) {
    if (ping < 0) return PingQuality.failed;
    if (ping >= 9999) return PingQuality.bad;
    if (ping < 100) return PingQuality.excellent;
    if (ping < 300) return PingQuality.good;
    if (ping < 600) return PingQuality.fair;
    if (ping < 1000) return PingQuality.poor;
    return PingQuality.bad;
  }
}
