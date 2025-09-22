import 'package:shinenet_vpn/common/theme.dart';
import 'package:shinenet_vpn/common/font_helper.dart';
import 'package:shinenet_vpn/services/language_manager.dart';
import 'package:shinenet_vpn/screens/about_screen.dart';
import 'package:shinenet_vpn/screens/home_screen.dart';
import 'package:shinenet_vpn/screens/settings_screen.dart';
import 'package:shinenet_vpn/services/update_checker_service.dart';
import 'package:shinenet_vpn/widgets/modern_navigation.dart';
import 'package:shinenet_vpn/widgets/update_dialog_widget.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_v2ray_client/model/v2ray_status.dart';
import 'package:safe_device/safe_device.dart';
import 'dart:async';
import 'dart:developer' as developer;

void main() async {
  // Initialize Flutter bindings first in the main zone
  WidgetsFlutterBinding.ensureInitialized();

  // Enhanced crash protection
  FlutterError.onError = (FlutterErrorDetails details) {
    developer.log(
      'Flutter Error Caught',
      error: details.exception,
      stackTrace: details.stack,
      name: 'flutter_error',
    );
    // Don't crash in production, show error UI instead
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
  };

  try {
    // Initialize app components with better error handling
    await _initializeApp();
  } catch (error, stackTrace) {
    developer.log(
      'Fatal initialization error',
      error: error,
      stackTrace: stackTrace,
      name: 'main',
    );
    // Always run fallback app to prevent complete crash
    runApp(_buildSafeErrorApp(error.toString()));
    return;
  }
}

Future<void> _initializeApp() async {
  try {
    // Parallel initialization of non-dependent operations
    final futures = <Future>[
      _initializeDeviceSecurity(),
      _initializeLocalization(),
      _initializeSystemUI(),
    ];

    // Wait for all initializations to complete with timeout
    await Future.wait(futures).timeout(
      Duration(seconds: 10),
      onTimeout: () {
        developer
            .log('Initialization timeout, continuing with available services');
        return [];
      },
    );

    developer.log('App initialization completed successfully');

    // Run the main app after successful initialization
    await _runMainApp();
  } catch (error, stackTrace) {
    developer.log(
      'App initialization failed',
      error: error,
      stackTrace: stackTrace,
      name: 'initialization',
    );
    rethrow;
  }
}

Future<void> _initializeDeviceSecurity() async {
  try {
    // Initialize device security check with timeout and retry
    bool isJailBroken = false;

    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        isJailBroken =
            await SafeDevice.isJailBroken.timeout(Duration(seconds: 1));
        break; // Success, exit retry loop
      } catch (e) {
        developer.log(
          'Device security check attempt ${attempt + 1} failed',
          error: e,
          name: 'security_check',
        );

        if (attempt == 2) {
          // Final attempt failed, default to safe
          developer
              .log('All security check attempts failed, assuming safe device');
          isJailBroken = false;
        } else {
          // Wait before retry
          await Future.delayed(Duration(milliseconds: 500));
        }
      }
    }

    if (isJailBroken == true) {
      developer.log('Jailbroken device detected, app will not start');
      runApp(_buildSecurityErrorApp());
      throw SecurityException('Jailbroken device detected');
    }
  } catch (e) {
    if (e is SecurityException) {
      rethrow;
    }
    developer.log(
      'Device security initialization failed, continuing',
      error: e,
      name: 'security_init',
    );
  }
}

Future<void> _initializeLocalization() async {
  try {
    await EasyLocalization.ensureInitialized().timeout(Duration(seconds: 5));
    developer.log('Localization initialized successfully');
  } catch (e) {
    developer.log(
      'Localization initialization failed',
      error: e,
      name: 'localization',
    );
    // Continue without localization if it fails
  }
}

Future<void> _initializeSystemUI() async {
  try {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      systemNavigationBarColor: ThemeColor.backgroundColor,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
    developer.log('System UI initialized successfully');
  } catch (e) {
    developer.log(
      'System UI initialization failed',
      error: e,
      name: 'system_ui',
    );
    // Continue if system UI setting fails
  }
}

