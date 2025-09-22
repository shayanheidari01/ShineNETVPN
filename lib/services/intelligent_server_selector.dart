import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'flutter_v2ray_ping_service.dart'; // Use V2Ray delay ping service
import 'server_optimization_service.dart';
import 'connection_optimization_service.dart';

/// Intelligent server selector that learns from user patterns and optimizes selection
class IntelligentServerSelector {
  static final IntelligentServerSelector _instance =
      IntelligentServerSelector._internal();
  factory IntelligentServerSelector() => _instance;
  IntelligentServerSelector._internal();

  final ServerOptimizationService _serverOptimization =
      ServerOptimizationService();
  final ConnectionOptimizationService _connectionOptimization =
      ConnectionOptimizationService();

  // Caching and prediction
  final Map<String, ServerPrediction> _serverPredictions = {};
  final List<ConnectionPattern> _connectionPatterns = [];

  // Performance tracking
  final Map<String, PerformanceMetrics> _performanceHistory = {};
  Timer? _learningTimer;

  // Adaptive selection state
  final Map<String, AdaptiveServerMetrics> _adaptiveMetrics = {};
  DateTime? _lastAutoSelection;
  String? _currentBestServer;
  int _consecutiveFailures = 0;

  // Configuration - Optimized for faster automatic connections
  static const Duration _predictionCacheTimeout = Duration(minutes: 10);
  static const int _maxPredictionHistory = 100;
  static const int _maxAdaptiveRetries = 3;

  /// Initialize the intelligent selector
  Future<void> initialize() async {
    await _serverOptimization.initialize();
    await _connectionOptimization.initialize();
    await _loadLearningData();
    _startLearningProcess();
  }

  /// Get the best server with intelligent prediction and adaptive selection
  Future<String?> getBestServer({
    Function(String)? onStatusUpdate,
    Function(int, int)? onProgressUpdate,
    bool forceRefresh = false,
    bool useTcpFiltering = true, // Add TCP filtering option
  }) async {
    try {
      onStatusUpdate?.call('🔍 Analyzing optimal server selection...');

      // Adaptive selection: use recent best server if available and performing well
      if (!forceRefresh && _shouldUseAdaptiveSelection()) {
        final adaptiveServer = await _getAdaptiveServer(onStatusUpdate);
        if (adaptiveServer != null) {
          onStatusUpdate?.call('🚀 Using adaptive server selection...');
          return adaptiveServer;
        }
      }

      // Check if we have a recent prediction that's still valid
      if (!forceRefresh) {
        final cachedPrediction = _getCachedPrediction();
        if (cachedPrediction != null) {
          onStatusUpdate?.call('💡 Using intelligent prediction...');
          return cachedPrediction;
        }
      }

      // Get servers from optimization service with enhanced filtering
      onStatusUpdate?.call('📡 Fetching optimized server list...');
      final servers = await _serverOptimization.getOptimizedServerList(
        forceRefresh: forceRefresh,
        onStatusUpdate: onStatusUpdate,
      );

      if (servers.isEmpty) {
        return await _handleEmptyServerList(onStatusUpdate);
      }

      // Apply V2Ray delay pre-check (optional) to skip clearly unreachable servers
      List<String> filteredServers = servers;
      if (useTcpFiltering && servers.length > 5) {
        onStatusUpdate?.call('📡 Pre-checking servers with V2Ray delay...');
        final v2rayPing = FlutterV2rayPingService();
        v2rayPing.initialize();
        final pingMap = await v2rayPing.testMultipleServerPingsRobust(
          servers,
          timeoutSeconds: 2,
          parallel: false, // Sequential single-attempt pre-check per requirement
          onProgress: (completed, total) =>
              onProgressUpdate?.call(completed, total),
        );

        // Keep servers with valid delay (0 < ping < 9999)
        filteredServers = servers
            .where((s) => ((pingMap[s] ?? -1) > 0 && (pingMap[s] ?? -1) < 9999))
            .toList();

        if (filteredServers.isEmpty) {
          filteredServers = servers; // Fall back to original list
          onStatusUpdate?.call('⚠️ Pre-check filtered all servers, using original list...');
        } else {
          onStatusUpdate?.call(
              '✅ V2Ray delay pre-check kept ${filteredServers.length}/${servers.length} servers');
        }
      }

      // Apply multi-layer intelligent filtering
      final scoredServers =
          await _applyAdvancedFiltering(filteredServers, onStatusUpdate);

      onStatusUpdate?.call('⚡ Testing servers with AI optimization...');

      // Enhanced server testing with adaptive timeout
      final bestServer = await _performAdaptiveServerSelection(
        scoredServers,
        onStatusUpdate: onStatusUpdate,
        onProgressUpdate: onProgressUpdate,
      );

      if (bestServer != null) {
        // Learn from this selection and update adaptive metrics
        _recordSuccessfulSelection(bestServer);
        _updateAdaptiveMetrics(bestServer, true);

        // Cache the prediction with enhanced confidence
        _cachePrediction(bestServer);

        _currentBestServer = bestServer;
        _lastAutoSelection = DateTime.now();
        _consecutiveFailures = 0;

        onStatusUpdate?.call('✅ Optimal server selected successfully');
        return bestServer;
      }

      throw Exception(
          'Failed to connect to any server after intelligent selection');
    } catch (e) {
      _consecutiveFailures++;
      onStatusUpdate?.call('❌ Selection failed: ${e.toString()}');

      // Fallback to emergency server selection
      return await _handleSelectionFailure(onStatusUpdate);
    }
  }

