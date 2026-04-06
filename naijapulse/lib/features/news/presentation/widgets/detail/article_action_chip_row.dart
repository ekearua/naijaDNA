import 'package:flutter/material.dart';
import 'package:naijapulse/core/widgets/app_interactions.dart';
import 'package:naijapulse/features/news/domain/entities/news_article.dart';
import 'package:naijapulse/features/news/presentation/widgets/saved_article_controls.dart';

class ArticleActionChipRow extends StatelessWidget {
  const ArticleActionChipRow({
    required this.article,
    this.onLikeTap,
    this.onDiscussTap,
    this.onShareTap,
    super.key,
  });

  final NewsArticle article;
  final VoidCallback? onLikeTap;
  final VoidCallback? onDiscussTap;
  final VoidCallback? onShareTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        AppActionChip(
          icon: Icons.thumb_up_alt_outlined,
          label: 'Like',
          onTap: onLikeTap,
        ),
        AppActionChip(
          icon: Icons.chat_bubble_outline_rounded,
          label: 'Discuss',
          onTap: onDiscussTap,
        ),
        SavedArticleActionChip(article: article),
        AppActionChip(
          icon: Icons.share_outlined,
          label: 'Share',
          onTap: onShareTap,
        ),
      ],
    );
  }
}
