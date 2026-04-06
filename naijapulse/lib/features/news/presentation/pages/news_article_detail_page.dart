import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:naijapulse/core/di/injection_container.dart';
import 'package:naijapulse/core/error/failures.dart';
import 'package:naijapulse/core/routing/app_router.dart';
import 'package:naijapulse/core/routing/external_link.dart';
import 'package:naijapulse/core/services/article_tts_service.dart';
import 'package:naijapulse/core/theme/theme.dart';
import 'package:naijapulse/core/widgets/app_interactions.dart';
import 'package:naijapulse/core/widgets/news_thumbnail.dart';
import 'package:naijapulse/features/news/data/datasource/remote/news_remote_datasource.dart';
import 'package:naijapulse/features/news/data/models/news_readable_text_model.dart';
import 'package:naijapulse/features/news/domain/entities/news_article.dart';
import 'package:naijapulse/features/news/presentation/bloc/news_bloc.dart';
import 'package:naijapulse/features/news/presentation/helpers/news_engagement_helper.dart';
import 'package:naijapulse/features/news/presentation/widgets/news_time.dart';

class NewsArticleDetailPage extends StatefulWidget {
  const NewsArticleDetailPage({
    required this.articleId,
    this.article,
    super.key,
  });

  final String articleId;
  final NewsArticle? article;

  @override
  State<NewsArticleDetailPage> createState() => _NewsArticleDetailPageState();
}

class _NewsArticleDetailPageState extends State<NewsArticleDetailPage> {
  final NewsRemoteDataSource _remote =
      InjectionContainer.sl<NewsRemoteDataSource>();
  final ArticleTtsService _articleTtsService =
      InjectionContainer.sl<ArticleTtsService>();
  final ScrollController _scrollController = ScrollController();

  NewsArticle? _story;
  bool _loadingFallback = false;
  String? _fallbackError;
  NewsReadableTextModel? _readableText;
  String? _activeReadableArticleId;
  final List<GlobalKey> _paragraphKeys = <GlobalKey>[];
  int _lastAutoScrolledParagraphIndex = -1;

  @override
  void initState() {
    super.initState();
    _articleTtsService.addListener(_handleTtsStateChanged);
    _story = widget.article;
    if (_story == null) {
      _loadFallbackStory();
    }
  }