  /// Apply advanced multi-layer filtering with adaptive intelligence
  Future<List<String>> _applyAdvancedFiltering(
      List<String> servers, Function(String)? onStatusUpdate) async {
    onStatusUpdate?.call('🧮 Applying intelligent filtering...');

    // Quick pre-filtering for speed
    final validServers = servers.where((server) => server.isNotEmpty).toList();
    if (validServers.length <= 10) {
      // Small lists don't need complex filtering
      return validServers;
    }

    final scoredServers = <ScoredServer>[];
    final currentTime = DateTime.now();

    // Limit servers for speed optimization - take top 20 most recent + random 10
    final recentServers = validServers.take(20).toList();
    final remainingServers = validServers.skip(20).toList();
    remainingServers.shuffle();
    final serversToScore = [...recentServers, ...remainingServers.take(10)];

    for (final server in serversToScore) {
      double score = 60.0; // Enhanced base score

      // Historical performance with exponential weighting
      final performance = _performanceHistory[server];
      if (performance != null) {
        // Success rate with exponential bonus for high performers
        final successBonus = pow(performance.successRate, 1.5) * 40.0;
        score += successBonus;

        // Response time with logarithmic penalty
        final responseTimePenalty =
            log(performance.avgResponseTime.clamp(1, 5000)) * 8.0;
        score -= responseTimePenalty;

        // Recent activity bonus (servers used in last hour get priority)
        final hoursSinceLastUse =
            currentTime.difference(performance.lastUsed).inHours;
        if (hoursSinceLastUse < 1) {
          score += 25.0;
        } else if (hoursSinceLastUse < 6) {
          score += 15.0;
        } else if (hoursSinceLastUse < 24) {
          score += 5.0;
        }

        // Failure penalty with exponential growth
        score -= pow(performance.failureCount, 1.3) * 3.0;
      }

      // Adaptive metrics bonus
      final adaptiveMetrics = _adaptiveMetrics[server];
      if (adaptiveMetrics != null) {
        score += adaptiveMetrics.adaptiveScore;

        // Consistency bonus for stable performers
        if (adaptiveMetrics.consistencyRating > 0.8) {
          score += 20.0;
        }
      }

      // Enhanced pattern matching
      final patternScore = _calculateAdvancedPatternScore(server);
      score += patternScore;

      // Dynamic time-based preferences
      final timeScore = _calculateDynamicTimeScore(server);
      score += timeScore;

      // Connection quality prediction
      final qualityScore = _predictConnectionQuality(server);
      score += qualityScore;

      scoredServers.add(ScoredServer(server, score));
    }

    // Sort by score and return top performers with diversity
    scoredServers.sort((a, b) => b.score.compareTo(a.score));

    // Select top servers with geographic diversity if possible
    final selectedServers = _selectDiverseServers(scoredServers);

    onStatusUpdate
        ?.call('🎯 Selected ${selectedServers.length} optimal servers');
    return selectedServers;
  }

