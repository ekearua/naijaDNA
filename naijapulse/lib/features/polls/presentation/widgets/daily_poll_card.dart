import 'package:flutter/material.dart';
import 'package:naijapulse/core/theme/theme.dart';
import 'package:naijapulse/features/polls/domain/entities/poll.dart';

class DailyPollCard extends StatelessWidget {
  const DailyPollCard({
    required this.poll,
    required this.isSubmitting,
    required this.onVote,
    super.key,
  });

  final Poll poll;
  final bool isSubmitting;
  final ValueChanged<String> onVote;

  @override
  Widget build(BuildContext context) {
    final totalVotes = poll.totalVotes == 0 ? 1 : poll.totalVotes;
    final canVote = !poll.isClosed && !poll.hasVoted && !isSubmitting;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.45),
        ),
        color: Theme.of(context).colorScheme.surface,
        boxShadow: AppTheme.ambientShadow(Theme.of(context).brightness),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(23),
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.88),
                  Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.82),
                ],
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.how_to_vote_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Daily Poll',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Icon(
                  Icons.more_horiz_rounded,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  poll.question,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                ...poll.options.asMap().entries.map((entry) {
                  final index = entry.key;
                  final option = entry.value;
                  final ratio = option.votes / totalVotes;
                  final percent = (ratio * 100).round();
                  final isSelected = option.id == poll.selectedOptionId;
                  final color = _barColor(index, context);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PollOptionResultBar(
                      label: option.label,
                      percent: percent,
                      ratio: ratio,
                      color: color,
                      isSelected: isSelected,
                      isVoteEnabled: canVote,
                      onTap: () => onVote(option.id),
                    ),
                  );
                }),
                const SizedBox(height: 2),
                Text(
                  '${_formatVotes(poll.totalVotes)} votes',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.share_rounded, size: 20),
                    label: const Text('Share results'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                if (isSubmitting) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _barColor(int index, BuildContext context) {
    switch (index) {
      case 0:
        return Theme.of(context).colorScheme.primary;
      case 1:
        return const Color(0xFFEABF45);
      case 2:
        return const Color(0xFFB8D7F2);
      default:
        return const Color(0xFFD7E3E1);
    }
  }

  String _formatVotes(int value) {
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

class _PollOptionResultBar extends StatelessWidget {
  const _PollOptionResultBar({
    required this.label,
    required this.percent,
    required this.ratio,
    required this.color,
    required this.isSelected,
    required this.isVoteEnabled,
    required this.onTap,
  });

  final String label;
  final int percent;
  final double ratio;
  final Color color;
  final bool isSelected;
  final bool isVoteEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isVoteEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.darkSurfaceMuted
                : AppTheme.bgSoft,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: ratio.clamp(0, 1),
                  child: Container(color: color.withValues(alpha: 0.92)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '$percent%',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
