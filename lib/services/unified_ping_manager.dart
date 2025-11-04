import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'flutter_v2ray_ping_service.dart';

/// Unified Ping Result Manager - Enhanced Version
/// یکپارچه‌سازی نتایج تست پینگ سرورها برای عملکرد بهتر و یکسان در برنامه
/// Enhanced with immediate startup testing and better performance
class UnifiedPingManager {
  static final UnifiedPingManager _instance = UnifiedPingManager._internal();
  factory UnifiedPingManager() => _instance;
  UnifiedPingManager._internal();

  // Cache keys
  static const String _pingCacheKey = 'unified_ping_cache_v3';
  static const String _pingMetadataKey = 'unified_ping_metadata_v3';
  static const String _lastUpdateKey = 'unified_ping_last_update_v3';

  // Cache configuration
  static const Duration _excellentCacheTtl = Duration(minutes: 30); // <100ms
  static const Duration _goodCacheTtl = Duration(minutes: 20);      // 100-300ms
  static const Duration _fairCacheTtl = Duration(minutes: 15);      // 300-600ms
  static const Duration _poorCacheTtl = Duration(minutes: 10);      // 600-1000ms
  static const Duration _badCacheTtl = Duration(minutes: 5);        // >1000ms
  static const Duration _failureCacheTtl = Duration(minutes: 2);    // Failed/timeout

  // In-memory cache for ultra-fast access
  final Map<String, PingResult> _memoryCache = <String, PingResult>{};
  final Map<String, Future<PingResult>> _inFlightTests = <String, Future<PingResult>>{};
  
  // Ping service instance
  final FlutterV2rayPingService _pingService = FlutterV2rayPingService();
  
  // Event streams for real-time updates
  final StreamController<Map<String, PingResult>> _pingUpdatesController = 
      StreamController<Map<String, PingResult>>.broadcast();
  final StreamController<PingTestProgress> _progressController = 
      StreamController<PingTestProgress>.broadcast();
  
  Stream<Map<String, PingResult>> get pingUpdates => _pingUpdatesController.stream;
  Stream<PingTestProgress> get progressUpdates => _progressController.stream;
  
  // Startup testing state
  bool _isStartupTestingInProgress = false;
  bool _startupTestingCompleted = false;
  DateTime? _lastStartupTest;

  /// Initialize the ping manager
  Future<void> initialize() async {
    _pingService.initialize();
    await _loadCachedResults();
    print('🏓 UnifiedPingManager initialized - Ready for immediate testing');
  }

  /// Get ping result for a single server
  Future<PingResult> getPingResult(String serverConfig, {
    int timeoutSeconds = 3,
    bool useCache = true,
  }) async {
    if (serverConfig.isEmpty || serverConfig == 'Automatic') {
      return PingResult.failed(serverConfig);
    }

    // Check memory cache first
    if (useCache && _memoryCache.containsKey(serverConfig)) {
      final cached = _memoryCache[serverConfig]!;
      if (!cached.isExpired) {
        return cached;
      }
    }

    // Check if test is already in progress
    if (_inFlightTests.containsKey(serverConfig)) {
      return await _inFlightTests[serverConfig]!;
    }

    // Start new ping test
    final future = _performPingTest(serverConfig, timeoutSeconds);
    _inFlightTests[serverConfig] = future;

    try {
      final result = await future;
      _memoryCache[serverConfig] = result;
      _inFlightTests.remove(serverConfig);
      
      // Save to persistent cache
      await _saveToPersistentCache(serverConfig, result);
      
      // Notify listeners
      _notifyPingUpdate(serverConfig, result);
      
      return result;
    } catch (e) {
      _inFlightTests.remove(serverConfig);
      final failedResult = PingResult.failed(serverConfig);
      _memoryCache[serverConfig] = failedResult;
      return failedResult;
    }
  }

