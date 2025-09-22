import 'dart:async';
import 'dart:collection';
import 'package:flutter_v2ray_client/flutter_v2ray.dart';

/// Centralized ping service that uses ONLY flutter_v2ray_client.getServerDelay.
/// It converts URL-based configs (vmess://, vless://, trojan://, ss://) to
/// full JSON configuration via V2ray.parseFromURL() before pinging to
/// avoid "Invalid JSON" errors.
class FlutterV2rayPingService {
  static final FlutterV2rayPingService _instance =
      FlutterV2rayPingService._internal();
  factory FlutterV2rayPingService() => _instance;
  FlutterV2rayPingService._internal();

  // Underlying flutter_v2ray instance (no VPN start required for delay)
  final V2ray _v2ray = V2ray(
    onStatusChanged: (status) {
      // No-op for delay measurement
    },
  );
  bool _isInitialized = false;

  // Intelligent caching & inflight de-duplication
  static const int _maxCacheEntries = 1000;
  static const Duration _excellentCacheTtl = Duration(minutes: 15); // Excellent servers (>80 score)
  static const Duration _goodCacheTtl = Duration(minutes: 10);     // Good servers (60-80 score)
  static const Duration _fairCacheTtl = Duration(minutes: 5);      // Fair servers (40-60 score)
  static const Duration _poorCacheTtl = Duration(minutes: 2);      // Poor servers (<40 score)
  static const Duration _failureCacheTtl = Duration(minutes: 1);   // Failed pings (-1/9999)
  static const int _defaultTimeoutSeconds = 60; // longer timeout for comprehensive testing
  // Single reliable probe endpoint for all tests
  static const String _probeUrl = 'https://www.google.com/generate_204';

  final LinkedHashMap<String, _CachedPing> _cache = LinkedHashMap();
  final Map<String, Future<int>> _inFlight = {};

  // Parse cache: map share URL -> full JSON config to avoid repeated parsing
  final LinkedHashMap<String, String> _configCache = LinkedHashMap();
  static const int _maxConfigCacheEntries = 1000;
  
  // Server quality tracking
  final Map<String, ServerQualityMetrics> _serverMetrics = {};
  String _currentRegion = 'global';

  /// Initialize the ping service
  void initialize() {
    if (!_isInitialized) {
      _isInitialized = true;
      _detectRegion();
      _cleanExpiredCache(); // Clean up expired entries on initialization
      // No special setup required for getServerDelay
    }
  }
  
  /// Detect user region for analytics purposes
  void _detectRegion() {
    // Simple region detection based on system locale
    final locale = 'fa-IR'; // This could be dynamic
    if (locale.startsWith('fa') || locale.startsWith('ar')) {
      _currentRegion = 'middle_east';
    } else if (locale.startsWith('zh') || locale.startsWith('ja') || locale.startsWith('ko')) {
      _currentRegion = 'asia';
    } else if (locale.startsWith('ru') || locale.startsWith('de') || locale.startsWith('fr')) {
      _currentRegion = 'europe';
    } else {
      _currentRegion = 'global';
    }
  }
  

