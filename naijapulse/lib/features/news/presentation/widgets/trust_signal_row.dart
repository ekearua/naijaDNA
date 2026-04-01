import 'package:flutter/material.dart';

class TrustSignalChipData {
  const TrustSignalChipData({required this.label, this.color, this.onTap});

  final String label;
  final Color? color;
  final VoidCallback? onTap;
}

class TrustSignalRow extends StatelessWidget {
  const TrustSignalRow({required this.items, super.key});

  final List<TrustSignalChipData> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tag = items[index];
          return _TrustSignalChip(
            label: tag.label,
            color: tag.color ?? Theme.of(context).colorScheme.primary,
            onTap: tag.onTap,
          );
        },
      ),
    );
  }
}

class _TrustSignalChip extends StatelessWidget {
  const _TrustSignalChip({
    required this.label,
    required this.color,
    this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
