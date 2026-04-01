import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:naijapulse/core/di/injection_container.dart';
import 'package:naijapulse/core/error/failures.dart';
import 'package:naijapulse/core/routing/app_router.dart';
import 'package:naijapulse/core/theme/theme.dart';
import 'package:naijapulse/core/widgets/news_thumbnail.dart';
import 'package:naijapulse/features/news/data/datasource/remote/news_remote_datasource.dart';
import 'package:naijapulse/features/news/domain/entities/news_article.dart';
import 'package:naijapulse/features/news/presentation/bloc/news_bloc.dart';
import 'package:naijapulse/features/news/presentation/widgets/news_time.dart';
import 'package:naijapulse/features/search/presentation/widgets/search_feed_story_tile.dart';
import 'package:naijapulse/features/search/presentation/widgets/search_input_field.dart';
import 'package:naijapulse/features/search/presentation/widgets/search_result_story_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({this.showScaffold = true, super.key});

  final bool showScaffold;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const String _recentSearchesKey = 'recent_searches_v1';

  final TextEditingController _controller = TextEditingController();
  Timer? _searchDebounce;

  final List<String> _recentSearches = <String>[];

  String _query = '';
  bool _isSearching = false;
  bool _hasSearchedRemotely = false;
  String? _searchError;
  List<NewsArticle> _remoteResults = const <NewsArticle>[];
  int _searchToken = 0;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = BlocBuilder<NewsBloc, NewsState>(
      builder: (context, state) {
        final allStories = _mergeStories(state);
        final suggestedQueries = _buildSuggestedQueries(allStories);
        final exploreCategories = _buildExploreCategories(allStories);
        final normalizedQuery = _query.trim().toLowerCase();
        final hasQuery = normalizedQuery.isNotEmpty;

        final localFallbackResults = allStories.where((story) {
          if (!hasQuery) {
            return true;
          }
          return story.title.toLowerCase().contains(normalizedQuery) ||
              story.category.toLowerCase().contains(normalizedQuery) ||
              story.source.toLowerCase().contains(normalizedQuery) ||
              (story.summary?.toLowerCase().contains(normalizedQuery) ?? false);
        }).toList();

        List<NewsArticle> filteredResults = const <NewsArticle>[];
        if (hasQuery && _hasSearchedRemotely) {
          filteredResults = _remoteResults;
        } else if (hasQuery) {
          // Before/if remote response fails, keep local fallback results visible.
          filteredResults = localFallbackResults;
        }

        final cardResults = filteredResults.take(2).toList();
        final feedResults = filteredResults.length > 2
            ? filteredResults.sublist(2)
            : const <NewsArticle>[];

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _ExploreHeader(
              showBackButton: widget.showScaffold,
              onBackTap: _handleBackTap,
            ),
            const SizedBox(height: 12),
            SearchInputField(
              controller: _controller,
              onChanged: _onQueryChanged,
              onSubmitted: (value) {
                setState(() => _query = value);
                _rememberSearch(value);
                _searchDebounce?.cancel();
                _executeRemoteSearch(value);
              },
              onClear: _clearSearch,
              hintText: 'Truth Search: verify news or search topics...',
              leadingIcon: Icons.verified_rounded,
              height: 58,
              actionLabel: 'Verify',
              onActionTap: () => _executeRemoteSearch(_controller.text),
            ),
            const SizedBox(height: 8),
            Text(
              'Verified by the Nigerian Fact-Check Archive',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 18),
            if (hasQuery && _isSearching)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (hasQuery && _searchError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 10),
                child: Text(
                  'Search fallback active: $_searchError',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ),
            if (!hasQuery) ...[
              if (suggestedQueries.isNotEmpty) ...[
                _ExploreSectionHeader(
                  title: 'Trending Now',
                  trailingIcon: Icons.trending_up_rounded,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: suggestedQueries
                      .map(
                        (query) => ActionChip(
                          label: Text(query),
                          onPressed: () => _applyQuery(query),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 26),
              ],
              _ExploreSectionHeader(title: 'Categories'),
              const SizedBox(height: 12),
              _ExploreCategoryGrid(
                categories: exploreCategories,
                onCategoryTap: (value) => _applyQuery(value),
                onFactCheckTap: () => context.push(
                  AppRouter.liveFeedPath(
                    tagId: 'fact-checked',
                    label: 'Fact-Checked',
                  ),
                ),
              ),
              if (_recentSearches.isNotEmpty) ...[
                const SizedBox(height: 26),
                _RecentSearchesCard(
                  items: _recentSearches,
                  onTap: _applyQuery,
                  onClearAll: _clearRecentSearches,
                ),
              ],
              if (allStories.isNotEmpty) ...[
                const SizedBox(height: 26),
                _ExploreSectionHeader(title: 'Suggested for You'),
                const SizedBox(height: 12),
                ...allStories
                    .take(4)
                    .map(
                      (story) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _SuggestedStoryCard(
                          story: story,
                          onTap: () => _openStory(story),
                        ),
                      ),
                    ),
              ],
            ] else ...[
              _ExploreSectionHeader(title: 'Search Results'),
              const SizedBox(height: 10),
              if (state.status == NewsStatus.loading && allStories.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (allStories.isEmpty)
                _emptyBackendState(context)
              else ...[
                if (cardResults.isEmpty)
                  _emptyResultsState(context)
                else
                  ...cardResults.map(
                    (story) => SearchResultStoryTile(
                      story: story,
                      onTap: () => _openStory(story),
                    ),
                  ),
                if (feedResults.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...feedResults.map(
                    (story) => SearchFeedStoryTile(
                      story: story,
                      onTap: () => _openStory(story),
                    ),
                  ),
                ],
              ],
            ],
          ],
        );
      },
    );

    if (!widget.showScaffold) {
      return content;
    }

    return Scaffold(body: SafeArea(child: content));
  }

  void _applyQuery(String query) {
    _controller.text = query;
    setState(() => _query = query);
    _rememberSearch(query);
    _searchDebounce?.cancel();
    _executeRemoteSearch(query);
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      _searchDebounce?.cancel();
      setState(() {
        _isSearching = false;
        _hasSearchedRemotely = false;
        _searchError = null;
        _remoteResults = const <NewsArticle>[];
      });
      return;
    }

    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _executeRemoteSearch(trimmed);
    });
  }

  Future<void> _executeRemoteSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      return;
    }

    final token = ++_searchToken;
    setState(() {
      _isSearching = true;
      _hasSearchedRemotely = false;
      _searchError = null;
    });

    try {
      final remote = InjectionContainer.sl<NewsRemoteDataSource>();
      final results = await remote.searchStories(query: trimmed, limit: 30);
      if (!mounted || token != _searchToken) {
        return;
      }
      setState(() {
        _remoteResults = results;
        _isSearching = false;
        _hasSearchedRemotely = true;
      });
    } catch (error) {
      if (!mounted || token != _searchToken) {
        return;
      }
      setState(() {
        _isSearching = false;
        _hasSearchedRemotely = false;
        _searchError = mapFailure(error).message;
      });
    }
  }

  void _clearSearch() {
    _controller.clear();
    _searchDebounce?.cancel();
    setState(() {
      _query = '';
      _isSearching = false;
      _hasSearchedRemotely = false;
      _searchError = null;
      _remoteResults = const <NewsArticle>[];
    });
  }

  void _openStory(NewsArticle story) {
    context.read<NewsBloc>().add(NewsStoryOpened(story.id));
    context.push(AppRouter.newsDetailPath(story.id), extra: story);
  }

  void _handleBackTap() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRouter.homePath);
  }

  Widget _emptyResultsState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Text(
        'No results matched "$_query". Try another keyword.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  Widget _emptyBackendState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Text(
        'No stories are available from the backend yet. Pull to refresh from Home.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  List<NewsArticle> _mergeStories(NewsState state) {
    final all = [...state.topStories, ...state.latestStories];
    final byId = <String, NewsArticle>{};
    for (final story in all) {
      byId.putIfAbsent(story.id, () => story);
    }
    return byId.values.toList();
  }

  List<String> _buildSuggestedQueries(List<NewsArticle> stories) {
    final categorySuggestions = stories
        .map((story) => story.category.trim())
        .where((value) => value.isNotEmpty && value.toLowerCase() != 'general')
        .toSet()
        .take(3)
        .toList();
    final keywordSuggestions = _extractTrendingKeywords(stories);

    final combined = <String>[...categorySuggestions];
    for (final keyword in keywordSuggestions) {
      if (combined.length >= 6) {
        break;
      }
      if (!combined.any(
        (item) => item.toLowerCase() == keyword.toLowerCase(),
      )) {
        combined.add(keyword);
      }
    }
    return combined;
  }

  void _rememberSearch(String value) {
    final query = value.trim();
    if (query.isEmpty) {
      return;
    }

    setState(() {
      _recentSearches.removeWhere(
        (existing) => existing.toLowerCase() == query.toLowerCase(),
      );
      _recentSearches.insert(0, query);
      if (_recentSearches.length > 5) {
        _recentSearches.removeRange(5, _recentSearches.length);
      }
    });
    _persistRecentSearches();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_recentSearchesKey) ?? const <String>[];
    if (!mounted) {
      return;
    }
    setState(() {
      _recentSearches
        ..clear()
        ..addAll(
          stored
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .take(5),
        );
    });
  }

  Future<void> _persistRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentSearchesKey, _recentSearches);
  }

  Future<void> _clearRecentSearches() async {
    setState(() => _recentSearches.clear());
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentSearchesKey);
  }

  List<String> _buildExploreCategories(List<NewsArticle> stories) {
    final categories =
        stories
            .map((story) => story.category.trim())
            .where(
              (value) => value.isNotEmpty && value.toLowerCase() != 'general',
            )
            .toSet()
            .toList()
          ..sort();
    if (categories.isEmpty) {
      return const ['Politics', 'Business', 'Technology', 'Culture'];
    }
    return categories.take(6).toList();
  }

  List<String> _extractTrendingKeywords(List<NewsArticle> stories) {
    const stopWords = <String>{
      'the',
      'and',
      'are',
      'but',
      'can',
      'could',
      'will',
      'would',
      'should',
      'said',
      'says',
      'say',
      'amid',
      'under',
      'before',
      'after',
      'their',
      'there',
      'where',
      'which',
      'while',
      'because',
      'about',
      'into',
      'over',
      'through',
      'around',
      'for',
      'with',
      'from',
      'that',
      'this',
      'against',
      'nigeria',
    };

    final counts = <String, int>{};
    for (final story in stories) {
      final tokens = story.title
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
          .split(RegExp(r'\s+'))
          .where((token) => token.length >= 4 && !stopWords.contains(token));
      for (final token in tokens) {
        counts[token] = (counts[token] ?? 0) + 1;
      }
    }

    final ranked = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ranked
        .where((entry) => entry.value >= 2)
        .take(4)
        .map(
          (entry) => '${entry.key[0].toUpperCase()}${entry.key.substring(1)}',
        )
        .toList();
  }
}