  /// Calculate advanced pattern-based score with machine learning insights
  double _calculateAdvancedPatternScore(String server) {
    double score = 0.0;
    final currentTime = DateTime.now();

    // Check recent connection patterns with weighted time decay
    final recentPatterns = _connectionPatterns
        .where((p) => currentTime.difference(p.timestamp) < Duration(hours: 48))
        .toList();

    if (recentPatterns.isEmpty) return score;

    // Weighted frequency bonus with time decay
    for (final pattern
        in recentPatterns.where((p) => p.server == server && p.successful)) {
      final hoursAgo = currentTime.difference(pattern.timestamp).inHours;
      final timeWeight =
          exp(-hoursAgo / 24.0); // Exponential decay over 24 hours
      score += timeWeight * 3.0;
    }

    // Advanced time pattern matching with broader windows
    final currentHour = currentTime.hour;
    final currentDayOfWeek = currentTime.weekday;

    // Same hour patterns (±2 hours)
    final sameTimePatterns = recentPatterns
        .where((p) =>
            p.server == server &&
            p.successful &&
            (p.timestamp.hour - currentHour).abs() <= 2)
        .length;
    score += sameTimePatterns * 4.0;

    // Same day of week patterns
    final sameDayPatterns = recentPatterns
        .where((p) =>
            p.server == server &&
            p.successful &&
            p.timestamp.weekday == currentDayOfWeek)
        .length;
    score += sameDayPatterns * 2.0;

    // Consecutive success streak bonus
    final recentServerPatterns = recentPatterns
        .where((p) => p.server == server)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    int consecutiveSuccesses = 0;
    for (final pattern in recentServerPatterns) {
      if (pattern.successful) {
        consecutiveSuccesses++;
      } else {
        break;
      }
    }
    score += consecutiveSuccesses * 5.0;

    return score;
  }

  /// Calculate dynamic time-based score with network load prediction
  double _calculateDynamicTimeScore(String server) {
    final currentTime = DateTime.now();
    final currentHour = currentTime.hour;
    final currentDayOfWeek = currentTime.weekday;
    double score = 0.0;

    final performance = _performanceHistory[server];

    // Enhanced peak hours analysis (6 PM - 11 PM)
    if (currentHour >= 18 && currentHour <= 23) {
      if (performance != null) {
        // Prefer servers with consistently good performance during peak hours
        if (performance.avgResponseTime < 300) {
          score += 20.0; // Excellent peak performance
        } else if (performance.avgResponseTime < 600) {
          score += 12.0; // Good peak performance
        } else {
          score -= 5.0; // Poor peak performance penalty
        }

        // Success rate during peak hours is crucial
        if (performance.successRate > 0.9) {
          score += 15.0;
        }
      }
    }

    // Morning hours (6 AM - 10 AM) - prefer reliable servers
    else if (currentHour >= 6 && currentHour <= 10) {
      if (performance != null && performance.successRate > 0.85) {
        score += 12.0;
      }
    }

    // Off-peak hours (11 PM - 6 AM) - any decent server works
    else if (currentHour >= 23 || currentHour <= 6) {
      score += 8.0; // General off-peak bonus
      if (performance != null && performance.avgResponseTime < 800) {
        score += 5.0; // Bonus for fast off-peak servers
      }
    }

    // Weekend vs weekday preferences
    if (currentDayOfWeek >= 6) {
      // Weekend
      score += 3.0; // Slight weekend bonus for all servers
    }

    // Lunch hours (12 PM - 2 PM) - moderate load
    if (currentHour >= 12 && currentHour <= 14) {
      if (performance != null && performance.avgResponseTime < 400) {
        score += 8.0;
      }
    }

    return score;
  }

