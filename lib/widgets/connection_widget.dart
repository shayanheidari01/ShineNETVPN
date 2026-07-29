import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shinenet_vpn/common/theme.dart';

class ConnectionWidget extends StatefulWidget {
  const ConnectionWidget({
    super.key,
    required this.onTap,
    required this.isLoading,
    required this.status,
  });

  final bool isLoading;
  final GestureTapCallback onTap;
  final String status;

  @override
  State<ConnectionWidget> createState() => _ConnectionWidgetState();
}

class _ConnectionWidgetState extends State<ConnectionWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant ConnectionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLoading != widget.isLoading ||
        oldWidget.status != widget.status) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.isLoading) {
      _controller.repeat();
    } else {
      _controller
        ..stop()
        ..reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _connected {
    final state = widget.status.toUpperCase();
    return const {'CONNECTED', 'RUNNING', 'STARTED'}.contains(state);
  }

  bool get _failed => widget.status.toUpperCase() == 'FAILED';

  bool get _disconnecting {
    final status = widget.status.toLowerCase();
    return widget.isLoading &&
            const {'connected', 'running', 'started'}
                .contains(status.toLowerCase()) ||
        status.contains('disconnect') ||
        status.contains('stopping');
  }

  Color get _statusColor {
    if (_failed) return ThemeColor.errorColor;
    if (widget.isLoading) return ThemeColor.warningColor;
    if (_connected) return ThemeColor.successColor;
    return ThemeColor.secondaryText;
  }

  String get _statusLabel {
    if (widget.isLoading) {
      return _disconnecting ? 'disconnecting'.tr() : 'connecting'.tr();
    }
    if (_failed) return 'failed'.tr();
    return _connected ? 'connected'.tr() : 'disconnected'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor;

    return Semantics(
      button: true,
      enabled: true,
      label: _statusLabel,
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Transform.rotate(
                angle: widget.isLoading
                    ? _controller.value * math.pi * 2
                    : 0,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      widget.onTap();
                    },
                    child: AnimatedContainer(
                      duration: ThemeColor.mediumAnimation,
                      width: 148,
                      height: 148,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.07),
                        border: Border.all(
                          color: color.withValues(alpha: 0.30),
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ThemeColor.surfaceColor,
                          border: Border.all(color: ThemeColor.borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(
                                alpha: _connected ? 0.18 : 0.07,
                              ),
                              blurRadius: 32,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          widget.isLoading
                              ? Icons.stop_circle_outlined
                              : _failed
                                  ? Icons.priority_high_rounded
                                  : _connected
                                      ? Icons.shield_rounded
                                      : Icons.power_settings_new_rounded,
                          color: color,
                          size: 54,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 22),
          AnimatedSwitcher(
            duration: ThemeColor.fastAnimation,
            child: Text(
              _statusLabel,
              key: ValueKey(_statusLabel),
              style: ThemeColor.headingStyle(
                fontSize: 23,
                color: ThemeColor.primaryText,
                context: context,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
