import 'package:flutter/material.dart';
import 'package:naijapulse/core/widgets/empty_state_card.dart';
import 'package:naijapulse/features/news/domain/entities/news_article.dart';
import 'package:naijapulse/features/news/presentation/widgets/top_story_hero_card.dart';

class TopStoriesCarousel extends StatelessWidget {
  const TopStoriesCarousel({
    required this.stories,
    this.onStoryTap,
    this.onSaveTap,
    this.onDiscussTap,
    this.onLikeTap,
    this.onShareTap,
    super.key,
  });

  final List<NewsArticle> stories;
  final ValueChanged<NewsArticle>? onStoryTap;
  final ValueChanged<NewsArticle>? onSaveTap;
  final ValueChanged<NewsArticle>? onDiscussTap;
  final ValueChanged<NewsArticle>? onLikeTap;
  final ValueChanged<NewsArticle>? onShareTap;

  @override
  Widget build(BuildContext context) {
    if (stories.isEmpty) {
      return const EmptyStateCard(
        message: 'No top stories available right now.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        return SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: stories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) => SizedBox(
              width: cardWidth,
              child: TopStoryHeroCard(
                story: stories[index],
                onTap: onStoryTap == null
                    ? null
                    : () => onStoryTap!(stories[index]),
                onSaveTap: onSaveTap == null
                    ? null
                    : () => onSaveTap!(stories[index]),
                onDiscussTap: onDiscussTap == null
                    ? null
                    : () => onDiscussTap!(stories[index]),
                onLikeTap: onLikeTap == null
                    ? null
                    : () => onLikeTap!(stories[index]),
                onShareTap: onShareTap == null
                    ? null
                    : () => onShareTap!(stories[index]),
              ),
            ),
          ),
        );
      },
    );
  }
}
