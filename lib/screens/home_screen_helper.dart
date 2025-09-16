import 'dart:async';
import 'package:flutter_v2ray/flutter_v2ray.dart';

/// Helper method to find and test the best server from a list with improved performance
Future<String?> findAndTestBestServer(List<String> servers) async {
  if (servers.isEmpty) return null;
  
  // Increase the number of servers tested in parallel for better selection
  final serversToTest = servers.take(8).toList();
  final testResults = <Map<String, dynamic>>[];
  
  // Create batches to avoid overwhelming the system
  final batchSize = 4;
  final batches = <List<String>>[];
  for (int i = 0; i < serversToTest.length; i += batchSize) {
    final end = (i + batchSize < serversToTest.length) ? i + batchSize : serversToTest.length;
    batches.add(serversToTest.sublist(i, end));
  }
  
  // Process batches sequentially for better resource management
  for (final batch in batches) {
    final futures = batch.map((server) async {
      try {
        final v2rayURL = FlutterV2ray.parseFromURL(server);
        final config = v2rayURL.getFullConfiguration();
        
        if (config.isEmpty) return null;
        
        // Quick ping test with optimized timeout
        final flutterV2ray = FlutterV2ray(onStatusChanged: (status) {});
        final delay = await flutterV2ray
            .getServerDelay(config: config)
            .timeout(Duration(seconds: 2)); // Reduced timeout for faster testing
        
        if (delay > 0 && delay < 2500) { // Slightly stricter delay threshold
          return {
            'server': server,
            'config': config,
            'delay': delay,
            'score': _calculateServerScore(delay),
          };
        }
      } catch (e) {
        print('Server test failed: $e');
      }
      return null;
    });
    
    final batchResults = await Future.wait(futures);
    testResults.addAll(batchResults.where((result) => result != null).cast<Map<String, dynamic>>());
    
    // Small delay between batches to prevent resource exhaustion
    if (batches.indexOf(batch) < batches.length - 1) {
      await Future.delayed(Duration(milliseconds: 50));
    }
  }
  
  if (testResults.isEmpty) return null;
  
  // Sort by score (higher is better) and return the best
  testResults.sort((a, b) => b['score'].compareTo(a['score']));
  
  return testResults.first['config'] as String;
}

/// Calculate server score based on delay and other factors with enhanced algorithm
double _calculateServerScore(int delay) {
  if (delay <= 0) return 0.0;
  
  // Enhanced scoring algorithm for better server selection
  double score = 0.0;
  
  // Tiered scoring based on delay ranges for more precise selection
  if (delay < 50) {
    score = 100.0; // Excellent servers
  } else if (delay < 100) {
    score = 90.0 - (delay - 50) * 0.4; // Very good servers
  } else if (delay < 200) {
    score = 70.0 - (delay - 100) * 0.3; // Good servers
  } else if (delay < 500) {
    score = 40.0 - (delay - 200) * 0.1; // Acceptable servers
  } else if (delay < 1000) {
    score = 20.0 - (delay - 500) * 0.02; // Slow servers
  } else if (delay < 2000) {
    score = 10.0 - (delay - 1000) * 0.005; // Very slow servers
  } else {
    score = 5.0; // Extremely slow servers
  }
  
  // Additional bonus for ultra-fast servers
  if (delay < 30) {
    score += 20.0;
  }
  
  // Ensure score is never negative
  return score.clamp(0.0, 120.0);
}
