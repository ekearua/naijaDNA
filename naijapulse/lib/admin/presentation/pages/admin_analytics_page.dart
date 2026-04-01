import 'package:flutter/material.dart';
import 'package:naijapulse/admin/data/datasource/admin_remote_datasource.dart';
import 'package:naijapulse/admin/data/models/admin_models.dart';
import 'package:naijapulse/core/di/injection_container.dart';
import 'package:naijapulse/core/error/failures.dart';
import 'package:naijapulse/features/news/presentation/widgets/news_time.dart';

class AdminAnalyticsPage extends StatefulWidget {
  const AdminAnalyticsPage({super.key});

  @override
  State<AdminAnalyticsPage> createState() => _AdminAnalyticsPageState();
}

class _AdminAnalyticsPageState extends State<AdminAnalyticsPage> {
  final AdminRemoteDataSource _remote =
      InjectionContainer.sl<AdminRemoteDataSource>();

  AdminAnalyticsOverviewModel? _analytics;
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
      final analytics = await _remote.fetchAnalyticsOverview();
      if (!mounted) {
        return;
      }
      setState(() => _analytics = analytics);
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
    if (_loading && _analytics == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _analytics == null) {
      return _AnalyticsStateCard(
        title: 'Could not load analytics',
        message: _errorMessage!,
        actionLabel: 'Try again',
        onPressed: _load,
      );
    }

    final analytics = _analytics;
    if (analytics == null) {
      return _AnalyticsStateCard(
        title: 'Analytics unavailable',
        message: 'No analytics payload was returned.',
        actionLabel: 'Refresh',
        onPressed: _load,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Text(
            'Analytics Overview',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Content performance for the last ${analytics.windowDays} days.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF4F4A43)),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: analytics.headlineMetrics
                .map((metric) => _MetricCard(metric: metric))
                .toList(growable: false),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1100;
              if (!wide) {
                return Column(
                  children: [
                    _BreakdownCard(
                      title: 'Article Status Breakdown',
                      items: analytics.articleStatusBreakdown,
                    ),
                    const SizedBox(height: 16),
                    _BreakdownCard(
                      title: 'Verification Breakdown',
                      items: analytics.verificationBreakdown,
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _BreakdownCard(
                      title: 'Article Status Breakdown',
                      items: analytics.articleStatusBreakdown,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _BreakdownCard(
                      title: 'Verification Breakdown',
                      items: analytics.verificationBreakdown,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          _DataTableCard(
            title: 'Top Articles',
            subtitle: 'Stories drawing the most engagement and discussion.',
            child: Column(
              children: analytics.topArticles
                  .map(
                    (article) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        article.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${article.source} - ${article.category} - ${adminDateTimeLabel(article.publishedAt)}',
                      ),
                      trailing: Text(
                        '${article.engagementCount} eng / ${article.commentCount} c',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF4F4A43),
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          const SizedBox(height: 16),
          _DataTableCard(
            title: 'Top Sources',
            subtitle:
                'Most productive sources by published output and discussion.',
            child: Column(
              children: analytics.topSources
                  .map(
                    (source) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        source.source,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        'Articles ${source.articleCount} - Published ${source.publishedCount}',
                      ),
                      trailing: Text(
                        '${source.commentCount} comments',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF4F4A43),
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final AdminAnalyticsMetricModel metric;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFCFC3B0), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF12261C).withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${metric.value}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(metric.label, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.title, required this.items});

  final String title;
  final List<AdminAnalyticsMetricModel> items;

  @override
  Widget build(BuildContext context) {
    return _DataTableCard(
      title: title,
      subtitle: 'Snapshot totals grouped for newsroom review.',
      child: Column(
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(child: Text(item.label)),
                    Text(
                      '${item.value}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _DataTableCard extends StatelessWidget {
  const _DataTableCard({
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
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF4F4A43)),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _AnalyticsStateCard extends StatelessWidget {
  const _AnalyticsStateCard({
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
