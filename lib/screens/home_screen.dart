import 'dart:async';
import 'dart:convert';

import 'package:shinenet_vpn/common/http_client.dart';
import 'package:shinenet_vpn/widgets/server_selection_modal_widget.dart';
import 'package:shinenet_vpn/widgets/vpn_status.dart';
import 'package:shinenet_vpn/widgets/connection_widget.dart';
import 'package:shinenet_vpn/widgets/statistics_card.dart';
import 'package:shinenet_vpn/services/server_optimization_service.dart';
import 'package:shinenet_vpn/services/connection_optimization_service.dart';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../common/theme.dart';

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

  // UI State
  bool isLoading = false;
  String loadingStatus = '';
  int serversBeingTested = 0;
  int serversTestCompleted = 0;
  
  // Individual server test results
  List<Map<String, dynamic>> serverTestResults = [];
  bool isTestingServers = false;

  // Server State
  String selectedServer = 'Automatic';
  String selectedServerType = 'Automatic'; // Changed from selectedServerLogo
  int? connectedServerDelay;
  bool isFetchingPing = false;

  // Additional State
  bool proxyOnly = false;
  List<String> bypassSubnets = [];
  String? coreVersion;
  String? versionName;
  late SharedPreferences _prefs;
  List<String> blockedApps = [];

  // Server caching variables
  List<String>? cachedServers;
  List<String> _serverList = [];
  DateTime? lastServerFetch;
  static const Duration cacheExpiry = Duration(minutes: 10);
  static const String cacheKey = 'cached_servers';
  static const String cacheTimeKey = 'cache_timestamp';

  // Connection retry variables
  int connectionRetryCount = 0;
  static const int maxRetries = 3;
  static const Duration initialRetryDelay = Duration(seconds: 2);
  
  // Add fallback connection flag
  bool _useDirectConnection = false;
  bool _skipPingTests = false; // User preference to skip ping tests
  
  // Add server testing protection flag
  bool _isServerTestingInProgress = false;
  
  // Add a queue for server testing to prevent resource exhaustion
  final List<Map<String, dynamic>> _serverTestQueue = [];
  bool _isProcessingServerQueue = false;
  
  // Connection analytics
  DateTime? _connectionStartTime;
  int _totalConnectionAttempts = 0;
  int _successfulConnections = 0;
  int _failedConnections = 0;
  double _averageConnectionTime = 0.0;
  
  // Enhanced server testing
  List<Map<String, dynamic>> _serverTestResults = [];
  static const Duration _testCacheExpiry = Duration(minutes: 5);
  static const String _testCacheKey = 'server_test_results';
  static const String _testCacheTimeKey = 'server_test_cache_time';

  Future<void> _initializeServices() async {
    try {
      await _serverService.initialize();
      await _connectionService.initialize();
      await _loadConnectionAnalytics();
      
      // Start background testing for continuous optimization
      _startBackgroundTesting();
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
    _connectionStartTime = DateTime.now();
    
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
      'failedConnections': _failedConnections,
      'successRate': connectionSuccessRate,
      'averageConnectionTime': _averageConnectionTime,
      'optimizationServiceStats': _connectionService.getConnectionStats(),
    };
  }
  
  /// Get cached test results
  Future<List<Map<String, dynamic>>?> _getCachedTestResults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final resultsString = prefs.getString(_testCacheKey);
      if (resultsString != null) {
        final List<dynamic> resultsList = json.decode(resultsString);
        return resultsList.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      print('Error loading cached test results: $e');
    }
    return null;
  }
  
  /// Check if cache is valid
  Future<bool> _isCacheValid(List<Map<String, dynamic>> results) async {
    if (results.isEmpty) return false;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheTimeString = prefs.getString(_testCacheTimeKey);
      if (cacheTimeString == null) return false;
      
      final cacheTime = DateTime.parse(cacheTimeString);
      return DateTime.now().difference(cacheTime) < _testCacheExpiry;
    } catch (e) {
      return false;
    }
  }
  
  /// Cache test results
  Future<void> _cacheTestResults(List<Map<String, dynamic>> results) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_testCacheKey, json.encode(results));
      await prefs.setString(_testCacheTimeKey, DateTime.now().toIso8601String());
    } catch (e) {
      print('Error caching test results: $e');
    }
  }
  
  /// Update UI with cached results
  void _updateUIWithCachedResults() {
    if (!mounted) return;
    
    setState(() {
      serverTestResults = _serverTestResults;
      serversTestCompleted = _serverTestResults.length;
      loadingStatus = '📋 Using cached results (${_serverTestResults.length} servers)';
    });
  }
  
  /// Test servers with priority-based approach
  Future<void> _testServersWithPriority(List<String> servers) async {
    _serverTestResults.clear();
    
    // Sort servers by priority (best performing first)
    final prioritizedServers = await _prioritizeServers(servers);
    
    // Test servers in batches with different priorities
    await _testServerBatches(prioritizedServers);
  }
  
  /// Prioritize servers based on historical performance (simplified)
  Future<List<String>> _prioritizeServers(List<String> servers) async {
    // Simple prioritization without testing all servers
    // Just shuffle and take first few for faster startup
    final shuffledServers = List<String>.from(servers);
    shuffledServers.shuffle();
    
    // Return first 15 servers for testing
    return shuffledServers.take(15).toList();
  }
  
  /// Calculate server priority score
  double _calculateServerPriorityScore(int delay, int responseTime) {
    double score = 100.0;
    
    // Delay penalty (lower is better)
    if (delay > 0) {
      score -= (delay / 10.0);
    } else {
      score -= 50.0; // Penalty for failed tests
    }
    
    // Response time penalty
    score -= (responseTime / 20.0);
    
    return score.clamp(0.0, 100.0);
  }
  
  /// Test servers in batches with different priorities
  Future<void> _testServerBatches(List<String> servers) async {
    const int highPriorityBatch = 3;  // Test top 3 servers first
    const int mediumPriorityBatch = 6; // Then next 3 servers
    
    // High priority batch - test immediately
    if (servers.length >= highPriorityBatch) {
      await _testServerBatch(servers.sublist(0, highPriorityBatch), 'High Priority');
    }
    
    // Medium priority batch - test with delay
    if (servers.length > highPriorityBatch) {
      await Future.delayed(Duration(milliseconds: 300));
      final endIndex = servers.length >= mediumPriorityBatch ? mediumPriorityBatch : servers.length;
      await _testServerBatch(servers.sublist(highPriorityBatch, endIndex), 'Medium Priority');
    }
    
    // Remaining servers - test in background
    if (servers.length > mediumPriorityBatch) {
      Future.delayed(Duration(seconds: 1), () {
        _testServerBatch(servers.sublist(mediumPriorityBatch), 'Background');
      });
    }
  }
  
  /// Test a batch of servers
  Future<void> _testServerBatch(List<String> servers, String priority) async {
    print('🧪 Testing $priority batch: ${servers.length} servers');
    
    for (int i = 0; i < servers.length && mounted; i++) {
      final server = servers[i];
      
      try {
        final v2rayURL = FlutterV2ray.parseFromURL(server);
        final config = v2rayURL.getFullConfiguration();
        
        if (config.isEmpty) continue;
        
        final startTime = DateTime.now();
        final delay = await flutterV2ray
            .getServerDelay(config: config)
            .timeout(Duration(seconds: 2)); // Reduced timeout
        final responseTime = DateTime.now().difference(startTime).inMilliseconds;
        
        final result = {
          'index': i + 1,
          'config': config,
          'delay': delay,
          'responseTime': responseTime,
          'status': delay > 0 ? 'success' : (delay == -1 ? 'timeout' : 'error'),
          'priority': priority,
          'timestamp': DateTime.now().toIso8601String(),
        };
        
        _serverTestResults.add(result);
        
        if (mounted) {
          setState(() {
            serverTestResults = List.from(_serverTestResults);
            serversTestCompleted = _serverTestResults.length;
            loadingStatus = '🔍 $priority testing... (${_serverTestResults.length} tested)';
          });
        }
        
        print('✅ $priority Server ${i + 1}: ${delay > 0 ? '${delay}ms' : (delay == -1 ? 'Timeout' : 'Error')}');
        
        // Very short delay between tests for better performance
        await Future.delayed(Duration(milliseconds: 150));
        
      } catch (e) {
        print('❌ $priority Server ${i + 1} failed: $e');
        
        final result = {
          'index': i + 1,
          'config': '',
          'delay': -2,
          'responseTime': 0,
          'status': 'error',
          'priority': priority,
          'timestamp': DateTime.now().toIso8601String(),
        };
        
        _serverTestResults.add(result);
      }
    }
  }

  Future<void> _getServerListFallback() async {
    // Simple fallback implementation
    setState(() {
      loadingStatus = 'Using fallback method...';
    });
    
    // Use the existing connect method with a simple server list
    // This is a minimal implementation to ensure the app still works
    try {
      // You can implement a simple server fetching here
      // For now, we'll just show an error message
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('server_connection_failed'.tr()),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Fallback method also failed: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeServices();
    getVersionName();
    _loadServerSelection();
    flutterV2ray
        .initializeV2Ray(
      notificationIconResourceType: "mipmap",
      notificationIconResourceName: "launcher_icon",
    )
        .then((value) async {
      coreVersion = await flutterV2ray.getCoreVersion();

      setState(() {});
      Future.delayed(
        Duration(seconds: 1),
        () {
          if (v2rayStatus.value.state == 'CONNECTED') {
            delay();
          }
        },
      );
      
      // Automatically test servers after app initialization to speed up finding healthy servers
      Future.delayed(
        Duration(milliseconds: 800), // Much faster startup
        () {
          // Only test servers if not already connected or connecting
          if (mounted && v2rayStatus.value.state != 'CONNECTED' && v2rayStatus.value.state != 'CONNECTING') {
            _testServersAutomatically();
          }
        },
      );
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
                    titlePadding: EdgeInsets.symmetric(
                      horizontal: ThemeColor.mediumSpacing,
                      vertical: ThemeColor.smallSpacing,
                    ),
                    title: Text(
                      'ShineNET VPN',
                      style: ThemeColor.headingStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
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

  // Modern connection status card
  Widget _buildConnectionStatusCard(bool isConnected, bool isConnecting) {
    String statusText;
    Color statusColor;
    IconData statusIcon;
    
    if (isConnected) {
      statusText = 'connected'.tr();
      statusColor = ThemeColor.successColor;
      statusIcon = Icons.check_circle_rounded;
    } else if (isConnecting) {
      statusText = 'connecting'.tr();
      statusColor = ThemeColor.warningColor;
      statusIcon = Icons.sync_rounded;
    } else {
      statusText = 'disconnected'.tr();
      statusColor = ThemeColor.mutedText;
      statusIcon = Icons.radio_button_unchecked_rounded;
    }
    
    return AnimatedContainer(
      duration: ThemeColor.mediumAnimation,
      padding: EdgeInsets.all(ThemeColor.largeSpacing),
      decoration: ThemeColor.cardDecoration(
        withGradient: isConnected,
        withShadow: true,
      ),
      child: Row(
        children: [
          AnimatedRotation(
            turns: isConnecting ? 1 : 0,
            duration: ThemeColor.slowAnimation,
            child: Icon(
              statusIcon,
              color: statusColor,
              size: 28,
            ),
          ),
          SizedBox(width: ThemeColor.mediumSpacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connection Status',
                  style: ThemeColor.captionStyle(
                    color: ThemeColor.mutedText,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  statusText,
                  style: ThemeColor.bodyStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          if (isConnected && connectedServerDelay != null)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: ThemeColor.smallSpacing,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: ThemeColor.successColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
                border: Border.all(
                  color: ThemeColor.successColor.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '${connectedServerDelay}ms',
                style: ThemeColor.captionStyle(
                  color: ThemeColor.successColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Modern server selection card
  Widget _buildModernServerSelectionCard() {
    return AnimatedContainer(
      duration: ThemeColor.mediumAnimation,
      decoration: ThemeColor.cardDecoration(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
          onTap: () => _showServerSelectionModal(context),
          child: Padding(
            padding: EdgeInsets.all(ThemeColor.mediumSpacing),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ThemeColor.buildServerIcon(
                      serverType: selectedServer,
                      size: 24,
                      isSelected: v2rayStatus.value.state == 'CONNECTED',
                    ),
                    SizedBox(width: ThemeColor.mediumSpacing),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selected Server',
                            style: ThemeColor.captionStyle(),
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              ThemeColor.buildConnectionIndicator(
                                status: v2rayStatus.value.state,
                              ),
                              SizedBox(width: ThemeColor.smallSpacing),
                              Expanded(
                                child: Text(
                                  selectedServer,
                                  style: ThemeColor.bodyStyle(
                                    fontWeight: FontWeight.w600,
                                    color: ThemeColor.primaryText,
                                  ),
                                ),
                              ),
                            ],
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
              ],
            ),
          ),
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
            value: _formatDuration(status.duration),
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
            value: '${formatBytes(status.downloadSpeed)}/s',
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
        Icon(icon, color: color, size: 20),
        SizedBox(height: 4),
        Text(
          value,
          style: ThemeColor.bodyStyle(
            fontWeight: FontWeight.w600,
            color: color,
            fontSize: 14,
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
                    value: formatBytes(status.download),
                    color: ThemeColor.successColor,
                  ),
                ),
                SizedBox(width: ThemeColor.smallSpacing),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.upload_rounded,
                    label: 'upload'.tr(),
                    value: formatBytes(status.upload),
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
          Icon(icon, color: color, size: 24),
          SizedBox(height: ThemeColor.smallSpacing),
          Text(
            value,
            style: ThemeColor.bodyStyle(
              fontWeight: FontWeight.w700,
              color: color,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: ThemeColor.captionStyle(
              color: color.withValues(alpha: 0.8),
            ),
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

  // Quick actions card for mobile
  Widget _buildQuickActionsCard() {
    return AnimatedContainer(
      duration: ThemeColor.mediumAnimation,
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
                  'Quick Actions',
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
                    label: 'Test Servers',
                    color: ThemeColor.primaryColor,
                    onTap: isLoading ? null : testServersManually,
                  ),
                ),
                SizedBox(width: ThemeColor.smallSpacing),
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.refresh_rounded,
                    label: 'Refresh',
                    color: ThemeColor.successColor,
                    onTap: isLoading ? null : () async {
                      setState(() {
                        isLoading = true;
                        loadingStatus = 'Refreshing...';
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
                    label: 'Test All Servers',
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

  Widget _buildWideScreenLayout(V2RayStatus value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: _buildConnectionSection(value),
        ),
        SizedBox(width: ThemeColor.largeSpacing),
        if (value.state == 'CONNECTED')
          Expanded(
            flex: 3,
            child: _buildStatsSection(value),
          ),
      ],
    );
  }

  Widget _buildMobileLayout(V2RayStatus value) {
    return Column(
      children: [
        _buildConnectionSection(value),
        if (value.state == 'CONNECTED') ...[
          SizedBox(height: ThemeColor.largeSpacing),
          _buildStatsSection(value),
        ],
      ],
    );
  }

  Widget _buildConnectionSection(V2RayStatus value) {
    return Container(
      decoration: ThemeColor.cardDecoration(),
      child: Padding(
        padding: EdgeInsets.all(ThemeColor.largeSpacing),
        child: Column(
          children: [
            ConnectionWidget(
              onTap: () => _handleConnectionTap(value),
              isLoading: isLoading,
              status: value.state,
            ),
            if (isLoading && loadingStatus.isNotEmpty) ...[
              SizedBox(height: ThemeColor.mediumSpacing),
              _buildLoadingStatus(),
            ],
            if (value.state == 'CONNECTED') ...[
              SizedBox(height: ThemeColor.mediumSpacing),
              _buildDelayIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(V2RayStatus value) {
    return Column(
      children: [
        // Enhanced statistics card
        StatisticsCard(
          downloadSpeed: value.downloadSpeed,
          uploadSpeed: value.uploadSpeed,
          download: value.download,
          upload: value.upload,
          duration: value.duration,
          isConnected: value.state == 'CONNECTED',
        ),
        SizedBox(height: ThemeColor.mediumSpacing),
        // Original VPN card for additional info
        Container(
      decoration: ThemeColor.cardDecoration(),
      child: Padding(
        padding: EdgeInsets.all(ThemeColor.largeSpacing),
        child: VpnCard(
          download: value.download,
          upload: value.upload,
          downloadSpeed: value.downloadSpeed,
          uploadSpeed: value.uploadSpeed,
          selectedServer: selectedServer,
          selectedServerType: selectedServerType,
          duration: value.duration,
        ),
      ),
        ),
      ],
    );
  }

  Widget _buildDelayIndicator() {
    return AnimatedContainer(
      duration: ThemeColor.mediumAnimation,
      margin: EdgeInsets.only(top: ThemeColor.smallSpacing),
      padding: EdgeInsets.symmetric(
        horizontal: ThemeColor.mediumSpacing,
        vertical: ThemeColor.smallSpacing,
      ),
      decoration: BoxDecoration(
        color: connectedServerDelay == null
            ? ThemeColor.connectingColor.withValues(alpha: 0.1)
            : ThemeColor.connectedColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ThemeColor.largeRadius),
        border: Border.all(
          color: connectedServerDelay == null
              ? ThemeColor.connectingColor.withValues(alpha: 0.3)
              : ThemeColor.connectedColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: connectedServerDelay == null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LoadingAnimationWidget.threeArchedCircle(
                  color: ThemeColor.connectingColor,
                  size: 16,
                ),
                SizedBox(width: ThemeColor.smallSpacing),
                Text(
                  'Testing...',
                  style: ThemeColor.captionStyle(
                    color: ThemeColor.connectingColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            )
          : Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(ThemeColor.largeRadius),
                onTap: delay,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: ThemeColor.smallSpacing,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.wifi_rounded,
                        color: ThemeColor.connectedColor,
                        size: 16,
                      ),
                      SizedBox(width: ThemeColor.smallSpacing),
                      Text(
                        '${connectedServerDelay}ms',
                        style: ThemeColor.captionStyle(
                          color: ThemeColor.connectedColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.refresh_rounded,
                        color: ThemeColor.connectedColor,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildLoadingStatus() {
    return Container(
      padding: EdgeInsets.all(ThemeColor.mediumSpacing),
      decoration: ThemeColor.cardDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(ThemeColor.smallSpacing),
                decoration: BoxDecoration(
                  color: ThemeColor.connectingColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
                ),
                child: LoadingAnimationWidget.threeArchedCircle(
                  color: ThemeColor.connectingColor,
                  size: 24,
                ),
              ),
              SizedBox(width: ThemeColor.mediumSpacing),
              Flexible(
                child: Text(
                  loadingStatus,
                  style: ThemeColor.bodyStyle(
                    fontSize: 14,
                    color: ThemeColor.secondaryText,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          if (serversBeingTested > 0 && serversTestCompleted > 0) ...[
            SizedBox(height: ThemeColor.mediumSpacing),
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Testing servers...',
                      style: ThemeColor.captionStyle(),
                    ),
                    Text(
                      '$serversTestCompleted/$serversBeingTested',
                      style: ThemeColor.captionStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: ThemeColor.smallSpacing),
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: ThemeColor.surfaceColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Stack(
                    children: [
                      AnimatedContainer(
                        duration: ThemeColor.mediumAnimation,
                        width: (MediaQuery.of(context).size.width - 80) *
                            (serversTestCompleted / serversBeingTested),
                        height: 4,
                        decoration: BoxDecoration(
                          gradient: ThemeColor.primaryGradient,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _handleConnectionTap(V2RayStatus value) async {
    if (value.state == "DISCONNECTED") {
      connectionRetryCount = 0; // Reset retry count for new connection attempt
      _useDirectConnection = false; // Reset direct connection flag
      
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
  
  /// Simple automatic connection method
  Future<void> _connectAutomaticSimple() async {
    try {
      // Add overall timeout for the entire connection process
      await Future.any([
        _performSimpleConnection(),
        Future.delayed(Duration(seconds: 45), () {
          throw TimeoutException('Connection process timed out', Duration(seconds: 45));
        }),
      ]);
      
    } catch (e) {
      print('Simple automatic connection failed: $e');
      rethrow;
    }
  }
  
  /// Perform the actual simple connection
  Future<void> _performSimpleConnection() async {
    // First, try to use cached test results
    final cachedResults = await _getCachedTestResults();
    if (cachedResults != null && await _isCacheValid(cachedResults)) {
      print('📋 Using cached test results (${cachedResults.length} servers)');
      
      // Filter healthy servers from cache
      final healthyServers = cachedResults
          .where((result) => result['status'] == 'success' && result['delay'] > 0)
          .toList();
      
      if (healthyServers.isNotEmpty) {
        // Sort by delay and connect to best cached server
        healthyServers.sort((a, b) => a['delay'].compareTo(b['delay']));
        final bestServer = healthyServers.first;
        
        setState(() {
          loadingStatus = '🚀 Connecting to cached best server (${bestServer['delay']}ms)...';
        });
        
        await _connectToServer(
          bestServer['config'],
          minPing: bestServer['delay'],
        );
        return;
      }
    }
    
    // If no valid cached results, try cached servers
    final cachedServers = await _getCachedServerList();
    if (cachedServers.isNotEmpty) {
      print('📋 Using cached server list (${cachedServers.length} servers)');
      
      setState(() {
        loadingStatus = '🧪 Testing cached servers...';
      });

      // Test first 3 cached servers quickly
      final testResults = await _testServersOptimized(cachedServers.take(3).toList());
      
      if (testResults.isNotEmpty) {
        // Sort by delay and connect to best
        testResults.sort((a, b) => a['delay'].compareTo(b['delay']));
        final bestServer = testResults.first;
        
        setState(() {
          loadingStatus = '🚀 Connecting to best cached server (${bestServer['delay']}ms)...';
        });
        
        await _connectToServer(
          bestServer['config'],
          minPing: bestServer['delay'],
        );
        return;
      }
    }
    
    // If no cached data available, fetch fresh servers
    setState(() {
      loadingStatus = '📡 Fetching fresh servers...';
    });

    final servers = await _fetchServersWithFallback();
    if (servers.isEmpty) {
      throw Exception('No servers available');
    }

    setState(() {
      loadingStatus = '🧪 Testing fresh servers...';
    });

    // Test first 3 servers quickly
    final testResults = await _testServersOptimized(servers.take(3).toList());
    
    if (testResults.isNotEmpty) {
      // Sort by delay and connect to best
      testResults.sort((a, b) => a['delay'].compareTo(b['delay']));
      final bestServer = testResults.first;
      
      setState(() {
        loadingStatus = '🚀 Connecting to best fresh server (${bestServer['delay']}ms)...';
      });
      
      await _connectToServer(
        bestServer['config'],
        minPing: bestServer['delay'],
      );
    } else {
      // No healthy servers, try direct connection
      print('No healthy servers found, trying direct connection...');
      await connectDirectly(servers.take(2).toList());
    }
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
        await connectDirectly(servers.take(3).toList());
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
        
        await Future.delayed(Duration(milliseconds: 200));
        
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
              _skipPingTests = true;
              setState(() {
                isLoading = true;
              });
              await getServerList();
            } else {
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
        // Convert server test results to ServerInfo objects
        final healthyServers = serverTestResults
            .where((result) => result['status'] == 'success' && result['delay'] > 0)
            .map((result) {
              // Extract server name and IP from config
              final config = result['config'] as String;
              final index = result['index'] as int;
              final ping = result['delay'] as int;
              
              // Extract IP from config
              final ip = _extractIPFromConfig(config);
              
              // Generate a more descriptive server name
              final serverName = _generateServerName(config, ip, index);
              
              // Create a ServerInfo object
              return ServerInfo(
                name: serverName,
                config: config,
                ip: ip,
                countryCode: _getCountryCodeFromIPSync(ip), // Use sync version for immediate display
                ping: ping,
              );
            })
            .toList();
        
        return ServerSelectionModal(
          selectedServer: selectedServer,
          onServerSelected: (server) {
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
            
            if (v2rayStatus.value.state == "DISCONNECTED") {
              // If the selected server is 'Automatic', just save the selection and close the modal
              if (server == 'Automatic') {
                setState(() {
                  selectedServer = server;
                });
                _saveServerSelection(server);
                Navigator.pop(context);
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
                _connectToServer(server);
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
          healthyServers: healthyServers,
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
  
  // Get country code from IP (asynchronous implementation using ipwho.is)
  Future<String?> _getCountryCodeFromIP(String? ip) async {
    if (ip == null || ip.isEmpty) return null;
    
    try {
      final dio = Dio();
      final response = await dio.get(
        'https://ipwho.is/$ip',
        options: Options(
          headers: {
            'X-Content-Type-Options': 'nosniff',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data != null && data is Map) {
          // Check if the request was successful
          if (data['success'] == true) {
            return data['country_code'] as String? ?? 'US';
          }
        }
      }
    } catch (e) {
      print('Error getting country code for IP $ip: $e');
    }
    
    // Fallback to sync version
    return _getCountryCodeFromIPSync(ip);
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
        throw Exception('No servers found to test');
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
        throw Exception('No servers found to test');
      }

      print('Manually testing ${servers.length} servers...');
      
      setState(() {
        serversBeingTested = servers.length > 15 ? 15 : servers.length; // Limit to 15 for manual testing
        serversTestCompleted = 0;
        loadingStatus = 'Testing servers with optimized method...';
      });

      // Use optimized testing method
      final testResults = await _testServersOptimized(servers.take(15).toList());
      
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
          
          print('Server ${i + 1} result: ${delay > 0 ? '${delay}ms' : (delay == -1 ? 'Timeout' : 'Error')}');
          
          // If in Automatic mode and this is the first healthy server, connect automatically
          if (selectedServer == 'Automatic' && delay > 0 && serversTestCompleted == 1) {
            print('Automatic mode: Connecting to first healthy server');
            // Add a small delay to prevent race conditions
            await Future.delayed(Duration(milliseconds: 500));
            await _connectToServer(config, minPing: delay); // Fixed method name
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
        await Future.delayed(Duration(milliseconds: 800)); // Increased from 600ms to 800ms
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
          await Future.delayed(Duration(milliseconds: 1000));
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
    
    // Store servers for later use
    _serverList = servers;
    
    // If in automatic mode, test and connect to best server
    if (selectedServer == 'Automatic') {
      await _testAndConnectAutomatic(servers);
    } else {
      // For manual mode, just show the servers
      setState(() {
        isLoading = false;
        loadingStatus = '';
      });
    }
  }
  
  /// Sequential server testing using flutter_v2ray methods (one by one to prevent crashes)
  Future<List<Map<String, dynamic>>> _testServersOptimized(List<String> servers) async {
    final testResults = <Map<String, dynamic>>[];
    
    print('🚀 Starting sequential testing of ${servers.length} servers...');
    
    // Test servers one by one to prevent crashes
    for (int i = 0; i < servers.length; i++) {
      if (!mounted) break;
      
      final serverIndex = i + 1;
      final result = await _testSingleServerOptimized(servers[i], serverIndex, servers.length);
      
      if (result != null && result['delay'] > 0) {
        testResults.add(result);
      }
      
      // Update UI
      if (mounted) {
        setState(() {
          loadingStatus = '🧪 Tested ${testResults.length}/${servers.length} servers...';
        });
      }
      
      // Small delay between tests to prevent resource exhaustion
      await Future.delayed(Duration(milliseconds: 300));
    }
    
    print('✅ Sequential testing completed: ${testResults.length} working servers found');
    return testResults;
  }
  
  /// Test a single server with optimized error handling
  Future<Map<String, dynamic>?> _testSingleServerOptimized(String server, int index, int total) async {
    const timeout = Duration(seconds: 3); // Define timeout locally
    
    try {
      // Parse server configuration
      final v2rayURL = FlutterV2ray.parseFromURL(server);
      final config = v2rayURL.getFullConfiguration();
      
      if (config.isEmpty) {
        print('⚠️ Server $index/$total: Invalid configuration');
        return null;
      }
      
      final startTime = DateTime.now();
      int delay = -2; // Default to error
      
      try {
        // Use flutter_v2ray's getServerDelay method with proper timeout
        delay = await flutterV2ray
            .getServerDelay(config: config)
            .timeout(timeout);
            
      } on TimeoutException {
        delay = -1; // Timeout
        print('⏰ Server $index/$total: Timeout');
      } catch (e) {
        delay = -2; // Error
        print('❌ Server $index/$total: Error - $e');
      }
      
      final responseTime = DateTime.now().difference(startTime).inMilliseconds;
      
      if (delay > 0) {
        print('✅ Server $index/$total: ${delay}ms');
        return {
          'server': server,
          'config': config,
          'delay': delay,
          'responseTime': responseTime,
          'index': index,
          'status': 'success',
        };
      }
      
      return null;
      
    } catch (e) {
      print('❌ Server $index/$total failed: $e');
      return null;
    }
  }

  /// Test and connect in automatic mode - Optimized version with cache integration
  Future<void> _testAndConnectAutomatic(List<String> servers) async {
    try {
      // First, try to use cached test results
      final cachedResults = await _getCachedTestResults();
      if (cachedResults != null && await _isCacheValid(cachedResults)) {
        print('📋 Using cached test results for automatic connection (${cachedResults.length} servers)');
        
        // Filter healthy servers from cache
        final healthyServers = cachedResults
            .where((result) => result['status'] == 'success' && result['delay'] > 0)
            .toList();
        
        if (healthyServers.isNotEmpty) {
          // Sort by delay and connect to best cached server
          healthyServers.sort((a, b) => a['delay'].compareTo(b['delay']));
          final bestServer = healthyServers.first;
          
          setState(() {
            loadingStatus = '🚀 Connecting to cached best server (${bestServer['delay']}ms)...';
          });
          
          await _connectToServer(
            bestServer['config'],
            minPing: bestServer['delay'],
          );
          return;
        }
      }
      
      // If no valid cached results, test fresh servers
      setState(() {
        loadingStatus = '🧪 Testing servers for automatic connection...';
      });
      
      // Use optimized testing with proper flutter_v2ray methods
      final testResults = await _testServersOptimized(servers.take(8).toList());
      
      if (testResults.isNotEmpty) {
        // Sort by delay (lowest first)
        testResults.sort((a, b) => a['delay'].compareTo(b['delay']));
        
        final bestServer = testResults.first;
        print('🏆 Connecting to best server: ${bestServer['delay']}ms');
        
        // Cache the test results for future use
        await _cacheTestResults(testResults);
        
        await _connectToServer(
          bestServer['config'],
          minPing: bestServer['delay'],
        );
      } else {
        print('❌ No working servers found, trying direct connection...');
        await connectDirectly(servers);
      }
      
    } catch (e) {
      print('❌ Automatic connection failed: $e');
      await connectDirectly(servers);
    }
  }
  
  /// Get cached server list
  Future<List<String>> _getCachedServerList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getStringList('cached_server_list');
      return cached ?? [];
    } catch (e) {
      print('Error getting cached servers: $e');
      return [];
    }
  }
  
  /// Update cached servers with fresh data
  Future<void> _updateCachedServers(List<String> servers) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('cached_server_list', servers);
      await prefs.setString('cache_timestamp', DateTime.now().toIso8601String());
      print('✅ Updated cached servers (${servers.length} servers)');
    } catch (e) {
      print('Error updating cached servers: $e');
    }
  }
  
  /// Check if server cache is still valid
  Future<bool> _isServerCacheValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheTimeString = prefs.getString('cache_timestamp');
      if (cacheTimeString == null) return false;
      
      final cacheTime = DateTime.parse(cacheTimeString);
      final now = DateTime.now();
      
      return now.difference(cacheTime) < cacheExpiry;
    } catch (e) {
      return false;
    }
  }
  
  /// Get cache status information
  Future<Map<String, dynamic>> _getCacheStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serverCacheTime = prefs.getString('cache_timestamp');
      final testCacheTime = prefs.getString(_testCacheTimeKey);
      
      final serverCount = (await _getCachedServerList()).length;
      final testCount = (await _getCachedTestResults())?.length ?? 0;
      
      return {
        'serverCacheValid': await _isServerCacheValid(),
        'testCacheValid': testCacheTime != null ? await _isCacheValid(await _getCachedTestResults() ?? []) : false,
        'serverCount': serverCount,
        'testCount': testCount,
        'serverCacheTime': serverCacheTime,
        'testCacheTime': testCacheTime,
      };
    } catch (e) {
      return {
        'serverCacheValid': false,
        'testCacheValid': false,
        'serverCount': 0,
        'testCount': 0,
        'serverCacheTime': null,
        'testCacheTime': null,
      };
    }
  }
  
  /// Clear all cache data
  Future<void> _clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_server_list');
      await prefs.remove('cache_timestamp');
      await prefs.remove(_testCacheKey);
      await prefs.remove(_testCacheTimeKey);
      print('✅ All cache data cleared');
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }
  
  /// Force refresh cache (clear and fetch fresh data)
  Future<void> _forceRefreshCache() async {
    try {
      print('🔄 Force refreshing cache...');
      await _clearAllCache();
      
      // Fetch fresh servers
      final servers = await _fetchServersDirect();
      await _updateCachedServers(servers);
      
      // Test and cache results
      final testResults = await _testServersOptimized(servers.take(5).toList());
      await _cacheTestResults(testResults);
      
      print('✅ Cache refreshed successfully');
    } catch (e) {
      print('Error refreshing cache: $e');
    }
  }

  Future<List<String>> _fetchServersWithFallback() async {
    // First, check if we have valid cached servers
    if (await _isServerCacheValid()) {
      final cachedServers = await _getCachedServerList();
      if (cachedServers.isNotEmpty) {
        print('📋 Using cached servers (${cachedServers.length} servers)');
        return cachedServers;
      }
    }
    
    // If no valid cache, fetch fresh servers
    print('📡 Fetching fresh servers...');
    
    // Try direct connection first (primary method)
    try {
      final servers = await _fetchServersDirect();
      // Cache the fresh servers
      await _updateCachedServers(servers);
      return servers;
    } catch (e) {
      print('Direct connection failed: $e, trying alternative endpoint');
      setState(() {
        loadingStatus = 'Trying alternative endpoint...';
      });

      // Try alternative direct endpoint
      try {
        final servers = await _fetchServersFromAlternative();
        // Cache the fresh servers
        await _updateCachedServers(servers);
        return servers;
      } catch (e2) {
        print('Alternative endpoint failed: $e2, trying AllOrigins proxy');
        setState(() {
          loadingStatus = 'Trying proxy endpoint...';
        });

        // Fallback to AllOrigins proxy
        try {
          final servers = await _fetchServersFromAllOrigins();
          // Cache the fresh servers
          await _updateCachedServers(servers);
          return servers;
        } catch (e3) {
          print('AllOrigins proxy failed: $e3, trying cached servers as last resort');
          
          // Last resort: try cached servers even if expired
          final cachedServers = await _getCachedServerList();
          if (cachedServers.isNotEmpty) {
            print('📋 Using expired cached servers as last resort (${cachedServers.length} servers)');
            return cachedServers;
          }
          
          throw Exception('All endpoints failed. Direct: $e, Alternative: $e2, AllOrigins: $e3');
        }
      }
    }
  }

  Future<List<String>> _fetchServersFromAllOrigins() async {
    print('Fetching server list via AllOrigins proxy');
    setState(() {
      loadingStatus = 'Fetching server list via proxy...';
    });

    final response = await httpClient
        .get(
      'https://api.allorigins.win/get?url=https://v2ray.shayanheidari01.workers.dev/',
      options: Options(
        headers: {
          'X-Content-Type-Options': 'nosniff',
          'Accept': 'application/json',
        },
      ),
    )
        .timeout(
      Duration(seconds: 12), // Longer timeout for proxy service
      onTimeout: () {
        throw TimeoutException('AllOrigins proxy timeout');
      },
    );

    // Parse the AllOrigins response
    if (response.data == null) {
      throw Exception('Empty response from AllOrigins proxy');
    }

    Map<String, dynamic> allOriginsResponse;
    try {
      allOriginsResponse =
          response.data is String ? json.decode(response.data) : response.data;
    } catch (e) {
      throw Exception('Failed to parse AllOrigins response: $e');
    }

    // Check if the request was successful
    if (allOriginsResponse.containsKey('status')) {
      final status = allOriginsResponse['status'];
      if (status is Map) {
        final httpCode = status['http_code'];
        final responseTime = status['response_time'];
        final contentLength = status['content_length'];

        print(
            'AllOrigins Status: HTTP $httpCode, ${responseTime}ms, ${contentLength} bytes');

        if (httpCode != 200) {
          throw Exception('AllOrigins returned HTTP $httpCode');
        }

        // Log performance for monitoring
        if (responseTime != null && responseTime > 5000) {
          print('Warning: Slow AllOrigins response time: ${responseTime}ms');
        }
      }
    }

    // Extract the contents from AllOrigins response
    if (!allOriginsResponse.containsKey('contents')) {
      throw Exception('Invalid AllOrigins response format - missing contents');
    }

    String base64Data = allOriginsResponse['contents'];
    if (base64Data.isEmpty) {
      throw Exception('Empty content from AllOrigins proxy');
    }

    return _processServerData(base64Data);
  }

  Future<List<String>> _fetchServersDirect() async {
    print('Fetching server list directly');
    setState(() {
      loadingStatus = 'Fetching server list directly...';
    });

    final response = await httpClient
        .get(
      'https://v2ray.shayanheidari01.workers.dev/',
      options: Options(
        headers: {
          'X-Content-Type-Options': 'nosniff',
        },
      ),
    )
        .timeout(
      Duration(seconds: 8),
      onTimeout: () {
        throw TimeoutException('Direct connection timeout');
      },
    );

    String base64Data = response.data;
    if (base64Data.isEmpty) {
      throw Exception('Empty response from direct connection');
    }

    return _processServerData(base64Data);
  }

  Future<List<String>> _fetchServersFromAlternative() async {
    print('Fetching server list from alternative endpoint');
    setState(() {
      loadingStatus = 'Fetching from alternative endpoint...';
    });

    final response = await httpClient
        .get(
      'https://far-sheep-86.shayanheidari01.deno.net/',
      options: Options(
        headers: {
          'X-Content-Type-Options': 'nosniff',
        },
      ),
    )
        .timeout(
      Duration(seconds: 8),
      onTimeout: () {
        throw TimeoutException('Alternative endpoint timeout');
      },
    );

    String base64Data = response.data;
    if (base64Data.isEmpty) {
      throw Exception('Empty response from alternative endpoint');
    }

    return _processServerData(base64Data);
  }

  List<String> _processServerData(String base64Data) {
    setState(() {
      loadingStatus = 'Processing server configurations...';
    });

    if (base64Data.trim().isEmpty) {
      throw Exception('Base64 data is empty or contains only whitespace');
    }

    String decodedData;
    try {
      decodedData = utf8.decode(base64.decode(base64Data));
    } catch (e) {
      throw Exception('Failed to decode base64 data: $e');
    }

    if (decodedData.trim().isEmpty) {
      throw Exception('Decoded data is empty or contains only whitespace');
    }

    print('Decoded data length: ${decodedData.length} characters');
    print('First 200 characters: ${decodedData.substring(0, decodedData.length > 200 ? 200 : decodedData.length)}');

    // Split into server list and filter valid server configurations
    List<String> allLines = LineSplitter.split(decodedData).toList();
    print('Total lines in response: ${allLines.length}');
    
    List<String> servers = allLines
        .where((line) {
          String trimmedLine = line.trim();
          return trimmedLine.isNotEmpty &&
              !trimmedLine.startsWith('//') &&
              !trimmedLine.startsWith('#') &&
              (trimmedLine.startsWith('ss://') ||
                  trimmedLine.startsWith('vless://') ||
                  trimmedLine.startsWith('vmess://') ||
                  trimmedLine.startsWith('trojan://'));
        })
        .map((line) => line.trim())
        .toList();

    print('Found ${servers.length} valid server configurations out of ${allLines.length} lines');
    
    // Log some example servers for debugging
    for (int i = 0; i < servers.length && i < 3; i++) {
      print('Server ${i + 1}: ${servers[i].substring(0, servers[i].length > 50 ? 50 : servers[i].length)}...');
    }

    if (servers.isEmpty) {
      // Log what we found instead
      print('No valid servers found. Sample lines:');
      for (int i = 0; i < allLines.length && i < 10; i++) {
        print('Line ${i + 1}: ${allLines[i].trim()}');
      }
      throw Exception('No valid server configurations found in response. Check server format.');
    }

    return servers;
  }

  Future<void> connect(List<String> serverList) async {
    // Store original server list for potential direct connection fallback
    List<String> originalServerList = List.from(serverList);
    if (serverList.isEmpty) {
      print('ERROR: Server list is empty');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Server list is empty. Please check your internet connection.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      setState(() {
        isLoading = false;
      });
      return;
    }

    // Prevent multiple concurrent server testing operations
    if (_isServerTestingInProgress) {
      print('Server testing already in progress, skipping...');
      return;
    }
    
    _isServerTestingInProgress = true;
    
    try {
      print('Processing ${serverList.length} servers...');
      List<String> list = [];
      int parseFailures = 0;

      // Parse servers with better error handling
      for (String element in serverList) {
        try {
          final V2RayURL v2rayURL = FlutterV2ray.parseFromURL(element);
          final config = v2rayURL.getFullConfiguration();
          if (config.isNotEmpty) {
            list.add(config);
            print('Successfully parsed server: ${element.substring(0, 20 >= element.length ? element.length : 20)}...');
          } else {
            parseFailures++;
            print('WARNING: Empty configuration for server: ${element.substring(0, 20 >= element.length ? element.length : 20)}...');
          }
        } catch (e) {
          parseFailures++;
          print('ERROR: Failed to parse server ${element.substring(0, 20 >= element.length ? element.length : 20)}...: $e');
        }
      }

      if (list.isEmpty) {
        print('ERROR: No valid server configurations after parsing. Parse failures: $parseFailures');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'All server configurations are invalid. $parseFailures failed to parse.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        setState(() {
          isLoading = false;
          _isServerTestingInProgress = false;
        });
        return;
      }

      print('Testing ${list.length} valid configurations (${parseFailures} parse failures)');

      // Check if user preference is to skip ping tests or if we should use direct connection
      if (_skipPingTests || _useDirectConnection) {
        print('Skipping ping tests per user preference or fallback mode');
        await connectDirectly(originalServerList);
        return;
      }

      setState(() {
        isLoading = true;
        isTestingServers = true;
        loadingStatus = 'Testing server connections...';
        serversBeingTested = list.length > 25 ? 25 : list.length; // Limit display to 25
        serversTestCompleted = 0;
        serverTestResults = []; // Reset previous test results
      });

      Map<String, dynamic> getAllDelay = {};
      int successfulTests = 0;
      int failedTests = 0;
      int timeoutTests = 0;

      // Test servers one by one (sequential testing) with resource protection
      setState(() {
        loadingStatus = 'Testing server connectivity (this may take a moment)...';
      });

      // Limit total servers to test to prevent resource exhaustion
      int maxServersToTest = list.length > 25 ? 25 : list.length;
      print('Limiting server testing to $maxServersToTest servers to prevent resource exhaustion');

      // Use queue-based testing for automatic connection as well
      _serverTestQueue.clear();
      for (int i = 0; i < maxServersToTest; i++) {
        _serverTestQueue.add({
          'index': i,
          'config': list[i],
          'maxServers': maxServersToTest,
        });
      }
      
      await _processServerTestQueueForConnection(getAllDelay);
      
      // Count results from the queue processing
      getAllDelay.forEach((key, value) {
        if (value > 0) {
          successfulTests++;
        } else if (value == -1) {
          timeoutTests++;
        } else {
          failedTests++;
        }
      });

      print('Delay testing completed. Successful: $successfulTests, Failed: $failedTests, Timeout: $timeoutTests');

      setState(() {
        loadingStatus = 'Selecting best server...';
        isTestingServers = false;
      });

      int minPing = 99999999;
      String bestConfig = '';
      int validServers = 0;
      List<MapEntry<String, int>> workingServers = [];

      getAllDelay.forEach((key, value) {
        if (value > 0) {
          validServers++;
          workingServers.add(MapEntry(key, value));
          if (value < minPing) {
            setState(() {
              bestConfig = key;
              minPing = value;
            });
          }
        }
      });

      // Sort working servers by ping for fallback options
      workingServers.sort((a, b) => a.value.compareTo(b.value));

      print('Found $validServers working servers out of ${serverTestResults.length} tested');
      if (bestConfig.isNotEmpty) {
        print('Best server selected with ${minPing}ms ping');
        if (workingServers.length > 1) {
          print('Other working servers: ${workingServers.take(3).map((e) => '${e.value}ms').join(', ')}');
        }
      }

      // If no servers passed the test, try connecting to the first few anyway as a fallback
      if (bestConfig.isEmpty && list.isNotEmpty) {
        print('No servers passed ping test, trying to connect to first server as fallback...');
        bestConfig = list.first;
        setState(() {
          loadingStatus = 'No servers passed ping test, trying first server anyway...';
        });
      }

      if (bestConfig.isNotEmpty) {
        await _connectToServer(bestConfig, minPing: minPing);
      } else {
        print('ERROR: No servers available to connect to');
        
        // Try direct connection as last resort if ping tests failed
        if (!_useDirectConnection && originalServerList.isNotEmpty) {
          print('All ping tests failed, attempting direct connection as fallback...');
          _useDirectConnection = true;
          await connectDirectly(originalServerList);
          return;
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Unable to connect to any servers. ${timeoutTests} servers timed out, ${failedTests} servers failed. Please try again later.',
              ),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 7),
            ),
          );
        }
      }
      
      Future.delayed(
        Duration(seconds: 1),
        () {
          delay();
        },
      );
      setState(() {
        isLoading = false;
        loadingStatus = '';
        serversBeingTested = 0;
        serversTestCompleted = 0;
        _isServerTestingInProgress = false; // Reset the flag
      });
    } catch (e) {
      // Handle any unexpected errors
      print('Unexpected error in connect method: $e');
      setState(() {
        isLoading = false;
        isTestingServers = false;
        _isServerTestingInProgress = false; // Reset the flag
        loadingStatus = 'Connection failed';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('connection_failed_error'.tr().replaceAll('{{error}}', e.toString())),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Process server test queue for connection testing
  Future<void> _processServerTestQueueForConnection(Map<String, dynamic> getAllDelay) async {
    if (_isProcessingServerQueue) return;
    
    _isProcessingServerQueue = true;
    
    try {
      while (_serverTestQueue.isNotEmpty && mounted) {
        final serverInfo = _serverTestQueue.removeAt(0);
        final int i = serverInfo['index'];
        final String config = serverInfo['config'];
        final int maxServers = serverInfo['maxServers'];
        int globalIndex = i + 1;
        
        try {
          print('Testing server $globalIndex/$maxServers...');
          
          // Test the server delay with better error handling
          int delay = -2; // Default to error
          try {
            delay = await flutterV2ray
                .getServerDelay(config: config)
                .timeout(Duration(seconds: 5)); // Reduced timeout
          } on TimeoutException catch (e) {
            delay = -1; // Timeout
            print('Server $globalIndex timed out: $e');
          } catch (e) {
            // Handle all other exceptions to prevent crashes
            print('Server $globalIndex test failed with error: $e');
            delay = -2; // Error
          }
          
          getAllDelay[config] = delay;
          if (delay > 0) {
            print('Server $globalIndex ping: ${delay}ms ✓');
          } else if (delay == -1) {
            print('Server $globalIndex test timed out');
          } else {
            print('Server $globalIndex test failed');
          }
          
          // Add to individual test results only if mounted
          if (mounted) {
            setState(() {
              serverTestResults.add({
                'index': globalIndex,
                'config': config,
                'delay': delay,
                'status': delay > 0 ? 'success' : (delay == -1 ? 'timeout' : 'error')
              });
              serversTestCompleted = serverTestResults.length;
              loadingStatus = 'Testing servers... (${serversTestCompleted}/$maxServers) - ${getAllDelay.values.where((d) => d > 0).length} working';
            });
          }
          
          // If in Automatic mode and this is the first healthy server, connect automatically
          if (selectedServer == 'Automatic' && delay > 0 && getAllDelay.values.where((d) => d > 0).length == 1) {
            print('Automatic mode: Connecting to first healthy server');
            // Add a small delay to prevent race conditions
            await Future.delayed(Duration(milliseconds: 500));
            // Connect to this server and stop further testing
            await _connectToServer(config, minPing: delay);
            // Clear the queue since we're connecting
            _serverTestQueue.clear();
            return;
          }
        } catch (e) {
          print('Server $globalIndex test failed with exception: $e');
          getAllDelay[config] = -2;
          
          // Add to individual test results only if mounted
          if (mounted) {
            setState(() {
              serverTestResults.add({
                'index': globalIndex,
                'config': config,
                'delay': -2, // Error
                'status': 'error'
              });
              serversTestCompleted = serverTestResults.length;
              loadingStatus = 'Testing servers... (${serversTestCompleted}/$maxServers) - ${getAllDelay.values.where((d) => d > 0).length} working';
            });
          }
        }
        
        // Increased delay between tests to prevent resource exhaustion and crashes
        await Future.delayed(Duration(milliseconds: 800)); // Increased from 600ms to 800ms
      }
    } finally {
      _isProcessingServerQueue = false;
      _isServerTestingInProgress = false; // Reset the flag
    }
  }

  // Helper method to connect to a specific server
  Future<void> _connectToServer(String config, {int minPing = 0}) async {
    try {
      print('Requesting VPN permission...');
      if (await flutterV2ray.requestPermission()) {
        print('Starting V2Ray with selected configuration...');
        try {
          flutterV2ray.startV2Ray(
            remark: 'app_title'.tr(),
            config: config,
            proxyOnly: false,
            bypassSubnets: null,
            notificationDisconnectButtonName: 'disconnect_btn'.tr(),
            blockedApps: blockedApps,
          );
          print('V2Ray start command sent successfully for specific server');
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('connecting_to_selected_server'.tr()),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (e) {
          print('Error in direct connection: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('direct_connection_failed'.tr().replaceAll('{{error}}', e.toString())),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } else {
        print('VPN permission denied for specific server');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('error_permission'.tr()),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      print('Error connecting to specific server: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('failed_connect_selected_server'.tr().replaceAll('{{error}}', e.toString())),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() {
        isLoading = false;
        loadingStatus = '';
      });
    }
  }

  void delay() async {
    if (v2rayStatus.value.state == 'CONNECTED') {
      connectedServerDelay = await flutterV2ray.getConnectedServerDelay();
      setState(() {
        isFetchingPing = true;
      });
    }
    if (!mounted) return;
  }

  // Cache management methods for server list

  Future<void> _cacheServers(
      SharedPreferences prefs, List<String> servers) async {
    await prefs.setStringList(cacheKey, servers);
    await prefs.setString(cacheTimeKey, DateTime.now().toIso8601String());
    lastServerFetch = DateTime.now();
  }

  Future<bool> _tryUseCachedServersAsFallback() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final cached = prefs.getStringList(cacheKey);

      if (cached != null && cached.isNotEmpty) {
        print('Using ${cached.length} cached servers as fallback');
        if (mounted) {
          setState(() {
            loadingStatus = 'Using cached servers as fallback...';
          });
        }
        cachedServers = cached;
        await connect(cached);
        return true;
      } else {
        print('No cached servers available for fallback');
      }
    } catch (e) {
      print('Failed to use cached servers: $e');
    }
    return false;
  }

  // New method for direct connection without ping testing
  Future<void> connectDirectly(List<String> serverList) async {
    if (serverList.isEmpty) {
      print('ERROR: Server list is empty for direct connection');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('no_servers_direct_connection'.tr()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      setState(() {
        isLoading = false;
      });
      return;
    }

    print('Attempting direct connection to first working server from ${serverList.length} servers...');
    
    setState(() {
      loadingStatus = 'Attempting direct connection (skipping ping tests)...';
    });

    // Parse servers and try connecting to the first few without ping testing
    List<String> validConfigs = [];
    for (String element in serverList.take(5)) { // Try first 5 servers
      try {
        final V2RayURL v2rayURL = FlutterV2ray.parseFromURL(element);
        final config = v2rayURL.getFullConfiguration();
        if (config.isNotEmpty) {
          validConfigs.add(config);
        }
      } catch (e) {
        print('Failed to parse server for direct connection: $e');
      }
    }

    if (validConfigs.isEmpty) {
      print('ERROR: No valid configurations for direct connection');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('no_valid_server_configs'.tr()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      setState(() {
        isLoading = false;
      });
      return;
    }

    // Try connecting to the first valid configuration
    String configToTry = validConfigs.first;
    print('Attempting direct connection to server (config length: ${configToTry.length})');

    if (await flutterV2ray.requestPermission()) {
      try {
        print('Starting V2Ray with direct connection (no ping test)...');
        flutterV2ray.startV2Ray(
          remark: 'app_title'.tr(),
          config: configToTry,
          proxyOnly: false,
          bypassSubnets: null,
          notificationDisconnectButtonName: 'disconnect_btn'.tr(),
          blockedApps: blockedApps,
        );
        print('Direct connection attempt started successfully');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('attempting_direct_connection'.tr()),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        print('Error in direct connection: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('direct_connection_failed'.tr().replaceAll('{{error}}', e.toString())),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } else {
      print('VPN permission denied for direct connection');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('error_permission'.tr()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    setState(() {
      isLoading = false;
      loadingStatus = '';
    });
  }

  // Automatically test servers to speed up finding healthy servers
  Future<void> _testServersAutomatically() async {
    // Prevent multiple concurrent server testing operations
    if (_isServerTestingInProgress) {
      print('Server testing already in progress, skipping automatic testing...');
      return;
    }
    
    _isServerTestingInProgress = true;
    
    try {
      print('🚀 Starting optimized server testing on app start...');
      
      // Check if we have recent cached results
      final cachedResults = await _getCachedTestResults();
      if (cachedResults != null && await _isCacheValid(cachedResults)) {
        print('📋 Using cached server test results (${cachedResults.length} servers)');
        _serverTestResults = cachedResults;
        _updateUIWithCachedResults();
        return;
      }
      
      // Get server list directly for faster testing
      final servers = await _fetchServersWithFallback();
      if (servers.isEmpty) {
        print('❌ No servers found for testing');
        return;
      }

      print('✅ Testing ${servers.length} servers with optimized method...');
      
      // Use optimized testing method for first 8 servers
      final testResults = await _testServersOptimized(servers.toList());
      
      // Convert to the expected format for caching
      _serverTestResults = testResults.map((result) => {
        'index': result['index'],
        'config': result['config'],
        'delay': result['delay'],
        'responseTime': result['responseTime'],
        'status': result['status'],
        'priority': 'Automatic',
        'timestamp': DateTime.now().toIso8601String(),
      }).toList();
      
      // Cache the results for future use
      await _cacheTestResults(_serverTestResults);
      
      print('🎉 Optimized server testing completed. Results: ${_serverTestResults.length} servers tested');
    } catch (e) {
      print('❌ Error in automatic server testing: $e');
      // Fallback to original method
      await _testServersFallback();
    } finally {
      // Always reset the flag
      _isServerTestingInProgress = false;
    }
  }
  
  /// Sequential server testing method (15 servers one by one)
  Future<void> _testServersSequential(List<String> servers) async {
    _serverTestResults.clear();
    
    print('🔄 Starting sequential testing of ${servers.length} servers...');
    
    // Test servers one by one to prevent crashes
    for (int i = 0; i < servers.length && mounted; i++) {
      try {
        await _testSingleServerSequential(servers[i], i + 1);
        
        // Force garbage collection every 5 servers
        if (i % 5 == 0 && i > 0) {
          await _performCleanup();
        }
        
        // Longer delay between tests to prevent file descriptor issues
        await Future.delayed(Duration(milliseconds: 500));
      } catch (e) {
        print('❌ Error testing server ${i + 1}: $e');
        // Continue with next server even if one fails
        await Future.delayed(Duration(milliseconds: 200));
      }
    }
    
    // Final cleanup
    await _performCleanup();
    
    print('✅ Sequential testing completed. ${_serverTestResults.length} servers tested');
  }
  
  /// Perform cleanup to prevent file descriptor issues
  Future<void> _performCleanup() async {
    try {
      // Force garbage collection
      await Future.delayed(Duration(milliseconds: 100));
      
      // Give system time to clean up resources
      await Future.delayed(Duration(milliseconds: 200));
    } catch (e) {
      print('⚠️ Cleanup error: $e');
    }
  }
  
  /// Fast server testing method (sequential to prevent crashes)
  Future<void> _testServersFast(List<String> servers) async {
    _serverTestResults.clear();
    
    // Test servers one by one to prevent crashes
    for (int i = 0; i < servers.length && i < 6 && mounted; i++) {
      await _testSingleServerFast(servers[i], i + 1);
      
      // Small delay between tests to prevent system overload
      await Future.delayed(Duration(milliseconds: 200));
    }
  }
  
  /// Test a single server in sequential mode (15 servers) - Safe version
  Future<void> _testSingleServerSequential(String server, int index) async {
    if (!mounted) return; // Check if widget is still mounted
    
    try {
      final v2rayURL = FlutterV2ray.parseFromURL(server);
      final config = v2rayURL.getFullConfiguration();
      
      if (config.isEmpty) {
        print('⚠️ Server $index: Empty configuration');
        return;
      }
      
      final startTime = DateTime.now();
      int delay = -2; // Default to error
      
      try {
        // Use shorter timeout to prevent TLS handshake issues
        delay = await flutterV2ray
            .getServerDelay(config: config)
            .timeout(Duration(milliseconds: 800)); // Reduced timeout to prevent TLS issues
      } on TimeoutException {
        delay = -1; // Timeout
        print('⏰ Server $index: Timeout (TLS handshake issue)');
      } catch (e) {
        delay = -2; // Error
        print('❌ Server $index: Error - $e');
      }
      
      final responseTime = DateTime.now().difference(startTime).inMilliseconds;
      
      final result = {
        'index': index,
        'config': config,
        'delay': delay,
        'responseTime': responseTime,
        'status': delay > 0 ? 'success' : (delay == -1 ? 'timeout' : 'error'),
        'priority': 'Sequential',
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      _serverTestResults.add(result);
      
      if (mounted) {
        setState(() {
          serverTestResults = List.from(_serverTestResults);
          serversTestCompleted = _serverTestResults.length;
          loadingStatus = '🔄 Testing server $index/10... (${_serverTestResults.length} tested)';
        });
      }
      
      print('✅ Server $index: ${delay > 0 ? '${delay}ms' : (delay == -1 ? 'Timeout' : 'Error')}');
      
      // Add cleanup delay to prevent file descriptor issues
      await Future.delayed(Duration(milliseconds: 100));
      
    } catch (e) {
      print('❌ Server $index failed: $e');
      
      final result = {
        'index': index,
        'config': '',
        'delay': -2,
        'responseTime': 0,
        'status': 'error',
        'priority': 'Sequential',
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      _serverTestResults.add(result);
      
      if (mounted) {
        setState(() {
          serverTestResults = List.from(_serverTestResults);
          serversTestCompleted = _serverTestResults.length;
          loadingStatus = '🔄 Testing server $index/10... (${_serverTestResults.length} tested)';
        });
      }
      
      // Add cleanup delay even on error
      await Future.delayed(Duration(milliseconds: 100));
    }
  }

  /// Test a single server quickly and safely
  Future<void> _testSingleServerFast(String server, int index) async {
    if (!mounted) return; // Check if widget is still mounted
    
    try {
      final v2rayURL = FlutterV2ray.parseFromURL(server);
      final config = v2rayURL.getFullConfiguration();
      
      if (config.isEmpty) {
        print('⚠️ Server $index: Empty configuration');
        return;
      }
      
      final startTime = DateTime.now();
      int delay = -2; // Default to error
      
      try {
        delay = await flutterV2ray
            .getServerDelay(config: config)
            .timeout(Duration(milliseconds: 1000)); // 1 second timeout
      } on TimeoutException {
        delay = -1; // Timeout
        print('⏰ Server $index: Timeout');
      } catch (e) {
        delay = -2; // Error
        print('❌ Server $index: Error - $e');
      }
      
      final responseTime = DateTime.now().difference(startTime).inMilliseconds;
      
      final result = {
        'index': index,
        'config': config,
        'delay': delay,
        'responseTime': responseTime,
        'status': delay > 0 ? 'success' : (delay == -1 ? 'timeout' : 'error'),
        'priority': 'Fast',
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      _serverTestResults.add(result);
      
      if (mounted) {
        setState(() {
          serverTestResults = List.from(_serverTestResults);
          serversTestCompleted = _serverTestResults.length;
          loadingStatus = '⚡ Testing server $index... (${_serverTestResults.length} tested)';
        });
      }
      
      print('✅ Server $index: ${delay > 0 ? '${delay}ms' : (delay == -1 ? 'Timeout' : 'Error')}');
      
    } catch (e) {
      print('❌ Server $index failed: $e');
      
      final result = {
        'index': index,
        'config': '',
        'delay': -2,
        'responseTime': 0,
        'status': 'error',
        'priority': 'Fast',
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      _serverTestResults.add(result);
      
      if (mounted) {
        setState(() {
          serverTestResults = List.from(_serverTestResults);
          serversTestCompleted = _serverTestResults.length;
          loadingStatus = '⚡ Testing server $index... (${_serverTestResults.length} tested)';
        });
      }
    }
  }
  
  // Fallback server testing method (safe and sequential)
  Future<void> _testServersFallback() async {
    try {
      print('🔄 Starting safe fallback server testing...');
      
      // Get server list
      List<String> servers = await _fetchServersWithFallback();
      
      if (servers.isEmpty) {
        print('❌ No servers found for fallback testing');
        return;
      }

      print('🔄 Fallback testing ${servers.length} servers...');
      
      // Limit to first 4 servers to prevent crashes
      int maxServersToTest = servers.length > 4 ? 4 : servers.length;
      
      // Test servers one by one safely
      for (int i = 0; i < maxServersToTest && mounted; i++) {
        await _testSingleServerFallback(servers[i], i + 1);
        
        // Delay between tests to prevent system overload
        await Future.delayed(Duration(milliseconds: 300));
      }
      
      // Cache fallback results
      await _cacheTestResults(_serverTestResults);
      
    } catch (e) {
      print('❌ Error in fallback server testing: $e');
    }
  }
  
  /// Test a single server in fallback mode
  Future<void> _testSingleServerFallback(String server, int index) async {
    if (!mounted) return;
    
    try {
      final v2rayURL = FlutterV2ray.parseFromURL(server);
      final config = v2rayURL.getFullConfiguration();
      
      if (config.isEmpty) {
        print('⚠️ Fallback Server $index: Empty configuration');
        return;
      }
      
      final startTime = DateTime.now();
      int delay = -2; // Default to error
      
      try {
        delay = await flutterV2ray
            .getServerDelay(config: config)
            .timeout(Duration(seconds: 1));
      } on TimeoutException {
        delay = -1; // Timeout
        print('⏰ Fallback Server $index: Timeout');
      } catch (e) {
        delay = -2; // Error
        print('❌ Fallback Server $index: Error - $e');
      }
      
      final responseTime = DateTime.now().difference(startTime).inMilliseconds;
      
      final result = {
        'index': index,
        'config': config,
        'delay': delay,
        'responseTime': responseTime,
        'status': delay > 0 ? 'success' : (delay == -1 ? 'timeout' : 'error'),
        'priority': 'Fallback',
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      _serverTestResults.add(result);
      
      if (mounted) {
        setState(() {
          serverTestResults = List.from(_serverTestResults);
          serversTestCompleted = _serverTestResults.length;
          loadingStatus = '🔄 Fallback testing server $index... (${_serverTestResults.length} tested)';
        });
      }
      
      print('✅ Fallback Server $index: ${delay > 0 ? '${delay}ms' : (delay == -1 ? 'Timeout' : 'Error')}');
      
    } catch (e) {
      print('❌ Fallback Server $index failed: $e');
      
      final result = {
        'index': index,
        'config': '',
        'delay': -2,
        'responseTime': 0,
        'status': 'error',
        'priority': 'Fallback',
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      _serverTestResults.add(result);
      
      if (mounted) {
        setState(() {
          serverTestResults = List.from(_serverTestResults);
          serversTestCompleted = _serverTestResults.length;
          loadingStatus = '🔄 Fallback testing server $index... (${_serverTestResults.length} tested)';
        });
      }
    }
  }
  
  /// Start background server testing for continuous optimization
  void _startBackgroundTesting() {
    Timer.periodic(Duration(minutes: 10), (timer) {
      if (mounted && !_isServerTestingInProgress) {
        _performBackgroundServerTest();
      }
    });
  }
  
  /// Perform background server test
  Future<void> _performBackgroundServerTest() async {
    try {
      print('🔄 Performing background server test...');
      
      // Test a few random servers to keep data fresh
      final servers = await _fetchServersWithFallback();
      if (servers.isEmpty) return;
      
      // Test only 3 random servers in background
      final randomServers = servers.take(3).toList();
      
      for (final server in randomServers) {
        try {
          final v2rayURL = FlutterV2ray.parseFromURL(server);
          final config = v2rayURL.getFullConfiguration();
          
          if (config.isNotEmpty) {
            final delay = await flutterV2ray
                .getServerDelay(config: config)
                .timeout(Duration(seconds: 2));
            
            print('🔄 Background test: ${delay > 0 ? '${delay}ms' : 'Failed'}');
          }
        } catch (e) {
          print('🔄 Background test failed: $e');
        }
        
        // Small delay between background tests
        await Future.delayed(Duration(milliseconds: 500));
      }
    } catch (e) {
      print('❌ Background testing error: $e');
    }
  }

  // Process server test queue for automatic testing
  Future<void> _processServerTestQueueForAutomatic() async {
    if (_isProcessingServerQueue) return;
    
    _isProcessingServerQueue = true;
    
    try {
      while (_serverTestQueue.isNotEmpty && mounted) {
        final serverInfo = _serverTestQueue.removeAt(0);
        final int i = serverInfo['index'];
        final String serverUrl = serverInfo['serverUrl'];
        final int maxServers = serverInfo['maxServers'];
        
        try {
          // Parse the server configuration
          final V2RayURL v2rayURL = FlutterV2ray.parseFromURL(serverUrl);
          final config = v2rayURL.getFullConfiguration();
          
          if (config.isEmpty) {
            continue; // Skip empty configurations
          }
          
          // Test the server delay with a shorter timeout
          int delay = -2; // Default to error
          try {
            delay = await flutterV2ray
                .getServerDelay(config: config)
                .timeout(Duration(seconds: 3)); // Short timeout for automatic testing
          } on TimeoutException catch (e) {
            delay = -1; // Timeout
            print('Server ${i + 1} timeout: $e');
          } catch (e) {
            // Handle all other exceptions to prevent crashes
            delay = -2; // Error
            print('Server ${i + 1} error: $e');
          }
          
          // Add result to list only if still mounted
          if (mounted) {
            setState(() {
              serverTestResults.add({
                'index': i + 1,
                'config': config,
                'delay': delay,
                'status': delay > 0 ? 'success' : (delay == -1 ? 'timeout' : 'error')
              });
            });
          }
          
          print('Server ${i + 1} automatically tested: ${delay > 0 ? '${delay}ms' : (delay == -1 ? 'Timeout' : 'Error')}');
        } catch (e) {
          print('Server ${i + 1} automatic test failed: $e');
          
          // Add error result only if still mounted
          if (mounted) {
            setState(() {
              serverTestResults.add({
                'index': i + 1,
                'config': serverUrl,
                'delay': -2, // Error
                'status': 'error'
              });
            });
          }
        }
        
        // Increase delay between tests to prevent crashes (increased from 500ms)
        await Future.delayed(Duration(milliseconds: 800));
      }
    } finally {
      _isProcessingServerQueue = false;
    }
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

  String _formatDuration(String duration) {
    if (duration.contains(':') && duration.length >= 5) {
      final parts = duration.split(':');
      if (parts.length == 3) {
        final hours = int.tryParse(parts[0]) ?? 0;
        final minutes = int.tryParse(parts[1]) ?? 0;
        
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
      return duration;
    }
  }

}
