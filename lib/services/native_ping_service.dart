import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';

/// Native ping service using Kotlin TCP and ICMP implementation
/// Replaces Flutter V2Ray for better performance and reliability
class NativePingService {
  static const MethodChannel _channel =
      MethodChannel('com.shythonx.shinenet_vpn/native_ping');

  static final NativePingService _instance = NativePingService._internal();
  factory NativePingService() => _instance;
  NativePingService._internal();

  /// Perform TCP ping to check server reachability
  /// Returns ping time in milliseconds, -1 for failure, -2 for timeout
  Future<int> tcpPing(String host,
      {int port = 80, int timeoutMs = 1000}) async {
    try {
      final result = await _channel.invokeMethod('tcpPing', {
        'host': host,
        'port': port,
        'timeout': timeoutMs,
      });
      return result as int;
    } on PlatformException catch (e) {
      print('❌ TCP ping error: ${e.message}');
      return -1;
    } catch (e) {
      print('❌ TCP ping error: $e');
      return -1;
    }
  }

  /// Perform ICMP ping using system ping command
  /// Returns average ping time in milliseconds, -1 for failure, -2 for timeout
  Future<int> icmpPing(String host,
      {int timeoutMs = 2000, int count = 1}) async {
    try {
      final result = await _channel.invokeMethod('icmpPing', {
        'host': host,
        'timeout': timeoutMs,
        'count': count,
      });
      return result as int;
    } on PlatformException catch (e) {
      print('❌ ICMP ping error: ${e.message}');
      return -1;
    } catch (e) {
      print('❌ ICMP ping error: $e');
      return -1;
    }
  }

  /// Perform concurrent TCP ping on multiple servers
  /// Returns Map of server to ping result
  Future<Map<String, int>> batchTcpPing(List<String> servers,
      {int timeoutMs = 1000}) async {
    try {
      final result = await _channel.invokeMethod('batchTcpPing', {
        'servers': servers,
        'timeout': timeoutMs,
      });

      // Parse JSON response
      final jsonResponse =
          json.decode(result as String) as Map<String, dynamic>;
      return jsonResponse.map((key, value) => MapEntry(key, value as int));
    } on PlatformException catch (e) {
      print('❌ Batch TCP ping error: ${e.message}');
      return {};
    } catch (e) {
      print('❌ Batch TCP ping error: $e');
      return {};
    }
  }

  /// Perform concurrent ICMP ping on multiple servers
  /// Returns Map of server to ping result
  Future<Map<String, int>> batchIcmpPing(List<String> servers,
      {int timeoutMs = 2000}) async {
    try {
      final result = await _channel.invokeMethod('batchIcmpPing', {
        'servers': servers,
        'timeout': timeoutMs,
      });

      // Parse JSON response
      final jsonResponse =
          json.decode(result as String) as Map<String, dynamic>;
      return jsonResponse.map((key, value) => MapEntry(key, value as int));
    } on PlatformException catch (e) {
      print('❌ Batch ICMP ping error: ${e.message}');
      return {};
    } catch (e) {
      print('❌ Batch ICMP ping error: $e');
      return {};
    }
  }

  /// Smart ping that tries TCP first, falls back to ICMP
  /// Returns NativePingResult with method indication
  Future<NativePingResult> smartPing(String host,
      {int port = 80, int timeoutMs = 1000}) async {
    try {
      final result = await _channel.invokeMethod('smartPing', {
        'host': host,
        'port': port,
        'timeout': timeoutMs,
      });

      // Parse JSON response
      final jsonResponse =
          json.decode(result as String) as Map<String, dynamic>;
      return NativePingResult(
        time: jsonResponse['time'] as int,
        method: jsonResponse['method'] as String,
        success: jsonResponse['success'] as bool,
      );
    } on PlatformException catch (e) {
      print('❌ Smart ping error: ${e.message}');
      return NativePingResult(time: -1, method: 'FAILED', success: false);
    } catch (e) {
      print('❌ Smart ping error: $e');
      return NativePingResult(time: -1, method: 'FAILED', success: false);
    }
  }

