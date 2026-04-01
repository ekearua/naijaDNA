import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:naijapulse/core/di/injection_container.dart';
import 'package:naijapulse/core/error/failures.dart';
import 'package:naijapulse/core/routing/app_router.dart';
import 'package:naijapulse/features/auth/domain/entities/auth_session.dart';
import 'package:naijapulse/features/auth/domain/usecases/get_cached_session.dart';
import 'package:naijapulse/features/news/data/datasource/remote/news_remote_datasource.dart';
import 'package:naijapulse/features/news/domain/entities/article_comment.dart';
import 'package:naijapulse/features/news/domain/entities/news_article.dart';
import 'package:naijapulse/features/news/presentation/widgets/news_time.dart';

class ArticleDiscussionPage extends StatefulWidget {
  const ArticleDiscussionPage({
    required this.articleId,
    this.article,
    this.focusCommentId,
    super.key,
  });

  final String articleId;
  final NewsArticle? article;
  final int? focusCommentId;

  @override
  State<ArticleDiscussionPage> createState() => _ArticleDiscussionPageState();
}

class _ArticleDiscussionPageState extends State<ArticleDiscussionPage> {
  final NewsRemoteDataSource _remote =
      InjectionContainer.sl<NewsRemoteDataSource>();
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _commentKeys = <int, GlobalKey>{};

  NewsArticle? _article;
  List<ArticleComment> _comments = const <ArticleComment>[];
  AuthSession? _session;
  ArticleComment? _replyTarget;
  bool _loading = true;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _article = widget.article;
    _bootstrap();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _loadSession();
    await _loadDiscussion();
  }

  Future<void> _loadSession() async {
    try {
      _session = await InjectionContainer.sl<GetCachedSession>()();
    } catch (_) {
      _session = null;
    }
  }

  Future<void> _loadDiscussion() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final article =
          _article ?? await _remote.fetchStoryById(widget.articleId);
      final comments = await _remote.fetchArticleComments(widget.articleId);
      if (!mounted) {
        return;
      }
      setState(() {
        _article = article;
        _comments = comments;
      });
      _scrollToFocusedComment();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = mapFailure(error).message);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _scrollToFocusedComment() {
    final focusCommentId = widget.focusCommentId;
    if (focusCommentId == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      final context = _commentKeys[focusCommentId]?.currentContext;
      if (context == null) {
        return;
      }
      await Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 350),
        alignment: 0.15,
        curve: Curves.easeOutCubic,
      );
    });
  }

  GlobalKey _keyForComment(int commentId) {
    return _commentKeys.putIfAbsent(commentId, () => GlobalKey());
  }

  Future<void> _ensureSignedIn() async {
    if (_session != null) {
      return;
    }
    await context.push(AppRouter.loginPath);
    await _loadSession();
  }

  Future<void> _submitComment() async {
    await _ensureSignedIn();
    if (_session == null || _submitting) {
      return;
    }
    final body = _commentController.text.trim();
    if (body.isEmpty) {
      return;
    }

    setState(() => _submitting = true);
    try {
      if (_replyTarget == null) {
        await _remote.createArticleComment(
          articleId: widget.articleId,
          body: body,
        );
      } else {
        await _remote.replyToComment(commentId: _replyTarget!.id, body: body);
      }
      _commentController.clear();
      if (!mounted) {
        return;
      }
      setState(() => _replyTarget = null);
      await _loadDiscussion();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapFailure(error).message)));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _toggleLike(ArticleComment comment) async {
    await _ensureSignedIn();
    if (_session == null) {
      return;
    }
    try {
      final result = await _remote.toggleCommentLike(commentId: comment.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _comments = _updateCommentTree(
          _comments,
          comment.id,
          (target) => target.copyWith(
            likeCount: result.likeCount,
            viewerHasLiked: result.liked,
          ),
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapFailure(error).message)));
    }
  }

  Future<void> _reportComment(ArticleComment comment) async {
    await _ensureSignedIn();
    if (_session == null || comment.viewerHasReported) {
      return;
    }
    try {
      await _remote.reportComment(commentId: comment.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _comments = _updateCommentTree(
          _comments,
          comment.id,
          (target) => target.copyWith(
            viewerHasReported: true,
            reportCount: target.reportCount + 1,
          ),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment reported for review.')),
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

  Future<void> _moderateComment(ArticleComment comment, String action) async {
    if (!(_session?.canModerateDiscussions ?? false)) {
      return;
    }
    try {
      final updated = await _remote.moderateComment(
        commentId: comment.id,
        action: action,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _comments = _updateCommentTree(_comments, comment.id, (_) => updated);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_moderationSuccessLabel(action))));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapFailure(error).message)));
    }
  }

  List<ArticleComment> _updateCommentTree(
    List<ArticleComment> items,
    int commentId,
    ArticleComment Function(ArticleComment target) transform,
  ) {
    return items.map((item) {
      if (item.id == commentId) {
        return transform(item);
      }
      if (item.replies.isEmpty) {
        return item;
      }
      final updatedReplies = _updateCommentTree(
        item.replies,
        commentId,
        transform,
      );
      if (updatedReplies == item.replies) {
        return item;
      }
      return item.copyWith(replies: updatedReplies);
    }).toList();
  }

  String _moderationSuccessLabel(String action) {
    switch (action) {
      case 'remove':
        return 'Comment removed.';
      case 'restore':
        return 'Comment restored.';
      case 'dismiss_reports':
        return 'Reports dismissed and comment restored.';
      default:
        return 'Comment updated.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final article = _article;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discussion'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadDiscussion,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          if (article != null) _ArticleSummaryCard(article: article),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  )
                : _comments.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No comments yet. Start the conversation.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  )
                : ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    itemCount: _comments.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final comment = _comments[index];
                      return _CommentThreadCard(
                        highlightedCommentId: widget.focusCommentId,
                        keyForComment: _keyForComment,
                        comment: comment,
                        canModerate:
                            _session?.canModerateDiscussions ?? false,
                        onReply: comment.isRemoved
                            ? null
                            : () => setState(() => _replyTarget = comment),
                        onLike: comment.isRemoved
                            ? null
                            : () => _toggleLike(comment),
                        onReport: comment.isRemoved || comment.viewerHasReported
                            ? null
                            : () => _reportComment(comment),
                        onModerate: (action) =>
                            _moderateComment(comment, action),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(
                      context,
                    ).dividerColor.withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_replyTarget != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Replying to ${_replyTarget!.authorName}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                setState(() => _replyTarget = null),
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          minLines: 1,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: _session == null
                                ? 'Sign in to join the discussion'
                                : _replyTarget == null
                                ? 'Write a comment...'
                                : 'Write a reply...',
                          ),
                          onTap: _ensureSignedIn,
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: _submitting ? null : _submitComment,
                        child: _submitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Send'),
                      ),
                    ],
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

