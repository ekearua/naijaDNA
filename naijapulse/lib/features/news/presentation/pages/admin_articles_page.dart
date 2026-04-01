import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:naijapulse/core/di/injection_container.dart';
import 'package:naijapulse/core/error/failures.dart';
import 'package:naijapulse/core/routing/app_router.dart';
import 'package:naijapulse/features/auth/data/auth_session_controller.dart';
import 'package:naijapulse/features/auth/domain/entities/auth_session.dart';
import 'package:naijapulse/features/auth/domain/usecases/get_cached_session.dart';
import 'package:naijapulse/features/news/data/datasource/remote/news_remote_datasource.dart';
import 'package:naijapulse/features/news/domain/entities/news_article.dart';
import 'package:naijapulse/features/news/domain/entities/reported_comment.dart';

class AdminArticlesPage extends StatefulWidget {
  const AdminArticlesPage({super.key});

  @override
  State<AdminArticlesPage> createState() => _AdminArticlesPageState();
}

class _AdminArticlesPageState extends State<AdminArticlesPage> {
  static const List<String> _statusFilters = <String>[
    'all',
    'draft',
    'submitted',
    'approved',
    'published',
    'rejected',
    'archived',
  ];

  final NewsRemoteDataSource _remote =
      InjectionContainer.sl<NewsRemoteDataSource>();
  late final AuthSessionController _authSessionController;

