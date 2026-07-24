import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:developer' as developer;

class UpdateCheckerService {
  static const String _updateCheckUrl = 'https://raw.githubusercontent.com/shayanheidari01/shayanheidari01/refs/heads/main/shinenet_vpn.version';
  
  final Dio _dio = Dio();

  UpdateCheckerService() {
    _dio.options.connectTimeout = Duration(seconds: 10);
    _dio.options.receiveTimeout = Duration(seconds: 10);
    _dio.options.headers = {
      'accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
      'accept-encoding': 'gzip, deflate, br, zstd',
      'accept-language': 'en-US,en;q=0.9,fa-IR;q=0.8,fa;q=0.7',
      'cache-control': 'max-age=0',
      'priority': 'u=0, i',
      'sec-ch-ua': '"Not;A=Brand";v="8", "Chromium";v="150", "Google Chrome";v="150"',
      'sec-ch-ua-mobile': '?0',
      'sec-ch-ua-platform': '"Windows"',
      'sec-fetch-dest': 'document',
      'sec-fetch-mode': 'navigate',
      'sec-fetch-site': 'none',
      'sec-fetch-user': '?1',
      'upgrade-insecure-requests': '1',
      'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36',
    };
  }

  /// Check for app updates
  Future<UpdateInfo?> checkForUpdates() async {
    try {
      developer.log('🔍 Checking for app updates...', name: 'update_checker');
      
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      
      developer.log('📱 Current app version: $currentVersion', name: 'update_checker');
      
      // Fetch latest version from server
      final response = await _dio.get(_updateCheckUrl);
      
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch version info: ${response.statusCode}');
      }
      
      final versionData = json.decode(response.data);
      final latestVersion = versionData['version'] as String;
      final downloadLink = versionData['download_link'] as String;
      
      developer.log('🌐 Latest version from server: $latestVersion', name: 'update_checker');
      
      // Compare versions
      final needsUpdate = _compareVersions(currentVersion, latestVersion);
      
      if (needsUpdate) {
        developer.log('🆕 Update available: $currentVersion -> $latestVersion', name: 'update_checker');
        return UpdateInfo(
          currentVersion: currentVersion,
          latestVersion: latestVersion,
          downloadLink: downloadLink,
          needsUpdate: true,
        );
      } else {
        developer.log('✅ App is up to date', name: 'update_checker');
        return UpdateInfo(
          currentVersion: currentVersion,
          latestVersion: latestVersion,
          downloadLink: downloadLink,
          needsUpdate: false,
        );
      }
      
    } catch (e) {
      developer.log('❌ Error checking for updates: $e', name: 'update_checker');
      return null;
    }
  }
  
  /// Compare two version strings (returns true if update is needed)
  bool _compareVersions(String currentVersion, String latestVersion) {
    try {
      final current = _parseVersion(currentVersion);
      final latest = _parseVersion(latestVersion);
      
      // Compare major version
      if (latest[0] > current[0]) return true;
      if (latest[0] < current[0]) return false;
      
      // Compare minor version
      if (latest[1] > current[1]) return true;
      if (latest[1] < current[1]) return false;
      
      // Compare patch version
      if (latest[2] > current[2]) return true;
      
      return false; // Versions are equal or current is newer
    } catch (e) {
      developer.log('Error comparing versions: $e', name: 'update_checker');
      return false;
    }
  }
  
  /// Parse version string into [major, minor, patch]
  List<int> _parseVersion(String version) {
    final parts = version.split('.');
    return [
      int.parse(parts.length > 0 ? parts[0] : '0'),
      int.parse(parts.length > 1 ? parts[1] : '0'),
      int.parse(parts.length > 2 ? parts[2] : '0'),
    ];
  }
}

class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String downloadLink;
  final bool needsUpdate;
  
  UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadLink,
    required this.needsUpdate,
  });
  
  @override
  String toString() {
    return 'UpdateInfo(current: $currentVersion, latest: $latestVersion, needsUpdate: $needsUpdate)';
  }
}
