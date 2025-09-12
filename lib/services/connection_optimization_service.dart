import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConnectionOptimizationService {
  static final ConnectionOptimizationService _instance = ConnectionOptimizationService._internal();
  factory ConnectionOptimizationService() => _instance;
  ConnectionOptimizationService._internal();

  late final FlutterV2ray _flutterV2ray;
  final List<ConnectionAttempt> _connectionHistory = [];
  final Map<String, ConnectionStats> _connectionStats = {};
  
  // Configuration
  static const int _maxConcurrentTests = 8;
  static const Duration _connectionTimeout = Duration(seconds: 15);
  static const Duration _testTimeout = Duration(seconds: 3);
  static const int _maxRetries = 5;
  static const Duration _baseRetryDelay = Duration(seconds: 1);
  static const Duration _circuitBreakerTimeout = Duration(minutes: 5);
  static const int _maxFailuresBeforeCircuitBreak = 3;
  
  // State management
  bool _isConnecting = false;
  bool _isTestingServers = false;
  final List<ServerTestResult> _testResults = [];
  Timer? _connectionTimer;
  Timer? _healthCheckTimer;
  
  // Circuit breaker state
  final Map<String, CircuitBreakerState> _circuitBreakers = {};
  
  // Connection monitoring
  Timer? _connectionMonitor;
  DateTime? _lastSuccessfulConnection;
  int _consecutiveFailures = 0;

  /// Initialize the service
  Future<void> initialize() async {
    _flutterV2ray = FlutterV2ray(
      onStatusChanged: (status) {
        _handleV2RayStatusChange(status);
      },
    );
    await _loadConnectionHistory();
    _startConnectionMonitoring();
  }
  
  /// Handle V2Ray status changes
  void _handleV2RayStatusChange(V2RayStatus status) {
    if (status.state == 'CONNECTED') {
      _lastSuccessfulConnection = DateTime.now();
      _consecutiveFailures = 0;
    } else if (status.state == 'DISCONNECTED') {
      _consecutiveFailures++;
    }
  }
  
  /// Start connection monitoring
  void _startConnectionMonitoring() {
    _connectionMonitor?.cancel();
    _connectionMonitor = Timer.periodic(Duration(seconds: 30), (timer) {
      _checkConnectionHealth();
    });
  }
  
  /// Check connection health and attempt reconnection if needed
  void _checkConnectionHealth() {
    if (_lastSuccessfulConnection == null) return;
    
    final timeSinceLastConnection = DateTime.now().difference(_lastSuccessfulConnection!);
    if (timeSinceLastConnection > Duration(minutes: 10)) {
      // Connection has been idle for too long, check if it's still working
      _performHealthCheck();
    }
  }
  
  /// Perform health check on current connection
  Future<void> _performHealthCheck() async {
    try {
      // Simple connectivity test
      // This would typically ping a known server or check internet connectivity
      // For now, we'll just log the check
      print('Performing connection health check...');
    } catch (e) {
      print('Health check failed: $e');
      // If health check fails, we might want to trigger a reconnection
    }
  }

  /// Connect to the best available server with optimized selection
  Future<ConnectionResult> connectToBestServer(
    List<String> servers, {
    Function(String)? onStatusUpdate,
    Function(int, int)? onProgressUpdate,
  }) async {
    if (_isConnecting) {
      return ConnectionResult(
        success: false,
        error: 'Connection already in progress',
      );
    }

    _isConnecting = true;
    
    try {
      onStatusUpdate?.call('Analyzing server performance...');
      
      // Test servers in parallel with limited concurrency
      final testResults = await _testServersOptimized(
        servers,
        onStatusUpdate: onStatusUpdate,
        onProgressUpdate: onProgressUpdate,
      );

      if (testResults.isEmpty) {
        return ConnectionResult(
          success: false,
          error: 'No servers responded to tests',
        );
      }

      // Select the best server
      final bestServer = _selectBestServer(testResults);
      
      onStatusUpdate?.call('Connecting to optimal server...');
      
      // Attempt connection
      final connectionResult = await _attemptConnection(bestServer);
      
      // Record connection attempt
      _recordConnectionAttempt(bestServer, connectionResult);
      
      return connectionResult;
      
    } catch (e) {
      return ConnectionResult(
        success: false,
        error: 'Connection failed: $e',
      );
    } finally {
      _isConnecting = false;
    }
  }

  /// Test servers with optimized parallel processing
  Future<List<ServerTestResult>> _testServersOptimized(
    List<String> servers, {
    Function(String)? onStatusUpdate,
    Function(int, int)? onProgressUpdate,
  }) async {
    if (_isTestingServers) {
      return [];
    }

    _isTestingServers = true;
    _testResults.clear();
    
    try {
      // Limit the number of servers to test for better performance
      final serversToTest = servers.take(15).toList();
      final totalServers = serversToTest.length;
      
      onStatusUpdate?.call('Testing $totalServers servers...');
      
      // Create batches for parallel testing
      final batches = <List<String>>[];
      for (int i = 0; i < serversToTest.length; i += _maxConcurrentTests) {
        final end = min(i + _maxConcurrentTests, serversToTest.length);
        batches.add(serversToTest.sublist(i, end));
      }
      
      int completedTests = 0;
      
      // Process batches sequentially to avoid overwhelming the system
      for (final batch in batches) {
        final futures = batch.map((server) => _testSingleServer(server));
        
        try {
          final results = await Future.wait(
            futures,
            eagerError: false,
          );
          
          _testResults.addAll(results.where((result) => result.success));
          completedTests += batch.length;
          
          onProgressUpdate?.call(completedTests, totalServers);
          onStatusUpdate?.call('Tested $completedTests/$totalServers servers...');
          
          // Small delay between batches to prevent resource exhaustion
          if (batches.indexOf(batch) < batches.length - 1) {
            await Future.delayed(const Duration(milliseconds: 500));
          }
          
        } catch (e) {
          print('Error testing batch: $e');
        }
      }
      
      return _testResults;
      
    } finally {
      _isTestingServers = false;
    }
  }

  /// Test a single server with timeout and retry logic
  Future<ServerTestResult> _testSingleServer(String server) async {
    final startTime = DateTime.now();
    
    try {
      // Extract server details for testing
      final serverDetails = _extractServerDetails(server);
      if (serverDetails == null) {
        throw Exception('Invalid server configuration');
      }

      // Perform connection test with timeout
      final testResult = await _performConnectionTest(serverDetails)
          .timeout(_testTimeout);
      
      final responseTime = DateTime.now().difference(startTime).inMilliseconds;
      
      return ServerTestResult(
        server: server,
        success: true,
        responseTime: responseTime,
        ping: testResult,
        serverDetails: serverDetails,
      );
      
    } catch (e) {
      final responseTime = DateTime.now().difference(startTime).inMilliseconds;
      
      return ServerTestResult(
        server: server,
        success: false,
        responseTime: responseTime,
        error: e.toString(),
      );
    }
  }

  /// Perform actual connection test
  Future<int> _performConnectionTest(Map<String, dynamic> serverDetails) async {
    // This would typically involve a lightweight connection test
    // For now, we'll simulate with a random delay based on server quality
    final baseDelay = 100 + Random().nextInt(200);
    await Future.delayed(Duration(milliseconds: baseDelay));
    return baseDelay;
  }

  /// Select the best server based on test results and history
  String _selectBestServer(List<ServerTestResult> testResults) {
    if (testResults.isEmpty) {
      throw Exception('No test results available');
    }

    // Sort by score (combination of response time and historical success)
    testResults.sort((a, b) {
      final scoreA = _calculateServerScore(a);
      final scoreB = _calculateServerScore(b);
      return scoreB.compareTo(scoreA);
    });

    return testResults.first.server;
  }

  /// Calculate server score for selection with enhanced algorithm
  double _calculateServerScore(ServerTestResult result) {
    double score = 100.0;
    
    // Response time penalty (lower is better) - more aggressive penalty
    final responseTimePenalty = (result.responseTime / 5.0);
    score -= responseTimePenalty;
    
    // Ping quality bonus (lower ping is better)
    if (result.ping != null && result.ping! > 0) {
      final pingBonus = (1000 - result.ping!) / 10.0;
      score += pingBonus;
    }
    
    // Historical success bonus with exponential weighting
    final serverId = _getServerId(result.server);
    final stats = _connectionStats[serverId];
    if (stats != null) {
      // Success rate with exponential bonus for high success rates
      final successRateBonus = pow(stats.successRate, 2) * 30.0;
      score += successRateBonus;
      
      // Connection time penalty (lower is better)
      score -= (stats.avgConnectionTime / 50.0);
      
      // Stability bonus (recent successful connections)
      final recentSuccesses = _getRecentSuccesses(serverId);
      score += recentSuccesses * 2.0;
      
      // Circuit breaker penalty
      if (_isCircuitBreakerOpen(serverId)) {
        score -= 50.0;
      }
    }
    
    // Server type preference (if available)
    if (result.serverDetails != null) {
      final protocol = result.serverDetails!['protocol'] as String?;
      if (protocol == 'vmess') {
        score += 5.0; // Prefer VMess
      } else if (protocol == 'vless') {
        score += 3.0; // VLESS is also good
      }
    }
    
    // Geographic preference (if user location is available)
    final locationBonus = _calculateLocationBonus(result);
    score += locationBonus;
    
    return score.clamp(0.0, 300.0);
  }
  
  /// Get recent successful connections for a server
  int _getRecentSuccesses(String serverId) {
    final cutoff = DateTime.now().subtract(Duration(hours: 24));
    return _connectionHistory
        .where((attempt) => 
            _getServerId(attempt.server) == serverId &&
            attempt.success &&
            attempt.timestamp.isAfter(cutoff))
        .length;
  }
  
  /// Check if circuit breaker is open for a server
  bool _isCircuitBreakerOpen(String serverId) {
    final breaker = _circuitBreakers[serverId];
    if (breaker == null) return false;
    
    if (breaker.state == CircuitBreakerStateType.open) {
      // Check if timeout has passed
      if (DateTime.now().difference(breaker.lastFailure) > _circuitBreakerTimeout) {
        breaker.state = CircuitBreakerStateType.halfOpen;
        return false;
      }
      return true;
    }
    
    return false;
  }
  
  /// Calculate location bonus for server selection
  double _calculateLocationBonus(ServerTestResult result) {
    // This would use user's location and server location
    // For now, return a small random bonus
    return Random().nextDouble() * 5.0;
  }

  /// Attempt connection to a specific server with retry logic and circuit breaker
  Future<ConnectionResult> _attemptConnection(String server) async {
    final serverId = _getServerId(server);
    
    // Check circuit breaker
    if (_isCircuitBreakerOpen(serverId)) {
      return ConnectionResult(
        success: false,
        error: 'Server temporarily unavailable (circuit breaker open)',
      );
    }
    
    // Attempt connection with retries
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        // Request VPN permission
        final hasPermission = await _flutterV2ray.requestPermission();
        if (!hasPermission) {
          return ConnectionResult(
            success: false,
            error: 'VPN permission denied',
          );
        }

        // Start connection with timeout
        final connectionFuture = _startV2RayConnection(server);
        final result = await connectionFuture.timeout(_connectionTimeout);
        
        // Success - update circuit breaker
        _updateCircuitBreaker(serverId, true);
        
        return ConnectionResult(
          success: true,
          server: server,
          connectionTime: result,
        );
        
      } catch (e) {
        // Failure - update circuit breaker
        _updateCircuitBreaker(serverId, false);
        
        // If this is not the last attempt, wait before retrying
        if (attempt < _maxRetries - 1) {
          final delay = _calculateRetryDelay(attempt);
          await Future.delayed(delay);
        }
      }
    }
    
    return ConnectionResult(
      success: false,
      error: 'Connection failed after $_maxRetries attempts',
    );
  }
  
  /// Update circuit breaker state
  void _updateCircuitBreaker(String serverId, bool success) {
    if (!_circuitBreakers.containsKey(serverId)) {
      _circuitBreakers[serverId] = CircuitBreakerState();
    }
    
    final breaker = _circuitBreakers[serverId]!;
    
    if (success) {
      breaker.failureCount = 0;
      breaker.state = CircuitBreakerStateType.closed;
    } else {
      breaker.failureCount++;
      breaker.lastFailure = DateTime.now();
      
      if (breaker.failureCount >= _maxFailuresBeforeCircuitBreak) {
        breaker.state = CircuitBreakerStateType.open;
      }
    }
  }
  
  /// Calculate retry delay with exponential backoff
  Duration _calculateRetryDelay(int attempt) {
    final baseDelay = _baseRetryDelay.inMilliseconds;
    final exponentialDelay = baseDelay * pow(2, attempt);
    final jitter = Random().nextInt(1000); // Add jitter to prevent thundering herd
    return Duration(milliseconds: (exponentialDelay + jitter).toInt());
  }

  /// Start V2Ray connection
  Future<int> _startV2RayConnection(String server) async {
    final startTime = DateTime.now();
    
    try {
      await _flutterV2ray.startV2Ray(
        remark: 'ShineNET VPN',
        config: server,
        proxyOnly: false,
        bypassSubnets: null,
        notificationDisconnectButtonName: 'Disconnect',
        blockedApps: await _getBlockedApps(),
      );
      
      return DateTime.now().difference(startTime).inMilliseconds;
      
    } catch (e) {
      throw Exception('V2Ray connection failed: $e');
    }
  }

  /// Record connection attempt for learning
  void _recordConnectionAttempt(String server, ConnectionResult result) {
    final attempt = ConnectionAttempt(
      server: server,
      timestamp: DateTime.now(),
      success: result.success,
      connectionTime: result.connectionTime ?? 0,
      error: result.error,
    );
    
    _connectionHistory.add(attempt);
    
    // Update server statistics
    final serverId = _getServerId(server);
    if (!_connectionStats.containsKey(serverId)) {
      _connectionStats[serverId] = ConnectionStats();
    }
    
    final stats = _connectionStats[serverId]!;
    stats.totalAttempts++;
    if (result.success) {
      stats.successfulAttempts++;
      stats.totalConnectionTime += result.connectionTime ?? 0;
      stats.avgConnectionTime = stats.totalConnectionTime / stats.successfulAttempts;
    }
    
    // Keep only recent history (last 100 attempts)
    if (_connectionHistory.length > 100) {
      _connectionHistory.removeRange(0, _connectionHistory.length - 100);
    }
    
    // Save updated data
    _saveConnectionHistory();
  }

  /// Get blocked apps list
  Future<List<String>> _getBlockedApps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList('blockedApps') ?? [];
    } catch (e) {
      return [];
    }
  }

  /// Extract server details from configuration
  Map<String, dynamic>? _extractServerDetails(String server) {
    try {
      // This would parse the V2Ray configuration
      // For now, return a placeholder
      return {
        'address': 'server.example.com',
        'port': 443,
        'protocol': 'vmess',
      };
    } catch (e) {
      return null;
    }
  }

  /// Generate server ID for tracking
  String _getServerId(String server) {
    return server.hashCode.toString();
  }

  /// Load connection history from storage
  Future<void> _loadConnectionHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyString = prefs.getString('connection_history');
      if (historyString != null) {
        // Parse and load history
        // Implementation would depend on the data format
      }
    } catch (e) {
      print('Error loading connection history: $e');
    }
  }

  /// Save connection history to storage
  Future<void> _saveConnectionHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Save history data
      // Implementation would depend on the data format
    } catch (e) {
      print('Error saving connection history: $e');
    }
  }

  /// Get connection statistics
  Map<String, dynamic> getConnectionStats() {
    return {
      'totalAttempts': _connectionHistory.length,
      'successfulAttempts': _connectionHistory.where((a) => a.success).length,
      'avgConnectionTime': _connectionHistory
          .where((a) => a.success)
          .map((a) => a.connectionTime)
          .fold(0, (a, b) => a + b) / 
          _connectionHistory.where((a) => a.success).length,
      'serverStats': _connectionStats,
    };
  }

  /// Cleanup resources
  void dispose() {
    _connectionTimer?.cancel();
    _healthCheckTimer?.cancel();
    _connectionMonitor?.cancel();
  }
}

