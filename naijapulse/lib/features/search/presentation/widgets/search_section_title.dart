import 'package:flutter/material.dart';

class SearchSectionTitle extends StatelessWidget {
  const SearchSectionTitle({
    required this.title,
    this.actionLabel,
    this.onActionTap,
    super.key,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (actionLabel != null && onActionTap != null)
          TextButton(
            onPressed: onActionTap,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: Text(actionLabel!),
          )
        else if (actionLabel != null)
          Text(actionLabel!, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
