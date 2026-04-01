import 'package:flutter/material.dart';

class ArticleComment {
  const ArticleComment({
    required this.author,
    required this.timeLabel,
    required this.body,
    this.likeCount = 0,
  });

  final String author;
  final String timeLabel;
  final String body;
  final int likeCount;
}

class ArticleCommentsSection extends StatelessWidget {
  const ArticleCommentsSection({
    required this.commentCountLabel,
    required this.comments,
    super.key,
  });

  final String commentCountLabel;
  final List<ArticleComment> comments;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Text(
                  'Comments',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  commentCountLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Column(
              children: comments
                  .map((comment) => _ArticleCommentTile(comment: comment))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArticleCommentTile extends StatelessWidget {
  const _ArticleCommentTile({required this.comment});

  final ArticleComment comment;

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
                radius: 15,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.12),
                child: Icon(
                  Icons.person_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  comment.author,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                comment.timeLabel,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.more_horiz_rounded,
                size: 18,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            comment.body,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.thumb_up_alt_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                '${comment.likeCount}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 18,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
              const SizedBox(width: 6),
              Text('Reply', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ],
      ),
    );
  }
}
