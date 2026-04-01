import 'package:flutter/material.dart';

class PreferenceStoryItem extends StatelessWidget {
  const PreferenceStoryItem({
    required this.title,
    required this.source,
    required this.timeLabel,
    required this.onRemove,
    super.key,
  });

  final String title;
  final String source;
  final String timeLabel;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.12),
                child: Icon(
                  Icons.article_rounded,
                  size: 15,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  source,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Text(timeLabel, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onRemove,
              icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
              label: const Text('Remove from interests'),
            ),
          ),
        ],
      ),
    );
  }
}