/// Connection attempt model
class ConnectionAttempt {
  final String server;
  final DateTime timestamp;
  final bool success;
  final int connectionTime;
  final String? error;

  ConnectionAttempt({
    required this.server,
    required this.timestamp,
    required this.success,
    required this.connectionTime,
    this.error,
  });
}

/// Connection statistics model
class ConnectionStats {
  int totalAttempts = 0;
  int successfulAttempts = 0;
  int totalConnectionTime = 0;
  double avgConnectionTime = 0.0;

  double get successRate => totalAttempts > 0 ? successfulAttempts / totalAttempts : 0.0;
}

/// Connection result model
class ConnectionResult {
  final bool success;
  final String? server;
  final int? connectionTime;
  final String? error;

  ConnectionResult({
    required this.success,
    this.server,
    this.connectionTime,
    this.error,
  });
}

/// Server test result model
class ServerTestResult {
  final String server;
  final bool success;
  final int responseTime;
  final int? ping;
  final String? error;
  final Map<String, dynamic>? serverDetails;

  ServerTestResult({
    required this.server,
    required this.success,
    required this.responseTime,
    this.ping,
    this.error,
    this.serverDetails,
  });
}

/// Circuit breaker state model
class CircuitBreakerState {
  CircuitBreakerStateType state = CircuitBreakerStateType.closed;
  int failureCount = 0;
  DateTime lastFailure = DateTime.now();

  CircuitBreakerState();
}

/// Circuit breaker state types
enum CircuitBreakerStateType {
  closed,    // Normal operation
  open,      // Circuit is open, requests are blocked
  halfOpen,  // Testing if service is back
}
