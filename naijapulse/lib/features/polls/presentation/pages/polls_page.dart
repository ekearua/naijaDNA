import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:naijapulse/core/routing/app_router.dart';
import 'package:naijapulse/core/theme/theme.dart';
import 'package:naijapulse/core/widgets/app_search_bar.dart';
import 'package:naijapulse/features/polls/presentation/bloc/polls_bloc.dart';
import 'package:naijapulse/features/polls/presentation/widgets/daily_poll_card.dart';
import 'package:naijapulse/features/polls/presentation/widgets/election_pulse_card.dart';

class PollsPage extends StatelessWidget {
  const PollsPage({this.showScaffold = true, super.key});

  final bool showScaffold;

  @override
  Widget build(BuildContext context) {
    final content = BlocBuilder<PollsBloc, PollsState>(
      builder: (context, state) {
        if (state.status == PollsStatus.loading && state.polls.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.status == PollsStatus.error && state.polls.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(state.errorMessage ?? 'Unable to load polls.'),
            ),
          );
        }

        if (state.polls.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async {
              context.read<PollsBloc>().add(const LoadPollsRequested());
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: const [
                _PollsHero(activePolls: 0, totalVotes: 0),
                SizedBox(height: 18),
                _PollsEmptyCard(),
              ],
            ),
          );
        }

        final dailyPoll = state.polls.first;
        final electionPoll = state.polls.length > 1 ? state.polls[1] : null;
        final totalVotes = state.polls.fold<int>(
          0,
          (sum, poll) => sum + poll.totalVotes,
        );

        return RefreshIndicator(
          onRefresh: () async {
            context.read<PollsBloc>().add(const LoadPollsRequested());
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _PollsHero(
                activePolls: state.polls.length,
                totalVotes: totalVotes,
              ),
              const SizedBox(height: 20),
              const _PollsSectionHeader(
                title: 'Daily Pulse',
                subtitle:
                    'Quick community reads on the questions shaping the day.',
              ),
              const SizedBox(height: 12),
              DailyPollCard(
                poll: dailyPoll,
                isSubmitting: state.status == PollsStatus.submitting,
                onVote: (optionId) {
                  context.read<PollsBloc>().add(
                    VotePollRequested(pollId: dailyPoll.id, optionId: optionId),
                  );
                },
              ),
              if (electionPoll != null) ...[
                const SizedBox(height: 24),
                const _PollsSectionHeader(
                  title: 'Election Tracker',
                  subtitle:
                      'A longer-running signal on where sentiment is starting to settle.',
                ),
                const SizedBox(height: 12),
                ElectionPulseCard(poll: electionPoll),
              ],
              const SizedBox(height: 18),
              const _PollsEditorialNote(),
            ],
          ),
        );
      },
    );

    if (!showScaffold) {
      return content;
    }

    return Scaffold(body: SafeArea(top: true, child: content));
  }
}

class _PollsHero extends StatelessWidget {
  const _PollsHero({required this.activePolls, required this.totalVotes});

  final int activePolls;
  final int totalVotes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppTheme.editorialGradient(Theme.of(context).brightness),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                    return;
                  }
                  context.go(AppRouter.homePath);
                },
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: Theme.of(context).colorScheme.copyWith(
                      surface: Colors.white.withValues(alpha: 0.12),
                      onSurface: Colors.white,
                    ),
                    dividerColor: Colors.white.withValues(alpha: 0.18),
                  ),
                  child: AppSearchBar(
                    height: 44,
                    hintText: 'Search coverage and context',
                    onTap: () => context.push(AppRouter.searchPath),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                onPressed: () =>
                    context.read<PollsBloc>().add(const LoadPollsRequested()),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.sync_rounded),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Public Pulse',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Where the audience is leaning, in real time.',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontFamily: AppTheme.headlineFontFamily,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Track the daily poll, follow the longer election pulse, and keep public sentiment beside the headline coverage.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.86),
              height: 1.48,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroChip(label: '$activePolls active polls'),
              _HeroChip(label: '${_formatVotes(totalVotes)} votes logged'),
              const _HeroChip(label: 'Community signal'),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatVotes(int value) {
    final digits = value.toString();
    final chars = digits.split('');
    final buffer = StringBuffer();
    for (var i = 0; i < chars.length; i++) {
      buffer.write(chars[i]);
      final positionFromEnd = chars.length - i - 1;
      if (positionFromEnd > 0 && positionFromEnd % 3 == 0) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PollsSectionHeader extends StatelessWidget {
  const _PollsSectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

class _PollsEditorialNote extends StatelessWidget {
  const _PollsEditorialNote();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final background = brightness == Brightness.dark
        ? AppTheme.darkSurfaceMuted
        : AppTheme.bgSoft;
    final border = brightness == Brightness.dark
        ? AppTheme.darkDivider
        : AppTheme.divider;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border.withValues(alpha: 0.65)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.forum_outlined, color: AppTheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How to read this',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Polls are a conversation tool, not a projection. Use them as a snapshot of audience mood beside the broader reporting.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
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

class _PollsEmptyCard extends StatelessWidget {
  const _PollsEmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.45),
        ),
        boxShadow: AppTheme.ambientShadow(Theme.of(context).brightness),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No active polls right now.',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Pull to refresh when the next public pulse is published.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
