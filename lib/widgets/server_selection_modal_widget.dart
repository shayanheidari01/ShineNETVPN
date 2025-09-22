import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shinenet_vpn/common/theme.dart';
import 'package:shinenet_vpn/widgets/simple_server_list_widget.dart';
import 'package:shinenet_vpn/services/flutter_v2ray_ping_service.dart';

class ServerInfo {
  final String name;
  final String config;
  final String? ip;
  final String? countryCode;
  final int? ping;
  
  ServerInfo({
    required this.name,
    required this.config,
    this.ip,
    this.countryCode,
    this.ping,
  });
}

class ServerSelectionModal extends StatefulWidget {
  final String selectedServer;
  final Function(String) onServerSelected;
  final List<ServerInfo> healthyServers;

  ServerSelectionModal({
    required this.selectedServer, 
    required this.onServerSelected,
    this.healthyServers = const [],
  });

  @override
  _ServerSelectionModalState createState() => _ServerSelectionModalState();
}

class _ServerSelectionModalState extends State<ServerSelectionModal> {
  List<ServerInfo> _serversWithLivePing = [];
  bool _isTestingPing = false;
  Timer? _pingUpdateTimer;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filter = 'all'; // all | fast | good | timeout | failed
  String _sortKey = 'ping'; // ping | name
  bool _sortAsc = true;