  /// Test all servers immediately on app startup
  /// یکپارچه سازی تست فوری تمام سرورها بلافاصله بعد از اجرای نرم افزار
  Future<Map<String, PingResult>> testAllServersOnStartup(List<String> serverConfigs, {
    int timeoutSeconds = 2, // Faster timeout for startup
    Function(String, PingResult)? onProgress,
    Function(int completed, int total)? onProgressCount,
  }) async {
    if (_isStartupTestingInProgress) {
      print('⚠️ Startup testing already in progress, waiting...');
      // Wait for current test to complete
      while (_isStartupTestingInProgress) {
        await Future.delayed(Duration(milliseconds: 100));
      }
      return getCachedResults(serverConfigs);
    }

    _isStartupTestingInProgress = true;
    _lastStartupTest = DateTime.now();
    
    try {
      print('🚀 Starting immediate server ping testing for ${serverConfigs.length} servers...');
      
      // Notify progress start
      _notifyProgress(PingTestProgress(
        completed: 0,
        total: serverConfigs.length,
        phase: PingTestPhase.starting,
        message: 'شروع تست پینگ ${serverConfigs.length} سرور...',
      ));
      
      int completedCount = 0;
      final results = await getPingResults(
        serverConfigs,
        timeoutSeconds: timeoutSeconds,
        useCache: false, // Force fresh tests on startup
        parallel: true,
        onProgress: (server, result) {
          onProgress?.call(server, result);
          completedCount++;
          onProgressCount?.call(completedCount, serverConfigs.length);
          
          // Update progress
          _notifyProgress(PingTestProgress(
            completed: completedCount,
            total: serverConfigs.length,
            phase: PingTestPhase.testing,
            message: 'تست شده: $completedCount از ${serverConfigs.length}',
            currentServer: server,
            currentResult: result,
          ));
        },
      );
      
      _startupTestingCompleted = true;
      
      // Notify completion
      _notifyProgress(PingTestProgress(
        completed: serverConfigs.length,
        total: serverConfigs.length,
        phase: PingTestPhase.completed,
        message: 'تست پینگ تکمیل شد - ${results.length} نتیجه',
      ));
      
      print('✅ Startup ping testing completed: ${results.length} results');
      return results;
      
    } finally {
      _isStartupTestingInProgress = false;
    }
  }

  /// Get ping results for multiple servers
  Future<Map<String, PingResult>> getPingResults(List<String> serverConfigs, {
    int timeoutSeconds = 3,
    bool useCache = true,
    bool parallel = true,
    Function(String, PingResult)? onProgress,
  }) async {
    final results = <String, PingResult>{};
    
    // Filter valid servers
    final validServers = serverConfigs
        .where((config) => config.isNotEmpty && config != 'Automatic')
        .toList();

    if (validServers.isEmpty) {
      return results;
    }

    if (parallel) {
      // Parallel testing with controlled concurrency
      final futures = <Future<void>>[];
      final semaphore = Semaphore(6); // Limit concurrent tests
      
      for (final server in validServers) {
        futures.add(semaphore.acquire().then((_) async {
          try {
            final result = await getPingResult(server, 
                timeoutSeconds: timeoutSeconds, useCache: useCache);
            results[server] = result;
            onProgress?.call(server, result);
          } finally {
            semaphore.release();
          }
        }));
      }
      
      await Future.wait(futures);
    } else {
      // Sequential testing
      for (final server in validServers) {
        final result = await getPingResult(server, 
            timeoutSeconds: timeoutSeconds, useCache: useCache);
        results[server] = result;
        onProgress?.call(server, result);
      }
    }

    return results;
  }

  /// Get cached ping results (fast, no network calls)
  Map<String, PingResult> getCachedResults([List<String>? serverConfigs]) {
    if (serverConfigs == null) {
      return Map<String, PingResult>.from(_memoryCache);
    }
    
    final results = <String, PingResult>{};
    for (final config in serverConfigs) {
      if (_memoryCache.containsKey(config)) {
        final cached = _memoryCache[config]!;
        if (!cached.isExpired) {
          results[config] = cached;
        }
      }
    }
    return results;
  }