  /// Get cached prediction if available and valid
  String? _getCachedPrediction() {
    final bestPrediction = _serverPredictions.values
        .where((p) =>
            DateTime.now().difference(p.timestamp) < _predictionCacheTimeout)
        .fold<ServerPrediction?>(null, (best, current) {
      if (best == null || current.confidence > best.confidence) {
        return current;
      }
      return best;
    });

    return bestPrediction?.server;
  }

  /// Cache a server prediction
  void _cachePrediction(String server) {
    final confidence = _calculatePredictionConfidence(server);
    _serverPredictions[server] = ServerPrediction(
      server: server,
      confidence: confidence,
      timestamp: DateTime.now(),
    );
  }

  /// Calculate prediction confidence based on historical data
  double _calculatePredictionConfidence(String server) {
    final performance = _performanceHistory[server];
    if (performance == null) return 0.5;

    double confidence = 0.0;

    // Success rate confidence
    confidence += performance.successRate * 0.4;

    // Response time confidence
    if (performance.avgResponseTime < 200) {
      confidence += 0.3;
    } else if (performance.avgResponseTime < 500) {
      confidence += 0.2;
    } else if (performance.avgResponseTime < 1000) {
      confidence += 0.1;
    }

    // Usage frequency confidence
    final recentUsage = _connectionPatterns
        .where((p) =>
            p.server == server &&
            DateTime.now().difference(p.timestamp) < Duration(days: 7))
        .length;
    confidence += (recentUsage / 10.0).clamp(0.0, 0.3);

    return confidence.clamp(0.0, 1.0);
  }

  /// Record a successful server selection for learning
  void _recordSuccessfulSelection(String server) {
    // Update performance metrics
    if (!_performanceHistory.containsKey(server)) {
      _performanceHistory[server] = PerformanceMetrics();
    }

    final metrics = _performanceHistory[server]!;
    metrics.totalConnections++;
    metrics.successfulConnections++;
    metrics.lastUsed = DateTime.now();

    // Record connection pattern
    _connectionPatterns.add(ConnectionPattern(
      server: server,
      timestamp: DateTime.now(),
      successful: true,
    ));

    // Limit pattern history
    if (_connectionPatterns.length > _maxPredictionHistory) {
      _connectionPatterns.removeRange(
          0, _connectionPatterns.length - _maxPredictionHistory);
    }

    // Save learning data
    _saveLearningData();
  }

  /// Record a failed server selection for learning
  void recordFailedSelection(String server, int responseTime) {
    if (!_performanceHistory.containsKey(server)) {
      _performanceHistory[server] = PerformanceMetrics();
    }

    final metrics = _performanceHistory[server]!;
    metrics.totalConnections++;
    metrics.failureCount++;
    metrics.totalResponseTime += responseTime;
    metrics.avgResponseTime =
        metrics.totalResponseTime / metrics.totalConnections;

    // Record failed pattern
    _connectionPatterns.add(ConnectionPattern(
      server: server,
      timestamp: DateTime.now(),
      successful: false,
    ));

    _saveLearningData();
  }

  /// Start the enhanced learning process - Optimized to 10 minutes
  void _startLearningProcess() {
    _learningTimer?.cancel();
    _learningTimer = Timer.periodic(Duration(minutes: 10), (timer) {
      _performLearningUpdate();
    });
  }

  /// Perform periodic learning updates with adaptive intelligence
  void _performLearningUpdate() {
    final currentTime = DateTime.now();

    // Clean old predictions - Optimized to 45 minutes
    _serverPredictions.removeWhere((key, prediction) =>
        currentTime.difference(prediction.timestamp) > Duration(minutes: 45));

    // Clean old adaptive metrics (keep last 7 days)
    _adaptiveMetrics.removeWhere((key, metrics) =>
        currentTime.difference(metrics.lastAdaptiveUpdate) > Duration(days: 7));

    // Update performance metrics based on recent patterns
    _updatePerformanceMetrics();

    // Update adaptive metrics for all servers
    _updateAllAdaptiveMetrics();

    // Perform predictive analysis for future connections
    _performPredictiveAnalysis();

    // Save updated learning data
    _saveLearningData();
  }

