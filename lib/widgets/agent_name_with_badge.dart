import 'package:flutter/material.dart';

class AgentNameWithBadge extends StatelessWidget {
  final String name;
  final bool isVerified;
  final TextStyle? style;
  final double iconSize;
  final Color? iconColor;
  final MainAxisAlignment alignment;

  const AgentNameWithBadge({
    super.key,
    required this.name,
    required this.isVerified,
    this.style,
    this.iconSize = 18,
    this.iconColor,
    this.alignment = MainAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(name, style: style),
        if (isVerified) ...[
          const SizedBox(width: 6),
          Tooltip(
            message: 'Verified Agent',
            child: Icon(
              Icons.verified,
              color: iconColor ?? Colors.lightBlueAccent,
              size: iconSize,
            ),
          ),
        ],
      ],
    );
  }
}