  /// Clear all cached results
  Future<void> clearCache() async {
    _memoryCache.clear();
    _inFlightTests.clear();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pingCacheKey);
    await prefs.remove(_pingMetadataKey);
    await prefs.remove(_lastUpdateKey);
  }

  /// Get ping statistics
  PingStatistics getStatistics([List<String>? serverConfigs]) {
    final configs = serverConfigs ?? _memoryCache.keys.toList();
    final results = configs
        .map((config) => _memoryCache[config])
        .where((result) => result != null && !result.isExpired)
        .cast<PingResult>()
        .toList();

    if (results.isEmpty) {
      return PingStatistics.empty();
    }

    final validPings = results
        .where((r) => r.isSuccess)
        .map((r) => r.pingMs)
        .toList();

    if (validPings.isEmpty) {
      return PingStatistics.empty();
    }

    validPings.sort();
    
    return PingStatistics(
      totalServers: results.length,
      successfulPings: validPings.length,
      failedPings: results.length - validPings.length,
      averagePing: validPings.reduce((a, b) => a + b) / validPings.length,
      medianPing: validPings[validPings.length ~/ 2].toDouble(),
      minPing: validPings.first.toDouble(),
      maxPing: validPings.last.toDouble(),
      excellentServers: validPings.where((p) => p < 100).length,
      goodServers: validPings.where((p) => p >= 100 && p < 300).length,
      fairServers: validPings.where((p) => p >= 300 && p < 600).length,
      poorServers: validPings.where((p) => p >= 600).length,
    );
  }

  /// Perform actual ping test
  Future<PingResult> _performPingTest(String serverConfig, int timeoutSeconds) async {
    try {
      final startTime = DateTime.now();
      final ping = await _pingService.testServerPing(serverConfig, timeoutSeconds: timeoutSeconds);
      final endTime = DateTime.now();
      
      if (ping > 0 && ping < 9999) {
        return PingResult.success(
          serverConfig: serverConfig,
          pingMs: ping,
          testTime: startTime,
          responseTime: endTime.difference(startTime),
        );
      } else if (ping >= 9999) {
        return PingResult.timeout(serverConfig, testTime: startTime);
      } else {
        return PingResult.failed(serverConfig, testTime: startTime);
      }
    } catch (e) {
      return PingResult.failed(serverConfig, error: e.toString());
    }
  }

  /// Load cached results from persistent storage
  Future<void> _loadCachedResults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getString(_pingCacheKey);
      
      if (cacheJson != null) {
        final cacheData = json.decode(cacheJson) as Map<String, dynamic>;
        
        for (final entry in cacheData.entries) {
          try {
            final result = PingResult.fromJson(entry.value);
            if (!result.isExpired) {
              _memoryCache[entry.key] = result;
            }
          } catch (e) {
            // Skip invalid cache entries
          }
        }
      }
    } catch (e) {
      print('Error loading ping cache: $e');
    }
  }

  /// Save result to persistent cache
  Future<void> _saveToPersistentCache(String serverConfig, PingResult result) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingJson = prefs.getString(_pingCacheKey) ?? '{}';
      final cacheData = json.decode(existingJson) as Map<String, dynamic>;
      
      cacheData[serverConfig] = result.toJson();
      
      // Cleanup expired entries
      cacheData.removeWhere((key, value) {
        try {
          final cachedResult = PingResult.fromJson(value);
          return cachedResult.isExpired;
        } catch (e) {
          return true; // Remove invalid entries
        }
      });
      
      await prefs.setString(_pingCacheKey, json.encode(cacheData));
      await prefs.setString(_lastUpdateKey, DateTime.now().toIso8601String());
    } catch (e) {
      print('Error saving ping cache: $e');
    }
  }

  /// Notify listeners of ping updates
  void _notifyPingUpdate(String serverConfig, PingResult result) {
    if (!_pingUpdatesController.isClosed) {
      _pingUpdatesController.add({serverConfig: result});
    }
  }
  
  /// Notify progress updates
  void _notifyProgress(PingTestProgress progress) {
    if (!_progressController.isClosed) {
      _progressController.add(progress);
    }
  }
  
  /// Get startup testing status
  bool get isStartupTestingInProgress => _isStartupTestingInProgress;
  bool get isStartupTestingCompleted => _startupTestingCompleted;
  DateTime? get lastStartupTest => _lastStartupTest;
  
  /// Force refresh all cached results
  Future<Map<String, PingResult>> forceRefreshAll(List<String> serverConfigs, {
    int timeoutSeconds = 3,
    Function(String, PingResult)? onProgress,
  }) async {
    // Clear all cached results
    _memoryCache.clear();
    
    return await getPingResults(
      serverConfigs,
      timeoutSeconds: timeoutSeconds,
      useCache: false,
      parallel: true,
      onProgress: onProgress,
    );
  }

  /// Dispose resources
  void dispose() {
    _pingUpdatesController.close();
    _progressController.close();
    _memoryCache.clear();
    _inFlightTests.clear();
    _isStartupTestingInProgress = false;
    _startupTestingCompleted = false;
  }
}

/// Ping result data class
class PingResult {
  final String serverConfig;
  final int pingMs;
  final DateTime testTime;
  final Duration? responseTime;
  final String? error;
  final PingStatus status;

  PingResult({
    required this.serverConfig,
    required this.pingMs,
    required this.testTime,
    this.responseTime,
    this.error,
    required this.status,
  });

  factory PingResult.success({
    required String serverConfig,
    required int pingMs,
    required DateTime testTime,
    Duration? responseTime,
  }) {
    return PingResult(
      serverConfig: serverConfig,
      pingMs: pingMs,
      testTime: testTime,
      responseTime: responseTime,
      status: PingStatus.success,
    );
  }

