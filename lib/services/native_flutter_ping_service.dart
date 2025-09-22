import 'dart:async';
import '../services/native_ping_service.dart';

/// Native ping service replacement for FlutterV2rayPingService
/// Uses Kotlin TCP and ICMP ping instead of V2Ray for better performance
class NativeFlutterPingService {
  static final NativeFlutterPingService _instance =
      NativeFlutterPingService._internal();
  factory NativeFlutterPingService() => _instance;
  NativeFlutterPingService._internal();

  final NativePingService _nativePingService = NativePingService();
  bool _isInitialized = false;

  // Cache for ping results
  final Map<String, int> _pingCache = {};
  final Map<String, DateTime> _pingTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 15);

  /// Initialize the native ping service
  void initialize() {
    if (!_isInitialized) {
      _isInitialized = true;
      print(
          '🏓 NativeFlutterPingService initialized with Kotlin TCP/ICMP ping');
    }
  }

  /// Test server ping using native Kotlin implementation
  /// This replaces the V2Ray ping functionality
  Future<int> testServerPing(
    String serverConfig, {
    int? timeoutSeconds,
    bool enableRetry = true,
    bool useCache = true,
    bool forceRetest = false,
  }) async {
    if (!_isInitialized) {
      initialize();
    }

    // Check cache first
    if (useCache && !forceRetest) {
      final cached = _getCachedPing(serverConfig);
      if (cached != null) {
        print('💾 Using cached native ping result: ${cached}ms');
        return cached;
      }
    }

    try {
      // Use native ping service instead of V2Ray
      final timeoutMs = timeoutSeconds != null ? timeoutSeconds * 1000 : 2000;
      final pingTime = await _nativePingService.pingServerConfig(
        serverConfig,
        timeoutMs: timeoutMs,
      );

      // Cache successful results
      if (pingTime > 0) {
        _cachePing(serverConfig, pingTime);
      }

      return pingTime;
    } catch (e) {
      print('❌ Native ping test failed: $e');
      return -1;
    }
  }

  /// Test multiple servers with native ping
  Future<Map<String, int>> testMultipleServerPings(
    List<String> serverConfigs, {
    int? timeoutSeconds,
    bool parallel = true,
    Function(int completed, int total)? onProgress,
    Function(String server, int ping)? onServerComplete,
    int? maxConcurrent,
    bool enableRetry = true,
    Future<List<String>> Function(List<String> servers)? tcpFilter,
  }) async {
    if (!_isInitialized) {
      initialize();
    }

    print(
        '🚀 Starting native batch ping test for ${serverConfigs.length} servers');

    try {
      final timeoutMs = timeoutSeconds != null ? timeoutSeconds * 1000 : 2000;

      // Use native batch ping implementation
      final results = await _nativePingService.batchPingServerConfigs(
        serverConfigs,
        timeoutMs: timeoutMs,
      );

      // Process results and update cache
      final finalResults = <String, int>{};
      int completed = 0;

      results.forEach((config, pingTime) {
        completed++;
        finalResults[config] = pingTime;

        // Cache successful results
        if (pingTime > 0) {
          _cachePing(config, pingTime);
        }

        // Report progress
        if (onProgress != null) {
          onProgress(completed, serverConfigs.length);
        }

        if (onServerComplete != null) {
          onServerComplete(config, pingTime);
        }
      });

      print('✅ Native batch ping completed: ${finalResults.length} results');
      return finalResults;
    } catch (e) {
      print('❌ Native batch ping error: $e');
      return {};
    }
  }

  /// Get cached ping result
  int? _getCachedPing(String serverConfig) {
    final timestamp = _pingTimestamps[serverConfig];
    if (timestamp != null) {
      if (DateTime.now().difference(timestamp) < _cacheExpiry) {
        return _pingCache[serverConfig];
      } else {
        // Remove expired cache
        _pingCache.remove(serverConfig);
        _pingTimestamps.remove(serverConfig);
      }
    }
    return null;
  }

  /// Cache ping result
  void _cachePing(String serverConfig, int pingTime) {
    _pingCache[serverConfig] = pingTime;
    _pingTimestamps[serverConfig] = DateTime.now();
  }

  /// Clean up expired cache entries
  void cleanupExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    _pingTimestamps.forEach((key, timestamp) {
      if (now.difference(timestamp) > _cacheExpiry) {
        expiredKeys.add(key);
      }
    });

    for (final key in expiredKeys) {
      _pingCache.remove(key);
      _pingTimestamps.remove(key);
    }

    if (expiredKeys.isNotEmpty) {
      print(
          '🧹 Cleaned up ${expiredKeys.length} expired native ping cache entries');
    }
  }

  /// Dispose resources
  void dispose() {
    _pingCache.clear();
    _pingTimestamps.clear();
    _isInitialized = false;
    print('🔄 NativeFlutterPingService disposed');
  }

  /// Get performance statistics
  Map<String, dynamic> getPerformanceStats() {
    return {
      'total_cached_pings': _pingCache.length,
      'cache_hit_ratio': _pingCache.isNotEmpty ? 1.0 : 0.0, // Simplified
      'ping_method': 'Native Kotlin TCP/ICMP',
      'is_initialized': _isInitialized,
    };
  }

  /// Smart ping with method selection
  Future<Map<String, dynamic>> smartPing(String host,
      {int port = 80, int timeoutMs = 1000}) async {
    try {
      final result = await _nativePingService.smartPing(host,
          port: port, timeoutMs: timeoutMs);
      return {
        'time': result.time,
        'method': result.method,
        'success': result.success,
        'ping_type': 'native_smart',
      };
    } catch (e) {
      return {
        'time': -1,
        'method': 'FAILED',
        'success': false,
        'ping_type': 'native_smart',
        'error': e.toString(),
      };
    }
  }

  /// ICMP ping specifically
  Future<int> icmpPing(String host, {int timeoutMs = 2000}) async {
    try {
      return await _nativePingService.icmpPing(host, timeoutMs: timeoutMs);
    } catch (e) {
      print('❌ Native ICMP ping failed: $e');
      return -1;
    }
  }

  /// Clear all cached failures (compatibility method)
  void clearAllFailures() {
    // For native ping, we just clear all cached results
    _pingCache.clear();
    _pingTimestamps.clear();
    print('🧹 Cleared all native ping cache and failures');
  }

  /// Get ping statistics (compatibility method)
  Map<String, dynamic> getPingStatistics(Map<String, int> results) {
    final successful = results.values.where((ping) => ping > 0).length;
    final total = results.length;
    final successRate = total > 0 ? (successful / total) * 100 : 0.0;

    final validPings = results.values.where((ping) => ping > 0).toList();
    final averagePing = validPings.isNotEmpty
        ? validPings.reduce((a, b) => a + b) / validPings.length
        : 0.0;

    return {
      'successful_pings': successful,
      'total_pings': total,
      'success_rate': successRate,
      'average_ping': averagePing,
      'ping_method': 'Native Kotlin TCP/ICMP',
    };
  }
}
