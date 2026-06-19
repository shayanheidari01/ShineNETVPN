import 'package:shinenet_vpn/common/theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BlockedAppsWidgets extends StatefulWidget {
   BlockedAppsWidgets({super.key});

  @override
  State<BlockedAppsWidgets> createState() => _BlockedAppsWidgetsState();
}

class _BlockedAppsWidgetsState extends State<BlockedAppsWidgets>
    with SingleTickerProviderStateMixin {
  List<AppInfo>? apps;
  List<AppInfo>? filteredApps;
  List<String> blockedApps = [];
  bool isLoading = true;
  TextEditingController searchController = TextEditingController();
  bool isSearchReady = false;
  bool isLoadSystemApps = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    searchController.addListener(_filterApps);
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? savedBlockedApps = prefs.getStringList('blockedApps') ?? [];
    bool? savedIsLoadSystemApps = prefs.getBool('isLoadSystemApps');

    if (!mounted) return;
    
    setState(() {
      blockedApps = savedBlockedApps;
      isLoadSystemApps = savedIsLoadSystemApps ?? false;
    });

    _loadApps();
  }

  Future<void> _loadApps() async {
    if (!mounted) return;
    
    setState(() {
      isLoading = true;
    });

    List<AppInfo> installedApps =
        await InstalledApps.getInstalledApps(!isLoadSystemApps, true);

    if (!mounted) return;
    
    setState(() {
      apps = installedApps;

      apps!.sort((a, b) {
        bool aIsBlocked = blockedApps.contains(a.packageName);
        bool bIsBlocked = blockedApps.contains(b.packageName);
        return (bIsBlocked ? 1 : 0).compareTo(aIsBlocked ? 1 : 0);
      });

      filteredApps = apps;
      isLoading = false;
    });

    // Delay enabling search with mounted check
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          isSearchReady = true;
        });
      }
    });
  }

  void _filterApps() {
    if (!mounted) return;
    
    String query = searchController.text.toLowerCase();
    setState(() {
      filteredApps = apps?.where((app) {
        return app.name.toLowerCase().contains(query) ||
            app.packageName.toLowerCase().contains(query);
      }).toList();

      filteredApps!.sort((a, b) {
        bool aIsBlocked = blockedApps.contains(a.packageName);
        bool bIsBlocked = blockedApps.contains(b.packageName);
        return (bIsBlocked ? 1 : 0).compareTo(aIsBlocked ? 1 : 0);
      });
    });
  }

  Future<void> _saveBlockedApps() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('blockedApps', blockedApps);
    await prefs.setBool('isLoadSystemApps', isLoadSystemApps);
  }

  void _toggleBlockedApp(String packageName) {
    if (!mounted) return;
    
    setState(() {
      if (blockedApps.contains(packageName)) {
        blockedApps.remove(packageName);
      } else {
        blockedApps.add(packageName);
      }
    });
    _saveBlockedApps();
  }

  void _toggleSystemApps() {
    if (!mounted) return;
    
    setState(() {
      isLoading = true;
      isLoadSystemApps = !isLoadSystemApps;
    });
    _saveBlockedApps();
    _loadApps();
  }

  @override
  void dispose() {
    searchController.removeListener(_filterApps);
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AnimatedOpacity(
          opacity: isSearchReady ? 1.0 : 0.0,
          duration: Duration(milliseconds: 500),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'search_application'.tr(),
              hintStyle: TextStyle(
                  color: isSearchReady ? Colors.white : Colors.white70),
              border: InputBorder.none,
            ),
            style: TextStyle(color: Colors.white),
            enabled: isSearchReady,
          ),
        ),
        backgroundColor: ThemeColor.backgroundColor,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'toggleSystemApps') {
                _toggleSystemApps();
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                CheckedPopupMenuItem<String>(
                  value: 'toggleSystemApps',
                  checked: isLoadSystemApps,
                  child: Text('show_system_apps'.tr()),
                ),
              ];
            },
          ),
        ],
      ),
      body: isLoading
          ? Center(
              child: CupertinoActivityIndicator(
                color: Colors.white,
              ),
            )
          : ListView.builder(
              itemCount: filteredApps?.length ?? 0,
              itemBuilder: (context, index) {
                AppInfo app = filteredApps![index];
                bool isBlocked = blockedApps.contains(app.packageName);
                return ListTile(
                  leading: app.icon != null && app.icon!.isNotEmpty
                      ? Image.memory(app.icon!)
                      : Icon(Icons.android),
                  title: Text(app.name),
                  subtitle: Text(app.packageName),
                  trailing: Checkbox(
                    value: isBlocked,
                    onChanged: (bool? value) {
                      _toggleBlockedApp(app.packageName);
                    },
                  ),
                  onTap: () {
                    _toggleBlockedApp(app.packageName);
                  },
                );
              },
            ),
    );
  }
}
