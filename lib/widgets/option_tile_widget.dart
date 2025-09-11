import 'package:shinenet_vpn/common/theme.dart';
import 'package:flutter/material.dart';

class OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isShowArrowBtn;

  OptionTile(
      {required this.icon,
      required this.title,
      required this.subtitle,
      this.isShowArrowBtn = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 75,
      decoration: BoxDecoration(
        border: Border.all(color: ThemeColor.foregroundColor),
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: ThemeColor.foregroundColor,
          size: 32,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: ThemeColor.foregroundColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey,
            ),
          ),
        ),
        trailing: isShowArrowBtn
            ? Icon(Icons.arrow_forward,
                color: ThemeColor.foregroundColor, size: 30)
            : null,
      ),
    );
  }
}