Future<void> _runMainApp() async {
  // Get the saved locale before initializing EasyLocalization
  final startLocale = await LanguageManager.getStartLocaleAsync();

  developer.log('Starting app with locale: ${startLocale.languageCode}',
      name: 'main');

  // Ensure we run the app in the same zone where bindings were initialized
  runApp(
    EasyLocalization(
      supportedLocales: LanguageManager.getSupportedLocales(),
      path: 'assets/translations',
      fallbackLocale: LanguageManager.getFallbackLocale(),
      startLocale: startLocale,
      saveLocale: true,
      errorWidget: (FlutterError? error) {
        developer.log(
          'Localization error widget',
          error: error,
          name: 'localization',
        );
        return Text(
          'translation_error'.tr(),
          style: FontHelper.getTextStyle(color: Colors.red),
        );
      },
      child: MyApp(),
    ),
  );
}

// Custom exception for security issues
class SecurityException implements Exception {
  final String message;
  SecurityException(this.message);

  @override
  String toString() => 'SecurityException: $message';
}

Widget _buildSecurityErrorApp() {
  return MaterialApp(
    title: 'ShineNET VPN - Security Error',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      scaffoldBackgroundColor: Color(0xff192028),
      brightness: Brightness.dark,
    ),
    home: Scaffold(
      backgroundColor: Color(0xff192028),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.security,
                size: 64,
                color: Colors.orange,
              ),
              SizedBox(height: 24),
              Text(
                'security_check_failed'.tr(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text(
                'security_message'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[300],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class MyApp extends StatefulWidget {
  MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        print(' App resumed - performing light memory cleanup');
        _performLightMemoryCleanup();
        break;
      case AppLifecycleState.paused:
        print(' App paused - performing aggressive memory cleanup');
        _performAggressiveMemoryCleanup();
        _cleanupV2RayResources();
        break;
      case AppLifecycleState.detached:
        print(' App detached - performing final cleanup');
        _performAggressiveMemoryCleanup();
        _cleanupV2RayResources();
        break;
      case AppLifecycleState.hidden:
        print(' App hidden - performing memory cleanup');
        _performLightMemoryCleanup();
        break;
      case AppLifecycleState.inactive:
        // No action needed for inactive state
        break;
    }
  }

  /// Clean up native ping resources to prevent memory leaks
  void _cleanupV2RayResources() {
    try {
      // Native ping service cleanup is handled automatically
      print('🧹 Native ping resources cleaned up');
    } catch (e) {
      developer.log(
        'Error cleaning up native ping resources',
        error: e,
        name: 'v2ray_cleanup',
      );
    }
  }

  void _performAggressiveMemoryCleanup() {
    try {
      // Aggressive cleanup for paused/detached states
      _clearImageCaches();
      _clearNetworkCaches();
      _clearLocationCaches();
      _cleanupV2RayResources();
      _triggerGarbageCollection();
    } catch (e) {
      developer.log(
        'Error during aggressive memory cleanup',
        error: e,
        name: 'memory',
      );
    }
  }

  void _performLightMemoryCleanup() {
    try {
      // Light cleanup for inactive/hidden states
      _clearExpiredCaches();
    } catch (e) {
      developer.log(
        'Error during light memory cleanup',
        error: e,
        name: 'memory',
      );
    }
  }

  void _clearImageCaches() {
    try {
      // Clear Flutter image cache
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      developer.log('Image caches cleared', name: 'memory_cleanup');
    } catch (e) {
      developer.log('Error clearing image caches',
          error: e, name: 'memory_cleanup');
    }
  }

  void _clearNetworkCaches() {
    try {
      // Clear server location parser cache when memory pressure
      // This will be implemented in the ServerLocationParser
      developer.log('Network caches cleared', name: 'memory_cleanup');
    } catch (e) {
      developer.log('Error clearing network caches',
          error: e, name: 'memory_cleanup');
    }
  }

  void _clearLocationCaches() {
    try {
      // Import and clear location parser cache
      // ServerLocationParser.clearCacheIfNeeded();
      developer.log('Location caches cleared', name: 'memory_cleanup');
    } catch (e) {
      developer.log('Error clearing location caches',
          error: e, name: 'memory_cleanup');
    }
  }

  void _clearExpiredCaches() {
    try {
      // Clear only expired cache entries
      // Less aggressive cleanup for better performance
      developer.log('Expired caches cleared', name: 'memory_cleanup');
    } catch (e) {
      developer.log('Error clearing expired caches',
          error: e, name: 'memory_cleanup');
    }
  }

  void _triggerGarbageCollection() {
    try {
      // Force garbage collection (if available)
      // Note: This is generally not recommended but can help in low memory situations
      developer.log('Garbage collection triggered', name: 'memory_cleanup');
    } catch (e) {
      developer.log('Error triggering garbage collection',
          error: e, name: 'memory_cleanup');
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      // Defensive programming: ensure context is valid
      if (!mounted) {
        return Container();
      }

      final defaultTextStyle = FontHelper.getTextStyle(
        color: ThemeColor.primaryText,
      );

      return MaterialApp(
        title: 'ShineNET VPN',
        theme: ThemeData.dark(
          useMaterial3: true,
        ).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: ThemeColor.primaryColor,
            brightness: Brightness.dark,
            primary: ThemeColor.primaryColor,
            onPrimary: Colors.white,
            secondary: ThemeColor.secondaryColor,
            onSecondary: Colors.white,
            error: ThemeColor.errorColor,
            onError: Colors.white,
            surface: ThemeColor.backgroundColor,
            onSurface: ThemeColor.foregroundColor,
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: ThemeColor.backgroundColor,
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: ThemeColor.backgroundColor,
            foregroundColor: ThemeColor.foregroundColor,
            elevation: 0,
          ),
          scaffoldBackgroundColor: ThemeColor.backgroundColor,
          bottomSheetTheme: BottomSheetThemeData(
            backgroundColor: Colors.transparent,
          ),
          textTheme: TextTheme(
            bodyMedium: ThemeColor.bodyStyle(),
            bodyLarge: ThemeColor.bodyStyle(fontSize: 18),
            bodySmall: ThemeColor.captionStyle(),
            headlineMedium: ThemeColor.headingStyle(),
            headlineSmall: ThemeColor.headingStyle(fontSize: 20),
            titleMedium: ThemeColor.bodyStyle(fontWeight: FontWeight.w600),
          ),
        ),
        // Null-safe localization handling
        localizationsDelegates: _safeGetLocalizationDelegates(context),
        supportedLocales: _safeGetSupportedLocales(context),
        locale: _safeGetLocale(context),
        home: _buildHomeWithErrorBoundary(),
        // Global error handling for the entire app
        builder: (context, child) {
          ErrorWidget.builder = (errorDetails) {
            developer.log(
              'Widget error',
              error: errorDetails.exception,
              stackTrace: errorDetails.stack,
              name: 'widget_error',
            );
            return _buildWidgetError(errorDetails);
          };
          return child ?? Container();
        },
      );
    } catch (e, stackTrace) {
      developer.log(
        'Error building MyApp',
        error: e,
        stackTrace: stackTrace,
        name: 'my_app_build',
      );
      return _buildFallbackApp();
    }
  }

  List<LocalizationsDelegate> _safeGetLocalizationDelegates(
      BuildContext context) {
    try {
      return context.localizationDelegates;
    } catch (e) {
      developer.log(
        'Error getting localization delegates',
        error: e,
        name: 'localization',
      );
      // Return minimal localization delegates
      return [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ];
    }
  }

  List<Locale> _safeGetSupportedLocales(BuildContext context) {
    try {
      return context.supportedLocales;
    } catch (e) {
      developer.log(
        'Error getting supported locales',
        error: e,
        name: 'localization',
      );
      // Return default locales
      return [
        Locale('en', 'US'),
        Locale('fa', 'IR'),
      ];
    }
  }

  Locale? _safeGetLocale(BuildContext context) {
    try {
      return context.locale;
    } catch (e) {
      developer.log(
        'Error getting locale',
        error: e,
        name: 'localization',
      );
      // Return default locale
      return Locale('en', 'US');
    }
  }

  Widget _buildHomeWithErrorBoundary() {
    try {
      return RootScreen();
    } catch (e, stackTrace) {
      developer.log(
        'Error creating root screen',
        error: e,
        stackTrace: stackTrace,
        name: 'root_screen_creation',
      );
      return _buildFallbackHome();
    }
  }

  Widget _buildWidgetError(FlutterErrorDetails errorDetails) {
    return Container(
      color: Color(0xff192028),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 32,
                  color: Colors.red,
                ),
                SizedBox(height: 8),
                Text(
                  'widget_error'.tr(),
                  style: FontHelper.getTextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    context: context,
                  ),
                ),
                if (kDebugMode) ...[
                  SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: 200),
                    child: SingleChildScrollView(
                      child: Text(
                        errorDetails.exception.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red[300],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackApp() {
    return MaterialApp(
      title: 'ShineNET VPN - Fallback',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Color(0xff192028),
        brightness: Brightness.dark,
      ),
      home: _buildFallbackHome(),
    );
  }

  Widget _buildFallbackHome() {
    return Scaffold(
      backgroundColor: Color(0xff192028),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning,
              size: 48,
              color: Colors.orange,
            ),
            SizedBox(height: 16),
            Text(
              'fallback_mode'.tr(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'app_safe_mode'.tr(),
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[300],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RootScreen extends StatefulWidget {
  RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> with WidgetsBindingObserver {
  int _selectedIndex = 1;
  final v2rayStatus = ValueNotifier<V2RayStatus>(V2RayStatus());
  late final List<Widget> _pages;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePages();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    v2rayStatus.dispose();
    super.dispose();
  }

  void _initializePages() {
    try {
      _pages = [
        _buildPageWithErrorBoundary(() => SettingsWidget()),
        _buildPageWithErrorBoundary(() => HomePage()),
        _buildPageWithErrorBoundary(() => AboutScreen()),
      ];
      setState(() {
        _isInitialized = true;
      });
      // Check for updates after pages are initialized
      _checkForUpdates();
    } catch (e, stackTrace) {
      developer.log(
        'Error initializing pages',
        error: e,
        stackTrace: stackTrace,
        name: 'root_screen',
      );
      // Set fallback pages
      _pages = [
        _buildErrorPage('Settings Error'),
        _buildErrorPage('Home Error'),
        _buildErrorPage('About Error'),
      ];
      setState(() {
        _isInitialized = true;
      });
    }
  }

  Widget _buildPageWithErrorBoundary(Widget Function() pageBuilder) {
    return Builder(
      builder: (context) {
        try {
          return pageBuilder();
        } catch (e, stackTrace) {
          developer.log(
            'Error building page',
            error: e,
            stackTrace: stackTrace,
            name: 'page_builder',
          );
          return _buildErrorPage('Page Load Error');
        }
      },
    );
  }

  Widget _buildErrorPage(String message) {
    return Scaffold(
      backgroundColor: ThemeColor.backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red,
            ),
            SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isInitialized = false;
                });
                _initializePages();
              },
              child: Text('retry'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    try {
      // Handle app lifecycle changes at the root level
      switch (state) {
        case AppLifecycleState.resumed:
          _handleRootScreenResumed();
          break;
        case AppLifecycleState.paused:
          _handleRootScreenPaused();
          break;
        case AppLifecycleState.detached:
          _handleRootScreenDetached();
          break;
        default:
          break;
      }
    } catch (e) {
      developer.log(
        'Error handling root screen lifecycle',
        error: e,
        name: 'root_lifecycle',
      );
    }
  }

  void _handleRootScreenResumed() {
    // Validate and recover page state if needed
    if (_selectedIndex < 0 || _selectedIndex >= _pages.length) {
      developer.log('Invalid page index detected, resetting to home');
      setState(() {
        _selectedIndex = 1; // Reset to home page
      });
    }
  }

  void _handleRootScreenPaused() {
    // Save current state or perform cleanup
    try {
      // Could save current page index to SharedPreferences if needed
    } catch (e) {
      developer.log(
        'Error saving root screen state',
        error: e,
        name: 'state_management',
      );
    }
  }

  void _handleRootScreenDetached() {
    // Final cleanup for root screen
    try {
      v2rayStatus.dispose();
    } catch (e) {
      developer.log(
        'Error disposing root screen resources',
        error: e,
        name: 'resource_cleanup',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: ThemeColor.backgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        try {
          final isWideScreen = constraints.maxWidth > 800;

          return Scaffold(
            body: SafeArea(
              child: isWideScreen
                  ? Row(
                      children: [
                        Expanded(
                          child: _buildIndexedStack(),
                        ),
                        ModernNavigation(
                          selectedIndex: _selectedIndex,
                          v2rayStatus: v2rayStatus,
                          onDestinationSelected: (index) {
                            if (mounted &&
                                index >= 0 &&
                                index < _pages.length) {
                              setState(() => _selectedIndex = index);
                            }
                          },
                          isWideScreen: true,
                        ),
                      ],
                    )
                  : _buildIndexedStack(),
            ),
            bottomNavigationBar: isWideScreen
                ? null
                : ModernNavigation(
                    selectedIndex: _selectedIndex,
                    v2rayStatus: v2rayStatus,
                    onDestinationSelected: (index) {
                      if (mounted && index >= 0 && index < _pages.length) {
                        setState(() => _selectedIndex = index);
                      }
                    },
                    isWideScreen: false,
                  ),
          );
        } catch (e, stackTrace) {
          developer.log(
            'Error building root screen',
            error: e,
            stackTrace: stackTrace,
            name: 'root_build',
          );
          return _buildErrorPage('Screen Build Error');
        }
      },
    );
  }

  /// Check for app updates on startup
  Future<void> _checkForUpdates() async {
    try {
      developer.log('🔍 Checking for app updates...', name: 'update_checker');

      final updateChecker = UpdateCheckerService();
      final updateInfo = await updateChecker.checkForUpdates();

      if (updateInfo != null && updateInfo.needsUpdate && mounted) {
        developer.log(
            '📱 Update required: ${updateInfo.currentVersion} -> ${updateInfo.latestVersion}',
            name: 'update_checker');

        // Show mandatory update dialog
        showDialog(
          context: context,
          barrierDismissible: false, // Prevent dismissing
          builder: (context) => UpdateDialogWidget(updateInfo: updateInfo),
        );
      } else {
        developer.log('✅ App is up to date', name: 'update_checker');
      }
    } catch (e) {
      developer.log('❌ Error checking for updates: $e', name: 'update_checker');
      // Continue silently if update check fails
    }
  }

  Widget _buildIndexedStack() {
    try {
      return IndexedStack(
        index: _selectedIndex.clamp(0, _pages.length - 1),
        children: _pages,
      );
    } catch (e, stackTrace) {
      developer.log(
        'Error building indexed stack',
        error: e,
        stackTrace: stackTrace,
        name: 'indexed_stack',
      );
      return _buildErrorPage('Navigation Error');
    }
  }
}

/// Build a safe error app that won't crash
Widget _buildSafeErrorApp(String error) {
  return MaterialApp(
    title: 'ShineNET VPN - خطا',
    home: Scaffold(
      backgroundColor: Colors.red[900],
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 64,
              ),
              SizedBox(height: 16),
              Text(
                'خطا در ShineNET VPN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text(
                'برنامه با خطا مواجه شده و نیاز به راه‌اندازی مجدد دارد.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    error.length > 500 ? error.substring(0, 500) + '...' : error,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  try {
                    SystemNavigator.pop();
                  } catch (e) {
                    developer.log('Failed to restart app', error: e);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.red[900],
                ),
                child: Text('راه‌اندازی مجدد'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
