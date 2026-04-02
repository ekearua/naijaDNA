import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:naijapulse/core/di/injection_container.dart';
import 'package:naijapulse/core/error/failures.dart';
import 'package:naijapulse/core/routing/app_router.dart';
import 'package:naijapulse/core/sync/sync_cubit.dart';
import 'package:naijapulse/core/theme/theme.dart';
import 'package:naijapulse/core/widgets/empty_state_card.dart';
import 'package:naijapulse/core/widgets/news_thumbnail.dart';
import 'package:naijapulse/features/auth/data/auth_session_controller.dart';
import 'package:naijapulse/features/news/data/datasource/remote/news_remote_datasource.dart';
import 'package:naijapulse/features/news/data/models/homepage_content_model.dart';
import 'package:naijapulse/features/news/domain/entities/news_article.dart';
import 'package:naijapulse/features/news/presentation/bloc/news_bloc.dart';
import 'package:naijapulse/features/news/presentation/helpers/news_engagement_helper.dart';
import 'package:naijapulse/features/news/presentation/widgets/news_time.dart';
import 'package:naijapulse/features/news/presentation/widgets/public_pulse_section.dart';
import 'package:naijapulse/features/polls/presentation/bloc/polls_bloc.dart';

class NewsHomePage extends StatefulWidget {
  const NewsHomePage({this.showScaffold = true, super.key});

  final bool showScaffold;

  @override
  State<NewsHomePage> createState() => _NewsHomePageState();
}

class _NewsHomePageState extends State<NewsHomePage> {
  final NewsRemoteDataSource _remote =
      InjectionContainer.sl<NewsRemoteDataSource>();
  late final AuthSessionController _authSessionController;

  HomepageContentModel? _homepage;
  bool _loadingHomepage = true;
  String? _homepageError;
  String? _selectedCategoryFilter;
  String? _selectedSecondaryChipKey;
  List<NewsArticle> _forYouStories = const <NewsArticle>[];
  bool _loadingForYou = true;
  String? _forYouError;
  final Set<String> _recordedForYouImpressions = <String>{};

