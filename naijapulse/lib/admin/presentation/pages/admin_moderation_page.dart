import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:naijapulse/admin/data/datasource/admin_remote_datasource.dart';
import 'package:naijapulse/core/di/injection_container.dart';
import 'package:naijapulse/core/error/failures.dart';
import 'package:naijapulse/core/routing/app_router.dart';
import 'package:naijapulse/features/news/domain/entities/reported_comment.dart';
import 'package:naijapulse/features/news/presentation/widgets/news_time.dart';

class AdminModerationPage extends StatefulWidget {
  const AdminModerationPage({super.key});

  @override
  State<AdminModerationPage> createState() => _AdminModerationPageState();
}

class _AdminModerationPageState extends State<AdminModerationPage> {
  final AdminRemoteDataSource _remote =
      InjectionContainer.sl<AdminRemoteDataSource>();

  List<ReportedComment> _comments = const <ReportedComment>[];
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final items = await _remote.fetchReportedComments();
      if (!mounted) {
        return;
      }
      setState(() => _comments = items);
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

  Future<void> _moderate(ReportedComment comment, String action) async {
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
          _comments = _comments.where((item) => item.id != comment.id).toList();
          return;
        }
        _comments = _comments
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_actionMessage(action))));
      if (action != 'remove') {
        await _load();
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

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Text(
            'Comment Moderation',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Review reports, inspect the live discussion context, and remove or restore comments.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF4F4A43)),
          ),
          const SizedBox(height: 18),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorMessage != null)
            _ModerationStateCard(
              title: 'Could not load moderation queue',
              message: _errorMessage!,
              actionLabel: 'Try again',
              onPressed: _load,
            )
          else if (_comments.isEmpty)
            _ModerationStateCard(
              title: 'Moderation queue is clear',
              message:
                  'New reports will appear here when users flag discussion.',
              actionLabel: 'Refresh',
              onPressed: _load,
            )
          else
            ..._comments.map(
              (comment) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _ModerationCommentCard(
                  comment: comment,
                  onOpenDiscussion: () => context.push(
                    AppRouter.articleDiscussionPath(
                      comment.articleId,
                      commentId: comment.id,
                    ),
                  ),
                  onOpenArticle: () => context.go(
                    AppRouter.adminArticleDetailPath(comment.articleId),
                  ),
                  onActionSelected: (action) => _moderate(comment, action),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _actionMessage(String action) {
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

class _ModerationCommentCard extends StatelessWidget {
  const _ModerationCommentCard({
    required this.comment,
    required this.onOpenDiscussion,
    required this.onOpenArticle,
    required this.onActionSelected,
  });

  final ReportedComment comment;
  final VoidCallback onOpenDiscussion;
  final VoidCallback onOpenArticle;
  final ValueChanged<String> onActionSelected;

  @override
  Widget build(BuildContext context) {
    final actions = comment.isRemoved
        ? const <String>['restore']
        : const <String>['remove', 'dismiss_reports'];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFCFC3B0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF12261C).withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                          _Badge(
                            label: comment.status,
                            color: comment.isRemoved
                                ? const Color(0xFFC53030)
                                : const Color(0xFFB7791F),
                          ),
                          _Badge(
                            label: '${comment.reportCount} reports',
                            color: const Color(0xFFC53030),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        comment.articleTitle,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'By ${comment.authorName} - ${adminDateTimeLabel(comment.updatedAt)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF4F4A43),
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
                          child: Text(switch (action) {
                            'remove' => 'Remove comment',
                            'restore' => 'Restore comment',
                            'dismiss_reports' => 'Dismiss reports',
                            _ => action,
                          }),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(comment.body, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  'Likes ${comment.likeCount} - Replies ${comment.replyCount}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF4F4A43),
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: onOpenArticle,
                  icon: const Icon(Icons.article_outlined),
                  label: const Text('Open article'),
                ),
                const SizedBox(width: 10),
                FilledButton.tonalIcon(
                  onPressed: onOpenDiscussion,
                  icon: const Icon(Icons.forum_outlined),
                  label: const Text('Open discussion'),
                ),
              ],
            ),
            if (comment.moderationReason?.trim().isNotEmpty ?? false) ...[
              const SizedBox(height: 12),
              Text(
                comment.moderationReason!.trim(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF4F4A43),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ModerationStateCard extends StatelessWidget {
  const _ModerationStateCard({
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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFCFC3B0), width: 1.2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
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
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                FilledButton(onPressed: onPressed, child: Text(actionLabel)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
