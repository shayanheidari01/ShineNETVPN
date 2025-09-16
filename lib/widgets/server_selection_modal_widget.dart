import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shinenet_vpn/common/theme.dart';
import 'package:shinenet_vpn/widgets/simple_server_list_widget.dart';
import 'package:shinenet_vpn/services/server_optimization_service.dart';

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

class _ServerSelectionModalState extends State<ServerSelectionModal> {
  List<ServerInfo> _serversWithLivePing = [];
  bool _isTestingPing = false;
  Timer? _pingUpdateTimer;

  @override
  void initState() {
    super.initState();
    // Sort initial servers by existing ping values
    _serversWithLivePing = _sortServersByPing(List.from(widget.healthyServers));
    print('Server selection modal opened with ${_serversWithLivePing.length} servers');
    
    // Start initial ping testing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startLivePingTesting();
      _setupPeriodicPingUpdates();
    });
  }

  @override
  void dispose() {
    _pingUpdateTimer?.cancel();
    super.dispose();
  }

  /// Start live ping testing for all servers
  void _startLivePingTesting() async {
    if (_serversWithLivePing.isEmpty || _isTestingPing) return;
    
    setState(() {
      _isTestingPing = true;
    });

    // Test ping for each server with timeout
    final serverOptimization = ServerOptimizationService();
    final futures = _serversWithLivePing.map((server) async {
      try {
        final result = await serverOptimization.testServerConnection(server.config)
            .timeout(Duration(seconds: 5));
        return ServerInfo(
          name: server.name,
          config: server.config,
          ip: server.ip,
          countryCode: server.countryCode,
          ping: result.success ? (result.ping ?? result.responseTime) : -1,
        );
      } catch (e) {
        print('Ping test failed for ${server.name}: $e');
        return ServerInfo(
          name: server.name,
          config: server.config,
          ip: server.ip,
          countryCode: server.countryCode,
          ping: -1,
        );
      }
    });

    try {
      final results = await Future.wait(futures, eagerError: false);
      if (mounted) {
        // Sort servers by ping (best ping first)
        final sortedResults = _sortServersByPing(results);
        setState(() {
          _serversWithLivePing = sortedResults;
          _isTestingPing = false;
        });
        print('Live ping test completed for ${results.length} servers');
      }
    } catch (e) {
      print('Error in live ping testing: $e');
      if (mounted) {
        setState(() {
          _isTestingPing = false;
        });
      }
    }
  }

  /// Set up periodic ping updates
  void _setupPeriodicPingUpdates() {
    _pingUpdateTimer?.cancel();
    _pingUpdateTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted && !_isTestingPing) {
        _startLivePingTesting();
      }
    });
  }

  /// Sort servers by ping (best ping first)
  List<ServerInfo> _sortServersByPing(List<ServerInfo> servers) {
    final sortedServers = List<ServerInfo>.from(servers);
    
    sortedServers.sort((a, b) {
      final pingA = a.ping ?? -1;
      final pingB = b.ping ?? -1;
      
      // Failed servers (-1 ping) go to the end
      if (pingA == -1 && pingB == -1) return 0;
      if (pingA == -1) return 1;
      if (pingB == -1) return -1;
      
      // Timeout servers (9999ms) go after successful but before failed
      if (pingA >= 9999 && pingB >= 9999) return 0;
      if (pingA >= 9999) return 1;
      if (pingB >= 9999) return -1;
      
      // Sort by ping (lower is better)
      return pingA.compareTo(pingB);
    });
    
    return sortedServers;
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
          // Simple handle bar
          Container(
            margin: EdgeInsets.only(top: ThemeColor.smallSpacing),
            width: 50,
            height: 4,
            decoration: BoxDecoration(
              color: ThemeColor.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Simplified header
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: ThemeColor.largeSpacing,
              vertical: ThemeColor.mediumSpacing,
            ),
            child: Text(
              'select_server_title'.tr(),
              style: ThemeColor.headingStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          // Content
          Expanded(
            child: Column(
              children: [
                // Automatic server option
                Container(
                  margin: EdgeInsets.symmetric(horizontal: ThemeColor.largeSpacing),
                  child: _buildModernServerCard(
                    title: 'automatic'.tr(),
                    subtitle: 'best_server_auto'.tr(),
                    icon: Icons.auto_awesome_rounded,
                    serverType: 'server_automatic'.tr(),
                    isSelected: widget.selectedServer == 'server_automatic'.tr(),
                    onTap: () => _selectServer(context, 'server_automatic'.tr()),
                  ),
                ),
                
                // Live ping status and refresh button
                Container(
                  margin: EdgeInsets.symmetric(horizontal: ThemeColor.largeSpacing),
                  child: Row(
                    children: [
                      // Ping status indicator
                      if (_isTestingPing)
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.all(ThemeColor.mediumSpacing),
                            decoration: BoxDecoration(
                              color: ThemeColor.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
                              border: Border.all(color: ThemeColor.primaryColor.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(ThemeColor.primaryColor),
                                  ),
                                ),
                                SizedBox(width: ThemeColor.mediumSpacing),
                                Text(
                                  'testing_server_ping'.tr(),
                                  style: ThemeColor.bodyStyle(
                                    color: ThemeColor.primaryColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      
                      // Refresh button
                      if (!_isTestingPing)
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: ThemeColor.mediumSpacing,
                              vertical: ThemeColor.smallSpacing,
                            ),
                            child: ElevatedButton.icon(
                              onPressed: _startLivePingTesting,
                              icon: Icon(Icons.refresh_rounded, size: 18),
                              label: Text('refresh'.tr()),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ThemeColor.primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Simple server list
                if (_serversWithLivePing.isNotEmpty) ...[
                  SizedBox(height: ThemeColor.mediumSpacing),
                  Expanded(
                    child: SimpleServerListWidget(
                      servers: _serversWithLivePing.map((server) => {
                        'name': server.name,
                        'config': server.config,
                        'ip': server.ip ?? '',
                        'countryCode': server.countryCode ?? '',
                        'ping': server.ping ?? -1,
                      }).toList(),
                      selectedServer: widget.selectedServer,
                      onServerSelected: (config) => _selectServer(context, config),
                    ),
                  ),
                ],
              ],
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
}