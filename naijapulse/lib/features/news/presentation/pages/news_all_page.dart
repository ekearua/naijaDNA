import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:naijapulse/core/routing/app_router.dart';
import 'package:naijapulse/core/theme/theme.dart';
import 'package:naijapulse/core/widgets/news_thumbnail.dart';
import 'package:naijapulse/features/news/domain/entities/news_article.dart';
import 'package:naijapulse/features/news/presentation/bloc/news_bloc.dart';
import 'package:naijapulse/features/news/presentation/widgets/news_time.dart';
import 'package:naijapulse/features/polls/presentation/bloc/polls_bloc.dart';

class NewsAllPage extends StatefulWidget {
  const NewsAllPage({this.showScaffold = true, super.key});

  final bool showScaffold;

  @override
  State<NewsAllPage> createState() => _NewsAllPageState();
}

class _NewsAllPageState extends State<NewsAllPage> {
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final state = context.read<NewsBloc>().state;
      if (state.status == NewsStatus.initial) {
        context.read<NewsBloc>().add(const LoadNewsRequested());
      }
    });
  }

  void _openStory(NewsArticle story) {
    context.read<NewsBloc>().add(NewsStoryOpened(story.id));
    context.push(AppRouter.newsDetailPath(story.id), extra: story);
  }

  @override
  Widget build(BuildContext context) {
    final pageBody = BlocBuilder<NewsBloc, NewsState>(
      builder: (context, state) {
        final pollsState = context.watch<PollsBloc>().state;
        final allStories = _mergeStories(state);
        final categories = _buildCategories(allStories, pollsState: pollsState);
        final effectiveCategory = categories.contains(_selectedCategory)
            ? _selectedCategory
            : categories.first;
        final stories = _filteredStories(allStories, effectiveCategory);
        final themeData = _themeForCategory(effectiveCategory);
        final featuredStory = stories.isNotEmpty ? stories.first : null;
        final spotlightStories = stories.skip(1).take(3).toList();
        final latestStories = stories.skip(4).toList();

        if (state.status == NewsStatus.loading && stories.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.status == NewsStatus.error && stories.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(state.error ?? 'Unable to load news feed.'),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            context.read<NewsBloc>().add(const LoadNewsRequested());
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _CategoryHero(
                theme: themeData,
                categoryLabel: effectiveCategory,
                onBackTap: () {
                  if (context.canPop()) {
                    context.pop();
                    return;
                  }
                  context.go(AppRouter.homePath);
                },
                onSearchTap: () => context.push(AppRouter.searchPath),
              ),
              const SizedBox(height: 14),
              _CategoryFilterRail(
                categories: categories,
                selectedCategory: effectiveCategory,
                onSelected: (value) =>
                    setState(() => _selectedCategory = value),
              ),
              const SizedBox(height: 18),
              if (featuredStory != null) ...[
                _CategoryFeatureCard(
                  story: featuredStory,
                  theme: themeData,
                  onTap: () => _openStory(featuredStory),
                ),
                const SizedBox(height: 18),
              ],
              if (spotlightStories.isNotEmpty) ...[
                _SectionHeader(
                  title: themeData.spotlightTitle,
                  subtitle: themeData.spotlightSubtitle,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 218,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: spotlightStories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (context, index) {
                      final story = spotlightStories[index];
                      return _CategoryMiniCard(
                        story: story,
                        theme: themeData,
                        onTap: () => _openStory(story),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 22),
              ],
              if (latestStories.isNotEmpty) ...[
                const _SectionHeader(
                  title: 'Daily edit',
                  subtitle:
                      'A tighter list of follow-up reads, reactions, and deeper context.',
                ),
                const SizedBox(height: 12),
                ...latestStories.map(
                  (story) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _CategoryStoryRow(
                      story: story,
                      theme: themeData,
                      onTap: () => _openStory(story),
                    ),
                  ),
                ),
              ],
              if (stories.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Text(
                    'No stories available in this category yet.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );

    if (!widget.showScaffold) {
      return SafeArea(top: true, bottom: false, child: pageBody);
    }

    return Scaffold(body: SafeArea(top: true, child: pageBody));
  }

  List<NewsArticle> _mergeStories(NewsState state) {
    final all = [...state.topStories, ...state.latestStories];
    final byId = <String, NewsArticle>{};
    for (final story in all) {
      byId.putIfAbsent(story.id, () => story);
    }
    return byId.values.toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  }

  List<NewsArticle> _filteredStories(
    List<NewsArticle> stories,
    String category,
  ) {
    if (_normalizeCategory(category) == 'all') {
      return stories;
    }
    final selected = _normalizeCategory(category);
    return stories
        .where((story) => _inferStoryCategoryKey(story) == selected)
        .toList();
  }

  String _normalizeCategory(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'all') {
      return 'all';
    }
    if (normalized.contains('breaking') ||
        normalized.contains('headline') ||
        normalized.contains('top news')) {
      return 'breaking-news';
    }
    if (normalized == 'breaking news') {
      return 'breaking-news';
    }
    if (normalized.contains('politic') || normalized.contains('election')) {
      return 'politics';
    }
    if (normalized.contains('business') ||
        normalized.contains('econom') ||
        normalized.contains('finance') ||
        normalized.contains('naira') ||
        normalized.contains('market')) {
      return 'business';
    }
    if (normalized == 'technology') {
      return 'technology';
    }
    if (normalized.contains('tech') || normalized.contains('startup')) {
      return 'technology';
    }
    if (normalized.contains('sport') ||
        normalized.contains('football') ||
        normalized.contains('afcon')) {
      return 'sports';
    }
    if (normalized.contains('music')) {
      return 'music';
    }
    if (normalized.contains('entertain') ||
        normalized.contains('celebrity') ||
        normalized.contains('nollywood') ||
        normalized.contains('lifestyle')) {
      return 'entertainment';
    }
    return normalized;
  }

  List<String> _buildCategories(
    List<NewsArticle> stories, {
    required PollsState pollsState,
  }) {
    final storyCategoryKeys = stories
        .map(_inferStoryCategoryKey)
        .where((key) => key.isNotEmpty && key != 'all')
        .toSet();
    if (storyCategoryKeys.isEmpty) {
      return const ['All'];
    }

    final labelsByKey = <String, String>{};
    for (final category in pollsState.categories) {
      final key = _normalizeCategory(category.name);
      if (key.isEmpty || !storyCategoryKeys.contains(key)) {
        continue;
      }
      labelsByKey[key] = category.name.trim();
    }
    for (final key in storyCategoryKeys) {
      labelsByKey.putIfAbsent(key, () => _displayCategoryFromKey(key));
    }

    final labels = labelsByKey.values.toList()..sort();
    return ['All', ...labels];
  }

  String _displayCategoryFromKey(String normalized) {
    switch (normalized) {
      case 'breaking-news':
        return 'Breaking News';
      case 'technology':
        return 'Technology';
      case 'music':
        return 'Music';
      default:
        final words = normalized
            .replaceAll('-', ' ')
            .split(' ')
            .where((word) => word.isNotEmpty)
            .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
            .toList();
        return words.join(' ');
    }
  }

  String _inferStoryCategoryKey(NewsArticle story) {
    final storyCategory = _normalizeCategory(story.category);
    if (storyCategory != 'general') {
      return storyCategory;
    }

    final text = '${story.title} ${story.summary ?? ''} ${story.source}'
        .toLowerCase();
    if (text.contains('politic') || text.contains('election')) {
      return 'politics';
    }
    if (text.contains('business') ||
        text.contains('econom') ||
        text.contains('market') ||
        text.contains('naira') ||
        text.contains('cbn')) {
      return 'business';
    }
    if (text.contains('tech') ||
        text.contains('startup') ||
        text.contains('ai') ||
        text.contains('fintech')) {
      return 'technology';
    }
    if (text.contains('sport') ||
        text.contains('football') ||
        text.contains('afcon') ||
        text.contains('npfl')) {
      return 'sports';
    }
    if (text.contains('music') || text.contains('album')) {
      return 'music';
    }
    if (text.contains('entertain') ||
        text.contains('movie') ||
        text.contains('nollywood') ||
        text.contains('celebrity')) {
      return 'entertainment';
    }
    return 'breaking-news';
  }

  _CategoryTheme _themeForCategory(String category) {
    switch (_normalizeCategory(category)) {
      case 'business':
        return const _CategoryTheme(
          gradientColors: [Color(0xFF153A6B), Color(0xFF2F5A96)],
          accent: AppTheme.business,
          label: 'Business',
          title: 'Markets, money, and policy in motion.',
          subtitle:
              'A tighter briefing on the forces moving prices, companies, and the wider economy.',
          spotlightTitle: 'Market radar',
          spotlightSubtitle:
              'Quick reads that frame what matters before the next trading cycle.',
        );
      case 'sports':
        return const _CategoryTheme(
          gradientColors: [Color(0xFF9B5B16), Color(0xFFD88C2F)],
          accent: AppTheme.sports,
          label: 'Sports',
          title: 'Matchdays, transfers, and the stories behind the scoreline.',
          subtitle:
              'Fast-moving updates with enough context to keep the conversation sharp.',
          spotlightTitle: 'Game focus',
          spotlightSubtitle:
              'The fixtures, personalities, and narratives driving the feed.',
        );
      case 'music':
        return const _CategoryTheme(
          gradientColors: [Color(0xFF6A395E), Color(0xFF9A5B8B)],
          accent: Color(0xFF8E5C9F),
          label: 'Music',
          title: 'The sound shaping the moment.',
          subtitle:
              'Chart shifts, releases, performances, and the culture around them.',
          spotlightTitle: 'On rotation',
          spotlightSubtitle:
              'What people are listening to, debating, and carrying forward.',
        );
      case 'entertainment':
        return const _CategoryTheme(
          gradientColors: [Color(0xFF6B2042), Color(0xFFA03E72)],
          accent: AppTheme.entertainment,
          label: 'Entertainment',
          title:
              'Culture, lifestyle, and the stories everyone is talking about.',
          subtitle:
              'A more polished sweep across Nollywood, celebrity, and lifestyle trends.',
          spotlightTitle: 'Culture radar',
          spotlightSubtitle:
              'Follow-ups and side angles that keep the feed feeling alive.',
        );
      case 'technology':
        return const _CategoryTheme(
          gradientColors: [Color(0xFF0E5B55), Color(0xFF19756A)],
          accent: AppTheme.tech,
          label: 'Technology',
          title:
              'Innovation, infrastructure, and the systems changing everyday life.',
          subtitle:
              'A cleaner read on startups, AI, telecoms, and the policy edges around them.',
          spotlightTitle: 'Signal boost',
          spotlightSubtitle:
              'Secondary stories that explain where the tech story is really heading.',
        );
      case 'politics':
        return const _CategoryTheme(
          gradientColors: [Color(0xFF761F1A), Color(0xFFB13A30)],
          accent: AppTheme.breaking,
          label: 'Politics',
          title: 'Power, policy, and the people shaping the national agenda.',
          subtitle:
              'Sharp updates with enough context to make the day’s politics legible.',
          spotlightTitle: 'Political watch',
          spotlightSubtitle:
              'Key developments and follow-on angles worth holding onto.',
        );
      case 'breaking-news':
      default:
        return const _CategoryTheme(
          gradientColors: [Color(0xFF8B241D), Color(0xFFC84C3B)],
          accent: AppTheme.breaking,
          label: 'Breaking News',
          title: 'The biggest developments, framed fast.',
          subtitle:
              'Urgent coverage that still keeps the signal clearer than the noise.',
          spotlightTitle: 'Still developing',
          spotlightSubtitle:
              'Fresh reads and second-wave details around the day’s lead stories.',
        );
    }
  }
}

class _CategoryTheme {
  const _CategoryTheme({
    required this.gradientColors,
    required this.accent,
    required this.label,
    required this.title,
    required this.subtitle,
    required this.spotlightTitle,
    required this.spotlightSubtitle,
  });

  final List<Color> gradientColors;
  final Color accent;
  final String label;
  final String title;
  final String subtitle;
  final String spotlightTitle;
  final String spotlightSubtitle;
}

class _CategoryHero extends StatelessWidget {
  const _CategoryHero({
    required this.theme,
    required this.categoryLabel,
    required this.onBackTap,
    required this.onSearchTap,
  });

  final _CategoryTheme theme;
  final String categoryLabel;
  final VoidCallback onBackTap;
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.gradientColors,
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: onBackTap,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.16),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const Spacer(),
              IconButton.filledTonal(
                onPressed: onSearchTap,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.16),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.search_rounded),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              categoryLabel == 'All' ? 'All News' : theme.label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            theme.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontFamily: AppTheme.headlineFontFamily,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            theme.subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.86),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryFilterRail extends StatelessWidget {
  const _CategoryFilterRail({
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
  });

  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == selectedCategory;
          return ChoiceChip(
            label: Text(category),
            selected: isSelected,
            showCheckmark: false,
            onSelected: (_) => onSelected(category),
            backgroundColor: Theme.of(context).colorScheme.surface,
            selectedColor: AppTheme.primary.withValues(alpha: 0.12),
            side: BorderSide(
              color: isSelected
                  ? AppTheme.primary
                  : AppTheme.divider.withValues(alpha: 0.8),
            ),
            labelStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

class _CategoryFeatureCard extends StatelessWidget {
  const _CategoryFeatureCard({
    required this.story,
    required this.theme,
    required this.onTap,
  });

  final NewsArticle story;
  final _CategoryTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: AppTheme.ambientShadow(Theme.of(context).brightness),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 260,
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
                          Colors.black.withValues(alpha: 0.76),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 18,
                    left: 18,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: theme.accent.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        theme.label,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20,
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
                          '${story.source} • ${relativeTimeLabel(story.publishedAt)}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.84),
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
                    : 'A sharper read on the lead story in this part of the feed.',
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

class _CategoryMiniCard extends StatelessWidget {
  const _CategoryMiniCard({
    required this.story,
    required this.theme,
    required this.onTap,
  });

  final NewsArticle story;
  final _CategoryTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 258,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.divider.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: 110,
                width: double.infinity,
                child: NewsThumbnail(
                  imageUrl: story.imageUrl,
                  fallbackLabel: story.category,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              story.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '${story.source} • ${relativeTimeLabel(story.publishedAt)}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryStoryRow extends StatelessWidget {
  const _CategoryStoryRow({
    required this.story,
    required this.theme,
    required this.onTap,
  });

  final NewsArticle story;
  final _CategoryTheme theme;
  final VoidCallback onTap;

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
          border: Border.all(color: AppTheme.divider.withValues(alpha: 0.55)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 96,
                height: 96,
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      theme.label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: theme.accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
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
                    story.summary?.trim().isNotEmpty == true
                        ? story.summary!.trim()
                        : 'Open for the fuller story and sourcing.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${story.source} • ${relativeTimeLabel(story.publishedAt)}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppTheme.textMeta),
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
