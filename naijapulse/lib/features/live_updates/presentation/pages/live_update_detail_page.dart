import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:naijapulse/core/di/injection_container.dart';
import 'package:naijapulse/core/error/failures.dart';
import 'package:naijapulse/core/routing/app_router.dart';
import 'package:naijapulse/features/live_updates/data/datasource/remote/live_updates_remote_datasource.dart';
import 'package:naijapulse/features/live_updates/data/models/live_update_models.dart';
import 'package:naijapulse/features/news/presentation/widgets/news_time.dart';
import 'package:naijapulse/features/polls/data/datasource/remote/polls_remote_datasource.dart';
import 'package:naijapulse/features/polls/data/models/poll_model.dart';

class LiveUpdateDetailPage extends StatefulWidget {
  const LiveUpdateDetailPage({required this.slug, super.key});

  final String slug;

  @override
  State<LiveUpdateDetailPage> createState() => _LiveUpdateDetailPageState();
}

class _LiveUpdateDetailPageState extends State<LiveUpdateDetailPage> {
  final LiveUpdatesRemoteDataSource _liveRemote =
      InjectionContainer.sl<LiveUpdatesRemoteDataSource>();
  final PollsRemoteDataSource _pollsRemote =
      InjectionContainer.sl<PollsRemoteDataSource>();

  LiveUpdatePageDetailModel? _detail;
  bool _loading = true;
  String? _errorMessage;
  Timer? _pollTimer;
  final Set<String> _submittingPollIds = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final detail = await _liveRemote.fetchPublicPage(slug: widget.slug);
      if (!mounted) {
        return;
      }
      setState(() => _detail = detail);
      _restartPolling();
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

  void _restartPolling() {
    _pollTimer?.cancel();
    if (!(_detail?.page.isLive ?? false)) {
      return;
    }
    _pollTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _pollForUpdates(),
    );
  }

  Future<void> _pollForUpdates() async {
    final detail = _detail;
    if (detail == null) {
      return;
    }
    final latestSeen = detail.entries.isEmpty
        ? null
        : detail.entries
              .map((entry) => entry.publishedAt)
              .reduce((a, b) => a.isAfter(b) ? a : b);
    try {
      final response = await _liveRemote.fetchPublicPage(
        slug: widget.slug,
        after: latestSeen,
      );
      if (!mounted) {
        return;
      }
      final merged = <String, LiveUpdateEntryModel>{
        for (final entry in detail.entries) entry.id: entry,
      };
      for (final entry in response.entries) {
        merged[entry.id] = entry;
      }
      final entries = merged.values.toList()
        ..sort((a, b) {
          final pinCompare = (b.isPinned ? 1 : 0).compareTo(a.isPinned ? 1 : 0);
          if (pinCompare != 0) {
            return pinCompare;
          }
          return b.publishedAt.compareTo(a.publishedAt);
        });
      setState(() {
        _detail = detail.copyWith(page: response.page, entries: entries);
      });
      _restartPolling();
    } catch (_) {
      // Silent background polling failure; manual refresh remains available.
    }
  }

  Future<void> _submitPollVote(
    LiveUpdateEntryModel entry,
    PollModel poll,
    String optionId,
  ) async {
    setState(() => _submittingPollIds.add(poll.id));
    try {
      final updated = await _pollsRemote.submitVote(
        pollId: poll.id,
        optionId: optionId,
      );
      if (!mounted) {
        return;
      }
      final detail = _detail;
      if (detail == null) {
        return;
      }
      final entries = detail.entries
          .map(
            (item) =>
                item.id == entry.id ? item.copyWith(linkedPoll: updated) : item,
          )
          .toList(growable: false);
      setState(() => _detail = detail.copyWith(entries: entries));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapFailure(error).message)));
    } finally {
      if (mounted) {
        setState(() => _submittingPollIds.remove(poll.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _buildBody(context, detail),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, LiveUpdatePageDetailModel? detail) {
    if (_loading && detail == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null && detail == null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [Text(_errorMessage!, textAlign: TextAlign.center)],
      );
    }
    if (detail == null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          Text('Live update page is unavailable.', textAlign: TextAlign.center),
        ],
      );
    }
    final page = detail.page;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(AppRouter.liveUpdatesPath);
                }
              },
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                page.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (page.coverImageUrl?.trim().isNotEmpty ?? false)
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Image.network(
              page.coverImageUrl!,
              height: 240,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _LiveStatusPill(
              label: page.isLive ? 'LIVE' : _titleCase(page.status),
              active: page.isLive,
            ),
            _LiveStatusPill(label: page.category),
            if (page.isBreaking) const _LiveStatusPill(label: 'Breaking'),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          page.title,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (page.heroKicker?.trim().isNotEmpty ?? false) ...[
          const SizedBox(height: 10),
          Text(
            page.heroKicker!,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Text(page.summary, style: Theme.of(context).textTheme.bodyLarge),
        if (page.lastPublishedEntryAt != null) ...[
          const SizedBox(height: 10),
          Text(
            'Last updated ${adminDateTimeLabel(page.lastPublishedEntryAt!)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 24),
        ...detail.entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _LiveEntryCard(
              entry: entry,
              submittingPollIds: _submittingPollIds,
              onVote: _submitPollVote,
            ),
          ),
        ),
      ],
    );
  }
}

class _LiveEntryCard extends StatelessWidget {
  const _LiveEntryCard({
    required this.entry,
    required this.submittingPollIds,
    required this.onVote,
  });

  final LiveUpdateEntryModel entry;
  final Set<String> submittingPollIds;
  final Future<void> Function(
    LiveUpdateEntryModel entry,
    PollModel poll,
    String optionId,
  )
  onVote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            adminDateTimeLabel(entry.publishedAt),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (entry.headline?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Text(
              entry.headline!,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (entry.body?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 10),
            Text(entry.body!, style: theme.textTheme.bodyLarge),
          ],
          if (entry.imageUrl?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(
                entry.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            if (entry.imageCaption?.trim().isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              Text(entry.imageCaption!, style: theme.textTheme.bodySmall),
            ],
          ],
          if (entry.linkedArticle != null) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () => context.push(
                AppRouter.newsDetailPath(entry.linkedArticle!.id),
                extra: entry.linkedArticle,
              ),
              borderRadius: BorderRadius.circular(20),
              child: Ink(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.linkedArticle!.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (entry.linkedArticle!.summary?.trim().isNotEmpty ??
                        false) ...[
                      const SizedBox(height: 6),
                      Text(
                        entry.linkedArticle!.summary!,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          if (entry.linkedPoll != null) ...[
            const SizedBox(height: 12),
            _EmbeddedPollCard(
              poll: entry.linkedPoll!,
              submitting: submittingPollIds.contains(entry.linkedPoll!.id),
              onVote: (optionId) => onVote(entry, entry.linkedPoll!, optionId),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmbeddedPollCard extends StatelessWidget {
  const _EmbeddedPollCard({
    required this.poll,
    required this.submitting,
    required this.onVote,
  });

  final PollModel poll;
  final bool submitting;
  final ValueChanged<String> onVote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalVotes = poll.totalVotes;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.25,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            poll.question,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ...poll.options.map((option) {
            final fraction = totalVotes == 0 ? 0.0 : option.votes / totalVotes;
            final disabled = submitting || poll.hasVoted || poll.isClosed;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: disabled ? null : () => onVote(option.id),
                borderRadius: BorderRadius.circular(16),
                child: Ink(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(option.label)),
                          Text('${option.votes}'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: fraction),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _LiveStatusPill extends StatelessWidget {
  const _LiveStatusPill({required this.label, this.active = false});

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
