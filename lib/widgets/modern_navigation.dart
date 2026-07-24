import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_v2ray_client/flutter_v2ray.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shinenet_vpn/common/theme.dart';

class ModernNavigation extends StatelessWidget {
  const ModernNavigation({
    super.key,
    required this.selectedIndex,
    required this.v2rayStatus,
    required this.onDestinationSelected,
    required this.isWideScreen,
  });

  final int selectedIndex;
  final ValueNotifier<V2RayStatus> v2rayStatus;
  final ValueChanged<int> onDestinationSelected;
  final bool isWideScreen;

  List<_NavigationItem> _items() => [
        _NavigationItem(Iconsax.setting_2, 'settings'.tr(), 0),
        _NavigationItem(Iconsax.shield_tick, 'home'.tr(), 1),
        _NavigationItem(Iconsax.info_circle, 'about'.tr(), 2),
      ];

  void _select(int index) {
    HapticFeedback.selectionClick();
    onDestinationSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    return isWideScreen ? _desktop(context) : _mobile(context);
  }

  Widget _mobile(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: ThemeColor.surfaceColor.withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: ThemeColor.borderColor),
          boxShadow: const [
            BoxShadow(
              color: ThemeColor.shadowColor,
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: _items().map((item) {
            final selected = selectedIndex == item.index;
            return Expanded(
              child: Semantics(
                selected: selected,
                button: true,
                label: item.label,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _select(item.index),
                    borderRadius: BorderRadius.circular(17),
                    child: AnimatedContainer(
                      duration: ThemeColor.fastAnimation,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: selected
                            ? ThemeColor.primaryColor.withValues(alpha: 0.13)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.icon,
                            size: 21,
                            color: selected
                                ? ThemeColor.primaryColor
                                : ThemeColor.mutedText,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ThemeColor.captionStyle(
                              fontSize: 11,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: selected
                                  ? ThemeColor.primaryColor
                                  : ThemeColor.mutedText,
                              context: context,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _desktop(BuildContext context) {
    return Container(
      width: 252,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: ThemeColor.cardDecoration(
        color: ThemeColor.surfaceColor,
        radius: ThemeColor.largeRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 28),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: ThemeColor.primaryGradient,
                    borderRadius:
                        BorderRadius.circular(ThemeColor.smallRadius),
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: ThemeColor.backgroundColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'app_title'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ThemeColor.headingStyle(
                      fontSize: 17,
                      context: context,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ..._items().map((item) => _desktopItem(context, item)),
          const Spacer(),
          _connectionStatus(context),
        ],
      ),
    );
  }

  Widget _desktopItem(BuildContext context, _NavigationItem item) {
    final selected = selectedIndex == item.index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _select(item.index),
          borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
          child: AnimatedContainer(
            duration: ThemeColor.fastAnimation,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: selected
                  ? ThemeColor.primaryColor.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 21,
                  color: selected
                      ? ThemeColor.primaryColor
                      : ThemeColor.secondaryText,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    item.label,
                    style: ThemeColor.bodyStyle(
                      color: selected
                          ? ThemeColor.primaryText
                          : ThemeColor.secondaryText,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      context: context,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.circle,
                    size: 7,
                    color: ThemeColor.primaryColor,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _connectionStatus(BuildContext context) {
    return ValueListenableBuilder<V2RayStatus>(
      valueListenable: v2rayStatus,
      builder: (context, status, _) {
        final normalized = status.state.toUpperCase();
        final connected = const {'CONNECTED', 'RUNNING', 'STARTED'}
            .contains(normalized);
        final connecting =
            const {'CONNECTING', 'STARTING'}.contains(normalized);
        final color = connected
            ? ThemeColor.successColor
            : connecting
                ? ThemeColor.warningColor
                : ThemeColor.mutedText;
        final label = connected
            ? 'connected'.tr()
            : connecting
                ? 'connecting'.tr()
                : 'disconnected'.tr();

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ThemeColor.cardColor,
            borderRadius: BorderRadius.circular(ThemeColor.mediumRadius),
            border: Border.all(color: ThemeColor.borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: ThemeColor.bodyStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                    context: context,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NavigationItem {
  const _NavigationItem(this.icon, this.label, this.index);

  final IconData icon;
  final String label;
  final int index;
}