  /// Update performance metrics based on patterns
  void _updatePerformanceMetrics() {
    for (final server in _performanceHistory.keys) {
      final metrics = _performanceHistory[server]!;

      // Calculate success rate
      if (metrics.totalConnections > 0) {
        metrics.successRate =
            metrics.successfulConnections / metrics.totalConnections;
      }

      // Decay old metrics to give more weight to recent performance
      if (DateTime.now().difference(metrics.lastUsed) > Duration(days: 7)) {
        metrics.successRate *= 0.9; // Slight decay for unused servers
      }
    }
  }

  /// Load learning data from storage with adaptive metrics
  Future<void> _loadLearningData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load performance history
      final performanceData =
          prefs.getString('intelligent_performance_history');
      if (performanceData != null) {
        final Map<String, dynamic> data = json.decode(performanceData);
        _performanceHistory.clear();
        data.forEach((key, value) {
          _performanceHistory[key] = PerformanceMetrics.fromJson(value);
        });
      }

      // Load connection patterns
      final patternsData = prefs.getString('intelligent_connection_patterns');
      if (patternsData != null) {
        final List<dynamic> data = json.decode(patternsData);
        _connectionPatterns.clear();
        _connectionPatterns.addAll(
            data.map((item) => ConnectionPattern.fromJson(item)).toList());
      }