  /// Parse server configuration to extract host and port for TCP ping
  /// Supports multiple formats: URL-based, JSON-based, and host:port
  Future<int> pingServerConfig(String serverConfig,
      {int timeoutMs = 1000}) async {
    try {
      // Extract host and port from server configuration
      final hostPort = _extractHostPort(serverConfig);
      if (hostPort == null) {
        print('❌ Unable to extract host:port from server config');
        return -1;
      }

      // Perform TCP ping
      return await tcpPing(hostPort.host,
          port: hostPort.port, timeoutMs: timeoutMs);
    } catch (e) {
      print('❌ Server config ping error: $e');
      return -1;
    }
  }

  /// Batch ping server configurations
  /// Automatically extracts host:port from various server config formats
  Future<Map<String, int>> batchPingServerConfigs(List<String> serverConfigs,
      {int timeoutMs = 1000}) async {
    try {
      // Convert server configs to host:port format
      final hostPortList = <String>[];
      final configToHostPort = <String, String>{};

      for (final config in serverConfigs) {
        final hostPort = _extractHostPort(config);
        if (hostPort != null) {
          final hostPortString = '${hostPort.host}:${hostPort.port}';
          hostPortList.add(hostPortString);
          configToHostPort[hostPortString] = config;
        }
      }

      if (hostPortList.isEmpty) {
        print('❌ No valid server configurations found');
        return {};
      }

      // Perform batch TCP ping
      final results = await batchTcpPing(hostPortList, timeoutMs: timeoutMs);

      // Convert results back to original server config format
      final configResults = <String, int>{};
      results.forEach((hostPortString, ping) {
        final originalConfig = configToHostPort[hostPortString];
        if (originalConfig != null) {
          configResults[originalConfig] = ping;
        }
      });

      return configResults;
    } catch (e) {
      print('❌ Batch server config ping error: $e');
      return {};
    }
  }

