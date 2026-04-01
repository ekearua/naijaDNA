import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:naijapulse/core/di/injection_container.dart';
import 'package:naijapulse/core/routing/app_router.dart';
import 'package:naijapulse/core/theme/theme.dart';
import 'package:naijapulse/core/widgets/empty_state_card.dart';
import 'package:naijapulse/core/widgets/news_thumbnail.dart';
import 'package:naijapulse/features/news/data/datasource/local/saved_story_local_datasource.dart';
import 'package:naijapulse/features/news/domain/entities/news_article.dart';
import 'package:naijapulse/features/news/presentation/bloc/news_bloc.dart';
import 'package:naijapulse/features/news/presentation/widgets/news_time.dart';

class SavedStoriesPage extends StatefulWidget {
  const SavedStoriesPage({this.showScaffold = true, super.key});

  final bool showScaffold;

  @override
  State<SavedStoriesPage> createState() => _SavedStoriesPageState();
}

class _SavedStoriesPageState extends State<SavedStoriesPage> {
  final SavedStoryLocalDataSource _savedStore =
      InjectionContainer.sl<SavedStoryLocalDataSource>();
  Set<String> _savedIds = <String>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedIds();
  }

  Future<void> _loadSavedIds() async {
    final ids = await _savedStore.getSavedArticleIds();
    if (!mounted) {
      return;
    }
    setState(() {
      _savedIds = ids;
      _loading = false;
    });
  }

  Future<void> _removeSavedStory(String articleId) async {
    await _savedStore.toggleSaved(articleId);
    await _loadSavedIds();
  }

  @override
  Widget build(BuildContext context) {
    final content = BlocBuilder<NewsBloc, NewsState>(
      builder: (context, state) {
        final allStories = _mergeStories(state);
        final savedStories = allStories
            .where((story) => _savedIds.contains(story.id))
            .toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
          children: [
            Text(
              'Saved',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                fontFamily: AppTheme.headlineFontFamily,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your briefing shelf for stories worth returning to.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 18),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 28),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_savedIds.isEmpty)
              const EmptyStateCard(
                message:
                    'No saved stories yet. Tap Save on any headline to pin it here.',
              )
            else if (savedStories.isEmpty)
              const EmptyStateCard(
                message:
                    'Saved stories will appear here once those articles are loaded into the current feed snapshot.',
              )
            else ...[
              _SavedHeroCard(
                story: savedStories.first,
                onTap: () => _openStory(savedStories.first),
                onRemove: () => _removeSavedStory(savedStories.first.id),
              ),
              if (savedStories.length > 1) ...[
                const SizedBox(height: 16),
                _SavedSupportCard(
                  story: savedStories[1],
                  onTap: () => _openStory(savedStories[1]),
                  onRemove: () => _removeSavedStory(savedStories[1].id),
                ),
              ],
              if (savedStories.length > 2) ...[
                const SizedBox(height: 24),
                Text(
                  'Saved archive',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                ...savedStories
                    .skip(2)
                    .map(
                      (story) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _SavedStoryRow(
                          story: story,
                          onTap: () => _openStory(story),
                          onRemove: () => _removeSavedStory(story.id),
                        ),
                      ),
                    ),
              ],
            ],
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () => context.go(AppRouter.homePath),
              icon: const Icon(Icons.home_outlined),
              label: const Text('Back to Home'),
            ),
          ],
        );
      },
    );

    if (!widget.showScaffold) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Saved')),
      body: content,
    );
  }

  void _openStory(NewsArticle story) {
    context.push(AppRouter.newsDetailPath(story.id), extra: story);
  }

  List<NewsArticle> _mergeStories(NewsState state) {
    final all = [...state.topStories, ...state.latestStories];
    final byId = <String, NewsArticle>{};
    for (final story in all) {
      byId.putIfAbsent(story.id, () => story);
    }
    final merged = byId.values.toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return merged;
  }
}

class _SavedHeroCard extends StatelessWidget {
  const _SavedHeroCard({
    required this.story,
    required this.onTap,
    required this.onRemove,
  });

  final NewsArticle story;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: Theme.of(context).colorScheme.surface,
          boxShadow: AppTheme.ambientShadow(Theme.of(context).brightness),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 240,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  NewsThumbnail(
                    imageUrl: story.imageUrl,
                    fallbackLabel: story.category,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.08),
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 18,
                    left: 18,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Saved Briefing',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    right: 14,
                    child: IconButton.filledTonal(
                      onPressed: onRemove,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.18),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.bookmark_remove_outlined),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 22,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          story.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${story.source} • ${story.category} • ${relativeTimeLabel(story.publishedAt)}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.82),
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Text(
                story.summary?.trim().isNotEmpty == true
                    ? story.summary!.trim()
                    : 'Return to this story when you need the fuller context, source trail, and discussion around it.',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedSupportCard extends StatelessWidget {
  const _SavedSupportCard({
    required this.story,
    required this.onTap,
    required this.onRemove,
  });

  final NewsArticle story;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.divider.withValues(alpha: 0.7)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                width: 104,
                height: 104,
                child: NewsThumbnail(
                  imageUrl: story.imageUrl,
                  fallbackLabel: story.category,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    story.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${story.source} • ${relativeTimeLabel(story.publishedAt)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.bookmark_remove_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedStoryRow extends StatelessWidget {
  const _SavedStoryRow({
    required this.story,
    required this.onTap,
    required this.onRemove,
  });

  final NewsArticle story;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.divider.withValues(alpha: 0.55)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    story.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    story.summary?.trim().isNotEmpty == true
                        ? story.summary!.trim()
                        : 'Saved for later reading.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${story.category} • ${story.source} • ${relativeTimeLabel(story.publishedAt)}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppTheme.textMeta),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.bookmark_remove_outlined),
            ),
          ],
        ),
      ),
    );
  }
}
