import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Helper function for fire-and-forget operations
void unawaited(Future<void> future) {
  future.catchError((error) {
    print('Unawaited operation failed: $error');
  });
}

class ServerOptimizationService {
  static final ServerOptimizationService _instance =
      ServerOptimizationService._internal();
  factory ServerOptimizationService() => _instance;
  ServerOptimizationService._internal();

  late final Dio _dio;
  final List<String> _serverEndpoints = [
    'https://v2ray.shayanheidari01.workers.dev/',
    'https://far-sheep-86.shayanheidari01.deno.net/',
  ];

  // Fallback server configurations
  final List<String> _fallbackServers = [
    'vmess://eyJ2IjoiMiIsInBzIjoiU2hpbmVORVQgU2VydmVyIDEiLCJhZGQiOiIxMDQuMjEuNTUuMjM0IiwicG9ydCI6IjQ0MyIsInR5cGUiOiJub25lIiwiaWQiOiI5NWZlZGQzZC1hNzQzLTQ5ZGEtOGI4Ni05ZjNlNzM5NzIyZDciLCJhaWQiOiIwIiwibmV0Ijoid3MiLCJwYXRoIjoiLyIsImhvc3QiOiIiLCJ0bHMiOiJ0bHMifQ==',
    'vmess://eyJ2IjoiMiIsInBzIjoiU2hpbmVORVQgU2VydmVyIDIiLCJhZGQiOiIxNzIuNjcuMTMwLjE1NCIsInBvcnQiOiI0NDMiLCJ0eXBlIjoibm9uZSIsImlkIjoiOTVmZWRkM2QtYTc0My00OWRhLThiODYtOWYzZTczOTcyMmQ3IiwiYWlkIjoiMCIsIm5ldCI6IndzIiwicGF0aCI6Ii8iLCJob3N0IjoiIiwidGxzIjoidGxzIn0=',
    'vmess://eyJ2IjoiMiIsInBzIjoiU2hpbmVORVQgU2VydmVyIDMiLCJhZGQiOiIxNzIuNjcuMTMwLjE1NSIsInBvcnQiOiI0NDMiLCJ0eXBlIjoibm9uZSIsImlkIjoiOTVmZWRkM2QtYTc0My00OWRhLThiODYtOWYzZTczOTcyMmQ3IiwiYWlkIjoiMCIsIm5ldCI6IndzIiwicGF0aCI6Ii8iLCJob3N0IjoiIiwidGxzIjoidGxzIn0=',
  ];

  // Cache and storage keys
  static const String _cacheKey = 'optimized_cached_servers';
  static const String _cacheTimeKey = 'optimized_cache_timestamp';
  static const String _serverHealthKey = 'server_health_data';

  // Connection configuration - Optimized for better performance
  static const int _maxConcurrentRequests = 2; // Less concurrent requests for stability
  static const Duration _requestTimeout = Duration(seconds: 5); // More time for slow networks
  static const Duration _connectTimeout = Duration(seconds: 3); // Better for slow connections
  static const Duration _pingTimeout = Duration(milliseconds: 2000); // More reasonable timeout

  // Health monitoring
  Timer? _healthCheckTimer;
  final Map<String, ServerHealthData> _serverHealth = {};

  // Server management

  /// Initialize the service
  Future<void> initialize() async {
    _initializeDio();
    await SharedPreferences.getInstance();
    await _loadCachedData();
    await _getUserLocation();
    _startHealthMonitoring();
  }