  @override
  void initState() {
    super.initState();
    _authSessionController = InjectionContainer.sl<AuthSessionController>();
    _authSessionController.addListener(_handleAuthChanged);
    _loadHomepage();
    _loadForYouStories();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<PollsBloc>().add(const LoadPollsRequested());
    });
  }

  @override
  void dispose() {
    _authSessionController.removeListener(_handleAuthChanged);
    super.dispose();
  }

  void _openStory(NewsArticle story) {
    context.read<NewsBloc>().add(NewsStoryOpened(story.id));
    context.push(AppRouter.newsDetailPath(story.id), extra: story);
  }

  Future<void> _saveStory(NewsArticle story) async {
    await NewsEngagementHelper.saveArticle(context, story);
  }

  Future<void> _shareStory(NewsArticle story) async {
    await NewsEngagementHelper.shareArticle(context, story);
  }

  Future<void> _discussStory(NewsArticle story) async {
    await NewsEngagementHelper.discussArticle(context, story, openDetail: true);
  }

  Future<void> _refreshFeed() async {
    await Future.wait([_loadHomepage(), _loadForYouStories()]);
    if (!mounted) {
      return;
    }
    context.read<PollsBloc>().add(const LoadPollsRequested());
  }

  void _handleAuthChanged() {
    if (!mounted) {
      return;
    }
    if (!_authSessionController.isAuthenticated) {
      _recordedForYouImpressions.clear();
    }
    _loadForYouStories();
  }

  Future<void> _loadHomepage() async {
    setState(() {
      _loadingHomepage = true;
      _homepageError = null;
    });
    try {
      final homepage = await _remote.fetchHomepageContent();
      if (!mounted) {
        return;
      }
      setState(() {
        _homepage = homepage;
        _selectedSecondaryChipKey = _resolveSelectedSecondaryChipKey(homepage);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _homepageError = mapFailure(error).message);
    } finally {
      if (mounted) {
        setState(() => _loadingHomepage = false);
      }
    }
  }

  Future<void> _loadForYouStories() async {
    setState(() {
      _loadingForYou = true;
      _forYouError = null;
    });
    try {
      final stories = await _remote.fetchPersonalizedStories(
        limit: 12,
        category: _selectedCategoryFilter,
      );
      if (!mounted) {
        return;
      }
      setState(() => _forYouStories = stories);
      _recordForYouImpressions(stories);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _forYouError = mapFailure(error).message);
    } finally {
      if (mounted) {
        setState(() => _loadingForYou = false);
      }
    }
  }

  void _recordForYouImpressions(List<NewsArticle> stories) {
    final pendingStories = stories
        .where((story) => _recordedForYouImpressions.add(story.id))
        .toList(growable: false);
    if (pendingStories.isEmpty) {
      return;
    }
    unawaited(
      Future.wait(
        pendingStories.map(
          (story) => _remote.recordFeedEvent(
            articleId: story.id,
            eventType: 'impression',
          ),
        ),
      ).catchError((_) {
        // Impression telemetry should never interrupt the feed.
      }),
    );
  }

  Future<void> _handleForYouMoreLikeThis(NewsArticle story) async {
    await NewsEngagementHelper.likeArticle(context, story);
  }

  Future<void> _handleForYouHideStory(NewsArticle story) async {
    try {
      final applied = await _remote.applyFeedFeedback(
        action: 'hide_article',
        articleId: story.id,
      );
      if (!mounted) {
        return;
      }
      if (applied) {
        setState(() {
          _forYouStories = _forYouStories
              .where((item) => item.id != story.id)
              .toList(growable: false);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('We will show less of this story.')),
        );
        await _loadForYouStories();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to personalize your feed.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapFailure(error).message)));
    }
  }

  Future<void> _handleForYouHideSource(NewsArticle story) async {
    final source = story.source.trim();
    if (source.isEmpty) {
      return;
    }
    try {
      final applied = await _remote.applyFeedFeedback(
        action: 'hide_source',
        source: source,
      );
      if (!mounted) {
        return;
      }
      if (applied) {
        setState(() {
          _forYouStories = _forYouStories
              .where((item) => item.source.trim() != source)
              .toList(growable: false);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stories from $source will be shown less.')),
        );
        await _loadForYouStories();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to personalize your feed.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapFailure(error).message)));
    }
  }

  String? _resolveSelectedSecondaryChipKey(HomepageContentModel homepage) {
    final current = _selectedSecondaryChipKey;
    if (current != null &&
        homepage.secondaryChips.any((item) => item.key == current)) {
      return current;
    }
    return homepage.secondaryChips.isEmpty
        ? null
        : homepage.secondaryChips.first.key;
  }

  HomepageSecondaryChipFeedModel? _findSelectedSecondaryChip(
    HomepageContentModel? homepage,
  ) {
    if (homepage == null || _selectedSecondaryChipKey == null) {
      return null;
    }
    for (final chip in homepage.secondaryChips) {
      if (chip.key == _selectedSecondaryChipKey) {
        return chip;
      }
    }
    return null;
  }

  List<String> _buildCategoryChipLabels({
    required HomepageContentModel? homepage,
    required List<NewsArticle> latestStories,
  }) {
    final labels = <String>[];
    final seen = <String>{};
    final storyGroups = <Iterable<NewsArticle>>[
      homepage?.topStories ?? const <NewsArticle>[],
      latestStories,
      if (homepage != null)
        ...homepage.categories.map((section) => section.items),
    ];
    for (final group in storyGroups) {
      for (final story in group) {
        final label = story.category.trim();
        if (label.isEmpty) {
          continue;
        }
        final normalized = label.toLowerCase();
        if (seen.add(normalized)) {
          labels.add(label);
        }
      }
    }
    labels.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return labels;
  }

  List<NewsArticle> _filterStoriesByCategory(
    List<NewsArticle> stories,
    String? category,
  ) {
    final normalizedCategory = category?.trim().toLowerCase();
    if (normalizedCategory == null || normalizedCategory.isEmpty) {
      return stories;
    }
    return stories
        .where(
          (story) => story.category.trim().toLowerCase() == normalizedCategory,
        )
        .toList(growable: false);
  }

  List<Widget> _buildCategorySectionWidgets(
    HomepageCategoryFeedModel categorySection,
  ) {
    final items = _filterStoriesByCategory(
      categorySection.items,
      _selectedCategoryFilter,
    );
    if (items.isEmpty) {
      return const <Widget>[];
    }

    return <Widget>[
      const SizedBox(height: 6),
      _SectionHeading(title: categorySection.label),
      const SizedBox(height: 14),
      ...items.map(
        (story) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: _EditorialStoryCard(
            story: story,
            onTap: () => _openStory(story),
            onSaveTap: () => _saveStory(story),
            onShareTap: () => _shareStory(story),
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final pollsState = context.watch<PollsBloc>().state;
    final isSignedIn = _authSessionController.isAuthenticated;
    final homepage = _homepage;
    final personalizedLatestStories = _forYouStories.toList(growable: false);
    final unfilteredLatestStories =
        isSignedIn && personalizedLatestStories.isNotEmpty
        ? personalizedLatestStories
        : homepage == null
        ? const <NewsArticle>[]
        : homepage.latestStories.toList(growable: false);
    final categoryChipLabels = _buildCategoryChipLabels(
      homepage: homepage,
      latestStories: unfilteredLatestStories,
    );
    final selectedCategoryFilter =
        _selectedCategoryFilter != null &&
            categoryChipLabels.any(
              (label) =>
                  label.toLowerCase() == _selectedCategoryFilter!.toLowerCase(),
            )
        ? _selectedCategoryFilter
        : null;
    final latestStories = _filterStoriesByCategory(
      unfilteredLatestStories,
      selectedCategoryFilter,
    );
    final latestStoriesArePersonalized =
        isSignedIn && personalizedLatestStories.isNotEmpty;
    final topStories = _filterStoriesByCategory(
      homepage?.topStories.toList(growable: false) ?? const <NewsArticle>[],
      selectedCategoryFilter,
    );
    final selectedSecondaryChip = _findSelectedSecondaryChip(homepage);
    final filteredSecondaryChipStories = selectedSecondaryChip == null
        ? const <NewsArticle>[]
        : _filterStoriesByCategory(
            selectedSecondaryChip.items,
            selectedCategoryFilter,
          );
    final hasPolls = pollsState.polls.isNotEmpty;
    final hasHomepageContent = homepage != null && !homepage.isEmpty;

    final content = MultiBlocListener(
      listeners: [
        BlocListener<SyncCubit, SyncState>(
          listenWhen: (previous, current) =>
              previous.status != current.status &&
              current.status == SyncStatus.synced,
          listener: (context, state) {
            _loadHomepage();
            _loadForYouStories();
          },
        ),
        BlocListener<PollsBloc, PollsState>(
          listenWhen: (previous, current) =>
              previous.status != current.status &&
              current.status == PollsStatus.error,
          listener: (context, state) {
            final message = state.errorMessage ?? 'Unable to submit vote.';
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
          },
        ),
      ],
      child: _loadingHomepage && homepage == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshFeed,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  if (_homepageError != null && !hasHomepageContent)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _FeedErrorBanner(
                        message: _homepageError!,
                        onRetry: _refreshFeed,
                      ),
                    ),
                  if (categoryChipLabels.isNotEmpty) ...[
                    _EditorialChipRow(
                      categories: categoryChipLabels,
                      selectedCategory: selectedCategoryFilter,
                      onSelected: (value) {
                        setState(() => _selectedCategoryFilter = value);
                        if (isSignedIn) {
                          _loadForYouStories();
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (homepage != null &&
                      homepage.secondaryChips.isNotEmpty) ...[
                    _SecondaryChipRow(
                      chips: homepage.secondaryChips,
                      selectedKey: _selectedSecondaryChipKey,
                      onSelected: (value) =>
                          setState(() => _selectedSecondaryChipKey = value),
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (topStories.isNotEmpty) ...[
                    const _SectionHeading(title: 'Top Stories'),
                    const SizedBox(height: 14),
                    _TopStoriesCarousel(
                      stories: topStories,
                      onStoryTap: _openStory,
                      onSaveTap: _saveStory,
                      onShareTap: _shareStory,
                      onDiscussTap: _discussStory,
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (latestStories.isNotEmpty) ...[
                    _SectionHeading(
                      title: 'Latest Stories',
                      subtitle: latestStoriesArePersonalized
                          ? 'Shaped by your interests and reading activity.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    ...latestStories.map(
                      (story) => Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: _EditorialStoryCard(
                          story: story,
                          onTap: () => _openStory(story),
                          onSaveTap: () => _saveStory(story),
                          onShareTap: () => _shareStory(story),
                          onMoreLikeThis: latestStoriesArePersonalized
                              ? () => _handleForYouMoreLikeThis(story)
                              : null,
                          onHideStory: latestStoriesArePersonalized
                              ? () => _handleForYouHideStory(story)
                              : null,
                          onHideSource: latestStoriesArePersonalized
                              ? () => _handleForYouHideSource(story)
                              : null,
                        ),
                      ),
                    ),
                  ],
                  if (homepage != null && homepage.categories.isNotEmpty) ...[
                    for (final categorySection in homepage.categories)
                      ..._buildCategorySectionWidgets(categorySection),
                  ],
                  if (selectedSecondaryChip != null &&
                      filteredSecondaryChipStories.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _SectionHeading(title: selectedSecondaryChip.label),
                    const SizedBox(height: 14),
                    ...filteredSecondaryChipStories.map(
                      (story) => Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: _EditorialStoryCard(
                          story: story,
                          onTap: () => _openStory(story),
                          onSaveTap: () => _saveStory(story),
                          onShareTap: () => _shareStory(story),
                        ),
                      ),
                    ),
                  ],
                  if (hasPolls) ...[
                    const SizedBox(height: 6),
                    const _SectionHeading(
                      title: 'Public Pulse',
                      subtitle:
                          'See what the audience is weighing in on today.',
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).dividerColor.withValues(alpha: 0.35),
                        ),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: const PublicPulseSection(),
                    ),
                  ],
                  if (!hasHomepageContent && !_loadingHomepage) ...[
                    const SizedBox(height: 18),
                    const EmptyStateCard(
                      message:
                          'No stories are featured on the home feed right now. Please check back shortly for the latest updates.',
                    ),
                  ],
                ],
              ),
            ),
    );

    if (!widget.showScaffold) {
      return content;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerForeground = isDark ? Colors.white : AppTheme.textPrimary;
    final headerSurface = isDark
        ? Colors.white.withValues(alpha: 0.2)
        : Colors.white.withValues(alpha: 0.9);
    final systemOverlayStyle = isDark
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          );

    return Scaffold(
      appBar: AppBar(
        systemOverlayStyle: systemOverlayStyle,
        titleSpacing: 16,
        toolbarHeight: 72,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: headerSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: headerForeground.withValues(alpha: 0.08),
                ),
              ),
              child: Text(
                'naijaDNA',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: headerForeground,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const Spacer(),
            Container(
              decoration: BoxDecoration(
                color: headerSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: headerForeground.withValues(alpha: 0.08),
                ),
              ),
              child: IconButton(
                onPressed: () => context.push(AppRouter.searchPath),
                icon: Icon(
                  Icons.search_rounded,
                  color: headerForeground,
                  size: 18,
                ),
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
                padding: EdgeInsets.zero,
                tooltip: 'Search',
              ),
            ),
          ],
        ),
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppTheme.editorialGradient(Theme.of(context).brightness),
          ),
        ),
      ),
      body: content,
    );
  }
}

