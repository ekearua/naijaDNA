import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:naijapulse/core/di/injection_container.dart';
import 'package:naijapulse/core/error/failures.dart';
import 'package:naijapulse/core/routing/app_router.dart';
import 'package:naijapulse/features/live_updates/data/datasource/remote/live_updates_remote_datasource.dart';
import 'package:naijapulse/features/live_updates/data/models/live_update_models.dart';
import 'package:naijapulse/features/news/presentation/widgets/news_time.dart';

class LiveUpdatesHubPage extends StatefulWidget {
  const LiveUpdatesHubPage({super.key});

  @override
  State<LiveUpdatesHubPage> createState() => _LiveUpdatesHubPageState();
}

class _LiveUpdatesHubPageState extends State<LiveUpdatesHubPage> {
  final LiveUpdatesRemoteDataSource _remote =
      InjectionContainer.sl<LiveUpdatesRemoteDataSource>();

  List<LiveUpdatePageSummaryModel> _pages =
      const <LiveUpdatePageSummaryModel>[];
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
      final pages = await _remote.fetchPublicPages();
      if (!mounted) {
        return;
      }
      setState(() => _pages = pages);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Live Updates')),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _pages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null && _pages.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(child: Text(_errorMessage!, textAlign: TextAlign.center)),
        ],
      );
    }
    if (_pages.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          Center(
            child: Text(
              'No live coverage pages are available right now.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _pages.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final page = _pages[index];
        return InkWell(
          onTap: () => context.push(AppRouter.liveUpdateDetailPath(page.slug)),
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (page.coverImageUrl?.trim().isNotEmpty ?? false)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    child: Image.network(
                      page.coverImageUrl!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _HubPill(
                            label: page.isLive
                                ? 'LIVE'
                                : _titleCase(page.status),
                            active: page.isLive,
                          ),
                          _HubPill(label: page.category),
                          if (page.isBreaking)
                            const _HubPill(label: 'Breaking'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        page.title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        page.summary,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (page.lastPublishedEntryAt != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Updated ${adminDateTimeLabel(page.lastPublishedEntryAt!)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HubPill extends StatelessWidget {
  const _HubPill({required this.label, this.active = false});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _titleCase(String value) {
  return value
      .split(RegExp(r'[\s_-]+'))
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}
