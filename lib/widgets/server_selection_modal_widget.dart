import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shinenet_vpn/common/theme.dart';
import 'package:shinenet_vpn/services/unified_ping_manager.dart';

class ServerInfo {
  final String name;
  final String config;
  final String? ip;
  final String? countryCode;
  final int? ping;
  final String? remark;

  ServerInfo({
    required this.name,
    required this.config,
    this.ip,
    this.countryCode,
    this.ping,
    this.remark,
  });
}

class ServerSelectionModal extends StatefulWidget {
  final String selectedServer;
  final ValueChanged<String> onServerSelected;
  final List<ServerInfo> healthyServers;

  const ServerSelectionModal({
    super.key,
    required this.selectedServer,
    required this.onServerSelected,
    this.healthyServers = const [],
  });

  @override
  State<ServerSelectionModal> createState() => _ServerSelectionModalState();
}

class _ServerSelectionModalState extends State<ServerSelectionModal>
    with TickerProviderStateMixin {
  late final List<ServerInfo> _allServers;
  late List<ServerInfo> _visibleServers;
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Unified ping manager for real-time ping updates
  final UnifiedPingManager _pingManager = UnifiedPingManager();
  StreamSubscription<Map<String, PingResult>>? _pingUpdateSubscription;
  
  // Real-time ping results
  Map<String, PingResult> _livePingResults = {};
  bool _isLivePingTesting = false;

  @override
  void initState() {
    super.initState();
    _allServers = List<ServerInfo>.from(widget.healthyServers)
      ..sort(_compareByPing);
    _visibleServers = List<ServerInfo>.from(_allServers);
    _searchController.addListener(_handleSearchChanged);
    
    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    // Start entrance animation
    _animationController.forward();
    
    // Initialize ping system
    _initializePingSystem();
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    _animationController.dispose();
    _pingUpdateSubscription?.cancel();
    super.dispose();
  }
  
  /// Initialize ping system with real-time updates
  void _initializePingSystem() {
    // Initialize ping manager
    _pingManager.initialize();
    
    // Subscribe to real-time ping updates
    _pingUpdateSubscription = _pingManager.pingUpdates.listen((updates) {
      if (mounted) {
        setState(() {
          _livePingResults.addAll(updates);
          // Update server ping data
          for (final server in _allServers) {
            final pingResult = _livePingResults[server.config];
            if (pingResult != null) {
              // Update server ping data in place
              final updatedServer = ServerInfo(
                name: server.name,
                config: server.config,
                ip: server.ip,
                countryCode: server.countryCode,
                ping: pingResult.pingMs,
                remark: server.remark,
              );
              final index = _allServers.indexOf(server);
              if (index >= 0) {
                _allServers[index] = updatedServer;
              }
            }
          }
          // Re-sort servers by updated ping
          _allServers.sort(_compareByPing);
          _handleSearchChanged(); // Refresh visible servers
        });
      }
    });
    
    // Load cached ping results
    _loadCachedPingResults();
    
    // Start live ping testing
    _startLivePingTesting();
  }
  
  /// Load cached ping results for immediate display
  void _loadCachedPingResults() {
    final serverConfigs = _allServers
        .map((server) => server.config)
        .where((config) => config.isNotEmpty && config != 'Automatic')
        .toList();
    
    final cachedResults = _pingManager.getCachedResults(serverConfigs);
    if (cachedResults.isNotEmpty && mounted) {
      setState(() {
        _livePingResults.addAll(cachedResults);
      });
    }
  }
  
  /// Start live ping testing for all servers
  void _startLivePingTesting() async {
    if (_isLivePingTesting) return;
    
    setState(() {
      _isLivePingTesting = true;
    });
    
    final serverConfigs = _allServers
        .map((server) => server.config)
        .where((config) => config.isNotEmpty && config != 'Automatic')
        .toList();
    
    if (serverConfigs.isNotEmpty) {
      // Start ping testing in background
      _pingManager.getPingResults(
        serverConfigs,
        timeoutSeconds: 3,
        useCache: true,
        parallel: true,
        onProgress: (server, result) {
          // Progress updates handled by stream subscription
        },
      ).then((_) {
        if (mounted) {
          setState(() {
            _isLivePingTesting = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: bottomInset + 16,
        ),
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: mediaQuery.size.height * 0.88,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(Radius.circular(28)),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(28)),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.15),
                              Colors.white.withValues(alpha: 0.05),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1.5,
                          ),
                          borderRadius: const BorderRadius.all(Radius.circular(28)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildGlassHeader(context),
                            _buildSearchSection(context),
                            _buildAutomaticSection(context),
                            Expanded(
                              child: _visibleServers.isEmpty
                                  ? _buildEmptyState(context)
                                  : _buildServerList(context),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _handleSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();

    setState(() {
      if (query.isEmpty) {
        _visibleServers = List<ServerInfo>.from(_allServers);
        return;
      }

      _visibleServers = _allServers.where((server) {
        final name = server.name.toLowerCase();
        final ip = (server.ip ?? '').toLowerCase();
        final remark = (server.remark ?? '').toLowerCase();
        return name.contains(query) || ip.contains(query) || remark.contains(query);
      }).toList();
    });
  }

  Widget _buildGlassHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          // Title section
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      ThemeColor.primaryColor.withValues(alpha: 0.2),
                      ThemeColor.primaryColor.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: ThemeColor.primaryColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.dns_rounded,
                  color: ThemeColor.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'select_server_title'.tr(),
                      style: ThemeColor.headingStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        context: context,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isLivePingTesting 
                          ? 'testing_servers_unified'.tr(namedArgs: {'count': _allServers.length.toString()})
                          : 'server_count'.tr(namedArgs: {'count': _allServers.length.toString()}),
                      style: ThemeColor.captionStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.7),
                        context: context,
                      ),
                    ),
                    // Show progress indicator when testing
                    if (_isLivePingTesting) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(ThemeColor.primaryColor),
                        minHeight: 2,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              style: ThemeColor.bodyStyle(
                fontSize: 16,
                color: Colors.white,
                context: context,
              ),
              decoration: InputDecoration(
                prefixIcon: Container(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.search_rounded,
                    color: Colors.white.withValues(alpha: 0.6),
                    size: 20,
                  ),
                ),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          _handleSearchChanged();
                        },
                        icon: Icon(
                          Icons.clear_rounded,
                          color: Colors.white.withValues(alpha: 0.6),
                          size: 20,
                        ),
                      ),
                hintText: 'search_placeholder'.tr(),
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 16,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAutomaticSection(BuildContext context) {
    final isSelected = widget.selectedServer == 'Automatic';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: GestureDetector(
        onTap: () => _selectServer('Automatic'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      ThemeColor.primaryColor.withValues(alpha: 0.3),
                      ThemeColor.primaryColor.withValues(alpha: 0.1),
                    ],
                  )
                : LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.1),
                      Colors.white.withValues(alpha: 0.05),
                    ],
                  ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? ThemeColor.primaryColor.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isSelected
                        ? [
                            ThemeColor.primaryColor,
                            ThemeColor.primaryColor.withValues(alpha: 0.8),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.2),
                            Colors.white.withValues(alpha: 0.1),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.8),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'automatic'.tr(),
                      style: ThemeColor.bodyStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        context: context,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'automatic_description'.tr(),
                      style: ThemeColor.captionStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.7),
                        context: context,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? ThemeColor.primaryColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  isSelected ? Icons.check_rounded : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServerList(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: ListView.separated(
        physics: const BouncingScrollPhysics(),
        itemCount: _visibleServers.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final server = _visibleServers[index];
          return _buildGlassServerTile(context, server, index);
        },
      ),
    );
  }

  Widget _buildGlassServerTile(BuildContext context, ServerInfo server, int index) {
    final isSelected = widget.selectedServer == server.config ||
        widget.selectedServer == server.name;
    final ping = server.ping ?? 0;

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * value),
          child: Opacity(
            opacity: value,
            child: GestureDetector(
              onTap: () => _selectServer(server.config),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                transform: Matrix4.identity()..scale(isSelected ? 1.02 : 1.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  ThemeColor.primaryColor.withValues(alpha: 0.25),
                                  ThemeColor.primaryColor.withValues(alpha: 0.1),
                                ],
                              )
                            : LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withValues(alpha: 0.12),
                                  Colors.white.withValues(alpha: 0.06),
                                ],
                              ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? ThemeColor.primaryColor.withValues(alpha: 0.4)
                              : Colors.white.withValues(alpha: 0.15),
                          width: 1.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: ThemeColor.primaryColor.withValues(alpha: 0.2),
                                  blurRadius: 20,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 8),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          // Server icon
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isSelected
                                    ? [
                                        ThemeColor.primaryColor.withValues(alpha: 0.8),
                                        ThemeColor.primaryColor.withValues(alpha: 0.6),
                                      ]
                                    : [
                                        Colors.white.withValues(alpha: 0.2),
                                        Colors.white.withValues(alpha: 0.1),
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.dns_rounded,
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.8),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Server info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  server.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: ThemeColor.bodyStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    context: context,
                                  ),
                                ),
                                if (server.remark != null && server.remark!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    server.remark!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: ThemeColor.captionStyle(
                                      fontSize: 13,
                                      color: Colors.white.withValues(alpha: 0.7),
                                      context: context,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Ping indicator
                          _buildGlassPingIndicator(ping),
                          const SizedBox(width: 12),
                          // Selection indicator
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? ThemeColor.primaryColor
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              isSelected ? Icons.check_rounded : Icons.radio_button_unchecked_rounded,
                              color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGlassPingIndicator(int ping) {
    final color = _getPingColor(ping);
    final label = _getPingLabel(ping);
    final isLiveTesting = _isLivePingTesting && ping == 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.2),
            color.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Show loading indicator for live testing
          if (isLiveTesting) ...[
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(width: 4),
          ] else if (ping < 100 && ping > 0) ...[
            Icon(
              Icons.flash_on,
              size: 12,
              color: color,
            ),
            const SizedBox(width: 2),
          ] else if (ping < 0) ...[
            Icon(
              Icons.error_outline,
              size: 12,
              color: color,
            ),
            const SizedBox(width: 2),
          ] else if (ping >= 9999) ...[
            Icon(
              Icons.access_time,
              size: 12,
              color: color,
            ),
            const SizedBox(width: 2),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getPingColor(int ping) {
    if (ping < 0) return Colors.red;
    if (ping == 0) return Colors.grey;
    if (ping >= 9999) return Colors.orange;
    if (ping < 100) return Colors.green;
    if (ping < 300) return Colors.yellow;
    return Colors.orange;
  }

  String _getPingLabel(int ping) {
    if (ping < 0) return 'خطا';
    if (ping == 0) return 'تست';
    if (ping >= 9999) return 'بالا';
    return '${ping}ms';
  }

  Widget _buildEmptyState(BuildContext context) {
    final hasSearch = _searchController.text.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.1),
                    Colors.white.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Icon(
                hasSearch ? Icons.search_off_rounded : Icons.dns_rounded,
                size: 48,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              hasSearch ? 'no_servers_match_filter'.tr() : 'no_servers_available'.tr(),
              textAlign: TextAlign.center,
              style: ThemeColor.bodyStyle(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.8),
                context: context,
              ),
            ),
            const SizedBox(height: 16),
            if (hasSearch)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  _handleSearchChanged();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        ThemeColor.primaryColor.withValues(alpha: 0.2),
                        ThemeColor.primaryColor.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: ThemeColor.primaryColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'clear_filters'.tr(),
                    style: TextStyle(
                      color: ThemeColor.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  int _compareByPing(ServerInfo a, ServerInfo b) {
    final pingA = a.ping ?? 0;
    final pingB = b.ping ?? 0;

    int rank(int ping) {
      if (ping <= 0) return 3; // failed or unknown
      if (ping >= 9999) return 2; // timeout
      return 1; // valid ping
    }

    final rankA = rank(pingA);
    final rankB = rank(pingB);
    if (rankA != rankB) return rankA.compareTo(rankB);

    return pingA.compareTo(pingB);
  }

  void _selectServer(String server) {
    HapticFeedback.lightImpact();
    widget.onServerSelected(server);
  }
}
