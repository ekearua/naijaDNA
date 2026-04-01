import 'package:flutter/material.dart';

class SearchHeaderBar extends StatelessWidget {
  const SearchHeaderBar({
    required this.onBackTap,
    required this.onCancelTap,
    super.key,
  });

  final VoidCallback onBackTap;
  final VoidCallback onCancelTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          IconButton(
            onPressed: onBackTap,
            icon: const Icon(Icons.arrow_back_rounded),
            splashRadius: 18,
            visualDensity: VisualDensity.compact,
            tooltip: 'Back',
          ),
          Text(
            'Search',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          TextButton(
            onPressed: onCancelTap,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
