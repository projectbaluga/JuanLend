import 'package:flutter/material.dart';
import 'responsive_container.dart';

class ScreenHeader extends StatelessWidget {
  final String title;
  final Widget? titleSuffix;
  final Widget? action;

  const ScreenHeader({
    super.key,
    required this.title,
    this.titleSuffix,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveContainer.isDesktop(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (!isDesktop)
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (titleSuffix != null) ...[
                const SizedBox(width: 8),
                titleSuffix!,
              ],
            ],
          )
        else if (titleSuffix != null)
          Row(
            children: [
              titleSuffix!,
            ],
          )
        else
          const SizedBox.shrink(),
        if (action != null) action!,
      ],
    );
  }
}
