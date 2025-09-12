import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ServerOptimizationService {
  static final ServerOptimizationService _instance = ServerOptimizationService._internal();
  factory ServerOptimizationService() => _instance;
  ServerOptimizationService._internal();

  final Dio _dio = Dio();
  final List<String> _serverEndpoints = [
    'https://v2ray.shayanheidari01.workers.dev/',
    'https://far-sheep-86.shayanheidari01.deno.net/',
  ];
  
  // Cache configuration
  static const String _cacheKey = 'optimized_cached_servers';
  static const String _cacheTimeKey = 'optimized_cache_timestamp';
  static const String _serverHealthKey = 'server_health_data';
  static const String _userLocationKey = 'user_location_data';
  static const Duration _cacheExpiry = Duration(minutes: 15);
  static const Duration _healthCheckInterval = Duration(minutes: 30);
  
  // Connection configuration
  static const int _maxConcurrentRequests = 3;
  static const Duration _requestTimeout = Duration(seconds: 6);
  static const Duration _pingTimeout = Duration(seconds: 3);
  static const int _maxRetries = 2;
  
  // Server health tracking
  Map<String, ServerHealthData> _serverHealth = {};
  Timer? _healthCheckTimer;
  Map<String, double>? _userLocation;

  /// Initialize the service
  Future<void> initialize() async {
    await _loadCachedData();
    await _getUserLocation();
    _startHealthMonitoring();
  }

  /// Get optimized server list with intelligent selection
  Future<List<String>> getOptimizedServerList({
    bool forceRefresh = false,
    Function(String)? onStatusUpdate,
  }) async {
    try {
      onStatusUpdate?.call('Initializing server selection...');
      
      // Check cache first
      if (!forceRefresh && await _isCacheValid()) {
        onStatusUpdate?.call('Using cached servers...');
        final cachedServers = await _getCachedServers();
        if (cachedServers.isNotEmpty) {
          return _selectOptimalServers(cachedServers);
        }
      }

      // Fetch fresh servers with parallel requests
      onStatusUpdate?.call('Fetching server list...');
      final servers = await _fetchServersParallel(onStatusUpdate);
      
      if (servers.isEmpty) {
        throw Exception('No servers available');
      }

      // Cache the servers
      await _cacheServers(servers);
      
      // Select optimal servers based on location and health
      return _selectOptimalServers(servers);
      
    } catch (e) {
      print('Error in getOptimizedServerList: $e');
      // Fallback to cached servers
      final cachedServers = await _getCachedServers();
      if (cachedServers.isNotEmpty) {
        onStatusUpdate?.call('Using fallback servers...');
        return _selectOptimalServers(cachedServers);
      }
      rethrow;
    }
  }

  /// Fetch servers using parallel requests for better performance
  Future<List<String>> _fetchServersParallel(Function(String)? onStatusUpdate) async {
    final List<Future<List<String>>> futures = [];
    
    for (int i = 0; i < _serverEndpoints.length && i < _maxConcurrentRequests; i++) {
      futures.add(_fetchFromEndpoint(_serverEndpoints[i], onStatusUpdate));
    }

    // Wait for the first successful response
    final results = await Future.wait(
      futures,
      eagerError: false,
    );

    // Find the first non-empty result
    for (final result in results) {
      if (result.isNotEmpty) {
        return result;
      }
    }

    throw Exception('All server endpoints failed');
  }

  /// Fetch servers from a specific endpoint
  Future<List<String>> _fetchFromEndpoint(String endpoint, Function(String)? onStatusUpdate) async {
    try {
      onStatusUpdate?.call('Connecting to ${_getEndpointName(endpoint)}...');
      
      final response = await _dio.get(
        endpoint,
        options: Options(
          headers: {
            'X-Content-Type-Options': 'nosniff',
            'Accept': 'application/json',
            'User-Agent': 'ShineNET-VPN/1.0',
          },
          sendTimeout: _requestTimeout,
          receiveTimeout: _requestTimeout,
        ),
      );

      if (response.data == null || response.data.toString().isEmpty) {
        throw Exception('Empty response from $endpoint');
      }

      return _processServerData(response.data.toString());
      
    } catch (e) {
      print('Error fetching from $endpoint: $e');
      rethrow;
    }
  }

  /// Process server data with improved parsing
  List<String> _processServerData(String data) {
    try {
      // Handle both direct base64 and AllOrigins format
      String base64Data = data;
      
      // Check if it's AllOrigins format
      if (data.startsWith('{')) {
        final jsonData = json.decode(data);
        if (jsonData['contents'] != null) {
          base64Data = jsonData['contents'];
        }
      }

      if (base64Data.isEmpty) {
        throw Exception('Empty base64 data');
      }

      // Decode base64
      final decodedBytes = base64.decode(base64Data);
      final decodedString = utf8.decode(decodedBytes);
      
      // Parse server configurations
      final lines = decodedString.split('\n');
      final servers = <String>[];
      
      for (final line in lines) {
        final trimmedLine = line.trim();
        if (trimmedLine.isNotEmpty && _isValidServerConfig(trimmedLine)) {
          servers.add(trimmedLine);
        }
      }

      return servers;
      
    } catch (e) {
      print('Error processing server data: $e');
      throw Exception('Failed to process server data: $e');
    }
  }

  /// Validate server configuration
  bool _isValidServerConfig(String config) {
    try {
      final decoded = base64.decode(config);
      final decodedString = utf8.decode(decoded);
      final jsonData = json.decode(decodedString);
      
      // Basic validation
      return jsonData['outbounds'] != null && 
             jsonData['outbounds'] is List &&
             (jsonData['outbounds'] as List).isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Select optimal servers based on location and health data
  List<String> _selectOptimalServers(List<String> servers) {
    if (servers.isEmpty) return servers;

    // Sort servers by priority
    final sortedServers = List<String>.from(servers);
    
    // Apply intelligent selection
    sortedServers.sort((a, b) {
      final healthA = _getServerHealth(a);
      final healthB = _getServerHealth(b);
      
      // Prioritize by health score
      final scoreA = _calculateServerScore(a, healthA);
      final scoreB = _calculateServerScore(b, healthB);
      
      return scoreB.compareTo(scoreA);
    });

    // Return top servers (limit to prevent resource exhaustion)
    return sortedServers.take(20).toList();
  }

  /// Calculate server score based on health and location
  double _calculateServerScore(String server, ServerHealthData? health) {
    double score = 0.0;
    
    // Base score
    score += 50.0;
    
    // Health-based scoring
    if (health != null) {
      // Success rate (0-30 points)
      score += health.successRate * 30.0;
      
      // Response time (0-20 points, faster is better)
      if (health.avgResponseTime > 0) {
        score += (3000 - health.avgResponseTime) / 3000 * 20.0;
      }
      
      // Recent failures penalty
      if (health.recentFailures > 0) {
        score -= health.recentFailures * 5.0;
      }
    }
    
    return score.clamp(0.0, 100.0);
  }

  /// Get server health data
  ServerHealthData? _getServerHealth(String server) {
    final serverId = _getServerId(server);
    return _serverHealth[serverId];
  }

  /// Generate server ID for tracking
  String _getServerId(String server) {
    try {
      final decoded = base64.decode(server);
      final decodedString = utf8.decode(decoded);
      final jsonData = json.decode(decodedString);
      
      if (jsonData['outbounds'] != null && 
          (jsonData['outbounds'] as List).isNotEmpty) {
        final outbound = jsonData['outbounds'][0];
        if (outbound['settings'] != null && 
            outbound['settings']['vnext'] != null &&
            (outbound['settings']['vnext'] as List).isNotEmpty) {
          final vnext = outbound['settings']['vnext'][0];
          return '${vnext['address']}_${vnext['port']}';
        }
      }
    } catch (e) {
      // Fallback to hash of the entire config
      return server.hashCode.toString();
    }
    return server.hashCode.toString();
  }

  /// Test server connection with optimized ping
  Future<ServerTestResult> testServerConnection(String server) async {
    final serverId = _getServerId(server);
    final startTime = DateTime.now();
    
    try {
      // Extract server details for ping test
      final serverDetails = _extractServerDetails(server);
      if (serverDetails == null) {
        throw Exception('Invalid server configuration');
      }

      // Perform ping test
      final pingResult = await _pingServer(serverDetails['address'], serverDetails['port']);
      
      final responseTime = DateTime.now().difference(startTime).inMilliseconds;
      
      // Update health data
      _updateServerHealth(serverId, true, responseTime);
      
      return ServerTestResult(
        server: server,
        success: true,
        responseTime: responseTime,
        ping: pingResult,
      );
      
    } catch (e) {
      final responseTime = DateTime.now().difference(startTime).inMilliseconds;
      
      // Update health data
      _updateServerHealth(serverId, false, responseTime);
      
      return ServerTestResult(
        server: server,
        success: false,
        responseTime: responseTime,
        error: e.toString(),
      );
    }
  }

  /// Extract server details from configuration
  Map<String, dynamic>? _extractServerDetails(String server) {
    try {
      final decoded = base64.decode(server);
      final decodedString = utf8.decode(decoded);
      final jsonData = json.decode(decodedString);
      
      if (jsonData['outbounds'] != null && 
          (jsonData['outbounds'] as List).isNotEmpty) {
        final outbound = jsonData['outbounds'][0];
        if (outbound['settings'] != null && 
            outbound['settings']['vnext'] != null &&
            (outbound['settings']['vnext'] as List).isNotEmpty) {
          final vnext = outbound['settings']['vnext'][0];
          return {
            'address': vnext['address'],
            'port': vnext['port'],
          };
        }
      }
    } catch (e) {
      print('Error extracting server details: $e');
    }
    return null;
  }

  /// Optimized ping test
  Future<int> _pingServer(String address, int port) async {
    try {
      final socket = await Socket.connect(
        address,
        port,
        timeout: _pingTimeout,
      );
      
      final startTime = DateTime.now();
      await socket.close();
      final endTime = DateTime.now();
      
      return endTime.difference(startTime).inMilliseconds;
    } catch (e) {
      throw Exception('Ping failed: $e');
    }
  }

  /// Update server health data
  void _updateServerHealth(String serverId, bool success, int responseTime) {
    final now = DateTime.now();
    
    if (!_serverHealth.containsKey(serverId)) {
      _serverHealth[serverId] = ServerHealthData();
    }
    
    final health = _serverHealth[serverId]!;
    health.totalRequests++;
    
    if (success) {
      health.successfulRequests++;
      health.totalResponseTime += responseTime;
      health.avgResponseTime = health.totalResponseTime / health.successfulRequests;
    } else {
      health.recentFailures++;
    }
    
    // Reset recent failures after some time
    if (now.difference(health.lastFailureReset) > const Duration(hours: 1)) {
      health.recentFailures = 0;
      health.lastFailureReset = now;
    }
    
    health.lastChecked = now;
  }

  /// Get user location for intelligent server selection
  Future<void> _getUserLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final locationString = prefs.getString(_userLocationKey);
      
      if (locationString != null) {
        final locationData = json.decode(locationString);
        _userLocation = {
          'latitude': locationData['latitude']?.toDouble() ?? 0.0,
          'longitude': locationData['longitude']?.toDouble() ?? 0.0,
          'timestamp': locationData['timestamp'],
        };
        
        // Check if location is recent (less than 1 hour old)
        final timestamp = DateTime.parse(locationData['timestamp']);
        if (DateTime.now().difference(timestamp) > const Duration(hours: 1)) {
          _userLocation = null;
        }
      }
      
      // For now, we'll skip location services to avoid permission issues
      // This can be implemented later with proper permission handling
    } catch (e) {
      print('Error getting user location: $e');
    }
  }

  /// Start background health monitoring
  void _startHealthMonitoring() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(_healthCheckInterval, (timer) {
      _performBackgroundHealthCheck();
    });
  }

  /// Perform background health check
  Future<void> _performBackgroundHealthCheck() async {
    try {
      final servers = await _getCachedServers();
      if (servers.isEmpty) return;
      
      // Test a few random servers
      final serversToTest = servers.take(5).toList();
      final futures = serversToTest.map((server) => testServerConnection(server));
      
      await Future.wait(futures, eagerError: false);
      
      // Save updated health data
      await _saveHealthData();
      
    } catch (e) {
      print('Error in background health check: $e');
    }
  }

  /// Cache management methods
  Future<bool> _isCacheValid() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheTimeString = prefs.getString(_cacheTimeKey);
    if (cacheTimeString == null) return false;

    final cacheTime = DateTime.parse(cacheTimeString);
    return DateTime.now().difference(cacheTime) < _cacheExpiry;
  }

  Future<List<String>> _getCachedServers() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_cacheKey) ?? [];
  }

  Future<void> _cacheServers(List<String> servers) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_cacheKey, servers);
    await prefs.setString(_cacheTimeKey, DateTime.now().toIso8601String());
  }

  Future<void> _loadCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    final healthString = prefs.getString(_serverHealthKey);
    if (healthString != null) {
      try {
        final healthData = json.decode(healthString);
        _serverHealth = Map<String, ServerHealthData>.from(
          healthData.map((key, value) => MapEntry(key, ServerHealthData.fromJson(value)))
        );
      } catch (e) {
        print('Error loading health data: $e');
      }
    }
  }

  Future<void> _saveHealthData() async {
    final prefs = await SharedPreferences.getInstance();
    final healthData = _serverHealth.map((key, value) => MapEntry(key, value.toJson()));
    await prefs.setString(_serverHealthKey, json.encode(healthData));
  }

  /// Utility methods
  String _getEndpointName(String endpoint) {
    if (endpoint.contains('workers.dev')) return 'Primary Server';
    if (endpoint.contains('deno.net')) return 'Alternative Server';
    return 'Server';
  }

  /// Cleanup resources
  void dispose() {
    _healthCheckTimer?.cancel();
    _dio.close();
  }
}