  @override
  void dispose() {
    _articleTtsService.removeListener(_handleTtsStateChanged);
    _articleTtsService.stop();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleTtsStateChanged() {
    if (!mounted) {
      return;
    }
    final activeParagraphIndex = _articleTtsService.currentParagraphIndex;
    setState(() {});
    if (activeParagraphIndex < 0) {
      _lastAutoScrolledParagraphIndex = -1;
    }
    if (activeParagraphIndex >= 0 &&
        activeParagraphIndex != _lastAutoScrolledParagraphIndex) {
      _lastAutoScrolledParagraphIndex = activeParagraphIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollActiveParagraphIntoView(activeParagraphIndex);
      });
    }
    final errorMessage = _articleTtsService.errorMessage;
    if (errorMessage != null && errorMessage.trim().isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  Future<void> _loadFallbackStory() async {
    setState(() {
      _loadingFallback = true;
      _fallbackError = null;
    });
    try {
      final story = await _remote.fetchStoryById(widget.articleId);
      if (!mounted) {
        return;
      }
      setState(() => _story = story);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _fallbackError = mapFailure(error).message);
    } finally {
      if (mounted) {
        setState(() => _loadingFallback = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NewsBloc, NewsState>(
      builder: (context, state) {
        final story = _story ?? _findStoryById(state, widget.articleId);
        if (_story == null && story != null) {
          _story = story;
        }

        if ((state.status == NewsStatus.loading || _loadingFallback) &&
            story == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (story == null) {
          return _ArticleUnavailableScaffold(
            title: 'Story unavailable',
            message:
                _fallbackError ??
                'We could not find this story in the current feed snapshot. Pull to refresh and try again.',
          );
        }

        final relatedStories = _buildRelatedStories(state, story);
        final bodyParagraphs = _displayParagraphs(story);
        _syncParagraphKeys(bodyParagraphs.length);
        return _ArticleDetailScaffold(
          story: story,
          relatedStories: relatedStories,
          bodyParagraphs: bodyParagraphs,
          ttsState: _articleTtsService.state,
          activeParagraphIndex: _articleTtsService.currentParagraphIndex,
          activeParagraphProgress: _articleTtsService.currentParagraphProgress,
          scrollController: _scrollController,
          paragraphKeys: _paragraphKeys,
          onListen: () => _handleListenPressed(story),
          onOpenRelated: (item) =>
              context.push(AppRouter.newsDetailPath(item.id), extra: item),
        );
      },
    );
  }

  Future<void> _handleListenPressed(NewsArticle story) async {
    switch (_articleTtsService.state) {
      case ArticleTtsPlaybackState.playing:
        await _articleTtsService.pause();
        return;
      case ArticleTtsPlaybackState.paused:
        await _articleTtsService.resume();
        return;
      case ArticleTtsPlaybackState.loading:
        return;
      case ArticleTtsPlaybackState.idle:
      case ArticleTtsPlaybackState.error:
        break;
    }

    try {
      final readable = await _loadReadableText(story);
      final paragraphs = _readableParagraphs(story, readable);
      await _articleTtsService.speakParagraphs(paragraphs);
      if (!mounted) {
        return;
      }
      if (readable.usedFallback) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Using the article summary because full publisher text was limited.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapFailure(error).message)));
    }
  }

  Future<NewsReadableTextModel> _loadReadableText(NewsArticle story) async {
    if (_readableText != null && _activeReadableArticleId == story.id) {
      return _readableText!;
    }
    final readable = await _remote.fetchReadableText(story.id);
    if (mounted) {
      setState(() {
        _readableText = readable;
        _activeReadableArticleId = story.id;
      });
    } else {
      _readableText = readable;
      _activeReadableArticleId = story.id;
    }
    return readable;
  }

  List<String> _displayParagraphs(NewsArticle story) {
    if (_readableText != null && _activeReadableArticleId == story.id) {
      final readableParagraphs = _readableParagraphs(story, _readableText!);
      if (readableParagraphs.isNotEmpty) {
        return readableParagraphs;
      }
    }
    return _fallbackBodyParagraphs(story);
  }

  List<String> _readableParagraphs(
    NewsArticle story,
    NewsReadableTextModel readable,
  ) {
    final rawParagraphs = readable.text
        .split(RegExp(r'\n\s*\n'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (rawParagraphs.isEmpty) {
      return _fallbackBodyParagraphs(story);
    }

    final normalizedTitle = story.title.trim().toLowerCase();
    final normalizedSource = story.source.trim().toLowerCase();
    final filtered = rawParagraphs.where((paragraph) {
      final normalized = paragraph.trim().toLowerCase();
      if (normalized.isEmpty) {
        return false;
      }
      if (normalized == normalizedTitle || normalized == normalizedSource) {
        return false;
      }
      if (normalized.length < 24 &&
          (normalized.contains(normalizedTitle) ||
              normalized.contains(normalizedSource))) {
        return false;
      }
      return true;
    }).toList();

    return filtered.isEmpty ? _fallbackBodyParagraphs(story) : filtered;
  }

  List<String> _fallbackBodyParagraphs(NewsArticle story) {
    final text = [
      _displaySummary(story),
      if ((story.reviewNotes ?? '').trim().isNotEmpty)
        story.reviewNotes!.trim(),
    ].whereType<String>().where((item) => item.isNotEmpty).join(' ');

    if (text.isEmpty) {
      return [
        'This article is available from ${story.source}. Use the source actions below to read the full report and join the discussion around it.',
      ];
    }

    final sentences = text
        .replaceAll(RegExp(r'\s+'), ' ')
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (sentences.isEmpty) {
      return [text];
    }

    final paragraphs = <String>[];
    for (var i = 0; i < sentences.length; i += 2) {
      final chunk = sentences.skip(i).take(2).join(' ');
      paragraphs.add(chunk);
    }
    return paragraphs;
  }

  String? _displaySummary(NewsArticle story) {
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

  void _syncParagraphKeys(int paragraphCount) {
    if (_paragraphKeys.length == paragraphCount) {
      return;
    }
    if (_paragraphKeys.length < paragraphCount) {
      _paragraphKeys.addAll(
        List<GlobalKey>.generate(
          paragraphCount - _paragraphKeys.length,
          (_) => GlobalKey(),
        ),
      );
    } else {
      _paragraphKeys.removeRange(paragraphCount, _paragraphKeys.length);
    }
    if (_lastAutoScrolledParagraphIndex >= paragraphCount) {
      _lastAutoScrolledParagraphIndex = -1;
    }
  }

  void _scrollActiveParagraphIntoView(int paragraphIndex) {
    if (!mounted ||
        !_scrollController.hasClients ||
        paragraphIndex < 0 ||
        paragraphIndex >= _paragraphKeys.length) {
      return;
    }
    final paragraphContext = _paragraphKeys[paragraphIndex].currentContext;
    if (paragraphContext == null) {
      return;
    }
    Scrollable.ensureVisible(
      paragraphContext,
      alignment: 0.18,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  NewsArticle? _findStoryById(NewsState state, String id) {
    final all = [...state.topStories, ...state.latestStories];
    for (final item in all) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  List<NewsArticle> _buildRelatedStories(NewsState state, NewsArticle story) {
    final all = [...state.topStories, ...state.latestStories];
    final seenIds = <String>{story.id};
    final deduped = <NewsArticle>[];
    for (final item in all) {
      if (seenIds.add(item.id)) {
        deduped.add(item);
      }
    }

    final ranked =
        deduped.map((item) {
          final sameCategory =
              item.category.trim().toLowerCase() ==
              story.category.trim().toLowerCase();
          final sameSource =
              item.source.trim().toLowerCase() ==
              story.source.trim().toLowerCase();
          final sharedTags = _sharedTagCount(story, item);
          final score =
              (sharedTags * 10) + (sameCategory ? 3 : 0) + (sameSource ? 1 : 0);
          return (story: item, score: score);
        }).toList()..sort((a, b) {
          final byScore = b.score.compareTo(a.score);
          if (byScore != 0) {
            return byScore;
          }
          return b.story.publishedAt.compareTo(a.story.publishedAt);
        });

    return ranked.take(4).map((entry) => entry.story).toList(growable: false);
  }

  int _sharedTagCount(NewsArticle left, NewsArticle right) {
    final leftTags = left.tags
        .map((tag) => tag.trim().toLowerCase())
        .where((tag) => tag.isNotEmpty)
        .toSet();
    final rightTags = right.tags
        .map((tag) => tag.trim().toLowerCase())
        .where((tag) => tag.isNotEmpty)
        .toSet();
    return leftTags.intersection(rightTags).length;
  }
}

class _ArticleDetailScaffold extends StatelessWidget {
  const _ArticleDetailScaffold({
    required this.story,
    required this.relatedStories,
    required this.bodyParagraphs,
    required this.ttsState,
    required this.activeParagraphIndex,
    required this.activeParagraphProgress,
    required this.scrollController,
    required this.paragraphKeys,
    required this.onListen,
    required this.onOpenRelated,
  });

  final NewsArticle story;
  final List<NewsArticle> relatedStories;
  final List<String> bodyParagraphs;
  final ArticleTtsPlaybackState ttsState;
  final int activeParagraphIndex;
  final double activeParagraphProgress;
  final ScrollController scrollController;
  final List<GlobalKey> paragraphKeys;
  final VoidCallback onListen;
  final ValueChanged<NewsArticle> onOpenRelated;

  @override
  Widget build(BuildContext context) {
    final sourceUrl = story.articleUrl?.trim();
    final uri = sourceUrl == null || sourceUrl.isEmpty
        ? null
        : Uri.tryParse(sourceUrl);
    final hasValidSource = uri != null && uri.hasScheme && uri.host.isNotEmpty;
    final glanceBullets = _atAGlanceBullets(story);
    final showAtAGlance = _shouldShowAtAGlance(glanceBullets, bodyParagraphs);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final contentSurface = isDark ? AppTheme.darkSurface : Colors.white;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        leading: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: AppIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            semanticLabel: 'Go back',
            style: AppIconButtonStyle.contrast,
            onPressed: () {
              if (context.canPop()) {
                context.pop();
                return;
              }
              context.go(AppRouter.homePath);
            },
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: AppIconButton(
              icon: Icons.open_in_new_rounded,
              tooltip: 'Open source',
              semanticLabel: 'Open source article',
              style: AppIconButtonStyle.contrast,
              onPressed: hasValidSource
                  ? () => _openSource(context, uri)
                  : null,
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.45),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push(
                    AppRouter.articleDiscussionPath(story.id),
                    extra: story,
                  ),
                  icon: const Icon(Icons.forum_outlined),
                  label: Text('Discuss ${story.commentCount ?? 0}'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      NewsEngagementHelper.shareArticle(context, story),
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Share'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: hasValidSource
                      ? () => _openSource(context, uri)
                      : null,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Read full'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverToBoxAdapter(child: _ArticleHero(story: story)),
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                color: contentSurface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(34),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MetadataRow(story: story),
                    const SizedBox(height: 16),
                    _ActionPills(
                      onSave: () =>
                          NewsEngagementHelper.saveArticle(context, story),
                      onListen: onListen,
                      listenLabel: _listenLabel(ttsState),
                      onDiscuss: () => context.push(
                        AppRouter.articleDiscussionPath(story.id),
                        extra: story,
                      ),
                      onOpenSource: hasValidSource
                          ? () => _openSource(context, uri)
                          : null,
                    ),
                    if (showAtAGlance) ...[
                      const SizedBox(height: 18),
                      _AtAGlanceCard(items: glanceBullets),
                    ],
                    const SizedBox(height: 22),
                    Text(
                      'Story',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...bodyParagraphs.asMap().entries.map(
                      (entry) => Padding(
                        key: paragraphKeys[entry.key],
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _StoryParagraphCard(
                          paragraph: entry.value,
                          isActive:
                              entry.key == activeParagraphIndex &&
                              (ttsState == ArticleTtsPlaybackState.playing ||
                                  ttsState == ArticleTtsPlaybackState.loading ||
                                  ttsState == ArticleTtsPlaybackState.paused),
                          progress: entry.key == activeParagraphIndex
                              ? activeParagraphProgress
                              : 0,
                        ),
                      ),
                    ),
                    if ((story.reviewNotes ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _QuoteCard(quote: story.reviewNotes!.trim()),
                    ],
                    const SizedBox(height: 26),
                    Text(
                      'Related stories',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (relatedStories.isEmpty)
                      Text(
                        'More related coverage will appear here as the feed updates.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      )
                    else
                      ...relatedStories.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _RelatedStoryCard(
                            story: item,
                            onTap: () => onOpenRelated(item),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _listenLabel(ArticleTtsPlaybackState state) {
    switch (state) {
      case ArticleTtsPlaybackState.loading:
        return 'Preparing...';
      case ArticleTtsPlaybackState.playing:
        return 'Pause';
      case ArticleTtsPlaybackState.paused:
        return 'Restart';
      case ArticleTtsPlaybackState.idle:
      case ArticleTtsPlaybackState.error:
        return 'Listen';
    }
  }

  Future<void> _openSource(BuildContext context, Uri uri) async {
    if (kIsWeb) {
      await openExternalLink(uri.toString());
      return;
    }
    if (!context.mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ArticleSourceWebViewPage(story: story, uri: uri),
      ),
    );
  }

  List<String> _atAGlanceBullets(NewsArticle story) {
    final summary = _displaySummary(story) ?? '';
    if (summary.isEmpty) {
      return [];
    }
    final sentences = summary
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    return sentences.take(3).toList();
  }

  String? _displaySummary(NewsArticle story) {
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

  bool _shouldShowAtAGlance(List<String> bullets, List<String> paragraphs) {
    if (bullets.isEmpty) {
      return false;
    }
    if (paragraphs.isEmpty) {
      return true;
    }
    final normalizedBody = paragraphs
        .map(_normalizeComparisonText)
        .where((item) => item.isNotEmpty)
        .join(' ');
    if (normalizedBody.isEmpty) {
      return true;
    }
    for (final bullet in bullets) {
      final normalizedBullet = _normalizeComparisonText(bullet);
      if (normalizedBullet.isEmpty) {
        continue;
      }
      if (!normalizedBody.contains(normalizedBullet)) {
        return true;
      }
    }
    return false;
  }
}

class _ArticleHero extends StatelessWidget {
  const _ArticleHero({required this.story});

  final NewsArticle story;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          height: 380,
          width: double.infinity,
          child: story.imageUrl != null && story.imageUrl!.trim().isNotEmpty
              ? NewsThumbnail(
                  imageUrl: story.imageUrl,
                  fallbackLabel: story.category,
                )
              : DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primary.withValues(alpha: 0.98),
                        AppTheme.primaryContainer,
                      ],
                    ),
                  ),
                ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.08),
                  Colors.black.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.74),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 36,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.breaking,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  story.category.toUpperCase(),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                story.title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontFamily: AppTheme.headlineFontFamily,
                  height: 1.08,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.story});

  final NewsArticle story;

  @override
  Widget build(BuildContext context) {
    final verified =
        story.isFactChecked ||
        story.verificationStatus.trim().toLowerCase() == 'fact_checked' ||
        story.verificationStatus.trim().toLowerCase() == 'verified';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
              child: Text(
                story.source.trim().isNotEmpty
                    ? story.source.trim().characters.first.toUpperCase()
                    : 'N',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  Text(
                    story.source,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '- ${relativeTimeLabel(story.publishedAt)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (verified)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.primary.withValues(alpha: 0.2)
                      : const Color(0xFFEAF4EE),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Fact-Checked',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
        if (story.tags.isNotEmpty) ...[
          const SizedBox(height: 12),
          _StoryTagWrap(tags: story.tags),
        ],
      ],
    );
  }
}

class _StoryTagWrap extends StatelessWidget {
  const _StoryTagWrap({required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final visibleTags = tags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .take(8)
        .toList(growable: false);
    if (visibleTags.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: visibleTags
          .map(
            (tag) => AppActionChip(
              label: tag,
              compact: true,
              selected: true,
              selectedColor: isDark
                  ? AppTheme.darkSurfaceMuted
                  : const Color(0xFFF6F7F8),
              selectedForegroundColor: isDark
                  ? AppTheme.darkTextPrimary
                  : AppTheme.textPrimary,
            ),
          )
          .toList(growable: false),
    );
  }
}

class _ActionPills extends StatelessWidget {
  const _ActionPills({
    required this.onSave,
    required this.onListen,
    required this.listenLabel,
    required this.onDiscuss,
    this.onOpenSource,
  });

  final VoidCallback onSave;
  final VoidCallback onListen;
  final String listenLabel;
  final VoidCallback onDiscuss;
  final VoidCallback? onOpenSource;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedBackground = isDark
        ? AppTheme.darkSurfaceMuted
        : const Color(0xFFF3F4F6);
    final mutedForeground = isDark
        ? AppTheme.darkTextPrimary
        : AppTheme.textPrimary;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        AppActionChip(
          icon: Icons.bookmark_border_rounded,
          label: 'Save',
          selected: true,
          selectedColor: mutedBackground,
          selectedForegroundColor: mutedForeground,
          onTap: onSave,
        ),
        AppActionChip(
          icon: Icons.forum_outlined,
          label: 'Discuss',
          selected: true,
          selectedColor: mutedBackground,
          selectedForegroundColor: mutedForeground,
          onTap: onDiscuss,
        ),
        AppActionChip(
          icon: Icons.volume_up_rounded,
          label: listenLabel,
          selected: true,
          selectedColor: AppTheme.primary.withValues(alpha: 0.14),
          selectedForegroundColor: AppTheme.primary,
          onTap: onListen,
        ),
        AppActionChip(
          icon: Icons.open_in_new_rounded,
          label: 'Open Source',
          selected: true,
          selectedColor: AppTheme.primary,
          selectedForegroundColor: Colors.white,
          onTap: onOpenSource,
        ),
      ],
    );
  }
}

class _AtAGlanceCard extends StatelessWidget {
  const _AtAGlanceCard({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bodyColor = isDark
        ? AppTheme.darkTextSecondary
        : AppTheme.textPrimary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceMuted : const Color(0xFFF7FAF8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppTheme.darkDivider : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'At a Glance',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Icon(Icons.circle, size: 8, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: bodyColor,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.quote});

  final String quote;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceMuted : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppTheme.darkDivider : const Color(0xFFE5E7EB),
        ),
      ),
      child: Text(
        '"$quote"',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppTheme.primary,
          fontWeight: FontWeight.w700,
          fontFamily: AppTheme.headlineFontFamily,
          height: 1.45,
        ),
      ),
    );
  }
}

class _StoryParagraphCard extends StatelessWidget {
  const _StoryParagraphCard({
    required this.paragraph,
    required this.isActive,
    required this.progress,
  });

  final String paragraph;
  final bool isActive;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paragraphColor = isDark
        ? AppTheme.darkTextSecondary
        : AppTheme.textPrimary;
    final backgroundColor = isActive
        ? AppTheme.primary.withValues(alpha: isDark ? 0.18 : 0.08)
        : Colors.transparent;
    final borderColor = isActive
        ? AppTheme.primary.withValues(alpha: 0.5)
        : Colors.transparent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isActive) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress.clamp(0, 1),
                minHeight: 5,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.16),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Text(
            paragraph,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              height: 1.65,
              color: paragraphColor,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _RelatedStoryCard extends StatelessWidget {
  const _RelatedStoryCard({required this.story, required this.onTap});

  final NewsArticle story;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? AppTheme.darkDivider : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 90,
                height: 70,
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${story.category} - ${relativeTimeLabel(story.publishedAt)}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppTheme.textMeta),
                  ),
                  if (story.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _StoryTagWrap(tags: story.tags.take(3).toList()),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            const AppIcon(
              Icons.chevron_right_rounded,
              size: AppIconSize.small,
              tone: AppIconTone.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _ArticleSourceWebViewPage extends StatefulWidget {
  const _ArticleSourceWebViewPage({required this.story, required this.uri});

  final NewsArticle story;
  final Uri uri;

  @override
  State<_ArticleSourceWebViewPage> createState() =>
      _ArticleSourceWebViewPageState();
}

class _ArticleSourceWebViewPageState extends State<_ArticleSourceWebViewPage> {
  late final WebViewController _controller;
  int _progress = 0;
  String? _errorMessage;
  bool _didFinishMainPageLoad = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) {
              return;
            }
            setState(() => _progress = progress);
          },
          onPageStarted: (_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _didFinishMainPageLoad = false;
              _errorMessage = null;
              _progress = 0;
            });
          },
          onPageFinished: (_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _didFinishMainPageLoad = true;
              _progress = 100;
            });
          },
          onWebResourceError: (error) {
            if (!mounted) {
              return;
            }
            final dynamic details = error;
            bool isMainFrame = false;
            try {
              isMainFrame = details.isForMainFrame == true;
            } catch (_) {
              isMainFrame = !_didFinishMainPageLoad;
            }
            if (!isMainFrame && _didFinishMainPageLoad) {
              return;
            }
            setState(() {
              _errorMessage =
                  'We could not load this publisher page right now. Try again in a moment.';
            });
          },
        ),
      )
      ..loadRequest(widget.uri);
  }

  String? _displaySummary(NewsArticle story) {
    final summary = (story.summary ?? '').trim();
    if (summary.isEmpty) {
      return null;
    }
    final normalizedTitle = story.title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final normalizedSummary = summary
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.story.source,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: _progress < 100
              ? LinearProgressIndicator(value: _progress / 100)
              : const SizedBox.shrink(),
        ),
        actions: [
          AppIconButton(
            icon: Icons.forum_outlined,
            onPressed: () => context.push(
              AppRouter.articleDiscussionPath(widget.story.id),
              extra: widget.story,
            ),
            tooltip: 'Discussion',
            semanticLabel: 'Open discussion',
            style: AppIconButtonStyle.tonal,
          ),
          AppIconButton(
            icon: Icons.refresh_rounded,
            onPressed: () {
              setState(() {
                _errorMessage = null;
                _progress = 0;
              });
              _controller.loadRequest(widget.uri);
            },
            tooltip: 'Reload',
            semanticLabel: 'Reload article source',
            style: AppIconButtonStyle.tonal,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.story.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (_displaySummary(widget.story)?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 6),
                  Text(
                    _displaySummary(widget.story)!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _errorMessage != null
                ? _ArticleUnavailableView(
                    message: _errorMessage!,
                    actionLabel: 'Open in browser',
                    onActionTap: () => openExternalLink(widget.uri.toString()),
                  )
                : WebViewWidget(controller: _controller),
          ),
        ],
      ),
    );
  }
}

class _ArticleUnavailableScaffold extends StatelessWidget {
  const _ArticleUnavailableScaffold({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _ArticleUnavailableView(message: message),
    );
  }
}

class _ArticleUnavailableView extends StatelessWidget {
  const _ArticleUnavailableView({
    required this.message,
    this.actionLabel,
    this.onActionTap,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (actionLabel != null && onActionTap != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onActionTap, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