      // Load adaptive metrics
      final adaptiveData = prefs.getString('intelligent_adaptive_metrics');
      if (adaptiveData != null) {
        final Map<String, dynamic> data = json.decode(adaptiveData);
        _adaptiveMetrics.clear();
        data.forEach((key, value) {
          _adaptiveMetrics[key] = AdaptiveServerMetrics.fromJson(value);
        });
      }
    } catch (e) {
      print('Error loading learning data: $e');
    }
  }

  /// Save learning data to storage with adaptive metrics
  Future<void> _saveLearningData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save performance history
      final performanceData = _performanceHistory
          .map((key, value) => MapEntry(key, value.toJson()));
      await prefs.setString(
          'intelligent_performance_history', json.encode(performanceData));

      // Save connection patterns (keep only recent ones)
      final recentPatterns = _connectionPatterns
          .where((p) =>
              DateTime.now().difference(p.timestamp) < Duration(days: 30))
          .toList();
      final patternsData = recentPatterns.map((p) => p.toJson()).toList();
      await prefs.setString(
          'intelligent_connection_patterns', json.encode(patternsData));

      // Save adaptive metrics
      final adaptiveData =
          _adaptiveMetrics.map((key, value) => MapEntry(key, value.toJson()));
      await prefs.setString(
          'intelligent_adaptive_metrics', json.encode(adaptiveData));
    } catch (e) {
      print('Error saving learning data: $e');
    }
  }

  /// Get performance statistics
  Map<String, dynamic> getPerformanceStats() {
    final totalServers = _performanceHistory.length;
    final avgSuccessRate = _performanceHistory.values
            .map((m) => m.successRate)
            .fold(0.0, (a, b) => a + b) /
        max(totalServers, 1);

    return {
      'totalServers': totalServers,
      'avgSuccessRate': avgSuccessRate,
      'totalPatterns': _connectionPatterns.length,
      'activePredictions': _serverPredictions.length,
    };
  }

  /// Check if adaptive selection should be used
  bool _shouldUseAdaptiveSelection() {
    if (_currentBestServer == null || _lastAutoSelection == null) {
      return false;
    }

    // Use adaptive selection if last selection was recent and successful
    final timeSinceLastSelection =
        DateTime.now().difference(_lastAutoSelection!);
    if (timeSinceLastSelection > Duration(minutes: 30)) {
      return false;
    }

    // Check if current best server is still performing well
    final adaptiveMetrics = _adaptiveMetrics[_currentBestServer!];
    if (adaptiveMetrics != null) {
      return adaptiveMetrics.recentSuccessRate > 0.8 &&
          adaptiveMetrics.consistencyRating > 0.7;
    }

    return _consecutiveFailures < 2;
  }

  /// Get adaptive server selection
  Future<String?> _getAdaptiveServer(Function(String)? onStatusUpdate) async {
    if (_currentBestServer == null) return null;

    try {
      // Quick validation of current best server
      onStatusUpdate?.call('🔄 Validating adaptive server...');

      final testResult =
          await _serverOptimization.testServerConnection(_currentBestServer!);

      if (testResult.success && testResult.responseTime < 2000) {
        _updateAdaptiveMetrics(
            _currentBestServer!, true, testResult.responseTime);
        return _currentBestServer;
      } else {
        _updateAdaptiveMetrics(
            _currentBestServer!, false, testResult.responseTime);
        _currentBestServer = null;
        return null;
      }
    } catch (e) {
      _currentBestServer = null;
      return null;
    }
  }

  /// Handle empty server list scenario
  Future<String?> _handleEmptyServerList(
      Function(String)? onStatusUpdate) async {
    onStatusUpdate?.call('⚠️ No servers available, using fallback...');

    // Try to get cached servers from optimization service
    try {
      final cachedServers =
          await _serverOptimization.getOptimizedServerList(forceRefresh: false);
      if (cachedServers.isNotEmpty) {
        return cachedServers.first;
      }
    } catch (e) {
      print('Fallback server retrieval failed: $e');
    }

    throw Exception('No servers available and fallback failed');
  }

  /// Handle selection failure with emergency fallback
  Future<String?> _handleSelectionFailure(
      Function(String)? onStatusUpdate) async {
    onStatusUpdate?.call('🆘 Attempting emergency server selection...');

    // If we have too many consecutive failures, reset adaptive state
    if (_consecutiveFailures >= _maxAdaptiveRetries) {
      _currentBestServer = null;
      _lastAutoSelection = null;
      _consecutiveFailures = 0;
    }

    // Try to get any working server from cache
    try {
      final cachedServers =
          await _serverOptimization.getOptimizedServerList(forceRefresh: false);
      if (cachedServers.isNotEmpty) {
        // Return the first cached server as emergency fallback
        onStatusUpdate?.call('🔧 Using emergency fallback server');
        return cachedServers.first;
      }
    } catch (e) {
      print('Emergency fallback failed: $e');
    }

    return null;
  }

  /// Perform adaptive server selection with enhanced testing
  Future<String?> _performAdaptiveServerSelection(
    List<String> servers, {
    Function(String)? onStatusUpdate,
    Function(int, int)? onProgressUpdate,
  }) async {
    if (servers.isEmpty) return null;

    try {
      // Use connection optimization service for testing
      final testResults = await _connectionOptimization.connectToBestServer(
        servers,
        onStatusUpdate: onStatusUpdate,
        onProgressUpdate: onProgressUpdate,
      );

      return testResults.success ? testResults.server : null;
    } catch (e) {
      print('Adaptive server selection failed: $e');
      return null;
    }
  }

  /// Update adaptive metrics for a server
  void _updateAdaptiveMetrics(String server, bool success,
      [int? responseTime]) {
    if (!_adaptiveMetrics.containsKey(server)) {
      _adaptiveMetrics[server] = AdaptiveServerMetrics();
    }

    _adaptiveMetrics[server]!.updateMetrics(success, responseTime ?? 0);
  }

  /// Select diverse servers for better geographic distribution
  List<String> _selectDiverseServers(List<ScoredServer> scoredServers) {
    // Optimized selection: top 15 servers with some diversity
    final selectedServers = <String>[];
    final addressSet = <String>{};

    // Always include top 5 servers regardless of address
    for (int i = 0; i < min(5, scoredServers.length); i++) {
      selectedServers.add(scoredServers[i].server);
      try {
        final address = _extractServerAddress(scoredServers[i].server);
        if (address != null) addressSet.add(address);
      } catch (e) {
        // Ignore address extraction errors
      }
    }

    // Add more servers with diversity consideration
    for (int i = 5;
        i < scoredServers.length && selectedServers.length < 15;
        i++) {
      final server = scoredServers[i].server;
      final address = _extractServerAddress(server);

      // Add server if unique address or we have less than 10 servers
      if (selectedServers.length < 10 ||
          address == null ||
          !addressSet.contains(address)) {
        selectedServers.add(server);
        if (address != null) addressSet.add(address);
      }
    }

    return selectedServers;
  }

  /// Extract server address for diversity checking
  String? _extractServerAddress(String server) {
    try {
      if (server.startsWith('vmess://')) {
        final base64Part = server.substring(8);
        final decoded = base64.decode(base64Part);
        final decodedString = utf8.decode(decoded);
        final jsonData = json.decode(decodedString);
        return jsonData['add'] ?? jsonData['address'];
      }
      // Add other protocol parsing as needed
    } catch (e) {
      // Ignore errors
    }
    return null;
  }

  /// Predict connection quality based on historical data
  double _predictConnectionQuality(String server) {
    final performance = _performanceHistory[server];
    final adaptive = _adaptiveMetrics[server];

    if (performance == null && adaptive == null) return 0.0;

    double qualityScore = 0.0;

    if (performance != null) {
      // Base quality from historical performance
      qualityScore += performance.successRate * 15.0;

      // Response time quality (faster = better)
      if (performance.avgResponseTime < 200) {
        qualityScore += 10.0;
      } else if (performance.avgResponseTime < 500) {
        qualityScore += 5.0;
      }
    }

    if (adaptive != null) {
      // Recent performance quality
      qualityScore += adaptive.adaptiveScore * 0.2;
    }

    return qualityScore;
  }

  /// Update all adaptive metrics during learning cycles
  void _updateAllAdaptiveMetrics() {
    final currentTime = DateTime.now();

    // Decay adaptive scores for servers not used recently
    for (final metrics in _adaptiveMetrics.values) {
      final daysSinceUpdate =
          currentTime.difference(metrics.lastAdaptiveUpdate).inDays;
      if (daysSinceUpdate > 1) {
        // Gradually decay adaptive score for unused servers
        metrics.adaptiveScore *= pow(0.95, daysSinceUpdate);
      }
    }
  }

  /// Perform predictive analysis for future connections
  void _performPredictiveAnalysis() {
    // Analyze patterns to predict optimal servers for different time periods
    final currentHour = DateTime.now().hour;

    // Update predictions for next few hours based on historical patterns
    for (final server in _performanceHistory.keys) {
      final performance = _performanceHistory[server]!;

      // Calculate time-based prediction confidence
      final hourlyPatterns = _connectionPatterns
          .where((p) => p.server == server && p.successful)
          .where((p) => (p.timestamp.hour - currentHour).abs() <= 3)
          .length;

      if (hourlyPatterns > 2) {
        // This server performs well at this time
        final prediction = ServerPrediction(
          server: server,
          confidence: (hourlyPatterns / 10.0).clamp(0.0, 1.0),
          timestamp: DateTime.now(),
        );

        _serverPredictions[server] = prediction;
      }
    }
  }

  /// Cleanup resources
  void dispose() {
    _learningTimer?.cancel();
    _serverOptimization.dispose();
    // _connectionOptimization.dispose(); // Commented out as dispose method doesn't exist
    _saveLearningData();
  }
}

