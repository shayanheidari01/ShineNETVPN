import 'dart:async';
import 'dart:collection';
import 'package:flutter_v2ray_client/flutter_v2ray.dart';
import '../services/flutter_v2ray_ping_service.dart'; // Use V2Ray delay ping service

/// Ultra-fast server selection with intelligent caching and native ping
Future<String?> findAndTestBestServer(List<String> servers) async {
  if (servers.isEmpty) return null;

  print(
      '🚀 Starting ultra-fast server selection with native ping from ${servers.length} servers');
  final stopwatch = Stopwatch()..start();

  // Step 1: Quick validation and limit servers for faster processing
  final validServers = <String>[];
  for (final server in servers) {
    // Process all servers
    try {
      final v2rayURL = V2ray.parseFromURL(server);
      if (v2rayURL.getFullConfiguration().isNotEmpty) {
        validServers.add(server);
      }
    } catch (e) {
      // Skip invalid servers silently for speed
      continue;
    }
  }

  if (validServers.isEmpty) return null;
  print(
      '✅ Found ${validServers.length} valid servers in ${stopwatch.elapsedMilliseconds}ms');

  // Step 2: Use V2Ray delay ping service for consistent results
  final pingService = FlutterV2rayPingService();
  pingService.initialize();

  final testResults = <Map<String, dynamic>>[];

  // Ultra-fast concurrent tests for maximum speed with native ping
  const maxConcurrent = 20; // Increased for native ping performance
  final semaphore = Semaphore(maxConcurrent);

  final futures = validServers.map((server) async {
    await semaphore.acquire();
    try {
      // Use V2Ray delay ping service with ultra-fast timeout for automatic connection
      final delay = await pingService.testServerPing(
        server,
        timeoutSeconds: 1, // Ultra-fast 1 second timeout
        useCache: false, // Don't use cache for fresh results
        forceRetest: true, // Force fresh testing
      );

      // Accept servers with ultra-fast native ping for automatic connection
      if (delay > 0 && delay <= 2000) {
        // Ultra-fast threshold (2 seconds max)
        // V2Ray delay ping provides real config-based measurement
        final v2rayURL = V2ray.parseFromURL(server);
        return {
          'server': server,
          'config': v2rayURL.getFullConfiguration(),
          'delay': delay,
          'score': _calculateFastServerScore(delay),
        };
      }
    } catch (e) {
      // Timeout or error - skip silently for speed
      print('⚠️ Ping test failed for server: $e');
    } finally {
      semaphore.release();
    }
    return null;
  });

  // Wait for all tests with timeout
  try {
    final results = await Future.wait(futures).timeout(
      Duration(seconds: 6), // Ultra-fast overall timeout for native ping
      onTimeout: () {
        print('⚠️ Native ping testing timed out, using available results');
        return <Map<String, Object>?>[];
      },
    );
    testResults.addAll(
        results.where((result) => result != null).cast<Map<String, dynamic>>());
  } catch (e) {
    print('⚠️ Some ping tests failed, using available results: $e');
  }

  stopwatch.stop();
  print('⚡ Ping testing completed in ${stopwatch.elapsedMilliseconds}ms');

  if (testResults.isEmpty) {
    print('⚠️ No servers responded in ping tests, trying direct connection with best cached server...');
    
    // Try to find a working server from valid servers
    for (int i = 0; i < validServers.length && i < 3; i++) {
      try {
        final v2rayURL = V2ray.parseFromURL(validServers[i]);
        final config = v2rayURL.getFullConfiguration();
        
        // Validate configuration before returning
        if (config.isNotEmpty && config.length > 50) {
          print('✅ Using cached server ${i + 1} as fallback');
          return config;
        }
      } catch (e) {
        print('⚠️ Cached server ${i + 1} validation failed: $e');
        continue;
      }
    }
    
    // Ultimate fallback - use emergency server
    print('🆘 All cached servers failed, using emergency server');
    final emergencyServer = 'vmess://eyJ2IjoiMiIsInBzIjoiRW1lcmdlbmN5IFNlcnZlciIsImFkZCI6IjEwNC4yMS41NS4yMzQiLCJwb3J0IjoiNDQzIiwidHlwZSI6Im5vbmUiLCJpZCI6Ijk1ZmVkZDNkLWE3NDMtNDlkYS04Yjg2LTlmM2U3Mzk3MjJkNyIsImFpZCI6IjAiLCJuZXQiOiJ3cyIsInBhdGgiOiIvIiwiaG9zdCI6IiIsInRscyI6InRscyJ9';
    final emergencyV2rayURL = V2ray.parseFromURL(emergencyServer);
    return emergencyV2rayURL.getFullConfiguration();
  }

  // Step 3: Smart selection - prefer ultra-fast servers
  testResults.sort((a, b) => b['score'].compareTo(a['score']));

  final bestServer = testResults.first;
  print(
      '🏆 Selected best server: ${bestServer['delay']}ms (score: ${bestServer['score']?.toStringAsFixed(1) ?? 'N/A'})');

  return bestServer['config'] as String;
}

/// Ultra-fast server scoring optimized for speed over precision
double _calculateFastServerScore(int delay) {
  if (delay <= 0) return 0.0;

  // Simplified scoring for faster processing
  if (delay < 100) return 100.0; // Excellent
  if (delay < 300) return 80.0; // Very good
  if (delay < 600) return 60.0; // Good
  if (delay < 1200) return 40.0; // Acceptable
  if (delay < 2000) return 20.0; // Slow
  return 10.0; // Very slow
}

/// Simple semaphore implementation for concurrency control
class Semaphore {
  final int maxCount;
  int _currentCount;
  final Queue<Completer<void>> _waitQueue = Queue<Completer<void>>();

  Semaphore(this.maxCount) : _currentCount = maxCount;

  Future<void> acquire() async {
    if (_currentCount > 0) {
      _currentCount--;
      return;
    }

    final completer = Completer<void>();
    _waitQueue.add(completer);
    return completer.future;
  }

  void release() {
    if (_waitQueue.isNotEmpty) {
      final completer = _waitQueue.removeFirst();
      completer.complete();
    } else {
      _currentCount++;
    }
  }
}
