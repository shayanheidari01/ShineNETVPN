import 'dart:convert';
import 'package:dio/dio.dart';

/// Utility class to parse server location information from server configurations
class ServerLocationParser {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: Duration(seconds: 5),
    receiveTimeout: Duration(seconds: 5),
    headers: {
      'User-Agent': 'ShineNETVPN/1.0',
    },
  ));
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
        final vmessData = _parseVmessLocation(serverConfig, location);
        remarksLocation = vmessData;
        hostAddress = _extractVmessHost(serverConfig);
      } else if (serverConfig.startsWith('vless://')) {
        final vlessData = _parseVlessLocation(serverConfig, location);
        remarksLocation = vlessData;
        hostAddress = _extractVlessHost(serverConfig);
      } else if (serverConfig.startsWith('trojan://')) {
        final trojanData = _parseTrojanLocation(serverConfig, location);
        remarksLocation = trojanData;
        hostAddress = _extractTrojanHost(serverConfig);
      } else if (serverConfig.startsWith('ss://')) {
        final ssData = _parseShadowsocksLocation(serverConfig, location);
        remarksLocation = ssData;
        hostAddress = _extractShadowsocksHost(serverConfig);
      }

      // Try to get location from API first (most accurate)
      if (hostAddress != null && hostAddress.isNotEmpty) {
        final apiLocation = await _getLocationFromAPI(hostAddress);
        if (apiLocation['country']?.isNotEmpty == true) {
          return apiLocation;
        }
        
        // Fallback to domain-based detection
        final domainLocation = _extractLocationFromDomain(hostAddress);
        if (domainLocation['country']?.isNotEmpty == true) {
          return domainLocation;
        }
      }

      // Fallback to remarks-based location
      if (remarksLocation['country']?.isNotEmpty == true) {
        return remarksLocation;
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

  /// Check if string is an IP address
  static bool _isIPAddress(String host) {
    final ipv4Pattern = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    final ipv6Pattern = RegExp(r'^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$');
    return ipv4Pattern.hasMatch(host) || ipv6Pattern.hasMatch(host);
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

  /// Get accurate location from free IP geolocation API
  static Future<Map<String, String>> _getLocationFromAPI(String hostAddress) async {
    Map<String, String> location = {
      'country': '',
      'countryCode': '',
      'city': '',
      'region': '',
      'flag': '🏳️',
    };

    try {
      // Skip if not an IP address
      if (!_isIPAddress(hostAddress)) {
        return location;
      }

      // Use ip-api.com - completely free, no API key required
      final response = await _dio.get(
        'http://ip-api.com/json/$hostAddress',
        queryParameters: {
          'fields': 'status,country,countryCode,region,regionName,city,zip,lat,lon,timezone,isp,org,as,query',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data['status'] == 'success') {
          location['country'] = data['country'] ?? '';
          location['countryCode'] = data['countryCode'] ?? '';
          location['city'] = data['city'] ?? '';
          location['region'] = data['regionName'] ?? data['region'] ?? '';
          location['zip'] = data['zip'] ?? '';
          location['isp'] = data['isp'] ?? '';
          location['org'] = data['org'] ?? '';
          location['as'] = data['as'] ?? '';
          location['timezone'] = data['timezone'] ?? '';
          location['lat'] = data['lat']?.toString() ?? '';
          location['lon'] = data['lon']?.toString() ?? '';
          location['query'] = data['query'] ?? hostAddress;
          
          // Generate flag emoji from country code
          if (location['countryCode']?.isNotEmpty == true) {
            location['flag'] = getFlagEmoji(location['countryCode']!);
          }
          
          // Create detailed location string
          location['detailedLocation'] = _formatDetailedLocation(location);
          
          print('API Location for $hostAddress: ${location['detailedLocation']} (${location['isp']})');
          return location;
        }
      }
    } catch (e) {
      print('Error getting location from API for $hostAddress: $e');
      
      // Try alternative free API as fallback
      try {
        final response = await _dio.get('https://ipapi.co/$hostAddress/json/');
        
        if (response.statusCode == 200) {
          final data = response.data;
          
          if (data['error'] != true) {
            location['country'] = data['country_name'] ?? '';
            location['countryCode'] = data['country_code'] ?? '';
            location['city'] = data['city'] ?? '';
            location['region'] = data['region'] ?? '';
            location['isp'] = data['org'] ?? '';
            location['timezone'] = data['timezone'] ?? '';
            location['lat'] = data['latitude']?.toString() ?? '';
            location['lon'] = data['longitude']?.toString() ?? '';
            
            if (location['countryCode']?.isNotEmpty == true) {
              location['flag'] = getFlagEmoji(location['countryCode']!);
            }
            
            // Create detailed location string
            location['detailedLocation'] = _formatDetailedLocation(location);
            
            print('Fallback API Location for $hostAddress: ${location['detailedLocation']}');
            return location;
          }
        }
      } catch (e2) {
        print('Fallback API also failed for $hostAddress: $e2');
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
}