class _ExploreHeader extends StatelessWidget {
  const _ExploreHeader({required this.showBackButton, required this.onBackTap});

  final bool showBackButton;
  final VoidCallback onBackTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showBackButton)
          IconButton(
            onPressed: onBackTap,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        if (showBackButton) const SizedBox(width: 4),
        Text(
          'Explore',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: AppTheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ExploreSectionHeader extends StatelessWidget {
  const _ExploreSectionHeader({required this.title, this.trailingIcon});

  final String title;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
        ),
        if (trailingIcon != null)
          Icon(trailingIcon, color: Theme.of(context).colorScheme.primary),
      ],
    );
  }
}

class _ExploreCategoryGrid extends StatelessWidget {
  const _ExploreCategoryGrid({
    required this.categories,
    required this.onCategoryTap,
    required this.onFactCheckTap,
  });

  final List<String> categories;
  final ValueChanged<String> onCategoryTap;
  final VoidCallback onFactCheckTap;

  @override
  Widget build(BuildContext context) {
    final visibleCategories = categories.take(5).toList();

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.55,
      children: [
        _CategoryFeatureTile(onTap: onFactCheckTap),
        ...visibleCategories.map(
          (category) => _CategoryTile(
            label: category,
            onTap: () => onCategoryTap(category),
          ),
        ),
      ],
    );
  }
}

