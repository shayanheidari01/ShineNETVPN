import 'package:flutter/material.dart';
import 'package:shinenet_vpn/common/font_helper.dart';

class ThemeColor {
  // Modern minimal color palette
  static const Color backgroundColor = Color(0xff0F0F0F); // Deep modern black
  static const Color surfaceColor = Color(0xff1C1C1E); // iOS-inspired surface
  static const Color cardColor = Color(0xff2C2C2E); // Elevated modern surface
  static const Color foregroundColor = Color(0xffFFFFFF); // Pure white

  // Modern accent colors
  static const Color primaryColor = Color(0xff0A84FF); // Modern iOS blue
  static const Color secondaryColor = Color(0xff8E8E93); // Subtle gray
  static const Color successColor = Color(0xff34C759); // Modern green
  static const Color warningColor = Color(0xffFF9F0A); // Modern orange
  static const Color errorColor = Color(0xffFF453A); // Modern red

  // Modern text colors
  static const Color primaryText = Color(0xffFFFFFF);
  static const Color secondaryText = Color(0xffAEAEB2);
  static const Color mutedText = Color(0xff8E8E93);

  // Modern border and divider colors
  static const Color borderColor = Color(0xff38383A);
  static const Color dividerColor = Color(0xff2C2C2E);

  // Modern connection status colors
  static const Color connectedColor = Color(0xff34C759);
  static const Color connectingColor = Color(0xffFF9F0A);
  static const Color disconnectedColor = Color(0xff8E8E93);

  // Modern gradient designs
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xff0A84FF), Color(0xff64D2FF)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xff2C2C2E), Color(0xff1C1C1E)],
  );

  static const LinearGradient connectionGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xff34C759), Color(0xff30D158)],
  );

  // Modern shadow and glow effects
  static const Color shadowColor = Color(0x40000000);
  static const Color glowColor = Color(0x330A84FF);

  // Smooth animation durations
  static const Duration fastAnimation = Duration(milliseconds: 250);
  static const Duration mediumAnimation = Duration(milliseconds: 420);
  static const Duration slowAnimation = Duration(milliseconds: 750);

  // Modern border radius values
  static const double smallRadius = 12.0;
  static const double mediumRadius = 16.0;
  static const double largeRadius = 20.0;
  static const double xlRadius = 28.0;

  // Consistent spacing system
  static const double smallSpacing = 8.0;
  static const double mediumSpacing = 16.0;
  static const double largeSpacing = 24.0;
  static const double xlSpacing = 32.0;

  // Helper methods for modern UI components
  static BoxDecoration cardDecoration({
    Color? color,
    double? radius,
    bool withBorder = false,
    bool withShadow = true,
    bool withGradient = false,
  }) {
    return BoxDecoration(
      color: withGradient ? null : (color ?? cardColor),
      gradient: withGradient ? cardGradient : null,
      borderRadius: BorderRadius.circular(radius ?? mediumRadius),
      border: withBorder
          ? Border.all(
              color: borderColor.withValues(alpha: 0.3),
              width: 0.5,
            )
          : null,
      boxShadow: withShadow
          ? [
              BoxShadow(
                color: shadowColor.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ]
          : null,
    );
  }

  static BoxDecoration glassDecoration({
    double opacity = 0.1,
    double? radius,
    bool withBorder = true,
  }) {
    return BoxDecoration(
      color: foregroundColor.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(radius ?? mediumRadius),
      border: withBorder
          ? Border.all(
              color: foregroundColor.withValues(alpha: 0.2),
              width: 0.5,
            )
          : null,
      boxShadow: [
        BoxShadow(
          color: shadowColor.withValues(alpha: 0.05),
          blurRadius: 10,
          spreadRadius: -5,
        ),
      ],
    );
  }

  static TextStyle headingStyle({
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.bold,
    Color? color,
    BuildContext? context,
  }) {
    try {
      return FontHelper.getHeadingStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color ?? primaryText,
        context: context,
      );
    } catch (e) {
      return TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color ?? primaryText,
      );
    }
  }

  static TextStyle bodyStyle({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    BuildContext? context,
  }) {
    try {
      return FontHelper.getBodyStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color ?? secondaryText,
        context: context,
      );
    } catch (e) {
      return TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color ?? secondaryText,
      );
    }
  }

  static TextStyle captionStyle({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    BuildContext? context,
  }) {
    try {
      return FontHelper.getCaptionStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color ?? mutedText,
        context: context,
      );
    } catch (e) {
      return TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color ?? mutedText,
      );
    }
  }

  // Modern server icon helper
  static Widget buildServerIcon({
    required String serverType,
    double size = 32,
    Color? color,
    bool isSelected = false,
  }) {
    IconData iconData;
    Color iconColor = color ?? (isSelected ? primaryColor : secondaryText);

    switch (serverType.toLowerCase()) {
      case 'automatic':
      case 'auto':
        iconData = Icons.auto_awesome_rounded;
        break;
      case 'server 1':
      case 'server1':
        iconData = Icons.dns_rounded;
        break;
      case 'server 2':
      case 'server2':
        iconData = Icons.cloud_rounded;
        break;
      default:
        iconData = Icons.router_rounded;
    }

    return Container(
      width: size + 16,
      height: size + 16,
      decoration: BoxDecoration(
        color: isSelected
            ? primaryColor.withValues(alpha: 0.15)
            : surfaceColor.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(smallRadius),
        border: isSelected
            ? Border.all(color: primaryColor.withValues(alpha: 0.3), width: 1)
            : null,
      ),
      child: Icon(
        iconData,
        size: size,
        color: iconColor,
      ),
    );
  }

  // Modern connection status indicator
  static Widget buildConnectionIndicator({
    required String status,
    double size = 12,
  }) {
    Color indicatorColor;
    switch (status.toLowerCase()) {
      case 'connected':
        indicatorColor = successColor;
        break;
      case 'connecting':
        indicatorColor = warningColor;
        break;
      default:
        indicatorColor = mutedText;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: indicatorColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: indicatorColor.withValues(alpha: 0.4),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}
