import 'package:flutter/material.dart';
import 'package:naijapulse/core/widgets/app_interactions.dart';
import 'package:naijapulse/core/widgets/news_thumbnail.dart';
import 'package:naijapulse/features/news/domain/entities/news_article.dart';
import 'package:naijapulse/features/news/presentation/widgets/saved_article_controls.dart';
import 'package:naijapulse/features/news/presentation/widgets/news_time.dart';

class SearchResultStoryTile extends StatelessWidget {
  const SearchResultStoryTile({
    required this.story,
    required this.onTap,
    super.key,
  });

  final NewsArticle story;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage =
        story.imageUrl != null && story.imageUrl!.trim().isNotEmpty;
    final commentCount = story.commentCount;
    final hasComments = commentCount != null && commentCount > 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Theme.of(context).dividerColor),
          color: Theme.of(context).colorScheme.surface,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 90,
                  height: 70,
                  child: NewsThumbnail(
                    imageUrl: story.imageUrl,
                    fallbackLabel: story.category,
                  ),
                ),
              ),
            if (hasImage) const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    story.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const AppIcon(
                        Icons.radio_button_checked_rounded,
                        size: AppIconSize.xSmall,
                        tone: AppIconTone.accent,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          '${story.source} - ${relativeTimeLabel(story.publishedAt)}',
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      SavedArticleInlineAction(
                        article: story,
                        compact: true,
                        unsavedTone: AppIconTone.secondary,
                        savedTone: AppIconTone.accent,
                      ),
                      if (hasComments) ...[
                        const SizedBox(width: 10),
                        AppIcon(
                          Icons.chat_bubble_outline_rounded,
                          size: AppIconSize.xSmall,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$commentCount comments',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 2),
            AppIcon(
              Icons.more_horiz_rounded,
              size: AppIconSize.xSmall,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ],
        ),
      ),
    );
  }
}
