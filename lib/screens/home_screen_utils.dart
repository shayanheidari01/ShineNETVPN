import 'dart:convert';

/// Utility functions for home screen server processing
class HomeScreenUtils {
  
  /// Get flag emoji from country code
  static String? getFlagFromCountryCode(String? countryCode) {
    if (countryCode == null || countryCode.isEmpty) return '🏳️';
    
    final flags = {
      'US': '🇺🇸', 'UK': '🇬🇧', 'GB': '🇬🇧', 'DE': '🇩🇪', 'FR': '🇫🇷',
      'JP': '🇯🇵', 'SG': '🇸🇬', 'CA': '🇨🇦', 'AU': '🇦🇺', 'NL': '🇳🇱',
      'HK': '🇭🇰', 'TW': '🇹🇼', 'KR': '🇰🇷', 'IN': '🇮🇳', 'BR': '🇧🇷',
      'RU': '🇷🇺', 'TR': '🇹🇷', 'IR': '🇮🇷', 'CN': '🇨🇳', 'IT': '🇮🇹',
      'ES': '🇪🇸', 'SE': '🇸🇪', 'NO': '🇳🇴', 'FI': '🇫🇮', 'DK': '🇩🇰',
      'CH': '🇨🇭', 'AT': '🇦🇹', 'BE': '🇧🇪', 'PL': '🇵🇱', 'CZ': '🇨🇿',
      'HU': '🇭🇺', 'RO': '🇷🇴', 'BG': '🇧🇬', 'GR': '🇬🇷', 'PT': '🇵🇹',
      'IE': '🇮🇪', 'LU': '🇱🇺', 'MT': '🇲🇹', 'CY': '🇨🇾', 'LV': '🇱🇻',
      'LT': '🇱🇹', 'EE': '🇪🇪', 'SI': '🇸🇮', 'SK': '🇸🇰', 'HR': '🇭🇷',
      'MX': '🇲🇽', 'AR': '🇦🇷', 'CL': '🇨🇱', 'CO': '🇨🇴', 'PE': '🇵🇪',
      'VE': '🇻🇪', 'UY': '🇺🇾', 'PY': '🇵🇾', 'BO': '🇧🇴', 'EC': '🇪🇨',
      'ZA': '🇿🇦', 'EG': '🇪🇬', 'MA': '🇲🇦', 'NG': '🇳🇬', 'KE': '🇰🇪',
      'TH': '🇹🇭', 'VN': '🇻🇳', 'MY': '🇲🇾', 'ID': '🇮🇩', 'PH': '🇵🇭',
      'BD': '🇧🇩', 'PK': '🇵🇰', 'LK': '🇱🇰', 'MM': '🇲🇲', 'KH': '🇰🇭',
      'LA': '🇱🇦', 'NP': '🇳🇵', 'BT': '🇧🇹', 'MV': '🇲🇻', 'AF': '🇦🇫',
      'IQ': '🇮🇶', 'SY': '🇸🇾', 'LB': '🇱🇧', 'JO': '🇯🇴', 'IL': '🇮🇱',
      'PS': '🇵🇸', 'SA': '🇸🇦', 'AE': '🇦🇪', 'QA': '🇶🇦', 'KW': '🇰🇼',
      'BH': '🇧🇭', 'OM': '🇴🇲', 'YE': '🇾🇪', 'UZ': '🇺🇿', 'KZ': '🇰🇿',
      'KG': '🇰🇬', 'TJ': '🇹🇯', 'TM': '🇹🇲', 'AZ': '🇦🇿', 'AM': '🇦🇲',
      'GE': '🇬🇪', 'BY': '🇧🇾', 'UA': '🇺🇦', 'MD': '🇲🇩', 'RS': '🇷🇸',
      'ME': '🇲🇪', 'BA': '🇧🇦', 'MK': '🇲🇰', 'AL': '🇦🇱', 'XK': '🇽🇰',
    };
    
    return flags[countryCode.toUpperCase()] ?? '🏳️';
  }

  /// Extract IP address from server configuration
  static String extractIPFromConfig(String config) {
    try {
      if (config.startsWith('vmess://')) {
        final decoded = utf8.decode(base64.decode(config.substring(8)));
        final json = jsonDecode(decoded);
        return json['add'] ?? 'Unknown';
      } else if (config.startsWith('vless://') || config.startsWith('trojan://')) {
        final uri = Uri.parse(config);
        return uri.host;
      } else if (config.startsWith('ss://')) {
        final uri = Uri.parse(config);
        return uri.host;
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return 'Unknown';
  }

  /// Generate server name from configuration
  static String generateServerName(String config, String ip, int index) {
    try {
      if (config.startsWith('vmess://')) {
        final decoded = utf8.decode(base64.decode(config.substring(8)));
        final json = jsonDecode(decoded);
        final ps = json['ps'] as String?;
        if (ps != null && ps.isNotEmpty) {
          return ps;
        }
      }
    } catch (e) {
      // Ignore parsing errors
    }
    
    // Fallback to IP or generic name
    if (ip != 'Unknown') {
      return 'Server $index ($ip)';
    }
    return 'Server $index';
  }

  /// Get country code from IP (synchronous basic implementation)
  static String getCountryCodeFromIPSync(String ip) {
    // Basic IP range detection for common providers
    if (ip.startsWith('104.21.') || ip.startsWith('172.67.')) {
      return 'US'; // Cloudflare
    } else if (ip.startsWith('52.') || ip.startsWith('54.')) {
      return 'US'; // AWS
    } else if (ip.startsWith('35.') || ip.startsWith('34.')) {
      return 'US'; // Google Cloud
    }
    
    // Default fallback
    return 'US';
  }
}
