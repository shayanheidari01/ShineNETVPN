import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shinenet_vpn/common/theme.dart';

/// Enhanced server list widget with improved display and functionality
class EnhancedServerListWidget extends StatefulWidget {
  final List<Map<String, dynamic>> servers;
  final String? selectedServer;
  final Function(String) onServerSelected;
  final bool showPing;
  final bool showCountryFlags;
  final bool allowRefresh;
  final VoidCallback? onRefresh;

  const EnhancedServerListWidget({
    Key? key,
    required this.servers,
    this.selectedServer,
    required this.onServerSelected,
    this.showPing = true,
    this.showCountryFlags = true,
    this.allowRefresh = true,
    this.onRefresh,
  }) : super(key: key);

  @override
  State<EnhancedServerListWidget> createState() => _EnhancedServerListWidgetState();
}

class _EnhancedServerListWidgetState extends State<EnhancedServerListWidget> {
  String _searchQuery = '';
  String _sortBy = 'ping'; // ping, name, country
  bool _sortAscending = true;
  List<Map<String, dynamic>> _filteredServers = [];

  @override
  void initState() {
    super.initState();
    _updateFilteredServers();
  }

  @override
  void didUpdateWidget(EnhancedServerListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.servers != widget.servers) {
      _updateFilteredServers();
    }
  }

  void _updateFilteredServers() {
    _filteredServers = widget.servers.where((server) {
      final name = (server['name'] as String? ?? '').toLowerCase();
      final country = (server['countryCode'] as String? ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();
      
      return name.contains(query) || country.contains(query);
    }).toList();

    // Sort servers
    _filteredServers.sort((a, b) {
      int comparison = 0;
      
      switch (_sortBy) {
        case 'ping':
          final pingA = a['ping'] as int? ?? 9999;
          final pingB = b['ping'] as int? ?? 9999;
          comparison = pingA.compareTo(pingB);
          break;
        case 'name':
          final nameA = a['name'] as String? ?? '';
          final nameB = b['name'] as String? ?? '';
          comparison = nameA.compareTo(nameB);
          break;
        case 'country':
          final countryA = a['countryCode'] as String? ?? '';
          final countryB = b['countryCode'] as String? ?? '';
          comparison = countryA.compareTo(countryB);
          break;
      }
      
      return _sortAscending ? comparison : -comparison;
    });

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        _buildSearchAndSort(),
        Expanded(
          child: _buildServerList(),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(ThemeColor.largeSpacing),
      decoration: BoxDecoration(
        gradient: ThemeColor.primaryGradient,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ThemeColor.largeRadius),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.dns_rounded,
            color: Colors.white,
            size: 24,
          ),
          SizedBox(width: ThemeColor.mediumSpacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'server_list'.tr(),
                  style: ThemeColor.headingStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_filteredServers.length} ${'servers_available'.tr()}',
                  style: ThemeColor.captionStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (widget.allowRefresh && widget.onRefresh != null)
            IconButton(
              onPressed: widget.onRefresh,
              icon: Icon(
                Icons.refresh_rounded,
                color: Colors.white,
              ),
              tooltip: 'refresh_servers'.tr(),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchAndSort() {
    return Container(
      padding: EdgeInsets.all(ThemeColor.mediumSpacing),
      decoration: BoxDecoration(
        color: ThemeColor.surfaceColor,
        border: Border(
          bottom: BorderSide(
            color: ThemeColor.borderColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Search field
          TextField(
            decoration: InputDecoration(
              hintText: 'search_servers'.tr(),
              prefixIcon: Icon(Icons.search_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
                borderSide: BorderSide(color: ThemeColor.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
                borderSide: BorderSide(color: ThemeColor.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
                borderSide: BorderSide(color: ThemeColor.primaryColor, width: 2),
              ),
              filled: true,
              fillColor: ThemeColor.backgroundColor,
            ),
            onChanged: (value) {
              _searchQuery = value;
              _updateFilteredServers();
            },
          ),
          SizedBox(height: ThemeColor.mediumSpacing),
          // Sort options
          Row(
            children: [
              Text(
                'sort_by'.tr(),
                style: ThemeColor.bodyStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(width: ThemeColor.mediumSpacing),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildSortChip('ping', Icons.speed_rounded),
                      SizedBox(width: ThemeColor.smallSpacing),
                      _buildSortChip('name', Icons.label_rounded),
                      SizedBox(width: ThemeColor.smallSpacing),
                      _buildSortChip('country', Icons.flag_rounded),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  _sortAscending = !_sortAscending;
                  _updateFilteredServers();
                },
                icon: Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  color: ThemeColor.primaryColor,
                ),
                tooltip: _sortAscending ? 'sort_ascending'.tr() : 'sort_descending'.tr(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String sortType, IconData icon) {
    final isSelected = _sortBy == sortType;
    return GestureDetector(
      onTap: () {
        _sortBy = sortType;
        _updateFilteredServers();
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: ThemeColor.mediumSpacing,
          vertical: ThemeColor.smallSpacing,
        ),
        decoration: BoxDecoration(
          color: isSelected ? ThemeColor.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
          border: Border.all(
            color: isSelected ? ThemeColor.primaryColor : ThemeColor.borderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : ThemeColor.mutedText,
            ),
            SizedBox(width: 4),
            Text(
              sortType.tr(),
              style: ThemeColor.captionStyle(
                color: isSelected ? Colors.white : ThemeColor.mutedText,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerList() {
    if (_filteredServers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: ThemeColor.mutedText,
            ),
            SizedBox(height: ThemeColor.mediumSpacing),
            Text(
              _searchQuery.isEmpty ? 'no_servers_available'.tr() : 'no_servers_found'.tr(),
              style: ThemeColor.bodyStyle(color: ThemeColor.mutedText),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(ThemeColor.mediumSpacing),
      itemCount: _filteredServers.length,
      itemBuilder: (context, index) {
        final server = _filteredServers[index];
        return _buildServerCard(server, index);
      },
    );
  }

  Widget _buildServerCard(Map<String, dynamic> server, int index) {
    final isSelected = widget.selectedServer == server['config'];
    final ping = server['ping'] as int? ?? -1;
    final name = server['name'] as String? ?? 'Unknown Server';
    final countryCode = server['countryCode'] as String? ?? '';
    final ip = server['ip'] as String? ?? '';

    final pingColor = _getPingColor(ping);
    final pingStatus = _getPingStatus(ping);

    return Container(
      margin: EdgeInsets.only(bottom: ThemeColor.mediumSpacing),
      decoration: BoxDecoration(
        gradient: isSelected
            ? LinearGradient(
                colors: [
                  ThemeColor.primaryColor.withValues(alpha: 0.1),
                  ThemeColor.surfaceColor.withValues(alpha: 0.8),
                ],
              )
            : null,
        borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
        border: Border.all(
          color: isSelected ? ThemeColor.primaryColor : ThemeColor.borderColor,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected 
                ? ThemeColor.primaryColor.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: isSelected ? 12 : 8,
            offset: Offset(0, isSelected ? 4 : 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onServerSelected(server['config'] as String);
          },
          child: Padding(
            padding: EdgeInsets.all(ThemeColor.largeSpacing),
            child: Row(
              children: [
                // Server icon and country flag
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
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.dns_rounded,
                        color: isSelected ? Colors.white : ThemeColor.primaryColor,
                        size: 24,
                      ),
                      if (widget.showCountryFlags && countryCode.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            _countryCodeToFlag(countryCode),
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(width: ThemeColor.largeSpacing),
                
                // Server info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: ThemeColor.bodyStyle(
                                fontSize: 16,
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
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                gradient: ThemeColor.primaryGradient,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'selected'.tr(),
                                style: ThemeColor.captionStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 4),
                      if (ip.isNotEmpty)
                        Text(
                          ip,
                          style: ThemeColor.captionStyle(
                            fontSize: 12,
                            color: ThemeColor.mutedText,
                          ),
                        ),
                      if (widget.showPing)
                        Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: pingColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                ping > 0 ? '${ping}ms' : 'timeout'.tr(),
                                style: ThemeColor.captionStyle(
                                  fontSize: 12,
                                  color: pingColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                pingStatus,
                                style: ThemeColor.captionStyle(
                                  fontSize: 11,
                                  color: pingColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Selection indicator
                AnimatedContainer(
                  duration: Duration(milliseconds: 200),
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
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    color: isSelected ? Colors.white : Colors.transparent,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getPingColor(int ping) {
    if (ping <= 0) return ThemeColor.errorColor;
    if (ping < 100) return ThemeColor.successColor;
    if (ping < 300) return ThemeColor.warningColor;
    return ThemeColor.errorColor;
  }

  String _getPingStatus(int ping) {
    if (ping <= 0) return 'offline'.tr();
    if (ping < 100) return 'excellent'.tr();
    if (ping < 300) return 'good'.tr();
    return 'slow'.tr();
  }

  String _countryCodeToFlag(String countryCode) {
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
