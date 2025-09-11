import 'package:flutter/material.dart';
import '../common/theme.dart';

class ConnectionButton extends StatelessWidget {
  final bool isConnected;
  final bool isConnecting;
  final VoidCallback onTap;
  final String? serverName;

  const ConnectionButton({
    Key? key,
    required this.isConnected,
    required this.isConnecting,
    required this.onTap,
    this.serverName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 180,
        height: 180,
        decoration: ThemeColor.glassDecoration(
          opacity: 0.05,
          radius: 90,
          withBorder: true,
        ).copyWith(
          border: Border.all(
            color: _getBorderColor(),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getBackgroundColor(),
            ),
            child: Center(
              child: Icon(
                _getIcon(),
                size: 48,
                color: ThemeColor.foregroundColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getBorderColor() {
    if (isConnecting) return ThemeColor.warningColor.withOpacity(0.5);
    if (isConnected) return ThemeColor.primaryColor.withOpacity(0.5);
    return ThemeColor.foregroundColor.withOpacity(0.1);
  }

  Color _getBackgroundColor() {
    if (isConnecting) return ThemeColor.warningColor.withOpacity(0.1);
    if (isConnected) return ThemeColor.primaryColor.withOpacity(0.1);
    return ThemeColor.cardColor;
  }

  IconData _getIcon() {
    if (isConnecting) return Icons.wifi_protected_setup_rounded;
    if (isConnected) return Icons.wifi_rounded;
    return Icons.wifi_off_rounded;
  }
}
