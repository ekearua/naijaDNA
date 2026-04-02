import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:naijapulse/admin/data/datasource/admin_remote_datasource.dart';
import 'package:naijapulse/admin/data/models/admin_models.dart';
import 'package:naijapulse/admin/presentation/article_category_options.dart';
import 'package:naijapulse/admin/presentation/widgets/homepage_quick_actions.dart';
import 'package:naijapulse/core/di/injection_container.dart';
import 'package:naijapulse/core/error/failures.dart';
import 'package:naijapulse/core/routing/external_link.dart';
import 'package:naijapulse/core/routing/app_router.dart';
import 'package:naijapulse/core/utils/content_text.dart';
import 'package:naijapulse/core/widgets/news_thumbnail.dart';
import 'package:naijapulse/features/notifications/domain/entities/app_notification.dart';
import 'package:naijapulse/features/news/data/models/news_article_model.dart';
import 'package:naijapulse/features/news/presentation/widgets/news_time.dart';

class AdminArticleDetailPage extends StatefulWidget {
  const AdminArticleDetailPage({required this.articleId, super.key});

  final String articleId;

  @override
  State<AdminArticleDetailPage> createState() => _AdminArticleDetailPageState();
}

class _AdminArticleDetailPageState extends State<AdminArticleDetailPage> {
  final AdminRemoteDataSource _remote =
      InjectionContainer.sl<AdminRemoteDataSource>();

