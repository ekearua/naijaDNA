import 'package:flutter/material.dart';

class MetaBadge extends StatelessWidget {
  const MetaBadge({required this.label, this.color, super.key});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final resolvedTextColor = color ?? onSurface.withValues(alpha: 0.88);
    final resolvedBackground = color != null
        ? color!.withValues(alpha: 0.16)
        : Theme.of(context).colorScheme.surfaceContainerHighest;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: resolvedBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: resolvedTextColor,
          ),
        ),
      ),
    );
  }
}