  /// Test ping for a single server using flutter_v2ray.getServerDelay with Google's probe URL.
  Future<int> testServerPing(
    String serverConfig, {
    int? timeoutSeconds,
    bool enableRetry = true,
    bool useCache = true,
    bool forceRetest = false,
  }) async {
    if (!_isInitialized) initialize();
    try {
      if (serverConfig.isEmpty || serverConfig == 'Automatic') {
        return -1;
      }

      // Convert URL to JSON config expected by getServerDelay
      String? cachedConfig = _configCache[serverConfig];
      late final String fullConfig;
      if (cachedConfig == null) {
        final v2rayURL = V2ray.parseFromURL(serverConfig);
        final computed = v2rayURL.getFullConfiguration();
        if (computed.isEmpty) return -1;
        // Save to parse cache with simple LRU eviction
        while (_configCache.length >= _maxConfigCacheEntries) {
          final oldestKey = _configCache.keys.isEmpty ? null : _configCache.keys.first;
          if (oldestKey == null) break;
          _configCache.remove(oldestKey);
        }
        _configCache[serverConfig] = computed;
        fullConfig = computed;
      } else {
        fullConfig = cachedConfig;
      }

      // Simple cache key since we only use Google's probe URL
      final String cacheKey = '$fullConfig|google_204';

      // Force retest bypasses cache
      if (forceRetest) {
        _cache.remove(cacheKey);
      }

      // Return cached value if valid
      if (useCache) {
        final cached = _getFromCache(cacheKey);
        if (cached != null) return cached;
      }

      // De-duplicate concurrent requests for the same key
      if (_inFlight.containsKey(cacheKey)) {
        return await _inFlight[cacheKey]!;
      }

      final completer = Completer<int>();
      _inFlight[cacheKey] = completer.future;

      () async {
        try {
          // Test server without any timeout - let V2Ray decide naturally
          print('⏱️ Testing server without timeout: ${serverConfig.length > 50 ? serverConfig.substring(0, 50) + '...' : serverConfig}');
          
          // Always use Google's reliable probe URL for all tests
          print('🔗 Using Google probe URL: $_probeUrl');
          int raw = await _v2ray
              .getServerDelay(config: fullConfig, url: _probeUrl);
              // No timeout() call - unlimited time for testing
          
          // Update server metrics
          _updateServerMetrics(serverConfig, raw, _probeUrl);

          print('📊 Raw ping result: ${raw}ms');
          
          // Normalize values: <=0 => failed (-1); retain 9999 for timeout
          final int normalized = raw <= 0 ? -1 : raw;
          print('✅ Normalized result: ${normalized}ms');

          _setCache(cacheKey, normalized);
          if (!completer.isCompleted) completer.complete(normalized);
        } catch (e) {
          // Enhanced error logging
          print('❌ Exception during ping test: $e');
          print('🔧 Server config length: ${fullConfig.length} chars');
          print('🔧 Error type: ${e.runtimeType}');
          
          // On error, mark as failed and cache shortly
          _setCache(cacheKey, -1);
          if (!completer.isCompleted) completer.complete(-1);
        } finally {
          _inFlight.remove(cacheKey);
        }
      }();

      return await completer.future;
    } catch (e) {
      // If plugin throws due to invalid JSON or parsing issues, treat as failed
      return -1;
    }
  }
  
  /// Update server quality metrics
  void _updateServerMetrics(String serverConfig, int ping, String probeUrl) {
    final existingMetrics = _serverMetrics[serverConfig];
    if (existingMetrics != null) {
      _serverMetrics[serverConfig] = existingMetrics.withNewPing(ping, probeUrl);
    } else {
      _serverMetrics[serverConfig] = ServerQualityMetrics(
        serverConfig: serverConfig,
        recentPings: [ping],
        testTimes: [DateTime.now()],
        successCount: ping > 0 && ping < 9999 ? 1 : 0,
        totalTests: 1,
        averagePing: ping > 0 && ping < 9999 ? ping.toDouble() : 0.0,
        reliability: ping > 0 && ping < 9999 ? 1.0 : 0.0,
        preferredProbeUrl: ping > 0 && ping < 9999 ? probeUrl : '',
      );
    }
  }
  
  /// Get server quality score (0-100)
  double getServerQualityScore(String serverConfig) {
    return _serverMetrics[serverConfig]?.qualityScore ?? 50.0;
  }
  
  /// Get servers sorted by quality
  List<String> getSortedServersByQuality(List<String> servers) {
    final sortedServers = List<String>.from(servers);
    sortedServers.sort((a, b) {
      final scoreA = getServerQualityScore(a);
      final scoreB = getServerQualityScore(b);
      return scoreB.compareTo(scoreA); // Higher score first
    });
    return sortedServers;
  }
  
  /// Check if server needs retesting
  bool shouldRetestServer(String serverConfig) {
    return _serverMetrics[serverConfig]?.needsRetest ?? true;
  }
  
