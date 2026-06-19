import 'package:flutter/material.dart';
import 'package:shinenet_vpn/common/liquid_glass_container.dart';
import 'package:shinenet_vpn/common/theme.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';

class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  // استفاده از jsDelivr برای دسترسی بهتر به فایل‌های GitHub
  static const String _bannerImageUrl =
      'https://cdn.jsdelivr.net/gh/shayanheidari01/shayanheidari01@main/SNV-ADS/banner.gif';
  static const String _clickUrlSource =
      'https://cdn.jsdelivr.net/gh/shayanheidari01/shayanheidari01@main/SNV-ADS/click_url.txt';

  String? _clickUrl;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadClickUrl();
  }

  Future<void> _loadClickUrl() async {
    try {
      final dio = Dio();
      final response = await dio.get(
        _clickUrlSource,
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: true,
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final url = response.data.toString().trim();
        if (url.isNotEmpty) {
          setState(() {
            _clickUrl = url;
            _isLoading = false;
            _hasError = false;
          });
          return;
        }
      }

      throw Exception('Invalid response');
    } catch (e) {
      print('Error loading click URL: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _handleBannerClick() async {
    if (_clickUrl == null || _clickUrl!.isEmpty) {
      return;
    }

    try {
      final uri = Uri.parse(_clickUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        print('Could not launch URL: $_clickUrl');
      }
    } catch (e) {
      print('Error launching URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // اگر خطا داریم یا در حال بارگذاری است، چیزی نشان نمی‌دهیم
    if (_hasError || _isLoading) {
      return const SizedBox.shrink();
    }

    return LiquidGlassContainer(
      borderRadius: ThemeColor.xlRadius,
      padding: EdgeInsets.zero,
      blurSigma: 25,
      enableBlur: false,
      gradientColors: [
        Colors.white.withValues(alpha: 0.12),
        Colors.white.withValues(alpha: 0.04),
      ],
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThemeColor.xlRadius),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(ThemeColor.xlRadius),
          onTap: _handleBannerClick,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(ThemeColor.xlRadius),
            child: AspectRatio(
              aspectRatio: 16 / 9, // نسبت ابعاد 16:9
              child: Image.network(
                _bannerImageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) {
                    return child;
                  }
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: ThemeColor.primaryColor,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  print('Error loading banner image: $error');
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
