import 'package:shinenet_vpn/common/theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class ConnectionWidget extends StatefulWidget {
  ConnectionWidget({
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
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _scaleController;
  late AnimationController _rotationController;
  late AnimationController _waveController;
  late AnimationController _colorController;
  late AnimationController _glowController;
  late AnimationController _bounceController;
  
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _waveAnimation;
  late Animation<Color?> _colorAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2000),
    )..repeat();

    _scaleController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 200),
    );

    _rotationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _colorController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _bounceController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400),
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.elasticOut,
    ));

    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: Curves.easeInOut,
    ));

    _colorAnimation = ColorTween(
      begin: ThemeColor.disconnectedColor,
      end: ThemeColor.connectedColor,
    ).animate(CurvedAnimation(
      parent: _colorController,
      curve: Curves.easeInOutCubic,
    ));

    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));

    _bounceAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticOut,
    ));

    // Start wave animation for connected state
    _updateAnimationState();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scaleController.dispose();
    _rotationController.dispose();
    _waveController.dispose();
    _colorController.dispose();
    _glowController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  void _updateAnimationState() {
    if (widget.status.toUpperCase() == "CONNECTED") {
      _waveController.repeat(reverse: true);
      _colorController.forward();
    } else {
      _waveController.stop();
      _waveController.reset();
      _colorController.reverse();
    }
  }

  Color _getShadowColor() {
    if (widget.isLoading) {
      if (_isDisconnectingState()) {
        return ThemeColor.warningColor; // Orange for disconnecting
      }
      return ThemeColor.connectingColor; // Blue for connecting
    } else if (widget.status.toUpperCase() == "CONNECTED") {
      // Use animated color for smooth transition to connected state
      return _colorAnimation.value ?? ThemeColor.connectedColor;
    } else {
      // Use animated color for smooth transition to disconnected state
      return _colorAnimation.value ?? ThemeColor.disconnectedColor;
    }
  }

  Color _getButtonColor() {
    if (widget.isLoading) {
      return ThemeColor.connectingColor.withValues(alpha: 0.2);
    } else if (widget.status.toUpperCase() == "CONNECTED") {
      return ThemeColor.connectedColor.withValues(alpha: 0.2);
    } else {
      return ThemeColor.errorColor.withValues(alpha: 0.2);
    }
  }

  IconData _getStatusIcon() {
    if (widget.isLoading) {
      if (_isDisconnectingState()) {
        return Icons.power_off_rounded; // Power off icon for disconnecting
      }
      return Icons.power_settings_new_rounded; // Power icon for connecting
    } else if (widget.status.toUpperCase() == "CONNECTED") {
      return Icons.shield_rounded; // Shield icon for connected
    } else {
      return Icons.power_settings_new_rounded; // Power icon for disconnected
    }
  }

  @override
  void didUpdateWidget(ConnectionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      print('Status changed from ${oldWidget.status} to ${widget.status}');
      _rotationController.forward().then((_) {
        _rotationController.reset();
      });
      _bounceController.forward().then((_) {
        _bounceController.reverse();
      });
      _updateAnimationState();
    }
  }

  /// Check if the current state indicates disconnecting process
  bool _isDisconnectingState() {
    // Only consider it disconnecting if we're currently connected and then start loading
    // This prevents confusion during initial connection attempts
    final currentStatus = widget.status.toUpperCase();
    
    // If already connected and now loading, it's likely disconnecting
    if (currentStatus == "CONNECTED" && widget.isLoading) {
      return true;
    }
    
    // Check explicit disconnecting states
    final status = widget.status.toLowerCase();
    return status.contains('disconnect') ||
           status == 'disconnecting' ||
           status.contains('stopping') ||
           status.contains('stop');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isSmallScreen = size.width < 350 || size.height < 700;

    final buttonSize = isSmallScreen ? 140.0 : 160.0;
    final iconSize = isSmallScreen ? 70.0 : 80.0;
    final waveSize = isSmallScreen ? 160.0 : 180.0;

    return Column(
      children: [
        GestureDetector(
          onTapDown: (_) {
            HapticFeedback.lightImpact();
            _scaleController.forward();
          },
          onTapUp: (_) {
            _scaleController.reverse();
          },
          onTapCancel: () {
            _scaleController.reverse();
          },
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _pulseController,
              _scaleAnimation,
              _rotationAnimation,
              _waveAnimation,
            ]),
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value * _bounceAnimation.value,
                child: Transform.rotate(
                  angle: _rotationAnimation.value * 0.1,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer wave effect for connected state
                      if (widget.status.toUpperCase() == "CONNECTED")
                        ...List.generate(3, (index) {
                          final delay = index * 0.3;
                          final animValue =
                              (_waveAnimation.value + delay) % 1.0;
                          return Transform.scale(
                            scale: 1.0 + (animValue * 0.3),
                            child: Opacity(
                              opacity: (1.0 - animValue) * 0.3,
                              child: Container(
                                width: waveSize,
                                height: waveSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _getShadowColor(),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      // Main button container
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _getShadowColor().withValues(alpha: 0.4 * _glowAnimation.value),
                              blurRadius: 40 + (20 * _pulseController.value),
                              spreadRadius: 4 + (4 * _pulseController.value),
                            ),
                            BoxShadow(
                              color: _getShadowColor().withValues(alpha: 0.2 * _glowAnimation.value),
                              blurRadius: 80 + (40 * _pulseController.value),
                              spreadRadius: 8 + (8 * _pulseController.value),
                            ),
                            // Add inner glow effect
                            BoxShadow(
                              color: _getShadowColor().withValues(alpha: 0.1 * _glowAnimation.value),
                              blurRadius: 20,
                              spreadRadius: -10,
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: widget.isLoading
                                ? null
                                : () {
                                    HapticFeedback.mediumImpact();
                                    widget.onTap();
                                  },
                            customBorder: CircleBorder(),
                            child: Container(
                              height: buttonSize,
                              width: buttonSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    _getButtonColor().withValues(alpha: 0.8),
                                    _getButtonColor().withValues(alpha: 0.1),
                                  ],
                                ),
                                border: Border.all(
                                  color:
                                      _getShadowColor().withValues(alpha: 0.4),
                                  width: 3,
                                ),
                              ),
                              child: Center(
                                child: widget.isLoading
                                    ? LoadingAnimationWidget.threeArchedCircle(
                                        color: ThemeColor.primaryColor,
                                        size: iconSize,
                                      )
                                    : AnimatedSwitcher(
                                        duration: Duration(milliseconds: 500),
                                        transitionBuilder: (child, animation) {
                                          return ScaleTransition(
                                            scale: Tween<double>(
                                              begin: 0.5,
                                              end: 1.0,
                                            ).animate(CurvedAnimation(
                                              parent: animation,
                                              curve: Curves.elasticOut,
                                            )),
                                            child: RotationTransition(
                                              turns: Tween<double>(
                                                begin: 0.5,
                                                end: 0.0,
                                              ).animate(CurvedAnimation(
                                                parent: animation,
                                                curve: Curves.easeOutBack,
                                              )),
                                              child: FadeTransition(
                                                opacity: animation,
                                                child: child,
                                              ),
                                            ),
                                          );
                                        },
                                        child: Icon(
                                          _getStatusIcon(),
                                          key: ValueKey(widget.status),
                                          color: _getShadowColor(),
                                          size: iconSize,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: ThemeColor.largeSpacing),
        AnimatedSwitcher(
          duration: ThemeColor.mediumAnimation,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(0, 0.5),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: Column(
            key: ValueKey('${widget.isLoading}_${widget.status}'),
            children: [
              Text(
                widget.isLoading
                    ? (_isDisconnectingState()
                        ? 'disconnecting'.tr()
                        : 'connecting'.tr())
                    : widget.status.toUpperCase() == "DISCONNECTED" ||
                            widget.status.isEmpty ||
                            widget.status.toLowerCase() == "disconnected"
                        ? 'disconnected'.tr()
                        : 'connected'.tr(),
                style: ThemeColor.headingStyle(
                  fontSize: isSmallScreen ? 16 : 18,
                  color: _getShadowColor(),
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              SizedBox(height: ThemeColor.smallSpacing),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ThemeColor.mediumSpacing,
                  vertical: ThemeColor.smallSpacing,
                ),
                decoration: BoxDecoration(
                  color: _getShadowColor().withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(ThemeColor.largeRadius),
                  border: Border.all(
                    color: _getShadowColor().withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  _getStatusDescription(),
                  style: ThemeColor.captionStyle(
                    fontSize: isSmallScreen ? 12 : 14,
                    color: _getShadowColor(),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getStatusDescription() {
    if (widget.isLoading) {
      if (_isDisconnectingState()) {
        return 'disconnecting_secure_connection'.tr();
      }
      return 'establishing_secure_connection'.tr();
    } else if (widget.status.toUpperCase() == "CONNECTED") {
      return 'connection_secure_private'.tr();
    } else {
      return 'tap_connect_vpn'.tr();
    }
  }
}