class _ArticleSummaryCard extends StatelessWidget {
  const _ArticleSummaryCard({required this.article});

  final NewsArticle article;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            article.title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '${article.source} - ${relativeTimeLabel(article.publishedAt)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if ((article.summary ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              article.summary!.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => context.push(
              AppRouter.newsDetailPath(article.id),
              extra: article,
            ),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Open story'),
          ),
        ],
      ),
    );
  }
}

class _CommentThreadCard extends StatelessWidget {
  const _CommentThreadCard({
    required this.comment,
    required this.onReply,
    required this.onLike,
    required this.onReport,
    required this.onModerate,
    required this.canModerate,
    required this.keyForComment,
    this.highlightedCommentId,
  });

  final ArticleComment comment;
  final VoidCallback? onReply;
  final VoidCallback? onLike;
  final VoidCallback? onReport;
  final ValueChanged<String> onModerate;
  final bool canModerate;
  final GlobalKey Function(int commentId) keyForComment;
  final int? highlightedCommentId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      key: keyForComment(comment.id),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlightedCommentId == comment.id
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.48)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlightedCommentId == comment.id
              ? theme.colorScheme.primary.withValues(alpha: 0.45)
              : theme.colorScheme.outline.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CommentBody(
            comment: comment,
            onReply: onReply,
            onLike: onLike,
            onReport: onReport,
            onModerate: canModerate ? onModerate : null,
          ),
          for (final reply in comment.replies) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Container(
                key: keyForComment(reply.id),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: highlightedCommentId == reply.id
                      ? theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.42,
                        )
                      : theme.colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.35,
                        ),
                  borderRadius: BorderRadius.circular(14),
                  border: highlightedCommentId == reply.id
                      ? Border.all(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.4,
                          ),
                        )
                      : null,
                ),
                child: _CommentBody(comment: reply),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CommentBody extends StatelessWidget {
  const _CommentBody({
    required this.comment,
    this.onReply,
    this.onLike,
    this.onReport,
    this.onModerate,
  });

  final ArticleComment comment;
  final VoidCallback? onReply;
  final VoidCallback? onLike;
  final VoidCallback? onReport;
  final ValueChanged<String>? onModerate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                comment.authorName,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              relativeTimeLabel(comment.createdAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          comment.body,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontStyle: comment.isRemoved ? FontStyle.italic : FontStyle.normal,
          ),
        ),
        if (onLike != null ||
            onReply != null ||
            onReport != null ||
            onModerate != null) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (onLike != null)
                TextButton.icon(
                  onPressed: onLike,
                  icon: Icon(
                    comment.viewerHasLiked
                        ? Icons.thumb_up_rounded
                        : Icons.thumb_up_outlined,
                  ),
                  label: Text(
                    comment.likeCount > 0 ? '${comment.likeCount}' : 'Like',
                  ),
                ),
              if (onReply != null)
                TextButton.icon(
                  onPressed: onReply,
                  icon: const Icon(Icons.reply_rounded),
                  label: const Text('Reply'),
                ),
              if (onReport != null)
                TextButton.icon(
                  onPressed: onReport,
                  icon: Icon(
                    comment.viewerHasReported
                        ? Icons.flag_rounded
                        : Icons.outlined_flag_rounded,
                  ),
                  label: Text(
                    comment.viewerHasReported ? 'Reported' : 'Report',
                  ),
                ),
              if (comment.reportCount > 0)
                Text(
                  '${comment.reportCount} report${comment.reportCount == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (onModerate != null)
                PopupMenuButton<String>(
                  tooltip: 'Moderate comment',
                  onSelected: onModerate,
                  itemBuilder: (context) => [
                    if (!comment.isRemoved)
                      const PopupMenuItem<String>(
                        value: 'remove',
                        child: Text('Remove comment'),
                      ),
                    if (comment.isRemoved)
                      const PopupMenuItem<String>(
                        value: 'restore',
                        child: Text('Restore comment'),
                      ),
                    if (!comment.isRemoved)
                      const PopupMenuItem<String>(
                        value: 'dismiss_reports',
                        child: Text('Dismiss reports'),
                      ),
                  ],
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Icon(Icons.shield_outlined, size: 18),
                  ),
                ),
            ],
          ),
        ],
        if (comment.moderationReason?.trim().isNotEmpty ?? false) ...[
          const SizedBox(height: 8),
          Text(
            comment.moderationReason!.trim(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.72),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }
}
