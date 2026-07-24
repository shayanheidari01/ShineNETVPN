import 'package:flutter/material.dart';
import 'package:shinenet_vpn/common/font_helper.dart';

/// ShineNET's compact design system.
///
/// The UI intentionally uses one accent, quiet surfaces and subtle borders.
/// Status colors are reserved for actual connection feedback.
class ThemeColor {
  static const Color backgroundColor = Color(0xFF07110F);
  static const Color surfaceColor = Color(0xFF0D1A17);
  static const Color cardColor = Color(0xFF13231F);
  static const Color elevatedSurface = Color(0xFF192B26);
  static const Color foregroundColor = Color(0xFFF2F7F5);

  static const Color primaryColor = Color(0xFF5EE8B0);
  static const Color secondaryColor = Color(0xFF8BA39B);
  static const Color successColor = Color(0xFF5EE8B0);
  static const Color warningColor = Color(0xFFFFC56B);
  static const Color errorColor = Color(0xFFFF7B7B);

  static const Color primaryText = Color(0xFFF2F7F5);
  static const Color secondaryText = Color(0xFFA9BBB5);
  static const Color mutedText = Color(0xFF71857E);
  static const Color borderColor = Color(0xFF223A33);
  static const Color dividerColor = Color(0xFF1C312B);

  static const Color connectedColor = successColor;
  static const Color connectingColor = warningColor;
  static const Color disconnectedColor = Color(0xFF8BA39B);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6CF0B9), Color(0xFF35C995)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF162822), Color(0xFF0E1C18)],
  );

  static const LinearGradient connectionGradient = primaryGradient;

  static const Color shadowColor = Color(0x66000000);
  static const Color glowColor = Color(0x335EE8B0);

  static const Duration fastAnimation = Duration(milliseconds: 180);
  static const Duration mediumAnimation = Duration(milliseconds: 320);
  static const Duration slowAnimation = Duration(milliseconds: 600);

  static const double smallRadius = 12;
  static const double mediumRadius = 18;
  static const double largeRadius = 24;
  static const double xlRadius = 32;

  static const double smallSpacing = 8;
  static const double mediumSpacing = 16;
  static const double largeSpacing = 24;
  static const double xlSpacing = 32;

  static ThemeData buildTheme() {
    final scheme = const ColorScheme.dark(
      primary: primaryColor,
      onPrimary: backgroundColor,
      secondary: secondaryColor,
      onSecondary: backgroundColor,
      error: errorColor,
      onError: backgroundColor,
      surface: surfaceColor,
      onSurface: primaryText,
      outline: borderColor,
      outlineVariant: dividerColor,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: backgroundColor,
      canvasColor: backgroundColor,
      splashFactory: InkSparkle.splashFactory,
      dividerColor: dividerColor,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: primaryText,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(largeRadius),
          side: const BorderSide(color: borderColor),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(largeRadius),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceColor,
        modalBackgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        hintStyle: const TextStyle(color: mutedText),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(mediumRadius),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(mediumRadius),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(mediumRadius),
          borderSide: const BorderSide(color: primaryColor, width: 1.4),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: elevatedSurface,
        contentTextStyle: const TextStyle(color: primaryText),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(mediumRadius),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: Color(0x245EE8B0),
        surfaceTintColor: Colors.transparent,
        height: 68,
      ),
      textTheme: TextTheme(
        bodyMedium: bodyStyle(),
        bodyLarge: bodyStyle(fontSize: 17),
        bodySmall: captionStyle(),
        headlineMedium: headingStyle(),
        headlineSmall: headingStyle(fontSize: 20),
        titleLarge: headingStyle(fontSize: 22),
        titleMedium: bodyStyle(
          fontWeight: FontWeight.w700,
          color: primaryText,
        ),
      ),
    );
  }

  static BoxDecoration cardDecoration({
    Color? color,
    double? radius,
    bool withBorder = true,
    bool withShadow = false,
    bool withGradient = false,
  }) {
    return BoxDecoration(
      color: withGradient ? null : (color ?? cardColor),
      gradient: withGradient ? cardGradient : null,
      borderRadius: BorderRadius.circular(radius ?? largeRadius),
      border: withBorder ? Border.all(color: borderColor) : null,
      boxShadow: withShadow
          ? const [
              BoxShadow(
                color: shadowColor,
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ]
          : null,
    );
  }

  static BoxDecoration glassDecoration({
    double opacity = 0.08,
    double? radius,
    bool withBorder = true,
  }) {
    return BoxDecoration(
      color: foregroundColor.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(radius ?? largeRadius),
      border: withBorder ? Border.all(color: borderColor) : null,
    );
  }

  static TextStyle headingStyle({
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
    BuildContext? context,
  }) {
    try {
      return FontHelper.getHeadingStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color ?? primaryText,
        context: context,
      ).copyWith(height: 1.2, letterSpacing: -0.2);
    } catch (_) {
      return TextStyle(
        fontSize: fontSize,
        height: 1.2,
        letterSpacing: -0.2,
        fontWeight: fontWeight,
        color: color ?? primaryText,
      );
    }
  }

  static TextStyle bodyStyle({
    double fontSize = 15,
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
      ).copyWith(height: 1.45);
    } catch (_) {
      return TextStyle(
        fontSize: fontSize,
        height: 1.45,
        fontWeight: fontWeight,
        color: color ?? secondaryText,
      );
    }
  }

  static TextStyle captionStyle({
    double fontSize = 13,
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
      ).copyWith(height: 1.35);
    } catch (_) {
      return TextStyle(
        fontSize: fontSize,
        height: 1.35,
        fontWeight: fontWeight,
        color: color ?? mutedText,
      );
    }
  }

  static Widget buildServerIcon({
    required String serverType,
    double size = 24,
    Color? color,
    bool isSelected = false,
  }) {
    final type = serverType.toLowerCase();
    final icon = type == 'automatic' || type == 'auto'
        ? Icons.auto_awesome_rounded
        : type.contains('cloud')
            ? Icons.cloud_rounded
            : Icons.dns_rounded;

    return Container(
      width: size + 22,
      height: size + 22,
      decoration: BoxDecoration(
        color: isSelected
            ? primaryColor.withValues(alpha: 0.14)
            : elevatedSurface,
        borderRadius: BorderRadius.circular(smallRadius),
      ),
      child: Icon(
        icon,
        size: size,
        color: color ?? (isSelected ? primaryColor : secondaryText),
      ),
    );
  }

  static Widget buildConnectionIndicator({
    required String status,
    double size = 10,
  }) {
    final normalized = status.toLowerCase();
    final color = normalized == 'connected'
        ? successColor
        : normalized == 'connecting'
            ? warningColor
            : mutedText;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
