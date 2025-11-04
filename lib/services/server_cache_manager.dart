import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'server_optimization_service.dart';
import 'flutter_v2ray_ping_service.dart'; // Use V2Ray delay ping for filtering

// Helper function for fire-and-forget operations
void unawaited(Future<void> future) {
  future.catchError((error) {
    print('Unawaited operation failed: $error');
  });
}

/// Advanced server cache management system
class ServerCacheManager {
  static final ServerCacheManager _instance = ServerCacheManager._internal();
  factory ServerCacheManager() => _instance;
  ServerCacheManager._internal();

  // Cache keys
  static const String _serverListKey = 'cached_server_list_v2';
  static const String _serverMetadataKey = 'server_metadata_v2';
  static const String _pingCacheKey = 'server_ping_cache_v2';
  static const String _healthCacheKey = 'server_health_cache_v2';
  static const String _tcpPingCacheKey =
      'server_tcp_ping_cache_v2'; // Add TCP ping cache key
  static const String _lastFetchKey = 'last_fetch_timestamp_v2';

  // Optimized cache configuration for maximum performance
  static const Duration _serverCacheExpiry =
      Duration(hours: 2); // Much longer cache for stability
  static const Duration _pingCacheExpiry =
      Duration(minutes: 30); // Longer ping cache
  static const Duration _healthCacheExpiry =
      Duration(hours: 1); // Longer health cache
  static const Duration _tcpPingCacheExpiry =
      Duration(minutes: 30); // Longer TCP ping cache

  // Performance optimization settings
  static const int _maxCachedServers = 100; // Higher limit for more servers
  static const int _maxPingHistory = 200; // More ping history

  // In-memory cache for ultra-fast access
  List<String>? _memoryCache;
  DateTime? _memoryCacheTime;
  Map<String, int>? _memoryPingCache;
  DateTime? _memoryPingCacheTime;

  /// Cache server list with metadata and TCP ping results
  Future<void> cacheServers(
    List<String> servers, {
    Map<String, dynamic>? metadata,
    Map<String, bool>? tcpPingResults, // Add TCP ping results parameter
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Cache servers
      await prefs.setStringList(_serverListKey, servers);
      await prefs.setInt(_lastFetchKey, timestamp);

      // Cache metadata if provided
      if (metadata != null) {
        await prefs.setString(_serverMetadataKey, jsonEncode(metadata));
      }

      // Cache TCP ping results if provided
      if (tcpPingResults != null) {
        final tcpCacheData = {
          'tcpPings': tcpPingResults,
          'timestamp': timestamp,
        };
        await prefs.setString(_tcpPingCacheKey, jsonEncode(tcpCacheData));
      }

      print('✅ Cached ${servers.length} servers with timestamp $timestamp');
    } catch (e) {
      print('❌ Failed to cache servers: $e');
    }
  }

