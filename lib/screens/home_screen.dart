import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shinenet_vpn/common/http_client.dart';
import 'package:shinenet_vpn/common/liquid_glass_container.dart';
import 'package:shinenet_vpn/common/theme.dart';

import 'package:shinenet_vpn/widgets/connection_widget.dart';
import 'package:shinenet_vpn/widgets/server_selection_modal_widget.dart';
import 'package:shinenet_vpn/widgets/ad_banner_widget.dart';
import 'package:shinenet_vpn/services/server_optimization_service.dart';
import 'package:shinenet_vpn/services/connection_optimization_service.dart';
import 'package:shinenet_vpn/services/server_cache_manager.dart';
import 'package:shinenet_vpn/services/intelligent_server_selector.dart';
import 'package:shinenet_vpn/utils/server_location_parser.dart';
import 'package:shinenet_vpn/screens/home_screen_helper.dart';
import 'package:shinenet_vpn/services/flutter_v2ray_client_manager.dart';
import 'package:shinenet_vpn/services/flutter_v2ray_ping_service.dart';
import 'package:shinenet_vpn/services/aether_client_manager.dart';
import 'package:shinenet_vpn/screens/scan_mode_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_v2ray_client/flutter_v2ray.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:easy_localization/easy_localization.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FlutterV2rayClientManager _v2rayManager = FlutterV2rayClientManager();
  final AetherClientManager _aetherManager = AetherClientManager();
  StreamSubscription<AetherState>? _aetherStateSub;
  ValueNotifier<V2RayStatus> get v2rayStatus => _v2rayManager.statusNotifier;

  /// Selected VPN core: 'aether' or 'v2ray'.
  String _selectedCore = 'aether';
  static const String _selectedCoreKey = 'selected_vpn_core';

  /// Whether the Aether native libs are physically present on this device.
  bool _aetherAvailable = false;
  AetherState _aetherState = AetherState.disconnected;
  String _aetherProtocol = 'masque';
  String _aetherScanMode = 'turbo';
  String _aetherTransport = 'h3';

  static const String _lastSuccessfulServerKey = 'last_successful_server';
  static const String _lastSuccessfulTimestampKey =
      'last_successful_server_time';
  static const Duration _fastReconnectValidity = Duration(minutes: 45);

  // Optimization services
  final ServerOptimizationService _serverService = ServerOptimizationService();
  final ConnectionOptimizationService _connectionService =
      ConnectionOptimizationService();
  final ServerCacheManager _cacheManager = ServerCacheManager();
  final IntelligentServerSelector _intelligentSelector =
      IntelligentServerSelector();

  // UI State
  bool isLoading = false;
  String loadingStatus = '';
  int serversBeingTested = 0;
  int serversTestCompleted = 0;

  // Individual server test results
  List<Map<String, dynamic>> serverTestResults = <Map<String, dynamic>>[];
  bool isTestingServers = false;

  // Server State
  String selectedServer = 'Automatic';
  String selectedServerType = 'Automatic'; // Changed from selectedServerLogo
  int? connectedServerDelay;
  bool isFetchingPing = false;
  bool _isFetchingIP = false;

  // Additional State
  bool proxyOnly = false;
  List<String> bypassSubnets = <String>[];
  String? coreVersion;
  String? versionName;
  late SharedPreferences _prefs;
  List<String> blockedApps = <String>[];

  // Server management - unified with ServerCacheManager
  List<String> cachedServers = <String>[];
  List<Map<String, dynamic>> processedServers = <Map<String, dynamic>>[];
  Map<String, int> serverPings =
      <String, int>{}; // Legacy ping results (deprecated)
  DateTime? lastServerFetch;
  String? _lastSuccessfulServer;
  DateTime? _lastSuccessfulServerTime;

  // Connection retry variables
  int connectionRetryCount = 0;
  static const int maxRetries = 5;
  static const Duration initialRetryDelay = Duration(seconds: 2);

  // Add server testing protection flag
  bool _isServerTestingInProgress = false;

  // Add a queue for server testing to prevent resource exhaustion
  final List<Map<String, dynamic>> _serverTestQueue = <Map<String, dynamic>>[];
  bool _isProcessingServerQueue = false;

  // Connection analytics
  int _totalConnectionAttempts = 0;
  int _successfulConnections = 0;
  int _failedConnections = 0;
  double _averageConnectionTime = 0.0;

  // User IP Information
  String? _userIP;
  int _ipRequestGeneration = 0;
  String? _userCountryFlag;
  String? _userCountryName;

  Future<void> _initializeServices() async {
    try {
      await _serverService.initialize();
      await _connectionService.initialize();
      await _intelligentSelector.initialize();
      await _loadConnectionAnalytics();
      await _initializeAether();

      // Background testing removed for optimization
    } catch (e) {
      print('Error initializing optimization services: $e');
      // Continue with original implementation if optimization services fail
    }
  }

  Future<void> _initializeAether() async {
    try {
      _aetherAvailable = await _aetherManager.checkNativeLibs();
      if (!_aetherAvailable) {
        print('Aether native libs not available — V2Ray path remains active');
      }

      await _loadSelectedCore();

      if (!_aetherAvailable) {
        // Force v2ray if native libs are missing, regardless of saved preference
        _selectedCore = 'v2ray';
      }

      if (_selectedCore != 'aether') return;

      await _aetherManager.syncState();
      await _loadAetherPreferences();

      _aetherStateSub?.cancel();
      _aetherStateSub = _aetherManager.stateStream.listen((state) {
        if (!mounted) return;
        setState(() {
          _aetherState = state;
          if (state == AetherState.connecting) {
            isLoading = true;
            loadingStatus = '';
          } else if (state == AetherState.connected) {
            isLoading = false;
            loadingStatus = '';
            if (_userIP == null && !_isFetchingIP) {
              _fetchUserIP();
            }
          } else if (state == AetherState.failed) {
            isLoading = false;
            loadingStatus = '';
          } else if (state == AetherState.disconnected) {
            isLoading = false;
            loadingStatus = '';
            _ipRequestGeneration++;
            _userIP = null;
            _userCountryFlag = null;
            _userCountryName = null;
          }
        });

        if (state == AetherState.failed) {
          _aetherManager.stop();
          _showAetherFailure();
        }
      });

      if (mounted) {
        setState(() {
          _aetherState = _aetherManager.currentState;
        });
      }
    } catch (e) {
      print('Aether init failed: $e');
      _aetherAvailable = false;
    }
  }

  Future<void> _loadAetherPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _aetherProtocol = prefs.getString('selected_aether_protocol') ?? 'masque';
      _aetherScanMode = prefs.getString('selected_aether_scan_mode') ?? 'turbo';
      _aetherTransport = prefs.getString('selected_aether_transport') ?? 'h3';
    });
  }

  Future<void> _loadSelectedCore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_selectedCoreKey) ?? '';
    if (saved == 'aether' || saved == 'v2ray') {
      _selectedCore = saved;
    } else {
      // Default: prefer aether if available, otherwise v2ray
      _selectedCore = _aetherAvailable ? 'aether' : 'v2ray';
    }
  }

  Future<void> _saveSelectedCore(String core) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedCoreKey, core);
  }

  Future<void> _showAetherFailure() async {
    final detail = await _aetherManager.getLastError();
    if (!mounted) return;
    final message = detail.isNotEmpty
        ? detail
        : 'aether_connection_failed'.tr();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: ThemeColor.errorColor,
          duration: const Duration(seconds: 5),
        ),
      );
  }

  bool get _isAetherConnected => _aetherState == AetherState.connected;
  bool get _isAetherConnecting => _aetherState == AetherState.connecting;

  /// Whether the Aether path is active (user chose Aether AND native libs exist).
  bool get _useAether => _selectedCore == 'aether' && _aetherAvailable;

  String _aetherProtocolLabel() {
    switch (_aetherProtocol) {
      case 'wireguard':
        return 'protocol_wireguard'.tr();
      case 'gool':
        return 'protocol_gool'.tr();
      default:
        return 'protocol_masque'.tr();
    }
  }

  String _aetherScanLabel() {
    switch (_aetherScanMode) {
      case 'balanced':
        return 'scan_balanced'.tr();
      case 'thorough':
        return 'scan_thorough'.tr();
      case 'stealth':
        return 'scan_stealth'.tr();
      default:
        return 'scan_turbo'.tr();
    }
  }

  Future<void> _saveLastSuccessfulServer(String serverConfig) async {
    try {
      final timestamp = DateTime.now();
      await _prefs.setString(_lastSuccessfulServerKey, serverConfig);
      await _prefs.setString(
          _lastSuccessfulTimestampKey, timestamp.toIso8601String());
      _lastSuccessfulServer = serverConfig;
      _lastSuccessfulServerTime = timestamp;
    } catch (e) {
      print('Failed to persist last successful server: $e');
    }
  }

  bool _isLastSuccessfulServerFresh() {
    if (_lastSuccessfulServer == null || _lastSuccessfulServer!.isEmpty) {
      return false;
    }
    if (_lastSuccessfulServerTime == null) {
      return true;
    }
    return DateTime.now().difference(_lastSuccessfulServerTime!) <=
        _fastReconnectValidity;
  }

  Future<bool> _tryReconnectUsingLastSuccessfulServer() async {
    if (!_isLastSuccessfulServerFresh()) {
      return false;
    }

    final server = _lastSuccessfulServer!;
    try {
      if (mounted) {
        setState(() {
          loadingStatus = '⚡️ Reconnecting to your fastest server...';
        });
      } else {
        loadingStatus = '⚡️ Reconnecting to your fastest server...';
      }

      print('⚡ Attempting fast reconnect with last successful server');
      await _connectToServer(server);
      return true;
    } catch (e) {
      print('Fast reconnect failed: $e');
      return false;
    }
  }

  Future<void> _fetchUserIP() async {
    if (_isFetchingIP) return;
    final requestGeneration = ++_ipRequestGeneration;

    if (mounted) {
      setState(() {
        _isFetchingIP = true;
      });
    } else {
      _isFetchingIP = true;
    }

    try {
      String? ipAddress;
      String? flagUrl;
      String? countryName;
      Object? lastError;

      // Use small, independent requests: the shared HTTP client has retry
      // interceptors intended for server lists and can delay this UI request.
      const endpoints = <String>[
        'https://api64.ipify.org?format=json',
        'https://api.ipify.org?format=json',
        'https://ifconfig.co/json',
        'https://ipwho.is/',
      ];
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
          responseType: ResponseType.json,
          followRedirects: true,
          maxRedirects: 2,
          validateStatus: (status) => status != null && status >= 200 && status < 300,
          headers: const {'accept': 'application/json,text/plain'},
        ),
      );

      for (final endpoint in endpoints) {
        try {
          final response = await dio.get(endpoint);
          final data = response.data;
          final candidate = data is Map
              ? (data['ip'] ?? data['ip_addr'] ?? data['address'])?.toString()
              : data?.toString().trim();
          if (candidate != null && _looksLikeIp(candidate)) {
            ipAddress = candidate;
            if (data is Map) {
              flagUrl = data['flag'] is Map
                  ? data['flag']['img']?.toString()
                  : data['flag']?.toString();
              countryName =
                  (data['country'] ?? data['country_name'])?.toString();
            }
            break;
          }
        } catch (error) {
          lastError = error;
        }
      }
      dio.close(force: true);

      if (ipAddress == null || ipAddress.isEmpty) {
        throw lastError ?? Exception('Empty IP response');
      }

      if (!mounted || requestGeneration != _ipRequestGeneration) return;

      setState(() {
        _userIP = ipAddress;
        _userCountryFlag = flagUrl;
        _userCountryName = countryName;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('ip_updated_successfully'.tr()),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
    } catch (error) {
      final readableError = _formatReadableError(error);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                'failed_to_fetch_ip'.tr(args: [readableError]),
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: ThemeColor.errorColor,
              duration: Duration(seconds: 4),
            ),
          );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingIP = false;
        });
      } else {
        _isFetchingIP = false;
      }
    }
  }

  bool _looksLikeIp(String value) {
    final normalized = value.trim();
    final ipv4 = RegExp(
      r'^(25[0-5]|2[0-4]\d|1?\d?\d)(\.(25[0-5]|2[0-4]\d|1?\d?\d)){3}$',
    );
    final ipv6 = RegExp(r'^[0-9a-fA-F:]{2,45}$');
    return ipv4.hasMatch(normalized) || ipv6.hasMatch(normalized);
  }

  String _formatReadableError(Object error) {
    if (error is DioException) {
      if (error.response?.statusMessage != null &&
          error.response!.statusMessage!.isNotEmpty) {
        return error.response!.statusMessage!;
      }
      if (error.response?.statusCode != null) {
        return 'HTTP ${error.response!.statusCode}';
      }
      if (error.message != null && error.message!.isNotEmpty) {
        return error.message!;
      }
    }

    final message = error.toString();
    if (message.length > 60) {
      return '${message.substring(0, 57)}...';
    }
    return message;
  }

  /// Load connection analytics from storage
  Future<void> _loadConnectionAnalytics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _totalConnectionAttempts = prefs.getInt('total_connection_attempts') ?? 0;
      _successfulConnections = prefs.getInt('successful_connections') ?? 0;
      _failedConnections = prefs.getInt('failed_connections') ?? 0;
      _averageConnectionTime =
          prefs.getDouble('average_connection_time') ?? 0.0;
    } catch (e) {
      print('Error loading connection analytics: $e');
    }
  }

  /// Save connection analytics to storage
  Future<void> _saveConnectionAnalytics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('total_connection_attempts', _totalConnectionAttempts);
      await prefs.setInt('successful_connections', _successfulConnections);
      await prefs.setInt('failed_connections', _failedConnections);
      await prefs.setDouble('average_connection_time', _averageConnectionTime);
    } catch (e) {
      print('Error saving connection analytics: $e');
    }
  }

  /// Record connection attempt
  void _recordConnectionAttempt(bool success, int connectionTime) {
    _totalConnectionAttempts++;

    if (success) {
      _successfulConnections++;
      // Update average connection time
      if (_averageConnectionTime == 0.0) {
        _averageConnectionTime = connectionTime.toDouble();
      } else {
        _averageConnectionTime =
            (_averageConnectionTime + connectionTime) / 2.0;
      }
    } else {
      _failedConnections++;
    }

    _saveConnectionAnalytics();
  }

  /// Get connection success rate
  double get connectionSuccessRate {
    if (_totalConnectionAttempts == 0) return 0.0;
    return _successfulConnections / _totalConnectionAttempts;
  }

  /// Get connection analytics summary
  Map<String, dynamic> getConnectionAnalytics() {
    return {
      'totalAttempts': _totalConnectionAttempts,
      'successfulConnections': _successfulConnections,
      'successRate': connectionSuccessRate,
      'averageConnectionTime': _averageConnectionTime,
      'optimizationServiceStats': _connectionService.getConnectionStats(),
      'blockedApps': blockedApps,
    };
  }

  @override
  void dispose() {
    _aetherStateSub?.cancel();
    _intelligentSelector.dispose();
    _v2rayManager.stop();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    getVersionName();
    // Attach shared V2ray instance to services BEFORE initializing them
    _loadServerSelection();

    // Defer network/cache work until after the first frame so the initial
    // screen remains responsive on slower devices.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future<void>.delayed(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        _initializeServices();
        _fetchAndCacheServersOnStartup();
      });
    });

    _v2rayManager
        .ensureInitialized(
      notificationIconResourceType: "notification_icon_type".tr(),
      notificationIconResourceName: "notification_icon_name".tr(),
    )
        .then((value) async {
      coreVersion = await _v2rayManager.getCoreVersion();
      
      // Listen for status changes to trigger IP fetch
      _v2rayManager.addStatusListener((status) {
        if (!mounted) return;
        
        final String state = status.state.toUpperCase();
        final bool isConnected = state == 'CONNECTED' ||
            state == 'RUNNING' ||
            state == 'STARTED';
            
        if (isConnected && _userIP == null && !_isFetchingIP) {
          _fetchUserIP();
        } else if (!isConnected && _userIP != null) {
          _ipRequestGeneration++;
          setState(() {
            _userIP = null;
            _userCountryFlag = null;
            _userCountryName = null;
          });
        }
      });
      
      setState(() {});
    }).catchError((error) {
      print('V2Ray initialization failed: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColor.backgroundColor,
      body: Stack(
        children: [
          Positioned.fill(child: _buildLiquidBackground()),
          SafeArea(
            child: ValueListenableBuilder<V2RayStatus>(
              valueListenable: v2rayStatus,
              builder: (context, status, _) {
                // Prefer Aether tunnel state when native core is available
                final String normalizedState = status.state.toUpperCase();
                final bool v2rayConnecting = normalizedState == 'CONNECTING' ||
                    normalizedState == 'STARTING';
                final bool v2rayConnected = normalizedState == 'CONNECTED' ||
                    normalizedState == 'RUNNING' ||
                    normalizedState == 'STARTED';

                final bool isConnected =
                    _useAether ? _isAetherConnected : v2rayConnected;
                final bool isConnecting = !isConnected &&
                    (_useAether
                        ? (_isAetherConnecting || isLoading)
                        : (isLoading || v2rayConnecting));
                final String displayStatus = isConnected
                    ? 'CONNECTED'
                    : (isConnecting
                        ? 'CONNECTING'
                        : (_aetherState == AetherState.failed
                            ? 'FAILED'
                            : 'DISCONNECTED'));

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverAppBar(
                      pinned: true,
                      automaticallyImplyLeading: false,
                      titleSpacing: 20,
                      title: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              gradient: ThemeColor.primaryGradient,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              Icons.shield_rounded,
                              color: ThemeColor.backgroundColor,
                              size: 21,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'app_title'.tr(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: ThemeColor.headingStyle(
                                    fontSize: 18,
                                    context: context,
                                  ),
                                ),
                                Text(
                                  displayStatus == 'CONNECTED'
                                      ? 'connected'.tr()
                                      : 'disconnected'.tr(),
                                  style: ThemeColor.captionStyle(
                                    fontSize: 11,
                                    color: isConnected
                                        ? ThemeColor.successColor
                                        : ThemeColor.secondaryText,
                                    context: context,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildCoreSelector(),
                          const SizedBox(height: 16),
                          _buildSimplifiedConnectionSection(
                              status, isConnected, isConnecting, displayStatus),
                          const SizedBox(height: 16),
                          AdBannerWidget(),
                          const SizedBox(height: 16),
                          if (_useAether)
                            _buildAetherModeCard()
                          else
                            _buildSimplifiedServerSelection(),
                          const SizedBox(height: 16),
                          if (isConnected) ...[
                            if (_useAether)
                              _buildAetherConnectedInfo()
                            else
                              _buildSimplifiedStats(status),
                            const SizedBox(height: 16),
                          ],
                        ]),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiquidBackground() {
    return Container(
      decoration: const BoxDecoration(
        color: ThemeColor.backgroundColor,
      ),
      child: Stack(
        children: [
          Positioned(
            top: -190,
            right: -130,
            child: _buildGlowBlob(
              diameter: 360,
              colors: [
                ThemeColor.primaryColor.withValues(alpha: 0.10),
                ThemeColor.primaryColor.withValues(alpha: 0.0),
              ],
            ),
          ),
          Positioned(
            bottom: -180,
            left: -160,
            child: _buildGlowBlob(
              diameter: 360,
              colors: [
                ThemeColor.successColor.withValues(alpha: 0.06),
                ThemeColor.successColor.withValues(alpha: 0.0),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlowBlob({
    required double diameter,
    required List<Color> colors,
  }) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: colors,
        ),
      ),
    );
  }

  List<Color> _neutralGlassGradient(
      {double highlight = 0.14, double lowlight = 0.04}) {
    return [
      Colors.white.withValues(alpha: highlight.clamp(0.0, 1.0)),
      Colors.white.withValues(alpha: lowlight.clamp(0.0, 1.0)),
    ];
  }

  List<Color> _tintedGlassGradient(
    Color tint, {
    double highlight = 0.22,
    double lowlight = 0.06,
  }) {
    return [
      tint.withValues(alpha: highlight.clamp(0.0, 1.0)),
      Colors.white.withValues(alpha: lowlight.clamp(0.0, 1.0)),
    ];
  }

  // Simplified connection section
  Widget _buildSimplifiedConnectionSection(
    V2RayStatus status,
    bool isConnected,
    bool isConnecting,
    String displayStatus,
  ) {
    final Color baseTint = isConnected
        ? ThemeColor.connectedColor
        : (isConnecting ? ThemeColor.connectingColor : ThemeColor.primaryColor);

    return LiquidGlassContainer(
      borderRadius: ThemeColor.xlRadius,
      padding: EdgeInsets.all(ThemeColor.largeSpacing),
      blurSigma: 28,
      gradientColors: _tintedGlassGradient(
        baseTint,
        highlight: isConnected ? 0.28 : 0.2,
        lowlight: 0.05,
      ),
      child: Column(
        children: [
          ConnectionWidget(
            onTap: () => _handleConnectionTap(status),
            // A confirmed connection wins over stale asynchronous work.
            isLoading: isConnecting && !isConnected,
            status: displayStatus,
          ),
          if (isConnected) ...[
            SizedBox(height: ThemeColor.mediumSpacing),
            _buildSimplifiedStatusInfo(status),
          ],
          if (_shouldShowLoadingStatus()) ...[
            SizedBox(height: ThemeColor.mediumSpacing),
            _buildSimplifiedLoadingStatus(),
          ],
        ],
      ),
    );
  }

  // Simplified status info
  Widget _buildSimplifiedStatusInfo(V2RayStatus status) {
    final bool showV2RayStats = !_useAether;

    return LiquidGlassContainer(
      padding: EdgeInsets.all(ThemeColor.mediumSpacing),
      borderRadius: ThemeColor.largeRadius,
      blurSigma: 24,
      enableBlur: false,
      showShadow: false,
      gradientColors: _tintedGlassGradient(
        ThemeColor.successColor,
        highlight: 0.24,
        lowlight: 0.05,
      ),
      child: showV2RayStats
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: _buildSimpleStatItem(
                    icon: Icons.timer_rounded,
                    label: 'connection_time'.tr(),
                    value: status.duration,
                    color: ThemeColor.successColor,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: ThemeColor.successColor.withValues(alpha: 0.3),
                ),
                Expanded(
                  child: _buildSimpleStatItem(
                    icon: Icons.arrow_downward_rounded,
                    label: 'download'.tr(),
                    value: _formatSpeed('${status.downloadSpeed} B/s'),
                    color: ThemeColor.successColor,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: ThemeColor.successColor.withValues(alpha: 0.3),
                ),
                Expanded(
                  child: _buildSimpleStatItem(
                    icon: Icons.arrow_upward_rounded,
                    label: 'upload'.tr(),
                    value: _formatSpeed('${status.uploadSpeed} B/s'),
                    color: ThemeColor.warningColor,
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ValueListenableBuilder<String>(
                  valueListenable: _aetherManager.durationNotifier,
                  builder: (context, duration, _) {
                    return Expanded(
                      child: _buildSimpleStatItem(
                        icon: Icons.timer_rounded,
                        label: 'connection_time'.tr(),
                        value: duration,
                        color: ThemeColor.successColor,
                      ),
                    );
                  },
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: ThemeColor.successColor.withValues(alpha: 0.3),
                ),
                Expanded(
                  child: _buildSimpleStatItem(
                  icon: Icons.language_rounded,
                  label: 'ip_address'.tr(),
                  value: _userIP ?? '—',
                  color: ThemeColor.primaryColor,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSimpleStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: ThemeColor.bodyStyle(
              fontWeight: FontWeight.w700,
              color: color,
              fontSize: 15,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: ThemeColor.captionStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
      ],
    );
  }

  bool _shouldShowLoadingStatus() {
    return isLoading && loadingStatus.isNotEmpty;
  }

  Widget _buildAetherModeCard() {
    return LiquidGlassContainer(
      borderRadius: ThemeColor.largeRadius,
      padding: EdgeInsets.all(ThemeColor.mediumSpacing),
      blurSigma: 20,
      gradientColors: _tintedGlassGradient(
        ThemeColor.primaryColor,
        highlight: 0.18,
        lowlight: 0.05,
      ),
      borderColor: ThemeColor.primaryColor.withValues(alpha: 0.28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ThemeColor.primaryColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
                ),
                child: Icon(Icons.hub_rounded,
                    color: ThemeColor.primaryColor, size: 22),
              ),
              SizedBox(width: ThemeColor.mediumSpacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'aether_edge_mode'.tr(),
                      style: ThemeColor.bodyStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'aether_edge_mode_desc'.tr(),
                      style: ThemeColor.captionStyle(
                        color: ThemeColor.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'scan_mode'.tr(),
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ScanModeScreen(),
                    ),
                  );
                  await _loadAetherPreferences();
                },
                icon: Icon(Icons.tune_rounded, color: ThemeColor.primaryColor),
              ),
            ],
          ),
          SizedBox(height: ThemeColor.mediumSpacing),
          Row(
            children: [
              Expanded(
                child: _buildAetherChip(
                  icon: Icons.vpn_key_rounded,
                  label: _aetherProtocolLabel(),
                ),
              ),
              SizedBox(width: ThemeColor.smallSpacing),
              Expanded(
                child: _buildAetherChip(
                  icon: Icons.bolt_rounded,
                  label: _aetherScanLabel(),
                ),
              ),
              SizedBox(width: ThemeColor.smallSpacing),
              Expanded(
                child: _buildAetherChip(
                  icon: Icons.public_rounded,
                  label: _aetherTransport.toUpperCase(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAetherChip({required IconData icon, required String label}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: ThemeColor.primaryColor),
          SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: ThemeColor.captionStyle(
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Core selector ──────────────────────────────────────────────

  bool get _isVpnActive {
    if (_useAether) return _isAetherConnected || _isAetherConnecting;
    final state = v2rayStatus.value.state.toUpperCase();
    return state == 'CONNECTED' ||
        state == 'RUNNING' ||
        state == 'STARTED' ||
        state == 'CONNECTING' ||
        state == 'STARTING';
  }

  void _onCoreSelected(String core) {
    if (core == _selectedCore) return;

    if (_isVpnActive) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('switch_core_disconnect'.tr()),
            behavior: SnackBarBehavior.floating,
            backgroundColor: ThemeColor.warningColor,
            duration: const Duration(seconds: 3),
          ),
        );
      return;
    }

    setState(() {
      _selectedCore = core;
    });
    _saveSelectedCore(core);

    if (core == 'aether' && _aetherAvailable) {
      _aetherManager.syncState().then((_) {
        if (!mounted) return;
        _loadAetherPreferences();
      });
    }
  }

  Widget _buildCoreSelector() {
    final bool aetherDisabled = !_aetherAvailable;

    return LiquidGlassContainer(
      borderRadius: ThemeColor.xlRadius,
      padding: EdgeInsets.zero,
      blurSigma: 24,
      enableBlur: false,
      gradientColors: _neutralGlassGradient(highlight: 0.16, lowlight: 0.04),
      borderColor: ThemeColor.borderColor.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              ThemeColor.mediumSpacing,
              ThemeColor.mediumSpacing,
              ThemeColor.mediumSpacing,
              ThemeColor.smallSpacing,
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ThemeColor.primaryColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
                  ),
                  child: Icon(Icons.memory_rounded,
                      color: ThemeColor.primaryColor, size: 20),
                ),
                SizedBox(width: ThemeColor.smallSpacing),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'vpn_core'.tr(),
                        style: ThemeColor.bodyStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'vpn_core_desc'.tr(),
                        style: ThemeColor.captionStyle(
                          color: ThemeColor.secondaryText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              ThemeColor.mediumSpacing,
              0,
              ThemeColor.mediumSpacing,
              ThemeColor.mediumSpacing,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildCoreOption(
                    icon: Icons.hub_rounded,
                    label: 'core_aether'.tr(),
                    isSelected: _selectedCore == 'aether',
                    isDisabled: aetherDisabled,
                    disabledLabel: 'core_not_available'.tr(),
                    onTap: () => _onCoreSelected('aether'),
                  ),
                ),
                SizedBox(width: ThemeColor.smallSpacing),
                Expanded(
                  child: _buildCoreOption(
                    icon: Icons.public_rounded,
                    label: 'core_v2ray'.tr(),
                    isSelected: _selectedCore == 'v2ray',
                    onTap: () => _onCoreSelected('v2ray'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoreOption({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    bool isDisabled = false,
    String? disabledLabel,
  }) {
    final Color activeColor = ThemeColor.primaryColor;
    final Color color =
        isSelected ? activeColor : (isDisabled ? ThemeColor.mutedText : ThemeColor.secondaryText);

    return Material(
      color: isSelected
          ? activeColor.withValues(alpha: 0.14)
          : Colors.white.withValues(alpha: 0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
        side: BorderSide(
          color: isSelected
              ? activeColor.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.08),
          width: isSelected ? 1.5 : 0.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
        onTap: isDisabled ? null : onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: color,
                size: 26,
              ),
              SizedBox(height: 6),
              Text(
                label,
                style: ThemeColor.captionStyle(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              if (isDisabled && disabledLabel != null) ...[
                SizedBox(height: 2),
                Text(
                  disabledLabel,
                  style: ThemeColor.captionStyle(
                    color: ThemeColor.errorColor.withValues(alpha: 0.7),
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAetherConnectedInfo() {
    return LiquidGlassContainer(
      padding: EdgeInsets.all(ThemeColor.mediumSpacing),
      borderRadius: ThemeColor.largeRadius,
      blurSigma: 20,
      enableBlur: false,
      showShadow: false,
      gradientColors: _tintedGlassGradient(
        ThemeColor.successColor,
        highlight: 0.22,
        lowlight: 0.05,
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSimpleStatItem(
              icon: Icons.shield_rounded,
              label: 'protocol_selection'.tr(),
              value: _aetherProtocolLabel(),
              color: ThemeColor.successColor,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: ThemeColor.successColor.withValues(alpha: 0.3),
          ),
          Expanded(
            child: _buildSimpleStatItem(
              icon: Icons.language_rounded,
              label: 'ip_address'.tr(),
              value: _userIP ?? '—',
              color: ThemeColor.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  // Simplified loading status
  Widget _buildSimplifiedLoadingStatus() {
    return LiquidGlassContainer(
      padding: EdgeInsets.all(ThemeColor.mediumSpacing),
      borderRadius: ThemeColor.largeRadius,
      blurSigma: 22,
      enableBlur: false,
      showShadow: false,
      gradientColors: _tintedGlassGradient(
        ThemeColor.connectingColor,
        highlight: 0.22,
        lowlight: 0.05,
      ),
      child: Row(
        children: [
          LoadingAnimationWidget.threeArchedCircle(
            color: ThemeColor.connectingColor,
            size: 20,
          ),
          SizedBox(width: ThemeColor.mediumSpacing),
          Expanded(
            child: Text(
              loadingStatus,
              style: ThemeColor.bodyStyle(
                color: ThemeColor.connectingColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper function to format bytes for better readability
  String _formatBytes(String bytesStr) {
    try {
      // Extract numeric value from string like "1234567 B"
      final match = RegExp(r'(\d+)').firstMatch(bytesStr);
      if (match == null) return bytesStr;

      final bytes = int.parse(match.group(1)!);

      if (bytes < 1024) return '${bytes} B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      if (bytes < 1024 * 1024 * 1024)
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    } catch (e) {
      return bytesStr;
    }
  }

  // Helper function to format speed for better readability
  String _formatSpeed(String speedStr) {
    try {
      // Extract numeric value from string like "1234567 B/s"
      final match = RegExp(r'(\d+)').firstMatch(speedStr);
      if (match == null) return speedStr;

      final bytesPerSec = int.parse(match.group(1)!);

      if (bytesPerSec < 1024) return '${bytesPerSec} B/s';
      if (bytesPerSec < 1024 * 1024)
        return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
      if (bytesPerSec < 1024 * 1024 * 1024)
        return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
      return '${(bytesPerSec / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB/s';
    } catch (e) {
      return speedStr;
    }
  }

  // Simplified server selection
  Widget _buildSimplifiedServerSelection() {
    return Container(
      decoration: ThemeColor.cardDecoration(
        color: ThemeColor.cardColor,
        radius: ThemeColor.largeRadius,
      ),
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThemeColor.largeRadius),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(ThemeColor.largeRadius),
          onTap: () => _showServerSelectionModal(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ThemeColor.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
                  ),
                  child: Icon(
                    Icons.dns_rounded,
                    color: ThemeColor.primaryColor,
                    size: 24,
                  ),
                ),
                SizedBox(width: ThemeColor.mediumSpacing),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'server'.tr(),
                      style: ThemeColor.captionStyle(
                        color: ThemeColor.mutedText,
                      ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        selectedServer,
                        style: ThemeColor.bodyStyle(
                          fontWeight: FontWeight.w700,
                          color: ThemeColor.primaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: ThemeColor.mutedText,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Simplified stats
  Widget _buildSimplifiedStats(V2RayStatus status) {
    return LiquidGlassContainer(
      borderRadius: ThemeColor.xlRadius,
      padding: EdgeInsets.all(ThemeColor.mediumSpacing),
      blurSigma: 25,
      enableBlur: false,
      gradientColors: _neutralGlassGradient(highlight: 0.18, lowlight: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_rounded,
                color: ThemeColor.primaryColor,
                size: 20,
              ),
              SizedBox(width: ThemeColor.smallSpacing),
              Text(
                'statistics'.tr(),
                style: ThemeColor.bodyStyle(
                  fontWeight: FontWeight.w600,
                  color: ThemeColor.primaryText,
                ),
              ),
            ],
          ),
          SizedBox(height: ThemeColor.mediumSpacing),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.arrow_downward_rounded,
                  label: '${'download'.tr()} / ${'speed'.tr()}',
                  speedValue: _formatSpeed("${status.downloadSpeed} B/s"),
                  sizeValue: _formatBytes("${status.download} B"),
                  color: ThemeColor.successColor,
                ),
              ),
              SizedBox(width: ThemeColor.smallSpacing),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.arrow_upward_rounded,
                  label: '${'upload'.tr()} / ${'speed'.tr()}',
                  speedValue: _formatSpeed("${status.uploadSpeed} B/s"),
                  sizeValue: _formatBytes("${status.upload} B"),
                  color: ThemeColor.warningColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String speedValue,
    required String sizeValue,
    required Color color,
  }) {
    return LiquidGlassContainer(
      borderRadius: ThemeColor.largeRadius,
      padding: EdgeInsets.all(ThemeColor.mediumSpacing),
      blurSigma: 22,
      enableBlur: false,
      showShadow: false,
      gradientColors: _tintedGlassGradient(
        color,
        highlight: 0.2,
        lowlight: 0.05,
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(height: ThemeColor.smallSpacing),
          Text(
            speedValue,
            style: ThemeColor.bodyStyle(
              fontWeight: FontWeight.w800,
              color: color,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 2),
          Text(
            sizeValue,
            style: ThemeColor.captionStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 2),
          Text(
            label,
            style: ThemeColor.captionStyle(
              color: color.withValues(alpha: 0.6),
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }



  Future<void> _cancelConnectionAttempt() async {
    // Stop both engines defensively: the selected engine may have started
    // while the status notifier is still catching up.
    try {
      await _aetherManager.stop();
    } catch (_) {}
    try {
      _v2rayManager.stop();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      isLoading = false;
      loadingStatus = '';
      _aetherState = AetherState.disconnected;
    });
  }

  void _handleConnectionTap(V2RayStatus value) async {
    // Aether-first path when Aether core is selected and available
    if (_useAether) {
      if (_isAetherConnected || _isAetherConnecting || isLoading) {
        if (mounted) {
          setState(() {
            isLoading = true;
            loadingStatus = 'disconnecting'.tr();
          });
        }
        await _cancelConnectionAttempt();
        return;
      }

      await _connectWithAether();
      return;
    }

    final current = value.state.toUpperCase();
    // The connection CTA is also a cancel action while a handshake is active.
    if (current == 'CONNECTED' ||
        current == 'CONNECTING' ||
        current == 'STARTING' ||
        isLoading) {
      await _cancelConnectionAttempt();
      return;
    }

    // Treat any other state as disconnected and attempt connection
    if (!isLoading) {
      connectionRetryCount = 0; // Reset retry count for new connection attempt

      // Check if we have servers available (use actual server lists instead of test results)
      final hasProcessedServers = processedServers.isNotEmpty;
      final hasCachedServers = cachedServers.isNotEmpty;
      final hasAnyServers = hasProcessedServers || hasCachedServers;

      if (!hasAnyServers) {
        // No servers available at all, need to fetch
        print('No servers available, fetching new servers...');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('no_servers_available_fetching'.tr()),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        // We have servers available, proceed with connection
        final serverCount = hasProcessedServers
            ? processedServers.length
            : cachedServers.length;
        print(
            'Found $serverCount available servers, proceeding with connection...');
      }

      // Always proceed with connection attempt (the connection methods handle server fetching if needed)
      await _connectWithRetry();
    }
  }

  Future<void> _connectWithAether() async {
    try {
      setState(() {
        isLoading = true;
        loadingStatus = 'aether_preparing'.tr();
      });

      await _loadAetherPreferences();

      final granted = await _aetherManager.requestVpnPermission();
      if (!granted) {
        throw Exception('vpn_permission_denied'.tr());
      }

      setState(() {
        loadingStatus = '';
      });

      await _aetherManager.start(
        protocol: _aetherProtocol,
        scanMode: _aetherScanMode,
        ipScan: (await SharedPreferences.getInstance())
                .getString('selected_ip_version') ??
            'v4',
        obfuscation: (await SharedPreferences.getInstance())
                .getString('selected_aether_obfuscation') ??
            'firewall',
        transport: _aetherTransport,
      );

      // State updates continue via _aetherStateSub
    } catch (e) {
      print('Aether connection failed: $e');
      await _aetherManager.stop();
      if (mounted) {
        setState(() {
          isLoading = false;
          loadingStatus = '';
          _aetherState = AetherState.failed;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('connection_failed_error_details'
                .tr()
                .replaceAll('{{error}}', e.toString())),
            behavior: SnackBarBehavior.floating,
            backgroundColor: ThemeColor.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _connectWithRetry() async {
    try {
      setState(() {
        isLoading = true;
        loadingStatus = '🔄 Preparing connection...';
      });

      // Try simple automatic connection first
      await _connectAutomaticSimple();
    } catch (e) {
      print('Simple automatic connection failed: $e');

      // Fallback to enhanced method
      try {
        await _connectAutomaticSmart();
      } catch (e2) {
        print('Enhanced automatic connection also failed: $e2');

        // Final fallback to original method
        await _connectWithFallbackRetry();
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          loadingStatus = '';
        });
      }
    }
  }

  /// Enhanced automatic connection method with intelligent retry
  Future<void> _connectAutomaticSimple() async {
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        setState(() {
          loadingStatus = retryCount == 0
              ? '🚀 Starting automatic connection...'
              : '🔄 Retrying automatic connection (${retryCount + 1}/$maxRetries)...';
        });

        // Add overall timeout for the entire connection process
        await Future.any([
          _performSimpleConnection(),
          Future.delayed(Duration(seconds: 30), () {
            throw TimeoutException(
                'Connection process timed out', Duration(seconds: 30));
          }),
        ]);

        // If we reach here, connection was successful
        print('✅ Automatic connection successful on attempt ${retryCount + 1}');
        return;
      } catch (e) {
        retryCount++;
        print('❌ Automatic connection attempt $retryCount failed: $e');

        if (retryCount >= maxRetries) {
          print('🚫 All automatic connection attempts failed');
          rethrow;
        }

        // Wait before retry with exponential backoff
        final delaySeconds = retryCount * 2;
        setState(() {
          loadingStatus = '⏳ Waiting ${delaySeconds}s before retry...';
        });
        await Future.delayed(Duration(seconds: delaySeconds));
      }
    }
  }

  /// Perform the actual simple connection with improved logic
  Future<void> _performSimpleConnection() async {
    setState(() {
      loadingStatus = '🔍 Finding best server for automatic connection...';
    });

    // ⚡️ Step 0: Immediately try to reuse the last successful server if it is still fresh
    if (await _tryReconnectUsingLastSuccessfulServer()) {
      return;
    }

    // ⚡️ Step 1: Try immediate connection mode first (connect after first ping)
    try {
      final servers = await _fetchServersWithFallback();
      if (servers.isNotEmpty) {
        setState(() {
          loadingStatus = '📡 Testing servers for immediate connection...';
        });

        final immediateCompleter = Completer<Map<String, dynamic>?>();
        final bestServer = await _selectBestServerSmart(
          servers.take(8).toList(),
          connectImmediately: true, // Enable immediate connection mode
          immediateCompleter: immediateCompleter,
        ).timeout(Duration(seconds: 15), onTimeout: () {
          print('Immediate connection mode timed out');
          return null;
        });

        // If immediate connection was successful, we're done
        if (bestServer == null && immediateCompleter.isCompleted) {
          return;
        }

        // If we got a best server but didn't connect immediately, connect now
        if (bestServer != null && bestServer['server'] != null) {
          setState(() {
            loadingStatus = '🚀 Connecting to optimal server...';
          });
          await _connectToServer(bestServer['server'] as String);
          return;
        }
      }
    } catch (e) {
      print('Immediate connection mode failed: $e');
    }

    // Step 2: Fallback to intelligent server selector
    String? intelligentServer;
    try {
      if (mounted) {
        setState(() {
          loadingStatus = '🤖 Analyzing servers with intelligent selector...';
        });
      }

      intelligentServer = await _intelligentSelector.getBestServer(
        onStatusUpdate: (status) {
          if (!mounted) return;
          setState(() {
            loadingStatus = '🤖 ${status.trim()}';
          });
        },
        onProgressUpdate: (completed, total) {
          if (!mounted || total == 0) return;
          setState(() {
            loadingStatus = '🤖 Testing servers $completed/$total...';
          });
        },
      );
    } catch (e) {
      print('Intelligent selector failed: $e');
    }

    if (intelligentServer != null && intelligentServer.isNotEmpty) {
      try {
        setState(() {
          loadingStatus = '🚀 Connecting via intelligent selector...';
        });
        await _connectToServer(intelligentServer);
        print('✅ Connected using intelligent server selector');
        return;
      } catch (e) {
        print('❌ Intelligent selector connection failed: $e');
      }
    }

    // Step 1: Try to use processed servers with ping data
    if (processedServers.isNotEmpty) {
      print('📋 Using processed servers (${processedServers.length} servers)');

      // Filter and sort healthy servers by ping (best first)
      final healthyServers = processedServers
          .where((server) =>
              (server['ping'] as int) > 0 && (server['ping'] as int) < 5000)
          .toList();

      // Sort by ping (ascending - best ping first)
      healthyServers
          .sort((a, b) => (a['ping'] as int).compareTo(b['ping'] as int));

      if (healthyServers.isNotEmpty) {
        // Try top 3 servers for better reliability
        for (int i = 0; i < healthyServers.length && i < 3; i++) {
          final server = healthyServers[i];
          try {
            setState(() {
              loadingStatus =
                  '🚀 Connecting to server ${i + 1} (${server['ping']}ms)...';
            });

            await _connectToServer(server['config'] as String);
            print(
                '✅ Successfully connected to server with ${server['ping']}ms ping');
            return;
          } catch (e) {
            print('❌ Failed to connect to server ${i + 1}: $e');
            if (i == healthyServers.length - 1 || i == 2) {
              // If this was the last attempt, continue to next method
              break;
            }
            // Try next server
            continue;
          }
        }
      }
    }

    // Step 2: Fetch fresh servers and test them with immediate connection
    setState(() {
      loadingStatus = '📡 Fetching fresh servers...';
    });

    try {
      final freshServers = await _fetchServersWithFallback();
      if (freshServers.isNotEmpty) {
        // Use smart server selection with immediate connection mode
        final immediateCompleter = Completer<Map<String, dynamic>?>();
        final bestServer = await _selectBestServerSmart(
          freshServers.take(8).toList(),
          connectImmediately: true, // Enable immediate connection mode
          immediateCompleter: immediateCompleter,
        ).timeout(Duration(seconds: 30), onTimeout: () {
          print('Server selection timed out');
          return null;
        });

        // If immediate connection was successful, we're done
        if (bestServer == null && immediateCompleter.isCompleted) {
          return;
        }

        // Fallback to old method if immediate connection didn't happen
        if (bestServer == null) {
          final fallbackServer =
              await findAndTestBestServer(freshServers.take(5).toList());
          if (fallbackServer != null) {
            setState(() {
              loadingStatus = '🚀 Connecting to optimal server...';
            });
            await _connectToServer(fallbackServer);
            return;
          }
        } else if (bestServer['server'] != null) {
          // If we got a best server but didn't connect immediately, connect now
          setState(() {
            loadingStatus = '🚀 Connecting to optimal server...';
          });
          await _connectToServer(bestServer['server'] as String);
          return;
        }
      }
    } catch (e) {
      print('Failed to fetch fresh servers: $e');
    }

    // Step 3: Fallback to cached servers
    if (cachedServers.isNotEmpty) {
      print('📋 Using cached servers as fallback');

      setState(() {
        loadingStatus = '🚀 Connecting to cached server...';
      });

      // Try first few cached servers
      for (int i = 0; i < cachedServers.length && i < 3; i++) {
        try {
          await _connectToServer(cachedServers[i]);
          print('✅ Successfully connected using cached server ${i + 1}');
          return;
        } catch (e) {
          print('❌ Cached server ${i + 1} failed: $e');
          if (i == cachedServers.length - 1 || i == 2) {
            break;
          }
        }
      }
    }

    // Step 4: Ultimate fallback - use optimization service
    setState(() {
      loadingStatus = '🔧 Using optimization service...';
    });

    try {
      final optimizedServers =
          await _serverService.getOptimizedServerList(forceRefresh: true);
      if (optimizedServers.isNotEmpty) {
        await _connectToServer(optimizedServers.first);
        return;
      }
    } catch (e) {
      print('Optimization service failed: $e');
    }

    throw Exception('All automatic connection methods failed');
  }

  /// Enhanced automatic connection with smart server selection
  Future<void> _connectAutomaticSmart() async {
    try {
      // Step 1: Get server list with multiple fallbacks
      final servers = await _fetchServersWithMultipleFallbacks();
      if (servers.isEmpty) {
        throw Exception('No servers available from any source');
      }

      setState(() {
        loadingStatus = '🔍 Analyzing ${servers.length} servers...';
      });

      // Step 2: Test servers and connect immediately after first valid ping
      final immediateCompleter = Completer<Map<String, dynamic>?>();
      final bestServer = await _selectBestServerSmart(
        servers,
        connectImmediately: true, // Enable immediate connection mode
        immediateCompleter: immediateCompleter,
      ).timeout(Duration(seconds: 30), onTimeout: () {
        print('Server selection timed out, using first available server');
        return null;
      });

      // If immediate connection was successful, we're done
      if (bestServer == null && immediateCompleter.isCompleted) {
        return;
      }

      if (bestServer == null) {
        // Fallback: try direct connection with first server
        print('No healthy servers found, trying direct connection...');
        // connectDirectly(servers.take(3).toList()); // Removed to fix compilation
        return;
      }

      setState(() {
        loadingStatus = '🚀 Connecting to optimal server...';
      });

      // Step 3: Connect to the selected server (if immediate connection didn't happen)
      await _connectToSelectedServer(bestServer);
    } catch (e) {
      print('Smart automatic connection failed: $e');
      rethrow;
    }
  }

  /// Fetch servers with multiple fallback methods
  Future<List<String>> _fetchServersWithMultipleFallbacks() async {
    final fallbackMethods = [
      _fetchServersOptimized,
      _fetchServersDirect,
      _fetchServersFromAllOrigins,
      _fetchServersFromAlternative,
    ];

    for (int i = 0; i < fallbackMethods.length; i++) {
      try {
        setState(() {
          loadingStatus =
              '📡 Fetching servers (method ${i + 1}/${fallbackMethods.length})...';
        });

        final servers = await fallbackMethods[i]();
        if (servers.isNotEmpty) {
          print(
              '✅ Successfully fetched ${servers.length} servers using method ${i + 1}');
          return servers;
        }
      } catch (e) {
        print('❌ Method ${i + 1} failed: $e');
        if (i < fallbackMethods.length - 1) {
          await Future.delayed(Duration(milliseconds: 500));
        }
      }
    }

    throw Exception('All server fetching methods failed');
  }

  /// Select the best server using smart algorithm with immediate connection option
  Future<Map<String, dynamic>?> _selectBestServerSmart(
    List<String> servers, {
    bool connectImmediately =
        false, // If true, connect immediately after first valid ping
    Completer<Map<String, dynamic>?>?
        immediateCompleter, // Completer for immediate connection
  }) async {
    final testResults = <Map<String, dynamic>>[];
    final serversToTest = servers.take(8).toList(); // Test first 8 servers

    setState(() {
      loadingStatus = '🚀 Parallel testing ${serversToTest.length} servers...';
    });

    // Use parallel testing for faster server selection
    final v2rayPing = FlutterV2rayPingService();
    v2rayPing.initialize();

    // Flag to track if we've already connected
    bool hasConnectedImmediately = false;

    final results = await v2rayPing.testMultipleServerPingsIntelligent(
      serversToTest,
      baseTimeoutSeconds: 60,
      parallel: true,
      maxConcurrent: 12, // Test 12 servers simultaneously for speed
      prioritizeByQuality: true,
      onServerComplete: (server, ping) async {
        if (!mounted) return;

        final effectiveDelay = ping <= 0 ? -1 : ping;
        final responseTime = ping; // Use ping as response time

        if (effectiveDelay > 0 && effectiveDelay < 9999) {
          try {
            // Parse config once we know ping is valid
            final v2rayURL = V2ray.parseFromURL(server);
            final config = v2rayURL.getFullConfiguration();
            if (config.isNotEmpty) {
              final score = _calculateServerScore(
                  effectiveDelay, responseTime, testResults.length);
              final serverData = {
                'server': server,
                'config': config,
                'delay': effectiveDelay,
                'responseTime': responseTime,
                'score': score,
                'index': testResults.length + 1,
              };
              testResults.add(serverData);
              print(
                  '⚡ Real-time result ${testResults.length}: ${effectiveDelay}ms (score: ${score.toStringAsFixed(1)})');

              // Update UI immediately with current results count
              if (mounted) {
                setState(() {
                  loadingStatus =
                      '⚡ Real-time testing: ${testResults.length} results found...';
                });
              }

              // ⚡️ If in immediate connection mode and this is the first valid result, connect immediately
              if (connectImmediately &&
                  !hasConnectedImmediately &&
                  testResults.length == 1) {
                hasConnectedImmediately = true;
                print(
                    '🚀 اتصال فوری به اولین سرور با پینگ معتبر: ${effectiveDelay}ms');

                // Complete the completer immediately with the first valid server
                if (immediateCompleter != null &&
                    !immediateCompleter.isCompleted) {
                  immediateCompleter.complete(serverData);
                }

                // Connect immediately in background (don't await to allow other pings to continue)
                if (mounted) {
                  setState(() {
                    loadingStatus =
                        '🚀 در حال اتصال فوری به سرور (${effectiveDelay}ms)...';
                  });

                  // Start connection without awaiting to allow other operations to continue
                  _connectToServer(server).then((_) {
                    if (mounted) {
                      print('✅ اتصال فوری موفق بود');
                      setState(() {
                        loadingStatus = '✅ متصل شد';
                      });
                    }
                  }).catchError((e) {
                    print('❌ اتصال فوری ناموفق بود: $e');
                    if (mounted) {
                      setState(() {
                        loadingStatus = '❌ اتصال فوری ناموفق بود';
                      });
                    }
                    // Note: We don't reset the flag here as we want to prevent multiple connection attempts
                    // The fallback methods will handle retry if needed
                  });
                }
              }
            }
          } catch (e) {
            print('❌ Server parsing failed: $e');
          }
        }
      },
    );

    // If immediate connection was attempted, return null (connection already done)
    if (connectImmediately && hasConnectedImmediately) {
      return null;
    }

    if (testResults.isEmpty) return null;

    // Sort by score (highest first)
    testResults.sort((a, b) => b['score'].compareTo(a['score']));

    final bestServer = testResults.first;
    print(
        '🏆 Best server selected: ${bestServer['delay']}ms (score: ${bestServer['score'].toStringAsFixed(1)})');

    return bestServer;
  }

  /// Calculate server score for selection
  double _calculateServerScore(int delay, int responseTime, int index) {
    double score = 100.0;

    // Delay penalty (lower is better)
    score -= (delay / 10.0);

    // Response time penalty
    score -= (responseTime / 20.0);

    // Priority bonus (earlier servers get slight bonus)
    score += (8 - index) * 0.5;

    // Stability bonus (if delay is very low)
    if (delay < 200) {
      score += 10.0;
    } else if (delay < 500) {
      score += 5.0;
    }

    return score.clamp(0.0, 100.0);
  }

  /// Connect to the selected server
  Future<void> _connectToSelectedServer(Map<String, dynamic> serverData) async {
    try {
      final config = serverData['config'] as String;
      final delay = serverData['delay'] as int;

      // Request VPN permission
      final hasPermission = await _v2rayManager.requestPermission();
      if (!hasPermission) {
        throw Exception('VPN permission denied');
      }

      // Start V2Ray connection (remove await as startV2Ray is not async)
      await _v2rayManager.start(
        remark: 'ShineNET VPN - Auto',
        config: config,
        proxyOnly: false,
        bypassSubnets: null,
        notificationDisconnectButtonName: 'DISCONNECT',
        blockedApps: blockedApps,
      );

      // Record successful connection
      _recordConnectionAttempt(true, delay);
    } catch (e) {
      _recordConnectionAttempt(false, 0);
      throw Exception('Failed to connect to selected server: $e');
    }
  }

  /// Fetch servers using optimized service
  Future<List<String>> _fetchServersOptimized() async {
    try {
      final servers = await _serverService.getOptimizedServerList(
        forceRefresh: true,
        onStatusUpdate: (status) {
          if (mounted) {
            setState(() {
              loadingStatus = '📡 $status';
            });
          }
        },
      );
      return servers;
    } catch (e) {
      print('Optimized server fetch failed: $e');
      rethrow;
    }
  }

  /// Fallback connection with retry
  Future<void> _connectWithFallbackRetry() async {
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        await getServerList();
        return; // Connection successful, exit retry loop
      } catch (e) {
        print('Fallback connection attempt ${attempt + 1} failed: $e');

        if (attempt < maxRetries) {
          // Calculate exponential backoff delay
          final delaySeconds = initialRetryDelay.inSeconds * (1 << attempt);
          final delay =
              Duration(seconds: delaySeconds > 30 ? 30 : delaySeconds);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Connection failed. Retrying in ${delay.inSeconds} seconds... (${attempt + 1}/$maxRetries)',
                ),
                behavior: SnackBarBehavior.floating,
                duration: delay,
              ),
            );
          }

          await Future.delayed(delay);
        } else {
          // Final attempt failed - offer direct connection
          if (mounted) {
            setState(() {
              isLoading = false;
            });

            // Show option to try direct connection
            final bool tryDirect = await _showDirectConnectionDialog();
            if (tryDirect) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('error_max_retries_reached'.tr()),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        }
      }
    }
  }

  Future<bool> _showDirectConnectionDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('connection_failed'.tr()),
              content: Text('standard_connection_failed_dialog'.tr()),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('cancel'.tr()),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('try_direct_connection'.tr()),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  void _showServerSelectionModal(BuildContext context) {
    // Prepare servers synchronously - processedServers should be available immediately
    final availableServers = _prepareServersForModal();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (BuildContext context) {
        print(
            '📊 Total servers available for modal: ${availableServers.length}');

        return ServerSelectionModal(
          selectedServer: selectedServer,
          onServerSelected: (server) async {
            // Only allow Automatic or specific server configs
            if (server == 'Server 1' || server == 'Server 2') {
              // Don't allow Server 1 or Server 2 selection
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('select_healthy_server'.tr()),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
              return;
            }

            // Allow selection when not connected or connecting
            final String currentState = v2rayStatus.value.state.toUpperCase();
            final bool canChangeServer =
                currentState != 'CONNECTED' && currentState != 'CONNECTING';
            if (canChangeServer) {
              // If the selected server is 'Automatic', perform automatic connection
              if (server == 'Automatic') {
                setState(() {
                  selectedServer = server;
                });
                _saveServerSelection(server);
                Navigator.pop(context);

                // Perform automatic connection to best available server
                try {
                  setState(() {
                    isLoading = true;
                    loadingStatus = '🚀 Starting automatic connection...';
                  });
                  print('🚀 Starting automatic connection mode...');
                  await _performSimpleConnection();
                  print('✅ Automatic connection completed successfully');
                } catch (e) {
                  print('❌ Automatic connection failed: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('connection_failed_error_details'
                            .tr(namedArgs: {'error': e.toString()})),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 5),
                      ),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() {
                      isLoading = false;
                      loadingStatus = '';
                    });
                  }
                }
              } else {
                // If a specific healthy server config is selected, connect to it immediately
                // Extract a descriptive name for the server
                String serverName = _generateServerNameFromConfig(server);

                setState(() {
                  selectedServer = serverName;
                });
                _saveServerSelection(serverName);
                Navigator.pop(context);

                // Connect to the specific server configuration
                try {
                  setState(() {
                    isLoading = true;
                    loadingStatus = '🔌 Connecting to selected server...';
                  });
                  await _connectToServer(server);
                } finally {
                  if (mounted) {
                    setState(() {
                      isLoading = false;
                      loadingStatus = '';
                    });
                  }
                }
              }
            } else {
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'error_change_server'.tr(),
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          },
          healthyServers: availableServers,
        );
      },
    );
  }

  /// Prepare servers for the selection modal (synchronous for instant display)
  List<ServerInfo> _prepareServersForModal() {
    try {
      // 1) Preferred: use processedServers (already enriched with location + ping)
      if (processedServers.isNotEmpty) {
        return processedServers.map((serverData) {
          final ping = serverData['ping'] as int;
          return ServerInfo(
            name: serverData['name'] as String,
            config: serverData['config'] as String,
            ip: serverData['ip'] as String?,
            countryCode: serverData['countryCode'] as String?,
            ping: ping,
            remark: (serverData['remark'] as String?)?.trim(),
          );
        }).toList();
      }

      // 2) Fallback: use cachedServers (populated during startup)
      if (cachedServers.isNotEmpty) {
        final list = <ServerInfo>[];
        for (int i = 0; i < cachedServers.length; i++) {
          final cfg = cachedServers[i];
          final ip = _extractIPFromConfig(cfg);
          final name = _generateServerName(cfg, ip, i + 1);
          final cc = _getCountryCodeFromIPSync(ip);
          final ping = serverPings[cfg] ?? 0;
          final remark = _extractRemark(cfg);
          list.add(ServerInfo(
            name: name,
            config: cfg,
            ip: ip,
            countryCode: cc,
            ping: ping,
            remark: remark.isNotEmpty ? remark : null,
          ));
        }
        return list;
      }

      // 3) Last resort: return empty (widget shows placeholder + refresh)
      return <ServerInfo>[];
    } catch (e) {
      print('Error preparing servers for modal: $e');
      return <ServerInfo>[];
    }
  }

  // Generate a descriptive server name without IP to hide server IPs as requested
  String _generateServerName(String config, String? ip, int index) {
    // Try to extract protocol information
    String protocol = 'Server';
    if (config.startsWith('vmess://')) {
      protocol = 'VMess';
    } else if (config.startsWith('vless://')) {
      protocol = 'VLess';
    } else if (config.startsWith('trojan://')) {
      protocol = 'Trojan';
    } else if (config.startsWith('ss://')) {
      protocol = 'Shadowsocks';
    }

    // Return server name without IP as requested
    return '$protocol $index';
  }

  // Generate a descriptive server name from config for direct selection
  String _generateServerNameFromConfig(String config) {
    // Try to extract protocol information
    String protocol = 'Healthy Server';
    if (config.startsWith('vmess://')) {
      protocol = 'VMess Server';
    } else if (config.startsWith('vless://')) {
      protocol = 'VLess Server';
    } else if (config.startsWith('trojan://')) {
      protocol = 'Trojan Server';
    } else if (config.startsWith('ss://')) {
      protocol = 'Shadowsocks Server';
    }

    return protocol;
  }

  // Extract IP address from server configuration
  String? _extractIPFromConfig(String config) {
    try {
      // Handle different V2Ray protocols
      if (config.startsWith('vmess://')) {
        // VMess URL format
        String base64Part = config.substring(8); // Remove 'vmess://'
        
        // Remove remark/tag (everything after #) before decoding
        if (base64Part.contains('#')) {
          base64Part = base64Part.split('#')[0].trim();
        }
        
        // Remove query parameters (everything after ?)
        if (base64Part.contains('?')) {
          base64Part = base64Part.split('?')[0].trim();
        }
        
        // Remove any trailing/leading whitespace
        base64Part = base64Part.trim();
        
        // Normalize base64 padding
        int remainder = base64Part.length % 4;
        if (remainder > 0) {
          base64Part += '=' * (4 - remainder);
        }
        
        final decoded = utf8.decode(base64.decode(base64Part));
        final json = jsonDecode(decoded);
        return json['add'] as String?; // 'add' field contains the address
      } else if (config.startsWith('vless://') ||
          config.startsWith('trojan://') ||
          config.startsWith('ss://')) {
        // For other protocols, parse as URI
        final uri = Uri.parse(config);
        return uri.host;
      }
    } catch (e) {
      // Silently handle parsing errors - these are expected for some configs
      // print('Error extracting IP from config: $e');
    }

    // Fallback to regex extraction
    try {
      final ipRegex = RegExp(r'(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})');
      final match = ipRegex.firstMatch(config);
      return match?.group(1);
    } catch (e) {
      return null;
    }
  }

  // Synchronous version for immediate display
  String? _getCountryCodeFromIPSync(String? ip) {
    // Simple mapping for immediate display
    if (ip == null || ip.isEmpty) return null;

    if (ip.startsWith('1.1.1')) return 'AU'; // Cloudflare DNS
    if (ip.startsWith('8.8.8')) return 'US'; // Google DNS
    if (ip.startsWith('208.67.222')) return 'US'; // OpenDNS
    if (ip.startsWith('104.16')) return 'US'; // Cloudflare
    if (ip.startsWith('104.17')) return 'US'; // Cloudflare
    if (ip.startsWith('104.18')) return 'US'; // Cloudflare
    if (ip.startsWith('104.19')) return 'US'; // Cloudflare
    if (ip.startsWith('104.20')) return 'US'; // Cloudflare
    if (ip.startsWith('104.21')) return 'US'; // Cloudflare
    if (ip.startsWith('104.22')) return 'US'; // Cloudflare
    if (ip.startsWith('104.23')) return 'US'; // Cloudflare
    if (ip.startsWith('104.24')) return 'US'; // Cloudflare
    if (ip.startsWith('104.25')) return 'US'; // Cloudflare
    if (ip.startsWith('104.26')) return 'US'; // Cloudflare
    if (ip.startsWith('104.27')) return 'US'; // Cloudflare
    if (ip.startsWith('104.28')) return 'US'; // Cloudflare
    if (ip.startsWith('172.64')) return 'US'; // Cloudflare
    if (ip.startsWith('172.65')) return 'US'; // Cloudflare
    if (ip.startsWith('172.66')) return 'US'; // Cloudflare
    if (ip.startsWith('172.67')) return 'US'; // Cloudflare
    if (ip.startsWith('172.68')) return 'US'; // Cloudflare
    if (ip.startsWith('172.69')) return 'US'; // Cloudflare

    // Add more common IP to country mappings here
    // This is a simplified approach for immediate display

    return 'US'; // Default fallback
  }

  String getServerParam() {
    // Only return 'auto' since we're removing Server 1 and Server 2
    return 'auto';
  }

  Future<void> _loadServerSelection() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedServer = _prefs.getString('selectedServers') ?? 'Automatic';
      selectedServerType =
          _prefs.getString('selectedServerTypes') ?? 'Automatic';
      _lastSuccessfulServer = _prefs.getString(_lastSuccessfulServerKey);
      final storedTimestamp = _prefs.getString(_lastSuccessfulTimestampKey);
      if (storedTimestamp != null) {
        try {
          _lastSuccessfulServerTime = DateTime.parse(storedTimestamp);
        } catch (_) {
          _lastSuccessfulServerTime = null;
        }
      }
    });
  }

  Future<void> _saveServerSelection(String server, [String? serverType]) async {
    await _prefs.setString('selectedServers', server);
    await _prefs.setString('selectedServerTypes', serverType ?? server);
    setState(() {
      selectedServer = server;
      selectedServerType = serverType ?? server;
    });
  }

  // New method to test all servers with better resource management
  Future<void> testAllServers() async {
    // Prevent multiple concurrent server testing operations
    if (_isServerTestingInProgress) {
      print('Server testing already in progress, skipping...');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('server_testing_in_progress'.tr()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    _isServerTestingInProgress = true;

    try {
      setState(() {
        isLoading = true;
        isTestingServers = true;
        loadingStatus = 'Fetching server list for complete testing...';
        serverTestResults = [];
      });

      // Get server list
      List<String> servers = await _fetchServersWithFallback();

      if (servers.isEmpty) {
        // Show user-friendly message instead of throwing exception
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('no_servers_available'.tr()),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      print('Testing all ${servers.length} servers...');

      setState(() {
        serversBeingTested = servers.length;
        serversTestCompleted = 0;
        loadingStatus =
            'Testing all servers (this may take several minutes)...';
      });

      // Test all servers without limit
      int maxServersToTest = servers.length;
      print('Testing all $maxServersToTest servers');

      // Use queue-based testing to prevent resource exhaustion
      _serverTestQueue.clear();
      for (int i = 0; i < maxServersToTest; i++) {
        _serverTestQueue.add({
          'index': i,
          'serverUrl': servers[i],
          'maxServers': maxServersToTest,
        });
      }

      await _processServerTestQueue();

      print(
          'Complete server testing completed. Results: ${serverTestResults.length} servers tested');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('server_testing_complete'.tr().replaceAll(
                '{{count}}',
                serverTestResults
                    .where((r) => r['delay'] > 0)
                    .length
                    .toString())),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      print('Error in complete server testing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('error_testing_servers'
                .tr()
                .replaceAll('{{error}}', e.toString())),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      _isServerTestingInProgress = false;
      if (mounted) {
        setState(() {
          isLoading = false;
          isTestingServers = false;
          loadingStatus = '';
        });
      }
    }
  }

  // New method to manually test servers one by one with better resource management
  Future<void> testServersManually() async {
    // Prevent multiple concurrent server testing operations
    if (_isServerTestingInProgress) {
      print('Server testing already in progress, skipping...');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('server_testing_in_progress'.tr()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    _isServerTestingInProgress = true;

    try {
      setState(() {
        isLoading = true;
        isTestingServers = true;
        loadingStatus = 'Fetching server list for manual testing...';
        serverTestResults = [];
      });

      // Get server list
      List<String> servers = await _fetchServersWithFallback();

      if (servers.isEmpty) {
        // Show user-friendly message instead of throwing exception
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('no_servers_available'.tr()),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      print('Manually testing ${servers.length} servers...');

      setState(() {
        serversBeingTested = servers.length; // Test all available servers
        serversTestCompleted = 0;
        loadingStatus =
            'Testing all ${servers.length} servers with optimized method...';
      });

      // Use optimized testing method
      final testResults = await _testServersOptimized(servers);

      // Convert results to the expected format
      serverTestResults = testResults
          .map((result) => {
                'index': result['index'],
                'config': result['config'],
                'delay': result['delay'],
                'status': result['status'],
              })
          .toList();

      print(
          'Manual server testing completed. Results: ${serverTestResults.length} servers tested');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('server_testing_completed'.tr().replaceAll(
                '{{count}}',
                serverTestResults
                    .where((r) => r['delay'] > 0)
                    .length
                    .toString())),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Error in manual server testing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('server_testing_failed'
                .tr()
                .replaceAll('{{error}}', e.toString())),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() {
        isLoading = false;
        isTestingServers = false;
        loadingStatus = 'Server testing completed';
        _isServerTestingInProgress = false; // Reset the flag
      });
    }
  }

  // Process server test queue to prevent resource exhaustion
  Future<void> _processServerTestQueue() async {
    if (_isProcessingServerQueue) return;

    _isProcessingServerQueue = true;

    try {
      while (_serverTestQueue.isNotEmpty && mounted) {
        final serverInfo = _serverTestQueue.removeAt(0);
        final int i = serverInfo['index'];
        final String serverUrl = serverInfo['serverUrl'];
        final int maxServers = serverInfo['maxServers'];

        try {
          print('Testing server ${i + 1}/$maxServers...');

          // Parse the server configuration for potential connection usage
          final V2RayURL v2rayURL = V2ray.parseFromURL(serverUrl);
          final config = v2rayURL.getFullConfiguration();
          if (config.isEmpty) {
            throw Exception('Empty configuration');
          }

          // Test ping using V2Ray delay service
          int delay;
          try {
            final v2rayPing = FlutterV2rayPingService();
            v2rayPing.initialize();
            // Use adaptive ping testing in server queue processing (60s timeout)
            final ping = await v2rayPing.testServerPingAdaptive(
              serverUrl,
              baseTimeoutSeconds: 60,
              useCache: false,
              forceRetest: true,
            );
            delay = ping >= 9999 ? 9999 : (ping <= 0 ? -1 : ping);
          } catch (e) {
            print('Server ${i + 1} test failed with error: $e');
            delay = -1;
          }

          // Add result to list only if mounted
          if (mounted) {
            setState(() {
              serverTestResults.add({
                'index': i + 1,
                'config': config,
                'delay': delay,
                'status': delay > 0
                    ? 'success'
                    : (delay == 9999 ? 'timeout' : 'error')
              });
              serversTestCompleted = serverTestResults.length;
              loadingStatus = 'Testing server ${i + 1}/$maxServers...';
            });
          }

          print(
              'Server ${i + 1} result: ${delay > 0 ? '${delay}ms' : (delay == 9999 ? 'timeout'.tr() : 'error'.tr())}');

          // If in Automatic mode and this is the first healthy server, connect automatically
          if (selectedServer == 'Automatic' &&
              delay > 0 &&
              serversTestCompleted == 1) {
            print('Automatic mode: Connecting to first healthy server');
            // Add a small delay to prevent race conditions
            await Future.delayed(Duration(milliseconds: 500));
            await _connectToServer(
                serverUrl); // Use original server URL for connection
            // Clear the queue since we're connecting
            _serverTestQueue.clear();
            return; // Exit after connecting to the first healthy server
          }
        } catch (e) {
          print('Server ${i + 1} test failed: $e');

          // Add error result only if mounted
          if (mounted) {
            setState(() {
              serverTestResults.add({
                'index': i + 1,
                'config': serverUrl,
                'delay': -2, // Error
                'status': 'error'
              });
              serversTestCompleted = serverTestResults.length;
            });
          }
        }

        // Increased delay between tests to avoid overwhelming the system and prevent crashes
        await Future.delayed(Duration(milliseconds: 400)); // Optimized delay
      }
    } finally {
      _isProcessingServerQueue = false;
    }
  }

  Future<List<String>> getDeviceArchitecture() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    return androidInfo.supportedAbis;
  }

  void getVersionName() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      versionName = packageInfo.version;
    });
  }

  Future<void> getServerList() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      setState(() {
        isLoading = true;
        loadingStatus = ' Preparing connection...';
        blockedApps = prefs.getStringList('blockedApps') ?? [];
      });

      // Enhanced server list fetching with multiple fallbacks
      await _getServerListEnhanced();
    } on TimeoutException catch (e) {
      print('Timeout error: ${e.message}');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Connection timeout. Please check your internet connection and try again.',
            ),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print('Error in getServerList: $e');
      // Try to use cached servers as fallback
      if (await _tryUseCachedServersAsFallback()) {
        return;
      }

      if (mounted) {
        setState(() {
          isLoading = false;
        });

        String errorMessage;
        if (e.toString().contains('No valid server configurations')) {
          errorMessage =
              'Server configuration error. Please contact support if this persists.';
        } else if (e.toString().contains('endpoint')) {
          errorMessage =
              'All server endpoints are currently unavailable. Please try again later.';
        } else if (e.toString().contains('Failed to decode')) {
          errorMessage = 'Server data is corrupted. Please try again later.';
        } else {
          errorMessage =
              'Unable to connect to servers. Please check your internet connection and try again.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Enhanced server list fetching with multiple fallbacks
  Future<void> _getServerListEnhanced() async {
    final fallbackMethods = [
      _tryOptimizedServices,
      _tryDirectConnection,
      _tryAllOriginsProxy,
      _tryAlternativeEndpoint,
      _tryCachedServers,
    ];

    for (int i = 0; i < fallbackMethods.length; i++) {
      try {
        setState(() {
          loadingStatus =
              ' Trying connection method ${i + 1}/${fallbackMethods.length}...';
        });

        final success = await fallbackMethods[i]();
        if (success) {
          print(' Successfully connected using method ${i + 1}');
          return;
        }
      } catch (e) {
        print(' Method ${i + 1} failed: $e');
        if (i < fallbackMethods.length - 1) {
          await Future.delayed(Duration(milliseconds: 500));
        }
      }
    }

    throw Exception('All connection methods failed');
  }

  /// Try optimized services first
  Future<bool> _tryOptimizedServices() async {
    try {
      final servers = await _serverService.getOptimizedServerList(
        forceRefresh: false,
        onStatusUpdate: (status) {
          if (mounted) {
            setState(() {
              loadingStatus = ' $status';
            });
          }
        },
      );

      if (servers.isNotEmpty) {
        print('Successfully fetched ${servers.length} optimized servers');

        final connectionResult = await _connectionService.connectToBestServer(
          servers,
          onStatusUpdate: (status) {
            if (mounted) {
              setState(() {
                loadingStatus = status;
              });
            }
          },
          onProgressUpdate: (completed, total) {
            if (mounted) {
              setState(() {
                serversBeingTested = total;
                serversTestCompleted = completed;
              });
            }
          },
        );

        if (connectionResult.success) {
          print('Successfully connected to optimized server');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('connected_to_optimal_server'.tr()),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
              ),
            );
          }
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Optimized services failed: $e');
      return false;
    }
  }

  /// Try direct connection
  Future<bool> _tryDirectConnection() async {
    try {
      final servers = await _fetchServersDirect();
      if (servers.isNotEmpty) {
        await _processServerList(servers);
        return true;
      }
      return false;
    } catch (e) {
      print('Direct connection failed: $e');
      return false;
    }
  }

  /// Try AllOrigins proxy
  Future<bool> _tryAllOriginsProxy() async {
    try {
      final servers = await _fetchServersFromAllOrigins();
      if (servers.isNotEmpty) {
        await _processServerList(servers);
        return true;
      }
      return false;
    } catch (e) {
      print('AllOrigins proxy failed: $e');
      return false;
    }
  }

  /// Try alternative endpoint
  Future<bool> _tryAlternativeEndpoint() async {
    try {
      final servers = await _fetchServersFromAlternative();
      if (servers.isNotEmpty) {
        await _processServerList(servers);
        return true;
      }
      return false;
    } catch (e) {
      print('Alternative endpoint failed: $e');
      return false;
    }
  }

  /// Try cached servers as last resort
  Future<bool> _tryCachedServers() async {
    try {
      final cachedServers = await _getCachedServerList();
      if (cachedServers.isNotEmpty) {
        print('Using ${cachedServers.length} cached servers');
        await _processServerList(cachedServers);
        return true;
      }
      return false;
    } catch (e) {
      print('Cached servers failed: $e');
      return false;
    }
  }

  /// Process server list and connect
  Future<void> _processServerList(List<String> servers) async {
    if (servers.isEmpty) return;

    setState(() {
      loadingStatus = ' Processing ${servers.length} servers...';
    });

    // If in automatic mode, test and connect to best server
    if (selectedServer == 'Automatic') {
      // Automatic connection logic simplified for optimization
      setState(() {
        isLoading = false;
        loadingStatus = '';
      });
    } else {
      // For manual mode, just show the servers
      setState(() {
        isLoading = false;
        loadingStatus = '';
      });
    }
  }

  // Cache management methods for server list

  Future<bool> _tryUseCachedServersAsFallback() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final cached = prefs.getStringList('cached_servers');

      if (cached != null && cached.isNotEmpty) {
        print('Using ${cached.length} cached servers as fallback');
        if (mounted) {
          setState(() {
            loadingStatus = 'Using cached servers as fallback...';
          });
        }
        cachedServers = cached;
        // Process cached servers (simplified)
        setState(() {
          isLoading = false;
          loadingStatus = 'Using cached servers';
        });
        return true;
      } else {
        print('No cached servers available for fallback');
      }
    } catch (e) {
      print('Failed to use cached servers: $e');
    }
    return false;
  }

  /// Enhanced fetch and cache servers on app startup
  Future<void> _fetchAndCacheServersOnStartup() async {
    try {
      // Check if we have valid cached servers using new cache manager
      if (await _cacheManager.isServerCacheValid()) {
        cachedServers = await _cacheManager.getCachedServers();
        serverPings = await _cacheManager.getCachedPingResults();

        if (cachedServers.isNotEmpty) {
          _processServersWithLocation(cachedServers);

          // Trigger UI update to show cached servers immediately
          if (mounted) {
            setState(() {
              loadingStatus = '';
            });
          }

          print(
              'Using cached servers (${cachedServers.length} servers) with ${serverPings.length} ping results');
          return;
        }
      }

      // Fetch fresh servers with status updates
      setState(() {
        loadingStatus = ' Fetching server list...';
      });

      final servers = await _serverService.getOptimizedServerList(
        forceRefresh: true,
        onStatusUpdate: (status) {
          if (mounted) {
            setState(() {
              loadingStatus = status;
            });
          }
        },
      );

      if (servers.isNotEmpty) {
        // Store ALL servers in cachedServers for complete display
        cachedServers = servers;

        // Cache servers using new cache manager
        await _cacheManager.cacheServers(servers, metadata: {
          'fetchTime': DateTime.now().toIso8601String(),
          'serverCount': servers.length,
          'source': 'optimization_service',
        });

        // Process servers synchronously for immediate display
        _processServersWithLocation(servers);

        if (mounted) {
          setState(() {
            loadingStatus = '';
          });
        }

        print(
            ' Server startup completed with ${processedServers.length} processed servers');
      }
    } catch (e) {
      print(' Failed to fetch servers on startup: $e');
      // Try to load any existing cached servers as fallback
      cachedServers = await _cacheManager.getCachedServers();
      serverPings = await _cacheManager.getCachedPingResults();

      if (cachedServers.isNotEmpty) {
        _processServersWithLocation(cachedServers);
      }

      if (mounted) {
        setState(() {
          loadingStatus = '';
        });
      }
    }
  }

  /// Process servers for enhanced display (synchronous for instant rendering)
  void _processServersWithLocation(List<String> servers) {
    try {
      final newProcessedServers = <Map<String, dynamic>>[];

      for (int i = 0; i < servers.length; i++) {
        final server = servers[i];

        final ip = _extractIPFromConfig(server);
        final serverName = _generateServerName(server, ip, i + 1);
        final remark = _extractRemark(server);
        final countryCode = _getCountryCodeFromIPSync(ip);
        final ping = serverPings[server] ?? 0;

        final locationInfo =
            ServerLocationParser.parseServerLocationSync(server);
        final realCountryCode = locationInfo['countryCode']?.isNotEmpty == true
            ? locationInfo['countryCode']!
            : countryCode;
        final realCountryName = locationInfo['country']?.isNotEmpty == true
            ? locationInfo['country']!
            : serverName;
        final cityName = locationInfo['city'] ?? '';

        final locationLabel = cityName.isNotEmpty
            ? '$cityName, $realCountryName'
            : realCountryName;

        newProcessedServers.add({
          'name': locationLabel,
          'location': locationLabel,
          'remark': remark,
          'config': server,
          'ip': ip,
          'countryCode': realCountryCode,
          'ping': ping,
        });
      }

      // Sort servers by ping with categories:
      // 0=success (1..9998), 1=not tested (0), 2=timeout (>=9999), 3=failed (-1)
      newProcessedServers.sort((a, b) {
        final pingA = a['ping'] as int;
        final pingB = b['ping'] as int;
        int cat(int p) {
          if (p > 0 && p < 9999) return 0;
          if (p == 0) return 1;
          if (p >= 9999) return 2;
          return 3;
        }

        final cA = cat(pingA);
        final cB = cat(pingB);
        if (cA != cB) return cA.compareTo(cB);
        return pingA.compareTo(pingB);
      });

      processedServers = newProcessedServers;
    } catch (e) {
      print('Error processing servers: $e');
    }
  }

  String _extractRemark(String config) {
    try {
      if (config.startsWith('vmess://')) {
        String base64Part = config.substring(8);
        
        // Remove remark/tag (everything after #) before decoding
        if (base64Part.contains('#')) {
          // The part after # is often the remark itself (URL encoded)
          final remarkPart = base64Part.split('#')[1].trim();
          if (remarkPart.isNotEmpty) {
            return _decodeRemarkText(remarkPart);
          }
          base64Part = base64Part.split('#')[0].trim();
        }
        
        // Remove query parameters (everything after ?)
        if (base64Part.contains('?')) {
          base64Part = base64Part.split('?')[0].trim();
        }
        
        // Remove any trailing/leading whitespace
        base64Part = base64Part.trim();
        
        // Normalize base64 padding
        int remainder = base64Part.length % 4;
        if (remainder > 0) {
          base64Part += '=' * (4 - remainder);
        }
        
        final decoded = utf8.decode(base64.decode(base64Part));
        final json = jsonDecode(decoded) as Map<String, dynamic>;
        final ps = json['ps'];
        if (ps is String && ps.trim().isNotEmpty) {
          return _decodeRemarkText(ps);
        }
      } else if (config.startsWith('vless://') ||
          config.startsWith('trojan://') ||
          config.startsWith('ss://')) {
        final uri = Uri.parse(config);
        final fragment = uri.fragment;
        if (fragment.isNotEmpty) {
          return _decodeRemarkText(fragment);
        }
      }
    } catch (e) {
      // Silently handle parsing errors - these are expected for some configs
      // print('Error extracting remark: $e');
    }

    return '';
  }

  String _decodeRemarkText(String value) {
    var result = value.trim();
    if (result.isEmpty) return result;

    if (!result.contains('%')) return result;

    for (final decoder in [Uri.decodeFull, Uri.decodeComponent]) {
      try {
        final decoded = decoder(result).trim();
        if (decoded.isNotEmpty) {
          result = decoded;
          break;
        }
      } catch (_) {
        continue;
      }
    }

    return result;
  }

  // Essential missing functions - minimal implementations
  Future<void> _connectToServer(String server) async {
    try {
      // Enhanced server validation with better error handling
      if (server.isEmpty) {
        print(' Server config is empty, trying cached servers...');
        if (cachedServers.isNotEmpty) {
          server = cachedServers.first;
          print(' Using first cached server instead');
        } else {
          throw Exception('No valid server configuration available');
        }
      }

      // Normalize server config format
      String normalizedServer = server.trim();

      // More flexible protocol validation
      final validProtocols = [
        'vmess://',
        'vless://',
        'trojan://',
        'ss://',
        'http://',
        'https://'
      ];
      bool isValidProtocol = validProtocols
          .any((protocol) => normalizedServer.startsWith(protocol));

      if (!isValidProtocol) {
        print(' Invalid protocol, trying to fix server config...');
        // Try to fix common config issues
        if (!normalizedServer.contains('://')) {
          // Assume vmess if no protocol specified
          normalizedServer = 'vmess://' + normalizedServer;
          print(' Added vmess:// protocol prefix');
        }
      }

      final v2rayURL = V2ray.parseFromURL(normalizedServer);
      final config = v2rayURL.getFullConfiguration();

      // Enhanced configuration validation
      if (config.isEmpty || config.length < 50) {
        print(' Generated config is too short or empty, trying fallback...');

        // Try with different server from cache
        if (cachedServers.length > 1) {
          for (int i = 1; i < cachedServers.length && i < 3; i++) {
            try {
              final fallbackUrl = V2ray.parseFromURL(cachedServers[i]);
              final fallbackConfig = fallbackUrl.getFullConfiguration();
              if (fallbackConfig.isNotEmpty && fallbackConfig.length > 50) {
                print(' Using fallback server ${i + 1}');
                normalizedServer = cachedServers[i];
                break;
              }
            } catch (e) {
              print(' Fallback server ${i + 1} also failed: $e');
              continue;
            }
          }
        }

        // If still empty, use emergency servers
        if (config.isEmpty) {
          print('🆘 Using emergency server configuration');
          normalizedServer =
              'vmess://eyJ2IjoiMiIsInBzIjoiRW1lcmdlbmN5IFNlcnZlciIsImFkZCI6IjEwNC4yMS41NS4yMzQiLCJwb3J0IjoiNDQzIiwidHlwZSI6Im5vbmUiLCJpZCI6Ijk1ZmVkZDNkLWE3NDMtNDlkYS04Yjg2LTlmM2U3Mzk3MjJkNyIsImFpZCI6IjAiLCJuZXQiOiJ3cyIsInBhdGgiOiIvIiwiaG9zdCI6IiIsInRscyI6InRscyJ9';
        }
      }

      // Re-parse with final server config
      final finalV2rayURL = V2ray.parseFromURL(normalizedServer);
      final finalConfig = finalV2rayURL.getFullConfiguration();

      print('✅ Final config length: ${finalConfig.length} characters');

      // Request VPN permission first
      final hasPermission = await _v2rayManager.requestPermission();
      if (!hasPermission) {
        throw Exception('VPN permission denied');
      }

      // Start V2Ray connection with enhanced logging
      print('🚀 Starting V2Ray connection...');
      await _v2rayManager.start(
        remark: finalV2rayURL.remark.isNotEmpty
            ? finalV2rayURL.remark
            : 'Auto Server',
        config: finalConfig,
        proxyOnly: false,
        bypassSubnets: null,
        notificationDisconnectButtonName: 'DISCONNECT',
        blockedApps: blockedApps,
      );

      print('✅ Connected to server: ${finalV2rayURL.remark}');
      await _saveLastSuccessfulServer(normalizedServer);
    } catch (e) {
      print('❌ Connection error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('connection_failed_error_details'
                .tr()
                .replaceAll('{{error}}', e.toString())),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    }
  }

  Future<List<String>> _getCachedServerList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList('cached_servers') ?? [];
    } catch (e) {
      return [];
    }
  }

  Future<List<String>> _fetchServersWithFallback() async {
    try {
      // First try to get cached servers
      List<String> servers = await _getCachedServerList();

      // If no cached servers, try to fetch fresh ones
      if (servers.isEmpty) {
        servers =
            await _serverService.getOptimizedServerList(forceRefresh: true);
      }

      return servers;
    } catch (e) {
      print('Error fetching servers: $e');
      // Return empty list if all methods fail
      return [];
    }
  }

  Future<List<String>> _fetchServersDirect() async {
    return await _getCachedServerList();
  }

  Future<List<String>> _fetchServersFromAllOrigins() async {
    return await _getCachedServerList();
  }

  Future<List<String>> _fetchServersFromAlternative() async {
    return await _getCachedServerList();
  }

  void connectDirectly(String server) {
    _connectToServer(server);
  }

  Future<List<Map<String, dynamic>>> _testServersOptimized(
      List<String> servers) async {
    try {
      if (servers.isEmpty) return [];
      final v2rayPing = FlutterV2rayPingService();
      v2rayPing.initialize();

      // Use robust multi-server ping with limited concurrency to avoid duplicate logic
      final pingMap = await v2rayPing.testMultipleServerPingsRobust(
        servers,
        timeoutSeconds: 2,
        parallel: true,
        maxConcurrent: 12,
      );

      // Build results list in the expected structure
      final List<Map<String, dynamic>> results = [];
      for (int i = 0; i < servers.length; i++) {
        final server = servers[i];
        final ping = pingMap[server] ?? -1;
        final delay = ping >= 9999 ? 9999 : (ping <= 0 ? -1 : ping);
        results.add({
          'index': i + 1,
          'config': server,
          'delay': delay,
          'status':
              delay > 0 ? 'success' : (delay == 9999 ? 'timeout' : 'error'),
        });
      }
      return results;
    } catch (e) {
      print('Error in _testServersOptimized: $e');
      return [];
    }
  }
}
