import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:naijapulse/admin/data/datasource/admin_remote_datasource.dart';
import 'package:naijapulse/admin/data/models/admin_models.dart';
import 'package:naijapulse/core/di/injection_container.dart';
import 'package:naijapulse/core/error/failures.dart';
import 'package:naijapulse/core/routing/app_router.dart';
import 'package:naijapulse/features/news/domain/entities/reported_comment.dart';
import 'package:naijapulse/features/news/presentation/widgets/news_time.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final AdminRemoteDataSource _remote =
      InjectionContainer.sl<AdminRemoteDataSource>();

  AdminDashboardSummaryModel? _summary;
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
      final summary = await _remote.fetchDashboardSummary();
      if (!mounted) {
        return;
      }
      setState(() => _summary = summary);
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
  Widget build(BuildContext context) {
    if (_loading && _summary == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _summary == null) {
      return _AdminMessageState(
        title: 'Could not load the dashboard',
        message: _errorMessage!,
        actionLabel: 'Try again',
        onPressed: _load,
      );
    }

    final summary = _summary;
    if (summary == null) {
      return _AdminMessageState(
        title: 'Dashboard unavailable',
        message: 'No summary data is available yet.',
        actionLabel: 'Refresh',
        onPressed: _load,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: summary.kpis
                .map((kpi) => _KpiCard(kpi: kpi))
                .toList(growable: false),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1120;
              if (!wide) {
                return Column(
                  children: [
                    _QueueSnapshotCard(queue: summary.editorialQueue),
                    const SizedBox(height: 16),
                    _SourceHealthCard(sourceHealth: summary.sourceHealth),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: _QueueSnapshotCard(queue: summary.editorialQueue),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 5,
                    child: _SourceHealthCard(
                      sourceHealth: summary.sourceHealth,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1120;
              if (!wide) {
                return Column(
                  children: [
                    _WorkflowCard(items: summary.recentWorkflowActivity),
                    const SizedBox(height: 16),
                    _ReportedCommentsCard(items: summary.reportedComments),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: _WorkflowCard(items: summary.recentWorkflowActivity),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 5,
                    child: _ReportedCommentsCard(
                      items: summary.reportedComments,
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
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.kpi});

  final AdminKpiModel kpi;

  @override
  Widget build(BuildContext context) {
    final tone = _toneColor(kpi.tone);
    return SizedBox(
      width: 210,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFCFC3B0), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF12261C).withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.insights_rounded, color: tone),
              ),
              const SizedBox(height: 18),
              Text(
                '${kpi.value}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1D1B18),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                kpi.label,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF4F4A43)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _toneColor(String tone) {
    switch (tone) {
      case 'success':
        return const Color(0xFF0F766E);
      case 'warning':
        return const Color(0xFFB7791F);
      case 'danger':
        return const Color(0xFFC53030);
      case 'info':
        return const Color(0xFF2563EB);
      default:
        return const Color(0xFF0F6B4B);
    }
  }
}

class _QueueSnapshotCard extends StatelessWidget {
  const _QueueSnapshotCard({required this.queue});

  final AdminEditorialQueueModel queue;

  @override
  Widget build(BuildContext context) {
    return _AdminPanel(
      title: 'Editorial Queue Snapshot',
      subtitle: 'A quick read on what needs action next.',
      trailing: FilledButton.icon(
        onPressed: () => context.go(AppRouter.adminArticlesPath),
        icon: const Icon(Icons.library_books_outlined),
        label: const Text('Open queue'),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _QueueMetric(
            label: 'Submitted',
            value: queue.submitted,
            color: const Color(0xFFB7791F),
          ),
          _QueueMetric(
            label: 'Approved',
            value: queue.approved,
            color: const Color(0xFF2563EB),
          ),
          _QueueMetric(
            label: 'Rejected',
            value: queue.rejected,
            color: const Color(0xFFC53030),
          ),
          _QueueMetric(
            label: 'Scheduled',
            value: queue.scheduled,
            color: const Color(0xFF0F766E),
          ),
        ],
      ),
    );
  }
}

class _QueueMetric extends StatelessWidget {
  const _QueueMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
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
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceHealthCard extends StatelessWidget {
  const _SourceHealthCard({required this.sourceHealth});

  final List<AdminSourceHealthModel> sourceHealth;

  @override
  Widget build(BuildContext context) {
    return _AdminPanel(
      title: 'Source Health',
      subtitle: 'Configured feeds and their latest ingestion state.',
      trailing: OutlinedButton.icon(
        onPressed: () => context.go(AppRouter.adminOperationsPath),
        icon: const Icon(Icons.tune_rounded),
        label: const Text('Operations'),
      ),
      child: Column(
        children: sourceHealth
            .take(6)
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.sourceName,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Fetched ${item.fetched} - Inserted ${item.inserted} - Deduped ${item.deduped}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: const Color(0xFF4F4A43)),
                          ),
                        ],
                      ),
                    ),
                    _HealthBadge(status: item.status),
                  ],
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _WorkflowCard extends StatelessWidget {
  const _WorkflowCard({required this.items});

  final List<AdminWorkflowActivityModel> items;

  @override
  Widget build(BuildContext context) {
    return _AdminPanel(
      title: 'Recent Workflow Activity',
      subtitle:
          'Approval, rejection, and publication activity across the desk.',
      child: Column(
        children: items
            .map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFE6F2ED),
                  foregroundColor: const Color(0xFF0F6B4B),
                  child: const Icon(Icons.edit_note_rounded),
                ),
                title: Text(
                  '${item.actorName} ${_actionLabel(item.eventType)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${item.articleTitle}\n${adminDateTimeLabel(item.createdAt)}',
                ),
                isThreeLine: true,
                trailing: TextButton(
                  onPressed: () => context.go(
                    AppRouter.adminArticleDetailPath(item.articleId),
                  ),
                  child: const Text('Open'),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  String _actionLabel(String value) {
    switch (value) {
      case 'submitted':
        return 'submitted an article';
      case 'approved':
        return 'approved a story';
      case 'published':
        return 'published a story';
      case 'rejected':
        return 'rejected a story';
      case 'archived':
        return 'archived a story';
      default:
        return 'updated workflow';
    }
  }
}

class _ReportedCommentsCard extends StatelessWidget {
  const _ReportedCommentsCard({required this.items});

  final List<ReportedComment> items;

  @override
  Widget build(BuildContext context) {
    return _AdminPanel(
      title: 'Reported Comments',
      subtitle: 'The moderation queue with direct access to thread context.',
      trailing: OutlinedButton.icon(
        onPressed: () => context.go(AppRouter.adminModerationPath),
        icon: const Icon(Icons.flag_outlined),
        label: const Text('Open moderation'),
      ),
      child: Column(
        children: items.isEmpty
            ? [
                Text(
                  'No reported comments right now.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF4F4A43),
                  ),
                ),
              ]
            : items
                  .take(5)
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5EEE4),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0xFFCFC3B0),
                            width: 1.1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.articleTitle,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.body,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _MiniBadge(
                                    label: '${item.reportCount} reports',
                                    color: const Color(0xFFC53030),
                                  ),
                                  const SizedBox(width: 8),
                                  _MiniBadge(
                                    label: item.status,
                                    color: item.isRemoved
                                        ? const Color(0xFFC53030)
                                        : const Color(0xFFB7791F),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () => context.push(
                                      AppRouter.articleDiscussionPath(
                                        item.articleId,
                                        commentId: item.id,
                                      ),
                                    ),
                                    child: const Text('Open discussion'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
      ),
    );
  }
}

class _HealthBadge extends StatelessWidget {
  const _HealthBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'success' => const Color(0xFF0F766E),
      'warning' => const Color(0xFFB7791F),
      'failed' => const Color(0xFFC53030),
      _ => const Color(0xFF4F4A43),
    };
    return _MiniBadge(label: status, color: color);
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label, required this.color});

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

class _AdminPanel extends StatelessWidget {
  const _AdminPanel({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
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
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF4F4A43),
                        ),
                      ),
                    ],
                  ),
                ),
                ...?switch (trailing) {
                  final trailingWidget? => [trailingWidget],
                  null => null,
                },
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _AdminMessageState extends StatelessWidget {
  const _AdminMessageState({
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