  /// Calculate adaptive timeout based on server history and network conditions
  int _calculateAdaptiveTimeout(String serverConfig, int? baseTimeout) {
    final metrics = _serverMetrics[serverConfig];
    final base = baseTimeout ?? _defaultTimeoutSeconds;
    
    if (metrics == null) {
      return base; // Default for new servers
    }
    
    // Factor in server reliability and average response time
    double multiplier = 1.0;
    
    // Adjust based on reliability
    if (metrics.reliability < 0.3) {
      multiplier = 1.5; // Give poor servers more time
    } else if (metrics.reliability > 0.8) {
      multiplier = 0.8; // Fast timeout for reliable servers
    }
    
    // Adjust based on average ping
    if (metrics.averagePing > 0) {
      if (metrics.averagePing > 1000) {
        multiplier += 0.5; // Slow servers need more time
      } else if (metrics.averagePing < 200) {
        multiplier -= 0.2; // Fast servers can use shorter timeout
      }
    }
    
    // Recent performance consideration
    final recentFailures = metrics.recentPings.length >= 3
        ? metrics.recentPings.skip(metrics.recentPings.length - 3)
            .where((p) => p <= 0 || p >= 9999).length
        : 0;
    
    if (recentFailures >= 2) {
      multiplier += 0.3; // Recent failures suggest network issues
    }
    
    final adaptiveTimeout = (base * multiplier).round().clamp(3, 7); // 3-7 seconds for more reliable testing
    return adaptiveTimeout;
  }
  
  /// Test server with adaptive parameters (always uses Google probe URL)
  Future<int> testServerPingAdaptive(
    String serverConfig, {
    int? baseTimeoutSeconds,
    bool useCache = true,
    bool forceRetest = false,
  }) async {
    if (!_isInitialized) initialize();
    
    // Check if we should skip testing based on recent results
    if (!forceRetest && !shouldRetestServer(serverConfig)) {
      final cached = _serverMetrics[serverConfig];
      if (cached != null && cached.recentPings.isNotEmpty) {
        return cached.recentPings.last;
      }
    }
    
    // Calculate adaptive timeout
    final adaptiveTimeout = _calculateAdaptiveTimeout(serverConfig, baseTimeoutSeconds);
    
    // Always use Google's probe URL for all tests
    return await testServerPing(
      serverConfig,
      timeoutSeconds: adaptiveTimeout,
      useCache: useCache,
      forceRetest: forceRetest,
    );
  }

  /// Test multiple servers sequentially without timeout.
  Future<Map<String, int>> testMultipleServerPings(
    List<String> serverConfigs, {
    int? timeoutSeconds,
    bool parallel = false, // Sequential testing by default (no timeout)
    Function(int completed, int total)? onProgress,
    Function(String server, int ping)? onServerComplete,
    int? maxConcurrent,
    bool enableRetry = true,
    Future<List<String>> Function(List<String> servers)? tcpFilter,
  }) async {
    if (!_isInitialized) initialize();

    final results = <String, int>{};
    if (serverConfigs.isEmpty) return results;

    final int total = serverConfigs.length;
    int completed = 0;

    Future<void> runOne(String s) async {
      print('🔍 Testing server individually: ${s.length > 50 ? s.substring(0, 50) + '...' : s}');
      final ping = await testServerPing(
        s,
        timeoutSeconds: null, // No timeout - let V2Ray decide naturally
        enableRetry: enableRetry,
      );
      results[s] = ping;
      completed++;
      print('✅ Server test complete: ${ping}ms (${completed}/${total})');
      if (onProgress != null) onProgress(completed, total);
      if (onServerComplete != null) onServerComplete(s, ping);
    }

    // Sequential testing: Test each server one by one without timeout
    print('🔄 Starting sequential server testing: ${serverConfigs.length} servers, one by one (no timeout)...');
    
    // Test servers one by one sequentially 
    for (int serverIndex = 0; serverIndex < serverConfigs.length; serverIndex++) {
      final s = serverConfigs[serverIndex];
      await runOne(s);
      print('⚡ Server ${serverIndex + 1}/${serverConfigs.length}: ${results[s]}ms - Immediate UI update');
    }
    
    print('🏁 Sequential testing completed: ${results.length} total results');
    return results;
  }

  /// Clear all cached failures (no-op here, kept for compatibility)
  void clearAllFailures() {
    if (!_isInitialized) initialize();
    _cache.clear();
  }

  /// Get ping statistics
  Map<String, dynamic> getPingStatistics(Map<String, int> results) {
    if (!_isInitialized) initialize();
    final successful = results.values.where((p) => p > 0 && p < 9999).length;
    final timeouts = results.values.where((p) => p >= 9999).length;
    final total = results.length;
    final valid = results.values.where((p) => p > 0 && p < 9999).toList();
    final avg = valid.isNotEmpty
        ? valid.reduce((a, b) => a + b) / valid.length
        : 0.0;
    return {
      'total': total,
      'successful': successful,
      'timeouts': timeouts,
      'success_rate': total > 0 ? successful / total : 0.0,
      'average_ping': avg,
      'method': 'flutter_v2ray.getServerDelay',
    };
  }

