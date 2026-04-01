import 'package:flutter/material.dart';
import 'package:naijapulse/admin/data/datasource/admin_remote_datasource.dart';
import 'package:naijapulse/admin/data/models/admin_models.dart';
import 'package:naijapulse/core/di/injection_container.dart';
import 'package:naijapulse/core/error/failures.dart';
import 'package:naijapulse/features/news/presentation/widgets/news_time.dart';

class AdminOperationsPage extends StatefulWidget {
  const AdminOperationsPage({super.key});

  @override
  State<AdminOperationsPage> createState() => _AdminOperationsPageState();
}

class _AdminOperationsPageState extends State<AdminOperationsPage> {
  final AdminRemoteDataSource _remote =
      InjectionContainer.sl<AdminRemoteDataSource>();

  AdminCacheDiagnosticsModel? _diagnostics;
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
      final diagnostics = await _remote.fetchCacheDiagnostics();
      if (!mounted) {
        return;
      }
      setState(() => _diagnostics = diagnostics);
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
    if (_loading && _diagnostics == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _diagnostics == null) {
      return _OpsStateCard(
        title: 'Could not load operations diagnostics',
        message: _errorMessage!,
        actionLabel: 'Try again',
        onPressed: _load,
      );
    }

    final diagnostics = _diagnostics;
    if (diagnostics == null) {
      return _OpsStateCard(
        title: 'Operations unavailable',
        message: 'No diagnostics payload was returned.',
        actionLabel: 'Refresh',
        onPressed: _load,
      );
    }

    final ingestion = diagnostics.ingestion;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Text(
            'Operations',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Cache health, scheduler settings, and RSS ingestion telemetry in one place.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF6E675C)),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _MetricBox(label: 'Cache reads', value: diagnostics.readCount),
              _MetricBox(label: 'Cache hits', value: diagnostics.hitCount),
              _MetricBox(label: 'Cache misses', value: diagnostics.missCount),
              _MetricBox(label: 'Cache writes', value: diagnostics.writeCount),
              _MetricBox(label: 'Cache errors', value: diagnostics.errorCount),
              _MetricBox(
                label: 'Active sources',
                value: ingestion.activeSources,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _Panel(
            title: 'Cache Diagnostics',
            subtitle: 'Runtime cache state since process start.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _Badge(
                      label: diagnostics.enabled
                          ? 'Cache enabled'
                          : 'Cache disabled',
                      color: diagnostics.enabled
                          ? const Color(0xFF0F766E)
                          : const Color(0xFF6B7280),
                    ),
                    _Badge(
                      label: diagnostics.clientReady
                          ? 'Upstash ready'
                          : 'Upstash not ready',
                      color: diagnostics.clientReady
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFC53030),
                    ),
                    _Badge(
                      label: diagnostics.schedulerEnabled
                          ? 'Scheduler on'
                          : 'Scheduler off',
                      color: diagnostics.schedulerEnabled
                          ? const Color(0xFF0F766E)
                          : const Color(0xFFB7791F),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'TTL values',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Top ${diagnostics.newsTopTtlSeconds}s - Latest ${diagnostics.newsLatestTtlSeconds}s - Polls ${diagnostics.pollsActiveTtlSeconds}s - Categories ${diagnostics.categoriesTtlSeconds}s - Tags ${diagnostics.tagsTtlSeconds}s',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                if (diagnostics.namespaces.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: diagnostics.namespaces
                        .map(
                          (item) => _Badge(
                            label: '${item.namespace} v${item.version}',
                            color: const Color(0xFF0F6B4B),
                          ),
                        )
                        .toList(growable: false),
                  ),
                if (diagnostics.lastErrorMessage?.trim().isNotEmpty ??
                    false) ...[
                  const SizedBox(height: 16),
                  Text(
                    diagnostics.lastErrorMessage!.trim(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFC53030),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Panel(
            title: 'Ingestion Status',
            subtitle: 'Latest scheduler settings and recent feed runs.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Running: ${ingestion.running ? 'yes' : 'no'} - Interval: ${diagnostics.ingestionIntervalSeconds}s - Startup ingestion: ${diagnostics.startupIngestionEnabled ? 'on' : 'off'}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                if (ingestion.lastRun != null)
                  _RunCard(run: ingestion.lastRun!, emphasize: true),
                ...ingestion.recentRuns
                    .take(4)
                    .where((run) => run.runId != ingestion.lastRun?.runId)
                    .map(
                      (run) => Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _RunCard(run: run),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2DBCF)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
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

class _RunCard extends StatelessWidget {
  const _RunCard({required this.run, this.emphasize = false});

  final AdminIngestionRunModel run;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: emphasize ? const Color(0xFFF8F4ED) : const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6DDD1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${run.triggeredBy} - ${run.status}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  adminDateTimeLabel(run.startedAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6E675C),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Fetched ${run.fetchedCount} - Inserted ${run.insertedCount} - Deduped ${run.dedupedCount} - Errors ${run.errorCount}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (run.sources.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...run.sources
                  .take(3)
                  .map(
                    (source) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '${source.sourceName}: ${source.status} (${source.inserted} inserted)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6E675C),
                        ),
                      ),
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

class _OpsStateCard extends StatelessWidget {
  const _OpsStateCard({
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
