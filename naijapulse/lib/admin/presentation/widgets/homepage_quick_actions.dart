import 'package:flutter/material.dart';
import 'package:naijapulse/admin/data/datasource/admin_remote_datasource.dart';
import 'package:naijapulse/admin/data/models/admin_models.dart';
import 'package:naijapulse/admin/presentation/widgets/homepage_placement_dialog.dart';
import 'package:naijapulse/core/error/failures.dart';
import 'package:naijapulse/features/news/domain/entities/news_article.dart';

Future<bool> addArticleToHomepageFlow(
  BuildContext context, {
  required AdminRemoteDataSource remote,
  required NewsArticle article,
}) async {
  if (article.status != 'published') {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Only published stories can be placed on the homepage.'),
      ),
    );
    return false;
  }

  try {
    final config = await remote.fetchHomepageConfig();
    if (!context.mounted) {
      return false;
    }
    final selection = await showHomepagePlacementDialog(
      context,
      categories: config.categories,
      secondaryChips: config.secondaryChips,
    );
    if (selection == null || !context.mounted) {
      return false;
    }

    final current = <AdminHomepagePlacementItemModel>[
      ...config.topStories.asMap().entries.map(
        (entry) => entry.value.toPatchItem(positionOverride: entry.key),
      ),
      ...config.latestStories.asMap().entries.map(
        (entry) => entry.value.toPatchItem(positionOverride: entry.key),
      ),
      ...config.categorySections.expand(
        (section) => section.items.asMap().entries.map(
          (entry) => AdminHomepagePlacementItemModel(
            articleId: entry.value.id,
            section: 'category',
            targetKey: section.key,
            position: entry.key,
            enabled: true,
          ),
        ),
      ),
      ...config.secondaryChipSections.expand(
        (section) => section.items.asMap().entries.map(
          (entry) => AdminHomepagePlacementItemModel(
            articleId: entry.value.id,
            section: 'secondary_chip',
            targetKey: section.key,
            position: entry.key,
            enabled: true,
          ),
        ),
      ),
    ];

    final exists = current.any(
      (item) =>
          item.articleId == article.id &&
          item.section == selection.section &&
          item.targetKey == selection.targetKey,
    );
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This story is already in that homepage slot.'),
        ),
      );
      return false;
    }

    final position = current
        .where(
          (item) =>
              item.section == selection.section &&
              item.targetKey == selection.targetKey,
        )
        .length;
    final next = [
      ...current,
      AdminHomepagePlacementItemModel(
        articleId: article.id,
        section: selection.section,
        targetKey: selection.targetKey,
        position: position,
        enabled: true,
      ),
    ];
    await remote.updateHomepagePlacements(next);
    if (!context.mounted) {
      return true;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Story added to homepage curation.')),
    );
    return true;
  } catch (error) {
    if (!context.mounted) {
      return false;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mapFailure(error).message)));
    return false;
  }
}