  /// High-performance server fetch with optimized caching and error handling
  Future<List<String>> fetchAndCacheImmediately({
    Function(String)? onStatusUpdate,
    bool forceRefresh = true,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      onStatusUpdate?.call('🚀 Starting optimized server fetch...');

      // Check if we can use cached data first (unless force refresh)
      if (!forceRefresh) {
        final isValid = await isServerCacheValid();
        final cachedServers = await getCachedServers();
        if (isValid && cachedServers.isNotEmpty) {
          onStatusUpdate?.call(
              '⚡ Using cached servers (${cachedServers.length}) for better performance');
          return cachedServers;
        }
      }

      // Initialize server optimization service with timeout
      final serverOptimization = ServerOptimizationService();
      await serverOptimization.initialize().timeout(
            Duration(seconds: 10),
            onTimeout: () => throw TimeoutException(
                'Service initialization timeout', Duration(seconds: 10)),
          );

      onStatusUpdate?.call('🔍 Fetching optimized server list...');

      // Fetch servers with performance monitoring
      final servers = await serverOptimization
          .getOptimizedServerList(
            forceRefresh: forceRefresh,
            onStatusUpdate: onStatusUpdate,
          )
          .timeout(
            Duration(seconds: 30),
            onTimeout: () => throw TimeoutException(
                'Server fetch timeout', Duration(seconds: 30)),
          );

      if (servers.isEmpty) {
        throw Exception('No servers received from optimization service');
      }

      // Perform V2Ray delay ping testing only once after fetching servers
      onStatusUpdate?.call(
          '🔍 Performing V2Ray delay testing for ${servers.length} servers...');
      final tcpPingResults = <String, bool>{};

      final v2rayPing = FlutterV2rayPingService();
      v2rayPing.initialize();

      final existingPingCache = await getCachedPingResults();
      final serversToRetest = _selectServersForRobustTesting(
        servers,
        existingPingCache,
      );

      Map<String, int> focusedPingResults = {};

      if (serversToRetest.isNotEmpty) {
        final concurrency = max(1, min(serversToRetest.length, 6));
        onStatusUpdate?.call(
            '🛡️ Focused V2Ray delay testing for ${serversToRetest.length} key servers...');

        focusedPingResults = await v2rayPing.testMultipleServerPingsRobust(
          serversToRetest,
          timeoutSeconds: 3,
          parallel: true,
          maxConcurrent: concurrency,
          onProgress: (completed, total) {
            onStatusUpdate?.call(
                '🚀 V2Ray delay testing... ($completed/$total selected servers)');
          },
        );
      } else {
        print('ℹ️ Skipping focused V2Ray delay testing - using cached ping data');
      }

      final mergedPingResults = <String, int>{}
        ..addAll(existingPingCache)
        ..addAll(focusedPingResults);

      // Mark reachable servers (ping > 0 and < 9999) as true
      for (final server in servers) {
        final ping = mergedPingResults[server];
        if (ping == null) {
          tcpPingResults[server] = true; // Unknown ping - keep server available
        } else {
          tcpPingResults[server] = (ping > 0 && ping < 9999);
        }
      }

      final reachableCount = tcpPingResults.values.where((v) => v).length;
      print(
          '✅ V2Ray delay filtering completed: $reachableCount/${servers.length} servers are reachable');

      if (mergedPingResults.isNotEmpty) {
        await cachePingResults(mergedPingResults);
      }

      onStatusUpdate?.call(
          '💾 Caching ${servers.length} servers with metadata and TCP ping results...');

      // Cache with performance metadata and TCP ping results
      await cacheServers(servers,
          metadata: {
            'fetchTime': DateTime.now().toIso8601String(),
            'serverCount': servers.length,
            'fetchMethod': 'optimized_immediate',
            'fetchDuration': stopwatch.elapsedMilliseconds,
            'performanceGrade': _calculatePerformanceGrade(
                stopwatch.elapsedMilliseconds, servers.length),
          },
          tcpPingResults: tcpPingResults);

      stopwatch.stop();
      onStatusUpdate?.call(
          '✅ Successfully cached ${servers.length} servers in ${stopwatch.elapsedMilliseconds}ms!');

      return servers;
    } catch (e) {
      stopwatch.stop();
      onStatusUpdate?.call(
          '❌ Fetch failed after ${stopwatch.elapsedMilliseconds}ms: ${e.toString()}');

      // Enhanced fallback strategy
      return await _handleFetchFailure(e, onStatusUpdate);
    }
  }