  @override
  void initState() {
    super.initState();
    // Sort initial servers by existing ping values
    _serversWithLivePing = _sortServers(List.from(widget.healthyServers));
    print('📋 Server selection modal opened with ${_serversWithLivePing.length} servers (ping test will run once)');
    
    // Start initial ping testing (only once)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startLivePingTesting();
      // Remove periodic updates - ping only once when modal opens
      // _setupPeriodicPingUpdates();
    });

    // Listen to search query changes
    _searchController.addListener(() {
      if (!mounted) return;
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    // Cancel periodic timer if it exists
    _pingUpdateTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Sort controls (Ping/Name + Asc/Desc)
  Widget _buildSortControls() {
    return Padding(
      padding: EdgeInsets.fromLTRB(ThemeColor.largeSpacing, 8, ThemeColor.largeSpacing, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('sort_by'.tr(), style: ThemeColor.captionStyle()),
          ChoiceChip(
            label: Text('ping'.tr(), style: ThemeColor.captionStyle(color: _sortKey == 'ping' ? Colors.white : ThemeColor.mutedText)),
            selected: _sortKey == 'ping',
            selectedColor: ThemeColor.primaryColor,
            backgroundColor: ThemeColor.surfaceColor,
            onSelected: (_) => setState(() => _sortKey = 'ping'),
          ),
          ChoiceChip(
            label: Text('name'.tr(), style: ThemeColor.captionStyle(color: _sortKey == 'name' ? Colors.white : ThemeColor.mutedText)),
            selected: _sortKey == 'name',
            selectedColor: ThemeColor.primaryColor,
            backgroundColor: ThemeColor.surfaceColor,
            onSelected: (_) => setState(() => _sortKey = 'name'),
          ),
          Text(_sortAsc ? 'sort_ascending'.tr() : 'sort_descending'.tr(), style: ThemeColor.captionStyle()),
          IconButton(
            tooltip: _sortAsc ? 'sort_descending'.tr() : 'sort_ascending'.tr(),
            onPressed: () => setState(() => _sortAsc = !_sortAsc),
            icon: Icon(_sortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, color: ThemeColor.primaryColor, size: 18),
          ),
        ],
      ),
    );
  }

  /// Metrics header: counts and progress
  Widget _buildMetricsHeader() {
    final total = _serversWithLivePing.length;
    final tested = _serversWithLivePing.where((s) => (s.ping ?? 0) != 0).length;
    final successes = _serversWithLivePing.where((s) => (s.ping ?? 0) > 0 && (s.ping ?? 0) < 9999).length;
    final best = _serversWithLivePing
        .where((s) => (s.ping ?? 0) > 0 && (s.ping ?? 0) < 9999)
        .map((s) => s.ping!)
        .fold<int?>(null, (min, p) => min == null ? p : (p < min ? p : min));

    final progress = total > 0 ? tested / total : 0.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(ThemeColor.largeSpacing, 8, ThemeColor.largeSpacing, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: ThemeColor.borderColor,
                  valueColor: AlwaysStoppedAnimation<Color>(ThemeColor.primaryColor),
                  minHeight: 6,
                ),
              ),
              SizedBox(width: ThemeColor.smallSpacing),
              Text('$tested/$total', style: ThemeColor.captionStyle()),
            ],
          ),
          SizedBox(height: ThemeColor.smallSpacing),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text('servers_available'.tr(), style: ThemeColor.captionStyle()),
              Text(' • ', style: ThemeColor.captionStyle()),
              Text('${'ping'.tr()}: ${best != null ? '${best}ms' : 'not_available_short'.tr()}', style: ThemeColor.captionStyle()),
              Text(' • ', style: ThemeColor.captionStyle()),
              Text('${'excellent'.tr()}: $successes', style: ThemeColor.captionStyle()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQualityLegend() {
    Widget dot(Color c) => Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle));
    return Padding(
      padding: EdgeInsets.fromLTRB(ThemeColor.largeSpacing, 6, ThemeColor.largeSpacing, 0),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          dot(ThemeColor.successColor), Text('excellent'.tr(), style: ThemeColor.captionStyle()),
          dot(ThemeColor.warningColor), Text('good'.tr(), style: ThemeColor.captionStyle()),
          dot(ThemeColor.errorColor), Text('poor'.tr(), style: ThemeColor.captionStyle()),
          dot(Colors.orange), Text('timeout'.tr(), style: ThemeColor.captionStyle()),
          dot(ThemeColor.errorColor), Text('failed'.tr(), style: ThemeColor.captionStyle()),
        ],
      ),
    );
  }

  /// Start live ping testing for all servers
  void _startLivePingTesting() async {
    if (_serversWithLivePing.isEmpty || _isTestingPing) return;
    
    setState(() {
      _isTestingPing = true;
    });

    // Test ping for each server with V2Ray delay API (concurrently with limits)
    final v2rayPing = FlutterV2rayPingService();
    v2rayPing.initialize();
    // Skip Automatic sentinel if present
    final toTest = _serversWithLivePing.where((s) => s.config != 'Automatic').toList();

    final updated = List<ServerInfo>.from(_serversWithLivePing);
    final total = toTest.length;
    int completed = 0;

    // Use high-speed intelligent ping testing with parallel processing (60s timeout)
    await v2rayPing.testMultipleServerPingsIntelligent(
      toTest.map((s) => s.config).toList(),
      baseTimeoutSeconds: 60,
      parallel: true,
      prioritizeByQuality: true,
      onServerComplete: (config, ping) {
        final normalized = ping; // already normalized in intelligent helper
        final idx = updated.indexWhere((s) => s.config == config);
        if (idx != -1) {
          final srv = updated[idx];
          updated[idx] = ServerInfo(
            name: srv.name,
            config: srv.config,
            ip: srv.ip,
            countryCode: srv.countryCode,
            ping: normalized,
          );
          completed++;

          // Real-time UI update immediately when each server result comes in
          if (mounted) {
            setState(() {
              _serversWithLivePing = _sortServersRealTime(updated);
            });
          }

          final pingText = normalized < 0 ? '-1' : '${normalized}ms';
          print('⚡ Real-time update ${srv.name}: $pingText ($completed/$total) - UI updated immediately');
        }
      },
      onProgress: (c, t) {
        // Optional: could update a progress bar value here
      },
    );

    if (mounted) {
      setState(() {
        _serversWithLivePing = _sortServers(updated);
        _isTestingPing = false;
      });
      print('✅ Intelligent ping test completed for $total servers');
      
      // Perform maintenance after testing
      v2rayPing.performMaintenance();
    }
  }

  /// Set up periodic ping updates - DISABLED
  /// Ping testing now only runs once when modal opens to improve performance
  // void _setupPeriodicPingUpdates() {
  //   _pingUpdateTimer?.cancel();
  //   _pingUpdateTimer = Timer.periodic(Duration(seconds: 30), (timer) {
  //     if (mounted && !_isTestingPing) {
  //       _startLivePingTesting();
  //     }
  //   });
  // }

  /// Real-time sorting during ping testing - prioritizes completed pings
  List<ServerInfo> _sortServersRealTime(List<ServerInfo> servers) {
    final items = List<ServerInfo>.from(servers);
    
    // During ping testing, always sort by ping quality (best first)
    items.sort((a, b) {
      final pingA = a.ping ?? 0;
      final pingB = b.ping ?? 0;

      int priority(int p) {
        if (p > 0 && p < 100) return 1;     // Excellent (highest priority)
        if (p >= 100 && p < 300) return 2;  // Good
        if (p >= 300 && p < 9999) return 3; // Fair
        if (p == 0) return 4;               // Not tested yet
        if (p >= 9999) return 5;            // Timeout
        return 6;                           // Failed (-1)
      }

      final prioA = priority(pingA);
      final prioB = priority(pingB);
      
      // First sort by priority
      if (prioA != prioB) return prioA.compareTo(prioB);
      
      // Within same priority, sort by actual ping value
      if (pingA > 0 && pingB > 0 && pingA < 9999 && pingB < 9999) {
        return pingA.compareTo(pingB);
      }
      
      // Fallback to alphabetical
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return items;
  }

  /// Sort servers by selected key
  List<ServerInfo> _sortServers(List<ServerInfo> servers) {
    final items = List<ServerInfo>.from(servers);
    
    if (_sortKey == 'name') {
      items.sort((a, b) {
        final cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        return _sortAsc ? cmp : -cmp;
      });
      return items;
    }

    // Default: sort by ping with categories
    items.sort((a, b) {
      final pingA = a.ping ?? 0;
      final pingB = b.ping ?? 0;

      int cat(int p) {
        if (p > 0 && p < 9999) return 0; // success
        if (p == 0) return 1; // not tested
        if (p >= 9999) return 2; // timeout
        return 3; // failed (-1)
      }

      final cA = cat(pingA);
      final cB = cat(pingB);
      if (cA != cB) return cA.compareTo(cB);
      final cmp = pingA.compareTo(pingB);
      return _sortAsc ? cmp : -cmp;
    });

    return items;
  }

  /// Get display servers filtered by current search query and filter chips
  List<ServerInfo> _getDisplayServers() {
    final items = _applyFilter(_sortServers(_serversWithLivePing));
    
    if (_searchQuery.isEmpty) return items;
    final q = _searchQuery.toLowerCase();
    return items.where((s) {
      final name = s.name.toLowerCase();
      final ip = (s.ip ?? '').toLowerCase();
      return name.contains(q) || ip.contains(q);
    }).toList();
  }

  /// Apply simple ping-based filters to the current list
  List<ServerInfo> _applyFilter(List<ServerInfo> items) {
    switch (_filter) {
      case 'fast':
        return items.where((s) => (s.ping ?? 0) > 0 && (s.ping ?? 0) < 100).toList();
      case 'good':
        return items.where((s) => (s.ping ?? 0) >= 100 && (s.ping ?? 0) < 300).toList();
      case 'timeout':
        return items.where((s) => (s.ping ?? 0) >= 9999).toList();
      case 'failed':
        return items.where((s) => (s.ping ?? 0) < 0).toList();
      default:
        return items; // 'all'
    }
  }

  /// Build compact quick filter chip
  Widget _buildQuickChip(String label, String key) {
    final selected = _filter == key;
    return GestureDetector(
      onTap: () => setState(() => _filter = key),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? ThemeColor.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? ThemeColor.primaryColor : ThemeColor.borderColor.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: selected ? Colors.white : ThemeColor.mutedText,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// Empty state when no servers match the current filters
  Widget _buildEmptyFilteredState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ThemeColor.surfaceColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off_rounded, 
              size: 28, 
              color: ThemeColor.mutedText
            ),
          ),
          SizedBox(height: 16),
          Text(
            'no_servers_match_filter'.tr(), 
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: ThemeColor.mutedText,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'try_different_search_or_filter'.tr(),
            style: TextStyle(
              fontSize: 14,
              color: ThemeColor.mutedText.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _searchController.clear();
                _searchQuery = '';
                _filter = 'all';
              });
            },
            icon: Icon(Icons.clear_all_rounded, size: 18),
            label: Text('clear_filters'.tr()),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeColor.primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Check if a specific server is currently being tested
  /// Show testing spinner only while this server hasn't received a ping yet (ping == 0)
  bool _isCurrentlyTestingServer(String config) {
    if (!_isTestingPing) return false;
    final idx = _serversWithLivePing.indexWhere((s) => s.config == config);
    if (idx == -1) return _isTestingPing; // Fallback to global state
    final p = _serversWithLivePing[idx].ping ?? 0;
    return p == 0; // testing only until this server gets a ping
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: ThemeColor.backgroundColor,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ThemeColor.xlRadius),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Simple handle bar
          Container(
            margin: EdgeInsets.only(top: ThemeColor.smallSpacing),
            width: 50,
            height: 4,
            decoration: BoxDecoration(
              color: ThemeColor.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Enhanced header with ping status
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: ThemeColor.largeSpacing,
              vertical: ThemeColor.mediumSpacing,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.dns_rounded,
                      color: ThemeColor.primaryColor,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'select_server_title'.tr(),
                        style: ThemeColor.headingStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: Column(
              children: [
                // Automatic server option (simplified)
                Container(
                  margin: EdgeInsets.symmetric(horizontal: ThemeColor.largeSpacing, vertical: 8),
                  decoration: BoxDecoration(
                    color: widget.selectedServer == 'Automatic' 
                        ? ThemeColor.primaryColor.withValues(alpha: 0.1)
                        : ThemeColor.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.selectedServer == 'Automatic'
                          ? ThemeColor.primaryColor
                          : ThemeColor.borderColor,
                    ),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.selectedServer == 'Automatic'
                            ? ThemeColor.primaryColor
                            : ThemeColor.surfaceColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: widget.selectedServer == 'Automatic'
                            ? Colors.white
                            : ThemeColor.primaryColor,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'automatic'.tr(),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: widget.selectedServer == 'Automatic'
                            ? ThemeColor.primaryColor
                            : ThemeColor.primaryText,
                      ),
                    ),
                     subtitle: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'automatic_description'.tr(),
                            style: TextStyle(
                              color: ThemeColor.mutedText,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: widget.selectedServer == 'Automatic'
                        ? Icon(Icons.check_circle, color: ThemeColor.primaryColor)
                        : Icon(Icons.radio_button_unchecked, color: ThemeColor.mutedText),
                    onTap: () => _selectServer(context, 'Automatic'),
                  ),
                ),
                
                // Compact controls bar (simplified)
                Container(
                  margin: EdgeInsets.symmetric(horizontal: ThemeColor.largeSpacing, vertical: 8),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ThemeColor.surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ThemeColor.borderColor.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      // Search + Refresh only
                      Row(
                        children: [
                          // Compact search
                          Expanded(
                            child: Container(
                              height: 36,
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'search_placeholder'.tr(),
                                  hintStyle: TextStyle(fontSize: 13, color: ThemeColor.mutedText),
                                  prefixIcon: Icon(Icons.search_rounded, size: 18, color: ThemeColor.mutedText),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: Icon(Icons.clear_rounded, size: 16, color: ThemeColor.mutedText),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() => _searchQuery = '');
                                          },
                                        )
                                      : null,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: ThemeColor.borderColor.withValues(alpha: 0.3)),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                ),
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          // Refresh button
                          Container(
                            height: 36,
                            child: _isTestingPing
                                ? SizedBox.shrink()
                                : IconButton(
                                    onPressed: _startLivePingTesting,
                                    icon: Icon(Icons.refresh_rounded, size: 18, color: ThemeColor.primaryColor),
                                    style: IconButton.styleFrom(
                                      backgroundColor: ThemeColor.primaryColor.withValues(alpha: 0.1),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Server list with improved states  
                if (_serversWithLivePing.isEmpty) ...[
                  SizedBox(height: 8),
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: ThemeColor.surfaceColor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.dns_rounded, 
                              size: 32, 
                              color: ThemeColor.mutedText
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'no_servers_available'.tr(), 
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: ThemeColor.mutedText,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'loading_servers_please_wait'.tr(),
                            style: TextStyle(
                              fontSize: 14,
                              color: ThemeColor.mutedText.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (_serversWithLivePing.isNotEmpty && _getDisplayServers().isEmpty) ...[
                  SizedBox(height: 8),
                  Expanded(child: _buildEmptyFilteredState()),
                ],
                if (_getDisplayServers().isNotEmpty) ...[
                  SizedBox(height: 8),
                  Expanded(
                    child: SimpleServerListWidget(
                      servers: _getDisplayServers().map((server) {
                        return {
                          'name': server.name,
                          'config': server.config,
                          'ip': server.ip ?? '',
                          'countryCode': server.countryCode ?? '',
                          // Use the most up-to-date ping value
                          'ping': server.ping ?? 0,
                          'isTestingPing': _isTestingPing && _isCurrentlyTestingServer(server.config),
                          'location': server.name,
                          'rank': 0,
                        };
                      }).toList(),
                      selectedServer: widget.selectedServer,
                      onServerSelected: (config) => _selectServer(context, config),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Modern server card with enhanced design
  Widget _buildModernServerCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String serverType,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: ThemeColor.mediumAnimation,
      decoration: BoxDecoration(
        gradient: isSelected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ThemeColor.primaryColor.withValues(alpha: 0.1),
                  ThemeColor.secondaryColor.withValues(alpha: 0.05),
                ],
              )
            : null,
        borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
        border: Border.all(
          color: isSelected
              ? ThemeColor.primaryColor
              : ThemeColor.borderColor,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: ThemeColor.primaryColor.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: EdgeInsets.all(ThemeColor.largeSpacing),
            child: Row(
              children: [
                // Icon container
                Container(
                  padding: EdgeInsets.all(ThemeColor.mediumSpacing),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? ThemeColor.primaryGradient
                        : LinearGradient(
                            colors: [
                              ThemeColor.surfaceColor,
                              ThemeColor.surfaceColor.withValues(alpha: 0.8),
                            ],
                          ),
                    borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: ThemeColor.primaryColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : ThemeColor.primaryColor,
                    size: 24,
                  ),
                ),
                SizedBox(width: ThemeColor.largeSpacing),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: ThemeColor.bodyStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isSelected 
                                    ? ThemeColor.primaryColor
                                    : ThemeColor.primaryText,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: ThemeColor.smallSpacing,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                gradient: ThemeColor.primaryGradient,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: ThemeColor.primaryColor.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                'active'.tr(),
                                style: ThemeColor.captionStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: ThemeColor.captionStyle(
                          fontSize: 14,
                          color: isSelected
                              ? ThemeColor.primaryColor.withValues(alpha: 0.8)
                              : ThemeColor.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Selection indicator
                AnimatedContainer(
                  duration: ThemeColor.fastAnimation,
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? ThemeColor.primaryColor
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? ThemeColor.primaryColor
                          : ThemeColor.borderColor,
                      width: 2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: ThemeColor.primaryColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    color: isSelected ? Colors.white : Colors.transparent,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectServer(BuildContext context, String server) {
    HapticFeedback.lightImpact();
    widget.onServerSelected(server);
  }
}
