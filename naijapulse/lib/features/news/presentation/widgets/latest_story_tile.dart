import 'package:flutter/material.dart';
import 'package:naijapulse/core/widgets/meta_badge.dart';
import 'package:naijapulse/core/widgets/news_thumbnail.dart';
import 'package:naijapulse/features/news/domain/entities/news_article.dart';
import 'package:naijapulse/features/news/presentation/widgets/news_time.dart';

class LatestStoryTile extends StatelessWidget {
  const LatestStoryTile({required this.story, this.onTap, super.key});

  final NewsArticle story;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage =
        story.imageUrl != null && story.imageUrl!.trim().isNotEmpty;
    final commentCount = story.commentCount;
    final hasComments = commentCount != null && commentCount > 0;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (story.isFactChecked)
                        MetaBadge(
                          label: 'FactChecked',
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      MetaBadge(label: story.category),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    story.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.radio_button_checked_rounded,
                        size: 11,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${story.source} - ${relativeTimeLabel(story.publishedAt)}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.82),
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasComments) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.chat_bubble_rounded,
                          size: 12,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$commentCount',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.78),
                              ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (hasImage) ...[
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 104,
                  height: 78,
                  child: NewsThumbnail(
                    imageUrl: story.imageUrl,
                    fallbackLabel: story.category,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
