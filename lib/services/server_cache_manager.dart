import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const String _lastFetchKey = 'last_fetch_timestamp_v2';
  
  // Cache configuration
  static const Duration _serverCacheExpiry = Duration(hours: 2);
  static const Duration _pingCacheExpiry = Duration(minutes: 30);
  static const Duration _healthCacheExpiry = Duration(hours: 1);

  /// Cache server list with metadata
  Future<void> cacheServers(List<String> servers, {
    Map<String, dynamic>? metadata,
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
      
      print('✅ Cached ${servers.length} servers with timestamp $timestamp');
    } catch (e) {
      print('❌ Failed to cache servers: $e');
    }
  }

  /// Get cached servers
  Future<List<String>> getCachedServers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_serverListKey) ?? [];
    } catch (e) {
      print('❌ Failed to get cached servers: $e');
      return [];
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

  /// Get cached ping results
  Future<Map<String, int>> getCachedPingResults() async {
    try {
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
      return pings.map((key, value) => MapEntry(key, value as int));
    } catch (e) {
      print('❌ Failed to get cached ping results: $e');
      return {};
    }
  }

  /// Cache server health data
  Future<void> cacheServerHealth(Map<String, Map<String, dynamic>> healthData) async {
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
      return health.map((key, value) => 
          MapEntry(key, Map<String, dynamic>.from(value)));
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
}