  factory PingResult.timeout(String serverConfig, {DateTime? testTime}) {
    return PingResult(
      serverConfig: serverConfig,
      pingMs: 9999,
      testTime: testTime ?? DateTime.now(),
      status: PingStatus.timeout,
    );
  }

  factory PingResult.failed(String serverConfig, {DateTime? testTime, String? error}) {
    return PingResult(
      serverConfig: serverConfig,
      pingMs: -1,
      testTime: testTime ?? DateTime.now(),
      error: error,
      status: PingStatus.failed,
    );
  }

  bool get isSuccess => status == PingStatus.success && pingMs > 0 && pingMs < 9999;
  bool get isTimeout => status == PingStatus.timeout || pingMs >= 9999;
  bool get isFailed => status == PingStatus.failed || pingMs < 0;

  bool get isExpired {
    final now = DateTime.now();
    final age = now.difference(testTime);
    
    switch (quality) {
      case PingQuality.excellent:
        return age > UnifiedPingManager._excellentCacheTtl;
      case PingQuality.good:
        return age > UnifiedPingManager._goodCacheTtl;
      case PingQuality.fair:
        return age > UnifiedPingManager._fairCacheTtl;
      case PingQuality.poor:
        return age > UnifiedPingManager._poorCacheTtl;
      case PingQuality.bad:
        return age > UnifiedPingManager._badCacheTtl;
      case PingQuality.failed:
        return age > UnifiedPingManager._failureCacheTtl;
    }
  }

  PingQuality get quality {
    if (isFailed) return PingQuality.failed;
    if (isTimeout) return PingQuality.bad;
    if (pingMs < 100) return PingQuality.excellent;
    if (pingMs < 300) return PingQuality.good;
    if (pingMs < 600) return PingQuality.fair;
    if (pingMs < 1000) return PingQuality.poor;
    return PingQuality.bad;
  }

  Map<String, dynamic> toJson() {
    return {
      'serverConfig': serverConfig,
      'pingMs': pingMs,
      'testTime': testTime.toIso8601String(),
      'responseTime': responseTime?.inMilliseconds,
      'error': error,
      'status': status.index,
    };
  }

  factory PingResult.fromJson(Map<String, dynamic> json) {
    return PingResult(
      serverConfig: json['serverConfig'],
      pingMs: json['pingMs'],
      testTime: DateTime.parse(json['testTime']),
      responseTime: json['responseTime'] != null 
          ? Duration(milliseconds: json['responseTime']) 
          : null,
      error: json['error'],
      status: PingStatus.values[json['status']],
    );
  }
}

enum PingStatus { success, timeout, failed }
enum PingQuality { excellent, good, fair, poor, bad, failed }
enum PingTestPhase { starting, testing, completed, failed }

/// Ping statistics data class
class PingStatistics {
  final int totalServers;
  final int successfulPings;
  final int failedPings;
  final double averagePing;
  final double medianPing;
  final double minPing;
  final double maxPing;
  final int excellentServers;
  final int goodServers;
  final int fairServers;
  final int poorServers;

  PingStatistics({
    required this.totalServers,
    required this.successfulPings,
    required this.failedPings,
    required this.averagePing,
    required this.medianPing,
    required this.minPing,
    required this.maxPing,
    required this.excellentServers,
    required this.goodServers,
    required this.fairServers,
    required this.poorServers,
  });

  factory PingStatistics.empty() {
    return PingStatistics(
      totalServers: 0,
      successfulPings: 0,
      failedPings: 0,
      averagePing: 0.0,
      medianPing: 0.0,
      minPing: 0.0,
      maxPing: 0.0,
      excellentServers: 0,
      goodServers: 0,
      fairServers: 0,
      poorServers: 0,
    );
  }

  double get successRate => totalServers > 0 ? successfulPings / totalServers : 0.0;
  double get failureRate => totalServers > 0 ? failedPings / totalServers : 0.0;
}

/// Progress tracking for ping tests
class PingTestProgress {
  final int completed;
  final int total;
  final PingTestPhase phase;
  final String message;
  final String? currentServer;
  final PingResult? currentResult;
  final DateTime timestamp;
  
  PingTestProgress({
    required this.completed,
    required this.total,
    required this.phase,
    required this.message,
    this.currentServer,
    this.currentResult,
  }) : timestamp = DateTime.now();
  
  double get progress => total > 0 ? completed / total : 0.0;
  bool get isCompleted => completed >= total;
  bool get isFailed => phase == PingTestPhase.failed;
}

/// Semaphore for controlling concurrency
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
