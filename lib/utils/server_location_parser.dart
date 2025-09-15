import 'dart:convert';

/// Utility class to parse server location information from server configurations
class ServerLocationParser {
  /// Extract location information from server configuration
  static Map<String, String> parseServerLocation(String serverConfig) {
    try {
      // Default values
      Map<String, String> location = {
        'country': '',
        'countryCode': '',
        'city': '',
        'region': '',
        'flag': '🏳️',
      };

      if (serverConfig.startsWith('vmess://')) {
        return _parseVmessLocation(serverConfig, location);
      } else if (serverConfig.startsWith('vless://')) {
        return _parseVlessLocation(serverConfig, location);
      } else if (serverConfig.startsWith('trojan://')) {
        return _parseTrojanLocation(serverConfig, location);
      } else if (serverConfig.startsWith('ss://')) {
        return _parseShadowsocksLocation(serverConfig, location);
      }

      return location;
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

      // Extract location from 'ps' (remarks) field
      final remarks = data['ps'] as String? ?? '';
      return _extractLocationFromRemarks(remarks, location);
    } catch (e) {
      print('Error parsing VMess config: $e');
      return location;
    }
  }

  /// Parse VLess server configuration
  static Map<String, String> _parseVlessLocation(String config, Map<String, String> location) {
    try {
      final uri = Uri.parse(config);
      final fragment = uri.fragment; // This usually contains the server name/location
      return _extractLocationFromRemarks(fragment, location);
    } catch (e) {
      print('Error parsing VLess config: $e');
      return location;
    }
  }

  /// Parse Trojan server configuration
  static Map<String, String> _parseTrojanLocation(String config, Map<String, String> location) {
    try {
      final uri = Uri.parse(config);
      final fragment = uri.fragment; // This usually contains the server name/location
      return _extractLocationFromRemarks(fragment, location);
    } catch (e) {
      print('Error parsing Trojan config: $e');
      return location;
    }
  }

  /// Parse Shadowsocks server configuration
  static Map<String, String> _parseShadowsocksLocation(String config, Map<String, String> location) {
    try {
      final uri = Uri.parse(config);
      final fragment = uri.fragment; // This usually contains the server name/location
      return _extractLocationFromRemarks(fragment, location);
    } catch (e) {
      print('Error parsing Shadowsocks config: $e');
      return location;
    }
  }