  List<String> _selectServersForRobustTesting(
    List<String> servers,
    Map<String, int> existingPingCache, {
    int maxServers = 18,
  }) {
    if (servers.isEmpty || maxServers <= 0) {
      return [];
    }

    final newServers = <String>[];
    final staleServers = <String>[];
    final goodServers = <String>[];

    for (final server in servers) {
      final ping = existingPingCache[server];
      if (ping == null) {
        newServers.add(server);
      } else if (ping <= 0 || ping >= 9999) {
        staleServers.add(server);
      } else {
        goodServers.add(server);
      }
    }

    final selected = <String>{};

    void takeFrom(List<String> source) {
      for (final server in source) {
        if (selected.length >= maxServers) break;
        selected.add(server);
      }
    }

    takeFrom(newServers);
    takeFrom(staleServers);

    if (selected.length < maxServers && goodServers.isNotEmpty) {
      goodServers.sort((a, b) {
        final pingA = existingPingCache[a] ?? 9999;
        final pingB = existingPingCache[b] ?? 9999;
        return pingA.compareTo(pingB);
      });
      takeFrom(goodServers);
    }

    print(
        '🎯 Focused robust testing selection: ${selected.length} servers (new: ${newServers.length}, stale: ${staleServers.length}, cached: ${goodServers.length})');

    return selected.toList();
  }

  /// Calculate performance grade based on fetch time and server count
  String _calculatePerformanceGrade(int milliseconds, int serverCount) {
    final efficiency =
        serverCount / (milliseconds / 1000); // servers per second

    if (efficiency > 10) return 'Excellent';
    if (efficiency > 5) return 'Good';
    if (efficiency > 2) return 'Fair';
    return 'Poor';
  }

  /// Enhanced fallback handling for fetch failures
  Future<List<String>> _handleFetchFailure(
      dynamic error, Function(String)? onStatusUpdate) async {
    try {
      // Try to return any cached servers as fallback
      final cachedServers = await getCachedServers();
      if (cachedServers.isNotEmpty) {
        final cacheAge = await _getCacheAge();
        onStatusUpdate?.call(
            '📦 Using ${cachedServers.length} cached servers (${cacheAge} old) as fallback');
        return cachedServers;
      }

      // If no cache available, try emergency fallback
      onStatusUpdate
          ?.call('🆘 No cache available, attempting emergency fallback...');

      // This could trigger emergency server list from ServerOptimizationService
      final serverOptimization = ServerOptimizationService();
      // Use hardcoded emergency servers since getEmergencyServers is not available
      final emergencyServers = [
        'vmess://eyJ2IjoiMiIsInBzIjoiRW1lcmdlbmN5IFNlcnZlciAxIiwiYWRkIjoiMTA0LjIxLjU1LjIzNCIsInBvcnQiOiI0NDMiLCJ0eXBlIjoibm9uZSIsImlkIjoiOTVmZWRkM2QtYTc0My00OWRhLThiODYtOWYzZTczOTcyMmQ3IiwiYWlkIjoiMCIsIm5ldCI6IndzIiwicGF0aCI6Ii8iLCJob3N0IjoiIiwidGxzIjoidGxzIn0=',
        'vmess://eyJ2IjoiMiIsInBzIjoiRW1lcmdlbmN5IFNlcnZlciAyIiwiYWRkIjoiMTcyLjY3LjEzMC4xNTQiLCJwb3J0IjoiNDQzIiwidHlwZSI6Im5vbmUiLCJpZCI6Ijk1ZmVkZDNkLWE3NDMtNDlkYS04Yjg2LTlmM2U3Mzk3MjJkNyIsImFpZCI6IjAiLCJuZXQiOiJ3cyIsInBhdGgiOiIvIiwiaG9zdCI6IiIsInRscyI6InRscyJ9',
      ];

      if (emergencyServers.isNotEmpty) {
        await cacheServers(emergencyServers, metadata: {
          'fetchTime': DateTime.now().toIso8601String(),
          'serverCount': emergencyServers.length,
          'fetchMethod': 'emergency_fallback',
        });
        onStatusUpdate
            ?.call('🆘 Using ${emergencyServers.length} emergency servers');
        return emergencyServers;
      }
    } catch (fallbackError) {
      onStatusUpdate
          ?.call('❌ All fallback methods failed: ${fallbackError.toString()}');
      return []; // Return empty list instead of rethrowing
    }

    return []; // Return empty list as fallback
  }