  AdminArticleDetailModel? _detail;
  bool _loading = true;
  bool _runningAction = false;
  bool _savingMetadata = false;
  String? _errorMessage;
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _categoryController.addListener(_handleMetadataDraftChanged);
    _tagsController.addListener(_handleMetadataDraftChanged);
    _imageUrlController.addListener(_handleMetadataDraftChanged);
    _load();
  }

  void _handleMetadataDraftChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final detail = await _remote.fetchAdminArticleDetail(widget.articleId);
      if (!mounted) {
        return;
      }
      setState(() => _detail = detail);
      _categoryController.text = detail.article.category;
      _tagsController.text = articleTagDraftFromList(detail.article.tags);
      _imageUrlController.text = detail.article.imageUrl ?? '';
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

  @override
  void dispose() {
    _categoryController.removeListener(_handleMetadataDraftChanged);
    _tagsController.removeListener(_handleMetadataDraftChanged);
    _imageUrlController.removeListener(_handleMetadataDraftChanged);
    _categoryController.dispose();
    _tagsController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _runWorkflowAction(String action) async {
    final detail = _detail;
    if (detail == null || _runningAction) {
      return;
    }

    setState(() => _runningAction = true);
    try {
      await _remote.transitionAdminArticle(
        articleId: detail.article.id,
        action: action,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_actionMessage(action))));
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapFailure(error).message)));
    } finally {
      if (mounted) {
        setState(() => _runningAction = false);
      }
    }
  }

  Future<void> _openSource(NewsArticleModel article) async {
    final url = article.articleUrl?.trim();
    if (url == null || url.isEmpty) {
      return;
    }

    try {
      final opened = await openExternalLink(url);
      if (!mounted || opened) {
        return;
      }
      await context.push(AppRouter.newsDetailPath(article.id));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the publisher source right now.'),
        ),
      );
    }
  }

  Future<void> _openImageUrl() async {
    final url = _imageUrlController.text.trim();
    if (url.isEmpty) {
      return;
    }
    try {
      final opened = await openExternalLink(url);
      if (!mounted || opened) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the image URL.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the image URL.')),
      );
    }
  }

  Future<void> _saveMetadata() async {
    final detail = _detail;
    if (detail == null || _savingMetadata) {
      return;
    }

    final category = _categoryController.text.trim();
    final tags = parseArticleTagDraft(_tagsController.text);
    final imageUrl = _imageUrlController.text.trim();
    if (category.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose or enter a valid category.')),
      );
      return;
    }
    if (imageUrl.isNotEmpty &&
        !imageUrl.startsWith('http://') &&
        !imageUrl.startsWith('https://')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image URL must start with http:// or https://.'),
        ),
      );
      return;
    }

    setState(() => _savingMetadata = true);
    try {
      final article = await _remote.updateAdminArticle(
        articleId: detail.article.id,
        category: category,
        tags: tags,
        imageUrl: imageUrl,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _detail = AdminArticleDetailModel(
          article: article,
          workflowEvents: detail.workflowEvents,
          relatedNotifications: detail.relatedNotifications,
          reportedCommentCount: detail.reportedCommentCount,
          totalCommentCount: detail.totalCommentCount,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Article metadata updated.')),
      );
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapFailure(error).message)));
    } finally {
      if (mounted) {
        setState(() => _savingMetadata = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _detail == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _detail == null) {
      return _DetailMessageState(
        title: 'Could not load article detail',
        message: _errorMessage!,
        actionLabel: 'Try again',
        onPressed: _load,
      );
    }

    final detail = _detail;
    if (detail == null) {
      return _DetailMessageState(
        title: 'Article unavailable',
        message: 'The article detail response was empty.',
        actionLabel: 'Back to queue',
        onPressed: () => context.go(AppRouter.adminArticlesPath),
      );
    }

    final article = detail.article;
    final actions = _actionsFor(article.status);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Row(
            children: [
              TextButton.icon(
                onPressed: () => context.go(AppRouter.adminArticlesPath),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Back to queue'),
              ),
              const Spacer(),
              if (article.articleUrl?.trim().isNotEmpty ?? false)
                OutlinedButton.icon(
                  onPressed: () => _openSource(article),
                  icon: const Icon(Icons.open_in_browser_rounded),
                  label: const Text('Open source'),
                ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: article.status == 'published'
                    ? () => addArticleToHomepageFlow(
                        context,
                        remote: _remote,
                        article: article,
                      )
                    : null,
                icon: const Icon(Icons.push_pin_outlined),
                label: const Text('Add to homepage'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () =>
                    context.push(AppRouter.adminArticleEditPath(article.id)),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit article'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () => context.push(
                  AppRouter.articleDiscussionPath(article.id),
                  extra: article,
                ),
                icon: const Icon(Icons.forum_outlined),
                label: const Text('Discussion'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2DBCF)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StatusChip(
                        label: article.status,
                        color: _statusColor(article.status),
                      ),
                      _StatusChip(
                        label: article.verificationStatus,
                        color: _verificationColor(article.verificationStatus),
                        outlined: true,
                      ),
                      if (article.isFeatured)
                        const _StatusChip(
                          label: 'featured',
                          color: Color(0xFF0F766E),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    article.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${article.source} - ${article.category} - ${adminDateTimeLabel(article.publishedAt)}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF6E675C),
                    ),
                  ),
                  if (article.summary?.trim().isNotEmpty ?? false) ...[
                    const SizedBox(height: 18),
                    Text(
                      plainTextExcerpt(article.summary),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                  if (article.reviewNotes?.trim().isNotEmpty ?? false) ...[
                    const SizedBox(height: 18),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFCF8),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE6DDD1)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          article.reviewNotes!.trim(),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: actions
                        .map(
                          (action) => FilledButton.tonal(
                            onPressed: _runningAction
                                ? null
                                : () => _runWorkflowAction(action),
                            child: Text(_actionLabel(action)),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          _InsightCard(
            title: 'Story Metadata',
            subtitle:
                'Review the assigned category and image URL used by the client.',
            child: _MetadataEditorCard(
              categoryController: _categoryController,
              tagsController: _tagsController,
              imageUrlController: _imageUrlController,
              categoryOptions: articleCategoryOptionsFor(
                _categoryController.text,
              ),
              saving: _savingMetadata,
              imagePreviewUrl: _imageUrlController.text.trim().isEmpty
                  ? article.imageUrl
                  : _imageUrlController.text.trim(),
              onCategorySelected: (value) => setState(() {
                _categoryController.text = value;
              }),
              onOpenImage: _openImageUrl,
              onSave: _saveMetadata,
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1120;
              if (!wide) {
                return Column(
                  children: [
                    _InsightCard(
                      title: 'Story Signals',
                      subtitle:
                          'Discussion and moderation counts around this article.',
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _CountTile(
                            label: 'Comments',
                            value: detail.totalCommentCount,
                          ),
                          _CountTile(
                            label: 'Reported',
                            value: detail.reportedCommentCount,
                          ),
                          _CountTile(
                            label: 'Notifications',
                            value: detail.relatedNotifications.length,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _TimelineCard(events: detail.workflowEvents),
                    const SizedBox(height: 16),
                    _NotificationsCard(
                      notifications: detail.relatedNotifications,
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: _TimelineCard(events: detail.workflowEvents),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        _InsightCard(
                          title: 'Story Signals',
                          subtitle:
                              'Discussion and moderation counts around this article.',
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _CountTile(
                                label: 'Comments',
                                value: detail.totalCommentCount,
                              ),
                              _CountTile(
                                label: 'Reported',
                                value: detail.reportedCommentCount,
                              ),
                              _CountTile(
                                label: 'Notifications',
                                value: detail.relatedNotifications.length,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _NotificationsCard(
                          notifications: detail.relatedNotifications,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _actionMessage(String action) {
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
        return const Color(0xFFB7791F);
      case 'rejected':
        return const Color(0xFFC53030);
      case 'archived':
        return const Color(0xFF6B7280);
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
      default:
        return const Color(0xFF64748B);
    }
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2DBCF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6E675C)),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF8F4ED),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.events});

  final List<AdminWorkflowActivityModel> events;

  @override
  Widget build(BuildContext context) {
    return _InsightCard(
      title: 'Workflow History',
      subtitle: 'Every editorial transition recorded against this story.',
      child: events.isEmpty
          ? Text(
              'No workflow events recorded yet.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          : Column(
              children: events
                  .map(
                    (event) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE6F2ED),
                        foregroundColor: Color(0xFF0F6B4B),
                        child: Icon(Icons.track_changes_rounded),
                      ),
                      title: Text(
                        '${event.actorName} - ${event.eventType.replaceAll('_', ' ')}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        [
                          if (event.fromStatus != null ||
                              event.toStatus != null)
                            '${event.fromStatus ?? 'unknown'} ? ${event.toStatus ?? 'unknown'}',
                          if (event.notes?.trim().isNotEmpty ?? false)
                            event.notes!.trim(),
                          adminDateTimeLabel(event.createdAt),
                        ].join('\n'),
                      ),
                      isThreeLine: true,
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }
}

class _NotificationsCard extends StatelessWidget {
  const _NotificationsCard({required this.notifications});

  final List<AppNotification> notifications;

  @override
  Widget build(BuildContext context) {
    return _InsightCard(
      title: 'Related Notifications',
      subtitle: 'Reply and editorial notifications tied to this article.',
      child: notifications.isEmpty
          ? Text(
              'No notifications have been emitted for this story yet.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          : Column(
              children: notifications
                  .map(
                    (notification) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        _iconFor(notification.type),
                        color: const Color(0xFF0F6B4B),
                      ),
                      title: Text(
                        notification.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${notification.body}\n${adminDateTimeLabel(notification.createdAt)}',
                      ),
                      isThreeLine: true,
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'comment_reply':
        return Icons.reply_rounded;
      case 'comment_like':
        return Icons.thumb_up_alt_rounded;
      case 'article_approved':
        return Icons.verified_rounded;
      case 'article_published':
        return Icons.campaign_rounded;
      case 'article_rejected':
        return Icons.report_gmailerrorred_rounded;
      case 'article_archived':
        return Icons.archive_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
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
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: outlined ? 0.08 : 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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

class _MetadataEditorCard extends StatelessWidget {
  const _MetadataEditorCard({
    required this.categoryController,
    required this.tagsController,
    required this.imageUrlController,
    required this.categoryOptions,
    required this.saving,
    required this.imagePreviewUrl,
    required this.onCategorySelected,
    required this.onOpenImage,
    required this.onSave,
  });

  final TextEditingController categoryController;
  final TextEditingController tagsController;
  final TextEditingController imageUrlController;
  final List<String> categoryOptions;
  final bool saving;
  final String? imagePreviewUrl;
  final ValueChanged<String> onCategorySelected;
  final VoidCallback onOpenImage;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final hasPreview = (imagePreviewUrl ?? '').trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: categoryController,
          decoration: const InputDecoration(
            labelText: 'Category',
            hintText: 'Politics',
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categoryOptions
              .map(
                (option) => ActionChip(
                  label: Text(option),
                  onPressed: () => onCategorySelected(option),
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: tagsController,
          decoration: const InputDecoration(
            labelText: 'Tags',
            hintText: 'Politics, Abuja, Elections',
          ),
          minLines: 1,
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: parseArticleTagDraft(tagsController.text)
              .map(
                (tag) => Chip(
                  label: Text(tag),
                  visualDensity: VisualDensity.compact,
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: imageUrlController,
          decoration: InputDecoration(
            labelText: 'Image URL',
            hintText: 'https://publisher.com/image.jpg',
            suffixIcon: imageUrlController.text.trim().isEmpty
                ? null
                : IconButton(
                    tooltip: 'Open image',
                    onPressed: onOpenImage,
                    icon: const Icon(Icons.open_in_new_rounded),
                  ),
          ),
        ),
        if (hasPreview) ...[
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 200,
              width: double.infinity,
              child: NewsThumbnail(
                imageUrl: imagePreviewUrl,
                fallbackLabel: categoryController.text.trim(),
                alignment: Alignment.topCenter,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        SelectableText(
          imageUrlController.text.trim().isEmpty
              ? 'No image URL stored for this article yet.'
              : imageUrlController.text.trim(),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6E675C)),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Save metadata'),
          ),
        ),
      ],
    );
  }
}

class _DetailMessageState extends StatelessWidget {
  const _DetailMessageState({
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
            border: Border.all(color: const Color(0xFFE2DBCF)),
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
