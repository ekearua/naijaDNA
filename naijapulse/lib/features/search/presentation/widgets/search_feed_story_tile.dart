import 'package:flutter/material.dart';
import 'package:naijapulse/core/widgets/meta_badge.dart';
import 'package:naijapulse/core/widgets/news_thumbnail.dart';
import 'package:naijapulse/features/news/domain/entities/news_article.dart';
import 'package:naijapulse/features/news/presentation/widgets/news_time.dart';

class SearchFeedStoryTile extends StatelessWidget {
  const SearchFeedStoryTile({
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

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
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
                  const SizedBox(height: 7),
                  Text(
                    story.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.radio_button_checked_rounded,
                        size: 11,
                        color: Theme.of(context).colorScheme.primary,
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
                ],
              ),
            ),
            if (hasImage) ...[
              const SizedBox(width: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 84,
                  height: 60,
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