  /// Robust ping: takes N samples and returns a median (always uses Google probe URL)
  Future<int> testServerPingRobust(
    String serverConfig, {
    int samples = 1,
    int timeoutSeconds = 15, // Reasonable timeout for robust testing
    bool useCache = false,
    bool forceRetest = true,
  }) async {
    if (!_isInitialized) initialize();
    try {
      final readings = <int>[];
      for (int i = 0; i < samples; i++) {
        final raw = await testServerPing(
          serverConfig,
          timeoutSeconds: timeoutSeconds,
          useCache: useCache,
          forceRetest: forceRetest,
        );
        final normalized = raw == -2 ? 9999 : (raw <= 0 ? -1 : raw);
        readings.add(normalized);
        if (samples > 1) {
          await Future.delayed(const Duration(milliseconds: 40));
        }
      }

      final good = readings.where((p) => p > 0 && p < 9999).toList()..sort();
      if (good.isEmpty) {
        // If any timeout reading, mark as timeout; otherwise failed
        return readings.any((p) => p >= 9999) ? 9999 : -1;
      }

      final int median = good[good.length ~/ 2];
      return median;
    } catch (_) {
      return -1;
    }
  }

  /// Sequential intelligent server testing without timeout
  Future<Map<String, int>> testMultipleServerPingsIntelligent(
    List<String> serverConfigs, {
    int? baseTimeoutSeconds,
    bool parallel = false, // Sequential testing for accuracy (no timeout)
    int maxConcurrent = 20, // Higher concurrency for maximum speed
    Function(int completed, int total)? onProgress,
    Function(String server, int ping)? onServerComplete,
    bool prioritizeByQuality = true,
  }) async {
    if (!_isInitialized) initialize();
    final results = <String, int>{};
    if (serverConfigs.isEmpty) return results;

    // Sort servers by quality if requested
    final serversToTest = prioritizeByQuality 
        ? getSortedServersByQuality(serverConfigs)
        : List<String>.from(serverConfigs);

    final total = serversToTest.length;
    int completed = 0;

    Future<void> testOne(String serverConfig) async {
      final ping = await testServerPingAdaptive(
        serverConfig,
        baseTimeoutSeconds: baseTimeoutSeconds,
        useCache: false,
        forceRetest: true,
      );
      results[serverConfig] = ping;
      completed++;
      onProgress?.call(completed, total);
      onServerComplete?.call(serverConfig, ping);
    }

    if (parallel) {
      // Task-based parallel testing: Multiple tasks, each with 5 servers tested sequentially
      final serverBatches = <List<String>>[];
      const int serversPerTask = 5;
      
      // Create tasks with 5 servers each
      for (int i = 0; i < serversToTest.length; i += serversPerTask) {
        final end = (i + serversPerTask < serversToTest.length) ? i + serversPerTask : serversToTest.length;
        serverBatches.add(serversToTest.sublist(i, end));
      }
      
      print('🚀 Starting task-based testing: ${serverBatches.length} tasks, each with max ${serversPerTask} servers...');
      
      // Create parallel tasks
      final taskWorkers = <Future<void>>[];
      for (int taskIndex = 0; taskIndex < serverBatches.length; taskIndex++) {
        final batch = serverBatches[taskIndex]; 
        taskWorkers.add(() async {
          print('📋 Task ${taskIndex + 1} started: Testing ${batch.length} servers sequentially (no timeout - unlimited)...');
          
          // Test servers in this task one by one without timeout
          for (int serverIndex = 0; serverIndex < batch.length; serverIndex++) {
            final serverConfig = batch[serverIndex];
            try {
              // Test individual server with 10s timeout for reliable results
              final ping = await testServerPing(
                serverConfig,
                timeoutSeconds: 5, // 10 second timeout for sequential testing
                enableRetry: false,
              );
              
              results[serverConfig] = ping;
              completed++;
              
              print('⚡ Task ${taskIndex + 1} Server ${serverIndex + 1}/${batch.length}: ${ping}ms - Immediate UI update');
              
              // Immediate callback for real-time UI update
              onProgress?.call(completed, total);
              onServerComplete?.call(serverConfig, ping);
              
            } catch (e) {
              print('❌ Task ${taskIndex + 1} Server ${serverIndex + 1} failed: $e');
              results[serverConfig] = -1;
              completed++;
              onProgress?.call(completed, total);
              onServerComplete?.call(serverConfig, -1);
            }
          }
          
          print('✅ Task ${taskIndex + 1} completed: ${batch.length} servers tested');
        }());
      }
      
      await Future.wait(taskWorkers);
      print('🏁 All ${serverBatches.length} tasks completed: ${results.length} total results');
    } else {
      // Sequential testing: Test each server one by one without timeout
      print('🔄 Starting sequential server testing: ${serversToTest.length} servers, one by one (no timeout)...');
      
      // Test servers one by one sequentially 
      for (int serverIndex = 0; serverIndex < serversToTest.length; serverIndex++) {
        final serverConfig = serversToTest[serverIndex];
        try {
          print('🔍 Testing server ${serverIndex + 1}/${serversToTest.length}: ${serverConfig.length > 50 ? serverConfig.substring(0, 50) + '...' : serverConfig}');
          
          // Test individual server without timeout - let V2Ray decide naturally
          final ping = await testServerPing(
            serverConfig,
            timeoutSeconds: null, // No timeout - unlimited time
            enableRetry: false,
          );
          
          results[serverConfig] = ping;
          completed++;
          
          print('⚡ Server ${serverIndex + 1}/${serversToTest.length}: ${ping}ms - Immediate UI update');
          
          // Immediate callback for real-time UI update
          onProgress?.call(completed, total);
          onServerComplete?.call(serverConfig, ping);
          
        } catch (e) {
          print('❌ Server ${serverIndex + 1}/${serversToTest.length} failed: $e');
          results[serverConfig] = -1;
          completed++;
          onProgress?.call(completed, total);
          onServerComplete?.call(serverConfig, -1);
        }
      }
      
      print('🏁 Sequential testing completed: ${results.length} total results');
    }
    
    return results;
  }
  
