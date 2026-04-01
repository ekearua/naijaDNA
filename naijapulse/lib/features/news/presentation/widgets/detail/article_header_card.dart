import 'package:flutter/material.dart';
import 'package:naijapulse/features/news/domain/entities/news_article.dart';
import 'package:naijapulse/features/news/presentation/widgets/news_time.dart';

class ArticleHeaderCard extends StatelessWidget {
  const ArticleHeaderCard({required this.story, super.key});

  final NewsArticle story;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Container(
          //   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          //   decoration: BoxDecoration(
          //     color: const Color(0xFFC63D35),
          //     borderRadius: BorderRadius.circular(10),
          //   ),
          //   child: Text(
          //     story.category.toUpperCase(),
          //     style: Theme.of(context).textTheme.titleMedium?.copyWith(
          //       color: Colors.white,
          //       fontWeight: FontWeight.w800,
          //     ),
          //   ),
          // ),
          // const SizedBox(height: 12),
          Text(
            story.title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.radio_button_checked_rounded,
                size: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${story.source} - ${relativeTimeLabel(story.publishedAt)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