  /// Get cache age in human readable format
  Future<String> _getCacheAge() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_lastFetchKey);
      if (timestamp != null) {
        final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final age = DateTime.now().difference(cacheTime);

        if (age.inDays > 0) return '${age.inDays}d';
        if (age.inHours > 0) return '${age.inHours}h';
        if (age.inMinutes > 0) return '${age.inMinutes}m';
        return '${age.inSeconds}s';
      }
    } catch (e) {
      // Ignore errors
    }
    return 'unknown';
  }

  /// Get cached servers with memory cache optimization
  Future<List<String>> getCachedServers() async {
    try {
      // Check memory cache first for ultra-fast access
      if (_memoryCache != null && _memoryCacheTime != null) {
        final cacheAge = DateTime.now().difference(_memoryCacheTime!);
        if (cacheAge < Duration(minutes: 5)) {
          // 5-minute memory cache
          print(
              '⚡ Using ultra-fast memory cache (${_memoryCache!.length} servers)');
          return _memoryCache!;
        }
      }

      // Fallback to persistent cache
      final prefs = await SharedPreferences.getInstance();
      final servers = prefs.getStringList(_serverListKey) ?? [];

      // Update memory cache
      if (servers.isNotEmpty) {
        _memoryCache = servers.take(_maxCachedServers).toList();
        _memoryCacheTime = DateTime.now();
      }

      return servers;
    } catch (e) {
      print('❌ Failed to get cached servers: $e');
      return [];
    }
  }

  /// Clear memory cache to force refresh
  void clearMemoryCache() {
    _memoryCache = null;
    _memoryCacheTime = null;
    _memoryPingCache = null;
    _memoryPingCacheTime = null;
    print('🧺 Memory cache cleared');
  }

  /// Get cached ping results with memory optimization
  Future<Map<String, int>> getCachedPingResults() async {
    try {
      // Check memory cache first
      if (_memoryPingCache != null && _memoryPingCacheTime != null) {
        final cacheAge = DateTime.now().difference(_memoryPingCacheTime!);
        if (cacheAge < Duration(minutes: 3)) {
          // 3-minute memory ping cache
          print(
              '⚡ Using memory ping cache (${_memoryPingCache!.length} results)');
          return _memoryPingCache!;
        }
      }

      // Fallback to persistent cache
      final prefs = await SharedPreferences.getInstance();
      final cacheString = prefs.getString(_pingCacheKey);

      if (cacheString == null) return {};

      final cacheData = jsonDecode(cacheString) as Map<String, dynamic>;
      final timestamp = cacheData['timestamp'] as int;
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);

      // Check if ping cache is still valid
      if (DateTime.now().difference(cacheTime) > _pingCacheExpiry) {
        return {};
      }

      final pings = Map<String, dynamic>.from(cacheData['pings']);
      final result = pings.map((key, value) => MapEntry(key, value as int));

      // Update memory cache
      _memoryPingCache = result;
      _memoryPingCacheTime = DateTime.now();

      return result;
    } catch (e) {
      print('❌ Failed to get cached ping results: $e');
      return {};
    }
  }

  /// Check if server cache is valid
  Future<bool> isServerCacheValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_lastFetchKey);

      if (timestamp == null) return false;

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();

      return now.difference(cacheTime) < _serverCacheExpiry;
    } catch (e) {
      print('❌ Failed to check cache validity: $e');
      return false;
    }
  }

  /// Cache server ping results
  Future<void> cachePingResults(Map<String, int> pingResults) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final cacheData = {
        'pings': pingResults,
        'timestamp': timestamp,
      };

      await prefs.setString(_pingCacheKey, jsonEncode(cacheData));
      print('✅ Cached ping results for ${pingResults.length} servers');
    } catch (e) {
      print('❌ Failed to cache ping results: $e');
    }
  }

  /// Get cached TCP ping results
  Future<Map<String, bool>> getCachedTcpPingResults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheString = prefs.getString(_tcpPingCacheKey);

      if (cacheString == null) return {};

      final cacheData = jsonDecode(cacheString) as Map<String, dynamic>;
      final timestamp = cacheData['timestamp'] as int;
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);

      // Check if TCP ping cache is still valid
      if (DateTime.now().difference(cacheTime) > _tcpPingCacheExpiry) {
        return {};
      }

      final tcpPings = Map<String, dynamic>.from(cacheData['tcpPings']);
      return tcpPings.map((key, value) => MapEntry(key, value as bool));
    } catch (e) {
      print('❌ Failed to get cached TCP ping results: $e');
      return {};
    }
  }

  /// Cache server health data
  Future<void> cacheServerHealth(
      Map<String, Map<String, dynamic>> healthData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final cacheData = {
        'health': healthData,
        'timestamp': timestamp,
      };

      await prefs.setString(_healthCacheKey, jsonEncode(cacheData));
      print('✅ Cached health data for ${healthData.length} servers');
    } catch (e) {
      print('❌ Failed to cache server health: $e');
    }
  }

  /// Get cached server health data
  Future<Map<String, Map<String, dynamic>>> getCachedServerHealth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheString = prefs.getString(_healthCacheKey);

      if (cacheString == null) return {};

      final cacheData = jsonDecode(cacheString) as Map<String, dynamic>;
      final timestamp = cacheData['timestamp'] as int;
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);

      // Check if health cache is still valid
      if (DateTime.now().difference(cacheTime) > _healthCacheExpiry) {
        return {};
      }

      final health = Map<String, dynamic>.from(cacheData['health']);
      return health
          .map((key, value) => MapEntry(key, Map<String, dynamic>.from(value)));
    } catch (e) {
      print('❌ Failed to get cached server health: $e');
      return {};
    }
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final servers = await getCachedServers();
      final pings = await getCachedPingResults();
      final health = await getCachedServerHealth();

      final lastFetch = prefs.getInt(_lastFetchKey);
      final lastFetchTime = lastFetch != null
          ? DateTime.fromMillisecondsSinceEpoch(lastFetch)
          : null;

      return {
        'serverCount': servers.length,
        'pingCount': pings.length,
        'healthCount': health.length,
        'lastFetch': lastFetchTime?.toIso8601String(),
        'cacheValid': await isServerCacheValid(),
        'cacheAge': lastFetchTime != null
            ? DateTime.now().difference(lastFetchTime).inMinutes
            : null,
      };
    } catch (e) {
      print('❌ Failed to get cache stats: $e');
      return {};
    }
  }

  /// Clear all cache
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(_serverListKey),
        prefs.remove(_serverMetadataKey),
        prefs.remove(_pingCacheKey),
        prefs.remove(_healthCacheKey),
        prefs.remove(_lastFetchKey),
      ]);
      print('✅ Cleared all server cache');
    } catch (e) {
      print('❌ Failed to clear cache: $e');
    }
  }

  /// Get cache size in bytes (approximate)
  Future<int> getCacheSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int totalSize = 0;

      final keys = [
        _serverListKey,
        _serverMetadataKey,
        _pingCacheKey,
        _healthCacheKey,
      ];

      for (final key in keys) {
        final value = prefs.getString(key);
        if (value != null) {
          totalSize += value.length * 2; // Approximate UTF-16 encoding
        }
      }

      return totalSize;
    } catch (e) {
      print('❌ Failed to calculate cache size: $e');
      return 0;
    }
  }

  /// Force refresh servers and cache immediately
  Future<void> refreshServersNow({
    Function(String)? onStatusUpdate,
  }) async {
    try {
      onStatusUpdate?.call('🔄 Force refreshing server cache...');

      // Clear existing cache first
      await clearCache();
      onStatusUpdate?.call('🗑️ Cleared old cache');

      // Fetch and cache immediately
      final servers = await fetchAndCacheImmediately(
        onStatusUpdate: onStatusUpdate,
        forceRefresh: true,
      );

      onStatusUpdate?.call('✅ Cache refreshed with ${servers.length} servers');
    } catch (e) {
      onStatusUpdate?.call('❌ Failed to refresh cache: ${e.toString()}');
      rethrow;
    }
  }

  /// Get servers with automatic fetch if cache is empty or invalid
  Future<List<String>> getServersWithAutoFetch({
    Function(String)? onStatusUpdate,
  }) async {
    try {
      // Ultra-fast memory cache check first
      if (_memoryCache != null && _memoryCacheTime != null) {
        final cacheAge = DateTime.now().difference(_memoryCacheTime!);
        if (cacheAge < Duration(minutes: 5) && _memoryCache!.isNotEmpty) {
          onStatusUpdate?.call(
              '⚡ Using ultra-fast memory cache (${_memoryCache!.length} servers)');
          return _memoryCache!;
        }
      }

      // Check if persistent cache is valid and not empty
      final isValid = await isServerCacheValid();
      final cachedServers = await getCachedServers();

      if (isValid && cachedServers.isNotEmpty) {
        onStatusUpdate?.call('📦 Using ${cachedServers.length} cached servers');
        return cachedServers;
      }

      // Cache is invalid or empty, fetch immediately
      onStatusUpdate?.call('🔄 Cache invalid, fetching fresh servers...');
      final freshServers = await fetchAndCacheImmediately(
        onStatusUpdate: onStatusUpdate,
        forceRefresh: true,
      );

      // Update memory cache with fresh servers
      if (freshServers.isNotEmpty) {
        _memoryCache = freshServers.take(_maxCachedServers).toList();
        _memoryCacheTime = DateTime.now();
      }

      return freshServers;
    } catch (e) {
      onStatusUpdate?.call('❌ Auto-fetch failed: ${e.toString()}');

      // Last resort: try to get any cached servers (including stale ones)
      final cachedServers = await getCachedServers();
      if (cachedServers.isNotEmpty) {
        onStatusUpdate
            ?.call('📦 Using ${cachedServers.length} stale cached servers');
        return cachedServers;
      }

      rethrow;
    }
  }

  /// Preload cache in background for better performance
  Future<void> preloadCache() async {
    try {
      print('🚀 Preloading cache in background...');

      // Check if cache needs refresh
      final isValid = await isServerCacheValid();
      if (!isValid) {
        // Preload servers in background without waiting
        unawaited(fetchAndCacheImmediately(
          forceRefresh: true,
          onStatusUpdate: (status) => print('Background preload: $status'),
        ));
      }
    } catch (e) {
      print('❌ Cache preload failed: $e');
    }
  }

  /// Get optimized cache statistics with performance metrics
  Future<Map<String, dynamic>> getOptimizedCacheStats() async {
    final baseStats = await getCacheStats();

    return {
      ...baseStats,
      'memoryCache': {
        'hasMemoryCache': _memoryCache != null,
        'memoryCacheSize': _memoryCache?.length ?? 0,
        'memoryCacheAge': _memoryCacheTime != null
            ? DateTime.now().difference(_memoryCacheTime!).inSeconds
            : null,
      },
      'memoryPingCache': {
        'hasPingCache': _memoryPingCache != null,
        'pingCacheSize': _memoryPingCache?.length ?? 0,
        'pingCacheAge': _memoryPingCacheTime != null
            ? DateTime.now().difference(_memoryPingCacheTime!).inSeconds
            : null,
      },
      'performanceConfig': {
        'maxCachedServers': _maxCachedServers,
        'maxPingHistory': _maxPingHistory,
        'serverCacheExpiryMinutes': _serverCacheExpiry.inMinutes,
        'pingCacheExpiryMinutes': _pingCacheExpiry.inMinutes,
      }
    };
  }
}