  /// Initialize Dio with optimized settings
  void _initializeDio() {
    _dio = Dio(BaseOptions(
      connectTimeout: _connectTimeout,
      receiveTimeout: _requestTimeout,
      sendTimeout: _requestTimeout,
      headers: {
        'Accept': 'application/json, text/plain, */*',
        'User-Agent': 'ShineNET-VPN/1.0 (Mobile)',
        'Accept-Encoding': 'gzip, deflate',
        'Connection': 'keep-alive',
      },
      validateStatus: (status) =>
          status != null && status >= 200 && status < 300,
      followRedirects: true,
      maxRedirects: 3,
      // Enable connection pooling for better performance
      persistentConnection: true,
    ));

    // Add interceptors for better error handling and logging
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        options.headers['Cache-Control'] =
            'no-cache, no-store, must-revalidate';
        options.headers['Pragma'] = 'no-cache';
        options.headers['Expires'] = '0';

        // Add request timestamp for timeout tracking
        options.extra['request_start_time'] =
            DateTime.now().millisecondsSinceEpoch;

        handler.next(options);
      },
      onResponse: (response, handler) {
        final startTime =
            response.requestOptions.extra['request_start_time'] as int?;

        // Handle specific error cases
        if (startTime != null) {
          final duration = DateTime.now().millisecondsSinceEpoch - startTime;
          print(
              'Request to ${response.requestOptions.uri} completed in ${duration}ms');
        }
        handler.next(response);
      },
      onError: (error, handler) {
        final startTime =
            error.requestOptions.extra['request_start_time'] as int?;

        // Handle specific error cases
        if (error.type == DioExceptionType.connectionTimeout) {
          print('⏰ Connection timeout to ${error.requestOptions.uri}');
        } else if (error.type == DioExceptionType.receiveTimeout) {
          print('⏰ Receive timeout from ${error.requestOptions.uri}');
        } else if (error.response != null) {
          final statusCode = error.response?.statusCode;
          if (statusCode == 500) {
            print(
                '🚨 Server Error 500: ${error.requestOptions.uri} - Server is experiencing issues');
          } else if (statusCode == 503) {
            print(
                '🚨 Service Unavailable 503: ${error.requestOptions.uri} - Server temporarily unavailable');
          } else if (statusCode == 429) {
            print(
                '🚨 Rate Limited 429: ${error.requestOptions.uri} - Too many requests');
          } else {
            print(
                '🚨 Server responded with ${statusCode}: ${error.requestOptions.uri}');
          }
        } else {
          print('🚨 Network error: ${error.message}');
        }

        // Skip retry logic for now to avoid async issues in interceptor
        // Retry will be handled at the service level instead

        handler.next(error);
      },
    ));
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

      // Ultimate fallback to hardcoded servers
      onStatusUpdate?.call('Using emergency fallback servers...');
      print('Using emergency fallback servers due to network issues');
      await _cacheServers(_fallbackServers); // Cache the fallback servers
      return _selectOptimalServers(_fallbackServers);
    }
  }

  /// Check if all parallel requests have completed
  void _checkAllRequestsCompleted(int completedRequests,
      Completer<List<String>> completer, Map<String, dynamic> errors) {
    if (completedRequests >= _serverEndpoints.length &&
        !completer.isCompleted) {
      if (errors.isNotEmpty) {
        final errorDetails = errors.entries
            .map((e) => '${_getEndpointName(e.key)}: ${e.value}')
            .join('; ');
        completer.completeError(
          Exception('All endpoints failed: $errorDetails'),
          StackTrace.current,
        );
      } else {
        completer.complete(<String>[]);
      }
    }
  }

  /// Fetch servers using optimized parallel requests with better error handling
  Future<List<String>> _fetchServersParallel(
      Function(String)? onStatusUpdate) async {
    final completer = Completer<List<String>>();
    int completedRequests = 0;
    final errors = <String, dynamic>{}; // Store errors with endpoint info

    // Start all requests concurrently with proper error handling
    for (int i = 0;
        i < _serverEndpoints.length && i < _maxConcurrentRequests;
        i++) {
      final endpoint = _serverEndpoints[i];
      final endpointName = _getEndpointName(endpoint);

      onStatusUpdate?.call('Trying $endpointName...');

      unawaited(_fetchFromEndpoint(endpoint, onStatusUpdate).then((result) {
        if (!completer.isCompleted) {
          if (result.isNotEmpty) {
            if (!completer.isCompleted) {
              completer.complete(result);
            }
          } else {
            errors[endpoint] = 'No valid servers found';
            _checkAllRequestsCompleted(++completedRequests, completer, errors);
          }
        }
      }).catchError((error) {
        final errorMessage = error.toString();
        errors[endpoint] = errorMessage;
        print('Error from $endpoint: $errorMessage');

        if (!completer.isCompleted) {
          _checkAllRequestsCompleted(++completedRequests, completer, errors);
        }
      }));
    }

    // Add timeout for the entire operation
    return completer.future.timeout(
      Duration(seconds: 8), // Increased timeout for better reliability
      onTimeout: () {
        if (!completer.isCompleted) {
          completer.completeError(
            Exception('Server fetch timed out after 8 seconds'),
            StackTrace.current,
          );
        }
        return <String>[];
      },
    );
  }

  /// Process server data with optimized parsing
  List<String> _processServerData(String data) {
    try {
      // Handle both direct base64 and AllOrigins format
      String base64Data = data.trim();

      // Check if it's AllOrigins format
      if (base64Data.startsWith('{')) {
        final jsonData = json.decode(base64Data);
        if (jsonData['contents'] != null) {
          base64Data = jsonData['contents'].toString().trim();
        }
      }

      if (base64Data.isEmpty) {
        throw Exception('Empty base64 data');
      }

      // Decode base64 with error handling
      late final String decodedString;
      try {
        final decodedBytes = base64.decode(base64Data);
        decodedString = utf8.decode(decodedBytes);
      } catch (e) {
        throw Exception('Invalid base64 encoding: $e');
      }

      // Parse server configurations with optimized filtering
      final lines = decodedString.split('\n');
      final servers = <String>[];

      for (final line in lines) {
        final trimmedLine = line.trim();
        if (trimmedLine.isNotEmpty && _isValidServerConfig(trimmedLine)) {
          servers.add(trimmedLine);
        }
      }

      if (servers.isEmpty) {
        throw Exception('No valid server configurations found');
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
      // Check if it's a vmess:// URL format
      if (config.startsWith('vmess://') ||
          config.startsWith('vless://') ||
          config.startsWith('trojan://') ||
          config.startsWith('ss://')) {
        return true;
      }

      // Check if it's base64 encoded V2Ray config
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

  /// Select optimal servers with improved performance and smart filtering
  List<String> _selectOptimalServers(List<String> servers) {
    if (servers.isEmpty) return servers;

    // Pre-filter valid servers to avoid processing invalid ones
    final validServers = servers.where(_isValidServerConfig).toList();
    if (validServers.isEmpty) return servers;

    // Apply intelligent selection with caching and prioritization
    final serverScores = <String, double>{};
    final priorityServers = <String>[];
    final regularServers = <String>[];

    for (final server in validServers) {
      final health = _getServerHealth(server);
      final score = _calculateServerScore(server, health);
      serverScores[server] = score;

      // Prioritize servers with good health data
      if (health != null &&
          health.successRate > 0.8 &&
          health.avgResponseTime < 1000) {
        priorityServers.add(server);
      } else {
        regularServers.add(server);
      }
    }

    // Sort both lists by score
    priorityServers
        .sort((a, b) => serverScores[b]!.compareTo(serverScores[a]!));
    regularServers.sort((a, b) => serverScores[b]!.compareTo(serverScores[a]!));

    // Return priority servers first, then regular servers (ALL servers, no limitations)
    final result = <String>[];
    result.addAll(priorityServers); // Add ALL priority servers
    result.addAll(regularServers); // Add ALL regular servers

    return result.isEmpty ? validServers : result; // Return ALL servers
  }

  /// Calculate server score based on health and location with enhanced algorithm
  double _calculateServerScore(String server, ServerHealthData? health) {
    double score = 0.0;

    // Base score
    score += 50.0;

    // Health-based scoring with improved weighting
    if (health != null) {
      // Success rate (0-40 points) - increased weight for reliability
      score += health.successRate * 40.0;

      // Response time (0-30 points, faster is better) - increased weight for speed
      if (health.avgResponseTime > 0) {
        final responseScore =
            (2000 - health.avgResponseTime.clamp(0, 2000)) / 2000 * 30.0;
        score += responseScore;
      }

      // Recent activity bonus (servers used recently get priority)
      final hoursSinceLastCheck =
          DateTime.now().difference(health.lastChecked).inHours;
      if (hoursSinceLastCheck < 1) {
        score += 10.0; // Recent activity bonus
      } else if (hoursSinceLastCheck < 6) {
        score += 5.0; // Moderate activity bonus
      }

      // Recent failures penalty (exponential penalty for consecutive failures)
      if (health.recentFailures > 0) {
        score -= health.recentFailures * health.recentFailures * 3.0;
      }

      // Stability bonus for consistent performers
      if (health.totalRequests > 10 && health.successRate > 0.9) {
        score += 15.0;
      }
    } else {
      // New servers get a moderate score to allow testing
      score += 20.0;
    }

    return score.clamp(0.0, 150.0);
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

  /// Fetch servers from a specific endpoint with optimizations
  Future<List<String>> _fetchFromEndpoint(
      String endpoint, Function(String)? onStatusUpdate) async {
    final stopwatch = Stopwatch()..start();
    final endpointName = _getEndpointName(endpoint);

    try {
      onStatusUpdate?.call('Connecting to $endpointName...');

      final response = await _dio.get<String>(
        endpoint,
        options: Options(
          responseType: ResponseType.plain,
          headers: {
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
            'Expires': '0',
          },
          receiveTimeout: _requestTimeout,
          sendTimeout: _requestTimeout,
        ),
      );

      stopwatch.stop();
      print('Fetched from $endpointName in ${stopwatch.elapsedMilliseconds}ms');

      if (response.statusCode == 200 && response.data != null) {
        onStatusUpdate?.call('Processing response from $endpointName...');
        final servers = _processServerData(response.data!);
        if (servers.isNotEmpty) {
          onStatusUpdate?.call(
              'Found ${servers.length} valid servers from $endpointName');
          return servers;
        }
        throw Exception('No valid servers found in response');
      }

      throw Exception('Server responded with status: ${response.statusCode}');
    } on DioException catch (e) {
      stopwatch.stop();
      final errorMsg = 'Network error (${e.type}): ${e.message}';
      onStatusUpdate?.call('Error: $endpointName - ${e.message}');
      print(
          '$errorMsg\nURL: $endpoint\nTime: ${stopwatch.elapsedMilliseconds}ms');
      rethrow;
    } catch (e, stackTrace) {
      stopwatch.stop();
      onStatusUpdate?.call('Failed to process $endpointName');
      print('Error processing $endpoint: $e\n$stackTrace');
      rethrow;
    } finally {
      if (stopwatch.isRunning) stopwatch.stop();
    }
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
      final pingResult =
          await _pingServer(serverDetails['address'], serverDetails['port']);

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
      // Handle different protocol formats
      if (server.startsWith('vless://')) {
        return _parseVlessConfig(server);
      } else if (server.startsWith('vmess://')) {
        return _parseVmessConfig(server);
      } else if (server.startsWith('trojan://')) {
        return _parseTrojanConfig(server);
      } else if (server.startsWith('ss://')) {
        return _parseShadowsocksConfig(server);
      }

      // Fallback: try to decode as base64 JSON (legacy VMess)
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
        // Ignore base64 decode errors for URL-based configs
      }
    } catch (e) {
      print('Error extracting server details: $e');
    }
    return null;
  }

  /// Parse VLess configuration
  Map<String, dynamic>? _parseVlessConfig(String config) {
    try {
      final uri = Uri.parse(config);
      return {
        'address': uri.host,
        'port': uri.port,
      };
    } catch (e) {
      print('Error parsing VLess config: $e');
      return null;
    }
  }

  /// Parse VMess configuration
  Map<String, dynamic>? _parseVmessConfig(String config) {
    try {
      // Remove vmess:// prefix and decode base64
      final base64Part = config.substring(8);
      final decoded = base64.decode(base64Part);
      final decodedString = utf8.decode(decoded);
      final jsonData = json.decode(decodedString);

      return {
        'address': jsonData['add'] ?? jsonData['address'],
        'port': int.tryParse(jsonData['port']?.toString() ?? '0') ?? 0,
      };
    } catch (e) {
      print('Error parsing VMess config: $e');
      return null;
    }
  }

  /// Parse Trojan configuration
  Map<String, dynamic>? _parseTrojanConfig(String config) {
    try {
      final uri = Uri.parse(config);
      return {
        'address': uri.host,
        'port': uri.port,
      };
    } catch (e) {
      print('Error parsing Trojan config: $e');
      return null;
    }
  }

  /// Parse Shadowsocks configuration
  Map<String, dynamic>? _parseShadowsocksConfig(String config) {
    try {
      final uri = Uri.parse(config);
      return {
        'address': uri.host,
        'port': uri.port,
      };
    } catch (e) {
      print('Error parsing Shadowsocks config: $e');
      return null;
    }
  }

  /// Optimized ping test with connection pooling
  Future<int> _pingServer(String address, int port) async {
    final startTime = DateTime.now();

    try {
      // For main ping test, run without timeout to ensure accurate results
      final socket = await Socket.connect(
        address,
        port,
        timeout: Duration(seconds: 0), // No timeout for main ping test
      );

      final endTime = DateTime.now();
      await socket.close();

      return endTime.difference(startTime).inMilliseconds;
    } catch (e) {
      final endTime = DateTime.now();
      final elapsed = endTime.difference(startTime).inMilliseconds;

      // Return high ping instead of throwing for timeout cases
      if (e.toString().contains('timeout') ||
          elapsed >= _pingTimeout.inMilliseconds) {
        return 9999; // High ping indicates poor connection
      }

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
      health.avgResponseTime =
          health.totalResponseTime / health.successfulRequests;
    } else {
      health.recentFailures++;
    }

    // Reset recent failures after some time - Reduced to 15 minutes
    if (now.difference(health.lastFailureReset) > const Duration(minutes: 15)) {
      health.recentFailures = 0;
      health.lastFailureReset = now;
    }

    health.lastChecked = now;
  }

  /// Get user location for intelligent server selection
  Future<void> _getUserLocation() async {
    try {
      // Location processing removed for optimization
      // For now, we'll skip location services to avoid permission issues
      // This can be implemented later with proper permission handling
    } catch (e) {
      print('Error getting user location: $e');
    }
  }

  /// Start background health monitoring - Reduced to 15 minutes
  void _startHealthMonitoring() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(Duration(minutes: 15), (timer) {
      _performBackgroundHealthCheck();
    });
  }

  /// Perform optimized background health check
  Future<void> _performBackgroundHealthCheck() async {
    try {
      final servers = await _getCachedServers();
      if (servers.isEmpty) return;

      // Test ALL servers for complete health monitoring (no limitations)
      final serversToTest = servers; // Test all available servers
      final futures =
          serversToTest.map((server) => testServerConnection(server).timeout(
                Duration(seconds: 5),
                onTimeout: () => ServerTestResult(
                  server: server,
                  success: false,
                  responseTime: 5000,
                  error: 'Health check timeout',
                ),
              ));

      await Future.wait(futures, eagerError: false);

      // Save updated health data asynchronously
      unawaited(_saveHealthData());
    } catch (e) {
      print('Error in background health check: $e');
    }
  }

  /// Cache management methods with optimization
  Future<bool> _isCacheValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheTimeString = prefs.getString(_cacheTimeKey);
      if (cacheTimeString == null) return false;

      final cacheTime = DateTime.parse(cacheTimeString);
      final age = DateTime.now().difference(cacheTime);

      // Use 15 minute cache for consistency
      return age < Duration(minutes: 15);
    } catch (e) {
      print('Error checking cache validity: $e');
      return false;
    }
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
        _serverHealth.clear();
        _serverHealth.addAll(Map<String, ServerHealthData>.from(healthData.map(
            (key, value) => MapEntry(key, ServerHealthData.fromJson(value)))));
      } catch (e) {
        print('Error loading health data: $e');
      }
    }
  }

  Future<void> _saveHealthData() async {
    final prefs = await SharedPreferences.getInstance();
    final healthData =
        _serverHealth.map((key, value) => MapEntry(key, value.toJson()));
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
    _saveHealthData();
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

  double get successRate =>
      totalRequests > 0 ? successfulRequests / totalRequests : 0.0;

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
    health.lastChecked =
        DateTime.parse(json['lastChecked'] ?? DateTime.now().toIso8601String());
    health.lastFailureReset = DateTime.parse(
        json['lastFailureReset'] ?? DateTime.now().toIso8601String());
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