  AuthSession? _authSession;
  List<NewsArticle> _articles = const <NewsArticle>[];
  List<ReportedComment> _reportedComments = const <ReportedComment>[];
  String _selectedStatus = 'all';
  bool _loadingSession = true;
  bool _loadingArticles = false;
  bool _loadingReportedComments = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _authSessionController = InjectionContainer.sl<AuthSessionController>();
    _authSessionController.addListener(_handleAuthChanged);
    _loadSession();
  }

  @override
  void dispose() {
    _authSessionController.removeListener(_handleAuthChanged);
    super.dispose();
  }

  Future<void> _handleAuthChanged() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _authSession = _authSessionController.session;
      _loadingSession = false;
    });
    if (_authSession?.canManageEditorialContent ?? false) {
      await Future.wait([_loadArticles(), _loadReportedComments()]);
    }
  }

  Future<void> _loadSession() async {
    AuthSession? session;
    try {
      session = await InjectionContainer.sl<GetCachedSession>()();
    } catch (_) {
      session = null;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _authSession = session ?? _authSessionController.session;
      _loadingSession = false;
    });
    if (_authSession?.canManageEditorialContent ?? false) {
      await Future.wait([_loadArticles(), _loadReportedComments()]);
    }
  }

  Future<void> _loadArticles() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _loadingArticles = true;
      _errorMessage = null;
    });
    try {
      final items = await _remote.fetchAdminArticles(
        status: _selectedStatus == 'all' ? null : _selectedStatus,
      );
      if (!mounted) {
        return;
      }
      setState(() => _articles = items);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = mapFailure(error).message);
    } finally {
      if (mounted) {
        setState(() => _loadingArticles = false);
      }
    }
  }

  Future<void> _loadReportedComments() async {
    if (!mounted) {
      return;
    }
    setState(() => _loadingReportedComments = true);
    try {
      final items = await _remote.fetchReportedComments();
      if (!mounted) {
        return;
      }
      setState(() => _reportedComments = items);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _reportedComments = const <ReportedComment>[]);
    } finally {
      if (mounted) {
        setState(() => _loadingReportedComments = false);
      }
    }
  }

  Future<void> _openCreateArticle() async {
    final result = await context.push(AppRouter.newsSubmitPath);
    if (result == true) {
      await _loadArticles();
    }
  }

  Future<void> _runWorkflowAction(NewsArticle article, String action) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updated = await _remote.transitionAdminArticle(
        articleId: article.id,
        action: action,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        final index = _articles.indexWhere((item) => item.id == article.id);
        if (index >= 0) {
          final next = List<NewsArticle>.from(_articles);
          if (_selectedStatus != 'all' && updated.status != _selectedStatus) {
            next.removeAt(index);
          } else {
            next[index] = updated;
          }
          _articles = next;
        }
      });
      messenger.showSnackBar(SnackBar(content: Text(_successMessage(action))));
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(mapFailure(error).message)),
      );
    }
  }

  Future<void> _runModerationAction(
    ReportedComment comment,
    String action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updated = await _remote.moderateComment(
        commentId: comment.id,
        action: action,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        if (action == 'dismiss_reports') {
          _reportedComments = _reportedComments
              .where((item) => item.id != comment.id)
              .toList();
          return;
        }
        _reportedComments = _reportedComments
            .map(
              (item) => item.id == comment.id
                  ? ReportedComment(
                      id: item.id,
                      articleId: item.articleId,
                      articleTitle: item.articleTitle,
                      authorName: item.authorName,
                      body: updated.body,
                      status: updated.status,
                      reportCount: item.reportCount,
                      likeCount: updated.likeCount,
                      replyCount: updated.replyCount,
                      createdAt: item.createdAt,
                      updatedAt: updated.updatedAt,
                      moderationReason: updated.moderationReason,
                    )
                  : item,
            )
            .toList();
      });
      messenger.showSnackBar(
        SnackBar(content: Text(_moderationSuccessMessage(action))),
      );
      if (action != 'remove') {
        await _loadReportedComments();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(mapFailure(error).message)),
      );
    }
  }

  Future<void> _openDiscussion(ReportedComment comment) async {
    await context.push(
      AppRouter.articleDiscussionPath(comment.articleId, commentId: comment.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingSession) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!(_authSession?.canManageEditorialContent ?? false)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Editorial Desk')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 42,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 14),
                Text(
                  'Editorial access is limited to admin and editor accounts.',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Once your account is promoted, drafts and publication controls will appear here.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editorial Desk'),
        actions: [
          IconButton(
            tooltip: 'New article',
            onPressed: _openCreateArticle,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([_loadArticles(), _loadReportedComments()]);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(
              'Manage drafts, reviews, and publication state from one queue.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _statusFilters.map((status) {
                  final selected = _selectedStatus == status;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_statusLabel(status)),
                      selected: selected,
                      onSelected: (_) {
                        if (_selectedStatus == status) {
                          return;
                        }
                        setState(() => _selectedStatus = status);
                        _loadArticles();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            if (_loadingArticles)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              _MessageState(
                title: 'Could not load the editorial queue',
                message: _errorMessage!,
                actionLabel: 'Try again',
                onPressed: _loadArticles,
              )
            else if (_articles.isEmpty)
              _MessageState(
                title: 'No articles in this queue',
                message:
                    'Use the new article action to create a draft or publish directly.',
                actionLabel: 'Create article',
                onPressed: _openCreateArticle,
              )
            else
              ..._articles.map(
                (article) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AdminArticleCard(
                    article: article,
                    onActionSelected: (action) =>
                        _runWorkflowAction(article, action),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Text(
              'Reported Comments',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Review flagged discussion before it reappears in the app.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (_loadingReportedComments)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_reportedComments.isEmpty)
              _InlineInfoCard(
                icon: Icons.verified_user_outlined,
                title: 'No reported comments right now',
                message: 'New comment reports will appear here for moderation.',
              )
            else
              ..._reportedComments.map(
                (comment) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ReportedCommentCard(
                    comment: comment,
                    onOpenDiscussion: () => _openDiscussion(comment),
                    onActionSelected: (action) =>
                        _runModerationAction(comment, action),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateArticle,
        icon: const Icon(Icons.edit_note_rounded),
        label: const Text('New Article'),
      ),
    );
  }

  String _statusLabel(String value) {
    if (value == 'all') {
      return 'All';
    }
    return value
        .split('_')
        .map(
          (part) => '${part.substring(0, 1).toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  String _successMessage(String action) {
    switch (action) {
      case 'submit':
        return 'Article submitted for review.';
      case 'approve':
        return 'Article approved.';
      case 'publish':
        return 'Article published.';
      case 'reject':
        return 'Article rejected.';
      case 'archive':
        return 'Article archived.';
      default:
        return 'Article updated.';
    }
  }

  String _moderationSuccessMessage(String action) {
    switch (action) {
      case 'remove':
        return 'Comment removed from discussion.';
      case 'restore':
        return 'Comment restored.';
      case 'dismiss_reports':
        return 'Reports dismissed.';
      default:
        return 'Comment updated.';
    }
  }
}

class _AdminArticleCard extends StatelessWidget {
  const _AdminArticleCard({
    required this.article,
    required this.onActionSelected,
  });

  final NewsArticle article;
  final ValueChanged<String> onActionSelected;

  @override
  Widget build(BuildContext context) {
    final actions = _actionsFor(article.status);
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.16),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _StatusBadge(
                            label: article.status,
                            color: _statusColor(article.status),
                          ),
                          _StatusBadge(
                            label: article.verificationStatus,
                            color: _verificationColor(
                              article.verificationStatus,
                            ),
                            outlined: true,
                          ),
                          if (article.isFeatured)
                            const _StatusBadge(
                              label: 'Featured',
                              color: Color(0xFF0F766E),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        article.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${article.source} - ${article.category}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.72,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (actions.isNotEmpty)
                  PopupMenuButton<String>(
                    onSelected: onActionSelected,
                    itemBuilder: (context) => actions
                        .map(
                          (action) => PopupMenuItem<String>(
                            value: action,
                            child: Text(_actionLabel(action)),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
            if (article.summary != null &&
                article.summary!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                article.summary!.trim(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    article.sourceDomain ??
                        article.articleUrl ??
                        'Source link unavailable',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.64,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<String> _actionsFor(String status) {
    switch (status) {
      case 'draft':
        return const ['submit', 'approve', 'publish', 'reject', 'archive'];
      case 'submitted':
        return const ['approve', 'publish', 'reject', 'archive'];
      case 'approved':
        return const ['publish', 'reject', 'archive'];
      case 'published':
        return const ['archive'];
      case 'rejected':
        return const ['submit', 'publish', 'archive'];
      case 'archived':
        return const <String>[];
      default:
        return const ['archive'];
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'published':
        return const Color(0xFF0F766E);
      case 'approved':
        return const Color(0xFF2563EB);
      case 'submitted':
        return const Color(0xFFF59E0B);
      case 'rejected':
        return const Color(0xFFDC2626);
      case 'archived':
        return const Color(0xFF6B7280);
      case 'draft':
      default:
        return const Color(0xFF475569);
    }
  }

  Color _verificationColor(String status) {
    switch (status) {
      case 'fact_checked':
        return const Color(0xFF166534);
      case 'verified':
        return const Color(0xFF0F766E);
      case 'developing':
        return const Color(0xFFB45309);
      case 'opinion':
        return const Color(0xFF7C3AED);
      case 'sponsored':
        return const Color(0xFFB91C1C);
      case 'unverified':
      default:
        return const Color(0xFF64748B);
    }
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'submit':
        return 'Submit for review';
      case 'approve':
        return 'Approve';
      case 'publish':
        return 'Publish';
      case 'reject':
        return 'Reject';
      case 'archive':
        return 'Archive';
      default:
        return action;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
    this.outlined = false,
  });

  final String label;
  final Color color;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final text = label
        .split('_')
        .map(
          (part) => '${part.substring(0, 1).toUpperCase()}${part.substring(1)}',
        )
        .join(' ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: outlined
            ? color.withValues(alpha: 0.08)
            : color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: outlined ? 0.4 : 0.18),
        ),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: onPressed, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _ReportedCommentCard extends StatelessWidget {
  const _ReportedCommentCard({
    required this.comment,
    required this.onOpenDiscussion,
    required this.onActionSelected,
  });

  final ReportedComment comment;
  final VoidCallback onOpenDiscussion;
  final ValueChanged<String> onActionSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actions = comment.isRemoved
        ? const <String>['restore']
        : const <String>['remove', 'dismiss_reports'];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.16),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _StatusBadge(
                            label: comment.status,
                            color: comment.isRemoved
                                ? const Color(0xFFDC2626)
                                : const Color(0xFFB45309),
                          ),
                          _StatusBadge(
                            label:
                                '${comment.reportCount} report${comment.reportCount == 1 ? '' : 's'}',
                            color: const Color(0xFF7C2D12),
                            outlined: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        comment.articleTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'By ${comment.authorName}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.72,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: onActionSelected,
                  itemBuilder: (context) => actions
                      .map(
                        (action) => PopupMenuItem<String>(
                          value: action,
                          child: Text(_moderationActionLabel(action)),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(comment.body, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Text(
              'Article: ${comment.articleId} - Likes ${comment.likeCount} - Replies ${comment.replyCount}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.64),
              ),
            ),
            if (comment.moderationReason?.trim().isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              Text(
                comment.moderationReason!.trim(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: onOpenDiscussion,
                icon: const Icon(Icons.forum_outlined),
                label: const Text('Open Discussion'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _moderationActionLabel(String action) {
    switch (action) {
      case 'remove':
        return 'Remove comment';
      case 'restore':
        return 'Restore comment';
      case 'dismiss_reports':
        return 'Dismiss reports';
      default:
        return action;
    }
  }
}

class _InlineInfoCard extends StatelessWidget {
  const _InlineInfoCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(message, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
