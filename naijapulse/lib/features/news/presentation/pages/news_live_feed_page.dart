import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:naijapulse/core/routing/app_router.dart';
import 'package:naijapulse/features/news/domain/entities/news_article.dart';
import 'package:naijapulse/features/news/presentation/bloc/news_bloc.dart';
import 'package:naijapulse/features/news/presentation/widgets/latest_story_tile.dart';
import 'package:naijapulse/features/news/presentation/widgets/top_story_hero_card.dart';

class NewsLiveFeedPage extends StatefulWidget {
  const NewsLiveFeedPage({required this.tagId, this.tagLabel, super.key});

  final String tagId;
  final String? tagLabel;

  @override
  State<NewsLiveFeedPage> createState() => _NewsLiveFeedPageState();
}

class _NewsLiveFeedPageState extends State<NewsLiveFeedPage> {
  String get _normalizedTagId => widget.tagId.trim().toLowerCase();

  @override
  Widget build(BuildContext context) {
    final resolvedLabel = _resolveTagLabel();

    return Scaffold(
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            _LiveFeedTopBar(
              title: resolvedLabel,
              onBackTap: () {
                if (context.canPop()) {
                  context.pop();
                  return;
                }
                context.go(AppRouter.homePath);
              },
              onRefreshTap: () =>
                  context.read<NewsBloc>().add(const LoadNewsRequested()),
            ),
            Expanded(
              child: BlocBuilder<NewsBloc, NewsState>(
                builder: (context, state) {
                  final allStories = _mergeStories(state);
                  final taggedStories = _filterStoriesByTag(
                    allStories,
                    _normalizedTagId,
                  );
                  final liveUpdates = _buildLiveUpdates(taggedStories);
                  final relatedStories = taggedStories
                      .where(
                        (story) => !liveUpdates.any(
                          (liveStory) => liveStory.id == story.id,
                        ),
                      )
                      .toList();

                  if (state.status == NewsStatus.loading &&
                      taggedStories.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state.status == NewsStatus.error &&
                      taggedStories.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          state.error ?? 'Unable to load live feed.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  if (taggedStories.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: () async {
                        context.read<NewsBloc>().add(const LoadNewsRequested());
                      },
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        children: [
                          Text(
                            'No live feed items are available for "$resolvedLabel" yet.',
                            style: Theme.of(context).textTheme.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      context.read<NewsBloc>().add(const LoadNewsRequested());
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
                      children: [
                        Text(
                          'Live Updates',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        if (liveUpdates.isNotEmpty)
                          ...liveUpdates.map(
                            (story) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: SizedBox(
                                height: 240,
                                child: TopStoryHeroCard(
                                  story: story,
                                  onTap: () => _openStory(story),
                                ),
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              'No high-priority live updates at the moment.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        const SizedBox(height: 2),
                        Text(
                          'Related News',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        if (relatedStories.isEmpty)
                          Text(
                            'No additional related stories yet.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          )
                        else
                          ...relatedStories.map(
                            (story) => LatestStoryTile(
                              story: story,
                              onTap: () => _openStory(story),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openStory(NewsArticle story) {
    context.read<NewsBloc>().add(NewsStoryOpened(story.id));
    context.push(AppRouter.newsDetailPath(story.id), extra: story);
  }

  String _resolveTagLabel() {
    final explicit = widget.tagLabel?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }

    final words = _normalizedTagId
        .split(RegExp(r'[-_\s]+'))
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .toList();
    return words.isEmpty ? 'Live Feed' : words.join(' ');
  }

  List<NewsArticle> _mergeStories(NewsState state) {
    final merged = [...state.topStories, ...state.latestStories];
    final byId = <String, NewsArticle>{};
    for (final story in merged) {
      byId.putIfAbsent(story.id, () => story);
    }
    return byId.values.toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  }

  List<NewsArticle> _filterStoriesByTag(
    List<NewsArticle> stories,
    String tagId,
  ) {
    if (tagId.isEmpty) {
      return stories;
    }
    return stories.where((story) => _storyMatchesTag(story, tagId)).toList();
  }

  List<NewsArticle> _buildLiveUpdates(List<NewsArticle> stories) {
    final now = DateTime.now();
    final liveFirst = stories.where((story) {
      final text =
          '${story.title} ${story.summary ?? ''} ${story.category} ${story.source}'
              .toLowerCase();
      final ageHours = now.difference(story.publishedAt).inHours;
      return _containsAny(text, const [
            'live',
            'breaking',
            'developing',
            'update',
          ]) ||
          ageHours <= 4;
    }).toList();

    return liveFirst.take(3).toList();
  }

  bool _storyMatchesTag(NewsArticle story, String tagId) {
    final searchableText =
        '${story.title} ${story.summary ?? ''} ${story.category} ${story.source}'
            .toLowerCase();

    switch (tagId) {
      case 'fact-checked':
        return story.isFactChecked;
      case 'live-updates':
        final ageHours = DateTime.now().difference(story.publishedAt).inHours;
        return _containsAny(searchableText, const [
              'live',
              'breaking',
              'developing',
              'update',
            ]) ||
            ageHours <= 6;
      case 'election-2027':
        return _containsAny(searchableText, const [
          'election',
          'inec',
          'polling',
          'ballot',
          'vote',
          'campaign',
          'apc',
          'pdp',
          'lp',
        ]);
      default:
        final tokens = tagId
            .split(RegExp(r'[-_\s]+'))
            .where((token) => token.trim().length > 2)
            .toList();
        if (tokens.isEmpty) {
          return false;
        }
        return tokens.any(searchableText.contains);
    }
  }

  bool _containsAny(String haystack, List<String> keywords) {
    for (final keyword in keywords) {
      if (haystack.contains(keyword)) {
        return true;
      }
    }
    return false;
  }
}

class _LiveFeedTopBar extends StatelessWidget {
  const _LiveFeedTopBar({
    required this.title,
    required this.onBackTap,
    required this.onRefreshTap,
  });

  final String title;
  final VoidCallback onBackTap;
  final VoidCallback onRefreshTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.88),
          ],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBackTap,
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            tooltip: 'Back',
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            onPressed: onRefreshTap,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }
}
