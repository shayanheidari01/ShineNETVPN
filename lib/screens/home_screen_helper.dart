import 'dart:async';
import 'package:flutter_v2ray/flutter_v2ray.dart';

/// Helper method to find and test the best server from a list
Future<String?> findAndTestBestServer(List<String> servers) async {
  if (servers.isEmpty) return null;
  
  final testResults = <Map<String, dynamic>>[];
  
  // Test servers in parallel for faster results
  final futures = servers.take(3).map((server) async {
    try {
      final v2rayURL = FlutterV2ray.parseFromURL(server);
      final config = v2rayURL.getFullConfiguration();
      
      if (config.isEmpty) return null;
      
      // Quick ping test with short timeout
      final flutterV2ray = FlutterV2ray(onStatusChanged: (status) {});
      final delay = await flutterV2ray
          .getServerDelay(config: config)
          .timeout(Duration(seconds: 3));
      
      if (delay > 0 && delay < 3000) {
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
  
  final results = await Future.wait(futures);
  
  // Filter out null results and sort by score
  final validResults = results
      .where((result) => result != null)
      .cast<Map<String, dynamic>>()
      .toList();
  
  if (validResults.isEmpty) return null;
  
  // Sort by score (higher is better)
  validResults.sort((a, b) => b['score'].compareTo(a['score']));
  
  return validResults.first['config'] as String;
}

/// Calculate server score based on delay and other factors
double _calculateServerScore(int delay) {
  if (delay <= 0) return 0.0;
  
  // Base score from delay (lower delay = higher score)
  double score = 1000.0 / delay;
  
  // Bonus for very fast servers
  if (delay < 100) {
    score *= 1.5;
  } else if (delay < 200) {
    score *= 1.2;
  }
  
  // Penalty for slow servers
  if (delay > 1000) {
    score *= 0.5;
  }
  
  return score;
}