  /// Extract host and port from various server configuration formats
  HostPort? _extractHostPort(String serverConfig) {
    try {
      // Handle empty config
      if (serverConfig.isEmpty) return null;

      print(
          '🚀 Testing server config type: ${serverConfig.trim().startsWith('{') ? 'JSON' : 'URL/Other'}');

      // Handle JSON format with comprehensive parsing
      if (serverConfig.trim().startsWith('{') &&
          serverConfig.trim().endsWith('}')) {
        try {
          final parsed = json.decode(serverConfig);
          print('📋 JSON structure keys: ${parsed.keys.toList()}');

          // First check for direct host/port at root level
          if (parsed['host'] != null && parsed['port'] != null) {
            final address = parsed['host'] as String?;
            final port = parsed['port'] as int?;
            if (address != null &&
                address.isNotEmpty &&
                port != null &&
                port > 0) {
              print('✅ Extracted from root host/port: $address:$port');
              return HostPort(address, port);
            }
          }

          // Check for address/port at root level
          if (parsed['address'] != null && parsed['port'] != null) {
            final address = parsed['address'] as String?;
            final port = parsed['port'] as int?;
            if (address != null &&
                address.isNotEmpty &&
                port != null &&
                port > 0) {
              print('✅ Extracted from root address/port: $address:$port');
              return HostPort(address, port);
            }
          }

          // Check outbounds array
          if (parsed['outbounds'] != null &&
              (parsed['outbounds'] as List).isNotEmpty) {
            final outbound = parsed['outbounds'][0];
            print('📋 Outbound keys: ${outbound.keys.toList()}');

            if (outbound['settings'] != null) {
              final settings = outbound['settings'];
              print('📋 Settings keys: ${settings.keys.toList()}');

              // Handle VMess/VLess configuration (vnext)
              if (settings['vnext'] != null &&
                  (settings['vnext'] as List).isNotEmpty) {
                final vnext = settings['vnext'][0];
                print('📋 Vnext keys: ${vnext.keys.toList()}');
                final address = vnext['address'] as String?;
                final port = vnext['port'] as int?;
                if (address != null &&
                    address.isNotEmpty &&
                    port != null &&
                    port > 0) {
                  print('✅ Extracted from vnext: $address:$port');
                  return HostPort(address, port);
                }
              }

              // Handle Shadowsocks configuration (servers)
              if (settings['servers'] != null &&
                  (settings['servers'] as List).isNotEmpty) {
                final server = settings['servers'][0];
                print('📋 Server keys: ${server.keys.toList()}');
                final address = server['address'] as String?;
                final port = server['port'] as int?;
                if (address != null &&
                    address.isNotEmpty &&
                    port != null &&
                    port > 0) {
                  print('✅ Extracted from servers: $address:$port');
                  return HostPort(address, port);
                }
              }

              // Handle Trojan configuration (direct address/port)
              if (settings['address'] != null && settings['port'] != null) {
                final address = settings['address'] as String?;
                final port = settings['port'] as int?;
                if (address != null &&
                    address.isNotEmpty &&
                    port != null &&
                    port > 0) {
                  print('✅ Extracted from direct settings: $address:$port');
                  return HostPort(address, port);
                }
              }
            }

            // Check if outbound has direct address/port (some configurations)
            if (outbound['address'] != null && outbound['port'] != null) {
              final address = outbound['address'] as String?;
              final port = outbound['port'] as int?;
              if (address != null &&
                  address.isNotEmpty &&
                  port != null &&
                  port > 0) {
                print('✅ Extracted from outbound direct: $address:$port');
                return HostPort(address, port);
              }
            }
          }

          print('❌ Unable to extract host:port from server config');
          return null;
        } catch (e) {
          print('❌ JSON parsing error: $e');
          return null;
        }
      }

      // Handle URL format (vmess://, vless://, etc.)
      if (serverConfig.contains('://')) {
        try {
          // Use Flutter V2Ray to parse URL-based configurations
          // This is a simplified approach - in production you'd implement full URL parsing
          final uri = Uri.parse(serverConfig);
          if (uri.host.isNotEmpty && uri.port > 0) {
            print('✅ Extracted from URL: ${uri.host}:${uri.port}');
            return HostPort(uri.host, uri.port);
          }
        } catch (e) {
          print('❌ URL parsing failed: $e');
          // URL parsing failed, continue to other methods
        }
      }

      // Handle host:port format
      if (serverConfig.contains(':')) {
        final parts = serverConfig.split(':');
        if (parts.length >= 2) {
          final host = parts[0].trim();
          final port = int.tryParse(parts[1].trim());
          if (host.isNotEmpty && port != null && port > 0 && port <= 65535) {
            print('✅ Extracted from host:port: $host:$port');
            return HostPort(host, port);
          }
        }
      }

      // Handle plain host (use default port 443 for HTTPS)
      if (!serverConfig.contains(':') && serverConfig.trim().isNotEmpty) {
        print('✅ Using default port for host: ${serverConfig.trim()}:443');
        return HostPort(serverConfig.trim(), 443);
      }

      print('❌ No valid host:port found in config');
      return null;
    } catch (e) {
      print('❌ Error extracting host:port: $e');
      return null;
    }
  }
}

/// Data class for ping results
class NativePingResult {
  final int time;
  final String method;
  final bool success;

  NativePingResult({
    required this.time,
    required this.method,
    required this.success,
  });

  @override
  String toString() {
    return 'NativePingResult(time: $time, method: $method, success: $success)';
  }
}

/// Data class for host and port
class HostPort {
  final String host;
  final int port;

  HostPort(this.host, this.port);

  @override
  String toString() => '$host:$port';
}
