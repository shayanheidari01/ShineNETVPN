import 'package:shinenet_vpn/common/theme.dart';
import 'package:shinenet_vpn/common/animations.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
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
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2000),
    )..repeat();

    _scaleController = AnimationController(
      vsync: this,
      duration: ThemeColor.mediumAnimation,
    );

    _rotationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    _waveController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
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

    // Start wave animation for connected state
    _updateAnimationState();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scaleController.dispose();
    _rotationController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ConnectionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _rotationController.forward().then((_) {
        _rotationController.reset();
      });
      _updateAnimationState();
    }
  }

  void _updateAnimationState() {
    if (widget.status == "CONNECTED") {
      _waveController.repeat(reverse: true);
    } else {
      _waveController.stop();
      _waveController.reset();
    }
  }

  Color _getShadowColor() {
    if (widget.isLoading) {
      return ThemeColor.connectingColor;
    } else if (widget.status == "CONNECTED") {
      return ThemeColor.connectedColor;
    } else {
      return ThemeColor.disconnectedColor;
    }
  }

  Color _getButtonColor() {
    if (widget.isLoading) {
      return ThemeColor.connectingColor.withOpacity(0.2);
    } else if (widget.status == "CONNECTED") {
      return ThemeColor.connectedColor.withOpacity(0.2);
    } else {
      return ThemeColor.errorColor.withOpacity(0.2);
    }
  }

  IconData _getStatusIcon() {
    if (widget.status == "CONNECTED") {
      return CupertinoIcons.checkmark_shield_fill;
    } else {
      return CupertinoIcons.power;
    }
  }

  @override
  Widget build(BuildContext context) {
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
                scale: _scaleAnimation.value,
                child: Transform.rotate(
                  angle: _rotationAnimation.value * 0.1,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer wave effect for connected state
                      if (widget.status == "CONNECTED")
                        ...List.generate(3, (index) {
                          final delay = index * 0.3;
                          final animValue =
                              (_waveAnimation.value + delay) % 1.0;
                          return Transform.scale(
                            scale: 1.0 + (animValue * 0.3),
                            child: Opacity(
                              opacity: (1.0 - animValue) * 0.3,
                              child: Container(
                                width: 180,
                                height: 180,
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
                              color: _getShadowColor().withOpacity(0.4),
                              blurRadius: 40 + (20 * _pulseController.value),
                              spreadRadius: 4 + (4 * _pulseController.value),
                            ),
                            BoxShadow(
                              color: _getShadowColor().withOpacity(0.2),
                              blurRadius: 80 + (40 * _pulseController.value),
                              spreadRadius: 8 + (8 * _pulseController.value),
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
                              height: 160,
                              width: 160,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    _getButtonColor().withOpacity(0.8),
                                    _getButtonColor().withOpacity(0.1),
                                  ],
                                ),
                                border: Border.all(
                                  color: _getShadowColor().withOpacity(0.4),
                                  width: 3,
                                ),
                              ),
                              child: Center(
                                child: widget.isLoading
                                    ? LoadingAnimationWidget.threeArchedCircle(
                                        color: ThemeColor.primaryColor,
                                        size: 70,
                                      )
                                    : AnimatedSwitcher(
                                        duration: ThemeColor.mediumAnimation,
                                        transitionBuilder: (child, animation) {
                                          return ScaleTransition(
                                            scale: animation,
                                            child: RotationTransition(
                                              turns: animation,
                                              child: child,
                                            ),
                                          );
                                        },
                                        child: Icon(
                                          _getStatusIcon(),
                                          key: ValueKey(widget.status),
                                          color: _getShadowColor(),
                                          size: 80,
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
                    ? context.tr('connecting')
                    : widget.status == "DISCONNECTED"
                        ? context.tr('disconnected')
                        : context.tr('connected'),
                style: ThemeColor.headingStyle(
                  fontSize: 20,
                  color: _getShadowColor(),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: ThemeColor.smallSpacing),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ThemeColor.mediumSpacing,
                  vertical: ThemeColor.smallSpacing,
                ),
                decoration: BoxDecoration(
                  color: _getShadowColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(ThemeColor.largeRadius),
                  border: Border.all(
                    color: _getShadowColor().withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  _getStatusDescription(),
                  style: ThemeColor.captionStyle(
                    color: _getShadowColor(),
                    fontWeight: FontWeight.w500,
                  ),
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
      return 'Establishing secure connection...';
    } else if (widget.status == "CONNECTED") {
      return 'Your connection is secure and private';
    } else {
      return 'Tap to connect to VPN';
    }
  }
}