/// Server prediction model
class ServerPrediction {
  final String server;
  final double confidence;
  final DateTime timestamp;

  ServerPrediction({
    required this.server,
    required this.confidence,
    required this.timestamp,
  });
}

/// Connection pattern model
class ConnectionPattern {
  final String server;
  final DateTime timestamp;
  final bool successful;

  ConnectionPattern({
    required this.server,
    required this.timestamp,
    required this.successful,
  });

  Map<String, dynamic> toJson() => {
        'server': server,
        'timestamp': timestamp.toIso8601String(),
        'successful': successful,
      };

  factory ConnectionPattern.fromJson(Map<String, dynamic> json) {
    return ConnectionPattern(
      server: json['server'],
      timestamp: DateTime.parse(json['timestamp']),
      successful: json['successful'],
    );
  }
}

/// Performance metrics model
class PerformanceMetrics {
  int totalConnections = 0;
  int successfulConnections = 0;
  int failureCount = 0;
  int totalResponseTime = 0;
  double avgResponseTime = 0.0;
  double successRate = 0.0;
  DateTime lastUsed = DateTime.now();

  PerformanceMetrics();

  Map<String, dynamic> toJson() => {
        'totalConnections': totalConnections,
        'successfulConnections': successfulConnections,
        'failureCount': failureCount,
        'totalResponseTime': totalResponseTime,
        'avgResponseTime': avgResponseTime,
        'successRate': successRate,
        'lastUsed': lastUsed.toIso8601String(),
      };