class _CategoryFeatureTile extends StatelessWidget {
  const _CategoryFeatureTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.primaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Essential',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white.withValues(alpha: isDark ? 0.9 : 0.92),
                letterSpacing: 0.9,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Fact-Check\nArchive',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? theme.colorScheme.surface : const Color(0xFFF1F3EF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? theme.dividerColor.withValues(alpha: 0.28)
                : const Color(0xFFD2D9D3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.grid_view_rounded, color: AppTheme.primary, size: 18),
            const Spacer(),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentSearchesCard extends StatelessWidget {
  const _RecentSearchesCard({
    required this.items,
    required this.onTap,
    required this.onClearAll,
  });

  final List<String> items;
  final ValueChanged<String> onTap;
  final Future<void> Function() onClearAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent Searches',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              TextButton(onPressed: onClearAll, child: const Text('Clear All')),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history_rounded),
              title: Text(item),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => onTap(item),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestedStoryCard extends StatelessWidget {
  const _SuggestedStoryCard({required this.story, required this.onTap});

  final NewsArticle story;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = (story.imageUrl ?? '').trim().isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.22),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasImage)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                child: SizedBox(
                  height: 170,
                  width: double.infinity,
                  child: NewsThumbnail(
                    imageUrl: story.imageUrl,
                    fallbackLabel: story.category,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    story.category.toUpperCase(),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.primary,
                      letterSpacing: 0.9,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    story.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(height: 1.18),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${story.source} • ${relativeTimeLabel(story.publishedAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
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
