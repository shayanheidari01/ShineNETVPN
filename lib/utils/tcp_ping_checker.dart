import 'dart:async';
import 'dart:math';
import '../services/native_ping_service.dart'; // Use native Kotlin ping service

class TCPPingChecker {
  static final NativePingService _nativePingService = NativePingService();

  /// Ultra-fast TCP ping using native Kotlin implementation
  static Future<bool> isServerReachableUltraFast(String serverConfig,
      {int timeoutMilliseconds = 800}) async {
    try {
      final pingTime = await _nativePingService.pingServerConfig(
        serverConfig,
        timeoutMs: timeoutMilliseconds,
      );

      // Return true if ping was successful (positive value)
      return pingTime > 0;
    } catch (e) {
      print('❌ Native TCP ping failed: $e');
      return false;
    }
  }

  /// Standard TCP ping check using native Kotlin implementation
  static Future<bool> isServerReachable(String serverConfig,
      {int timeoutSeconds = 2}) async {
    try {
      final timeoutMs = timeoutSeconds * 1000;
      final pingTime = await _nativePingService.pingServerConfig(
        serverConfig,
        timeoutMs: timeoutMs,
      );

      // Return true if ping was successful (positive value)
      return pingTime > 0;
    } catch (e) {
      print('❌ Native TCP ping failed: $e');
      return false;
    }
  }

  /// Validate host format for network connectivity (simplified for native implementation)
  static bool isValidHost(String host) {
    if (host.isEmpty) return false;

    // Simple validation - let the native implementation handle detailed validation
    return !host.contains(' ') && host.length > 0;
  }

  /// Ultra-fast batch server filtering using native Kotlin implementation with caching
  static Future<List<String>> filterReachableServers(
    List<String> serverConfigs, {
    int timeoutSeconds = 1,
    int maxConcurrent = 25,
    Function(int completed, int total)? onProgress,
  }) async {
    print(
        '🚀 Enhanced native filtering ${serverConfigs.length} servers (max $maxConcurrent concurrent)...');

    if (serverConfigs.isEmpty) return [];

    try {
      final timeoutMs = timeoutSeconds * 1000;

      // Early termination optimization: stop when we have enough good servers
      const int earlyTerminationThreshold = 10;
      final reachableServers = <String>[];

      // Process servers in intelligent batches
      final batchSize = min(maxConcurrent, 15);
      final batches = <List<String>>[];

      for (int i = 0; i < serverConfigs.length; i += batchSize) {
        final end = min(i + batchSize, serverConfigs.length);
        batches.add(serverConfigs.sublist(i, end));
      }

      int totalCompleted = 0;

      for (int batchIndex = 0; batchIndex < batches.length; batchIndex++) {
        final batch = batches[batchIndex];

        // Use native batch TCP ping
        final results = await _nativePingService.batchPingServerConfigs(
          batch,
          timeoutMs: timeoutMs,
        );

        // Process results
        results.forEach((config, pingTime) {
          totalCompleted++;
          if (pingTime > 0) {
            reachableServers.add(config);
          }

          // Report progress if callback provided
          if (onProgress != null) {
            onProgress(totalCompleted, serverConfigs.length);
          }
        });

        // Early termination for speed
        if (reachableServers.length >= earlyTerminationThreshold &&
            batchIndex >= 2) {
          print(
              '🚀 Early termination: Found ${reachableServers.length} good servers');
          break;
        }

        // Small delay between batches to prevent overwhelming
        if (batchIndex < batches.length - 1) {
          await Future.delayed(Duration(milliseconds: 20));
        }
      }

      print(
          '✅ Enhanced native filtering completed. ${reachableServers.length}/${totalCompleted} servers are reachable');
      return reachableServers;
    } catch (e) {
      print('❌ Enhanced native filtering error: $e');
      return [];
    }
  }

  /// Ultra-fast server filtering for automatic connection using native implementation
  static Future<List<String>> filterReachableServersUltraFast(
    List<String> serverConfigs, {
    int timeoutMilliseconds = 800,
    int maxConcurrent = 50,
    Function(int completed, int total)? onProgress,
  }) async {
    print(
        '🚀 Ultra-fast native filtering ${serverConfigs.length} servers for automatic connection...');

    try {
      // Use native batch TCP ping with ultra-fast settings
      final results = await _nativePingService.batchPingServerConfigs(
        serverConfigs,
        timeoutMs: timeoutMilliseconds,
      );

      // Filter successful pings
      final reachableServers = <String>[];
      int completed = 0;
      results.forEach((config, pingTime) {
        completed++;
        if (pingTime > 0) {
          reachableServers.add(config);
        }

        // Report progress if callback provided
        if (onProgress != null) {
          onProgress(completed, serverConfigs.length);
        }
      });

      print(
          '✅ Ultra-fast native filtering completed. ${reachableServers.length}/${serverConfigs.length} servers are reachable');
      return reachableServers;
    } catch (e) {
      print('❌ Ultra-fast native filtering error: $e');
      return [];
    }
  }

  /// Get ping time with detailed result information using native implementation
  static Future<Map<String, dynamic>> getPingDetails(String serverConfig,
      {int timeoutMs = 1000}) async {
    try {
      final result = await _nativePingService.smartPing(
        serverConfig.split(':')[0], // Extract host
        port: serverConfig.contains(':')
            ? int.tryParse(serverConfig.split(':')[1]) ?? 80
            : 80,
        timeoutMs: timeoutMs,
      );

      return {
        'time': result.time,
        'method': result.method,
        'success': result.success,
        'reachable': result.success,
      };
    } catch (e) {
      return {
        'time': -1,
        'method': 'FAILED',
        'success': false,
        'reachable': false,
        'error': e.toString(),
      };
    }
  }

  /// Validate server configuration format before TCP ping testing
  static bool isValidServerConfig(String serverConfig) {
    if (serverConfig.isEmpty) {
      return false;
    }

    // Let the native implementation handle format validation
    return true; // Native service will handle validation
  }

  /// ICMP ping using native Kotlin implementation
  static Future<int> icmpPing(String host, {int timeoutMs = 2000}) async {
    try {
      return await _nativePingService.icmpPing(host, timeoutMs: timeoutMs);
    } catch (e) {
      print('❌ Native ICMP ping failed: $e');
      return -1;
    }
  }

  /// Batch ICMP ping using native Kotlin implementation
  static Future<Map<String, int>> batchIcmpPing(List<String> hosts,
      {int timeoutMs = 2000}) async {
    try {
      return await _nativePingService.batchIcmpPing(hosts,
          timeoutMs: timeoutMs);
    } catch (e) {
      print('❌ Native batch ICMP ping failed: $e');
      return {};
    }
  }

  /// Smart ping that tries TCP first, falls back to ICMP
  static Future<Map<String, dynamic>> smartPing(String host,
      {int port = 80, int timeoutMs = 1000}) async {
    try {
      final result = await _nativePingService.smartPing(host,
          port: port, timeoutMs: timeoutMs);
      return {
        'time': result.time,
        'method': result.method,
        'success': result.success,
      };
    } catch (e) {
      print('❌ Native smart ping failed: $e');
      return {
        'time': -1,
        'method': 'FAILED',
        'success': false,
      };
    }
  }
}