  factory PerformanceMetrics.fromJson(Map<String, dynamic> json) {
    final metrics = PerformanceMetrics();
    metrics.totalConnections = json['totalConnections'] ?? 0;
    metrics.successfulConnections = json['successfulConnections'] ?? 0;
    metrics.failureCount = json['failureCount'] ?? 0;
    metrics.totalResponseTime = json['totalResponseTime'] ?? 0;
    metrics.avgResponseTime = json['avgResponseTime'] ?? 0.0;
    metrics.successRate = json['successRate'] ?? 0.0;
    metrics.lastUsed =
        DateTime.parse(json['lastUsed'] ?? DateTime.now().toIso8601String());
    return metrics;
  }
}

/// Scored server model for filtering
class ScoredServer {
  final String server;
  final double score;

  ScoredServer(this.server, this.score);
}

/// Adaptive server metrics for intelligent selection
class AdaptiveServerMetrics {
  double adaptiveScore = 0.0;
  double consistencyRating = 0.0;
  int recentConnections = 0;
  int recentSuccesses = 0;
  DateTime lastAdaptiveUpdate = DateTime.now();
  List<int> recentResponseTimes = [];

  AdaptiveServerMetrics();

  double get recentSuccessRate =>
      recentConnections > 0 ? recentSuccesses / recentConnections : 0.0;

  double get avgRecentResponseTime {
    if (recentResponseTimes.isEmpty) return 0.0;
    return recentResponseTimes.reduce((a, b) => a + b) /
        recentResponseTimes.length;
  }

  void updateMetrics(bool success, int responseTime) {
    recentConnections++;
    if (success) recentSuccesses++;

    recentResponseTimes.add(responseTime);
    if (recentResponseTimes.length > 10) {
      recentResponseTimes.removeAt(0);
    }

    // Calculate consistency rating based on response time variance
    if (recentResponseTimes.length >= 3) {
      final mean = avgRecentResponseTime;
      final variance = recentResponseTimes
              .map((rt) => pow(rt - mean, 2))
              .reduce((a, b) => a + b) /
          recentResponseTimes.length;
      final standardDeviation = sqrt(variance);

      // Lower standard deviation = higher consistency
      consistencyRating =
          1.0 - (standardDeviation / (mean + 1)).clamp(0.0, 1.0);
    }

    // Update adaptive score
    adaptiveScore = (recentSuccessRate * 50.0) +
        (consistencyRating * 30.0) +
        ((1000 - avgRecentResponseTime.clamp(0, 1000)) / 1000 * 20.0);

    lastAdaptiveUpdate = DateTime.now();
  }

  Map<String, dynamic> toJson() => {
        'adaptiveScore': adaptiveScore,
        'consistencyRating': consistencyRating,
        'recentConnections': recentConnections,
        'recentSuccesses': recentSuccesses,
        'lastAdaptiveUpdate': lastAdaptiveUpdate.toIso8601String(),
        'recentResponseTimes': recentResponseTimes,
      };

  factory AdaptiveServerMetrics.fromJson(Map<String, dynamic> json) {
    final metrics = AdaptiveServerMetrics();
    metrics.adaptiveScore = json['adaptiveScore'] ?? 0.0;
    metrics.consistencyRating = json['consistencyRating'] ?? 0.0;
    metrics.recentConnections = json['recentConnections'] ?? 0;
    metrics.recentSuccesses = json['recentSuccesses'] ?? 0;
    metrics.lastAdaptiveUpdate = DateTime.parse(
        json['lastAdaptiveUpdate'] ?? DateTime.now().toIso8601String());
    metrics.recentResponseTimes =
        List<int>.from(json['recentResponseTimes'] ?? []);
    return metrics;
  }
}
