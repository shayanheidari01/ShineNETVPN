import 'package:shinenet_vpn/common/theme.dart';
import 'package:shinenet_vpn/screens/about_screen.dart';
import 'package:shinenet_vpn/screens/home_screen.dart';
import 'package:shinenet_vpn/screens/settings_screen.dart';
import 'package:shinenet_vpn/widgets/navigation_rail_widget.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_v2ray/model/v2ray_status.dart';
import 'package:iconsax/iconsax.dart';
import 'package:safe_device/safe_device.dart';
import 'dart:async';
import 'dart:developer' as developer;

void main() async {
  runZonedGuarded(
    () async {
      try {
        await _initializeApp();
      } catch (error, stackTrace) {
        developer.log(
          'Fatal initialization error',
          error: error,
          stackTrace: stackTrace,
          name: 'main',
        );
        // Show fallback error app
        runApp(_buildErrorApp(error.toString()));
      }
    },
    (error, stackTrace) {
      developer.log(
        'Uncaught error in app',
        error: error,
        stackTrace: stackTrace,
        name: 'main',
      );
      // Log to crash reporting service if needed
      if (!kDebugMode) {
        // In production, you might want to send to crashlytics or similar
      }
    },
  );
}

Future<void> _initializeApp() async {
  try {
    // Ensure Flutter binding is initialized first
    WidgetsFlutterBinding.ensureInitialized();
    
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
        developer.log('Initialization timeout, continuing with available services');
        return [];
      },
    );
    
    developer.log('App initialization completed successfully');
    
    // Run the main app after successful initialization
    _runMainApp();
    
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
        isJailBroken = await SafeDevice.isJailBroken
            .timeout(Duration(seconds: 3));
        break; // Success, exit retry loop
      } catch (e) {
        developer.log(
          'Device security check attempt ${attempt + 1} failed',
          error: e,
          name: 'security_check',
        );
        
        if (attempt == 2) {
          // Final attempt failed, default to safe
          developer.log('All security check attempts failed, assuming safe device');
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
    await EasyLocalization.ensureInitialized()
        .timeout(Duration(seconds: 5));
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

void _runMainApp() {
  runApp(
    EasyLocalization(
      supportedLocales: [
        Locale('en', 'US'),
        Locale('fa', 'IR'),
        Locale('zh', 'CN'),
        Locale('ru', 'RU'),
      ],
      path: 'assets/translations',
      fallbackLocale: Locale('en', 'US'),
      startLocale: Locale('en', 'US'),
      saveLocale: true,
      errorWidget: (FlutterError? error) {
        developer.log(
          'Localization error widget',
          error: error,
          name: 'localization',
        );
        return Text(
          'Translation Error',
          style: TextStyle(color: Colors.red),
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

// Fallback apps for error scenarios
Widget _buildErrorApp(String error) {
  return MaterialApp(
    title: 'ShineNET VPN - Error',
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
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              SizedBox(height: 24),
              Text(
                'Application Error',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text(
                'The application encountered an error during initialization. Please restart the app.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[300],
                ),
                textAlign: TextAlign.center,
              ),
              if (kDebugMode) ...[
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Text(
                    'Debug Info: $error',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red[300],
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // Restart the app
                  SystemNavigator.pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text('Restart App'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
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
                'Security Check Failed',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text(
                'This application cannot run on modified or jailbroken devices for security reasons.',
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
        developer.log('App resumed', name: 'lifecycle');
        _handleAppResumed();
        break;
      case AppLifecycleState.inactive:
        developer.log('App inactive', name: 'lifecycle');
        _handleAppInactive();
        break;
      case AppLifecycleState.paused:
        developer.log('App paused', name: 'lifecycle');
        _handleAppPaused();
        break;
      case AppLifecycleState.detached:
        developer.log('App detached', name: 'lifecycle');
        _handleAppDetached();
        break;
      case AppLifecycleState.hidden:
        developer.log('App hidden', name: 'lifecycle');
        _handleAppHidden();
        break;
    }
  }

  void _handleAppResumed() {
    try {
      // Refresh app state when returning from background
      // Check for memory pressure and clean up if needed
      _performMemoryCleanup(false);
    } catch (e) {
      developer.log(
        'Error handling app resume',
        error: e,
        name: 'lifecycle',
      );
    }
  }

  void _handleAppInactive() {
    try {
      // Prepare for potential app suspension
      // Save critical state
    } catch (e) {
      developer.log(
        'Error handling app inactive',
        error: e,
        name: 'lifecycle',
      );
    }
  }

  void _handleAppPaused() {
    try {
      // App goes to background - cleanup resources
      _performMemoryCleanup(true);
      // Pause non-essential operations
      // Clear sensitive UI data if needed
    } catch (e) {
      developer.log(
        'Error during app pause cleanup',
        error: e,
        name: 'lifecycle',
      );
    }
  }

  void _handleAppDetached() {
    try {
      // Final cleanup before app destruction
      _performMemoryCleanup(true);
      // Close any open resources
      // Save critical data
    } catch (e) {
      developer.log(
        'Error during app detached cleanup',
        error: e,
        name: 'lifecycle',
      );
    }
  }

  void _handleAppHidden() {
    try {
      // App is hidden - similar to paused but less severe
      _performMemoryCleanup(false);
    } catch (e) {
      developer.log(
        'Error handling app hidden',
        error: e,
        name: 'lifecycle',
      );
    }
  }

  void _performMemoryCleanup(bool aggressive) {
    try {
      if (aggressive) {
        // Aggressive cleanup for background/detached states
        // Force garbage collection if available
        // Clear image caches
        // Clear network caches
      } else {
        // Light cleanup for inactive/hidden states
        // Clear expired caches
      }
    } catch (e) {
      developer.log(
        'Error during memory cleanup',
        error: e,
        name: 'memory_management',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      // Defensive programming: ensure context is valid
      if (!mounted) {
        return Container();
      }

      final defaultTextStyle = TextStyle(
        fontFamily: 'GM',
        color: ThemeColor.primaryText,
      );

      return MaterialApp(
        title: 'ShineNET VPN',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          textTheme: TextTheme(
            titleLarge: defaultTextStyle.copyWith(fontSize: 22, fontWeight: FontWeight.bold),
            titleMedium: defaultTextStyle.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
            titleSmall: defaultTextStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w500),
            bodyLarge: defaultTextStyle.copyWith(fontSize: 16),
            bodyMedium: defaultTextStyle.copyWith(fontSize: 14),
            bodySmall: defaultTextStyle.copyWith(fontSize: 12),
            labelLarge: defaultTextStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
            labelMedium: defaultTextStyle.copyWith(fontSize: 12, fontWeight: FontWeight.w500),
            labelSmall: defaultTextStyle.copyWith(fontSize: 10, fontWeight: FontWeight.w500),
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: ThemeColor.backgroundColor,
          cardColor: ThemeColor.cardColor,
          primaryColor: ThemeColor.primaryColor,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.dark(
            primary: ThemeColor.primaryColor,
            secondary: ThemeColor.secondaryColor,
            surface: ThemeColor.surfaceColor,
            background: ThemeColor.backgroundColor,
            error: ThemeColor.errorColor,
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: ThemeColor.primaryText,
            onBackground: ThemeColor.primaryText,
            onError: Colors.white,
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: ThemeColor.backgroundColor,
            foregroundColor: ThemeColor.foregroundColor,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: ThemeColor.headingStyle(
              fontSize: 20,
            ),
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              systemNavigationBarColor: ThemeColor.backgroundColor,
              systemNavigationBarIconBrightness: Brightness.light,
            ),
          ),
          cardTheme: CardTheme(
            color: ThemeColor.cardColor,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
            ),
            margin: EdgeInsets.symmetric(
              horizontal: ThemeColor.mediumSpacing,
              vertical: ThemeColor.smallSpacing,
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
              borderSide: BorderSide(color: ThemeColor.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
              borderSide: BorderSide(color: ThemeColor.borderColor.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
              borderSide: BorderSide(color: ThemeColor.primaryColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
              borderSide: BorderSide(color: ThemeColor.errorColor),
            ),
            filled: true,
            fillColor: ThemeColor.surfaceColor,
            contentPadding: EdgeInsets.symmetric(
              horizontal: ThemeColor.mediumSpacing,
              vertical: ThemeColor.mediumSpacing,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeColor.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: ThemeColor.primaryColor.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: ThemeColor.largeSpacing,
                vertical: ThemeColor.mediumSpacing,
              ),
              textStyle: ThemeColor.bodyStyle(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: ThemeColor.primaryColor,
              padding: EdgeInsets.symmetric(
                horizontal: ThemeColor.mediumSpacing,
                vertical: ThemeColor.smallSpacing,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
              ),
            ),
          ),
          snackBarTheme: SnackBarThemeData(
            backgroundColor: ThemeColor.surfaceColor,
            contentTextStyle: ThemeColor.bodyStyle(),
            actionTextColor: ThemeColor.primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
            ),
            behavior: SnackBarBehavior.floating,
          ),
          bottomSheetTheme: BottomSheetThemeData(
            backgroundColor: ThemeColor.backgroundColor,
            modalBackgroundColor: ThemeColor.backgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(ThemeColor.xlRadius),
              ),
            ),
            elevation: 0,
          ),
          dialogTheme: DialogTheme(
            backgroundColor: ThemeColor.surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ThemeColor.largeRadius),
            ),
            elevation: 0,
            titleTextStyle: ThemeColor.headingStyle(
              fontSize: 18,
            ),
            contentTextStyle: ThemeColor.bodyStyle(),
          ),
          pageTransitionsTheme: PageTransitionsTheme(
            builders: {
              TargetPlatform.android: CupertinoPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            },
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

  List<LocalizationsDelegate> _safeGetLocalizationDelegates(BuildContext context) {
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
                'Widget Error',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (kDebugMode) ...[
                SizedBox(height: 8),
                Text(
                  errorDetails.exception.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red[300],
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
              'Fallback Mode',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'App is running in safe mode',
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
              child: Text('Retry'),
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
          final isWideScreen = constraints.maxWidth > 600;
          
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: _buildIndexedStack(),
                  ),
                  _buildNavigationRail(isWideScreen),
                ],
              ),
            ),
            bottomNavigationBar: _buildBottomNavigation(isWideScreen),
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

  Widget _buildIndexedStack() {
    try {
      return IndexedStack(
        index: _selectedIndex.clamp(0, _pages.length - 1),
        children: _pages,
      );
    } catch (e) {
      developer.log(
        'Error building indexed stack',
        error: e,
        name: 'indexed_stack',
      );
      return _buildErrorPage('Content Error');
    }
  }

  Widget _buildNavigationRail(bool isWideScreen) {
    if (!isWideScreen) return SizedBox.shrink();
    
    try {
      return AnimatedSlide(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        offset: Offset.zero,
        child: AnimatedOpacity(
          duration: Duration(milliseconds: 200),
          opacity: 1,
          child: NavigationRailWidget(
            selectedIndex: _selectedIndex,
            singStatus: v2rayStatus,
            onDestinationSelected: (index) {
              if (mounted && index >= 0 && index < _pages.length) {
                setState(() => _selectedIndex = index);
              }
            },
          ),
        ),
      );
    } catch (e) {
      developer.log(
        'Error building navigation rail',
        error: e,
        name: 'navigation_rail',
      );
      return SizedBox.shrink();
    }
  }

  Widget? _buildBottomNavigation(bool isWideScreen) {
    if (isWideScreen) return null;
    
    try {
      return Container(
        decoration: BoxDecoration(
          color: Color(0xff192028),
          border: Border(
            top: BorderSide(
              color: Colors.grey.withOpacity(0.1),
              width: 1,
            ),
          ),
        ),
        child: NavigationBar(
          backgroundColor: Color(0xff192028),
          selectedIndex: _selectedIndex.clamp(0, 2),
          onDestinationSelected: (index) {
            if (mounted && index >= 0 && index < _pages.length) {
              setState(() => _selectedIndex = index);
            }
          },
          destinations: [
            NavigationDestination(
              icon: Icon(Iconsax.setting, color: Colors.grey),
              selectedIcon: Icon(Iconsax.setting, color: Colors.white),
              label: '',
            ),
            NavigationDestination(
              icon: Icon(Iconsax.home, color: Colors.grey),
              selectedIcon: Icon(Iconsax.home, color: Colors.white),
              label: '',
            ),
            NavigationDestination(
              icon: Icon(Iconsax.info_circle, color: Colors.grey),
              selectedIcon: Icon(Iconsax.info_circle, color: Colors.white),
              label: '',
            ),
          ],
        ),
      );
    } catch (e) {
      developer.log(
        'Error building bottom navigation',
        error: e,
        name: 'bottom_navigation',
      );
      return null;
    }
  }
}