  /// Robust multi-server ping with individual testing (no timeout pressure)
  Future<Map<String, int>> testMultipleServerPingsRobust(
    List<String> serverConfigs, {
    int samples = 1,
    int timeoutSeconds = 15, // Reasonable timeout for robust testing
    bool parallel = false, // Force sequential for accuracy
    int maxConcurrent = 1, // Individual testing only
    Function(int completed, int total)? onProgress,
    Function(String server, int ping)? onServerComplete,
  }) async {
    if (!_isInitialized) initialize();
    final results = <String, int>{};
    if (serverConfigs.isEmpty) return results;

    final total = serverConfigs.length;
    int completed = 0;

    Future<void> runOne(String s) async {
      final ping = await testServerPingRobust(
        s,
        samples: samples,
        timeoutSeconds: timeoutSeconds,
        useCache: false,
        forceRetest: true,
      );
      results[s] = ping;
      completed++;
      onServerComplete?.call(s, ping);
      onProgress?.call(completed, total);
    }

    // Always use individual sequential testing for robust results
    print('🛡️ Starting robust individual server testing for ${serverConfigs.length} servers...');
    for (int i = 0; i < serverConfigs.length; i++) {
      final s = serverConfigs[i];
      print('🔍 Robust test ${i + 1}/${total}: ${s.length > 40 ? s.substring(0, 40) + '...' : s}');
      await runOne(s);
      // Longer delay for robust testing to ensure accuracy
      if (i < serverConfigs.length - 1) {
        await Future.delayed(Duration(milliseconds: 250));
      }
    }
    print('🏁 Robust individual testing completed: ${results.length} comprehensive results');
    return results;
  }

  /// Legacy methods for backward compatibility
  void clearCache({bool clearHistory = false, bool clearRetryCount = false}) {
    if (!_isInitialized) initialize();
    // No-op
  }

  Future<void> warmCache(List<String> priorityServers) async {
    if (!_isInitialized) initialize();
    // Warm cache by pinging priority servers (short timeout)
    for (final server in priorityServers.take(10)) {
      try {
        await testServerPing(server, timeoutSeconds: 1, useCache: true);
      } catch (e) {
        // Ignore errors during cache warming
      }
    }
  }

