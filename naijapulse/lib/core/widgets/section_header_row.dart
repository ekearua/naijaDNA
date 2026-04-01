import 'package:flutter/material.dart';

class SectionHeaderRow extends StatelessWidget {
  const SectionHeaderRow({
    required this.title,
    this.actionLabel,
    this.onActionTap,
    this.titleStyle,
    super.key,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onActionTap;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style:
                titleStyle ??
                Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        if (actionLabel != null && onActionTap != null)
          TextButton.icon(
            onPressed: onActionTap,
            iconAlignment: IconAlignment.end,
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.secondary,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
            label: Text(
              actionLabel!,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}
