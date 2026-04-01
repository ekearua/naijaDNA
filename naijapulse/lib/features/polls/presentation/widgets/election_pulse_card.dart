import 'package:flutter/material.dart';
import 'package:naijapulse/core/theme/theme.dart';
import 'package:naijapulse/features/polls/domain/entities/poll.dart';

class ElectionPulseCard extends StatelessWidget {
  const ElectionPulseCard({required this.poll, super.key});

  final Poll poll;

  @override
  Widget build(BuildContext context) {
    final totalVotes = poll.totalVotes == 0 ? 1 : poll.totalVotes;
    final topOptions = [...poll.options]
      ..sort((a, b) => b.votes.compareTo(a.votes));
    final leaders = topOptions.take(2).toList();

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
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.darkSurfaceMuted
                  : AppTheme.bgSoft,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(23),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.flag_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Election 2027',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_formatVotes(poll.totalVotes)} active votes',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  poll.question,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 14),
                ...leaders.asMap().entries.map((entry) {
                  final index = entry.key;
                  final candidate = entry.value;
                  final ratio = candidate.votes / totalVotes;
                  final percent = (ratio * 100).round();
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == leaders.length - 1 ? 0 : 12,
                    ),
                    child: _CandidateResultTile(
                      name: candidate.label,
                      subtitle: index == 0 ? 'Leading candidate' : 'Runner-up',
                      ratio: ratio,
                      percent: percent,
                      color: index == 0
                          ? const Color(0xFF2A6CA1)
                          : const Color(0xFFC13C3C),
                    ),
                  );
                }),
              ],
            ),
          ),
          Divider(height: 1, color: Theme.of(context).dividerColor),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {},
              child: const Text('View results'),
            ),
          ),
        ],
      ),
    );
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

class _CandidateResultTile extends StatelessWidget {
  const _CandidateResultTile({
    required this.name,
    required this.subtitle,
    required this.ratio,
    required this.percent,
    required this.color,
  });

  final String name;
  final String subtitle;
  final double ratio;
  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$name - $percent%',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 34,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.darkSurfaceMuted
                : AppTheme.bgSoft,
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: ratio.clamp(0, 1),
                  child: Container(color: color),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '$percent%',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