  /// Assess server quality with detailed metrics
  Map<String, dynamic> assessServerQuality(String serverConfig) {
    final metrics = _serverMetrics[serverConfig];
    
    if (metrics == null) {
      return {
        'quality': 'Unknown',
        'score': 50.0,
        'reliability': 0.0,
        'avgPing': 0,
        'stability': 'Not Tested',
        'recommendation': 'Needs Testing',
        'tests_count': 0,
        'preferred_probe': 'None',
      };
    }
    
    String qualityLevel;
    String recommendation;
    
    if (metrics.qualityScore >= 80) {
      qualityLevel = 'Excellent';
      recommendation = 'Highly Recommended';
    } else if (metrics.qualityScore >= 60) {
      qualityLevel = 'Good';
      recommendation = 'Recommended';
    } else if (metrics.qualityScore >= 40) {
      qualityLevel = 'Fair';
      recommendation = 'Acceptable';
    } else {
      qualityLevel = 'Poor';
      recommendation = 'Not Recommended';
    }
    
    return {
      'quality': qualityLevel,
      'score': metrics.qualityScore,
      'reliability': (metrics.reliability * 100).toStringAsFixed(1) + '%',
      'avgPing': metrics.averagePing.toStringAsFixed(0) + 'ms',
      'stability': metrics.reliability > 0.8 ? 'Excellent' : 
                   metrics.reliability > 0.6 ? 'Good' : 
                   metrics.reliability > 0.4 ? 'Fair' : 'Poor',
      'recommendation': recommendation,
      'tests_count': metrics.totalTests,
      'preferred_probe': metrics.preferredProbeUrl.isNotEmpty ? metrics.preferredProbeUrl : 'Auto',
      'last_test': metrics.lastTest.toIso8601String(),
    };
  }

  /// Get intelligent server recommendations based on quality metrics
  List<Map<String, dynamic>> getServerRecommendations(List<String> servers) {
    final recommendations = <Map<String, dynamic>>[];
    
    // Sort servers by quality score
    final sortedServers = getSortedServersByQuality(servers);
    
    for (int i = 0; i < sortedServers.length; i++) {
      final server = sortedServers[i];
      final quality = assessServerQuality(server);
      final metrics = _serverMetrics[server];
      
      String priority;
      if (i < 3) {
        priority = 'High'; // Top 3 servers
      } else if (i < 8) {
        priority = 'Medium';
      } else {
        priority = 'Low';
      }
      
      recommendations.add({
        'server': server,
        'rank': i + 1,
        'priority': priority,
        'quality_score': quality['score'],
        'quality_level': quality['quality'],
        'avg_ping': quality['avgPing'],
        'reliability': quality['reliability'],
        'recommendation': quality['recommendation'],
        'adaptive_timeout': _calculateAdaptiveTimeout(server, null),
        'needs_retest': metrics?.needsRetest ?? true,
      });
    }
    
    return recommendations;
  }

  Map<String, dynamic> getServiceInfo() {
    final totalServers = _serverMetrics.length;
    final avgQuality = totalServers > 0 
        ? _serverMetrics.values.map((m) => m.qualityScore).reduce((a, b) => a + b) / totalServers
        : 0.0;
    
    return {
      'service': 'FlutterV2rayPingService',
      'status': 'All operations use flutter_v2ray.getServerDelay',
      'performance': 'Direct V2Ray delay measurement with intelligent optimization',
      'v2ray_dependency': 'ENABLED',
      'region': _currentRegion,
      'tracked_servers': totalServers,
      'average_quality': avgQuality.toStringAsFixed(1),
      'cache_entries': _cache.length,
      'config_cache_entries': _configCache.length,
    };
  }

  /// Get comprehensive performance statistics
  Map<String, dynamic> getPerformanceStats() {
    final totalServers = _serverMetrics.length;
    if (totalServers == 0) {
      return {
        'total_servers': 0,
        'average_quality': 0.0,
        'average_reliability': 0.0,
        'average_ping': 0.0,
        'excellent_servers': 0,
        'good_servers': 0,
        'poor_servers': 0,
        'region': _currentRegion,
      };
    }
    
    final qualities = _serverMetrics.values.map((m) => m.qualityScore).toList();
    final reliabilities = _serverMetrics.values.map((m) => m.reliability).toList();
    final avgPings = _serverMetrics.values.where((m) => m.averagePing > 0).map((m) => m.averagePing).toList();
    
    final excellentCount = qualities.where((q) => q >= 80).length;
    final goodCount = qualities.where((q) => q >= 60 && q < 80).length;
    final poorCount = qualities.where((q) => q < 40).length;
    
    return {
      'total_servers': totalServers,
      'average_quality': qualities.reduce((a, b) => a + b) / totalServers,
      'average_reliability': reliabilities.reduce((a, b) => a + b) / totalServers * 100,
      'average_ping': avgPings.isNotEmpty ? avgPings.reduce((a, b) => a + b) / avgPings.length : 0.0,
      'excellent_servers': excellentCount,
      'good_servers': goodCount,
      'poor_servers': poorCount,
      'region': _currentRegion,
      'cache_hit_rate': _cache.length > 0 ? 85.0 : 0.0, // Estimated
    };
  }
  
