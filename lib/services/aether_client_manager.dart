import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AetherState {
  disconnected,
  connecting,
  connected,
  failed,
}

class AetherClientManager {
  AetherClientManager._internal();

  static final AetherClientManager _instance = AetherClientManager._internal();
  factory AetherClientManager() => _instance;

  static const MethodChannel _channel =
      MethodChannel('com.shythonx.shinenet_vpn/aether');
  static const EventChannel _statusChannel =
      EventChannel('com.shythonx.shinenet_vpn/aether_status');

  static const String _connectedSinceKey = 'aether_connected_since';

  final StreamController<AetherState> _stateController =
      StreamController<AetherState>.broadcast();

  AetherState _currentState = AetherState.disconnected;
  bool _nativeLibsLoaded = false;
  bool _pollingReadiness = false;
  StreamSubscription<dynamic>? _nativeStatusSubscription;

  DateTime? _connectedSince;
  Timer? _durationTimer;
  final ValueNotifier<String> durationNotifier = ValueNotifier('00:00:00');

  Stream<AetherState> get stateStream => _stateController.stream;
  AetherState get currentState => _currentState;
  bool get areNativeLibsLoaded => _nativeLibsLoaded;

  /// Sync Flutter state with actual native VPN service state.
  /// Call this on app startup to detect if Aether is already running.
  Future<void> syncState() async {
    if (!_nativeLibsLoaded) return;
    try {
      final running = await isRunning();
      final ready = await isReady();
      if (running && ready && _currentState != AetherState.connected) {
        await _restoreConnectedSince();
        _updateState(AetherState.connected);
      } else if (running && !ready && _currentState != AetherState.connecting) {
        // Service is running but not ready yet — start polling
        _updateState(AetherState.connecting);
        _pollReadiness();
      } else if (!running && _currentState != AetherState.disconnected) {
        _updateState(AetherState.disconnected);
      }
    } catch (e) {
      // Native libs might not be loaded yet
    }
  }

  Future<bool> checkNativeLibs() async {
    try {
      final result = await _channel.invokeMethod<Map>('checkNativeLibs');
      _nativeLibsLoaded =
          (result?['aetherLoaded'] ?? false) && (result?['jniLoaded'] ?? false);
      if (_nativeLibsLoaded) {
        _listenToNativeStatus();
      }
      return _nativeLibsLoaded;
    } catch (e) {
      _nativeLibsLoaded = false;
      return false;
    }
  }

  void _listenToNativeStatus() {
    if (_nativeStatusSubscription != null) return;

    _nativeStatusSubscription =
        _statusChannel.receiveBroadcastStream().listen((event) {
      if (event is! Map) return;
      switch (event['status']?.toString().toLowerCase()) {
        case 'connecting':
          _updateState(AetherState.connecting);
          break;
        case 'connected':
          _updateState(AetherState.connected);
          break;
        case 'failed':
          _updateState(AetherState.failed);
          break;
        case 'disconnected':
          _updateState(AetherState.disconnected);
          break;
      }
    }, onError: (_) {
      // Native polling remains active as a fallback.
      _nativeStatusSubscription?.cancel();
      _nativeStatusSubscription = null;
    });
  }

  Future<bool> requestVpnPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestVpnPermission');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<void> start({
    required String protocol,
    String scanMode = 'turbo',
    String ipScan = 'v4',
    String obfuscation = 'firewall',
    String transport = 'auto',
    int socksPort = 1819,
  }) async {
    if (_currentState == AetherState.connecting) return;

    _updateState(AetherState.connecting);

    try {
      await _channel.invokeMethod('startAether', {
        'protocol': protocol,
        'scanMode': scanMode,
        'ipScan': ipScan,
        'obfuscation': obfuscation,
        'transport': transport,
        'socksPort': socksPort,
      });

      _pollReadiness();
    } catch (e) {
      _updateState(AetherState.failed);
      rethrow;
    }
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopAether');
      _updateState(AetherState.disconnected);
    } catch (e) {
      // Ignore stop errors
    }
  }

  Future<bool> isRunning() async {
    try {
      final result = await _channel.invokeMethod<bool>('isRunning');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isReady() async {
    try {
      final result = await _channel.invokeMethod<bool>('isReady');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<String> getLastLog() async {
    try {
      final result = await _channel.invokeMethod<String>('getLastLog');
      return result ?? '';
    } catch (e) {
      return '';
    }
  }

  Future<String> getLastError() async {
    try {
      final result = await _channel.invokeMethod<String>('getLastError');
      return result ?? '';
    } catch (e) {
      return '';
    }
  }

  /// Poll for tunnel readiness after starting.
  /// The VPN service starts asynchronously, so we give it time to boot up.
  void _pollReadiness() async {
    if (_pollingReadiness) return;
    _pollingReadiness = true;

    try {
      // Short delay for VPN service bootstrap
      await Future.delayed(const Duration(milliseconds: 400));

      int ticks = 0;
      const maxWaitSeconds = 90;

      while (_currentState == AetherState.connecting && ticks < maxWaitSeconds) {
        await Future.delayed(const Duration(milliseconds: 500));
        ticks++;

        try {
          final ready = await isReady();
          if (ready && _currentState == AetherState.connecting) {
            _updateState(AetherState.connected);
            return;
          }

          final running = await isRunning();
          final error = await getLastError();

          // Fail fast when native prepare/start already reported an error
          if (error.isNotEmpty &&
              !running &&
              ticks >= 2 &&
              _currentState == AetherState.connecting) {
            _updateState(AetherState.failed);
            return;
          }

          if (!running && ticks > 10 && _currentState == AetherState.connecting) {
            _updateState(AetherState.failed);
            return;
          }
        } catch (e) {
          // Continue polling
        }
      }

      // Timeout
      if (_currentState == AetherState.connecting) {
        _updateState(AetherState.failed);
      }
    } finally {
      _pollingReadiness = false;
    }
  }

  void _updateState(AetherState newState) {
    final wasConnected = _currentState == AetherState.connected;
    _currentState = newState;

    if (newState == AetherState.connected && !wasConnected) {
      if (_connectedSince == null) {
        _connectedSince = DateTime.now();
        _saveConnectedSince(_connectedSince!);
      }
      _startDurationTimer();
    } else if (newState != AetherState.connected && wasConnected) {
      _connectedSince = null;
      _clearConnectedSince();
      _stopDurationTimer();
      durationNotifier.value = '00:00:00';
    }

    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  Future<void> _restoreConnectedSince() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_connectedSinceKey);
    if (iso != null) {
      _connectedSince = DateTime.tryParse(iso);
    }
  }

  Future<void> _saveConnectedSince(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_connectedSinceKey, time.toIso8601String());
  }

  Future<void> _clearConnectedSince() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_connectedSinceKey);
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _updateDuration();
    _durationTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateDuration(),
    );
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  void _updateDuration() {
    if (_connectedSince == null) return;
    final elapsed = DateTime.now().difference(_connectedSince!);
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes.remainder(60);
    final seconds = elapsed.inSeconds.remainder(60);
    durationNotifier.value =
        '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void dispose() {
    _stopDurationTimer();
    _nativeStatusSubscription?.cancel();
    _nativeStatusSubscription = null;
  }
}
