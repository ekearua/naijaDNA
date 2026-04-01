import 'package:flutter/material.dart';
import 'package:naijapulse/core/widgets/news_thumbnail.dart';
import 'package:naijapulse/features/news/domain/entities/news_article.dart';

class ArticleHeroSection extends StatelessWidget {
  const ArticleHeroSection({required this.story, super.key});

  final NewsArticle story;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Stack(
        fit: StackFit.expand,
        children: [
          NewsThumbnail(
            imageUrl: story.imageUrl,
            fallbackLabel: story.category,
          ),
          // Positioned(
          //   top: 18,
          //   left: 18,
          //   child: DecoratedBox(
          //     decoration: BoxDecoration(
          //       color: const Color(0xFFC63D35),
          //       borderRadius: BorderRadius.circular(12),
          //     ),
          //     child: Padding(
          //       padding: const EdgeInsets.symmetric(
          //         horizontal: 14,
          //         vertical: 8,
          //       ),
          //       child: Text(
          //         story.category.toUpperCase(),
          //         style: Theme.of(context).textTheme.titleMedium?.copyWith(
          //           color: Colors.white,
          //           fontWeight: FontWeight.w800,
          //         ),
          //       ),
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }
}