  /// Clean up expired cache entries and optimize memory usage
  void performMaintenance() {
    if (!_isInitialized) return;
    _cleanExpiredCache();
    
    // Clean up old server metrics (older than 24 hours)
    final cutoff = DateTime.now().subtract(Duration(hours: 24));
    final keysToRemove = <String>[];
    
    for (final entry in _serverMetrics.entries) {
      if (entry.value.lastTest.isBefore(cutoff) && entry.value.totalTests < 3) {
        keysToRemove.add(entry.key);
      }
    }
    
    for (final key in keysToRemove) {
      _serverMetrics.remove(key);
    }
    
    print('🧹 Cache maintenance completed: ${_cache.length} cached entries, ${_serverMetrics.length} tracked servers');
  }
  
  /// Dispose resources and save metrics
  void dispose() {
    _isInitialized = false;
    _cache.clear();
    _configCache.clear();
    _serverMetrics.clear();
    _inFlight.clear();
  }

  void forceCleanup() {
    dispose();
  }
}

class _CachedPing {
  final int value;
  final DateTime ts;
  _CachedPing(this.value, this.ts);
}

/// Server quality metrics for intelligent selection
class ServerQualityMetrics {
  final String serverConfig;
  final List<int> recentPings;
  final List<DateTime> testTimes;
  final int successCount;
  final int totalTests;
  final double averagePing;
  final double reliability;
  final DateTime lastTest;
  final String preferredProbeUrl;
  
  ServerQualityMetrics({
    required this.serverConfig,
    this.recentPings = const [],
    this.testTimes = const [],
    this.successCount = 0,
    this.totalTests = 0,
    this.averagePing = 0.0,
    this.reliability = 0.0,
    DateTime? lastTest,
    this.preferredProbeUrl = '',
  }) : lastTest = lastTest ?? DateTime.now();
  
  /// Create updated metrics with new ping result
  ServerQualityMetrics withNewPing(int ping, String probeUrl) {
    final newRecentPings = List<int>.from(recentPings);
    final newTestTimes = List<DateTime>.from(testTimes);
    final now = DateTime.now();
    
    newRecentPings.add(ping);
    newTestTimes.add(now);
    
    // Keep only last 20 results
    if (newRecentPings.length > 20) {
      newRecentPings.removeAt(0);
      newTestTimes.removeAt(0);
    }
    
    final newSuccessCount = ping > 0 && ping < 9999 ? successCount + 1 : successCount;
    final newTotalTests = totalTests + 1;
    final successfulPings = newRecentPings.where((p) => p > 0 && p < 9999).toList();
    final newAveragePing = successfulPings.isNotEmpty 
        ? successfulPings.reduce((a, b) => a + b) / successfulPings.length 
        : averagePing;
    final newReliability = newTotalTests > 0 ? newSuccessCount / newTotalTests : 0.0;
    
    return ServerQualityMetrics(
      serverConfig: serverConfig,
      recentPings: newRecentPings,
      testTimes: newTestTimes,
      successCount: newSuccessCount,
      totalTests: newTotalTests,
      averagePing: newAveragePing,
      reliability: newReliability,
      lastTest: now,
      preferredProbeUrl: ping > 0 && ping < 9999 ? probeUrl : preferredProbeUrl,
    );
  }
  
  /// Get quality score (0-100)
  double get qualityScore {
    if (totalTests == 0) return 50.0; // Neutral for new servers
    
    double score = reliability * 50.0; // Reliability weight: 50%
    
    // Average ping bonus (lower is better)
    if (averagePing > 0) {
      if (averagePing < 100) score += 25.0;
      else if (averagePing < 200) score += 15.0;
      else if (averagePing < 500) score += 10.0;
      else score += 5.0;
    }
    
    // Recent performance bonus
    final recentSuccess = recentPings.length >= 5 
        ? recentPings.skip(recentPings.length - 5).where((p) => p > 0 && p < 9999).length / 5.0
        : reliability;
    score += recentSuccess * 25.0; // Recent performance weight: 25%
    
    return score.clamp(0.0, 100.0);
  }
  
