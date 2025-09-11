import 'package:shinenet_vpn/common/theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ServerSelectionModal extends StatefulWidget {
  final String selectedServer;
  final Function(String) onServerSelected;

  ServerSelectionModal(
      {required this.selectedServer, required this.onServerSelected});

  @override
  _ServerSelectionModalState createState() => _ServerSelectionModalState();
}

class _ServerSelectionModalState extends State<ServerSelectionModal>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late List<AnimationController> _itemControllers;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: ThemeColor.mediumAnimation,
      vsync: this,
    );
    
    _itemControllers = List.generate(
      3,
      (index) => AnimationController(
        duration: Duration(milliseconds: 300 + (index * 100)),
        vsync: this,
      ),
    );
    
    _animationController.forward();
    
    // Stagger the item animations
    for (int i = 0; i < _itemControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 100), () {
        if (mounted) {
          _itemControllers[i].forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    for (var controller in _itemControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ThemeColor.backgroundColor,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ThemeColor.xlRadius),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Modern handle bar
          Container(
            margin: EdgeInsets.only(top: ThemeColor.smallSpacing),
            width: 50,
            height: 4,
            decoration: BoxDecoration(
              color: ThemeColor.mutedText,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(ThemeColor.largeSpacing),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(ThemeColor.smallSpacing),
                      decoration: BoxDecoration(
                        gradient: ThemeColor.primaryGradient,
                        borderRadius: BorderRadius.circular(ThemeColor.smallRadius),
                        boxShadow: [
                          BoxShadow(
                            color: ThemeColor.primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.dns_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: ThemeColor.mediumSpacing),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Server',
                            style: ThemeColor.headingStyle(
                              fontSize: 22,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Choose your preferred server location',
                            style: ThemeColor.captionStyle(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: ThemeColor.largeSpacing),
                
                // Server options
                _buildModernServerOption(
                  title: 'Automatic',
                  subtitle: 'Best server selected automatically',
                  serverType: 'Automatic',
                  isSelected: widget.selectedServer == 'Automatic',
                  onTap: () => _selectServer(context, 'Automatic'),
                ),
                SizedBox(height: ThemeColor.smallSpacing),
                _buildModernServerOption(
                  title: 'Server 1',
                  subtitle: 'Manual server selection',
                  serverType: 'Server 1',
                  isSelected: widget.selectedServer == 'Server 1',
                  onTap: () => _selectServer(context, 'Server 1'),
                ),
                SizedBox(height: ThemeColor.smallSpacing),
                _buildModernServerOption(
                  title: 'Server 2',
                  subtitle: 'Manual server selection',
                  serverType: 'Server 2',
                  isSelected: widget.selectedServer == 'Server 2',
                  onTap: () => _selectServer(context, 'Server 2'),
                ),
                SizedBox(height: ThemeColor.mediumSpacing),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Modern server option without Lottie
  Widget _buildModernServerOption({
    required String title,
    required String subtitle,
    required String serverType,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: ThemeColor.mediumAnimation,
      decoration: ThemeColor.cardDecoration(
        color: isSelected ? ThemeColor.primaryColor.withOpacity(0.1) : null,
        withBorder: isSelected,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: EdgeInsets.all(ThemeColor.mediumSpacing),
            child: Row(
              children: [
                // Modern server icon
                ThemeColor.buildServerIcon(
                  serverType: serverType,
                  size: 24,
                  isSelected: isSelected,
                ),
                SizedBox(width: ThemeColor.mediumSpacing),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: ThemeColor.bodyStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isSelected 
                                    ? ThemeColor.primaryColor
                                    : ThemeColor.primaryText,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: ThemeColor.smallSpacing,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: ThemeColor.primaryColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Active',
                                style: ThemeColor.captionStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: ThemeColor.captionStyle(
                          color: isSelected
                              ? ThemeColor.primaryColor.withOpacity(0.8)
                              : ThemeColor.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: ThemeColor.smallSpacing),
                AnimatedScale(
                  scale: isSelected ? 1.0 : 0.0,
                  duration: ThemeColor.mediumAnimation,
                  child: Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: ThemeColor.primaryColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: ThemeColor.primaryColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  void _selectServer(BuildContext context, String server) {
    HapticFeedback.lightImpact();
    widget.onServerSelected(server);
  }
}
