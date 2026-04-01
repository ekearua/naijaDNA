import 'package:flutter/material.dart';
import 'package:naijapulse/core/theme/theme.dart';
import 'package:naijapulse/core/widgets/news_thumbnail.dart';
import 'package:naijapulse/features/news/domain/entities/news_article.dart';
import 'package:naijapulse/features/news/presentation/widgets/news_time.dart';

class AllNewsStoryTile extends StatelessWidget {
  const AllNewsStoryTile({required this.story, required this.onTap, super.key});

  final NewsArticle story;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final badgeColor = _categoryBadgeColor(story.category);
    final hasImage =
        story.imageUrl != null && story.imageUrl!.trim().isNotEmpty;
    final hasComments = (story.commentCount ?? 0) > 0;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    color: badgeColor,
                  ),
                  child: Text(
                    story.category.toUpperCase(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  relativeTimeLabel(story.publishedAt),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasImage)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 122,
                      height: 80,
                      child: NewsThumbnail(
                        imageUrl: story.imageUrl,
                        fallbackLabel: story.category,
                      ),
                    ),
                  ),
                if (hasImage) const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        story.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.radio_button_checked_rounded,
                            size: 14,
                            color: AppTheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${story.source} - ${relativeTimeLabel(story.publishedAt)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context).hintColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      if (hasComments) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 16,
                              color: Theme.of(context).hintColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${story.commentCount} comments',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context).hintColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _categoryBadgeColor(String category) {
    switch (category.toLowerCase()) {
      case 'breaking':
        return AppTheme.breaking;
      case 'politics':
        return const Color(0xFFC63D35);
      case 'business':
        return AppTheme.business;
      case 'tech':
      case 'technology':
        return AppTheme.tech;
      case 'sports':
        return AppTheme.sports;
      default:
        return AppTheme.primary;
    }
  }
}
