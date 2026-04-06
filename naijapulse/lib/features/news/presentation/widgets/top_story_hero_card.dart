import 'package:flutter/material.dart';
import 'package:naijapulse/core/widgets/news_thumbnail.dart';
import 'package:naijapulse/features/news/domain/entities/news_article.dart';
import 'package:naijapulse/features/news/presentation/widgets/saved_article_controls.dart';
import 'package:naijapulse/features/news/presentation/widgets/news_time.dart';
import 'package:naijapulse/features/news/presentation/widgets/story_action_pill.dart';

class TopStoryHeroCard extends StatelessWidget {
  const TopStoryHeroCard({
    required this.story,
    this.onTap,
    this.onDiscussTap,
    this.onLikeTap,
    this.onShareTap,
    super.key,
  });

  final NewsArticle story;
  final VoidCallback? onTap;
  final VoidCallback? onDiscussTap;
  final VoidCallback? onLikeTap;
  final VoidCallback? onShareTap;

  @override
  Widget build(BuildContext context) {
    final hasImage =
        story.imageUrl != null && story.imageUrl!.trim().isNotEmpty;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
        child: Stack(
          children: [
            Positioned.fill(
              child: hasImage
                  ? NewsThumbnail(
                      imageUrl: story.imageUrl,
                      fallbackLabel: story.category,
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.grey.shade700, Colors.grey.shade900],
                        ),
                      ),
                    ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.16),
                      Colors.black.withValues(alpha: 0.78),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    story.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${story.source} - ${relativeTimeLabel(story.publishedAt)}',
                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        SavedArticleActionChip(
                          article: story,
                          inverse: true,
                          compact: true,
                        ),
                        SizedBox(width: 8),
                        StoryActionPill(
                          icon: Icons.chat_bubble_outline_rounded,
                          label: 'Discuss',
                          iconColor: Color(0xFF3A4652),
                          onTap: onDiscussTap,
                        ),
                        SizedBox(width: 8),
                        StoryActionPill(
                          icon: Icons.thumb_up_alt_outlined,
                          label: 'Like',
                          iconColor: Color(0xFF0D8A5E),
                          onTap: onLikeTap,
                        ),
                        SizedBox(width: 8),
                        StoryActionPill(
                          icon: Icons.share_outlined,
                          label: 'Share',
                          iconColor: Color(0xFF3A4652),
                          onTap: onShareTap,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
