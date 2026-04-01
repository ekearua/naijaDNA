import 'package:flutter/material.dart';

class SuggestedQueryChip extends StatelessWidget {
  const SuggestedQueryChip({
    required this.label,
    required this.onTap,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      avatar: icon == null ? null : Icon(icon, size: 18),
      side: BorderSide(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
      ),
      backgroundColor: Theme.of(
        context,
      ).colorScheme.primary.withValues(alpha: 0.08),
      labelStyle: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      label: Text(label),
    );
  }
}
