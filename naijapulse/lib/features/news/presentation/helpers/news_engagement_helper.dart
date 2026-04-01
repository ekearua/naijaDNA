import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:naijapulse/core/di/injection_container.dart';
import 'package:naijapulse/core/error/failures.dart';
import 'package:naijapulse/core/routing/app_router.dart';
import 'package:naijapulse/features/news/data/datasource/local/saved_story_local_datasource.dart';
import 'package:naijapulse/features/news/data/datasource/remote/news_remote_datasource.dart';
import 'package:naijapulse/features/news/domain/entities/news_article.dart';

class NewsEngagementHelper {
  const NewsEngagementHelper._();

  static Future<void> likeArticle(
    BuildContext context,
    NewsArticle article,
  ) async {
    final remote = InjectionContainer.sl<NewsRemoteDataSource>();
    try {
      final applied = await remote.applyFeedFeedback(
        action: 'more_like_this',
        articleId: article.id,
      );
      if (!context.mounted) {
        return;
      }
      _showSnackBar(
        context,
        applied
            ? 'Preference updated. We will show you more stories like this.'
            : 'Sign in to personalize your feed.',
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      _showSnackBar(context, mapFailure(error).message);
    }
  }

  static Future<void> discussArticle(
    BuildContext context,
    NewsArticle article, {
    bool openDetail = false,
  }) async {
    final remote = InjectionContainer.sl<NewsRemoteDataSource>();
    try {
      await remote.recordFeedEvent(articleId: article.id, eventType: 'discuss');
    } catch (_) {
      // Discussion telemetry should never block UI flow.
    }

    if (openDetail) {
      if (!context.mounted) {
        return;
      }
      context.push(AppRouter.newsDetailPath(article.id), extra: article);
      return;
    }

    if (!context.mounted) {
      return;
    }
    _showSnackBar(context, 'Use the comment box below to join the discussion.');
  }

  static Future<void> saveArticle(
    BuildContext context,
    NewsArticle article,
  ) async {
    final savedStore = InjectionContainer.sl<SavedStoryLocalDataSource>();
    final remote = InjectionContainer.sl<NewsRemoteDataSource>();

    try {
      final nowSaved = await savedStore.toggleSaved(article.id);
      if (nowSaved) {
        await remote.recordFeedEvent(articleId: article.id, eventType: 'save');
      }
      if (!context.mounted) {
        return;
      }
      _showSnackBar(
        context,
        nowSaved ? 'Saved for later.' : 'Removed from saved stories.',
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      _showSnackBar(context, mapFailure(error).message);
    }
  }

  static Future<void> shareArticle(
    BuildContext context,
    NewsArticle article,
  ) async {
    final remote = InjectionContainer.sl<NewsRemoteDataSource>();
    final shareText = (article.articleUrl ?? article.title).trim();
    if (shareText.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: shareText));
    }

    try {
      await remote.recordFeedEvent(articleId: article.id, eventType: 'share');
    } catch (_) {
      // Sharing UX should not fail on telemetry.
    }

    if (!context.mounted) {
      return;
    }
    _showSnackBar(
      context,
      shareText.isEmpty
          ? 'Nothing to share for this article.'
          : 'Article link copied to clipboard.',
    );
  }

  static void _showSnackBar(BuildContext context, String message) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