class _FeedErrorBanner extends StatelessWidget {
  const _FeedErrorBanner({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(
          context,
        ).colorScheme.errorContainer.withValues(alpha: 0.82),
      ),
      child: Row(
        children: [
          Icon(
            Icons.wifi_off_rounded,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

String? _distinctStorySummary(NewsArticle story) {
  final summary = (story.summary ?? '').trim();
  if (summary.isEmpty) {
    return null;
  }
  final normalizedTitle = _normalizeComparisonText(story.title);
  final normalizedSummary = _normalizeComparisonText(summary);
  if (normalizedSummary.isEmpty || normalizedSummary == normalizedTitle) {
    return null;
  }
  if (normalizedSummary.startsWith(normalizedTitle)) {
    final remainder = normalizedSummary
        .substring(normalizedTitle.length)
        .trim();
    if (remainder.isEmpty || remainder.length <= 16) {
      return null;
    }
  }
  return summary;
}

String _normalizeComparisonText(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

class _EditorialChipRow extends StatelessWidget {
  const _EditorialChipRow({
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
  });

  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () => onSelected(null),
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selectedCategory == null
                        ? AppTheme.primary
                        : theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selectedCategory == null
                          ? AppTheme.primary.withValues(alpha: 0.14)
                          : theme.dividerColor.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Text(
                    'All',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: selectedCategory == null
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            ...categories.map((category) {
              final isSelected =
                  category.toLowerCase() == selectedCategory?.toLowerCase();
              final color = categoryColor(category);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => onSelected(category),
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.88)
                          : theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? color.withValues(alpha: 0.14)
                            : theme.dividerColor.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Text(
                      category,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: isSelected
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _SecondaryChipRow extends StatelessWidget {
  const _SecondaryChipRow({
    required this.chips,
    required this.selectedKey,
    required this.onSelected,
  });

  final List<HomepageSecondaryChipFeedModel> chips;
  final String? selectedKey;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(
          alpha: isDark ? 0.72 : 0.92,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppTheme.textPrimary.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Focus rails',
            style: theme.textTheme.labelLarge?.copyWith(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.72)
                  : AppTheme.primary,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: chips
                  .map((chip) {
                    final isSelected = chip.key == selectedKey;
                    final color =
                        _parseColor(chip.colorHex) ?? AppTheme.primary;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: FilterChip(
                        label: Text(chip.label),
                        selected: isSelected,
                        onSelected: (_) => onSelected(chip.key),
                        selectedColor: color.withValues(alpha: 0.14),
                        backgroundColor: theme.colorScheme.surfaceContainerLow,
                        checkmarkColor: color,
                        labelStyle: theme.textTheme.labelLarge?.copyWith(
                          color: isSelected
                              ? color
                              : theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? color.withValues(alpha: 0.4)
                              : theme.dividerColor.withValues(alpha: 0.28),
                        ),
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }

  Color? _parseColor(String? value) {
    if (value == null) {
      return null;
    }
    final cleaned = value.trim().replaceAll('#', '');
    if (cleaned.length != 6) {
      return null;
    }
    final parsed = int.tryParse(cleaned, radix: 16);
    if (parsed == null) {
      return null;
    }
    return Color(0xFF000000 | parsed);
  }
}

class _TopStoriesCarousel extends StatelessWidget {
  const _TopStoriesCarousel({
    required this.stories,
    required this.onStoryTap,
    required this.onSaveTap,
    required this.onShareTap,
    required this.onDiscussTap,
  });

  final List<NewsArticle> stories;
  final ValueChanged<NewsArticle> onStoryTap;
  final ValueChanged<NewsArticle> onSaveTap;
  final ValueChanged<NewsArticle> onShareTap;
  final ValueChanged<NewsArticle> onDiscussTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        return SizedBox(
          height: 520,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: stories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final story = stories[index];
              return SizedBox(
                width: cardWidth,
                child: _FeaturedStoryCard(
                  story: story,
                  onTap: () => onStoryTap(story),
                  onSaveTap: () => onSaveTap(story),
                  onShareTap: () => onShareTap(story),
                  onDiscussTap: () => onDiscussTap(story),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _FeaturedStoryCard extends StatelessWidget {
  const _FeaturedStoryCard({
    required this.story,
    required this.onTap,
    required this.onSaveTap,
    required this.onShareTap,
    required this.onDiscussTap,
  });

  final NewsArticle story;
  final VoidCallback onTap;
  final VoidCallback onSaveTap;
  final VoidCallback onShareTap;
  final VoidCallback onDiscussTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = (story.imageUrl ?? '').trim().isNotEmpty;
    final summary =
        _distinctStorySummary(story) ??
        'Deep reporting, sharp context, and what it means next.';
    final badgeBackground = Colors.black.withValues(alpha: 0.3);
    final badgeBorder = Colors.white.withValues(alpha: 0.14);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: 520,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: hasImage
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF154735), Color(0xFF081E18)],
                ),
          boxShadow: AppTheme.ambientShadow(Theme.of(context).brightness),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage)
              NewsThumbnail(
                imageUrl: story.imageUrl,
                fallbackLabel: story.category,
                alignment: Alignment.topCenter,
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.04),
                    Colors.black.withValues(alpha: 0.14),
                    Colors.black.withValues(alpha: 0.4),
                    Colors.black.withValues(alpha: 0.8),
                  ],
                  stops: const [0.0, 0.34, 0.66, 1.0],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: badgeBackground,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: badgeBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          story.isFactChecked
                              ? Icons.verified_user_rounded
                              : Icons.newspaper_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          story.isFactChecked ? 'Fact-Checked' : story.category,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: Colors.white,
                                letterSpacing: 0.8,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${relativeTimeLabel(story.publishedAt)} | ${story.source}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.78),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          story.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                height: 1.14,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.86),
                                height: 1.4,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _HeroActionButton(
                        icon: Icons.bookmark_border_rounded,
                        label: 'Save',
                        onTap: onSaveTap,
                      ),
                      _HeroActionButton(
                        icon: Icons.forum_outlined,
                        label: 'Discuss',
                        onTap: onDiscussTap,
                      ),
                      _HeroActionButton(
                        icon: Icons.share_outlined,
                        label: 'Share',
                        onTap: onShareTap,
                      ),
                    ],
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

class _HeroActionButton extends StatelessWidget {
  const _HeroActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppTheme.textPrimary),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: AppTheme.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontSize: 24,
            height: 1.08,
          ),
        ),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Text(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _HomeSearchPrompt extends StatelessWidget {
  const _HomeSearchPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(
              alpha: isDark ? 0.94 : 0.98,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : AppTheme.textPrimary.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.82)
                    : AppTheme.primary,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Search stories, topics, people, and places',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.9)
                        : AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditorialStoryCard extends StatelessWidget {
  const _EditorialStoryCard({
    required this.story,
    required this.onTap,
    required this.onSaveTap,
    required this.onShareTap,
    this.onMoreLikeThis,
    this.onHideStory,
    this.onHideSource,
  });
  final NewsArticle story;
  final VoidCallback onTap;
  final VoidCallback onSaveTap;
  final VoidCallback onShareTap;
  final VoidCallback? onMoreLikeThis;
  final VoidCallback? onHideStory;
  final VoidCallback? onHideSource;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasImage = (story.imageUrl ?? '').trim().isNotEmpty;
    final summary = _distinctStorySummary(story);
    final hasFeedbackActions =
        onMoreLikeThis != null || onHideStory != null || onHideSource != null;
    final cardColor = isDark
        ? const Color(0xFF1A1F24)
        : const Color(0xFFF3F1EC);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFDDD7CE);
    final chipBackground = isDark
        ? const Color(0xFF2C333A)
        : const Color(0xFFE6E1D7);
    final chipTextColor = isDark
        ? Colors.white.withValues(alpha: 0.92)
        : const Color(0xFF332D25);
    final secondaryTextColor = isDark
        ? Colors.white.withValues(alpha: 0.8)
        : const Color(0xFF5F584F);
    final summaryTextColor = isDark
        ? Colors.white.withValues(alpha: 0.88)
        : const Color(0xFF4E473F);
    final actionTextColor = isDark
        ? Colors.white.withValues(alpha: 0.82)
        : AppTheme.textPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor),
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
                  height: 220,
                  width: double.infinity,
                  child: NewsThumbnail(
                    imageUrl: story.imageUrl,
                    fallbackLabel: story.category,
                    alignment: Alignment.topCenter,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: chipBackground,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          story.category,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: chipTextColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (hasFeedbackActions)
                        PopupMenuButton<String>(
                          tooltip: 'Personalize feed',
                          icon: Icon(
                            Icons.more_horiz_rounded,
                            color: secondaryTextColor,
                          ),
                          onSelected: (value) {
                            switch (value) {
                              case 'more_like_this':
                                onMoreLikeThis?.call();
                                break;
                              case 'hide_story':
                                onHideStory?.call();
                                break;
                              case 'hide_source':
                                onHideSource?.call();
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            if (onMoreLikeThis != null)
                              const PopupMenuItem<String>(
                                value: 'more_like_this',
                                child: Text('Show more like this'),
                              ),
                            if (onHideStory != null)
                              const PopupMenuItem<String>(
                                value: 'hide_story',
                                child: Text('Not interested'),
                              ),
                            if (onHideSource != null)
                              PopupMenuItem<String>(
                                value: 'hide_source',
                                child: Text('Hide ${story.source}'),
                              ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    story.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 20,
                      height: 1.18,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${story.source} | ${relativeTimeLabel(story.publishedAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: secondaryTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (summary != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      summary,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: summaryTextColor,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _InlineAction(
                        icon: Icons.bookmark_border_rounded,
                        label: 'Save',
                        onTap: onSaveTap,
                      ),
                      const SizedBox(width: 16),
                      _InlineAction(
                        icon: Icons.share_outlined,
                        label: 'Share',
                        onTap: onShareTap,
                      ),
                      if ((story.commentCount ?? 0) > 0) ...[
                        const SizedBox(width: 16),
                        Icon(
                          Icons.forum_outlined,
                          size: 16,
                          color: actionTextColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${story.commentCount}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: actionTextColor,
                          ),
                        ),
                      ],
                    ],
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

class _InlineAction extends StatelessWidget {
  const _InlineAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 17,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.82)
                  : AppTheme.textPrimary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.82)
                    : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
