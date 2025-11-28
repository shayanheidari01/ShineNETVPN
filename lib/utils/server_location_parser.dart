import 'dart:convert';

/// Utility class to parse server location information from server configurations
class ServerLocationParser {
  /// Extract location information from server configuration
  static Future<Map<String, String>> parseServerLocation(
      String serverConfig) async {
    try {
      // Default values
      Map<String, String> location = {
        'country': '',
        'countryCode': '',
        'city': '',
        'region': '',
        'flag': '🏳️',
      };

      Map<String, String> remarksLocation = {};

      if (serverConfig.startsWith('vmess://')) {
        remarksLocation = _parseVmessLocation(serverConfig, location);
      } else if (serverConfig.startsWith('vless://')) {
        remarksLocation = _parseVlessLocation(serverConfig, location);
      } else if (serverConfig.startsWith('trojan://')) {
        remarksLocation = _parseTrojanLocation(serverConfig, location);
      } else if (serverConfig.startsWith('ss://')) {
        remarksLocation = _parseShadowsocksLocation(serverConfig, location);
      }

      Map<String, String> finalLocation = Map<String, String>.from(location);

      if (remarksLocation['country']?.isNotEmpty == true ||
          remarksLocation['city']?.isNotEmpty == true) {
        finalLocation = _mergeLocationData(remarksLocation, finalLocation);
      }

      if (finalLocation['countryCode']?.isNotEmpty == true &&
          (finalLocation['flag']?.isEmpty ?? true)) {
        finalLocation['flag'] = getFlagEmoji(finalLocation['countryCode']!);
      }

      return finalLocation;
    } catch (e) {
      print('Error parsing server location: $e');
      return {
        'country': 'Unknown',
        'countryCode': '',
        'city': '',
        'region': '',
        'flag': '🏳️',
      };
    }
  }

  /// Parse VMess server configuration
  static Map<String, String> _parseVmessLocation(
      String config, Map<String, String> location) {
    try {
      final base64Data = config.substring(8); // Remove 'vmess://'
      final jsonString = utf8.decode(base64.decode(base64Data));
      final data = json.decode(jsonString);

      // Extract location from 'ps' (remarks) field - method removed
      return location;
    } catch (e) {
      print('Error parsing VMess config: $e');
      return location;
    }
  }

  /// Parse VLess server configuration
  static Map<String, String> _parseVlessLocation(
      String config, Map<String, String> location) {
    try {
      final uri = Uri.parse(config);
      // Fragment parsing removed - method removed
      return location;
    } catch (e) {
      print('Error parsing VLess config: $e');
      return location;
    }
  }

  /// Parse Trojan server configuration
  static Map<String, String> _parseTrojanLocation(
      String config, Map<String, String> location) {
    try {
      final uri = Uri.parse(config);
      // Fragment parsing removed - method removed
      return location;
    } catch (e) {
      print('Error parsing Trojan config: $e');
      return location;
    }
  }

  /// Parse Shadowsocks server configuration
  static Map<String, String> _parseShadowsocksLocation(
      String config, Map<String, String> location) {
    try {
      final uri = Uri.parse(config);
      // Fragment parsing removed - method removed
      return location;
    } catch (e) {
      print('Error parsing Shadowsocks config: $e');
      return location;
    }
  }

  /// Get flag emoji from country code
  static String getFlagEmoji(String countryCode) {
    if (countryCode.length != 2) return '🏳️';

    try {
      final flag = countryCode
          .toUpperCase()
          .codeUnits
          .map((codeUnit) => String.fromCharCode(0x1F1E6 + codeUnit - 0x41))
          .join();
      return flag;
    } catch (e) {
      return '🏳️';
    }
  }

  /// Format detailed location string with comprehensive information
  static String _formatDetailedLocation(Map<String, String> location) {
    final parts = <String>[];

    // Add city if available
    if (location['city']?.isNotEmpty == true) {
      parts.add(location['city']!);
    }

    // Add region if available and different from city
    if (location['region']?.isNotEmpty == true &&
        location['region'] != location['city']) {
      parts.add(location['region']!);
    }

    // Add country
    if (location['country']?.isNotEmpty == true) {
      parts.add(location['country']!);
    }

    return parts.join(', ');
  }

  /// Get comprehensive location information for display
  static Map<String, String> getLocationDisplayInfo(
      Map<String, String> location) {
    final displayInfo = <String, String>{};

    // Primary location (city, region, country)
    displayInfo['primary'] = _formatDetailedLocation(location);

    // Secondary info (ISP/Organization with AS number)
    final secondaryParts = <String>[];
    if (location['isp']?.isNotEmpty == true) {
      secondaryParts.add(location['isp']!);
    } else if (location['org']?.isNotEmpty == true) {
      secondaryParts.add(location['org']!);
    }

    // Add AS information if available and different from ISP
    if (location['as']?.isNotEmpty == true) {
      final asInfo = location['as']!;
      if (!secondaryParts
          .any((part) => asInfo.toLowerCase().contains(part.toLowerCase()))) {
        secondaryParts.add(asInfo);
      }
    }

    displayInfo['secondary'] = secondaryParts.join(' • ');

    // Flag
    displayInfo['flag'] = location['flag'] ?? '🏳️';

    // Coordinates (for detailed view)
    if (location['lat']?.isNotEmpty == true &&
        location['lon']?.isNotEmpty == true) {
      displayInfo['coordinates'] = '${location['lat']}, ${location['lon']}';
    }

    // Timezone
    displayInfo['timezone'] = location['timezone'] ?? '';

    // ZIP code
    displayInfo['zip'] = location['zip'] ?? '';

    // Actual queried IP
    displayInfo['actualIP'] = location['query'] ?? '';

    return displayInfo;
  }

  /// Batch process multiple server locations for better performance
  static Future<Map<String, Map<String, String>>> batchParseLocations(
    List<String> serverConfigs, {
    int batchSize = 5,
    Duration delayBetweenBatches = const Duration(milliseconds: 500),
  }) async {
    final results = <String, Map<String, String>>{};

    for (int i = 0; i < serverConfigs.length; i += batchSize) {
      final batch = serverConfigs.skip(i).take(batchSize).toList();
      final batchFutures = batch.map((config) => parseServerLocation(config)
          .then((location) => MapEntry(config, location)));

      final batchResults = await Future.wait(batchFutures);
      for (final entry in batchResults) {
        results[entry.key] = entry.value;
      }
    }

    return results;
  }

  static Map<String, String> _mergeLocationData(
    Map<String, String> primary,
    Map<String, String> fallback,
  ) {
    final result = Map<String, String>.from(fallback);

    primary.forEach((key, value) {
      if (value.isNotEmpty) {
        result[key] = value;
      }
    });

    return result;
  }
}