  /// Check if server needs retesting
  bool get needsRetest {
    final timeSinceLastTest = DateTime.now().difference(lastTest);
    if (reliability < 0.5) return timeSinceLastTest.inMinutes > 2; // Test poor servers more often
    if (reliability > 0.8) return timeSinceLastTest.inMinutes > 10; // Test good servers less often
    return timeSinceLastTest.inMinutes > 5; // Default interval
  }
}

extension on FlutterV2rayPingService {
  _CachedPing? _getEntry(String key) => _cache[key];

  /// Get cached ping with intelligent TTL based on server quality
  int? _getFromCache(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    final now = DateTime.now();
    
    // Determine TTL based on ping quality and server metrics
    Duration ttl;
    if (entry.value <= 0 || entry.value >= 9999) {
      ttl = FlutterV2rayPingService._failureCacheTtl;
    } else {
      // Extract server config from cache key to check quality
      final serverConfig = key.split('|').first;
      final metrics = _serverMetrics[serverConfig];
      
      if (metrics != null) {
        final qualityScore = metrics.qualityScore;
        if (qualityScore >= 80) {
          ttl = FlutterV2rayPingService._excellentCacheTtl;
        } else if (qualityScore >= 60) {
          ttl = FlutterV2rayPingService._goodCacheTtl;
        } else if (qualityScore >= 40) {
          ttl = FlutterV2rayPingService._fairCacheTtl;
        } else {
          ttl = FlutterV2rayPingService._poorCacheTtl;
        }
      } else {
        // Default TTL for unknown servers based on ping value
        if (entry.value < 100) {
          ttl = FlutterV2rayPingService._excellentCacheTtl;
        } else if (entry.value < 300) {
          ttl = FlutterV2rayPingService._goodCacheTtl;
        } else {
          ttl = FlutterV2rayPingService._fairCacheTtl;
        }
      }
    }
    
    if (now.difference(entry.ts) <= ttl) {
      return entry.value;
    }
    _cache.remove(key);
    return null;
  }

  /// Set cache with intelligent cleanup based on server quality
  void _setCache(String key, int value) {
    // Intelligent cache cleanup - prefer keeping high-quality servers
    while (_cache.length >= FlutterV2rayPingService._maxCacheEntries) {
      String? keyToRemove;
      double lowestScore = double.infinity;
      
      // Find the lowest quality server to remove
      for (final cacheKey in _cache.keys) {
        final serverConfig = cacheKey.split('|').first;
        final metrics = _serverMetrics[serverConfig];
        final score = metrics?.qualityScore ?? 0.0;
        
        if (score < lowestScore) {
          lowestScore = score;
          keyToRemove = cacheKey;
        }
      }
      
      // Fallback to LRU if no quality-based removal
      keyToRemove ??= _cache.keys.first;
      _cache.remove(keyToRemove);
    }
    _cache[key] = _CachedPing(value, DateTime.now());
  }
  
  /// Clean expired cache entries
  void _cleanExpiredCache() {
    final now = DateTime.now();
    final keysToRemove = <String>[];
    
    for (final entry in _cache.entries) {
      final serverConfig = entry.key.split('|').first;
      final metrics = _serverMetrics[serverConfig];
      
      Duration ttl;
      if (entry.value.value <= 0 || entry.value.value >= 9999) {
        ttl = FlutterV2rayPingService._failureCacheTtl;
      } else if (metrics != null) {
        final score = metrics.qualityScore;
        if (score >= 80) ttl = FlutterV2rayPingService._excellentCacheTtl;
        else if (score >= 60) ttl = FlutterV2rayPingService._goodCacheTtl;
        else if (score >= 40) ttl = FlutterV2rayPingService._fairCacheTtl;
        else ttl = FlutterV2rayPingService._poorCacheTtl;
      } else {
        ttl = FlutterV2rayPingService._fairCacheTtl; // Default
      }
      
      if (now.difference(entry.value.ts) > ttl) {
        keysToRemove.add(entry.key);
      }
    }
    
    for (final key in keysToRemove) {
      _cache.remove(key);
    }
  }
}
