import 'package:flutter/material.dart';

class ArticleActionChipRow extends StatelessWidget {
  const ArticleActionChipRow({
    this.onLikeTap,
    this.onDiscussTap,
    this.onSaveTap,
    this.onShareTap,
    super.key,
  });

  final VoidCallback? onLikeTap;
  final VoidCallback? onDiscussTap;
  final VoidCallback? onSaveTap;
  final VoidCallback? onShareTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _actionChip(
          context,
          Icons.thumb_up_alt_outlined,
          'Like',
          onTap: onLikeTap,
        ),
        _actionChip(
          context,
          Icons.chat_bubble_outline_rounded,
          'Discuss',
          onTap: onDiscussTap,
        ),
        _actionChip(
          context,
          Icons.bookmark_border_rounded,
          'Save',
          onTap: onSaveTap,
        ),
        _actionChip(context, Icons.share_outlined, 'Share', onTap: onShareTap),
      ],
    );
  }

  Widget _actionChip(
    BuildContext context,
    IconData icon,
    String label, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
          color: Theme.of(context).colorScheme.surfaceContainerLow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
