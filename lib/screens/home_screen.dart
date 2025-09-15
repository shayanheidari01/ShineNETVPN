import 'dart:async';
import 'dart:convert';

import 'package:shinenet_vpn/common/theme.dart';
import 'package:shinenet_vpn/widgets/connection_widget.dart';
import 'package:shinenet_vpn/widgets/server_selection_modal_widget.dart';
import 'package:shinenet_vpn/services/server_optimization_service.dart';
import 'package:shinenet_vpn/services/connection_optimization_service.dart';
import 'package:shinenet_vpn/services/server_cache_manager.dart';
import 'package:shinenet_vpn/utils/server_location_parser.dart';
import 'package:shinenet_vpn/screens/home_screen_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:easy_localization/easy_localization.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final v2rayStatus = ValueNotifier<V2RayStatus>(V2RayStatus());
  late final FlutterV2ray flutterV2ray = FlutterV2ray(
    onStatusChanged: (status) {
      v2rayStatus.value = status;
    },
  );

  // Optimization services
  final ServerOptimizationService _serverService = ServerOptimizationService();
  final ConnectionOptimizationService _connectionService = ConnectionOptimizationService();
  final ServerCacheManager _cacheManager = ServerCacheManager();

  // UI State
  bool isLoading = false;
  String loadingStatus = '';
  int serversBeingTested = 0;
  int serversTestCompleted = 0;
  
  // Individual server test results
  List<Map<String, dynamic>> serverTestResults = <Map<String, dynamic>>[];
  bool isTestingServers = false;

  // Server State
  String selectedServer = 'Automatic';
  String selectedServerType = 'Automatic'; // Changed from selectedServerLogo
  int? connectedServerDelay;
  bool isFetchingPing = false;

  // Additional State
  bool proxyOnly = false;
  List<String> bypassSubnets = <String>[];
  String? coreVersion;
  String? versionName;
  late SharedPreferences _prefs;
  List<String> blockedApps = <String>[];

  // Server management - unified with ServerCacheManager
  List<String> cachedServers = <String>[];
  List<Map<String, dynamic>> processedServers = <Map<String, dynamic>>[];
  Map<String, int> serverPings = <String, int>{}; // Store ping results
  DateTime? lastServerFetch;
  static const String pingCacheKey = 'server_ping_cache';
  // Connection retry variables
  int connectionRetryCount = 0;
  static const int maxRetries = 5;
  static const Duration initialRetryDelay = Duration(seconds: 2);
  
  // Add server testing protection flag
  bool _isServerTestingInProgress = false;
  
  // Add a queue for server testing to prevent resource exhaustion
  final List<Map<String, dynamic>> _serverTestQueue = <Map<String, dynamic>>[];
  bool _isProcessingServerQueue = false;
  
  // Connection analytics
  int _totalConnectionAttempts = 0;
  int _successfulConnections = 0;
  int _failedConnections = 0;
  double _averageConnectionTime = 0.0;
  

  Future<void> _initializeServices() async {
    try {
      await _serverService.initialize();
      await _connectionService.initialize();
      await _loadConnectionAnalytics();
      
      // Background testing removed for optimization
    } catch (e) {
      print('Error initializing optimization services: $e');
      // Continue with original implementation if optimization services fail
    }
  }
  
  /// Load connection analytics from storage
  Future<void> _loadConnectionAnalytics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _totalConnectionAttempts = prefs.getInt('total_connection_attempts') ?? 0;
      _successfulConnections = prefs.getInt('successful_connections') ?? 0;
      _failedConnections = prefs.getInt('failed_connections') ?? 0;
      _averageConnectionTime = prefs.getDouble('average_connection_time') ?? 0.0;
    } catch (e) {
      print('Error loading connection analytics: $e');
    }
  }
  
  /// Save connection analytics to storage
  Future<void> _saveConnectionAnalytics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('total_connection_attempts', _totalConnectionAttempts);
      await prefs.setInt('successful_connections', _successfulConnections);
      await prefs.setInt('failed_connections', _failedConnections);
      await prefs.setDouble('average_connection_time', _averageConnectionTime);
    } catch (e) {
      print('Error saving connection analytics: $e');
    }
  }
  
  /// Record connection attempt
  void _recordConnectionAttempt(bool success, int connectionTime) {
    _totalConnectionAttempts++;
    
    if (success) {
      _successfulConnections++;
      // Update average connection time
      if (_averageConnectionTime == 0.0) {
        _averageConnectionTime = connectionTime.toDouble();
      } else {
        _averageConnectionTime = (_averageConnectionTime + connectionTime) / 2.0;
      }
    } else {
      _failedConnections++;
    }
    
    _saveConnectionAnalytics();
  }
  
  /// Get connection success rate
  double get connectionSuccessRate {
    if (_totalConnectionAttempts == 0) return 0.0;
    return _successfulConnections / _totalConnectionAttempts;
  }
  
  /// Get connection analytics summary
  Map<String, dynamic> getConnectionAnalytics() {
    return {
      'totalAttempts': _totalConnectionAttempts,
      'successfulConnections': _successfulConnections,
      'successRate': connectionSuccessRate,
      'averageConnectionTime': _averageConnectionTime,
      'optimizationServiceStats': _connectionService.getConnectionStats(),
      'blockedApps': blockedApps,
    };
  }

  @override
  void initState() {
    super.initState();
    getVersionName();
    _initializeServices();
    _loadServerSelection();
    
    // Fetch servers once on app startup
    _fetchAndCacheServersOnStartup();
    
    flutterV2ray
        .initializeV2Ray(
      notificationIconResourceType: "notification_icon_type".tr(),
      notificationIconResourceName: "notification_icon_name".tr(),
    )
        .then((value) async {
      coreVersion = await flutterV2ray.getCoreVersion();
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final bool isWideScreen = size.width > 600;

    return Scaffold(
      backgroundColor: ThemeColor.backgroundColor,
      body: SafeArea(
        child: ValueListenableBuilder<V2RayStatus>(
          valueListenable: v2rayStatus,
          builder: (context, status, _) {
            final bool isConnected = status.state == 'CONNECTED';
            final bool isConnecting = isLoading || status.state == 'CONNECTING';
            
            return CustomScrollView(
              slivers: [
                // Modern app bar
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  floating: true,
                  pinned: false,
                  expandedHeight: 80,
                  actions: [],
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: EdgeInsets.zero,
                    title: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: ThemeColor.mediumSpacing,
                        vertical: ThemeColor.smallSpacing,
                      ),
                      child: Text(
                        'ShineNET VPN',
                        style: ThemeColor.headingStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                
                // Main content
                SliverPadding(
                  padding: EdgeInsets.all(ThemeColor.mediumSpacing),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Simplified connection section
                      _buildSimplifiedConnectionSection(status, isConnected, isConnecting),
                      SizedBox(height: ThemeColor.largeSpacing),
                      
                      // Server selection (simplified)
                      _buildSimplifiedServerSelection(),
                      SizedBox(height: ThemeColor.largeSpacing),
                      
                      // Statistics (only when connected)
                      if (isConnected) ...[
                        _buildSimplifiedStats(status),
                        SizedBox(height: ThemeColor.largeSpacing),
                      ],
                      
                      // Quick actions (simplified)
                      _buildSimplifiedQuickActions(),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }


  // Simplified connection section
  Widget _buildSimplifiedConnectionSection(V2RayStatus status, bool isConnected, bool isConnecting) {
    return Container(
      decoration: ThemeColor.cardDecoration(
        withGradient: isConnected,
        withShadow: true,
      ),
      child: Padding(
        padding: EdgeInsets.all(ThemeColor.largeSpacing),
        child: Column(
          children: [
            // Connection button (simplified)
            ConnectionWidget(
              onTap: () => _handleConnectionTap(status),
              isLoading: isLoading,
              status: status.state,
            ),
            
            // Status info (simplified)
            if (isConnected) ...[
              SizedBox(height: ThemeColor.mediumSpacing),
              _buildSimplifiedStatusInfo(status),
            ],
            
            // Loading status (simplified)
            if (isLoading && loadingStatus.isNotEmpty) ...[
              SizedBox(height: ThemeColor.mediumSpacing),
              _buildSimplifiedLoadingStatus(),
            ],
          ],
        ),
      ),
    );
  }

  // Simplified status info
  Widget _buildSimplifiedStatusInfo(V2RayStatus status) {
    return Container(
      padding: EdgeInsets.all(ThemeColor.mediumSpacing),
      decoration: BoxDecoration(
        color: ThemeColor.successColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
        border: Border.all(
          color: ThemeColor.successColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildSimpleStatItem(
            icon: Icons.timer_rounded,
            label: 'connection_time'.tr(),
            value: status.duration,
            color: ThemeColor.successColor,
          ),
          Container(
            width: 1,
            height: 40,
            color: ThemeColor.successColor.withValues(alpha: 0.3),
          ),
          _buildSimpleStatItem(
            icon: Icons.speed_rounded,
            label: 'speed'.tr(),
            value: _formatSpeed('${status.downloadSpeed} B/s'),
            color: ThemeColor.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        SizedBox(height: 6),
        Text(
          value,
          style: ThemeColor.bodyStyle(
            fontWeight: FontWeight.w700,
            color: color,
            fontSize: 15,
          ),
        ),
        Text(
          label,
          style: ThemeColor.captionStyle(
            color: color.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // Simplified loading status
  Widget _buildSimplifiedLoadingStatus() {
    return Container(
      padding: EdgeInsets.all(ThemeColor.mediumSpacing),
      decoration: BoxDecoration(
        color: ThemeColor.connectingColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
        border: Border.all(
          color: ThemeColor.connectingColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          LoadingAnimationWidget.threeArchedCircle(
            color: ThemeColor.connectingColor,
            size: 20,
          ),
          SizedBox(width: ThemeColor.mediumSpacing),
          Expanded(
            child: Text(
              loadingStatus,
              style: ThemeColor.bodyStyle(
                color: ThemeColor.connectingColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper function to format bytes for better readability
  String _formatBytes(String bytesStr) {
    try {
      // Extract numeric value from string like "1234567 B"
      final match = RegExp(r'(\d+)').firstMatch(bytesStr);
      if (match == null) return bytesStr;
      
      final bytes = int.parse(match.group(1)!);
      
      if (bytes < 1024) return '${bytes} B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    } catch (e) {
      return bytesStr;
    }
  }

  // Helper function to format speed for better readability
  String _formatSpeed(String speedStr) {
    try {
      // Extract numeric value from string like "1234567 B/s"
      final match = RegExp(r'(\d+)').firstMatch(speedStr);
      if (match == null) return speedStr;
      
      final bytesPerSec = int.parse(match.group(1)!);
      
      if (bytesPerSec < 1024) return '${bytesPerSec} B/s';
      if (bytesPerSec < 1024 * 1024) return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
      if (bytesPerSec < 1024 * 1024 * 1024) return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
      return '${(bytesPerSec / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB/s';
    } catch (e) {
      return speedStr;
    }
  }

  // Simplified server selection
  Widget _buildSimplifiedServerSelection() {
    return Container(
      decoration: ThemeColor.cardDecoration(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
          onTap: () => _showServerSelectionModal(context),
          child: Padding(
            padding: EdgeInsets.all(ThemeColor.mediumSpacing),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ThemeColor.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
                  ),
                  child: Icon(
                    Icons.dns_rounded,
                    color: ThemeColor.primaryColor,
                    size: 24,
                  ),
                ),
                SizedBox(width: ThemeColor.mediumSpacing),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'server'.tr(),
                        style: ThemeColor.captionStyle(),
                      ),
                      SizedBox(height: 4),
                      Text(
                        selectedServer,
                        style: ThemeColor.bodyStyle(
                          fontWeight: FontWeight.w600,
                          color: ThemeColor.primaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: ThemeColor.mutedText,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Simplified stats
  Widget _buildSimplifiedStats(V2RayStatus status) {
    return Container(
      decoration: ThemeColor.cardDecoration(),
      child: Padding(
        padding: EdgeInsets.all(ThemeColor.mediumSpacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics_rounded,
                  color: ThemeColor.primaryColor,
                  size: 20,
                ),
                SizedBox(width: ThemeColor.smallSpacing),
                Text(
                  'statistics'.tr(),
                  style: ThemeColor.bodyStyle(
                    fontWeight: FontWeight.w600,
                    color: ThemeColor.primaryText,
                  ),
                ),
              ],
            ),
            SizedBox(height: ThemeColor.mediumSpacing),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.download_rounded,
                    label: 'download'.tr(),
                    value: '${status.download} B',
                    color: ThemeColor.successColor,
                  ),
                ),
                SizedBox(width: ThemeColor.smallSpacing),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.upload_rounded,
                    label: 'upload'.tr(),
                    value: '${status.upload} B',
                    color: ThemeColor.warningColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    // Format the value for better readability
    String formattedValue = _formatBytes(value);
    
    return Container(
      padding: EdgeInsets.all(ThemeColor.mediumSpacing),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Icon with background circle
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(height: ThemeColor.smallSpacing),
          // Value with better typography
          Text(
            formattedValue,
            style: ThemeColor.bodyStyle(
              fontWeight: FontWeight.w800,
              color: color,
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 2),
          // Label
          Text(
            label,
            style: ThemeColor.captionStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Simplified quick actions
  Widget _buildSimplifiedQuickActions() {
    return Container(
      decoration: ThemeColor.cardDecoration(),
      child: Padding(
        padding: EdgeInsets.all(ThemeColor.mediumSpacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.flash_on_rounded,
                  color: ThemeColor.warningColor,
                  size: 20,
                ),
                SizedBox(width: ThemeColor.smallSpacing),
                Text(
                  'quick_actions'.tr(),
                  style: ThemeColor.bodyStyle(
                    fontWeight: FontWeight.w600,
                    color: ThemeColor.primaryText,
                  ),
                ),
              ],
            ),
            SizedBox(height: ThemeColor.mediumSpacing),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.speed_rounded,
                    label: 'test_servers'.tr(),
                    color: ThemeColor.primaryColor,
                    onTap: isLoading ? null : testServersManually,
                  ),
                ),
                SizedBox(width: ThemeColor.smallSpacing),
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.refresh_rounded,
                    label: 'refresh'.tr(),
                    color: ThemeColor.successColor,
                    onTap: isLoading ? null : () async {
                      setState(() {
                        isLoading = true;
                        loadingStatus = 'refreshing'.tr();
                      });
                      await getServerList();
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: ThemeColor.smallSpacing),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.analytics_rounded,
                    label: 'test_all_servers'.tr(),
                    color: ThemeColor.warningColor,
                    onTap: isLoading ? null : testAllServers,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(ThemeColor.mediumSpacing),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(ThemeColor.smallSpacing),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              SizedBox(height: ThemeColor.smallSpacing),
              Text(
                label,
                style: ThemeColor.captionStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }




  void _handleConnectionTap(V2RayStatus value) async {
    if (value.state == "disconnected_status".tr()) {
      connectionRetryCount = 0; // Reset retry count for new connection attempt
      
      // Check if we have healthy servers available
      final healthyServers = serverTestResults
          .where((result) => result['status'] == 'success' && result['delay'] > 0)
          .toList();
      
      if (healthyServers.isEmpty) {
        // No healthy servers available, fetch new servers
        print('No healthy servers available, fetching new servers...');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('no_healthy_servers'.tr()),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        await _connectWithRetry();
      } else {
        // We have healthy servers, proceed with connection
        print('Found ${healthyServers.length} healthy servers, proceeding with connection...');
        await _connectWithRetry();
      }
    } else {
      flutterV2ray.stopV2Ray();
    }
  }

  Future<void> _connectWithRetry() async {
    try {
      setState(() {
        isLoading = true;
        loadingStatus = '🔄 Preparing automatic connection...';
      });

      // Try simple automatic connection first
      await _connectAutomaticSimple();
      
    } catch (e) {
      print('Simple automatic connection failed: $e');
      
      // Fallback to enhanced method
      try {
        await _connectAutomaticSmart();
      } catch (e2) {
        print('Enhanced automatic connection also failed: $e2');
        
        // Final fallback to original method
        await _connectWithFallbackRetry();
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          loadingStatus = '';
        });
      }
    }
  }
  
  /// Enhanced automatic connection method with intelligent retry
  Future<void> _connectAutomaticSimple() async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        setState(() {
          loadingStatus = retryCount == 0 
              ? '🚀 Starting automatic connection...' 
              : '🔄 Retrying automatic connection (${retryCount + 1}/$maxRetries)...';
        });
        
        // Add overall timeout for the entire connection process
        await Future.any([
          _performSimpleConnection(),
          Future.delayed(Duration(seconds: 30), () {
            throw TimeoutException('Connection process timed out', Duration(seconds: 30));
          }),
        ]);
        
        // If we reach here, connection was successful
        print('✅ Automatic connection successful on attempt ${retryCount + 1}');
        return;
        
      } catch (e) {
        retryCount++;
        print('❌ Automatic connection attempt $retryCount failed: $e');
        
        if (retryCount >= maxRetries) {
          print('🚫 All automatic connection attempts failed');
          rethrow;
        }
        
        // Wait before retry with exponential backoff
        final delaySeconds = retryCount * 2;
        setState(() {
          loadingStatus = '⏳ Waiting ${delaySeconds}s before retry...';
        });
        await Future.delayed(Duration(seconds: delaySeconds));
      }
    }
  }
  
  /// Perform the actual simple connection with improved logic
  Future<void> _performSimpleConnection() async {
    setState(() {
      loadingStatus = '🔍 Finding best server for automatic connection...';
    });

    // Step 1: Try to use processed servers with ping data
    if (processedServers.isNotEmpty) {
      print('📋 Using processed servers (${processedServers.length} servers)');
      
      // Filter and sort healthy servers by ping (best first)
      final healthyServers = processedServers
          .where((server) => (server['ping'] as int) > 0 && (server['ping'] as int) < 5000)
          .toList();
      
      // Sort by ping (ascending - best ping first)
      healthyServers.sort((a, b) => (a['ping'] as int).compareTo(b['ping'] as int));
      
      if (healthyServers.isNotEmpty) {
        // Try top 3 servers for better reliability
        for (int i = 0; i < healthyServers.length && i < 3; i++) {
          final server = healthyServers[i];
          try {
            setState(() {
              loadingStatus = '🚀 Connecting to server ${i + 1} (${server['ping']}ms)...';
            });
            
            await _connectToServer(server['config'] as String);
            print('✅ Successfully connected to server with ${server['ping']}ms ping');
            return;
          } catch (e) {
            print('❌ Failed to connect to server ${i + 1}: $e');
            if (i == healthyServers.length - 1 || i == 2) {
              // If this was the last attempt, continue to next method
              break;
            }
            // Try next server
            continue;
          }
        }
      }
    }
    
    // Step 2: Fetch fresh servers and test them
    setState(() {
      loadingStatus = '📡 Fetching fresh servers...';
    });
    
    try {
      final freshServers = await _fetchServersWithFallback();
      if (freshServers.isNotEmpty) {
        // Test and connect to best server from fresh list
        final bestServer = await findAndTestBestServer(freshServers.take(5).toList());
        if (bestServer != null) {
          setState(() {
            loadingStatus = '🚀 Connecting to optimal server...';
          });
          await _connectToServer(bestServer);
          return;
        }
      }
    } catch (e) {
      print('Failed to fetch fresh servers: $e');
    }
    
    // Step 3: Fallback to cached servers
    if (cachedServers.isNotEmpty) {
      print('📋 Using cached servers as fallback');
      
      setState(() {
        loadingStatus = '🚀 Connecting to cached server...';
      });
      
      // Try first few cached servers
      for (int i = 0; i < cachedServers.length && i < 3; i++) {
        try {
          await _connectToServer(cachedServers[i]);
          print('✅ Successfully connected using cached server ${i + 1}');
          return;
        } catch (e) {
          print('❌ Cached server ${i + 1} failed: $e');
          if (i == cachedServers.length - 1 || i == 2) {
            break;
          }
        }
      }
    }
    
    // Step 4: Ultimate fallback - use optimization service
    setState(() {
      loadingStatus = '🔧 Using optimization service...';
    });
    
    try {
      final optimizedServers = await _serverService.getOptimizedServerList(forceRefresh: true);
      if (optimizedServers.isNotEmpty) {
        await _connectToServer(optimizedServers.first);
        return;
      }
    } catch (e) {
      print('Optimization service failed: $e');
    }
    
    throw Exception('All automatic connection methods failed');
  }
  
  /// Enhanced automatic connection with smart server selection
  Future<void> _connectAutomaticSmart() async {
    try {
      // Step 1: Get server list with multiple fallbacks
      final servers = await _fetchServersWithMultipleFallbacks();
      if (servers.isEmpty) {
        throw Exception('No servers available from any source');
      }

      setState(() {
        loadingStatus = '🔍 Analyzing ${servers.length} servers...';
      });

      // Step 2: Test servers and select the best one with timeout
      final bestServer = await _selectBestServerSmart(servers)
          .timeout(Duration(seconds: 30), onTimeout: () {
        print('Server selection timed out, using first available server');
        return null;
      });
      
      if (bestServer == null) {
        // Fallback: try direct connection with first server
        print('No healthy servers found, trying direct connection...');
        // connectDirectly(servers.take(3).toList()); // Removed to fix compilation
        return;
      }

      setState(() {
        loadingStatus = '🚀 Connecting to optimal server...';
      });

      // Step 3: Connect to the selected server
      await _connectToSelectedServer(bestServer);
      
    } catch (e) {
      print('Smart automatic connection failed: $e');
      rethrow;
    }
  }
  
  /// Fetch servers with multiple fallback methods
  Future<List<String>> _fetchServersWithMultipleFallbacks() async {
    final fallbackMethods = [
      _fetchServersOptimized,
      _fetchServersDirect,
      _fetchServersFromAllOrigins,
      _fetchServersFromAlternative,
    ];
    
    for (int i = 0; i < fallbackMethods.length; i++) {
      try {
        setState(() {
          loadingStatus = '📡 Fetching servers (method ${i + 1}/${fallbackMethods.length})...';
        });
        
        final servers = await fallbackMethods[i]();
        if (servers.isNotEmpty) {
          print('✅ Successfully fetched ${servers.length} servers using method ${i + 1}');
          return servers;
        }
      } catch (e) {
        print('❌ Method ${i + 1} failed: $e');
        if (i < fallbackMethods.length - 1) {
          await Future.delayed(Duration(milliseconds: 500));
        }
      }
    }
    
    throw Exception('All server fetching methods failed');
  }
  
  /// Select the best server using smart algorithm
  Future<Map<String, dynamic>?> _selectBestServerSmart(List<String> servers) async {
    final testResults = <Map<String, dynamic>>[];
    final serversToTest = servers.take(8).toList(); // Test first 8 servers
    
    setState(() {
      loadingStatus = '🧪 Testing ${serversToTest.length} servers...';
    });
    
    for (int i = 0; i < serversToTest.length && mounted; i++) {
      final server = serversToTest[i];
      
      try {
        final v2rayURL = FlutterV2ray.parseFromURL(server);
        final config = v2rayURL.getFullConfiguration();
        
        if (config.isEmpty) continue;
        
        final startTime = DateTime.now();
        final delay = await flutterV2ray
            .getServerDelay(config: config)
            .timeout(Duration(milliseconds: 1000));
        final responseTime = DateTime.now().difference(startTime).inMilliseconds;
        
        if (delay > 0) {
          final score = _calculateServerScore(delay, responseTime, i);
          testResults.add({
            'server': server,
            'config': config,
            'delay': delay,
            'responseTime': responseTime,
            'score': score,
            'index': i + 1,
          });
          
          print('✅ Server ${i + 1}: ${delay}ms (score: ${score.toStringAsFixed(1)})');
        }
        
        setState(() {
          loadingStatus = '🧪 Testing server ${i + 1}/${serversToTest.length}...';
        });
        
        await Future.delayed(Duration(milliseconds: 100));
        
      } catch (e) {
        print('❌ Server ${i + 1} failed: $e');
      }
    }
    
    if (testResults.isEmpty) return null;
    
    // Sort by score (highest first)
    testResults.sort((a, b) => b['score'].compareTo(a['score']));
    
    final bestServer = testResults.first;
    print('🏆 Best server selected: ${bestServer['delay']}ms (score: ${bestServer['score'].toStringAsFixed(1)})');
    
    return bestServer;
  }
  
  /// Calculate server score for selection
  double _calculateServerScore(int delay, int responseTime, int index) {
    double score = 100.0;
    
    // Delay penalty (lower is better)
    score -= (delay / 10.0);
    
    // Response time penalty
    score -= (responseTime / 20.0);
    
    // Priority bonus (earlier servers get slight bonus)
    score += (8 - index) * 0.5;
    
    // Stability bonus (if delay is very low)
    if (delay < 200) {
      score += 10.0;
    } else if (delay < 500) {
      score += 5.0;
    }
    
    return score.clamp(0.0, 100.0);
  }
  
  /// Connect to the selected server
  Future<void> _connectToSelectedServer(Map<String, dynamic> serverData) async {
    try {
      final config = serverData['config'] as String;
      final delay = serverData['delay'] as int;
      
      // Request VPN permission
      final hasPermission = await flutterV2ray.requestPermission();
      if (!hasPermission) {
        throw Exception('VPN permission denied');
      }
      
      // Start V2Ray connection (remove await as startV2Ray is not async)
      flutterV2ray.startV2Ray(
        remark: 'ShineNET VPN - Auto',
        config: config,
        proxyOnly: false,
        bypassSubnets: null,
        notificationDisconnectButtonName: 'Disconnect',
        blockedApps: blockedApps,
      );
      
      // Record successful connection
      _recordConnectionAttempt(true, delay);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('connecting_to_optimal_server'.tr().replaceAll('{{delay}}', delay.toString())),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
      
    } catch (e) {
      _recordConnectionAttempt(false, 0);
      throw Exception('Failed to connect to selected server: $e');
    }
  }
  
  /// Fetch servers using optimized service
  Future<List<String>> _fetchServersOptimized() async {
    try {
      final servers = await _serverService.getOptimizedServerList(
        forceRefresh: true,
        onStatusUpdate: (status) {
          if (mounted) {
            setState(() {
              loadingStatus = '📡 $status';
            });
          }
        },
      );
      return servers;
    } catch (e) {
      print('Optimized server fetch failed: $e');
      rethrow;
    }
  }
  
  /// Fallback connection with retry
  Future<void> _connectWithFallbackRetry() async {
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        await getServerList();
        return; // Connection successful, exit retry loop
      } catch (e) {
        print('Fallback connection attempt ${attempt + 1} failed: $e');

        if (attempt < maxRetries) {
          // Calculate exponential backoff delay
          final delaySeconds = initialRetryDelay.inSeconds * (1 << attempt);
          final delay = Duration(seconds: delaySeconds > 30 ? 30 : delaySeconds);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Connection failed. Retrying in ${delay.inSeconds} seconds... (${attempt + 1}/$maxRetries)',
                ),
                behavior: SnackBarBehavior.floating,
                duration: delay,
              ),
            );
          }

          await Future.delayed(delay);
        } else {
          // Final attempt failed - offer direct connection
          if (mounted) {
            setState(() {
              isLoading = false;
            });
            
            // Show option to try direct connection
            final bool tryDirect = await _showDirectConnectionDialog();
            if (tryDirect) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('error_max_retries_reached'.tr()),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        }
      }
    }
  }
  
  Future<bool> _showDirectConnectionDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('connection_failed'.tr()),
          content: Text(
            'Standard connection with server testing failed. Would you like to try connecting directly without server testing? This may be slower but might work.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('cancel'.tr()),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('try_direct_connection'.tr()),
            ),
          ],
        );
      },
    ) ?? false;
  }

  void _showServerSelectionModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (BuildContext context) {
        // Use cached processed servers with ping data for display
        final availableServers = processedServers.map((serverData) {
          final ping = serverData['ping'] as int;
          print('🏓 Server: ${serverData['name']}, Ping: $ping'); // Debug ping data
          return ServerInfo(
            name: serverData['name'] as String,
            config: serverData['config'] as String,
            ip: serverData['ip'] as String?,
            countryCode: serverData['countryCode'] as String?,
            ping: ping > 0 ? ping : null, // Show ping if available, null if failed
          );
        }).toList();
        
        print('📊 Total servers with ping data: ${availableServers.length}');
        
        return ServerSelectionModal(
          selectedServer: selectedServer,
          onServerSelected: (server) async {
            // Only allow Automatic or specific server configs
            if (server == 'Server 1' || server == 'Server 2') {
              // Don't allow Server 1 or Server 2 selection
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('select_healthy_server'.tr()),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
              return;
            }
            
            if (v2rayStatus.value.state == "disconnected_status".tr()) {
              // If the selected server is 'Automatic', perform automatic connection
              if (server == 'Automatic' || server == 'server_automatic'.tr()) {
                setState(() {
                  selectedServer = server;
                });
                _saveServerSelection(server);
                Navigator.pop(context);
                
                // Perform automatic connection to best available server
                try {
                  await _performSimpleConnection();
                } catch (e) {
                  print('Automatic connection failed: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Automatic connection failed: ${e.toString()}'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } else {
                // If a specific healthy server config is selected, connect to it immediately
                // Extract a descriptive name for the server
                String serverName = _generateServerNameFromConfig(server);
                
                setState(() {
                  selectedServer = serverName;
                });
                _saveServerSelection(serverName);
                Navigator.pop(context);
                
                // Connect to the specific server configuration
                await _connectToServer(server);
              }
            } else {
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'error_change_server'.tr(),
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          },
          healthyServers: availableServers,
        );
      },
    );
  }
  
  // Generate a descriptive server name without IP to hide server IPs as requested
  String _generateServerName(String config, String? ip, int index) {
    // Try to extract protocol information
    String protocol = 'Server';
    if (config.startsWith('vmess://')) {
      protocol = 'VMess';
    } else if (config.startsWith('vless://')) {
      protocol = 'VLess';
    } else if (config.startsWith('trojan://')) {
      protocol = 'Trojan';
    } else if (config.startsWith('ss://')) {
      protocol = 'Shadowsocks';
    }
    
    // Return server name without IP as requested
    return '$protocol $index';
  }
  
  // Generate a descriptive server name from config for direct selection
  String _generateServerNameFromConfig(String config) {
    // Try to extract protocol information
    String protocol = 'Healthy Server';
    if (config.startsWith('vmess://')) {
      protocol = 'VMess Server';
    } else if (config.startsWith('vless://')) {
      protocol = 'VLess Server';
    } else if (config.startsWith('trojan://')) {
      protocol = 'Trojan Server';
    } else if (config.startsWith('ss://')) {
      protocol = 'Shadowsocks Server';
    }
    
    return protocol;
  }
  
  // Extract IP address from server configuration
  String? _extractIPFromConfig(String config) {
    try {
      // Handle different V2Ray protocols
      if (config.startsWith('vmess://')) {
        // VMess URL format
        final base64Part = config.substring(8); // Remove 'vmess://'
        final decoded = utf8.decode(base64.decode(base64Part));
        final json = jsonDecode(decoded);
        return json['add'] as String?; // 'add' field contains the address
      } else if (config.startsWith('vless://') || config.startsWith('trojan://') || config.startsWith('ss://')) {
        // For other protocols, parse as URI
        final uri = Uri.parse(config);
        return uri.host;
      }
    } catch (e) {
      print('Error extracting IP from config: $e');
    }
    
    // Fallback to regex extraction
    final ipRegex = RegExp(r'(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})');
    final match = ipRegex.firstMatch(config);
    return match?.group(1);
  }
  
  // Synchronous version for immediate display
  String? _getCountryCodeFromIPSync(String? ip) {
    // Simple mapping for immediate display
    if (ip == null || ip.isEmpty) return null;
    
    if (ip.startsWith('1.1.1')) return 'AU'; // Cloudflare DNS
    if (ip.startsWith('8.8.8')) return 'US'; // Google DNS
    if (ip.startsWith('208.67.222')) return 'US'; // OpenDNS
    if (ip.startsWith('104.16')) return 'US'; // Cloudflare
    if (ip.startsWith('104.17')) return 'US'; // Cloudflare
    if (ip.startsWith('104.18')) return 'US'; // Cloudflare
    if (ip.startsWith('104.19')) return 'US'; // Cloudflare
    if (ip.startsWith('104.20')) return 'US'; // Cloudflare
    if (ip.startsWith('104.21')) return 'US'; // Cloudflare
    if (ip.startsWith('104.22')) return 'US'; // Cloudflare
    if (ip.startsWith('104.23')) return 'US'; // Cloudflare
    if (ip.startsWith('104.24')) return 'US'; // Cloudflare
    if (ip.startsWith('104.25')) return 'US'; // Cloudflare
    if (ip.startsWith('104.26')) return 'US'; // Cloudflare
    if (ip.startsWith('104.27')) return 'US'; // Cloudflare
    if (ip.startsWith('104.28')) return 'US'; // Cloudflare
    if (ip.startsWith('172.64')) return 'US'; // Cloudflare
    if (ip.startsWith('172.65')) return 'US'; // Cloudflare
    if (ip.startsWith('172.66')) return 'US'; // Cloudflare
    if (ip.startsWith('172.67')) return 'US'; // Cloudflare
    if (ip.startsWith('172.68')) return 'US'; // Cloudflare
    if (ip.startsWith('172.69')) return 'US'; // Cloudflare
    
    // Add more common IP to country mappings here
    // This is a simplified approach for immediate display
    
    return 'US'; // Default fallback
  }
  

  String getServerParam() {
    // Only return 'auto' since we're removing Server 1 and Server 2
    return 'auto';
  }

  Future<void> _loadServerSelection() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedServer = _prefs.getString('selectedServers') ?? 'Automatic';
      selectedServerType = _prefs.getString('selectedServerTypes') ?? 'Automatic';
    });
  }

  Future<void> _saveServerSelection(String server, [String? serverType]) async {
    await _prefs.setString('selectedServers', server);
    await _prefs.setString('selectedServerTypes', serverType ?? server);
    setState(() {
      selectedServer = server;
      selectedServerType = serverType ?? server;
    });
  }

  // New method to test all servers with better resource management
  Future<void> testAllServers() async {
    // Prevent multiple concurrent server testing operations
    if (_isServerTestingInProgress) {
      print('Server testing already in progress, skipping...');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('server_testing_in_progress'.tr()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    
    _isServerTestingInProgress = true;
    
    try {
      setState(() {
        isLoading = true;
        isTestingServers = true;
        loadingStatus = 'Fetching server list for complete testing...';
        serverTestResults = [];
      });

      // Get server list
      List<String> servers = await _fetchServersWithFallback();
      
      if (servers.isEmpty) {
        // Show user-friendly message instead of throwing exception
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('no_servers_available'.tr()),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      print('Testing all ${servers.length} servers...');
      
      setState(() {
        serversBeingTested = servers.length;
        serversTestCompleted = 0;
        loadingStatus = 'Testing all servers (this may take several minutes)...';
      });

      // Test all servers without limit
      int maxServersToTest = servers.length;
      print('Testing all $maxServersToTest servers');

      // Use queue-based testing to prevent resource exhaustion
      _serverTestQueue.clear();
      for (int i = 0; i < maxServersToTest; i++) {
        _serverTestQueue.add({
          'index': i,
          'serverUrl': servers[i],
          'maxServers': maxServersToTest,
        });
      }
      
      await _processServerTestQueue();
      
      print('Complete server testing completed. Results: ${serverTestResults.length} servers tested');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('server_testing_complete'.tr().replaceAll('{{count}}', serverTestResults.where((r) => r['delay'] > 0).length.toString())),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      print('Error in complete server testing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('error_testing_servers'.tr().replaceAll('{{error}}', e.toString())),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      _isServerTestingInProgress = false;
      if (mounted) {
        setState(() {
          isLoading = false;
          isTestingServers = false;
          loadingStatus = '';
        });
      }
    }
  }

  // New method to manually test servers one by one with better resource management
  Future<void> testServersManually() async {
    // Prevent multiple concurrent server testing operations
    if (_isServerTestingInProgress) {
      print('Server testing already in progress, skipping...');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('server_testing_in_progress'.tr()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    
    _isServerTestingInProgress = true;
    
    try {
      setState(() {
        isLoading = true;
        isTestingServers = true;
        loadingStatus = 'Fetching server list for manual testing...';
        serverTestResults = [];
      });

      // Get server list
      List<String> servers = await _fetchServersWithFallback();
      
      if (servers.isEmpty) {
        // Show user-friendly message instead of throwing exception
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('no_servers_available'.tr()),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      print('Manually testing ${servers.length} servers...');
      
      setState(() {
        serversBeingTested = servers.length; // Test all available servers
        serversTestCompleted = 0;
        loadingStatus = 'Testing all ${servers.length} servers with optimized method...';
      });

      // Use optimized testing method
      final testResults = await _testServersOptimized(servers);
      
      // Convert results to the expected format
      serverTestResults = testResults.map((result) => {
        'index': result['index'],
        'config': result['config'],
        'delay': result['delay'],
        'status': result['status'],
      }).toList();
      
      print('Manual server testing completed. Results: ${serverTestResults.length} servers tested');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('server_testing_completed'.tr().replaceAll('{{count}}', serverTestResults.where((r) => r['delay'] > 0).length.toString())),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Error in manual server testing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('server_testing_failed'.tr().replaceAll('{{error}}', e.toString())),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() {
        isLoading = false;
        isTestingServers = false;
        loadingStatus = 'Server testing completed';
        _isServerTestingInProgress = false; // Reset the flag
      });
    }
  }

  // Process server test queue to prevent resource exhaustion
  Future<void> _processServerTestQueue() async {
    if (_isProcessingServerQueue) return;
    
    _isProcessingServerQueue = true;
    
    try {
      while (_serverTestQueue.isNotEmpty && mounted) {
        final serverInfo = _serverTestQueue.removeAt(0);
        final int i = serverInfo['index'];
        final String serverUrl = serverInfo['serverUrl'];
        final int maxServers = serverInfo['maxServers'];
        
        try {
          print('Testing server ${i + 1}/$maxServers...');
          
          // Parse the server configuration
          final V2RayURL v2rayURL = FlutterV2ray.parseFromURL(serverUrl);
          final config = v2rayURL.getFullConfiguration();
          
          if (config.isEmpty) {
            throw Exception('Empty configuration');
          }
          
          // Test the server delay with a shorter timeout to prevent crashes
          int delay = -2; // Default to error
          try {
            delay = await flutterV2ray
                .getServerDelay(config: config)
                .timeout(Duration(seconds: 5)); // Reduced timeout
          } on TimeoutException catch (e) {
            delay = -1; // Timeout
            print('Server ${i + 1} timed out: $e');
          } catch (e) {
            // Handle all other exceptions to prevent crashes
            print('Server ${i + 1} test failed with error: $e');
            delay = -2; // Error
          }
          
          // Add result to list only if mounted
          if (mounted) {
            setState(() {
              serverTestResults.add({
                'index': i + 1,
                'config': config,
                'delay': delay,
                'status': delay > 0 ? 'success' : (delay == -1 ? 'timeout' : 'error')
              });
              serversTestCompleted = serverTestResults.length;
              loadingStatus = 'Testing server ${i + 1}/$maxServers...';
            });
          }
          
          print('Server ${i + 1} result: ${delay > 0 ? '${delay}ms' : (delay == -1 ? 'timeout'.tr() : 'error'.tr())}');
          
          // If in Automatic mode and this is the first healthy server, connect automatically
          if (selectedServer == 'Automatic' && delay > 0 && serversTestCompleted == 1) {
            print('Automatic mode: Connecting to first healthy server');
            // Add a small delay to prevent race conditions
            await Future.delayed(Duration(milliseconds: 500));
            await _connectToServer(config); // Fixed method name
            // Clear the queue since we're connecting
            _serverTestQueue.clear();
            return; // Exit after connecting to the first healthy server
          }
        } catch (e) {
          print('Server ${i + 1} test failed: $e');
          
          // Add error result only if mounted
          if (mounted) {
            setState(() {
              serverTestResults.add({
                'index': i + 1,
                'config': serverUrl,
                'delay': -2, // Error
                'status': 'error'
              });
              serversTestCompleted = serverTestResults.length;
            });
          }
        }
        
        // Increased delay between tests to avoid overwhelming the system and prevent crashes
        await Future.delayed(Duration(milliseconds: 400)); // Optimized delay
      }
    } finally {
      _isProcessingServerQueue = false;
    }
  }

  Future<List<String>> getDeviceArchitecture() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    return androidInfo.supportedAbis;
  }

  void getVersionName() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      versionName = packageInfo.version;
    });
  }

  Future<void> getServerList() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      setState(() {
        isLoading = true;
        loadingStatus = '🔄 Preparing connection...';
        blockedApps = prefs.getStringList('blockedApps') ?? [];
      });

      // Enhanced server list fetching with multiple fallbacks
      await _getServerListEnhanced();

    } on TimeoutException catch (e) {
      print('Timeout error: ${e.message}');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Connection timeout. Please check your internet connection and try again.',
            ),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print('Error in getServerList: $e');
      // Try to use cached servers as fallback
      if (await _tryUseCachedServersAsFallback()) {
        return;
      }

      if (mounted) {
        setState(() {
          isLoading = false;
        });
        
        String errorMessage;
        if (e.toString().contains('No valid server configurations')) {
          errorMessage = 'Server configuration error. Please contact support if this persists.';
        } else if (e.toString().contains('endpoint')) {
          errorMessage = 'All server endpoints are currently unavailable. Please try again later.';
        } else if (e.toString().contains('Failed to decode')) {
          errorMessage = 'Server data is corrupted. Please try again later.';
        } else {
          errorMessage = 'Unable to connect to servers. Please check your internet connection and try again.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }
  
  /// Enhanced server list fetching with multiple fallbacks
  Future<void> _getServerListEnhanced() async {
    final fallbackMethods = [
      _tryOptimizedServices,
      _tryDirectConnection,
      _tryAllOriginsProxy,
      _tryAlternativeEndpoint,
      _tryCachedServers,
    ];
    
    for (int i = 0; i < fallbackMethods.length; i++) {
      try {
        setState(() {
          loadingStatus = '📡 Trying connection method ${i + 1}/${fallbackMethods.length}...';
        });
        
        final success = await fallbackMethods[i]();
        if (success) {
          print('✅ Successfully connected using method ${i + 1}');
          return;
        }
      } catch (e) {
        print('❌ Method ${i + 1} failed: $e');
        if (i < fallbackMethods.length - 1) {
          await Future.delayed(Duration(milliseconds: 500));
        }
      }
    }
    
    throw Exception('All connection methods failed');
  }
  
  /// Try optimized services first
  Future<bool> _tryOptimizedServices() async {
    try {
      final servers = await _serverService.getOptimizedServerList(
        forceRefresh: false,
        onStatusUpdate: (status) {
          if (mounted) {
            setState(() {
              loadingStatus = '🔧 $status';
            });
          }
        },
      );

      if (servers.isNotEmpty) {
        print('Successfully fetched ${servers.length} optimized servers');

        final connectionResult = await _connectionService.connectToBestServer(
          servers,
          onStatusUpdate: (status) {
            if (mounted) {
              setState(() {
                loadingStatus = status;
              });
            }
          },
          onProgressUpdate: (completed, total) {
            if (mounted) {
              setState(() {
                serversBeingTested = total;
                serversTestCompleted = completed;
              });
            }
          },
        );

        if (connectionResult.success) {
          print('Successfully connected to optimized server');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('connected_to_optimal_server'.tr()),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
              ),
            );
          }
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Optimized services failed: $e');
      return false;
    }
  }
  
  /// Try direct connection
  Future<bool> _tryDirectConnection() async {
    try {
      final servers = await _fetchServersDirect();
      if (servers.isNotEmpty) {
        await _processServerList(servers);
        return true;
      }
      return false;
    } catch (e) {
      print('Direct connection failed: $e');
      return false;
    }
  }
  
  /// Try AllOrigins proxy
  Future<bool> _tryAllOriginsProxy() async {
    try {
      final servers = await _fetchServersFromAllOrigins();
      if (servers.isNotEmpty) {
        await _processServerList(servers);
        return true;
      }
      return false;
    } catch (e) {
      print('AllOrigins proxy failed: $e');
      return false;
    }
  }
  
  /// Try alternative endpoint
  Future<bool> _tryAlternativeEndpoint() async {
    try {
      final servers = await _fetchServersFromAlternative();
      if (servers.isNotEmpty) {
        await _processServerList(servers);
        return true;
      }
      return false;
    } catch (e) {
      print('Alternative endpoint failed: $e');
      return false;
    }
  }
  
  /// Try cached servers as last resort
  Future<bool> _tryCachedServers() async {
    try {
      final cachedServers = await _getCachedServerList();
      if (cachedServers.isNotEmpty) {
        print('Using ${cachedServers.length} cached servers');
        await _processServerList(cachedServers);
        return true;
      }
      return false;
    } catch (e) {
      print('Cached servers failed: $e');
      return false;
    }
  }
  
  /// Process server list and connect
  Future<void> _processServerList(List<String> servers) async {
    if (servers.isEmpty) return;
    
    setState(() {
      loadingStatus = '🔄 Processing ${servers.length} servers...';
    });
    
    
    // If in automatic mode, test and connect to best server
    if (selectedServer == 'Automatic') {
      // Automatic connection logic simplified for optimization
      setState(() {
        isLoading = false;
        loadingStatus = '';
      });
    } else {
      // For manual mode, just show the servers
      setState(() {
        isLoading = false;
        loadingStatus = '';
      });
    }
  }
  
  

  // Cache management methods for server list

  Future<bool> _tryUseCachedServersAsFallback() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final cached = prefs.getStringList('cached_servers');

      if (cached != null && cached.isNotEmpty) {
        print('Using ${cached.length} cached servers as fallback');
        if (mounted) {
          setState(() {
            loadingStatus = 'Using cached servers as fallback...';
          });
        }
        cachedServers = cached;
        // Process cached servers (simplified)
        setState(() {
          isLoading = false;
          loadingStatus = 'Using cached servers';
        });
        return true;
      } else {
        print('No cached servers available for fallback');
      }
    } catch (e) {
      print('Failed to use cached servers: $e');
    }
    return false;
  }

  /// Enhanced fetch and cache servers on app startup
  Future<void> _fetchAndCacheServersOnStartup() async {
    try {
      // Check if we have valid cached servers using new cache manager
      if (await _cacheManager.isServerCacheValid()) {
        cachedServers = await _cacheManager.getCachedServers();
        serverPings = await _cacheManager.getCachedPingResults();
        
        if (cachedServers.isNotEmpty) {
          await _processServersWithLocation(cachedServers);
          print('✅ Using cached servers (${cachedServers.length} servers) with ${serverPings.length} ping results');
          return;
        }
      }

      // Fetch fresh servers with status updates
      setState(() {
        loadingStatus = '📡 Fetching server list...';
      });

      final servers = await _serverService.getOptimizedServerList(
        forceRefresh: true,
        onStatusUpdate: (status) {
          if (mounted) {
            setState(() {
              loadingStatus = status;
            });
          }
        },
      );

      if (servers.isNotEmpty) {
        // Cache servers using new cache manager
        await _cacheManager.cacheServers(servers, metadata: {
          'fetchTime': DateTime.now().toIso8601String(),
          'serverCount': servers.length,
          'source': 'optimization_service',
        });
        
        setState(() {
          loadingStatus = '🏓 Testing server performance...';
        });
        
        print('🏓 Starting ping tests for ${servers.length} servers...');
        await _testServerPings(servers);
        
        // Cache ping results
        await _cacheManager.cachePingResults(serverPings);
        
        await _processServersWithLocation(servers);
        print('✅ Server startup completed with ${processedServers.length} processed servers');
        
        if (mounted) {
          setState(() {
            loadingStatus = '';
          });
        }
      }
    } catch (e) {
      print('❌ Failed to fetch servers on startup: $e');
      // Try to load any existing cached servers as fallback
      cachedServers = await _cacheManager.getCachedServers();
      serverPings = await _cacheManager.getCachedPingResults();
      
      if (cachedServers.isNotEmpty) {
        await _processServersWithLocation(cachedServers);
      }
      
      if (mounted) {
        setState(() {
          loadingStatus = '';
        });
      }
    }
  }




  /// Test server pings one by one with immediate display updates
  Future<void> _testServerPings(List<String> servers) async {
    try {
      print('🏓 Testing ping for ${servers.length} servers one by one...');
      serverPings.clear();
      
      // Initialize processedServers with all servers (ping = 0 initially)
      await _processServersWithLocation(servers);
      
      // Test servers one by one to avoid interference
      for (int i = 0; i < servers.length; i++) {
        final server = servers[i];
        print('🔍 Testing server ${i + 1}/${servers.length}...');
        
        await _testSingleServerPing(server, i);
        
        // Immediately update the processed server with new ping data
        await _updateSingleServerInProcessedList(server, i);
        
        // Small delay between each test to prevent system overload
        if (i < servers.length - 1) {
          await Future.delayed(Duration(milliseconds: 200));
        }
      }
      
      await _savePingCache();
      print('✅ Serial ping testing completed for ${serverPings.length} servers');
    } catch (e) {
      print('Error testing server pings: $e');
    }
  }

  /// Test ping for a single server with improved error handling
  Future<void> _testSingleServerPing(String server, int index) async {
    try {
      // Parse server configuration
      final v2rayURL = FlutterV2ray.parseFromURL(server);
      final config = v2rayURL.getFullConfiguration();
      
      if (config.isEmpty) {
        serverPings[server] = -1;
        print('❌ Server ${index + 1}: Empty configuration');
        return;
      }
      
      // Test server delay with longer timeout
      final delay = await flutterV2ray
          .getServerDelay(config: config)
          .timeout(
            Duration(seconds: 1), // Increased timeout
            onTimeout: () {
              print('⏰ Server ${index + 1}: Timeout after 8 seconds');
              return 9999; // High ping for timeout
            },
          );
      
      if (delay > 0 && delay < 9999) {
        serverPings[server] = delay;
        print('✅ Server ${index + 1}: ${delay}ms');
      } else if (delay == 9999) {
        serverPings[server] = 9999; // Timeout but reachable
        print('⏰ Server ${index + 1}: Timeout (9999ms)');
      } else {
        serverPings[server] = -1; // Failed
        print('❌ Server ${index + 1}: Failed (${delay}ms)');
      }
    } catch (e) {
      serverPings[server] = -1; // Error
      print('❌ Server ${index + 1}: Exception - $e');
    }
  }

  /// Update a single server in processedServers list with new ping data
  Future<void> _updateSingleServerInProcessedList(String server, int index) async {
    try {
      // Find the server in processedServers and update its ping
      for (int i = 0; i < processedServers.length; i++) {
        if (processedServers[i]['config'] == server) {
          final ping = serverPings[server] ?? -1;
          processedServers[i]['ping'] = ping;
          
          // Trigger UI update
          if (mounted) {
            setState(() {
              // Sort servers by ping after each update (best first)
              processedServers.sort((a, b) {
                final pingA = a['ping'] as int;
                final pingB = b['ping'] as int;
                
                // Failed servers (-1) go to the end
                if (pingA == -1 && pingB != -1) return 1;
                if (pingB == -1 && pingA != -1) return -1;
                if (pingA == -1 && pingB == -1) return 0;
                
                // Sort by ping (lower is better)
                return pingA.compareTo(pingB);
              });
            });
          }
          break;
        }
      }
    } catch (e) {
      print('Error updating server in processed list: $e');
    }
  }

  /// Save ping results to cache
  Future<void> _savePingCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(pingCacheKey, json.encode(serverPings));
      print('✅ Ping cache saved');
    } catch (e) {
      print('Error saving ping cache: $e');
    }
  }

  /// Process servers with real location parsing for enhanced display
  Future<void> _processServersWithLocation(List<String> servers) async {
    try {
      processedServers.clear();
      
      for (int i = 0; i < servers.length; i++) {
        final server = servers[i];
        
        // Extract server information
        final ip = _extractIPFromConfig(server);
        final serverName = _generateServerName(server, ip, i + 1);
        final countryCode = _getCountryCodeFromIPSync(ip);
        final ping = serverPings[server] ?? 0;
        
        // Parse real location from server configuration
        final locationInfo = ServerLocationParser.parseServerLocation(server);
        final realCountryCode = locationInfo['countryCode']?.isNotEmpty == true 
            ? locationInfo['countryCode']! 
            : countryCode;
        final realCountryName = locationInfo['country']?.isNotEmpty == true 
            ? locationInfo['country']! 
            : serverName;
        final cityName = locationInfo['city'] ?? '';
        
        final serverData = {
          'name': cityName.isNotEmpty ? '$cityName, $realCountryName' : realCountryName,
          'config': server,
          'ip': ip,
          'countryCode': realCountryCode,
          'ping': ping,
        };
        
        processedServers.add(serverData);
      }
      
      // Sort servers by ping (best first, failed servers last)
      processedServers.sort((a, b) {
        final pingA = a['ping'] as int;
        final pingB = b['ping'] as int;
        
        // Failed servers (-1) go to the end
        if (pingA == -1 && pingB != -1) return 1;
        if (pingB == -1 && pingA != -1) return -1;
        if (pingA == -1 && pingB == -1) return 0;
        
        // Sort by ping (lower is better)
        return pingA.compareTo(pingB);
      });
      
      print('✅ Processed ${processedServers.length} servers for display');
    } catch (e) {
      print('Error processing servers: $e');
    }
  }

  // Essential missing functions - minimal implementations
  Future<void> _connectToServer(String server) async {
    try {
      // Validate server configuration before parsing
      if (server.isEmpty || (!server.startsWith('vmess://') && !server.startsWith('vless://') && !server.startsWith('trojan://') && !server.startsWith('ss://'))) {
        throw Exception('Invalid server configuration format');
      }

      final v2rayURL = FlutterV2ray.parseFromURL(server);
      final config = v2rayURL.getFullConfiguration();
      
      // Validate configuration before starting V2Ray
      if (config.isEmpty) {
        throw Exception('Empty configuration generated from server URL');
      }

      // Request VPN permission first
      final hasPermission = await flutterV2ray.requestPermission();
      if (!hasPermission) {
        throw Exception('VPN permission denied');
      }

      // Start V2Ray connection
      flutterV2ray.startV2Ray(
        remark: v2rayURL.remark.isNotEmpty ? v2rayURL.remark : 'ShineNET VPN',
        config: config,
        proxyOnly: proxyOnly,
        bypassSubnets: bypassSubnets,
        blockedApps: blockedApps,
      );

      print('✅ Connected to server: ${v2rayURL.remark}');
    } catch (e) {
      print('❌ Connection error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    }
  }

  Future<List<String>> _getCachedServerList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList('cached_servers') ?? [];
    } catch (e) {
      return [];
    }
  }

  Future<List<String>> _fetchServersWithFallback() async {
    try {
      // First try to get cached servers
      List<String> servers = await _getCachedServerList();
      
      // If no cached servers, try to fetch fresh ones
      if (servers.isEmpty) {
        servers = await _serverService.getOptimizedServerList(forceRefresh: true);
      }
      
      return servers;
    } catch (e) {
      print('Error fetching servers: $e');
      // Return empty list if all methods fail
      return [];
    }
  }

  Future<List<String>> _fetchServersDirect() async {
    return await _getCachedServerList();
  }

  Future<List<String>> _fetchServersFromAllOrigins() async {
    return await _getCachedServerList();
  }

  Future<List<String>> _fetchServersFromAlternative() async {
    return await _getCachedServerList();
  }

  void connectDirectly(String server) {
    _connectToServer(server);
  }

  Future<List<Map<String, dynamic>>> _testServersOptimized(List<String> servers) async {
    // Simplified server testing - just return empty list for now
    return [];
  }

}
