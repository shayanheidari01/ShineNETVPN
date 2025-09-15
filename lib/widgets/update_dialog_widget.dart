import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/update_checker_service.dart';
import '../common/theme.dart';
import 'dart:developer' as developer;

class UpdateDialogWidget extends StatelessWidget {
  final UpdateInfo updateInfo;
  
  const UpdateDialogWidget({
    Key? key,
    required this.updateInfo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent dismissing with back button
      child: AlertDialog(
        backgroundColor: ThemeColor.backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.system_update,
              color: ThemeColor.primaryColor,
              size: 28,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'update_available'.tr(),
                style: TextStyle(
                  color: ThemeColor.primaryText,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'update_message'.tr(),
              style: TextStyle(
                color: ThemeColor.secondaryText,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ThemeColor.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: ThemeColor.primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'current_version'.tr(),
                        style: TextStyle(
                          color: ThemeColor.secondaryText,
                          fontSize: 14,
                        ),
                      ),
                      Spacer(),
                      Text(
                        updateInfo.currentVersion,
                        style: TextStyle(
                          color: ThemeColor.primaryText,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'latest_version'.tr(),
                        style: TextStyle(
                          color: ThemeColor.secondaryText,
                          fontSize: 14,
                        ),
                      ),
                      Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: ThemeColor.primaryColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          updateInfo.latestVersion,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text(
              'update_required_message'.tr(),
              style: TextStyle(
                color: ThemeColor.errorColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _downloadUpdate(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeColor.primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'download_update'.tr(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _downloadUpdate(BuildContext context) async {
    try {
      developer.log('🔗 Opening download link: ${updateInfo.downloadLink}', name: 'update_dialog');
      
      final uri = Uri.parse(updateInfo.downloadLink);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showErrorSnackBar(context, 'cannot_open_link'.tr());
      }
    } catch (e) {
      developer.log('❌ Error opening download link: $e', name: 'update_dialog');
      _showErrorSnackBar(context, 'error_opening_link'.tr());
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ThemeColor.errorColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
