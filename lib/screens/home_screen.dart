import 'dart:async';
import 'dart:convert';

import 'package:shinenet_vpn/common/http_client.dart';
import 'package:shinenet_vpn/widgets/connection_button.dart';
import 'package:shinenet_vpn/widgets/server_selection_modal_widget.dart';
import 'package:shinenet_vpn/widgets/vpn_status.dart';
import 'package:shinenet_vpn/widgets/connection_widget.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../common/theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final v2rayStatus = ValueNotifier<V2RayStatus>(V2RayStatus());
  late final FlutterV2ray flutterV2ray = FlutterV2ray(
    onStatusChanged: (status) {
      v2rayStatus.value = status;
    },
  );

  // UI State
  bool isLoading = false;
  String loadingStatus = '';
  int serversBeingTested = 0;
  int serversTestCompleted = 0;

  // Server State
  String selectedServer = 'Automatic';
  String selectedServerType = 'Automatic'; // Changed from selectedServerLogo
  int? connectedServerDelay;
  bool isFetchingPing = false;

  // Additional State
  bool proxyOnly = false;
  List<String> bypassSubnets = [];
  String? coreVersion;
  String? versionName;
  late SharedPreferences _prefs;
  List<String> blockedApps = [];

  // Server caching variables
  List<String>? cachedServers;
  DateTime? lastServerFetch;
  static const Duration cacheExpiry = Duration(minutes: 10);
  static const String cacheKey = 'cached_servers';
  static const String cacheTimeKey = 'cache_timestamp';

  // Connection retry variables
  int connectionRetryCount = 0;
  static const int maxRetries = 3;
  static const Duration initialRetryDelay = Duration(seconds: 2);

  Future<void> _handleConnectionToggle() async {
    if (v2rayStatus.value.state == 'CONNECTED') {
      await flutterV2ray.stopV2Ray();
    } else if (v2rayStatus.value.state != 'CONNECTING') {
      setState(() {
        isLoading = true;
      });
      
      try {
        await getServerList();
      } catch (e) {
        print(e);
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    }
  }


  @override
  void initState() {
    super.initState();
    getVersionName();
    _loadServerSelection();
    flutterV2ray
        .initializeV2Ray(
      notificationIconResourceType: "mipmap",
      notificationIconResourceName: "launcher_icon",
    )
        .then((value) async {
      coreVersion = await flutterV2ray.getCoreVersion();

      setState(() {});
      Future.delayed(
        Duration(seconds: 1),
        () {
          if (v2rayStatus.value.state == 'CONNECTED') {
            delay();
          }
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final bool isWideScreen = size.width > 600;

    return Scaffold(
      backgroundColor: ThemeColor.backgroundColor,
      body: SafeArea(
        child: ValueListenableBuilder<V2RayStatus>(
          valueListenable: v2rayStatus,
          builder: (context, status, _) {
            final bool isConnected = status.state == 'CONNECTED';
            final bool isConnecting = isLoading || status.state == 'CONNECTING';
            
            return CustomScrollView(
              slivers: [
                // Modern app bar
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  floating: true,
                  pinned: false,
                  expandedHeight: 80,
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: EdgeInsets.symmetric(
                      horizontal: ThemeColor.mediumSpacing,
                      vertical: ThemeColor.smallSpacing,
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ShineNET VPN',
                          style: ThemeColor.headingStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: ThemeColor.surfaceColor,
                            borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
                          ),
                          child: Icon(
                            Icons.settings_rounded,
                            color: ThemeColor.secondaryText,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Main content
                SliverPadding(
                  padding: EdgeInsets.all(ThemeColor.mediumSpacing),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Connection status card
                      _buildConnectionStatusCard(isConnected, isConnecting),
                      SizedBox(height: ThemeColor.mediumSpacing),
                      
                      // Server selection card
                      _buildModernServerSelectionCard(),
                      SizedBox(height: ThemeColor.mediumSpacing),
                      
                      // Connection section
                      if (isWideScreen)
                        _buildWideScreenLayout(status)
                      else
                        _buildMobileLayout(status),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // Modern connection status card
  Widget _buildConnectionStatusCard(bool isConnected, bool isConnecting) {
    String statusText;
    Color statusColor;
    IconData statusIcon;
    
    if (isConnected) {
      statusText = context.tr('connected');
      statusColor = ThemeColor.successColor;
      statusIcon = Icons.check_circle_rounded;
    } else if (isConnecting) {
      statusText = context.tr('connecting');
      statusColor = ThemeColor.warningColor;
      statusIcon = Icons.sync_rounded;
    } else {
      statusText = context.tr('disconnected');
      statusColor = ThemeColor.mutedText;
      statusIcon = Icons.radio_button_unchecked_rounded;
    }
    
    return AnimatedContainer(
      duration: ThemeColor.mediumAnimation,
      padding: EdgeInsets.all(ThemeColor.largeSpacing),
      decoration: ThemeColor.cardDecoration(
        withGradient: isConnected,
        withShadow: true,
      ),
      child: Row(
        children: [
          AnimatedRotation(
            turns: isConnecting ? 1 : 0,
            duration: ThemeColor.slowAnimation,
            child: Icon(
              statusIcon,
              color: statusColor,
              size: 28,
            ),
          ),
          SizedBox(width: ThemeColor.mediumSpacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connection Status',
                  style: ThemeColor.captionStyle(
                    color: ThemeColor.mutedText,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  statusText,
                  style: ThemeColor.bodyStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          if (isConnected && connectedServerDelay != null)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: ThemeColor.smallSpacing,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: ThemeColor.successColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
                border: Border.all(
                  color: ThemeColor.successColor.withOpacity(0.3),
                ),
              ),
              child: Text(
                '${connectedServerDelay}ms',
                style: ThemeColor.captionStyle(
                  color: ThemeColor.successColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Modern server selection card
  Widget _buildModernServerSelectionCard() {
    return AnimatedContainer(
      duration: ThemeColor.mediumAnimation,
      decoration: ThemeColor.cardDecoration(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
          onTap: () => _showServerSelectionModal(context),
          child: Padding(
            padding: EdgeInsets.all(ThemeColor.mediumSpacing),
            child: Row(
              children: [
                ThemeColor.buildServerIcon(
                  serverType: selectedServer,
                  size: 24,
                  isSelected: v2rayStatus.value.state == 'CONNECTED',
                ),
                SizedBox(width: ThemeColor.mediumSpacing),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selected Server',
                        style: ThemeColor.captionStyle(),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          ThemeColor.buildConnectionIndicator(
                            status: v2rayStatus.value.state,
                          ),
                          SizedBox(width: ThemeColor.smallSpacing),
                          Expanded(
                            child: Text(
                              selectedServer,
                              style: ThemeColor.bodyStyle(
                                fontWeight: FontWeight.w600,
                                color: ThemeColor.primaryText,
                              ),
                            ),
                          ),
                        ],
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

  PreferredSizeWidget _buildAppBar(bool isWideScreen) {
    return AppBar(
      title: Text(
        context.tr('app_title'),
        style: TextStyle(
          color: ThemeColor.foregroundColor,
          fontSize: isWideScreen ? 22 : 18,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            'assets/images/logo_transparent.png',
            color: ThemeColor.foregroundColor,
            height: 50,
          ),
        ),
      ],
      automaticallyImplyLeading: !isWideScreen,
      centerTitle: true,
      backgroundColor: ThemeColor.backgroundColor,
      elevation: 0,
    );
  }

  Widget _buildServerSelectionCard() {
    return _buildModernServerSelectionCard();
  }

  Widget _buildMainContent(bool isWideScreen) {
    return ValueListenableBuilder(
      valueListenable: v2rayStatus,
      builder: (context, value, child) {
        return isWideScreen
            ? _buildWideScreenLayout(value)
            : _buildMobileLayout(value);
      },
    );
  }

  Widget _buildWideScreenLayout(V2RayStatus value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: _buildConnectionSection(value),
        ),
        SizedBox(width: ThemeColor.largeSpacing),
        if (value.state == 'CONNECTED')
          Expanded(
            flex: 3,
            child: _buildStatsSection(value),
          ),
      ],
    );
  }

  Widget _buildMobileLayout(V2RayStatus value) {
    return Column(
      children: [
        _buildConnectionSection(value),
        if (value.state == 'CONNECTED') ...[
          SizedBox(height: ThemeColor.largeSpacing),
          _buildStatsSection(value),
        ],
      ],
    );
  }

  Widget _buildConnectionSection(V2RayStatus value) {
    return Container(
      decoration: ThemeColor.cardDecoration(),
      child: Padding(
        padding: EdgeInsets.all(ThemeColor.largeSpacing),
        child: Column(
          children: [
            ConnectionWidget(
              onTap: () => _handleConnectionTap(value),
              isLoading: isLoading,
              status: value.state,
            ),
            if (isLoading && loadingStatus.isNotEmpty) ...[
              SizedBox(height: ThemeColor.mediumSpacing),
              _buildLoadingStatus(),
            ],
            if (value.state == 'CONNECTED') ...[
              SizedBox(height: ThemeColor.mediumSpacing),
              _buildDelayIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(V2RayStatus value) {
    return Container(
      decoration: ThemeColor.cardDecoration(),
      child: Padding(
        padding: EdgeInsets.all(ThemeColor.largeSpacing),
        child: VpnCard(
          download: value.download,
          upload: value.upload,
          downloadSpeed: value.downloadSpeed,
          uploadSpeed: value.uploadSpeed,
          selectedServer: selectedServer,
          selectedServerType: selectedServerType,
          duration: value.duration,
        ),
      ),
    );
  }

  Widget _buildDelayIndicator() {
    return AnimatedContainer(
      duration: ThemeColor.mediumAnimation,
      margin: EdgeInsets.only(top: ThemeColor.smallSpacing),
      padding: EdgeInsets.symmetric(
        horizontal: ThemeColor.mediumSpacing,
        vertical: ThemeColor.smallSpacing,
      ),
      decoration: BoxDecoration(
        color: connectedServerDelay == null
            ? ThemeColor.connectingColor.withOpacity(0.1)
            : ThemeColor.connectedColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(ThemeColor.largeRadius),
        border: Border.all(
          color: connectedServerDelay == null
              ? ThemeColor.connectingColor.withOpacity(0.3)
              : ThemeColor.connectedColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: connectedServerDelay == null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LoadingAnimationWidget.threeArchedCircle(
                  color: ThemeColor.connectingColor,
                  size: 16,
                ),
                SizedBox(width: ThemeColor.smallSpacing),
                Text(
                  'Testing...',
                  style: ThemeColor.captionStyle(
                    color: ThemeColor.connectingColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            )
          : Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(ThemeColor.largeRadius),
                onTap: delay,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: ThemeColor.smallSpacing,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.wifi_rounded,
                        color: ThemeColor.connectedColor,
                        size: 16,
                      ),
                      SizedBox(width: ThemeColor.smallSpacing),
                      Text(
                        '${connectedServerDelay}ms',
                        style: ThemeColor.captionStyle(
                          color: ThemeColor.connectedColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.refresh_rounded,
                        color: ThemeColor.connectedColor,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildLoadingStatus() {
    return Container(
      padding: EdgeInsets.all(ThemeColor.mediumSpacing),
      decoration: ThemeColor.cardDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(ThemeColor.smallSpacing),
                decoration: BoxDecoration(
                  color: ThemeColor.connectingColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
                ),
                child: LoadingAnimationWidget.threeArchedCircle(
                  color: ThemeColor.connectingColor,
                  size: 24,
                ),
              ),
              SizedBox(width: ThemeColor.mediumSpacing),
              Flexible(
                child: Text(
                  loadingStatus,
                  style: ThemeColor.bodyStyle(
                    fontSize: 14,
                    color: ThemeColor.secondaryText,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          if (serversBeingTested > 0 && serversTestCompleted > 0) ...[
            SizedBox(height: ThemeColor.mediumSpacing),
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Testing servers...',
                      style: ThemeColor.captionStyle(),
                    ),
                    Text(
                      '$serversTestCompleted/$serversBeingTested',
                      style: ThemeColor.captionStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: ThemeColor.smallSpacing),
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: ThemeColor.surfaceColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Stack(
                    children: [
                      AnimatedContainer(
                        duration: ThemeColor.mediumAnimation,
                        width: (MediaQuery.of(context).size.width - 80) *
                            (serversTestCompleted / serversBeingTested),
                        height: 4,
                        decoration: BoxDecoration(
                          gradient: ThemeColor.primaryGradient,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _handleConnectionTap(V2RayStatus value) async {
    if (value.state == "DISCONNECTED") {
      connectionRetryCount = 0; // Reset retry count for new connection attempt
      await _connectWithRetry();
    } else {
      flutterV2ray.stopV2Ray();
    }
  }

  Future<void> _connectWithRetry() async {
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        await getServerList();
        return; // Connection successful, exit retry loop
      } catch (e) {
        print('Connection attempt ${attempt + 1} failed: $e');

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
          // Final attempt failed
          if (mounted) {
            setState(() {
              isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  context.tr('error_max_retries_reached'),
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    }
  }

  void _showServerSelectionModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (BuildContext context) {
        return ServerSelectionModal(
          selectedServer: selectedServer,
          onServerSelected: (server) {
            if (v2rayStatus.value.state == "DISCONNECTED") {
              setState(() {
                selectedServer = server;
              });
              _saveServerSelection(server);
              Navigator.pop(context);
            } else {
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context.tr('error_change_server'),
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          },
        );
      },
    );
  }

  String getServerParam() {
    if (selectedServer == 'Server 1') {
      return 'server_1';
    } else if (selectedServer == 'Server 2') {
      return 'server_2';
    } else {
      return 'auto';
    }
  }

  Future<void> _loadServerSelection() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedServer = _prefs.getString('selectedServers') ?? 'Automatic';
      selectedServerType = _prefs.getString('selectedServerTypes') ?? 'Automatic';
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
        loadingStatus = 'Preparing connection...';
        blockedApps = prefs.getStringList('blockedApps') ?? [];
      });

      // Check if cached servers are still valid
      if (await _isCacheValid(prefs)) {
        print('Using cached server list');
        setState(() {
          loadingStatus = 'Using cached servers...';
        });
        cachedServers = prefs.getStringList(cacheKey) ?? [];
        await connect(cachedServers!);
        return;
      }

      // Try multiple endpoints for better reliability
      List<String> servers = await _fetchServersWithFallback();

      if (servers.isEmpty) {
        throw Exception('No valid server configurations found');
      }

      // Cache the servers
      await _cacheServers(prefs, servers);
      cachedServers = servers;

      // Connect with the filtered server list
      await connect(servers);
    } on TimeoutException catch (e) {
      // Try to use cached servers as fallback
      if (await _tryUseCachedServersAsFallback()) {
        return;
      }

      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.message!,
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Try to use cached servers as fallback
      if (await _tryUseCachedServersAsFallback()) {
        return;
      }

      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('error_domain')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<List<String>> _fetchServersWithFallback() async {
    // Try direct connection first (primary method)
    try {
      return await _fetchServersDirect();
    } catch (e) {
      print('Direct connection failed: $e, trying alternative endpoint');
      setState(() {
        loadingStatus = 'Trying alternative endpoint...';
      });

      // Try alternative direct endpoint
      try {
        return await _fetchServersFromAlternative();
      } catch (e2) {
        print('Alternative endpoint failed: $e2, trying AllOrigins proxy');
        setState(() {
          loadingStatus = 'Trying proxy endpoint...';
        });

        // Fallback to AllOrigins proxy
        try {
          return await _fetchServersFromAllOrigins();
        } catch (e3) {
          print('AllOrigins proxy failed: $e3');
          throw Exception('All endpoints failed. Direct: $e, Alternative: $e2, AllOrigins: $e3');
        }
      }
    }
  }

  Future<List<String>> _fetchServersFromAllOrigins() async {
    print('Fetching server list via AllOrigins proxy');
    setState(() {
      loadingStatus = 'Fetching server list via proxy...';
    });

    final response = await httpClient
        .get(
      'https://api.allorigins.win/get?url=https://v2ray.shayanheidari01.workers.dev/',
      options: Options(
        headers: {
          'X-Content-Type-Options': 'nosniff',
          'Accept': 'application/json',
        },
      ),
    )
        .timeout(
      Duration(seconds: 12), // Longer timeout for proxy service
      onTimeout: () {
        throw TimeoutException('AllOrigins proxy timeout');
      },
    );

    // Parse the AllOrigins response
    if (response.data == null) {
      throw Exception('Empty response from AllOrigins proxy');
    }

    Map<String, dynamic> allOriginsResponse;
    try {
      allOriginsResponse =
          response.data is String ? json.decode(response.data) : response.data;
    } catch (e) {
      throw Exception('Failed to parse AllOrigins response: $e');
    }

    // Check if the request was successful
    if (allOriginsResponse.containsKey('status')) {
      final status = allOriginsResponse['status'];
      if (status is Map) {
        final httpCode = status['http_code'];
        final responseTime = status['response_time'];
        final contentLength = status['content_length'];

        print(
            'AllOrigins Status: HTTP $httpCode, ${responseTime}ms, ${contentLength} bytes');

        if (httpCode != 200) {
          throw Exception('AllOrigins returned HTTP $httpCode');
        }

        // Log performance for monitoring
        if (responseTime != null && responseTime > 5000) {
          print('Warning: Slow AllOrigins response time: ${responseTime}ms');
        }
      }
    }

    // Extract the contents from AllOrigins response
    if (!allOriginsResponse.containsKey('contents')) {
      throw Exception('Invalid AllOrigins response format - missing contents');
    }

    String base64Data = allOriginsResponse['contents'];
    if (base64Data.isEmpty) {
      throw Exception('Empty content from AllOrigins proxy');
    }

    return _processServerData(base64Data);
  }

  Future<List<String>> _fetchServersDirect() async {
    print('Fetching server list directly');
    setState(() {
      loadingStatus = 'Fetching server list directly...';
    });

    final response = await httpClient
        .get(
      'https://v2ray.shayanheidari01.workers.dev/',
      options: Options(
        headers: {
          'X-Content-Type-Options': 'nosniff',
        },
      ),
    )
        .timeout(
      Duration(seconds: 8),
      onTimeout: () {
        throw TimeoutException('Direct connection timeout');
      },
    );

    String base64Data = response.data;
    if (base64Data.isEmpty) {
      throw Exception('Empty response from direct connection');
    }

    return _processServerData(base64Data);
  }

  Future<List<String>> _fetchServersFromAlternative() async {
    print('Fetching server list from alternative endpoint');
    setState(() {
      loadingStatus = 'Fetching from alternative endpoint...';
    });

    final response = await httpClient
        .get(
      'https://far-sheep-86.shayanheidari01.deno.net/',
      options: Options(
        headers: {
          'X-Content-Type-Options': 'nosniff',
        },
      ),
    )
        .timeout(
      Duration(seconds: 8),
      onTimeout: () {
        throw TimeoutException('Alternative endpoint timeout');
      },
    );

    String base64Data = response.data;
    if (base64Data.isEmpty) {
      throw Exception('Empty response from alternative endpoint');
    }

    return _processServerData(base64Data);
  }

  List<String> _processServerData(String base64Data) {
    setState(() {
      loadingStatus = 'Processing server configurations...';
    });

    String decodedData;
    try {
      decodedData = utf8.decode(base64.decode(base64Data));
    } catch (e) {
      throw Exception('Failed to decode base64 data: $e');
    }

    if (decodedData.isEmpty) {
      throw Exception('Decoded data is empty');
    }

    // Split into server list and filter valid server configurations
    List<String> allLines = LineSplitter.split(decodedData).toList();
    List<String> servers = allLines
        .where((line) =>
            line.trim().isNotEmpty &&
            !line.startsWith('//') &&
            (line.startsWith('ss://') ||
                line.startsWith('vless://') ||
                line.startsWith('vmess://') ||
                line.startsWith('trojan://')))
        .toList();

    print('Found ${servers.length} valid server configurations');

    if (servers.isEmpty) {
      throw Exception('No valid server configurations found in response');
    }

    return servers;
  }

  Future<void> connect(List<String> serverList) async {
    if (serverList.isEmpty) {
      // سرور یافت نشد
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('error_no_server_connected'),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      setState(() {
        isLoading = false;
      });
      return;
    }

    List<String> list = [];

    serverList.forEach((element) {
      final V2RayURL v2rayURL = FlutterV2ray.parseFromURL(element);

      list.add(v2rayURL.getFullConfiguration());
    });

    setState(() {
      isLoading = true;
      loadingStatus = 'Testing server connections...';
      serversBeingTested = list.length;
      serversTestCompleted = 0;
    });

    Map<String, dynamic> getAllDelay = {};

    // Get delay for each server configuration in parallel
    List<Future<void>> delayTasks = list.asMap().entries.map((entry) async {
      int index = entry.key;
      String config = entry.value;
      try {
        int delay = await flutterV2ray
            .getServerDelay(config: config)
            .timeout(Duration(seconds: 5)); // Individual timeout for each test
        getAllDelay[config] = delay;
      } catch (e) {
        getAllDelay[config] = -1; // Mark as failed
      } finally {
        setState(() {
          serversTestCompleted++;
          loadingStatus =
              'Testing servers... (${serversTestCompleted}/${serversBeingTested})';
        });
      }
    }).toList();

    // Wait for all delay tests to complete with overall timeout
    try {
      await Future.wait(delayTasks).timeout(Duration(seconds: 15));
    } catch (e) {
      print('Some delay tests timed out: $e');
      // Continue with available results
    }

    list.clear();

    setState(() {
      loadingStatus = 'Selecting best server...';
    });

    int minPing = 99999999;
    String bestConfig = '';

    getAllDelay.forEach(
      (key, value) {
        if (value < minPing && value != -1) {
          setState(() {
            bestConfig = key;
            minPing = value;
          });
        }
      },
    );

    if (bestConfig.isNotEmpty) {
      if (await flutterV2ray.requestPermission()) {
        flutterV2ray.startV2Ray(
          remark: context.tr('app_title'),
          config: bestConfig,
          proxyOnly: false,
          bypassSubnets: null,
          notificationDisconnectButtonName: context.tr('disconnect_btn'),
          blockedApps: blockedApps,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('error_permission')),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('error_no_server_connected'),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    Future.delayed(
      Duration(seconds: 1),
      () {
        delay();
      },
    );
    setState(() {
      isLoading = false;
      loadingStatus = '';
      serversBeingTested = 0;
      serversTestCompleted = 0;
    });
  }

  void delay() async {
    if (v2rayStatus.value.state == 'CONNECTED') {
      connectedServerDelay = await flutterV2ray.getConnectedServerDelay();
      setState(() {
        isFetchingPing = true;
      });
    }
    if (!mounted) return;
  }

  // Cache management methods
  Future<bool> _isCacheValid(SharedPreferences prefs) async {
    final cacheTimeString = prefs.getString(cacheTimeKey);
    if (cacheTimeString == null) return false;

    final cacheTime = DateTime.parse(cacheTimeString);
    final now = DateTime.now();

    return now.difference(cacheTime) < cacheExpiry &&
        prefs.getStringList(cacheKey) != null;
  }

  Future<void> _cacheServers(
      SharedPreferences prefs, List<String> servers) async {
    await prefs.setStringList(cacheKey, servers);
    await prefs.setString(cacheTimeKey, DateTime.now().toIso8601String());
    lastServerFetch = DateTime.now();
  }

  Future<bool> _tryUseCachedServersAsFallback() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final cached = prefs.getStringList(cacheKey);

      if (cached != null && cached.isNotEmpty) {
        print('Using cached servers as fallback');
        cachedServers = cached;
        await connect(cached);
        return true;
      }
    } catch (e) {
      print('Failed to use cached servers: $e');
    }
    return false;
  }
}