  /// Extract location information from server remarks/name
  static Map<String, String> _extractLocationFromRemarks(String remarks, Map<String, String> location) {
    if (remarks.isEmpty) return location;

    // Common location patterns in server names
    final locationPatterns = {
      // Countries with codes
      'United States': {'code': 'US', 'flag': '🇺🇸'},
      'USA': {'code': 'US', 'flag': '🇺🇸'},
      'US': {'code': 'US', 'flag': '🇺🇸'},
      'Germany': {'code': 'DE', 'flag': '🇩🇪'},
      'DE': {'code': 'DE', 'flag': '🇩🇪'},
      'United Kingdom': {'code': 'GB', 'flag': '🇬🇧'},
      'UK': {'code': 'GB', 'flag': '🇬🇧'},
      'GB': {'code': 'GB', 'flag': '🇬🇧'},
      'France': {'code': 'FR', 'flag': '🇫🇷'},
      'FR': {'code': 'FR', 'flag': '🇫🇷'},
      'Japan': {'code': 'JP', 'flag': '🇯🇵'},
      'JP': {'code': 'JP', 'flag': '🇯🇵'},
      'Singapore': {'code': 'SG', 'flag': '🇸🇬'},
      'SG': {'code': 'SG', 'flag': '🇸🇬'},
      'Canada': {'code': 'CA', 'flag': '🇨🇦'},
      'CA': {'code': 'CA', 'flag': '🇨🇦'},
      'Australia': {'code': 'AU', 'flag': '🇦🇺'},
      'AU': {'code': 'AU', 'flag': '🇦🇺'},
      'Netherlands': {'code': 'NL', 'flag': '🇳🇱'},
      'NL': {'code': 'NL', 'flag': '🇳🇱'},
      'Hong Kong': {'code': 'HK', 'flag': '🇭🇰'},
      'HK': {'code': 'HK', 'flag': '🇭🇰'},
      'Taiwan': {'code': 'TW', 'flag': '🇹🇼'},
      'TW': {'code': 'TW', 'flag': '🇹🇼'},
      'South Korea': {'code': 'KR', 'flag': '🇰🇷'},
      'Korea': {'code': 'KR', 'flag': '🇰🇷'},
      'KR': {'code': 'KR', 'flag': '🇰🇷'},
      'India': {'code': 'IN', 'flag': '🇮🇳'},
      'IN': {'code': 'IN', 'flag': '🇮🇳'},
      'Brazil': {'code': 'BR', 'flag': '🇧🇷'},
      'BR': {'code': 'BR', 'flag': '🇧🇷'},
      'Russia': {'code': 'RU', 'flag': '🇷🇺'},
      'RU': {'code': 'RU', 'flag': '🇷🇺'},
      'Turkey': {'code': 'TR', 'flag': '🇹🇷'},
      'TR': {'code': 'TR', 'flag': '🇹🇷'},
      'Iran': {'code': 'IR', 'flag': '🇮🇷'},
      'IR': {'code': 'IR', 'flag': '🇮🇷'},
      'China': {'code': 'CN', 'flag': '🇨🇳'},
      'CN': {'code': 'CN', 'flag': '🇨🇳'},
    };

    // Cities mapping
    final cityPatterns = {
      'New York': {'country': 'United States', 'code': 'US', 'flag': '🇺🇸'},
      'NYC': {'country': 'United States', 'code': 'US', 'flag': '🇺🇸'},
      'Los Angeles': {'country': 'United States', 'code': 'US', 'flag': '🇺🇸'},
      'LA': {'country': 'United States', 'code': 'US', 'flag': '🇺🇸'},
      'Chicago': {'country': 'United States', 'code': 'US', 'flag': '🇺🇸'},
      'Miami': {'country': 'United States', 'code': 'US', 'flag': '🇺🇸'},
      'London': {'country': 'United Kingdom', 'code': 'GB', 'flag': '🇬🇧'},
      'Paris': {'country': 'France', 'code': 'FR', 'flag': '🇫🇷'},
      'Berlin': {'country': 'Germany', 'code': 'DE', 'flag': '🇩🇪'},
      'Frankfurt': {'country': 'Germany', 'code': 'DE', 'flag': '🇩🇪'},
      'Tokyo': {'country': 'Japan', 'code': 'JP', 'flag': '🇯🇵'},
      'Seoul': {'country': 'South Korea', 'code': 'KR', 'flag': '🇰🇷'},
      'Sydney': {'country': 'Australia', 'code': 'AU', 'flag': '🇦🇺'},
      'Toronto': {'country': 'Canada', 'code': 'CA', 'flag': '🇨🇦'},
      'Amsterdam': {'country': 'Netherlands', 'code': 'NL', 'flag': '🇳🇱'},
      'Mumbai': {'country': 'India', 'code': 'IN', 'flag': '🇮🇳'},
      'Delhi': {'country': 'India', 'code': 'IN', 'flag': '🇮🇳'},
      'São Paulo': {'country': 'Brazil', 'code': 'BR', 'flag': '🇧🇷'},
      'Moscow': {'country': 'Russia', 'code': 'RU', 'flag': '🇷🇺'},
      'Istanbul': {'country': 'Turkey', 'code': 'TR', 'flag': '🇹🇷'},
      'Tehran': {'country': 'Iran', 'code': 'IR', 'flag': '🇮🇷'},
      'Shanghai': {'country': 'China', 'code': 'CN', 'flag': '🇨🇳'},
      'Beijing': {'country': 'China', 'code': 'CN', 'flag': '🇨🇳'},
    };

    final remarksUpper = remarks.toUpperCase();
    
    // First check for cities
    for (final entry in cityPatterns.entries) {
      if (remarksUpper.contains(entry.key.toUpperCase())) {
        location['city'] = entry.key;
        location['country'] = entry.value['country'] ?? '';
        location['countryCode'] = entry.value['code'] ?? '';
        location['flag'] = entry.value['flag'] ?? '🏳️';
        return location;
      }
    }

    // Then check for countries
    for (final entry in locationPatterns.entries) {
      if (remarksUpper.contains(entry.key.toUpperCase())) {
        location['country'] = entry.key == 'US' || entry.key == 'USA' ? 'United States' : entry.key;
        location['countryCode'] = entry.value['code'] ?? '';
        location['flag'] = entry.value['flag'] ?? '🏳️';
        break;
      }
    }

    // Extract additional info from remarks
    if (location['country']?.isEmpty == true) {
      // Try to extract from common patterns like "Country-City" or "City, Country"
      final parts = remarks.split(RegExp(r'[-,\s]+'));
      for (final part in parts) {
        final partUpper = part.trim().toUpperCase();
        if (locationPatterns.containsKey(partUpper)) {
          final info = locationPatterns[partUpper]!;
          location['country'] = partUpper == 'US' || partUpper == 'USA' ? 'United States' : partUpper;
          location['countryCode'] = info['code'] ?? '';
          location['flag'] = info['flag'] ?? '🏳️';
          break;
        }
      }
    }

    return location;
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
}