/// Server health data model
class ServerHealthData {
  int totalRequests = 0;
  int successfulRequests = 0;
  int totalResponseTime = 0;
  double avgResponseTime = 0.0;
  int recentFailures = 0;
  DateTime lastChecked = DateTime.now();
  DateTime lastFailureReset = DateTime.now();

  ServerHealthData();

  double get successRate => totalRequests > 0 ? successfulRequests / totalRequests : 0.0;

  Map<String, dynamic> toJson() => {
    'totalRequests': totalRequests,
    'successfulRequests': successfulRequests,
    'totalResponseTime': totalResponseTime,
    'avgResponseTime': avgResponseTime,
    'recentFailures': recentFailures,
    'lastChecked': lastChecked.toIso8601String(),
    'lastFailureReset': lastFailureReset.toIso8601String(),
  };

  factory ServerHealthData.fromJson(Map<String, dynamic> json) {
    final health = ServerHealthData();
    health.totalRequests = json['totalRequests'] ?? 0;
    health.successfulRequests = json['successfulRequests'] ?? 0;
    health.totalResponseTime = json['totalResponseTime'] ?? 0;
    health.avgResponseTime = json['avgResponseTime'] ?? 0.0;
    health.recentFailures = json['recentFailures'] ?? 0;
    health.lastChecked = DateTime.parse(json['lastChecked'] ?? DateTime.now().toIso8601String());
    health.lastFailureReset = DateTime.parse(json['lastFailureReset'] ?? DateTime.now().toIso8601String());
    return health;
  }
}

/// Server test result model
class ServerTestResult {
  final String server;
  final bool success;
  final int responseTime;
  final int? ping;
  final String? error;

  ServerTestResult({
    required this.server,
    required this.success,
    required this.responseTime,
    this.ping,
    this.error,
  });
}
