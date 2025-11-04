import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_v2ray_client/flutter_v2ray.dart';

/// Centralizes flutter_v2ray_client usage across the app to ensure a single
/// shared instance with synchronized status handling and lifecycle management.
class FlutterV2rayClientManager {
  FlutterV2rayClientManager._internal()
      : _statusNotifier = ValueNotifier<V2RayStatus>(V2RayStatus()) {
    _v2ray = V2ray(
      onStatusChanged: (status) {
        _statusNotifier.value = status;
        for (final listener in List<void Function(V2RayStatus)>.from(_statusListeners)) {
          try {
            listener(status);
          } catch (_) {
            // Swallow listener errors to avoid breaking status propagation.
          }
        }
      },
    );
  }

  static final FlutterV2rayClientManager _instance =
      FlutterV2rayClientManager._internal();

  factory FlutterV2rayClientManager() => _instance;

  late final V2ray _v2ray;
  final ValueNotifier<V2RayStatus> _statusNotifier;
  final Set<void Function(V2RayStatus)> _statusListeners =
      <void Function(V2RayStatus)>{};

  bool _isInitialized = false;
  Completer<void>? _initializingCompleter;
  String? _notificationIconResourceType;
  String? _notificationIconResourceName;

  /// Public status notifier to observe V2Ray status changes.
  ValueNotifier<V2RayStatus> get statusNotifier => _statusNotifier;

  /// Exposes the underlying V2Ray client for advanced operations.
  V2ray get client => _v2ray;

  bool get isInitialized => _isInitialized;

  /// Ensure the underlying V2Ray client is initialized. Subsequent calls reuse
  /// the first successful initialization parameters.
  Future<void> ensureInitialized({
    String? notificationIconResourceType,
    String? notificationIconResourceName,
  }) async {
    if (_isInitialized) return;
    if (_initializingCompleter != null) {
      return _initializingCompleter!.future;
    }

    _notificationIconResourceType ??=
        notificationIconResourceType ?? 'mipmap';
    _notificationIconResourceName ??=
        notificationIconResourceName ?? 'ic_launcher';

    _initializingCompleter = Completer<void>();
    try {
      await _v2ray.initialize(
        notificationIconResourceType: _notificationIconResourceType!,
        notificationIconResourceName: _notificationIconResourceName!,
      );
      _isInitialized = true;
      _initializingCompleter!.complete();
    } catch (error, stackTrace) {
      _initializingCompleter!.completeError(error, stackTrace);
      rethrow;
    } finally {
      _initializingCompleter = null;
    }
  }

  /// Request the necessary VPN permission from the operating system.
  Future<bool> requestPermission() async {
    return _v2ray.requestPermission();
  }

  /// Start a V2Ray connection with the provided configuration.
  Future<void> start({
    required String config,
    String remark = 'ShineNET VPN',
    bool proxyOnly = false,
    List<String>? blockedApps,
    List<String>? bypassSubnets,
    String? notificationDisconnectButtonName,
  }) async {
    await ensureInitialized();
    await _v2ray.startV2Ray(
      remark: remark,
      config: config,
      proxyOnly: proxyOnly,
      blockedApps: blockedApps,
      bypassSubnets: bypassSubnets,
      notificationDisconnectButtonName: notificationDisconnectButtonName ??
          'DISCONNECT',
    );
  }

  /// Stop the active V2Ray connection if any.
  Future<void> stop() async {
    if (!_isInitialized) return;
    try {
      await _v2ray.stopV2Ray();
    } catch (_) {
      // Ignore stop errors to keep shutdown resilient.
    }
  }

  /// Retrieve the core version once initialization is complete.
  Future<String?> getCoreVersion() async {
    await ensureInitialized();
    return _v2ray.getCoreVersion();
  }

  /// Add an additional listener for status changes.
  void addStatusListener(void Function(V2RayStatus) listener) {
    _statusListeners.add(listener);
  }

  /// Remove a previously added status listener.
  void removeStatusListener(void Function(V2RayStatus) listener) {
    _statusListeners.remove(listener);
  }
}
