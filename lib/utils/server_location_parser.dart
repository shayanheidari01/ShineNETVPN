import 'dart:convert';

/// Utility class to parse server location information from server configurations
class ServerLocationParser {
  // Performance optimization: Pre-compiled regex patterns
  static final RegExp _ipv4Pattern = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
  static final RegExp _ipv6Pattern = RegExp(r'^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$');
  
  /// Extract location information from server configuration
  static Future<Map<String, String>> parseServerLocation(String serverConfig) async {
    try {
      // Default values
      Map<String, String> location = {
        'country': '',
        'countryCode': '',
        'city': '',
        'region': '',
        'flag': '🏳️',
      };

      String? hostAddress;
      Map<String, String> remarksLocation = {};

      if (serverConfig.startsWith('vmess://')) {
        remarksLocation = _parseVmessLocation(serverConfig, location);
        hostAddress = _extractVmessHost(serverConfig);
      } else if (serverConfig.startsWith('vless://')) {
        remarksLocation = _parseVlessLocation(serverConfig, location);
        hostAddress = _extractVlessHost(serverConfig);
      } else if (serverConfig.startsWith('trojan://')) {
        remarksLocation = _parseTrojanLocation(serverConfig, location);
        hostAddress = _extractTrojanHost(serverConfig);
      } else if (serverConfig.startsWith('ss://')) {
        remarksLocation = _parseShadowsocksLocation(serverConfig, location);
        hostAddress = _extractShadowsocksHost(serverConfig);
      }

      Map<String, String> finalLocation = Map<String, String>.from(location);

      if (hostAddress != null && hostAddress.isNotEmpty) {
        final domainLocation = _extractLocationFromDomain(hostAddress);
        if (domainLocation['country']?.isNotEmpty == true ||
            domainLocation['city']?.isNotEmpty == true) {
          finalLocation = _mergeLocationData(domainLocation, finalLocation);
        }
      }

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
  static Map<String, String> _parseVmessLocation(String config, Map<String, String> location) {
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
  static Map<String, String> _parseVlessLocation(String config, Map<String, String> location) {
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
  static Map<String, String> _parseTrojanLocation(String config, Map<String, String> location) {
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
  static Map<String, String> _parseShadowsocksLocation(String config, Map<String, String> location) {
    try {
      final uri = Uri.parse(config);
      // Fragment parsing removed - method removed
      return location;
    } catch (e) {
      print('Error parsing Shadowsocks config: $e');
      return location;
    }
  }


  /// Get country name from country code
  static String getCountryName(String countryCode) {
    final countryNames = {
      'US': 'United States',
      'DE': 'Germany',
      'GB': 'United Kingdom',
      'FR': 'France',
      'JP': 'Japan',
      'SG': 'Singapore',
      'CA': 'Canada',
      'AU': 'Australia',
      'NL': 'Netherlands',
      'HK': 'Hong Kong',
      'TW': 'Taiwan',
      'KR': 'South Korea',
      'IN': 'India',
      'BR': 'Brazil',
      'RU': 'Russia',
      'TR': 'Turkey',
      'IR': 'Iran',
      'CN': 'China',
    };
    
    return countryNames[countryCode.toUpperCase()] ?? countryCode;
  }

  /// Get flag emoji from country code
  static String getFlagEmoji(String countryCode) {
    if (countryCode.length != 2) return '🏳️';
    
    try {
      final flag = countryCode.toUpperCase().codeUnits
          .map((codeUnit) => String.fromCharCode(0x1F1E6 + codeUnit - 0x41))
          .join();
      return flag;
    } catch (e) {
      return '🏳️';
    }
  }

  /// Extract host address from VMess configuration
  static String? _extractVmessHost(String config) {
    try {
      final base64Data = config.substring(8); // Remove 'vmess://'
      final jsonString = utf8.decode(base64.decode(base64Data));
      final data = json.decode(jsonString);
      return data['add'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Extract host address from VLess configuration
  static String? _extractVlessHost(String config) {
    try {
      final uri = Uri.parse(config);
      return uri.host;
    } catch (e) {
      return null;
    }
  }

  /// Extract host address from Trojan configuration
  static String? _extractTrojanHost(String config) {
    try {
      final uri = Uri.parse(config);
      return uri.host;
    } catch (e) {
      return null;
    }
  }

  /// Extract host address from Shadowsocks configuration
  static String? _extractShadowsocksHost(String config) {
    try {
      final uri = Uri.parse(config);
      return uri.host;
    } catch (e) {
      return null;
    }
  }

  /// Extract location information from domain name or IP address
  static Map<String, String> _extractLocationFromDomain(String hostAddress) {
    Map<String, String> location = {
      'country': '',
      'countryCode': '',
      'city': '',
      'region': '',
      'flag': '🏳️',
    };

    final host = hostAddress.toLowerCase();

    // Domain-based location patterns
    final domainPatterns = {
      // Country-specific domains
      '.us': {'country': 'United States', 'code': 'US', 'flag': '🇺🇸'},
      '.de': {'country': 'Germany', 'code': 'DE', 'flag': '🇩🇪'},
      '.uk': {'country': 'United Kingdom', 'code': 'GB', 'flag': '🇬🇧'},
      '.fr': {'country': 'France', 'code': 'FR', 'flag': '🇫🇷'},
      '.jp': {'country': 'Japan', 'code': 'JP', 'flag': '🇯🇵'},
      '.sg': {'country': 'Singapore', 'code': 'SG', 'flag': '🇸🇬'},
      '.ca': {'country': 'Canada', 'code': 'CA', 'flag': '🇨🇦'},
      '.au': {'country': 'Australia', 'code': 'AU', 'flag': '🇦🇺'},
      '.nl': {'country': 'Netherlands', 'code': 'NL', 'flag': '🇳🇱'},
      '.hk': {'country': 'Hong Kong', 'code': 'HK', 'flag': '🇭🇰'},
      '.tw': {'country': 'Taiwan', 'code': 'TW', 'flag': '🇹🇼'},
      '.kr': {'country': 'South Korea', 'code': 'KR', 'flag': '🇰🇷'},
      '.in': {'country': 'India', 'code': 'IN', 'flag': '🇮🇳'},
      '.br': {'country': 'Brazil', 'code': 'BR', 'flag': '🇧🇷'},
      '.ru': {'country': 'Russia', 'code': 'RU', 'flag': '🇷🇺'},
      '.tr': {'country': 'Turkey', 'code': 'TR', 'flag': '🇹🇷'},
      '.ir': {'country': 'Iran', 'code': 'IR', 'flag': '🇮🇷'},
      '.cn': {'country': 'China', 'code': 'CN', 'flag': '🇨🇳'},
      
      // City/region patterns in domain names
      'nyc': {'country': 'United States', 'code': 'US', 'flag': '🇺🇸', 'city': 'New York'},
      'ny': {'country': 'United States', 'code': 'US', 'flag': '🇺🇸', 'city': 'New York'},
      'la': {'country': 'United States', 'code': 'US', 'flag': '🇺🇸', 'city': 'Los Angeles'},
      'miami': {'country': 'United States', 'code': 'US', 'flag': '🇺🇸', 'city': 'Miami'},
      'chicago': {'country': 'United States', 'code': 'US', 'flag': '🇺🇸', 'city': 'Chicago'},
      'london': {'country': 'United Kingdom', 'code': 'GB', 'flag': '🇬🇧', 'city': 'London'},
      'paris': {'country': 'France', 'code': 'FR', 'flag': '🇫🇷', 'city': 'Paris'},
      'berlin': {'country': 'Germany', 'code': 'DE', 'flag': '🇩🇪', 'city': 'Berlin'},
      'frankfurt': {'country': 'Germany', 'code': 'DE', 'flag': '🇩🇪', 'city': 'Frankfurt'},
      'tokyo': {'country': 'Japan', 'code': 'JP', 'flag': '🇯🇵', 'city': 'Tokyo'},
      'seoul': {'country': 'South Korea', 'code': 'KR', 'flag': '🇰🇷', 'city': 'Seoul'},
      'sydney': {'country': 'Australia', 'code': 'AU', 'flag': '🇦🇺', 'city': 'Sydney'},
      'toronto': {'country': 'Canada', 'code': 'CA', 'flag': '🇨🇦', 'city': 'Toronto'},
      'amsterdam': {'country': 'Netherlands', 'code': 'NL', 'flag': '🇳🇱', 'city': 'Amsterdam'},
      'mumbai': {'country': 'India', 'code': 'IN', 'flag': '🇮🇳', 'city': 'Mumbai'},
      'delhi': {'country': 'India', 'code': 'IN', 'flag': '🇮🇳', 'city': 'Delhi'},
      'moscow': {'country': 'Russia', 'code': 'RU', 'flag': '🇷🇺', 'city': 'Moscow'},
      'istanbul': {'country': 'Turkey', 'code': 'TR', 'flag': '🇹🇷', 'city': 'Istanbul'},
      'tehran': {'country': 'Iran', 'code': 'IR', 'flag': '🇮🇷', 'city': 'Tehran'},
      'shanghai': {'country': 'China', 'code': 'CN', 'flag': '🇨🇳', 'city': 'Shanghai'},
      'beijing': {'country': 'China', 'code': 'CN', 'flag': '🇨🇳', 'city': 'Beijing'},
    };

    // Check for city/region patterns first
    for (final entry in domainPatterns.entries) {
      if (host.contains(entry.key)) {
        location['country'] = entry.value['country'] ?? '';
        location['countryCode'] = entry.value['code'] ?? '';
        location['flag'] = entry.value['flag'] ?? '🏳️';
        if (entry.value.containsKey('city')) {
          location['city'] = entry.value['city'] ?? '';
        }
        return location;
      }
    }

    // IP-based location detection (basic patterns)
    if (_isIPAddress(host)) {
      final ipLocation = _getLocationFromIPRange(host);
      if (ipLocation['country']?.isNotEmpty == true) {
        return ipLocation;
      }
    }

    return location;
  }

  /// Check if string is an IP address (optimized with pre-compiled regex)
  static bool _isIPAddress(String host) {
    return _ipv4Pattern.hasMatch(host) || _ipv6Pattern.hasMatch(host);
  }

  /// Get location from IP address ranges (basic implementation)
  static Map<String, String> _getLocationFromIPRange(String ip) {
    Map<String, String> location = {
      'country': '',
      'countryCode': '',
      'city': '',
      'region': '',
      'flag': '🏳️',
    };

    // Basic IP range patterns for common cloud providers
    final ipRanges = {
      // Cloudflare ranges
      '104.21.': {'country': 'United States', 'code': 'US', 'flag': '🇺🇸'},
      '172.67.': {'country': 'United States', 'code': 'US', 'flag': '🇺🇸'},
      '104.16.': {'country': 'United States', 'code': 'US', 'flag': '🇺🇸'},
      
      // AWS ranges
      '52.': {'country': 'United States', 'code': 'US', 'flag': '🇺🇸'},
      '54.': {'country': 'United States', 'code': 'US', 'flag': '🇺🇸'},
      
      // Google Cloud ranges
      '35.': {'country': 'United States', 'code': 'US', 'flag': '🇺🇸'},
      '34.': {'country': 'United States', 'code': 'US', 'flag': '🇺🇸'},
      
      // European ranges
      '185.': {'country': 'Germany', 'code': 'DE', 'flag': '🇩🇪'},
      '46.': {'country': 'Germany', 'code': 'DE', 'flag': '🇩🇪'},
      
      // Asian ranges
      '103.': {'country': 'Singapore', 'code': 'SG', 'flag': '🇸🇬'},
      '202.': {'country': 'Japan', 'code': 'JP', 'flag': '🇯🇵'},
    };

    for (final entry in ipRanges.entries) {
      if (ip.startsWith(entry.key)) {
        location['country'] = entry.value['country'] ?? '';
        location['countryCode'] = entry.value['code'] ?? '';
        location['flag'] = entry.value['flag'] ?? '🏳️';
        return location;
      }
    }

    return location;
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
  static Map<String, String> getLocationDisplayInfo(Map<String, String> location) {
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
      if (!secondaryParts.any((part) => asInfo.toLowerCase().contains(part.toLowerCase()))) {
        secondaryParts.add(asInfo);
      }
    }
    
    displayInfo['secondary'] = secondaryParts.join(' • ');
    
    // Flag
    displayInfo['flag'] = location['flag'] ?? '🏳️';
    
    // Coordinates (for detailed view)
    if (location['lat']?.isNotEmpty == true && location['lon']?.isNotEmpty == true) {
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
      final batchFutures = batch.map((config) => 
        parseServerLocation(config).then((location) => 
          MapEntry(config, location)
        )
      );
      
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
