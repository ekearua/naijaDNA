import 'package:flutter/material.dart';
import 'package:naijapulse/core/di/injection_container.dart';
import 'package:naijapulse/core/widgets/app_interactions.dart';
import 'package:naijapulse/features/news/data/datasource/local/saved_story_local_datasource.dart';
import 'package:naijapulse/features/news/domain/entities/news_article.dart';
import 'package:naijapulse/features/news/presentation/helpers/news_engagement_helper.dart';

class SavedArticleActionChip extends StatelessWidget {
  const SavedArticleActionChip({
    required this.article,
    this.inverse = false,
    this.compact = false,
    this.selectedColor,
    this.selectedForegroundColor,
    this.enableHaptics = false,
    super.key,
  });

  final NewsArticle article;
  final bool inverse;
  final bool compact;
  final Color? selectedColor;
  final Color? selectedForegroundColor;
  final bool enableHaptics;

  @override
  Widget build(BuildContext context) {
    return _SavedArticleStateBuilder(
      articleId: article.id,
      builder: (context, isSaved) {
        return AppActionChip(
          icon: isSaved
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          label: isSaved ? 'Saved' : 'Save',
          selected: isSaved,
          selectedColor: selectedColor,
          selectedForegroundColor: selectedForegroundColor,
          inverse: inverse,
          compact: compact,
          tooltip: isSaved
              ? 'Remove from saved stories'
              : 'Save story for later',
          enableHaptics: enableHaptics,
          onTap: () => NewsEngagementHelper.saveArticle(context, article),
        );
      },
    );
  }
}

class SavedArticleInlineAction extends StatelessWidget {
  const SavedArticleInlineAction({
    required this.article,
    this.compact = false,
    this.enableHaptics = false,
    this.unsavedTone = AppIconTone.secondary,
    this.savedTone = AppIconTone.accent,
    super.key,
  });

  final NewsArticle article;
  final bool compact;
  final bool enableHaptics;
  final AppIconTone unsavedTone;
  final AppIconTone savedTone;

  @override
  Widget build(BuildContext context) {
    return _SavedArticleStateBuilder(
      articleId: article.id,
      builder: (context, isSaved) {
        return AppInlineAction(
          icon: isSaved
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          label: isSaved ? 'Saved' : 'Save',
          tone: isSaved ? savedTone : unsavedTone,
          compact: compact,
          enableHaptics: enableHaptics,
          tooltip: isSaved
              ? 'Remove from saved stories'
              : 'Save story for later',
          onTap: () => NewsEngagementHelper.saveArticle(context, article),
        );
      },
    );
  }
}

class SavedArticleIconButton extends StatelessWidget {
  const SavedArticleIconButton({
    required this.article,
    this.compact = true,
    this.style = AppIconButtonStyle.neutral,
    this.iconSize = AppIconSize.small,
    this.enableHaptics = false,
    super.key,
  });

  final NewsArticle article;
  final bool compact;
  final AppIconButtonStyle style;
  final AppIconSize iconSize;
  final bool enableHaptics;

  @override
  Widget build(BuildContext context) {
    return _SavedArticleStateBuilder(
      articleId: article.id,
      builder: (context, isSaved) {
        return AppIconButton(
          icon: Icons.bookmark_border_rounded,
          selectedIcon: Icons.bookmark_rounded,
          selected: isSaved,
          compact: compact,
          style: style,
          iconSize: iconSize,
          enableHaptics: enableHaptics,
          tooltip: isSaved
              ? 'Remove from saved stories'
              : 'Save story for later',
          semanticLabel: isSaved
              ? 'Remove from saved stories'
              : 'Save story for later',
          onPressed: () => NewsEngagementHelper.saveArticle(context, article),
        );
      },
    );
  }
}

class _SavedArticleStateBuilder extends StatelessWidget {
  const _SavedArticleStateBuilder({
    required this.articleId,
    required this.builder,
  });

  final String articleId;
  final Widget Function(BuildContext context, bool isSaved) builder;

  @override
  Widget build(BuildContext context) {
    final savedStore = InjectionContainer.sl<SavedStoryLocalDataSource>();
    return ValueListenableBuilder<int>(
      valueListenable: savedStore.savedStoriesListenable,
      builder: (context, _, __) {
        return FutureBuilder<bool>(
          future: savedStore.isSaved(articleId),
          initialData: false,
          builder: (context, snapshot) {
            return builder(context, snapshot.data ?? false);
          },
        );
      },
    );
  }
}
